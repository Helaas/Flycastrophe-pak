# Flycastrophe for Leaf

Flycastrophe is a Dreamcast, Naomi and Atomiswave emulator for Leaf on the Miniloong Pocket 1.
It's Flycast's libretro core with speed changes from Deadcast ported in, and it runs in Leaf's
own RetroArch next to the Flycast cores Leaf already ships. The name is a warning: it trades
some accuracy for speed, so a game that looks wrong here may be fine in Flycast.

**Status: in development, not released yet.** The core is still plain Flycast with Leaf
packaging. The speed changes arrive one at a time, and each is measured on the device before
it lands. [FLYCASTROPHE.md](https://github.com/Helaas/Flycastrophe/blob/main/FLYCASTROPHE.md)
in the core's repository lists what has been ported and what hasn't.

## Using it

Once it's on Pak Rat, install it from there. There's no app to open: Flycastrophe shows up as
an emulator choice for Dreamcast, Naomi and Atomiswave. Pick it for a whole system or for a
single game, the same way you choose any other emulator in Leaf.

- Your games and BIOS files stay where they are: Flycastrophe uses the same `BIOS/dc` folder
  as Flycast.
- Save states and game saves go in Flycastrophe's own folders, `States/Flycastrophe` and
  `Saves/Flycastrophe`, so states you made with Flycast don't show up here.
- Flycastrophe keeps its own shared VMUs in `BIOS/dc/flycastrophe/`, so its saves never land in a
  VMU another Flycast core is using. If you want a save from Flycast, copy the
  `vmu_save_A1.bin` file across.
- Per-pixel transparency sorting is not available. Use per-triangle or per-strip.

## Building

You need Docker, make, git and python3. Nothing outside this repository is required.

```
make check         # build the pinned core, package it, validate the package
make dist-pakrat   # build/dist/Flycastrophe.mlp1.pak.zip
```

The core's source commit, its submodules and the toolchain image are pinned in
`core/core.lock.json`. To try a local checkout of the core instead:

```
FLYCASTROPHE_SRC=../Flycastrophe make package-mlp1
```

## Credits and licences

Flycast is by flyinghead and its contributors, and Deadcast is by tyrannotorus. Any mistakes in
the port are ours. The core is GPL-2.0; this repository's build scripts are MIT. See
[LICENSES](LICENSES/README.md).
