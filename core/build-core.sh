#!/usr/bin/env bash
# Build the Flycastrophe libretro core for the Miniloong Pocket 1.
#
# Self-contained: a clean clone of this repository plus Docker is the whole
# toolchain. Everything it needs is pinned in core/core.lock.json.
#
#   core/build-core.sh                        build into build/core, check the lock
#   FORCE=1 core/build-core.sh                rebuild even if the artifact is there
#   FLYCASTROPHE_SRC=<checkout> core/build-core.sh
#       build a local Flycastrophe checkout as it is (development only: the
#       lock's commit and hash are not checked, and the output says so)
#
# A locked build is profile-guided: it uses the profile in core/pgo/ that the
# lock's pgo section records, which only fits the lock's source commit. To
# train a new one (see core/pgo/README.md):
#   PGO=generate core/build-core.sh
#       an instrumented core that writes GCC profile data (.gcda) on exit
#   PGO=use PGO_PROFILE=<dir of .gcda files> core/build-core.sh
#       a core optimized with that profile
#   PGO=off core/build-core.sh
#       no profile (none of these three is checked against the lock)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$REPO_ROOT/core/core.lock.json"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"
OUT_DIR="$BUILD_DIR/core"

die() { echo "build-core: $*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "docker is required"
command -v git >/dev/null 2>&1 || die "git is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

lock_get() { # lock_get key key ... -> value (lists joined by spaces)
  python3 -I - "$LOCK" "$@" <<'PY'
import json, sys
v = json.load(open(sys.argv[1]))
for k in sys.argv[2:]:
    v = v[k]
print(" ".join(v) if isinstance(v, list) else v)
PY
}

SOURCE_URL="$(lock_get core source_url)"
SOURCE_COMMIT="$(lock_get core source_commit)"
IMAGE_REF="$(lock_get toolchain image)@$(lock_get toolchain digest)"
ARTIFACT="$(lock_get artifact file_name)"
EXPECTED_SHA="$(lock_get artifact sha256)"
EXPECTED_NEEDED="$(lock_get artifact needed)"
CMAKE_FLAGS="$(lock_get build cmake_flags)"
TARGET="$(lock_get build target)"

DEV=0
if [ -n "${FLYCASTROPHE_SRC:-}" ]; then
  DEV=1
  SRC_DIR="$(cd "$FLYCASTROPHE_SRC" && pwd)"
  echo "build-core: DEVELOPMENT build of $SRC_DIR at $(git -C "$SRC_DIR" rev-parse --short HEAD)$(git -C "$SRC_DIR" diff --quiet || echo ' + uncommitted changes')"
else
  SRC_DIR="$BUILD_DIR/flycastrophe-src"
fi

# Profile-guided builds. Every phase builds in /tmp/build inside the container,
# so GCC's .gcda names (the mangled object path under /tmp/pgo) match.
PGO="${PGO:-}"
if [ -z "$PGO" ]; then
  if [ "$DEV" = 0 ]; then PGO=lock; else PGO=off; fi
fi
PGO_FLAGS=""
PGO_MOUNT=()
case "$PGO" in
  off) ;;
  generate) PGO_FLAGS="$(lock_get pgo generate_flags)" ;;
  use|lock)
    if [ "$PGO" = lock ]; then
      [ "$(lock_get pgo trained_commit)" = "$SOURCE_COMMIT" ] \
        || die "the profile in core/pgo was trained on $(lock_get pgo trained_commit), the lock builds $SOURCE_COMMIT: retrain it (core/pgo/README.md)"
      PROFILE_TAR="$REPO_ROOT/$(lock_get pgo profile)"
      PROFILE_SHA="$(python3 -I -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$PROFILE_TAR")"
      [ "$PROFILE_SHA" = "$(lock_get pgo profile_sha256)" ] || die "$PROFILE_TAR sha256 $PROFILE_SHA, the lock says $(lock_get pgo profile_sha256)"
      PGO_PROFILE="$BUILD_DIR/pgo-profile"
      rm -rf "$PGO_PROFILE"; mkdir -p "$PGO_PROFILE"
      tar -xzf "$PROFILE_TAR" -C "$PGO_PROFILE"
    fi
    [ -d "${PGO_PROFILE:-}" ] || die "PGO=use needs PGO_PROFILE, a directory of .gcda files"
    PGO_PROFILE="$(cd "$PGO_PROFILE" && pwd)"
    PGO_FLAGS="$(lock_get pgo use_flags)"
    PGO_MOUNT=(-v "$PGO_PROFILE":/pgo-in:ro) ;;
  *) die "PGO is generate, use or off" ;;
esac

mkdir -p "$OUT_DIR"

if [ -f "$OUT_DIR/$ARTIFACT" ] && [ "${FORCE:-0}" != 1 ] && [ "$DEV" = 0 ] && [ "$PGO" = lock ]; then
  echo "build-core: $ARTIFACT already built (FORCE=1 to rebuild)"
else
  if [ "$DEV" = 0 ]; then
    if [ ! -d "$SRC_DIR/.git" ]; then
      git init -q "$SRC_DIR"
      git -C "$SRC_DIR" remote add origin "$SOURCE_URL"
    fi
    echo "build-core: fetching $SOURCE_COMMIT"
    git -C "$SRC_DIR" fetch -q --depth 1 origin "$SOURCE_COMMIT"
    git -C "$SRC_DIR" -c advice.detachedHead=false checkout -q --force FETCH_HEAD
    git -C "$SRC_DIR" clean -q -fdx
    [ "$(git -C "$SRC_DIR" rev-parse HEAD)" = "$SOURCE_COMMIT" ] \
      || die "checked out $(git -C "$SRC_DIR" rev-parse HEAD), lock says $SOURCE_COMMIT"
  fi

  # The submodules a GLES libretro build compiles, at the source commit's own
  # gitlinks, which must match what the lock records.
  python3 -I - "$LOCK" <<'PY' | while read -r path commit; do
import json, sys
for s in json.load(open(sys.argv[1]))["submodules"]["list"]:
    print(s["path"], s["commit"])
PY
    case "$path" in
      core/deps/tinygettext/*) parent=core/deps/tinygettext; sub="${path#core/deps/tinygettext/}" ;;
      *) parent=.; sub="$path" ;;
    esac
    git -C "$SRC_DIR/$parent" submodule update --init --depth 1 -q -- "$sub"
    actual="$(git -C "$SRC_DIR/$path" rev-parse HEAD)"
    [ "$actual" = "$commit" ] || die "$path is at $actual, lock says $commit"
  done

  echo "build-core: building in $IMAGE_REF"
  docker run --rm \
    -v "$SRC_DIR":/src:ro \
    -v "$OUT_DIR":/out ${PGO_MOUNT[@]+"${PGO_MOUNT[@]}"} \
    -e CMAKE_FLAGS="$CMAKE_FLAGS" -e TARGET="$TARGET" -e ARTIFACT="$ARTIFACT" -e PGO_FLAGS="$PGO_FLAGS" \
    "$IMAGE_REF" \
    bash -euc '
      git config --global --add safe.directory "*"
      . /opt/mlp1-toolchain/umrk/mlp1-build-flags.env
      TC=/opt/mlp1-toolchain/bin/$CROSS_TRIPLE
      # The bind mount is read-only and, from macOS, slow and case-insensitive;
      # build from a copy on the container filesystem.
      cp -a /src /tmp/src
      mkdir -p /tmp/pgo
      if [ -d /pgo-in ]; then cp /pgo-in/*.gcda /tmp/pgo/; fi
      CC=$TC-gcc CXX=$TC-g++ \
      CFLAGS="$UMRK_MLP1_PROFILE_CFLAGS $PGO_FLAGS" CXXFLAGS="$UMRK_MLP1_PROFILE_CXXFLAGS $PGO_FLAGS" \
      LDFLAGS="$UMRK_MLP1_PROFILE_LDFLAGS $PGO_FLAGS" \
        cmake -S /tmp/src -B /tmp/build -G Ninja $CMAKE_FLAGS \
          -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
          -DCMAKE_SYSROOT="$SYSROOT" -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
          >/tmp/cmake.log 2>&1 || { tail -40 /tmp/cmake.log; exit 1; }
      ninja -C /tmp/build "$TARGET" >/tmp/ninja.log 2>&1 \
        || { grep -nE "error|fatal" /tmp/ninja.log | head -30; tail -20 /tmp/ninja.log; exit 1; }
      cp /tmp/ninja.log /out/ninja.log
      cp "/tmp/build/$ARTIFACT" /out/
      $TC-strip --strip-unneeded "/out/$ARTIFACT"
      $TC-readelf -d "/out/$ARTIFACT" | sed -n "s/.*(NEEDED).*\[\(.*\)\]/\1/p" | sort | tr "\n" " " >/out/needed.txt
    '
fi

for _ in {1..50}; do [ -f "$OUT_DIR/$ARTIFACT" ] && break; sleep 0.1; done
[ -f "$OUT_DIR/$ARTIFACT" ] || die "build produced no $ARTIFACT"

needed="$(cat "$OUT_DIR/needed.txt" 2>/dev/null || true)"
[ "${needed% }" = "$EXPECTED_NEEDED" ] \
  || die "NEEDED is '${needed% }', lock expects '$EXPECTED_NEEDED'"

ACTUAL_SHA="$(python3 -I -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$OUT_DIR/$ARTIFACT")"
echo "build-core: $ARTIFACT sha256 $ACTUAL_SHA"

if [ "$PGO" != lock ] && [ "$DEV" = 0 ]; then
  echo "build-core: PGO=$PGO build, not checked against the lock"
  exit 0
fi
if [ "$DEV" = 1 ]; then
  echo "build-core: development build, not checked against the lock"
  exit 0
fi
if [ "$EXPECTED_SHA" = "PENDING-FIRST-VERIFIED-BUILD" ]; then
  echo "build-core: the lock has no recorded hash yet; record it once two clean builds agree"
  exit 0
fi
[ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || die "sha256 mismatch
  built:  $ACTUAL_SHA
  locked: $EXPECTED_SHA
The source, a submodule or the toolchain moved. Find out which before updating the lock."
echo "build-core: matches the lock"
