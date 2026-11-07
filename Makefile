# Flycastrophe content pak for Leaf.
#
# A clean clone of this repository plus Docker, make and python3 is the whole
# toolchain. Nothing here reaches outside the repository: if a target needs a
# path starting with ../, it does not belong in this file.
#
#   make core           build the pinned Flycastrophe libretro core (cached)
#   make package-mlp1   assemble build/package/Flycastrophe.pak
#   make dist-pakrat    zip it into build/dist/Flycastrophe.mlp1.pak.zip
#   make validate       check pak.json against the content-pak contract
#   make check          validate + package + validate the packaged tree
#   make clean          remove build outputs (keeps the cached source)
#   make distclean      remove build/ entirely
#
# FLYCASTROPHE_SRC=<checkout> make core builds a local Flycastrophe checkout
# instead of the pinned commit (development only).

SHELL := /bin/bash
REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD ?= $(REPO_ROOT)/build
PACKAGE := $(BUILD)/package/Flycastrophe.pak
DIST := $(BUILD)/dist
ARTIFACT := $(DIST)/Flycastrophe.mlp1.pak.zip

# The content-pak contract this pak is validated against, pinned. leaf-contracts
# is public; a local clone works too (CONTRACT_DIR=...).
CONTRACT_REPO ?= https://github.com/Utility-Muffin-Research-Kitchen/leaf-contracts.git
CONTRACT_REF ?= a641d6d6977e0bd76dde63d55045783c0724bce9
CONTRACT_DIR ?= $(BUILD)/contract

.PHONY: all core package-mlp1 dist-pakrat contract validate check clean distclean help

all: dist-pakrat

help:
	@sed -n '1,16p' $(lastword $(MAKEFILE_LIST))

core:
	@"$(REPO_ROOT)/core/build-core.sh"

package-mlp1: core
	@rm -rf "$(PACKAGE)"
	@mkdir -p "$(PACKAGE)/cores" "$(PACKAGE)/info"
	@cp "$(REPO_ROOT)/pak/pak.json" "$(PACKAGE)/pak.json"
	@cp "$(BUILD)/core/flycastrophe_libretro.so" "$(PACKAGE)/cores/flycastrophe_libretro.so"
	@cp "$(REPO_ROOT)/info/flycastrophe_libretro.info" "$(PACKAGE)/info/flycastrophe_libretro.info"
	@cp "$(REPO_ROOT)/LICENSES/CORE-LICENSE.txt" "$(PACKAGE)/LICENSE-CORE.txt"
	@cp "$(REPO_ROOT)/LICENSES/README.md" "$(PACKAGE)/LICENSES.md"
	@echo "packaged $(PACKAGE)"

dist-pakrat: package-mlp1
	@mkdir -p "$(DIST)"
	@rm -f "$(ARTIFACT)"
	@cd "$(BUILD)/package" && zip -q -r -X "$(ARTIFACT)" "Flycastrophe.pak"
	@python3 -I -c "import hashlib,sys;p=sys.argv[1];print('sha256', hashlib.sha256(open(p,'rb').read()).hexdigest())" "$(ARTIFACT)"
	@echo "wrote $(ARTIFACT)"

contract:
	@if [ ! -d "$(CONTRACT_DIR)/.git" ]; then \
		git init -q "$(CONTRACT_DIR)" && git -C "$(CONTRACT_DIR)" remote add origin "$(CONTRACT_REPO)"; \
	fi
	@if [ "$$(git -C "$(CONTRACT_DIR)" rev-parse HEAD 2>/dev/null)" != "$(CONTRACT_REF)" ]; then \
		git -C "$(CONTRACT_DIR)" fetch -q --depth 1 origin "$(CONTRACT_REF)" && \
		git -C "$(CONTRACT_DIR)" -c advice.detachedHead=false checkout -q FETCH_HEAD; \
	fi

validate: contract
	@python3 -I "$(REPO_ROOT)/scripts/validate-pak.py" --contract "$(CONTRACT_DIR)" --pak "$(REPO_ROOT)/pak"

check: validate package-mlp1
	@python3 -I "$(REPO_ROOT)/scripts/validate-pak.py" --contract "$(CONTRACT_DIR)" --pak "$(PACKAGE)" --packaged

clean:
	@rm -rf "$(BUILD)/package" "$(BUILD)/dist" "$(BUILD)/core"

distclean:
	@rm -rf "$(BUILD)"
