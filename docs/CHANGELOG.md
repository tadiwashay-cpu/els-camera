# Changelog

Versions are `MAJOR.MINOR.PATCH`; the number lives in `project.godot`
(`config/version`) and shows on the title screen and next to the FPS counter.
Bump MINOR for a phase or batch of features, PATCH for fixes.

## 0.1.2: Breakable arena

- Most cover in Blockout Yard can be smashed: crates and crate stacks,
  stone pillars, the edge railings (smash a segment and that stretch of edge
  is open for ring-outs) and explosive barrels.
- Blades break what they pass through (harder with faster swings and the
  spin), thrown swords smash crates and fly on through, and fighters knocked
  or ragdolled into scenery break it (credited to whoever sent them flying).
- Barrels blow up: big knockback and damage around them, chain reactions,
  the kill goes to whoever set it off. Bots throw at barrels next to you.
- Pieces burst into physics debris (pooled, fades after 5 s) and rebuild
  after 30-40 s; bots' paths update as things break; bots smash what blocks them.
- New sounds: wood and stone crashes, explosions.

## 0.1.1: Playtest fixes

- Fixed: after a jump, landing or dodge roll the body could stay frozen on
  the move's last frame and slide around (most visible when unarmed). Every
  move now hands the body back to running/standing when it ends.
- New jump animations (made in Blender, with sword versions): explosive
  launch, knee-drive rise (sword cocked behind the head), balanced fall,
  tucked front-flip double jump (the sword spins with you), back-flip wall
  kick, soft landing and a three-point "superhero" landing for big drops.

## 0.1.0: Phase 0 + Phase 1 playtest

First playable build: one arena, sword fights against bots.

**Game**
- Timed Kill Race against 1 to 3 bots (Easy / Normal / Hard), 1 to 15 minutes,
  optional kill target. Respawn after 3 s at the spawn farthest from enemies,
  2 s of protection. Last 30 seconds: kills count double. Tie: sudden death.
- Falling off the arena counts for whoever hit you in the last 5 s, else -1.
- Coins for kills and wins (saved; spent in a later phase).

**Fighters and moves**
- New block fighter rig and 36 original moves authored in Blender 5.3
  (tools/blender): locomotion with and without a sword, air moves, a 3-hit
  sword combo, a charged spin, punches and a kick, throw, catch, pickup, dodge
  roll, hit reacts, two get-ups, taunt, victory.
- Feet never slide: loops are played at the speed the fighter actually moves.
- Upper-body attacks while running; full-body moves when standing.
- Ragdolls on heavy hits (then a get-up that starts from how you landed) and on death.

**Combat**
- Damage from blade speed: base x clamp(speed / reference, 0.5, 2.5).
- Swept hit tests (no swings passing through at low frame rates).
- Throw and catch, aim assist (adjustable), lock-on.
- Hit-stop, camera shake, slow motion on kills, sparks, damage numbers, blade trails.
- Killcam replay of your death and of the final kill.

**Screens**
- Title with match setup and settings, loading screen with progress and tips,
  HUD, pause, results.

**Tech**
- Godot 4.7.2, Mobile renderer, Jolt physics, render scale presets with
  dynamic resolution, one draw call per fighter, pooled effects.
- CI: unit tests, a 60 s bots-only match, debug APK, playtest pre-release.

**Known gaps**
- Sounds are synthesised placeholders; no music yet.
- Blockout art only (grey boxes); real arenas start in Phase 2.
- No block/parry, powers or other weapons yet (Phase 2).
