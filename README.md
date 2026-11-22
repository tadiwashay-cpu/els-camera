# Block Duelist 3D

A third-person arena fighter for Android. Block fighters with swords race for
kills against the clock: swing, throw your sword, catch theirs out of the air
and send it back faster, knock them off the edge.

**Version 0.1.0: Phase 1 playtest (first playable kill race).**
Made with Godot 4.7.2 (Mobile renderer, Jolt physics). Built for a 4 GB
tablet (Redmi Pad 2) and up.

## Get the build
Every push builds a debug APK: GitHub > **Releases** > "Block Duelist 3D vX.Y.Z
(playtest)", or Actions > latest run > Artifacts. On Android: tap the APK and
allow "install unknown apps". What to test and report: [docs/PLAYTEST.md](docs/PLAYTEST.md).

To work in the editor: open `project.godot` in Godot 4.7 (desktop, or the
Android editor app) and press Play.

## What's in 0.1.0
- **Timed Kill Race** vs 1 to 3 bots: 1 to 15 minute matches, respawns at the
  spawn farthest from enemies with 2 s of protection, kills count double in the
  last 30 seconds, sudden death on a tie, optional kill target.
- **Block fighters** on our own rig with 36 original moves made in Blender:
  walk/run/sprint, strafes and backpedal (with and without a sword), jumps,
  double-jump flip, wall kick, dodge roll, a 3-hit sword combo, a charged
  360° spin, punches and a kick, overhand throw, catch, pickups, hit reacts,
  get-ups, taunt and victory.
- **Physics combat**: damage comes from how fast the blade moves (sprinting
  and falling swings hit hardest), heavy hits ragdoll the target for a
  moment, death is a full ragdoll and drops the sword.
- **Throw and catch**: throw your sword at anyone; time the THROW button as
  one flies at you to catch it and send it back 1.5x faster.
- **Killcam**: when you're killed, a slow-motion replay of the finishing blow
  (an exact replay, ragdoll included). The match ends on a replay of the final kill.
- **Blockout Yard** arena: three height levels, a bridge, cover, 6 sword
  spawners and an edge you can be knocked off.
- Touch controls (Godot 4.7's virtual joystick + buttons), keyboard/mouse and gamepad.
- Loading screen with real progress, tips and shader warm-up; title, match
  setup and settings (graphics preset, look speed, aim assist, button size/opacity).

## Controls
| | Touch | Keyboard / mouse | Gamepad |
|---|---|---|---|
| Move (push far to sprint) | left joystick | WASD (Shift sprints) | left stick |
| Look | swipe right side | mouse | right stick |
| Attack (hold to charge) | ATTACK | J / left click | X |
| Jump (twice to flip, at a wall to kick off) | JUMP | Space | A |
| Throw / catch | THROW | K / right click | Y |
| Dodge roll | DODGE | L / Ctrl | B |
| Lock on | LOCK | Q / Tab | RB |
| Pause | II | Esc | Start |

## Project
| Path | What |
|---|---|
| `src/` | the game (see CLAUDE.md for the code map) |
| `assets/fighters/` | the rig and all moves (built by `tools/blender/`) |
| `tools/blender/` | Blender 5.3 scripts that build the rig and animations |
| `tools/capture/` | headless test match, screenshot and replay test scenes |
| `tests/` | unit tests (GUT) |
| `docs/` | roadmap, changelog, playtest guide, animation pipeline |

Credits: [CREDITS.md](CREDITS.md).
