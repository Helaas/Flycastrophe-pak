# Profile-guided optimization

`profile.tar.gz` is GCC profile data (`.gcda` files) from an instrumented build of the
lock's source commit, played on a Miniloong Pocket 1. `build-core.sh` checks it against the
lock's `pgo` section (its sha256 and the commit it was trained on), unpacks it into the
build container's `/tmp/pgo` and compiles with `pgo.use_flags`. Every build phase compiles in
the container's `/tmp/build`, so the profile's file names (the mangled object paths) match.

The profile fits its commit only. A build of another commit stops with "retrain it", and a
local checkout (`FLYCASTROPHE_SRC`) builds without a profile.

## Training a new profile

After pointing the lock at a new commit:

1. Build the instrumented core:

   ```
   BUILD_DIR=$PWD/build/pgo-gen PGO=generate core/build-core.sh
   ```

2. Play it on an MLP1 with Leaf. Flycastrophe's bench has the script
   (`flycastrophe/bench/flycastrophe/pgo-train.sh` in Helaas/Flycastrophe): it runs the
   instrumented core in Leaf's RetroArch on a set of savestates and attract demos, quits
   RetroArch through its command port after each so the counters are written, and pulls
   the `.gcda` files. Leave the bench games (Crazy Taxi, Sonic Adventure 2) out of training
   so the bench measures the profile on games it hasn't seen.

3. Build with it and bench it against the core it replaces:

   ```
   BUILD_DIR=$PWD/build/pgo-use PGO=use PGO_PROFILE=<pulled gcda dir> core/build-core.sh
   ```

4. Pack it and record it:

   ```
   python3 core/pgo/pack-profile.py <pulled gcda dir> core/pgo/profile.tar.gz
   ```

   In `core/core.lock.json`, set `pgo.profile_sha256` to the printed hash,
   `pgo.trained_commit` to the source commit and `pgo.training` to what was played. Then
   record the artifact as for any repin: `artifact.sha256` back to
   `PENDING-FIRST-VERIFIED-BUILD`, two clean builds that agree, then `FORCE=1 make check`.

`PGO=off core/build-core.sh` builds the pinned commit without a profile, for comparisons.
