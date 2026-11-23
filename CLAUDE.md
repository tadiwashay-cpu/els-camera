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
godot --headless --path . res://tools/capture/smoke.tscn -- 60 3 1 - harbor_factory   # full match, 4 bots (weapon|-, arena)
```
Looking at the game without a device (needs `xvfb-run`; renders with the
GL fallback, so colours differ a little from the tablet):
```
xvfb-run -a godot --path . --resolution 1600x1000 res://tools/capture/shots.tscn -- OUT_DIR
xvfb-run -a godot --path . --resolution 1600x1000 res://tools/capture/lobby_shots.tscn -- OUT_DIR   # Armory, multiplayer, lobby
xvfb-run -a godot --path . res://tools/capture/ragdoll_test.tscn -- OUT_DIR
xvfb-run -a godot --path . res://tools/capture/killcam_test.tscn -- OUT_DIR
xvfb-run -a godot --path . --script res://tools/capture/move_sheet.gd -- OUT.png Slash_A,Run 7
xvfb-run -a godot --path . --resolution 1600x1000 res://tools/capture/arena_tour.tscn -- OUT_DIR beach_island [skip_s]
xvfb-run -a godot --path . --resolution 1800x1100 res://tools/capture/weapon_sheet.tscn -- OUT_DIR   # every weapon model
xvfb-run -a godot --path . res://tools/capture/weapon_test.tscn -- OUT_DIR bazooka,grapple,fan   # use weapons on a bot
godot --headless --path . res://tools/capture/water_test.tscn -- harbor_factory -10 0 -21.5     # swim and climb out
godot --headless --path . res://tools/capture/pad_test.tscn -- beach_island      # every bounce pad lands where it should
# LAN match between two processes (run the host in the background, then the joiner; scores must match):
godot --headless --path . res://tools/capture/net_smoke.tscn -- host 40 beach_island &
godot --headless --path . res://tools/capture/net_smoke.tscn -- join [OUT_DIR]
```


## Animation
All fighter animation is original, authored in **Blender 5.3** by
`tools/blender/build_fighter.py` (rig + 87 moves -> `assets/fighters/block_fighter.glb`
and `.moves.json` with lengths, loops, hit windows, release/catch times).
Never import animation from Lookout or other projects. To change a move, edit
`tools/blender/moves.py` and rebuild (see docs/ANIMATION.md). Moves are in
place; the game moves the body and scales loop speed so feet don't slide.

## Weapon models
Every weapon's model is original, modelled in code in Blender by
`tools/blender/build_weapons.py` (kit: `weapon_kit.py`: lathes, tubes along
curves, bevelled blades, rounded boxes) -> `assets/weapons/weapon_models.glb`,
one mesh per weapon id in socket space (+Y grip to tip), vertex colours with
the finish in alpha, at most 2400 triangles each. `WeaponModels` loads them;
the box parts in `tools/gen_weapons.py` are the fallback. Rebuild with
`/home/user/tools/bpyenv/bin/python tools/blender/build_weapons.py`, then
`godot --headless --import`, then check `weapon_sheet.tscn`.

## Code map
| Path | What |
|---|---|
| `src/autoload/` | `Save` (user://save.json), `Registry` (weapons, skins, arenas), `Audio` (SFX), `Game` (scene flow, graphics presets, input map, rebinding `REBINDABLE`/`rebind`/`reset_bindings`, hit-stop), `Net` (ENet host/join, lobby, roster, RPCs) |
| `src/net/` | `LanDiscovery` (UDP broadcast of games), `NetSync` (in-match: host snapshots/inputs/events, joiner puppets, interpolation, mirrors) |
| `src/fighter/` | `Fighter` (movement, combat, states), `FighterInput`, `BlockBody` (skinned box mesh, animation tree), `Ragdoll`, `SkinData`, `ContactShadow` (soft ground shadow), `HealthBar` (life bar over the head) |
| `src/input/` | `PlayerInput` (keys, pad, touch -> FighterInput; `face_view` in first person), `TouchControls` (VirtualJoystick + buttons, per-button `layout` overrides, edit mode), `AIBrain` (bots) |
| `src/weapons/` | `WeaponData` (+ `data/*.tres`, generated by `tools/gen_weapons.py`; part finish in colour alpha: 1 matte, 0.5 metal, 0 glow; own `block_clip`/`parry_clip` for the shield), `WeaponModels` (the Blender models), `weapon.gdshader`, `ThrownWeapon` (ricochet, lightning, return, phantom/warp copies), `Bolt` (shot styles: bolt, plasma, arrow, pebble, slug, rocket, orb, hook, crescent, wave, rock, snow, fist, boulder, rail, tornado), `WeaponSkills` (a power per weapon: `INFO` table of effect kinds + `DESC`), `Armory` (ranked prices, owned/equipped weapons in the save), `WeaponPickup`, `BladeTrail` |
| `src/arenas/` | `Arena` base (nav mesh, sky, blocks merged per surface, water, `bounce_pad(at, land, apex)` with a nav link, hazard hooks: `tick`, `speed_factor_at`, `grip_at`, `floor_push`, `ignite`, `bot_goal`), `blockout_yard`, `beach_island`, `harbor_factory`, `Breakable`, `DebrisPool`, `ArenaData`, shaders |
| `src/match/` | `Match` (rules, spawns, pickups, killcam, `threats_to`, `hit_feel`), `KillRace` (pure rules), `CameraRig` (third/first person, shake, lean, landing dip, punch, FOV kick), `Hud`, `DangerIndicator`, `ScreenFx` (vignette; hurt/punch/speed effects, screen read only while active), `Killcam`, `Fx` |
| `src/ui/` | title (settings, CONTROLS rebinding screen), `TouchLayoutEditor`, `ArmoryScreen`, `WeaponIcons` (renders every weapon model once into an icon atlas), loading screen, theme |
| `tests/` | GUT unit tests |
| `tools/` | Blender pipeline, capture/test scenes |

## Rules
- Static typing everywhere, one class per file, signals between systems,
  tunables in resources or `@export` (adjustable in the Inspector).
- A Fighter never knows who controls it: everything goes through FighterInput.
- Online, only the host (`Match.authority`) changes game state; joiners' fighters
  are puppets. New gameplay effects that others must see go through `Match.net.event()`.
- Weapons, skins and arenas are data: a new weapon is a row in `tools/gen_weapons.py`
  (run it; Registry finds every .tres in src/weapons/data). Every weapon needs a
  rank (`TIERS`, sets its Armory price), a power (`SKILLS`, defined in `WeaponSkills`)
  and a model in `tools/blender/build_weapons.py` (tests check all three).
- Weapons must be bought (Armory) before a player can hold them: `Fighter.allowed`
  (empty = anything, for bots), set from the roster's "owned"; check `Fighter.can_use()`
  before giving a fighter a weapon.
- Performance budget (Redmi Pad 2): 60 fps target / 30 floor, < 150k triangles,
  < 150 draw calls, game < 1.2 GB RAM. One draw call per fighter (single
  skinned mesh). Effects are pooled. At most 11 physical bones per fighter.
- `main` must always open and run; unfinished work stays on branches.
- No `.godot/`, keystores or build output in git. Credit every asset in CREDITS.md.
- Generation tools (ForgeGUI, Higgsfield, ElevenLabs) spend the owner's credits:
  ask before each batch. This cloud session's network allows GitHub and
  package registries only; Hugging Face and the generators' file hosts are blocked.
