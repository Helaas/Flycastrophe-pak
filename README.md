# Flycastrophe for Leaf

Flycastrophe is a Dreamcast, Naomi and Atomiswave emulator for Leaf on the Miniloong Pocket 1.
It's Flycast's libretro core with speed changes from Deadcast ported in, and it runs in Leaf's
own RetroArch next to the Flycast cores Leaf already ships. The name is a warning: it trades
some accuracy for speed, so a game that looks wrong here may be fine in Flycast.

**Version 0.1.0 requires Leaf 0.14.0 or newer.** Deadcast's main speed changes are in: the
sound chip and the polygon setup each run on a thread of their own, the CPU emulation uses
Deadcast's recompiler, and a game that falls behind skips frames to keep full speed. On the
Miniloong Pocket 1 that holds Crazy Taxi and Sonic Adventure 2 at a steady 60 fps, and with the
frame limit off it's 21% and 49% faster there than Leaf's Flycast core.
[FLYCASTROPHE.md](https://github.com/Helaas/Flycastrophe/blob/main/FLYCASTROPHE.md) in the
core's repository lists every change, what was left out and why.

## Using it

Install **Flycastrophe** from **Actions → Pak Rat**. There's no app to open: Flycastrophe shows up as
an emulator choice for Dreamcast, Naomi and Atomiswave. Pick it for a whole system or for a
single game, the same way you choose any other emulator in Leaf.

- Your games and BIOS files stay where they are: Flycastrophe uses the same `BIOS/dc` folder
  as Flycast.
- Save states and game saves go in Flycastrophe's own folders, `States/Flycastrophe` and
  `Saves/Flycastrophe`, so states you made with Flycast don't show up here.
- Flycastrophe keeps its own shared VMUs in `BIOS/dc/flycastrophe/`, so its saves never land in a
  VMU another Flycast core is using. If you want a save from Flycast, copy the
  `vmu_save_A1.bin` file across.
- `Saves/Flycastrophe` also gets a `.blocks` file per game when you quit it: the game code
  Flycastrophe translated, so a resumed game doesn't stall while it translates that code
  again. Deleting these files is safe.
- Per-pixel transparency sorting is not available. Transparency sorting defaults to per-strip,
  the fastest; Daytona USA 2001 (US and European discs) always sorts per triangle so the decals
  on the cars show.

The release checks cover boot and clean exit in 17 games, benchmark scenes in Crazy Taxi
and Sonic Adventure 2, and Pak Rat installation and removal. Full hands-on play, per-game
state checks and the complete launcher lifecycle checklist remain incomplete. See the
[release notes](https://github.com/Helaas/Flycastrophe-pak/releases/tag/v0.1.0) for details.

## If a game looks or sounds wrong

Each speed change has an option of its own. While the game is running, open the RetroArch
in-game menu and go to **Core Options**. The first four take effect the next time you start the
game.

- **Threaded Audio** (on) runs the sound chip on its own thread. Turn it off if a game's sound
  or timing goes wrong.
- **Parse Thread** (on) prepares each frame's polygons on its own thread. It helps games limited
  by drawing and costs a little in the rest.
- **Fast Vector Math** (on) computes the CPU's vector instructions faster but less exactly. Turn
  it off if a game's geometry jitters.
- **Idle Loop Skip** (on) lets the CPU skip the wait loops of the games Flycastrophe knows. Turn
  it off if a game hangs or runs at the wrong speed.
- **Auto Skip Frame** (Maximum) skips up to two frames in a row while a game is behind, so the
  game and its sound keep full speed. Set it to **Disabled** to draw every frame.
- **Audio DSP** (off) runs the sound chip's effects processor. Turn it on if a game's sound is
  missing its reverb or effects; it costs some speed.

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

The pinned core is built with profile-guided optimization: `core/pgo/profile.tar.gz`
holds GCC profile data from an instrumented build played on an MLP1, and the lock
records the commit it was trained on. A local checkout builds without it. Pinning a
new commit means training a new profile; `core/pgo/README.md` has the steps.

## Credits and licences

Flycast is by flyinghead and its contributors, and Deadcast is by tyrannotorus. Any mistakes in
the port are ours. The core is GPL-2.0; this repository's build scripts are MIT. See
[LICENSES](LICENSES/README.md).
