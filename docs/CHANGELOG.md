# Changelog

Versions are `MAJOR.MINOR.PATCH`; the number lives in `project.godot`
(`config/version`) and shows on the title screen and next to the FPS counter.
Bump MINOR for a phase or batch of features, PATCH for fixes.

## 0.7.0: First person weapon, power animations, Locker, new look

- **First person, rebuilt**: no more eyes, mouth or body in front of you.
  Only your weapon floats in front of the camera (your body is on a layer
  the eye camera skips; its shadow stays). The view is 90 degrees across
  (shooter standard), and the weapon sways when you turn, bobs when you
  walk, dips when you land and lifts its tip near walls so it never pokes
  through.
- **First-person swings made in Blender**: 28 moves (slashes, chop, stab,
  spear thrust and sweep, smash, spin, throw, gun kick, bow draw, guard,
  parry, shield bash/block/slam, casts, catch, equip). Each one is
  stretched so the swing crosses the screen exactly while the hit can land.
- **First-person motion blur**: a smear while you whip the view round and a
  soft blur at a run, like a real eye. Settings > FPP motion blur turns it
  off (it's always off on LOW).
- **Power animations made in Blender**: five new casting moves (call the
  sky, kneel and drive the weapon into the ground, power-up burst, push
  out, reach and yank back). Twelve weapon powers that borrowed the shout
  and stomp now use the one that fits.
- **Locker** (title > LOCKER):
  - LOOK: skin tone, shirt, pants and shoes colours (free), 7 hair styles,
    7 hats, 6 faces; some cost coins. Your fighter turns beside the menu,
    and wears your look in matches (online too) and on the loading screen.
  - UPGRADES: health, damage, speed and power, five levels each (200, 400,
    700, 1000, 1500 coins). Bots train too: a level on Normal, two on Hard.
  - Bots now get random looks.
- **New menu look**: slanted buttons, dark navy panels with a yellow
  stripe, bold italic condensed lettering (Barlow Condensed), a slanted
  poster band behind the title menu.
- **Armory INSPECT**: the weapon alone, big and lit; drag to turn it.

## 0.6.0: First person, button remapping, life bars, spawn fix

- **First person (FPP)**, CODM style: the FPP/TPP button under pause (or V,
  or the pad's Back) switches; Settings > Camera picks the default. The eye
  sits in your fighter's head, your body turns with the view and strafes,
  and the view pulls back out while you're knocked down. Third person stays
  the default.
- **Button remapping**: Settings > CONTROLS.
  - EDIT TOUCH LAYOUT: drag any on-screen button where you like, tap one and
    slide to resize it, SAVE (RESET puts them back).
  - Keyboard and gamepad: tap an action's key or pad button, then press the
    new one. A clash swaps the two; Pause can't be taken; RESET KEYS.
- **Life bars over heads** instead of damage numbers: a small bar about the
  size of a head floats over every fighter, drains when they're hit (a pale
  trail shows the hit) and follows them, even ragdolled. Its rim is the
  fighter's colour. Yours hides in first person.
- **No power names on screen**: using a weapon power or a power no longer
  shouts its name, and the HUD shows only the weapon (the SKILL button's
  ring shows when it's ready).
- **Fix: fighters spawning in the water / on top of each other** (Harbor
  Factory especially): with 9 spawn points the start spread put three
  fighters on each of three points and they burst apart, some into the sea.
  Each fighter now gets its own point (a seeded shuffle, the same on every
  phone), and a test checks every spawn point has dry ground 1.5 m around.
- Camera smoothing no longer depends on the frame rate.

## 0.5.0: Feel (lighting, screen effects, camera, particles) and bigger maps

- **Lighting**: metal reflects the sky (weapons, rails and trim shine),
  distant scenery fades into a sky-coloured haze that glows towards the sun,
  stronger colour grading, bloom only on bright parts. Soft contact shadows
  under every fighter (they ground fighters even on LOW, where sun shadows
  are off).
- **Screen effects** (MEDIUM and HIGH): a soft vignette; getting hit flashes
  the screen edges red with a colour split (stronger for heavy hits); your
  heavy hits and kills give a jolt; dashes, launches and bounce pads blur the
  edges of the screen towards the centre. The screen-reading effect only
  runs while one is happening.
- **Camera**: leans into sideways running, dips when you land hard, is
  knocked away from a blow that hits you, and widens (FOV kick) on kills,
  launches and bounce pads.
- **Particles**: soft dust clouds instead of cubes, dust kicked up when
  sprinting and rolling, a bright flash where every blow lands.
- **Bigger maps with twists: bounce pads** throw you in an arc to a set spot
  (bots use them too):
  - Blockout Yard: two new islands 6 m off the east and west edges (cover, a
    weapon spawner, a spawn point each); pads out and back, or sprint-jump.
  - Beach Island: Turtle Rock, a dry rock out west in shark water, with a
    palm, cover and a spawner; pads to it and back, up onto the ridge, and
    across to the islet.
  - Harbor Factory: a barge moored 5 m off the east quay with cargo and a
    spawner; pads to it and back, up onto the stacked containers, and onto
    the ship's deck.
  - Every arena now has at least 9 spawn points (for 8 bots).
- Fix (LAN): a kill in the match's last moment could be missing from a
  joiner's results; the host now sends the final scores with the end.

## 0.4.1: Curved weapon models, a big round shield with its own moves

- **Every weapon remodelled** with curves instead of boxes: 47 new models
  built in Blender from turned handles and pommels, swept curves (scythe,
  bow limbs, anchor arms, hooks), bevelled blades with real edges, and
  rounded heads. Metal parts shine, glowing parts glow, and each model stays
  under 2,400 triangles (about 1,000 on average). The Armory icons and the
  pickups use the new models.
- **The shield is bigger and round** (72 cm across, painted, with an iron rim,
  rivets and a steel boss) and fights its own way:
  - its own guard (shield up in front, the other fist ready),
  - two bashes: a stepping shove and a sweeping backhand,
  - a heavy: lift the shield overhead and slam it down, with a shockwave,
  - its own block (shield over the head and chest; blocks 85%) and parry,
  - the painted face always looks forward (new rig control for shields).

## 0.4.0: Weapon powers, the Armory, 8 bots

- **Every weapon has its own power** (48 in all, original): the SKILL
  button (keyboard C or G, gamepad LT) fires it, then it recharges (5 to
  14 s). The weapon glows in the power's colour when it's ready, and the
  HUD shows its name and READY or the seconds left. Powers are built from
  a few effects mixed per weapon: flying waves, dashes, teleports behind a
  target, pulls, blasts, leaping slams, spins, lightning storms, volleys,
  rains from the sky, ghost throws, a reflecting barrier and buffs (faster
  swings, free shots, a sugar-rush heal). Bots use them too. Online, the
  host runs them and every phone sees the same effects.
- **Not every weapon can be thrown**: 26 heavy, ranged and two-handed
  weapons stay in your hands (THROW does nothing with them). Thrown
  weapons and light blades still fly.
- **The Armory** (title screen): weapons are bought with coins before you
  can use them, priced by rank: S+ 1500, S 1000, A 600, B 350, C 150. The
  sword and fists are free. Each card shows the weapon (drawn from its 3D
  model), its rank, its power and what it does; a fighter on the right
  holds the selected weapon. EQUIP picks the weapon you start with.
  - A weapon you haven't bought can't be picked up or caught; standing on
    one shows "LOCKED" with its price. Bots can use everything.
  - "Start with" now offers **Your weapon** (the default: each fighter
    starts with their equipped weapon, bots with one of their own),
    Sword, Random (only weapons you own) or Fists. Online, every phone
    brings its own Armory weapons; the host enforces them.
  - Matches pay more: 15 coins a kill, 75 for a win, 10 for playing. Every
    save gets a one-time 500-coin welcome.
- **Up to 8 bots** (9 fighters) offline and online; spawns spread into
  rings when there are more fighters than spawn points.
- **Higher jumps**: 11.2 (double jump 10.2), about a metre more.
- **Danger sense**: when a thrown weapon or shot is about to hit you, a
  "!" flashes over your fighter, a chevron points where it's coming from
  and a short tingle plays, about 0.9 s before it lands.
- **Arms no longer go through the body** when running, guarding or
  fighting: the Blender rig now keeps the hands and elbows outside the
  torso, and the run, guard and idle arm poses were reworked.

## 0.3.0: Phase 3 increment A (LAN and hotspot multiplayer)

- **MULTIPLAYER** on the title screen: play with up to 4 phones on the
  same Wi-Fi, or on one phone's hotspot.
  - HOST A GAME opens a lobby; it shows the IPs others can type in.
  - Joiners see nearby games in a list (the host announces itself every
    second) or type the host's IP. Names come from "Your name".
  - The host picks match time, bots (0 to 3), bot skill, arena (or
    Random), start weapon and hazards; everyone sees them; START.
  - Every phone loads, then the countdown starts for all at once.
- **How it plays**: the host phone runs the real match (it decides hits,
  damage, hazards and bots); joiners send their controls 30 times a second
  and draw what the host sends back 30 times a second. Other fighters are
  smoothed about 0.1 s behind; your own fighter shows the newest state.
  Weapons in flight, shots, pickups, broken scenery, the crane, the press,
  oil fires, the tide and sharks all show the same on every phone. Hits,
  blasts, lightning, kill feed and callouts are sent as events; death and
  knockdown ragdolls are replayed on each phone from the same impulse.
- Online there's no killcam, slow motion or hit-stop (the match never
  pauses for anyone); the pause button opens a menu while play goes on.
- A joiner who leaves is replaced by a bot; if the host leaves, everyone
  goes back to the menu. Phones on different game versions can't join.
- After a match the host can start a rematch; joiners leave from results.
- CI now plays a real LAN match between two Godot processes and checks
  both sides finish with the same scores.

## 0.2.1: The sea, 23 new weapons, more detail

- **The sea drowns you slowly** instead of killing at once: standing in
  sea water drains 3 HP a second, swimming 6. Deep water floats you:
  swim to a ledge and press JUMP to kick up onto it (a strong kick, enough
  for the quay or a pier). No swinging or rolling while swimming; throwing
  works. Get knocked in and drown, and whoever knocked you in still gets
  the kill. The HUD warns you while you're in the water.
  - Beach Island: the tide now floods the beach for real (get onto the
    rocks, crates, the wreck, the hut or the ridge). Sharks bite swimmers
    in deep water every few seconds instead of killing outright. New rock
    outcrops in the shallows stay dry at high tide.
  - Harbor Factory: falling in is a swim back to a ladder, not an instant
    KO. The crane still dumps people in.
  - New treading-water Swim animation (Blender); getting knocked flying
    into deep water ends the ragdoll and you come up swimming.
- **23 new weapons** (47 in all), each our own design:
  - Melee: Scythe (wide sweeps), Lance (long charging thrust), Flail,
    Nunchucks (very fast), Shield (on the left arm: shield bashes, blocks
    soak 80% more, a longer parry window), Wrench, Shovel, Guitar (sends
    people flying), Umbrella (float down slowly), Ice Cream (chills:
    slows whoever it hits).
  - Thrown: Kunai, Snowball (chills), Saw Blade (ricochets off walls and
    slices through), Thunderbolt (calls down lightning: area damage and
    knockdowns, lights oil), Yo-yo (snaps back), Rocket Fist (a punch that
    flies out and comes back; new Blender move).
  - Ranged: Slingshot (pebbles that knock back), Twin Plasma Pistols
    (rapid, alternating hands), Bazooka (rockets that explode), Sniper
    Rifle (one big shot, slow to reload), Magic Scepter (homing orbs),
    Grapple Gun (pulls you to a wall, or yanks a fighter to you), Gust Fan
    (blows everyone in front back: great near water).
  - Rare (mystery crate): Bazooka, Sniper Rifle, Thunderbolt, Magic
    Scepter join the Plasma Blade, Anchor, Trident, Gauntlet and Bow.
- **Every weapon remodelled** with more parts (grips and wraps, guards,
  edges, bevels) and real finishes: polished metal shines, plasma and
  magic glow, wood and leather stay matte. Still one draw call each.
- **More detail on the new arenas** (merged into a few meshes, so it stays
  fast):
  - Beach Island: a fishing hut on stilts and a campfire, rock outcrops,
    driftwood, shells, starfish, seaweed, grass, wreck ribs and portholes,
    lighthouse door, windows and railing, pier lamps, a rowboat and buoys
    bobbing on the waves, gulls, drifting clouds and far islands.
  - Harbor Factory: a city skyline across the bay with lit windows and
    blinking beacons, ladders, mooring ropes, lifebuoys, a forklift,
    pallets, tyres, drums, barriers, cones, rain puddles, corrugated and
    windowed warehouse walls, a rolled-up door, a storage rack, steaming
    vents, ship railings, portholes, rust streaks, a lifeboat and mast light.
- Bots swim to the nearest ledge and climb out, wait out the tide on high
  ground, and judge reach from each weapon's length.

## 0.2.0: Phase 2 increment C (two new arenas)

- **Beach Island** (bright midday): a sand beach with a wrecked ship, a
  lighthouse on a rock, a wooden pier, palms, a waterfall over a cave and a
  rope bridge to a rock islet.
  - **The tide** comes in every 2 minutes (first at 0:45) and floods the
    low beach for about 25 s: wading is slow, so take the high ground.
  - **Sharks**: past the sand shelf the water is deep. Fall (or get knocked)
    in and a shark takes you; the kill goes to whoever knocked you in.
  - **Wreck cannon**: stand in the glowing ring at the cannon's breech and
    it fires you onto the lighthouse, where the mystery crate lands.
  - Smashable bridge planks and pier railings, washed-up crates, barrels.
- **Harbor Factory** (dusk, light rain): a container maze, a warehouse with
  catwalks, a cargo ship at the quay with two gangways, broken neon. Water
  on every side: knock people in.
  - **Gantry crane**: its magnet sweeps the yard and grabs loose metal
    weapons and anyone holding one (jump to kick free); it lets go over
    the water. Wood, rubber and plastic weapons are magnet-proof.
  - **Lever**: stand on the pad by the quay for a second to take over the
    crane for 10 s: it hunts your enemies and dunks them (your kills).
  - **Conveyor and crusher**: crates ride the belt into the press every
    4 s (red light and alarm first). So can you.
  - **Oil spills** are slippery; a blast, a bomb or a blaster bolt sets
    them on fire for 8 s.
- Match setup: **Arena** (Blockout Yard, Beach Island, Harbor Factory or
  Random, remembered) and **Hazards** on/off.
- Kill feed says how hazard kills happened ("fed to a shark", "crushed",
  "dunked").
- Bots use the cannon (especially to chase someone onto the lighthouse) and
  pull the crane lever, and kick free of the magnet.
- Performance: themed arenas merge their static boxes into one mesh per
  surface type (a handful of draw calls for the whole layout).
- CI plays a smoke match on every arena.

## 0.1.4: Phase 2 increment B (24 weapons)

- **24 weapons** (+ fists) in 7 families, each family with its own moves made
  in Blender:
  - Blades: Sword, Katana, Dagger (quick stabs), Rapier (fencing thrusts),
    Hand Axe, Plasma Blade
  - Heavy, two-handed: Hammer, Battle Axe, Pickaxe, Ship Anchor, Giant
    Lollipop: wide smashes, an overhead slam, and a charged leaping slam
    whose shockwave knocks down everyone around the impact
  - Polearms: Spear, Bo Staff, Trident: thrusts, a sweep and a long lunge
  - Fists: Fists, Boxing Gloves, Power Gauntlet
  - Thrown: Shuriken (x5), Throwing Knives (x4), Bomb (x2, explodes),
    Boomerang (comes back to your hand)
  - Ranged: Blaster (14 shots), Bow (hold to draw: harder, faster arrows);
    shots can be blocked, and parried back
  - Joke: Frying Pan (clang), Rubber Chicken (squeak, sends people flying)
- Weapon spawners hand out random weapons; every minute a gold **mystery
  crate** lands on the tower with a rare one inside (Plasma Blade, Anchor,
  Trident, Power Gauntlet, Bow).
- **SWAP** (R / D-pad up / touch button when you stand on a weapon): drop
  yours, take that one. Pickups keep their ammo.
- Match setup: start with a Sword, a **Random weapon** or Fists.
- Bots throw, shoot (and charge the bow) from range, and know each weapon's reach.

## 0.1.3: Phase 2 increment A (block, parry, powers, pickups)

- **Block** (hold BLOCK): walk with your guard up; blocked hits do 15% (heavy
  30%) and push you back; too much and the guard breaks.
- **Parry**: raise the guard within 150 ms of a hit: the attacker staggers
  open, you take nothing and gain power. Parrying a thrown weapon sends it
  back at the thrower, faster.
- **Power meter** fills as you deal (and take) damage; when it's full, POWER:
  Rage (double damage 5 s), Shockwave Stomp (everyone within 5 m flies),
  Blink (teleport 8 m, never off the edge), Iron Skin (70% less damage, no
  knockdowns 4 s), Bullet Time (everyone else at half speed 3 s), Second Wind
  (heal 50%, and it gets you up off the floor). Pick yours in match setup;
  bots get one each.
- **Map pickups** on 6 spots: health, speed boots, double damage, shield
  bubble, power battery.
- Bots block, parry, use their powers and go for health when hurt.
- New Blender moves: block (sword and fists), parries, stagger, stomp, roar, blink.
- HUD: power meter and active effects; touch BLOCK and POWER buttons.

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
