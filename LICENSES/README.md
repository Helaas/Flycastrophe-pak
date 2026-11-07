# Licensing

| What | Licence | Where |
| --- | --- | --- |
| The Flycastrophe libretro core (`cores/flycastrophe_libretro.so`), built from [Helaas/Flycastrophe](https://github.com/Helaas/Flycastrophe), a fork of [Flycast](https://github.com/flyinghead/flycast) with changes from [Deadcast](https://github.com/tyrannotorus/emulator-dreamcast-deadcast) | GPL-2.0 | `CORE-LICENSE.txt` (`LICENSE-CORE.txt` in the package) |
| Third-party code built into the core (asio, libchdr with zlib and zstd, rcheevos, tinygettext and others under Flycast's `core/deps/`) | Their own licences, all GPL-2.0 compatible | the source tree at the commit in `core/core.lock.json` |
| This repository's build system, manifests and scripts | MIT | `REPO-LICENSE.txt` |

The core's source is the commit named in `core/core.lock.json`, with the submodule commits
listed there. Releases attach that source as an archive next to the pak.
