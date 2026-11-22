# Roadmap

Seven phases; each ends in a tagged build tested on the Redmi Pad 2 before the
next starts. Claude ticks items as they land; the owner passes the gates.

## Phase 0: Foundation
- [x] Godot 4.7 project (Mobile renderer, Jolt, static typing), autoloads
- [x] CLAUDE.md, roadmap, changelog, playtest guide
- [x] CI: unit tests + bots-only match + debug APK on every push, playtest pre-release
- [x] Boot splash, title menu, loading screen (threaded load, progress bar, tips, shader warm-up)
- [x] **Gate:** the APK installs and opens on the Redmi Pad 2

## Phase 1: First playable fight (v0.1.0)
- [x] Block fighter on our own Blender rig (one skinned mesh, skins as data)
- [x] 36 original moves authored in Blender (tools/blender)
- [x] Third-person camera: shoulder spring arm, lock-on orbit, shake, hit-stop, slow-mo kills
- [x] Sword: 3-hit combo, charged spin heavy, blade-speed damage, blade trails
- [x] Throw and catch (catch window 200 ms, caught weapons fly back 1.5x faster)
- [x] Ragdoll: brief on heavy hits with get-up, full on death, sword drops as a pickup
- [x] Touch controls (VirtualJoystick + buttons), keyboard/mouse, gamepad
- [x] Blockout Yard arena (3 levels, bridge, cover, edges, 6 sword spawners, nav mesh)
- [x] Timed Kill Race vs bots (1 to 3), respawns with protection, last 30 s double, sudden death
- [x] Killcam replay of your death; final-kill replay; results with coins
- [x] **Gate:** owner played it on the tablet: "everything looks good", smooth on max settings

## Phase 2: Offline game (v0.2.x)
Done between playtests:
- [x] 0.1.1: fixed frozen sliding after one-off moves; new jump/landing animations
- [x] 0.1.2: breakable arena (crates, pillars, railings, explosive barrels, debris, rebuild)
- [x] 0.2.1: swimming and slow drowning, 23 more weapons (47), new weapon models, more detailed arenas

Increment A (combat depth):
- [x] Block (hold) and parry (150 ms window: staggers melee attackers, sends thrown weapons back)
- [x] Power meter (fills by dealing and taking damage) and 6 powers: Blink, Bullet Time,
      Shockwave Stomp, Rage, Iron Skin, Second Wind; power picked in match setup
- [x] Map pickups: health, speed boots, double damage, shield bubble, power battery
- [x] Bots block, parry and use powers (v0.1.3)

Increment B (weapons):
- [x] Weapon families with their own Blender movesets (blades, heavy, polearms, fists, thrown, ranged, joke)
- [x] 24 weapons (data + box models, tools/gen_weapons.py), mystery crate drops a rare one on the tower
- [x] Weapon swap / pick-up choice (v0.1.4)

Increment C (arenas, v0.2.0):
- [x] Beach Island (tide floods the beach, sharks in deep water, wreck cannon to the lighthouse)
- [x] Abandoned Harbor Factory (crane magnet + lever takeover, conveyor into a crusher, oil that burns, rain)
- [x] Arena choice in match setup (or Random), hazards on/off

- [ ] **Gate:** a 4-fighter, 5-minute match holds 60 fps on Medium with no blocking bugs

## Phase 3: LAN and hotspot multiplayer
- [ ] ENet host/join, UDP discovery, lobby, input sending, snapshots, interpolation
- [ ] **Gate:** two phones on a hotspot finish a match with no desync

## Phase 4: Content and progression
- [ ] Deep Forest, Abyss Submarine Base; 48 more weapons; all 12 powers
- [ ] Skins and customize screen, coins and unlocks, music, survival waves
- [ ] **Gate:** 30 minutes of solo play without running out of things to do

## Phase 5: Online and new 3D weapons
- [ ] Headless server, room codes, ping display; block football, king of the hill
- [ ] Gravity gun, freeze ray, jetpack, block builder and more
- [ ] **Gate:** an online match with a friend in another city stays playable

## Phase 6: Polish and release
- [ ] Boss tournament, performance and heat pass, touch layout editor
- [ ] Signed release build (AAB), store listing, v1.0 tag

## Tuning notes (from play-tests)
_Owner: add what felt off after each test here (or in an Issue)._

- v0.1.0 (Redmi Pad 2, max settings): smooth. Asked for better jump
  animations (done in 0.1.1), a fix for fighters sliding frozen after losing
  their weapon (done in 0.1.1) and a breakable, livelier environment.
