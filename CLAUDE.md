# Block Duelist 3D: notes for Claude

Read this first in every session, then `docs/ROADMAP.md` to see where we are.
The design plan is the "Block Duelist 3D: Game Design & Build Plan" doc
(Claude Docs, shared by the owner).

## What this is
An original third-person 3D arena fighter for Android, inspired by the feel of
stick-fighter physics games (genre ideas only: original name, art, moves, sounds).
Timed Kill Race: 2 to 4 block fighters, most kills when the clock runs out wins.
Godot **4.7.2**, GDScript with static typing, Mobile renderer, Jolt physics.
Main test device: Redmi Pad 2 (4 GB RAM, Mali-G57 MC2, 2560x1600).

This repository used to hold an Android camera app (Open Camera fork). It was
cleared for the game; the old app is still in git history and on `master`.

## Workflow (owner tests, Claude builds)
1. Owner starts a chat: "Continue Block Duelist, Phase N, task: X".
2. Claude reads this file and `docs/ROADMAP.md`, works on the session branch,
   runs the checks below, commits, pushes.
3. GitHub Actions runs the tests and a bots-only match, then builds a debug
   APK: download it from Releases ("vX.Y.Z (playtest)") or the run's Artifacts.
4. Owner plays it on the tablet and replies "merge" or lists problems.
Claude can't see or feel the game: the owner's play-test is the quality gate.
Never call a phase done before its gate (ROADMAP) passes on the device.

## Checks to run before every push
```
godot --headless --import                                        # after asset changes
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
godot --headless --path . res://tools/capture/smoke.tscn -- 60 3 1   # full match, 4 bots
```
Looking at the game without a device (needs `xvfb-run`; renders with the
GL fallback, so colours differ a little from the tablet):
```
xvfb-run -a godot --path . --resolution 1600x1000 res://tools/capture/shots.tscn -- OUT_DIR
xvfb-run -a godot --path . res://tools/capture/ragdoll_test.tscn -- OUT_DIR
xvfb-run -a godot --path . res://tools/capture/killcam_test.tscn -- OUT_DIR
xvfb-run -a godot --path . --script res://tools/capture/move_sheet.gd -- OUT.png Slash_A,Run 7
```


## Animation
All fighter animation is original, authored in **Blender 5.3** by
`tools/blender/build_fighter.py` (rig + 36 moves -> `assets/fighters/block_fighter.glb`
and `.moves.json` with lengths, loops, hit windows, release/catch times).
Never import animation from Lookout or other projects. To change a move, edit
`tools/blender/moves.py` and rebuild (see docs/ANIMATION.md). Moves are in
place; the game moves the body and scales loop speed so feet don't slide.

## Code map
| Path | What |
|---|---|
| `src/autoload/` | `Save` (user://save.json), `Registry` (weapons, skins, arenas), `Audio` (SFX), `Game` (scene flow, graphics presets, input map, hit-stop) |
| `src/fighter/` | `Fighter` (movement, combat, states), `FighterInput`, `BlockBody` (skinned box mesh, animation tree), `Ragdoll`, `SkinData` |
| `src/input/` | `PlayerInput` (keys, pad, touch -> FighterInput), `TouchControls` (VirtualJoystick + buttons), `AIBrain` (bots) |
| `src/weapons/` | `WeaponData` (+ `data/*.tres`), `ThrownWeapon`, `WeaponPickup`, `BladeTrail` |
| `src/arenas/` | `Arena` base (nav mesh, sky, blocks), `blockout_yard`, `ArenaData`, grid shader |
| `src/match/` | `Match` (rules, spawns, pickups, killcam), `KillRace` (pure rules), `CameraRig`, `Hud`, `Killcam`, `Fx` |
| `src/ui/` | title, loading screen, theme |
| `tests/` | GUT unit tests |
| `tools/` | Blender pipeline, capture/test scenes |

## Rules
- Static typing everywhere, one class per file, signals between systems,
  tunables in resources or `@export` (adjustable in the Inspector).
- A Fighter never knows who controls it: everything goes through FighterInput.
- Weapons, skins and arenas are data: a new weapon is a `.tres` + a line in Registry.
- Performance budget (Redmi Pad 2): 60 fps target / 30 floor, < 150k triangles,
  < 150 draw calls, game < 1.2 GB RAM. One draw call per fighter (single
  skinned mesh). Effects are pooled. At most 11 physical bones per fighter.
- `main` must always open and run; unfinished work stays on branches.
- No `.godot/`, keystores or build output in git. Credit every asset in CREDITS.md.
- Generation tools (ForgeGUI, Higgsfield, ElevenLabs) spend the owner's credits:
  ask before each batch. This cloud session's network allows GitHub and
  package registries only; Hugging Face and the generators' file hosts are blocked.
