# Flycastrophe for Leaf

Flycastrophe is a Dreamcast, Naomi and Atomiswave emulator for Leaf on the Miniloong Pocket 1.
It's Flycast's libretro core with speed changes from Deadcast ported in, and it runs in Leaf's
own RetroArch next to the Flycast cores Leaf already ships. The name is a warning: it trades
some accuracy for speed, so a game that looks wrong here may be fine in Flycast.

**Version 0.3.0 requires Leaf 0.14.0 or newer.** Deadcast's main speed changes are in: the
sound chip and the polygon setup each run on a thread of their own, the CPU emulation uses
Deadcast's recompiler, and a game that falls behind skips frames to keep full speed. Version
0.3.0 adds three things. A new option, **Group Translucent Polygons**, speeds up games that are
limited by drawing, such as NFL 2K2, and it's off by default because it only helps those games.
The recompiler's code cache is three times larger, which removes a one-second stall that long
Sonic Adventure 2 sessions hit when the cache filled up. And the renderer does less work for
each polygon. The core is also bigger: it takes about 53 MB on your card, up from about
30 MB in 0.2.0.
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

See the [release notes](https://github.com/Helaas/Flycastrophe-pak/releases/tag/v0.3.0) for what was
checked and what wasn't.

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
- **Group Translucent Polygons** (off) lets see-through polygons that don't overlap on screen
  change places so more of them are drawn together. Every pixel still gets its polygons in the
  game's order, so the picture is the same. It helps games limited by drawing, such as NFL 2K2.
  It only applies when Transparency sorting is per-strip or the game sorts its own lists, and it
  stays off when Native Depth Interpolation is on.
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
