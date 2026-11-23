# Animation pipeline

Every move in the game is original, made in **Blender 5.3** by scripts in
`tools/blender/`. Nothing is imported from other projects.

```
tools/blender/rigkit.py         rig (Godot humanoid bone names) + posing solver
tools/blender/moves.py          the move set (edit this)
tools/blender/build_fighter.py  builds and exports everything
        -> assets/fighters/block_fighter.glb         skeleton + 36 animations
        -> assets/fighters/block_fighter.moves.json  length, loop, events, speed
```

## Rebuild
Blender as a Python module (no Blender install needed):
```
python3 -m venv ~/bpyenv && ~/bpyenv/bin/pip install bpy==5.3.0
~/bpyenv/bin/python tools/blender/build_fighter.py
```
Or with Blender installed: `blender -b -P tools/blender/build_fighter.py`.
Then `godot --headless --import` and commit the GLB and JSON.

## How moves are written
A pose is a handful of controls rather than bone angles: pelvis offset and
tilt, spine/chest/neck/head bends, **hand targets** (in chest space, so they
turn with the torso), **foot targets** (in world space, so feet stay planted),
elbow/knee directions, a **grip** (the direction the sword blade points) and,
for a shield, a **face** (`face_l`: the way its painted front looks; without
it the wrist follows the forearm, which spins a shield when the elbow moves).
`rigkit.py` solves arms and legs with two-bone IK and keys every frame.

- Fighting moves are `Keys(base, [(time, {changes}, ease), ...])`. Each key
  only lists what changes; vectors follow curves through the keys (arcs, not
  straight lines). Eases: `in` (wind-up), `snap` / `out` (strikes), `smooth`,
  `back` (overshoot). `RESET` starts a key from the default pose.
- Locomotion comes from `gait(...)`: stride, cadence, stance share, lift,
  bob, lean, arm swing. Feet are planted for the stance part of the cycle,
  so at the clip's native `speed` nothing slides; the game scales playback
  to the fighter's real speed.
- Events used by the game: `hit` [start, end] (when the blade/fist can land),
  `release` (throws), `catch`, `grab`.

Conventions: the character faces -Y in Blender (+Z in Godot), its left is +X.
+pitch bends forward, +roll leans left, +yaw turns left. Distances in metres.

## Checking a move
Render a contact sheet (rows = moves, columns = frames, two angles):
```
xvfb-run -a godot --path . --script res://tools/capture/move_sheet.gd -- out.png Slash_A,Throw 7
# with a real weapon model in hand (cell size, view, weapon id):
xvfb-run -a godot --path . --script res://tools/capture/move_sheet.gd -- out.png Shield_Bash,Shield_Slam 6 200 three shield
```

## Adding mocap later
The rig uses Godot's humanoid bone names, so motion capture or generated
motion can be retargeted onto it:
- **Video mocap** (Rokoko Vision, RGB MoCap) or **text-to-motion**
  (Tencent HY-Motion 1.0, PRISM on Hugging Face) export FBX/BVH.
- Import the FBX in Blender, map its bones to ours by name, bake onto the
  `Fighter` armature, and add it as an action; or in Godot import it with a
  BoneMap + SkeletonProfileHumanoid and add the clip to the AnimationPlayer.
- Add the move's timing to `moves.py` (or the JSON) so the game knows its
  hit window.

This cloud session can't reach Hugging Face or the generators' file hosts
(network policy), so generated motion has to be downloaded on another
machine or in an environment that allows those hosts.

## First-person weapon moves (0.7)
In first person only the weapon floats in front of the camera.
`tools/blender/fp_moves.py` holds 28 moves as keys of a grip offset (camera
space, metres) and an **aim** added to the weapon family's rest aim: yaw
(tip left/right), pitch (tip up/down, 90 = straight up) and roll (spin
about the weapon's length). `build_fp.py` keys two empties ("FP" for the
grip, "Aim" whose location carries the three angles) and exports one
animation per move to `assets/fighters/fp_weapon.glb`, plus `fp_weapon.json`
with each move's `strike` span. The game (`FPViewModel`) picks the FP move
for the body's move (`FROM_MOVE`), stretches it so the strike lands in the
body move's hit window (or its release/fire/slam/power event), and adds
sway, bob, a landing dip and a lift near walls.

```
~/bpyenv/bin/python tools/blender/build_fp.py
godot --headless --import
xvfb-run -a godot --path . --resolution 800x500 res://tools/capture/fp_sheet.tscn -- OUT.png
```

## Power casts (0.7)
`Cast_Sky`, `Cast_Ground`, `Cast_Buff`, `Cast_Forward` and `Cast_Pull` in
`moves.py` carry a `power` event; `WeaponSkills.INFO` sets `at` to the same
time for the powers that use them.
