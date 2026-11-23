class_name WeaponSkills
extends RefCounted
## Weapon powers (SKILL). Every weapon has its own power on a cooldown: the
## weapon glows in the power's colour when it's ready. Powers are built from
## a few effect kinds (a flying wave, a dash, a teleport, a pull, an area
## blast, a leaping slam, a spin, a storm, a volley, a rain from the sky,
## phantom throws, a barrier, a buff); the table below gives each weapon its
## own mix, name and numbers. Everything runs on the match's authority (the
## host online); what others must see goes out as events.
##   anim: the move played; at: seconds into it when the power fires.
##   range: how close a target must be before a bot uses it.

const INFO := {
	# Blades -------------------------------------------------------------------
	&"sky_cleaver": {"name": "Sky Cleaver", "anim": &"Slash_C", "at": 0.12, "cd": 6.0, "color": Color(0.55, 0.85, 1.0),
		"range": 14.0, "kind": "bolt", "style": &"crescent", "speed": 26.0, "dmg": 20.0},
	&"flash_step": {"name": "Flash Step", "anim": &"Spear_Lunge", "at": 0.1, "cd": 6.0, "color": Color(0.85, 0.9, 1.0),
		"range": 8.0, "kind": "dash", "dist": 8.0, "dmg": 18.0, "knock": 7.0},
	&"shadow_step": {"name": "Shadow Step", "anim": &"Stab_C", "at": 0.05, "cd": 7.0, "color": Color(0.55, 0.3, 0.85),
		"range": 11.0, "kind": "teleport", "dmg": 14.0},
	&"needle_storm": {"name": "Needle Storm", "anim": &"Thrust_B", "at": 0.05, "cd": 6.0, "color": Color(1.0, 0.85, 0.4),
		"range": 3.0, "kind": "flurry", "ticks": 6, "dmg": 6.0, "reach": 2.9},
	&"axe_volley": {"name": "Axe Volley", "anim": &"Throw", "at": 0.2, "cd": 7.0, "color": Color(1.0, 0.55, 0.3),
		"range": 13.0, "kind": "phantom", "weapon": &"hand_axe", "count": 3, "spread": 16.0},
	&"plasma_nova": {"name": "Plasma Nova", "anim": &"Cast_Ground", "at": 0.32, "cd": 8.0, "color": Color(0.35, 0.95, 1.0),
		"range": 4.5, "kind": "area", "radius": 5.0, "dmg": 22.0, "knock": 9.0, "heavy": true, "ignite": true},
	&"pan_slam": {"name": "Pan Slam", "anim": &"Smash_B", "at": 0.25, "cd": 5.0, "color": Color(1.0, 0.95, 0.6),
		"range": 2.8, "kind": "smack", "dmg": 16.0, "sound": &"clang"},
	&"mega_squawk": {"name": "Mega Squawk", "anim": &"Cast_Forward", "at": 0.3, "cd": 7.0, "color": Color(1.0, 0.85, 0.2),
		"range": 5.0, "kind": "area", "radius": 6.0, "dmg": 5.0, "knock": 13.0, "sound": &"squeak"},
	&"overclock": {"name": "Overclock", "anim": &"Cast_Buff", "at": 0.36, "cd": 12.0, "color": Color(1.0, 0.5, 0.2),
		"range": 4.0, "kind": "buff", "effect": &"overclock", "time": 5.0},
	&"meteor_swing": {"name": "Meteor Swing", "anim": &"Smash_Release", "at": 0.05, "cd": 8.0, "color": Color(1.0, 0.45, 0.2),
		"range": 6.0, "kind": "leap", "fwd": 7.0, "up": 8.0, "radius": 3.6, "dmg": 24.0, "ignite": true},
	&"whirlwind": {"name": "Whirlwind", "anim": &"Heavy_Release", "at": 0.05, "cd": 7.0, "color": Color(0.9, 0.9, 0.95),
		"range": 2.5, "kind": "spin", "ticks": 5, "radius": 2.6, "dmg": 7.0},
	&"updraft": {"name": "Updraft", "anim": &"Power_Stomp_Sword", "at": 0.2, "cd": 8.0, "color": Color(0.4, 0.75, 1.0),
		"range": 3.0, "kind": "self_launch", "up": 13.0, "radius": 3.2, "dmg": 4.0, "knock": 8.0},
	&"brain_freeze": {"name": "Brain Freeze", "anim": &"Cast_Ground", "at": 0.32, "cd": 9.0, "color": Color(0.6, 0.95, 1.0),
		"range": 5.0, "kind": "area", "radius": 6.0, "dmg": 6.0, "knock": 3.0, "effect": &"chill", "time": 3.0, "fx": "frost"},
	# Heavy ----------------------------------------------------------------------
	&"earthshaker": {"name": "Earthshaker", "anim": &"Smash_Release", "at": 0.05, "cd": 8.0, "color": Color(1.0, 0.75, 0.3),
		"range": 5.0, "kind": "leap", "fwd": 3.0, "up": 10.0, "radius": 4.6, "dmg": 26.0},
	&"cyclone_cleave": {"name": "Cyclone Cleave", "anim": &"Heavy_Release", "at": 0.05, "cd": 8.0, "color": Color(1.0, 0.4, 0.3),
		"range": 2.8, "kind": "spin", "ticks": 4, "radius": 2.9, "dmg": 10.0},
	&"rockslide": {"name": "Rockslide", "anim": &"Cast_Sky", "at": 0.34, "cd": 9.0, "color": Color(0.75, 0.6, 0.45),
		"range": 14.0, "kind": "rain", "style": &"rock", "count": 4, "dmg": 18.0, "spread": 2.0},
	&"undertow": {"name": "Undertow", "anim": &"Cast_Pull", "at": 0.22, "cd": 10.0, "color": Color(0.2, 0.55, 0.9),
		"range": 8.0, "kind": "pull", "radius": 8.5, "strength": 15.0, "dmg": 10.0, "then_blast": 4.0},
	&"sugar_rush": {"name": "Sugar Rush", "anim": &"Cast_Buff", "at": 0.36, "cd": 14.0, "color": Color(1.0, 0.5, 0.8),
		"range": 99.0, "kind": "buff", "effect": &"speed", "time": 6.0, "heal": 25.0},
	&"dirt_kick": {"name": "Dirt Kick", "anim": &"Smash_A", "at": 0.25, "cd": 6.0, "color": Color(0.7, 0.55, 0.35),
		"range": 5.0, "kind": "cone", "reach": 6.0, "dmg": 8.0, "knock": 5.0, "effect": &"chill", "time": 2.0, "fx": "dust"},
	&"power_chord": {"name": "Power Chord", "anim": &"Smash_B", "at": 0.25, "cd": 8.0, "color": Color(0.8, 0.35, 1.0),
		"range": 5.0, "kind": "area", "radius": 6.0, "dmg": 12.0, "knock": 9.0, "up": 7.0, "sound": &"strum"},
	# Polearms -------------------------------------------------------------------
	&"skewer": {"name": "Skewer Charge", "anim": &"Spear_Lunge", "at": 0.1, "cd": 7.0, "color": Color(1.0, 0.8, 0.5),
		"range": 9.0, "kind": "dash", "dist": 9.0, "dmg": 24.0, "knock": 9.0},
	&"pole_vault": {"name": "Pole Vault", "anim": &"Spear_Sweep", "at": 0.05, "cd": 7.0, "color": Color(0.9, 0.75, 0.4),
		"range": 10.0, "kind": "leap", "fwd": 12.0, "up": 10.0, "radius": 3.0, "dmg": 16.0},
	&"tidal_surge": {"name": "Tidal Surge", "anim": &"Spear_Thrust_B", "at": 0.12, "cd": 8.0, "color": Color(0.2, 0.6, 1.0),
		"range": 12.0, "kind": "bolt", "style": &"wave", "speed": 16.0, "dmg": 14.0},
	&"grim_harvest": {"name": "Grim Harvest", "anim": &"Spear_Sweep", "at": 0.2, "cd": 9.0, "color": Color(0.5, 0.9, 0.5),
		"range": 7.0, "kind": "pull", "radius": 7.0, "strength": 13.0, "dmg": 14.0},
	&"joust": {"name": "Joust", "anim": &"Spear_Lunge", "at": 0.1, "cd": 8.0, "color": Color(0.4, 0.6, 1.0),
		"range": 12.0, "kind": "dash", "dist": 12.0, "dmg": 22.0, "knock": 12.0, "heavy": true},
	# Fists ----------------------------------------------------------------------
	&"haymaker": {"name": "Haymaker", "anim": &"Cross", "at": 0.12, "cd": 6.0, "color": Color(1.0, 0.7, 0.4),
		"range": 2.4, "kind": "uppercut", "dmg": 12.0},
	&"uppercut": {"name": "Uppercut", "anim": &"Cross", "at": 0.12, "cd": 6.0, "color": Color(1.0, 0.3, 0.25),
		"range": 2.6, "kind": "uppercut", "dmg": 16.0},
	&"gravity_smash": {"name": "Gravity Smash", "anim": &"Power_Stomp", "at": 0.3, "cd": 10.0, "color": Color(1.0, 0.6, 0.15),
		"range": 6.0, "kind": "pull", "radius": 6.5, "strength": 12.0, "dmg": 4.0, "then_blast": 4.2, "blast_dmg": 26.0},
	&"bulwark": {"name": "Bulwark", "anim": &"Block_Fists", "at": 0.05, "cd": 10.0, "color": Color(0.45, 0.7, 1.0),
		"range": 12.0, "kind": "buff", "effect": &"bulwark", "time": 3.0},
	# Thrown ---------------------------------------------------------------------
	&"star_fan": {"name": "Star Fan", "anim": &"Toss", "at": 0.16, "cd": 6.0, "color": Color(0.85, 0.9, 1.0),
		"range": 13.0, "kind": "phantom", "weapon": &"shuriken", "count": 5, "spread": 12.0},
	&"knife_storm": {"name": "Knife Storm", "anim": &"Cast_Forward", "at": 0.3, "cd": 8.0, "color": Color(0.9, 0.3, 0.3),
		"range": 6.0, "kind": "phantom", "weapon": &"throwing_knives", "count": 8, "spread": 45.0},
	&"kunai_warp": {"name": "Kunai Warp", "anim": &"Toss", "at": 0.16, "cd": 7.0, "color": Color(0.6, 0.35, 0.9),
		"range": 14.0, "kind": "phantom", "weapon": &"kunai", "count": 1, "spread": 0.0, "warp": true},
	&"cluster_bomb": {"name": "Cluster Bomb", "anim": &"Bomb_Lob", "at": 0.28, "cd": 9.0, "color": Color(1.0, 0.5, 0.2),
		"range": 12.0, "kind": "phantom", "weapon": &"bomb", "count": 3, "spread": 30.0},
	&"snowstorm": {"name": "Snowstorm", "anim": &"Toss", "at": 0.16, "cd": 8.0, "color": Color(0.8, 0.95, 1.0),
		"range": 14.0, "kind": "rain", "style": &"snow", "count": 7, "dmg": 6.0, "spread": 3.0},
	&"saw_storm": {"name": "Saw Storm", "anim": &"Cast_Forward", "at": 0.3, "cd": 9.0, "color": Color(0.9, 0.9, 0.95),
		"range": 7.0, "kind": "phantom", "weapon": &"saw_blade", "count": 4, "spread": 90.0},
	&"storm_call": {"name": "Storm Call", "anim": &"Cast_Sky", "at": 0.34, "cd": 10.0, "color": Color(1.0, 0.95, 0.4),
		"range": 14.0, "kind": "storm", "count": 3, "reach": 15.0},
	&"twin_return": {"name": "Twin Return", "anim": &"Toss", "at": 0.16, "cd": 7.0, "color": Color(1.0, 0.65, 0.25),
		"range": 12.0, "kind": "phantom", "weapon": &"boomerang", "count": 2, "spread": 8.0},
	&"yoyo_snare": {"name": "Yo-yo Snare", "anim": &"Toss", "at": 0.16, "cd": 7.0, "color": Color(1.0, 0.3, 0.3),
		"range": 10.0, "kind": "snare", "reach": 10.0, "dmg": 8.0},
	&"fist_barrage": {"name": "Fist Barrage", "anim": &"Rocket_Punch", "at": 0.17, "cd": 8.0, "color": Color(1.0, 0.55, 0.15),
		"range": 12.0, "kind": "volley", "style": &"fist", "count": 4, "spread": 8.0, "speed": 28.0, "dmg": 9.0, "stagger": 0.1},
	# Ranged ---------------------------------------------------------------------
	&"scatter_shot": {"name": "Scatter Shot", "anim": &"Shoot", "at": 0.01, "cd": 6.0, "color": Color(0.5, 1.0, 0.6),
		"range": 9.0, "kind": "volley", "style": &"bolt", "count": 7, "spread": 36.0, "speed": 50.0, "dmg": 7.0},
	&"overdrive": {"name": "Overdrive", "anim": &"Cast_Buff", "at": 0.36, "cd": 12.0, "color": Color(1.0, 0.35, 0.75),
		"range": 16.0, "kind": "buff", "effect": &"overdrive", "time": 3.5},
	&"big_rock": {"name": "Big Rock", "anim": &"Shoot", "at": 0.01, "cd": 6.0, "color": Color(0.6, 0.55, 0.5),
		"range": 14.0, "kind": "volley", "style": &"boulder", "count": 1, "spread": 0.0, "speed": 24.0, "dmg": 22.0},
	&"rocket_jump": {"name": "Rocket Jump", "anim": &"Power_Stomp_Sword", "at": 0.2, "cd": 8.0, "color": Color(1.0, 0.45, 0.15),
		"range": 3.5, "kind": "self_launch", "up": 16.0, "radius": 3.6, "dmg": 22.0, "knock": 10.0, "boom": true},
	&"rail_shot": {"name": "Rail Shot", "anim": &"Shoot", "at": 0.01, "cd": 8.0, "color": Color(0.3, 0.8, 1.0),
		"range": 30.0, "kind": "volley", "style": &"rail", "count": 1, "spread": 0.0, "speed": 160.0, "dmg": 38.0},
	&"starfall": {"name": "Starfall", "anim": &"Cast_Sky", "at": 0.34, "cd": 9.0, "color": Color(0.8, 0.6, 1.0),
		"range": 16.0, "kind": "rain", "style": &"orb", "count": 5, "dmg": 8.0, "spread": 4.0},
	&"reel_slam": {"name": "Reel Slam", "anim": &"Shoot", "at": 0.01, "cd": 8.0, "color": Color(0.6, 0.65, 0.8),
		"range": 12.0, "kind": "pull", "radius": 12.0, "strength": 17.0, "dmg": 6.0, "cone": 0.5},
	&"cyclone": {"name": "Cyclone", "anim": &"Shoot", "at": 0.01, "cd": 9.0, "color": Color(0.85, 0.95, 1.0),
		"range": 12.0, "kind": "bolt", "style": &"tornado", "speed": 7.0, "dmg": 8.0},
	&"arrow_rain": {"name": "Arrow Rain", "anim": &"Bow_Release", "at": 0.05, "cd": 9.0, "color": Color(1.0, 0.9, 0.6),
		"range": 18.0, "kind": "rain", "style": &"arrow", "count": 9, "dmg": 10.0, "spread": 3.0},
}


## What each power does, for the Armory card.
const DESC := {
	&"sky_cleaver": "Swing a glowing crescent that flies across the arena.",
	&"flash_step": "Dash forward in a blink, cutting everyone in the way.",
	&"shadow_step": "Vanish and reappear behind the nearest enemy, blade first.",
	&"needle_storm": "A blur of rapid stabs at whoever is in front of you.",
	&"axe_volley": "Throw three ghost axes in a fan. You keep your own.",
	&"plasma_nova": "Slam down a ring of plasma that burns and throws people back.",
	&"pan_slam": "One enormous clang that flattens the target.",
	&"mega_squawk": "A squawk so loud it blows everyone away from you.",
	&"overclock": "Swing faster and hit harder for a few seconds.",
	&"meteor_swing": "Leap at the nearest enemy and land in a burst of fire.",
	&"whirlwind": "Spin on the spot, slicing everything around you.",
	&"updraft": "A gust launches you skyward and knocks nearby fighters aside.",
	&"brain_freeze": "A blast of frost that slows everyone close to you.",
	&"earthshaker": "Jump high and crash down with a shockwave.",
	&"cyclone_cleave": "A heavy spinning cleave with a wide reach.",
	&"rockslide": "Call down falling rocks on your target.",
	&"undertow": "Drag enemies towards you, then blast them away.",
	&"sugar_rush": "Heal up and run faster for a few seconds.",
	&"dirt_kick": "Kick dirt in a cone: it stings and slows.",
	&"power_chord": "Strike a chord that bounces everyone near you into the air.",
	&"skewer": "Charge forward, spear first, through anyone in the way.",
	&"pole_vault": "Vault onto the nearest enemy and slam the ground.",
	&"tidal_surge": "Send a rolling wave along the ground.",
	&"grim_harvest": "Hook everyone nearby and reel them in.",
	&"joust": "A long armoured charge that sends people flying.",
	&"haymaker": "A rising punch that pops the target up.",
	&"uppercut": "A huge uppercut that launches the target.",
	&"gravity_smash": "Pull enemies in, then crush them with a blast.",
	&"bulwark": "Turn nearly every hit aside and reflect shots back.",
	&"star_fan": "Fling five ghost stars in a fan.",
	&"knife_storm": "Knives burst out from you in every direction.",
	&"kunai_warp": "Throw a ghost kunai and teleport to wherever it lands.",
	&"cluster_bomb": "Lob three extra bombs at once.",
	&"snowstorm": "A flurry of snowballs falls on your target and slows them.",
	&"saw_storm": "Four ghost saws spin out around you.",
	&"storm_call": "Lightning strikes the nearest enemies.",
	&"twin_return": "Throw two ghost boomerangs that come back around.",
	&"yoyo_snare": "Snag the target with your yo-yo and yank them close.",
	&"fist_barrage": "Fire a barrage of rocket fists.",
	&"scatter_shot": "A wide spray of bolts at close range.",
	&"overdrive": "Free shots for a few seconds: fire as fast as you like.",
	&"big_rock": "Launch one giant boulder.",
	&"rocket_jump": "Blast yourself into the air, hurting everyone below.",
	&"rail_shot": "A piercing rail shot that crosses the whole arena.",
	&"starfall": "Glowing orbs rain from the sky onto your target.",
	&"reel_slam": "Hook everyone in front of you and drag them in.",
	&"cyclone": "Release a tornado that wanders across the ground.",
	&"arrow_rain": "Arrows pour down on your target from above.",
}


static func info(id: StringName) -> Dictionary:
	return INFO.get(id, {})


static func describe(id: StringName) -> String:
	return str(DESC.get(id, ""))


## Runs the power `id` for `f` (on the authority).
static func perform(f: Fighter, id: StringName) -> void:
	var s := info(id)
	if s.is_empty() or f.world == null:
		return
	var m := f.world
	var col: Color = s["color"]
	f.count("skills")
	match str(s["kind"]):
		"bolt":
			var origin := f.global_position + Vector3.UP * (0.6 if s["style"] == &"wave" else 1.2) + f.forward() * 0.6
			m.spawn_bolt(f, origin, _aim(f, origin, float(s["speed"])), float(s["speed"]), _dmg(f, s), s["style"])
		"volley":
			var origin := f.socket_transform().origin
			var dir := _aim(f, origin, float(s["speed"]))
			var n := int(s["count"])
			for i in n:
				var a := 0.0 if n == 1 else lerpf(-float(s["spread"]), float(s["spread"]), float(i) / float(n - 1)) * 0.5
				var d := dir.rotated(Vector3.UP, deg_to_rad(a))
				var delay := float(s.get("stagger", 0.0)) * i
				if delay <= 0.0:
					m.spawn_bolt(f, origin, d, float(s["speed"]), _dmg(f, s), s["style"])
				else:
					m.get_tree().create_timer(delay).timeout.connect(func() -> void:
						if f.alive:
							m.spawn_bolt(f, f.socket_transform().origin, d, float(s["speed"]), _dmg(f, s), s["style"]))
		"phantom":
			var w := Registry.weapon(s["weapon"])
			var origin := f.socket_transform().origin
			var dir := _aim(f, origin, w.throw_speed)
			var n := int(s["count"])
			for i in n:
				var a := 0.0 if n == 1 else lerpf(-float(s["spread"]), float(s["spread"]), float(i) / float(n - 1))
				if float(s["spread"]) >= 90.0:
					a = 360.0 * float(i) / float(n)
				var p := m.spawn_projectile(f, w, origin, dir.rotated(Vector3.UP, deg_to_rad(a)), w.throw_speed, false, 1)
				p.phantom = true
				p.warp = bool(s.get("warp", false))
		"rain":
			var centre := _target_spot(f, float(s["range"]))
			var n := int(s["count"])
			for i in n:
				# A third land right on them, the rest around.
				var r := 0.35 if i < maxi(n / 3, 1) else float(s["spread"]) * sqrt(randf())
				var ang := randf() * TAU
				var off := Vector3(cos(ang), 0, sin(ang)) * r
				var from := centre + off + Vector3.UP * (12.0 + randf() * 3.0)
				var delay := 0.08 * i
				m.get_tree().create_timer(delay).timeout.connect(func() -> void:
					m.spawn_bolt(f, from, Vector3(randf_range(-0.05, 0.05), -1, randf_range(-0.05, 0.05)), 22.0, _dmg(f, s), s["style"]))
		"dash":
			_dash(f, s)
		"teleport":
			_teleport(f, s)
		"flurry":
			for i in int(s["ticks"]):
				m.get_tree().create_timer(0.08 * i).timeout.connect(func() -> void:
					if f.alive:
						_cone(f, float(s["reach"]), _dmg(f, s), 2.0, false, &"", 0.0)
						Audio.play(&"swing", f.global_position + Vector3.UP, -6.0, 1.5))
		"smack":
			var t := _front_target(f, float(s["range"]) + 0.4)
			if t:
				_hit(f, t, _dmg(f, s), (t.global_position - f.global_position).normalized(), true, 6.0)
			Audio.play(s.get("sound", &"hit_heavy"), f.global_position + Vector3.UP, 4.0)
		"area":
			_area(f, f.global_position + Vector3.UP * 0.5, float(s["radius"]), _dmg(f, s), float(s.get("knock", 6.0)),
				bool(s.get("heavy", false)), float(s.get("up", 0.0)), s.get("effect", &""), float(s.get("time", 0.0)))
			_ring(m, f.global_position, float(s["radius"]), col, str(s.get("fx", "shockwave")))
			if s.has("sound"):
				Audio.play(s["sound"], f.global_position + Vector3.UP, 6.0, 0.8)
				_net_sound(m, s["sound"], f.global_position, 6.0, 0.8)
			if bool(s.get("ignite", false)):
				m.arena.ignite(f.global_position, float(s["radius"]), f)
		"cone":
			_cone(f, float(s["reach"]), _dmg(f, s), float(s.get("knock", 5.0)), false, s.get("effect", &""), float(s.get("time", 0.0)))
			_fx(m, "dust", [f.global_position + f.forward() * 2.0, 1.4])
		"spin":
			for i in int(s["ticks"]):
				m.get_tree().create_timer(0.12 * i).timeout.connect(func() -> void:
					if f.alive:
						var last := i == int(s["ticks"]) - 1
						_area(f, f.global_position + Vector3.UP, float(s["radius"]), _dmg(f, s), 4.0 if not last else 9.0, last, 0.0, &"", 0.0)
						Audio.play(&"swing_heavy", f.global_position + Vector3.UP, -4.0, 1.2))
			_ring(m, f.global_position, float(s["radius"]), col, "shockwave")
		"leap":
			var t_air := 2.0 * float(s["up"]) / f.gravity
			var fwd := float(s["fwd"])
			var aim := _nearest_enemy(f, float(s["range"]) + 3.0, 0.3)
			if aim:
				# Land on them, not past them.
				var to := aim.global_position - f.global_position
				to.y = 0.0
				f.rotation.y = atan2(to.x, to.z)
				fwd = clampf(to.length() / t_air, 1.0, float(s["fwd"]) * 1.4)
			f.launch(f.forward() * fwd + Vector3.UP * float(s["up"]), 2.0)
			m.get_tree().create_timer(t_air).timeout.connect(func() -> void:
				if f.alive:
					_area(f, f.global_position + Vector3.UP * 0.5, float(s["radius"]), _dmg(f, s), 8.0, true, 0.0, &"", 0.0)
					_ring(m, f.global_position, float(s["radius"]), col, "shockwave")
					_fx(m, "dust", [f.global_position, 1.8])
					Audio.play(&"hit_heavy", f.global_position, 6.0, 0.6)
					_net_sound(m, &"hit_heavy", f.global_position, 6.0, 0.6)
					if bool(s.get("ignite", false)):
						m.arena.ignite(f.global_position, float(s["radius"]), f)
					if f.is_player:
						m.camera.shake(0.5))
		"self_launch":
			if bool(s.get("boom", false)):
				Fx.explosion(m, f.global_position, float(s["radius"]))
				Audio.play(&"boom", f.global_position, 2.0)
				if m.net:
					m.net.event("boom", [f.global_position, float(s["radius"])])
			else:
				_ring(m, f.global_position, float(s["radius"]), col, "gust")
			_area(f, f.global_position + Vector3.UP * 0.5, float(s["radius"]), _dmg(f, s), float(s.get("knock", 8.0)), bool(s.get("boom", false)), 6.0, &"", 0.0)
			f.launch(f.forward() * 2.0 + Vector3.UP * float(s["up"]), 0.3)
		"pull":
			_pull(f, float(s["radius"]), float(s["strength"]), _dmg(f, s), float(s.get("cone", -2.0)))
			_ring(m, f.global_position, float(s["radius"]), col, "shockwave")
			Audio.play(&"clunk", f.global_position + Vector3.UP, 2.0, 0.7)
			if s.has("then_blast"):
				m.get_tree().create_timer(0.45).timeout.connect(func() -> void:
					if f.alive:
						_area(f, f.global_position + Vector3.UP * 0.5, float(s["then_blast"]), float(s.get("blast_dmg", 16.0)) * f.powers.damage_dealt_mult(),
							10.0, true, 4.0, &"", 0.0)
						_ring(m, f.global_position, float(s["then_blast"]), col, "shockwave")
						Audio.play(&"hit_heavy", f.global_position, 6.0, 0.5)
						_net_sound(m, &"hit_heavy", f.global_position, 6.0, 0.5))
		"snare":
			var t := _nearest_enemy(f, float(s["reach"]), 0.2)
			if t:
				var pull := f.global_position - t.global_position
				pull.y = 0.0
				_hit(f, t, _dmg(f, s), pull.normalized(), false, 0.5)
				t.velocity = pull.normalized() * minf(pull.length() * 2.3, 17.0) + Vector3.UP * 5.0
		"uppercut":
			var t := _front_target(f, float(s["range"]) + 0.4)
			if t:
				var dir := (t.global_position - f.global_position)
				dir.y = 0.0
				_hit(f, t, _dmg(f, s), (dir.normalized() * 0.5 + Vector3.UP * 1.6).normalized(), true, 9.0)
			Audio.play(&"hit_heavy", f.global_position + Vector3.UP, 4.0, 1.2)
		"storm":
			var targets := _enemies_by_distance(f, float(s["reach"]))
			for i in mini(int(s["count"]), targets.size()):
				var t: Fighter = targets[i]
				m.get_tree().create_timer(0.18 * i).timeout.connect(func() -> void:
					if is_instance_valid(t) and t.alive:
						m.lightning(t.global_position + Vector3.UP * 0.2, f, 2.4))
		"buff":
			f.powers.add_effect(s["effect"], float(s["time"]))
			if s.has("heal"):
				f.health = minf(f.health + float(s["heal"]), f.max_health)
			_ring(m, f.global_position, 2.0, col, "burst")
			Audio.play(&"respawn", f.global_position + Vector3.UP, 0.0, 1.5)


# ---------------------------------------------------------------- helpers

static func _dmg(f: Fighter, s: Dictionary) -> float:
	return float(s.get("dmg", 10.0)) * f.powers.damage_dealt_mult()


static func _aim(f: Fighter, origin: Vector3, speed: float) -> Vector3:
	var t := f.locked_target()
	if t == null:
		t = _nearest_enemy(f, 30.0, 0.5)
	if t:
		var to := t.global_position + Vector3.UP * 1.1 - origin
		to += t.velocity * (to.length() / maxf(speed, 1.0)) * 0.5
		return to.normalized()
	return f.forward()


static func _target_spot(f: Fighter, reach: float) -> Vector3:
	var t := f.locked_target()
	if t == null:
		t = _nearest_enemy(f, reach, 0.0)
	return t.global_position if t else f.global_position + f.forward() * 9.0


static func _nearest_enemy(f: Fighter, reach: float, min_dot: float) -> Fighter:
	var best: Fighter
	var best_d := reach
	for o in f.world.fighters:
		if o == f or not o.alive or o.protect > 0.0:
			continue
		var to := o.global_position - f.global_position
		var d := to.length()
		if d < best_d and (min_dot <= -1.0 or f.forward().dot(Vector3(to.x, 0, to.z).normalized()) >= min_dot):
			best_d = d
			best = o
	return best


static func _enemies_by_distance(f: Fighter, reach: float) -> Array:
	var out: Array = []
	for o in f.world.fighters:
		if o != f and o.alive and o.protect <= 0.0 and o.global_position.distance_to(f.global_position) <= reach:
			out.append(o)
	out.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.global_position.distance_to(f.global_position) < b.global_position.distance_to(f.global_position))
	return out


static func _front_target(f: Fighter, reach: float) -> Fighter:
	return _nearest_enemy(f, reach, 0.35)


static func _hit(f: Fighter, v: Fighter, dmg: float, dir: Vector3, heavy: bool, knock: float, up: float = 0.0) -> float:
	var dealt := v.take_hit(dmg, dir, f, heavy, v.global_position + Vector3.UP, knock)
	if up > 0.0 and v.alive and v.state != Fighter.State.DOWN and not v.swimming:
		v.velocity.y = maxf(v.velocity.y, up)
	if dealt > 0.0:
		f.powers.dealt(dealt)
		f.hit_landed.emit(f, v, dealt)
	return dealt


static func _area(f: Fighter, centre: Vector3, radius: float, dmg: float, knock: float, heavy: bool, up: float,
		effect: StringName, time: float) -> void:
	for o in f.world.fighters:
		if o == f or not o.alive:
			continue
		var to := o.global_position + Vector3.UP - centre
		if to.length() > radius:
			continue
		var k := 1.0 - to.length() / radius * 0.5
		var dir := Vector3(to.x, 0, to.z).normalized()
		if dir.length() < 0.1:
			dir = f.forward()
		if _hit(f, o, dmg * k, dir, heavy, knock * k, up) > 0.0 and effect != &"":
			o.powers.add_effect(effect, time)
	for piece in f.world.arena.breakables:
		if not piece.is_broken and piece.global_position.distance_to(centre) < radius:
			piece.hit(dmg, piece.global_position, (piece.global_position - centre).normalized() * 4.0, f)


static func _cone(f: Fighter, reach: float, dmg: float, knock: float, heavy: bool, effect: StringName, time: float) -> void:
	for o in f.world.fighters:
		if o == f or not o.alive:
			continue
		var to := o.global_position - f.global_position
		to.y = 0.0
		if to.length() > reach or f.forward().dot(to.normalized()) < 0.55:
			continue
		if _hit(f, o, dmg, to.normalized(), heavy, knock) > 0.0 and effect != &"":
			o.powers.add_effect(effect, time)


static func _pull(f: Fighter, radius: float, strength: float, dmg: float, cone: float) -> void:
	for o in f.world.fighters:
		if o == f or not o.alive:
			continue
		var to := f.global_position - o.global_position
		to.y = 0.0
		var d := to.length()
		if d > radius or d < 0.8:
			continue
		if cone > -1.5 and f.forward().dot(-to.normalized()) < cone:
			continue
		_hit(f, o, dmg, to.normalized(), false, 0.5)
		if o.alive and o.state != Fighter.State.DOWN:
			o.velocity = to.normalized() * minf(d * 2.0, strength) + Vector3.UP * 4.0


## A blink-fast dash along the ground: everyone near the path is hit.
static func _dash(f: Fighter, s: Dictionary) -> void:
	var t := _nearest_enemy(f, float(s["dist"]) + 2.0, 0.3)
	if t:
		var to := t.global_position - f.global_position
		f.rotation.y = atan2(to.x, to.z)
	var dir := f.forward()
	var start := f.global_position
	var end := start + dir * float(s["dist"])
	var q := PhysicsRayQueryParameters3D.create(start + Vector3.UP, end + Vector3.UP, Game.L_WORLD)
	var hit := f.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		end = (hit["position"] as Vector3) - dir * 0.6 - Vector3.UP
	end.y = start.y
	for o in f.world.fighters:
		if o == f or not o.alive:
			continue
		if Geo.segment_distance(start + Vector3.UP, end + Vector3.UP, o.global_position + Vector3.UP * 0.4,
				o.global_position + Vector3.UP * 1.6) < 1.3:
			_hit(f, o, _dmg(f, s), dir, bool(s.get("heavy", false)), float(s.get("knock", 7.0)))
	for i in 5:
		_fx(f.world, "burst", [start.lerp(end, float(i) / 4.0) + Vector3.UP, s["color"]])
	f.global_position = end
	f.invuln = maxf(f.invuln, 0.25)
	Audio.play(&"swing_heavy", end + Vector3.UP, 2.0, 1.4)
	_net_sound(f.world, &"swing_heavy", end, 2.0, 1.4)


## Appear behind the nearest enemy and strike.
static func _teleport(f: Fighter, s: Dictionary) -> void:
	var t := _nearest_enemy(f, float(s["range"]), -2.0)
	if t == null:
		return
	var behind := t.global_position - t.forward() * 1.2
	var q := PhysicsRayQueryParameters3D.create(behind + Vector3.UP * 1.5, behind + Vector3.DOWN * 2.0, Game.L_WORLD)
	var ground := f.get_world_3d().direct_space_state.intersect_ray(q)
	if ground.is_empty():
		behind = t.global_position + (f.global_position - t.global_position).normalized() * 1.2
	else:
		behind = (ground["position"] as Vector3) + Vector3.UP * 0.05
	_fx(f.world, "burst", [f.global_position + Vector3.UP, s["color"]])
	f.global_position = behind
	var to := t.global_position - behind
	f.rotation.y = atan2(to.x, to.z)
	_fx(f.world, "burst", [behind + Vector3.UP, s["color"]])
	_hit(f, t, _dmg(f, s), to.normalized(), false, 4.0)
	Audio.play(&"swing", behind + Vector3.UP, 2.0, 1.6)


## A coloured ring on every phone (shockwave, frost, gust, burst, dust).
static func _ring(m: Match, at: Vector3, radius: float, color: Color, kind: String) -> void:
	ring_local(m, at, radius, color, kind)
	if m.net:
		m.net.event("fx", ["ring", at, radius, color, kind])


static func ring_local(m: Match, at: Vector3, radius: float, color: Color, kind: String) -> void:
	match kind:
		"frost":
			Fx.shockwave(m, at, radius, Color(0.7, 0.95, 1.0))
			Fx.sparks(m, at + Vector3.UP, Color(0.85, 0.97, 1.0), 30)
		"gust":
			Fx.shockwave(m, at, radius, color)
			Fx.dust(m, at, 1.4)
		"burst":
			Fx.burst(m, at + Vector3.UP, color)
		"dust":
			Fx.dust(m, at, radius * 0.4)
		_:
			Fx.shockwave(m, at, radius, color)


static func _fx(m: Match, kind: String, args: Array) -> void:
	match kind:
		"dust":
			Fx.dust(m, args[0], float(args[1]))
		"burst":
			Fx.burst(m, args[0], args[1])
	if m.net:
		m.net.event("fx", [kind] + args)


static func _net_sound(m: Match, sound: StringName, at: Vector3, db: float, pitch: float) -> void:
	if m.net:
		m.net.event("sound", [String(sound), at, db, pitch])
