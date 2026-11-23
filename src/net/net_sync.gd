class_name NetSync
extends Node
## A networked match's traffic (doc: Multiplayer).
##   Host: reads each joiner's input packets into their fighter, sends a
##   snapshot of everything ~30 times a second, and forwards events (hits,
##   deaths, blasts, notices) so every phone shows the same fight.
##   Joiner: every fighter is a puppet. Others are drawn ~100 ms in the past,
##   smoothly between snapshots; your own at the newest state (so it answers
##   your thumb quickly). Weapons in flight, pickups, broken scenery and the
##   arena's moving parts are mirrored; events become effects and kill feed.
##   Death and knockdown ragdolls run on each phone from the same impulse.

const SEND_EVERY := 2              # physics frames per snapshot / input packet (30 Hz)
const INTERP_DELAY := 0.1
const ACTIONS: Array[StringName] = [&"jump", &"throw", &"dodge", &"power", &"swap", &"skill"]
const STATE_DOWN := 8              # Fighter.State.DOWN, DEAD below
const STATE_DEAD := 10

var m: Match
var host := false
var _frame := 0
var _clock := 0.0

# Host side.
var _inputs: Dictionary = {}        # peer -> {"counts": PackedInt32Array, "taps": int, "hold": int, "seq": int}
var _peer_fighter: Dictionary = {}  # peer -> Fighter

# Joiner side.
var _snaps: Array = []              # newest last: {"t", "recv", "f": {id: Array}}
var _offset := INF                  # local clock - host clock (smallest seen)
var _counts := PackedInt32Array([0, 0, 0, 0, 0, 0])
var _taps := 0
var _was_attack := false
var _seq := 0
var _replicas: Dictionary = {}      # key -> Node3D
var _seen: Dictionary = {}
var _ragdolled: Dictionary = {}     # fighter id -> true while its ragdoll runs here
var _broken := PackedByteArray()
var stats := {"snapshots": 0, "bytes": 0, "inputs": 0, "events": 0}


func setup(match_node: Match) -> void:
	m = match_node
	host = Net.is_host
	name = "NetSync"
	Net.sync = self
	if host:
		for f in m.fighters:
			var peer := int(f.get_meta("peer", 0))
			if peer > 1:
				_peer_fighter[peer] = f
				_inputs[peer] = {"counts": PackedInt32Array([0, 0, 0, 0, 0, 0]), "taps": 0, "hold": 0, "seq": -1}
		m.arena.notice.connect(func(text: String, color: Color, sub: String) -> void: event("notice", [text, color, sub]))


## The host says go: everyone counts down together.
func start_countdown() -> void:
	m.countdown()


func _physics_process(delta: float) -> void:
	_clock += delta
	_frame += 1
	if host:
		_apply_inputs()
		if _frame % SEND_EVERY == 0 and m.started:
			var bytes := _snapshot()
			stats["bytes"] = bytes.size()
			Net.send_snapshot(bytes)
	else:
		_collect_input()
		if _frame % SEND_EVERY == 0:
			Net.send_input(_input_packet())
		_show(delta)


# ================================================================== host

func _apply_inputs() -> void:
	for peer: int in _inputs:
		var st: Dictionary = _inputs[peer]
		var f: Fighter = _peer_fighter.get(peer)
		if f == null:
			continue
		if int(st["hold"]) > 0:
			st["hold"] = int(st["hold"]) - 1
			f.input.attack_held = true


func receive_input(peer: int, bytes: PackedByteArray) -> void:
	var f: Fighter = _peer_fighter.get(peer)
	if f == null or not _inputs.has(peer):
		return
	var a: Variant = bytes_to_var(bytes)
	if not (a is Array) or (a as Array).size() < 9:
		return
	var p: Array = a
	var st: Dictionary = _inputs[peer]
	if int(p[0]) <= int(st["seq"]):
		return
	st["seq"] = int(p[0])
	stats["inputs"] += 1
	var inp := f.input
	inp.move = Vector2(float(p[1]), float(p[2])).limit_length(1.0)
	inp.aim_yaw = float(p[3])
	var flags := int(p[4])
	inp.sprint = flags & 1 != 0
	inp.attack_held = flags & 2 != 0
	inp.jump_held = flags & 4 != 0
	inp.block_held = flags & 8 != 0
	inp.face_view = flags & 16 != 0
	var tid := int(p[5])
	inp.target = m.fighter_by_id(tid) if tid >= 0 else null
	inp.aim_point = p[6] if p[6] is Vector3 else null
	var counts: PackedInt32Array = p[7]
	var old: PackedInt32Array = st["counts"]
	for i in mini(counts.size(), ACTIONS.size()):
		if counts[i] > old[i]:
			inp.press(ACTIONS[i])
	st["counts"] = counts
	var taps := int(p[8])
	if taps > int(st["taps"]) and not inp.attack_held:
		st["hold"] = 3                     # a tap shorter than a packet still lands
	st["taps"] = taps


## A joiner dropped out: a bot takes their fighter over.
func peer_left(peer: int, who: String) -> void:
	var f: Fighter = _peer_fighter.get(peer)
	_peer_fighter.erase(peer)
	_inputs.erase(peer)
	if f:
		f.input.clear()
		m.brains.append(AIBrain.new(f, m, m.config.difficulty))
		f.display_name = "%s (bot)" % f.display_name
		m.hud.refresh_board()
	event("notice", ["%s LEFT" % who.to_upper(), Color(1, 0.6, 0.4), "A bot takes over"])
	m.hud.callout("%s LEFT" % who.to_upper(), Color(1, 0.6, 0.4), "A bot takes over", 1.2)


func _snapshot() -> PackedByteArray:
	var fs: Array = []
	for f in m.fighters:
		var b := f.body
		var flags := (1 if f.protect > 0.0 else 0) | (2 if f.swimming else 0) | (4 if f.held() else 0) \
			| (8 if f.blocking else 0) | (16 if f.trail.active else 0) | (32 if b.action_upper else 0)
		fs.append([f.fighter_id, f.global_position.x, f.global_position.y, f.global_position.z, f.rotation.y,
			f.velocity.x, f.velocity.y, f.velocity.z, int(f.state), f.health, f.alive, b.loco, b.loco_speed,
			b.action, b.action_time, String(f.weapon_data.id) if f.weapon_data else "fists", f.ammo,
			f.powers.meter, flags, f.powers.effects.duplicate(), f.powers.shield, f.display_name, minf(f.skill_left(), 99.0)])
	var thrown: Array = []
	for p in m.projectiles:
		if is_instance_valid(p):
			var q := p.global_basis.get_rotation_quaternion()
			if p.get_child_count() > 0 and p.get_child(0) is Node3D:
				q = (p.get_child(0) as Node3D).global_basis.get_rotation_quaternion()
			thrown.append([p.get_instance_id(), String(p.data.id), p.global_position, q])
	var bolts: Array = []
	for c in m.get_children():
		if c is Bolt:
			var bo := c as Bolt
			bolts.append([bo.get_instance_id(), String(bo.style), bo.global_position, bo.velocity])
	var picks: Array = []
	for p in m.pickups:
		if is_instance_valid(p):
			picks.append([p.get_instance_id(), String(p.data.id), p.global_position])
	var ups: Array = []
	for p: Variant in m.powerups:
		ups.append(String((p as PowerUp).kind) if p != null and is_instance_valid(p) else "")
	var broken := PackedByteArray()
	var crates: Array = []
	for i in m.arena.breakables.size():
		var piece := m.arena.breakables[i]
		if i < m.arena.static_breakables:
			broken.append(1 if piece.is_broken else 0)
		elif not piece.is_broken:
			crates.append([piece.get_instance_id(), piece.size, piece.global_position, piece.color])
	var race := [m.race.time_left, m.race.overtime, m.race.finished, m.race.scores.duplicate()]
	var snap := [m.clock, race, fs, thrown, bolts, picks, ups, broken, crates, m.arena.net_state()]
	return var_to_bytes(snap).compress(FileAccess.COMPRESSION_DEFLATE)


## Host: something everyone should see happen.
func event(kind: String, data: Array) -> void:
	if host:
		Net.send_event(kind, data)


# ================================================================ joiner

func _collect_input() -> void:
	var inp := m.player.input
	for i in ACTIONS.size():
		if inp._presses.has(ACTIONS[i]):
			_counts[i] += 1
	inp._presses.clear()
	if inp.attack_held and not _was_attack:
		_taps += 1
	_was_attack = inp.attack_held


func _input_packet() -> PackedByteArray:
	var inp := m.player.input
	_seq += 1
	var flags := (1 if inp.sprint else 0) | (2 if inp.attack_held else 0) | (4 if inp.jump_held else 0) | (8 if inp.block_held else 0) \
		| (16 if inp.face_view else 0)
	var target := inp.target as Fighter
	return var_to_bytes([_seq, inp.move.x, inp.move.y, inp.aim_yaw, flags, target.fighter_id if target and is_instance_valid(target) else -1,
		inp.aim_point, _counts.duplicate(), _taps])


func receive_snapshot(bytes: PackedByteArray) -> void:
	var raw := bytes.decompress_dynamic(1 << 20, FileAccess.COMPRESSION_DEFLATE)
	var a: Variant = bytes_to_var(raw)
	if not (a is Array):
		return
	var s: Array = a
	stats["snapshots"] += 1
	stats["bytes"] = bytes.size()
	var t := float(s[0])
	if not _snaps.is_empty() and t <= float(_snaps[-1]["t"]):
		return
	_offset = minf(_offset, _clock - t) if _offset != INF else _clock - t
	_offset = lerpf(_offset, _clock - t, 0.01)       # drift slowly toward the latest
	var fmap := {}
	for rec: Array in s[2]:
		fmap[int(rec[0])] = rec
	_snaps.append({"t": t, "recv": _clock, "f": fmap})
	while _snaps.size() > 20:
		_snaps.pop_front()
	m.clock = t
	var race: Array = s[1]
	m.race.time_left = float(race[0])
	m.race.overtime = bool(race[1])
	m.race.finished = bool(race[2])
	var scores: Dictionary = race[3]
	if scores != m.race.scores:
		m.race.scores = scores
		m.hud.refresh_board()
	for rec: Array in s[2]:
		_apply_stats(rec)
	_mirror_thrown(s[3])
	_mirror_bolts(s[4])
	_mirror_pickups(s[5])
	_mirror_powerups(s[6])
	_mirror_broken(s[7])
	_mirror_crates(s[8])
	m.arena.apply_net_state(s[9])


## The non-moving parts of a fighter: health, weapon, power, effects.
func _apply_stats(rec: Array) -> void:
	var f := m.fighter_by_id(int(rec[0]))
	if f == null:
		return
	f.health = float(rec[9])
	var weapon := StringName(str(rec[15]))
	if f.weapon_data == null or f.weapon_data.id != weapon:
		f.equip(Registry.weapon(weapon), int(rec[16]))
	f.ammo = int(rec[16])
	f.powers.meter = float(rec[17])
	f.powers.effects = rec[19]
	f.powers.shield = float(rec[20])
	var flags := int(rec[18])
	f.protect = 0.5 if flags & 1 != 0 else 0.0
	f.swimming = flags & 2 != 0
	f.blocking = flags & 8 != 0
	f.trail.active = flags & 16 != 0
	f.state = int(rec[8]) as Fighter.State
	var alive := bool(rec[10])
	if alive and not f.alive:
		_respawned(f)
	f.alive = alive
	if rec.size() > 22:
		f.net_skill_left = float(rec[22])
	if str(rec[21]) != f.display_name:
		f.display_name = str(rec[21])
		m.hud.refresh_board()


func _respawned(f: Fighter) -> void:
	_ragdolled.erase(f.fighter_id)
	f.ragdoll.stop(0.0)
	f.collision_layer = Game.L_FIGHTERS
	Fx.burst(m, f.global_position + Vector3.UP, f.body.skin.trail)
	Audio.play(&"respawn", f.global_position + Vector3.UP, -4.0)
	if f == m.player:
		m.camera.yaw = f.rotation.y + PI
		m.camera.snap()
		m.hud.callout("BACK IN!", Color.WHITE, "2 s of protection", 0.6)


## Places and animates every puppet for this frame.
func _show(_delta: float) -> void:
	if _snaps.is_empty():
		return
	var host_now := _clock - _offset
	var newest: Dictionary = _snaps[-1]
	for f in m.fighters:
		var id := f.fighter_id
		var rec: Array = newest["f"].get(id, [])
		if rec.is_empty():
			continue
		var st := int(rec[8])
		var ragdoll := _ragdolled.has(id) and (st == STATE_DOWN or st == STATE_DEAD)
		if _ragdolled.has(id) and not ragdoll:
			# Getting up (or back in): hand the body back to the snapshots.
			_ragdolled.erase(id)
			f.ragdoll.stop(0.3)
			f.collision_layer = Game.L_FIGHTERS
		if ragdoll:
			f.puppet_follow_ragdoll()
			continue
		var pos: Vector3
		var yaw: float
		if f == m.player:
			# Our own fighter: the newest state, nudged on by its velocity.
			var age := minf(_clock - float(newest["recv"]), 0.12)
			pos = Vector3(rec[1], rec[2], rec[3]) + Vector3(rec[5], rec[6], rec[7]) * age
			yaw = float(rec[4])
		else:
			var pair := _bracket(host_now - INTERP_DELAY, id)
			if pair.is_empty():
				pos = Vector3(rec[1], rec[2], rec[3])
				yaw = float(rec[4])
			else:
				var a: Array = pair[0]
				var b: Array = pair[1]
				var u: float = pair[2]
				pos = Vector3(a[1], a[2], a[3]).lerp(Vector3(b[1], b[2], b[3]), u)
				yaw = lerp_angle(float(a[4]), float(b[4]), u)
		if f.global_position.distance_to(pos) > 6.0:
			f.global_position = pos            # a teleport (respawn, cannon): don't glide
		else:
			f.global_position = f.global_position.lerp(pos, 0.6)
		f.rotation.y = lerp_angle(f.rotation.y, yaw, 0.6)
		f.velocity = Vector3(rec[5], rec[6], rec[7])
		_animate(f, rec)


## The two snapshots either side of `t` for fighter `id`, and how far between.
func _bracket(t: float, id: int) -> Array:
	for i in range(_snaps.size() - 1, 0, -1):
		var b: Dictionary = _snaps[i]
		var a: Dictionary = _snaps[i - 1]
		if float(a["t"]) <= t and t <= float(b["t"]):
			if not a["f"].has(id) or not b["f"].has(id):
				return []
			var span := maxf(float(b["t"]) - float(a["t"]), 0.001)
			return [a["f"][id], b["f"][id], (t - float(a["t"])) / span]
	return []


func _animate(f: Fighter, rec: Array) -> void:
	var b := f.body
	var loco := StringName(str(rec[11]))
	if loco != &"":
		b.set_loco(loco, float(rec[12]))
	var action := StringName(str(rec[13]))
	var flags := int(rec[18])
	var was: StringName = _prev_action(f)
	if action != was:
		if action == &"":
			b.stop_action(0.15)
		else:
			b.play(action, flags & 32 != 0, 1.0, 0.05)
			if action.begins_with("Slash") or action.begins_with("Smash") or action.begins_with("Heavy_Release") \
					or action.begins_with("Spear") or action.begins_with("Stab") or action.begins_with("Thrust"):
				Audio.play(&"swing", f.global_position + Vector3.UP, -6.0, randf_range(0.9, 1.1))
			elif action in [&"Throw", &"Toss", &"Bomb_Lob", &"Rocket_Punch"]:
				Audio.play(&"throw", f.global_position + Vector3.UP, -4.0)
		f.set_meta("net_action", action)
	if action != &"":
		b.action_time = float(rec[14])
	b.set_guard(flags & 8 != 0, f.armed())


func _prev_action(f: Fighter) -> StringName:
	return f.get_meta("net_action", &"")


# --------------------------------------------------------------- mirrors

func _replica(key: String, make: Callable) -> Node3D:
	_seen[key] = true
	if not _replicas.has(key):
		var n: Node3D = make.call()
		m.add_child(n)
		_replicas[key] = n
	return _replicas[key]


func _sweep(prefix: String) -> void:
	for key: String in _replicas.keys():
		if key.begins_with(prefix) and not _seen.has(key):
			(_replicas[key] as Node).queue_free()
			_replicas.erase(key)
	for key: String in _seen.keys():
		if key.begins_with(prefix):
			_seen.erase(key)


static func _mesh_node(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return mi


func _mirror_thrown(list: Array) -> void:
	for rec: Array in list:
		var w := Registry.weapon(StringName(str(rec[1])))
		var n := _replica("t%d" % int(rec[0]), func() -> Node3D: return _mesh_node(w.mesh()))
		var was: Vector3 = n.get_meta("p", rec[2])
		n.set_meta("v", (Vector3(rec[2]) - was) / (SEND_EVERY / 60.0))
		n.set_meta("p", rec[2])
		n.global_position = rec[2]
		n.quaternion = rec[3]
	_sweep("t")


func _mirror_bolts(list: Array) -> void:
	for rec: Array in list:
		var style := StringName(str(rec[1]))
		var n := _replica("b%d" % int(rec[0]), func() -> Node3D:
			return _mesh_node(Bolt._mesh_for(style, Bolt.STYLES.get(style, Bolt.STYLES[&"bolt"])["color"])))
		var v: Vector3 = rec[3]
		n.global_position = rec[2]
		n.set_meta("v", v)
		if v.length() > 0.1:
			n.global_basis = Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
	_sweep("b")


func _mirror_pickups(list: Array) -> void:
	for rec: Array in list:
		var w := Registry.weapon(StringName(str(rec[1])))
		var n := _replica("k%d" % int(rec[0]), func() -> Node3D:
			var root := Node3D.new()
			root.set_meta("w", String(w.id))
			var mi := _mesh_node(w.mesh())
			mi.rotation_degrees = Vector3(0, 0, 70)
			root.add_child(mi)
			return root)
		n.global_position = rec[2]
		(n.get_child(0) as Node3D).rotation = Vector3(0, _clock * 2.2, 1.2)
	_sweep("k")


func _mirror_powerups(list: Array) -> void:
	for i in mini(list.size(), m.arena.pickup_points.size()):
		var kind := str(list[i])
		var key := "u%d" % i
		if kind == "":
			continue
		var cur: Node3D = _replicas.get(key)
		if cur and str(cur.get_meta("kind", "")) != kind:
			cur.queue_free()
			_replicas.erase(key)
		var p := _replica(key, func() -> Node3D:
			var n := PowerUp.new()
			n.set_meta("kind", kind)
			return n) as PowerUp
		if not p.has_meta("ready"):
			p.set_meta("ready", true)
			p.setup(StringName(kind), m.arena.pickup_points[i], i)
	_sweep("u")


## Mirrored things in flight: [[key, position, velocity]] (danger sense).
func flying() -> Array:
	var out: Array = []
	for key: String in _replicas:
		if key.begins_with("t") or key.begins_with("b"):
			var n := _replicas[key] as Node3D
			var v: Vector3 = n.get_meta("v", Vector3.ZERO)
			out.append([key, n.global_position, v])
	return out


## A mirrored weapon on the ground within `radius` (the SWAP button and
## the Armory lock hint), or null.
func pickup_near(pos: Vector3, radius: float) -> WeaponData:
	for key: String in _replicas:
		var n := _replicas[key] as Node3D
		if key.begins_with("k") and n.global_position.distance_to(pos + Vector3.UP * 0.6) < radius + 0.6:
			return Registry.weapon(StringName(str(n.get_meta("w", "sword"))))
	return null


func _mirror_broken(flags: PackedByteArray) -> void:
	for i in mini(flags.size(), m.arena.breakables.size()):
		var piece := m.arena.breakables[i]
		var want := flags[i] == 1
		if want and not piece.is_broken:
			piece.shatter()
		elif not want and piece.is_broken:
			piece.restore()


func _mirror_crates(list: Array) -> void:
	for rec: Array in list:
		var size: Vector3 = rec[1]
		var color: Color = rec[3]
		var n := _replica("c%d" % int(rec[0]), func() -> Node3D:
			var b := BoxBuilder.new()
			b.box(size, Vector3.ZERO, color)
			b.box(size + Vector3(0.02, -size.y * 0.8, 0.02), Vector3.ZERO, color.darkened(0.35))
			return _mesh_node(b.commit(BoxBuilder.vertex_color_material(0.8))))
		n.global_position = rec[2]
	for key: String in _replicas.keys():
		if key.begins_with("c") and not _seen.has(key):
			Fx.dust(m, (_replicas[key] as Node3D).global_position, 0.8)
			Audio.play(&"crash_wood", (_replicas[key] as Node3D).global_position, 0.0)
	_sweep("c")


# --------------------------------------------------------------- events

func receive_event(kind: String, d: Array) -> void:
	stats["events"] += 1
	match kind:
		"hit":
			var victim := m.fighter_by_id(int(d[0]))
			var attacker := m.fighter_by_id(int(d[1]))
			var at: Vector3 = d[3]
			var heavy := bool(d[4])
			Fx.sparks(m, at, Color(1.0, 0.85, 0.5), 18 if heavy else 12)
			Audio.play(&"hit_heavy" if heavy else &"hit", at, 0.0)
			if victim:
				victim.body.flash(0.8)
			m.hit_feel(victim, attacker, at, heavy)
		"down", "death":
			var f := m.fighter_by_id(int(d[0]))
			if f:
				var already := _ragdolled.has(f.fighter_id) and f.ragdoll.active
				_ragdolled[f.fighter_id] = true
				f.collision_layer = 0
				if not already or str(d[3]) != "":
					f.body.stop_action(0.0)
					f.ragdoll.start(d[2], d[1], StringName(str(d[3])) if str(d[3]) != "" else &"UpperChest")
				if kind == "death":
					Audio.play(&"death", f.global_position + Vector3.UP, 0.0)
					f.alive = false
		"kill":
			m.present_death(m.fighter_by_id(int(d[0])), m.fighter_by_id(int(d[1])), int(d[2]), str(d[3]))
		"boom":
			Fx.explosion(m, d[0], float(d[1]))
			Audio.play(&"boom", d[0], 2.0)
			m.camera.shake(clampf(1.2 - m.camera.global_position.distance_to(d[0]) / 25.0, 0.2, 1.0))
		"zap":
			Fx.lightning(m, d[0])
			Audio.play(&"zap", d[0], 4.0, 0.8)
		"gust":
			Fx.gust(m, d[0], d[1])
			Audio.play(&"swing_heavy", d[0], 0.0, 0.7)
		"sound":
			Audio.play(StringName(str(d[0])), d[1], float(d[2]), float(d[3]))
		"fx":
			match str(d[0]):
				"ring":
					WeaponSkills.ring_local(m, d[1], float(d[2]), d[3], str(d[4]))
				"sparks":
					Fx.sparks(m, d[1], d[2], int(d[3]))
				"dust":
					Fx.dust(m, d[1], float(d[2]))
				"splash":
					Fx.splash(m, d[1], float(d[2]))
				"burst":
					Fx.burst(m, d[1], d[2])
		"float":
			var f := m.fighter_by_id(int(d[0]))
			if f:
				m.callout_for(f, str(d[1]), d[2])
		"notice":
			m.hud.callout(str(d[0]), d[1], str(d[2]), 1.3)
		"shark":
			m.arena.call(&"_shark_show", d[0])
		"end":
			m.end_for_joiner(int(d[0]), d[1] if d.size() > 1 and d[1] is Dictionary else {})
