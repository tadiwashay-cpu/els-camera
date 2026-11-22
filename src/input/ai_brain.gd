class_name AIBrain
extends RefCounted
## A bot (doc: utility-scoring brain). Every 0.1 s it scores what to do:
## chase, attack, throw, grab a weapon or back off; then it "presses
## buttons" on its FighterInput like a player would. It paths with the
## arena's baked navigation mesh. Difficulty changes reaction time, aim
## and nerve, never what it can do.

const LEVELS := [
	{"reaction": 0.45, "catch": 0.15, "dodge": 0.1, "aggression": 0.45, "heavy": 0.1, "cadence": 0.62, "aim": 0.35, "block": 0.12, "parry": 0.05},
	{"reaction": 0.28, "catch": 0.45, "dodge": 0.22, "aggression": 0.65, "heavy": 0.2, "cadence": 0.42, "aim": 0.18, "block": 0.3, "parry": 0.2},
	{"reaction": 0.16, "catch": 0.75, "dodge": 0.35, "aggression": 0.85, "heavy": 0.3, "cadence": 0.3, "aim": 0.06, "block": 0.45, "parry": 0.45},
]

var me: Fighter
var world: Match
var level: Dictionary
var goal := "chase"
var target: Fighter

var _rng := RandomNumberGenerator.new()
var _think := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _repath := 0.0
var _attack_cd := 0.0
var _throw_cd := 2.0
var _hold := 0.0
var _release_next := false
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _decided_catch: Dictionary = {}       # projectile id -> bool
var _react := 0.0
var _pickup: WeaponPickup
var _barrel: Breakable
var _block_t := 0.0
var _guarded_attack := -1          # instance id + clip of the swing we decided on
var _powerup: PowerUp
var _arena_goal := Vector3.INF
## Sticks to an arena goal for a while once chosen (no dithering).
var _arena_goal_t := 0.0


func _init(fighter: Fighter, match_node: Match, difficulty: int) -> void:
	me = fighter
	world = match_node
	level = LEVELS[clampi(difficulty, 0, 2)]
	_rng.randomize()


func update(delta: float) -> void:
	var inp := me.input
	inp.sprint = false
	if me.state == Fighter.State.DOWN and me.powers.power == &"second_wind" and me.powers.ready_to_use():
		inp.press(&"power")
	_block_t -= delta
	inp.block_held = _block_t > 0.0
	if not me.alive or me.state == Fighter.State.FROZEN:
		inp.move = Vector2.ZERO
		inp.attack_held = false
		return
	if me.state == Fighter.State.HELD:
		# Caught by the crane: kick to get free.
		inp.move = Vector2.ZERO
		if _rng.randf() < delta * (1.0 + float(level["dodge"]) * 6.0):
			inp.press(&"jump")
		return
	if me.swimming:
		# In the sea: swim for the nearest ledge and kick up onto it.
		var exit := world.arena.swim_exit(me.global_position)
		var to := exit - me.global_position
		to.y = 0.0
		_steer(to, 1.0)
		inp.attack_held = false
		if to.length() < 1.8 or (me.is_on_wall() and _rng.randf() < delta * 5.0):
			inp.press(&"jump")
		return
	_attack_cd -= delta
	_throw_cd -= delta
	_strafe_t -= delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.1
		_decide()
	_handle_attack_button(delta)
	_react_to_incoming(delta)
	match goal:
		"pickup":
			if _pickup and is_instance_valid(_pickup):
				_go_to(_pickup.global_position, 1.0, delta)
			else:
				goal = "chase"
		"powerup":
			if _powerup and is_instance_valid(_powerup):
				_go_to(_powerup.global_position, 1.0, delta)
			else:
				goal = "chase"
		"chase":
			if target:
				_go_to(target.global_position, 1.0 if _dist() > 9.0 else 0.85, delta)
		"fight":
			_fight(delta)
		"throw":
			_face_and_stop()
			if me.state == Fighter.State.MOVE and _throw_cd <= 0.0:
				inp.press(&"throw")
				_throw_cd = 4.0 + _rng.randf() * 3.0
				goal = "chase"
		"toss":
			me.input.target = target
			_face_and_stop()
			if me.state == Fighter.State.MOVE and _attack_cd <= 0.0:
				_attack_cd = 0.55 * _rng.randf_range(0.9, 1.4)
				_hold = 0.03
				me.input.attack_held = true
		"shoot":
			me.input.target = target
			var to := target.global_position - me.global_position
			to.y = 0.0
			if _strafe_t <= 0.0:
				_strafe_t = 0.8 + _rng.randf() * 1.0
				_strafe = -_strafe
			_steer(to.normalized().cross(Vector3.UP) * _strafe, 0.4)
			if me.state == Fighter.State.MOVE and _attack_cd <= 0.0:
				var bow := me.weapon_data.heavy_charge != &""
				_attack_cd = (1.1 if bow else 0.3) * _rng.randf_range(0.9, 1.5) + float(level["reaction"]) * 0.5
				_hold = _rng.randf_range(0.5, 0.9) if bow else 0.03
				me.input.attack_held = true
		"barrel":
			# Throw the sword at a barrel the target is standing next to.
			_face_and_stop()
			if _barrel and is_instance_valid(_barrel) and not _barrel.is_broken and me.state == Fighter.State.MOVE:
				me.input.target = null
				var to := _barrel.global_position - me.global_position
				me.rotation.y = atan2(to.x, to.z)
				me.input.aim_point = _barrel.global_position
				me.input.press(&"throw")
				_throw_cd = 6.0 + _rng.randf() * 3.0
			goal = "chase"
		"arena":
			if _arena_goal != Vector3.INF:
				_go_to(_arena_goal, 1.0, delta)
			else:
				goal = "chase"
		"backoff":
			if target:
				var away := me.global_position - target.global_position
				away.y = 0.0
				_steer(away.normalized().rotated(Vector3.UP, _strafe * 0.6), 0.85)


func _dist() -> float:
	return me.global_position.distance_to(target.global_position) if target else INF


func _decide() -> void:
	target = _nearest_enemy()
	me.input.target = target if target and _dist() < 20.0 else null
	if target == null:
		goal = "idle"
		me.input.move = Vector2.ZERO
		return
	var d := _dist()
	var reach := _reach() + 0.2
	var scores := {}
	scores["chase"] = 0.45 + float(level["aggression"]) * 0.3
	if d < reach + 0.4 and absf(target.global_position.y - me.global_position.y) < 1.4:
		scores["fight"] = 1.0
	if not me.armed():
		_pickup = world.nearest_pickup(me.global_position, 22.0)
		if _pickup:
			scores["pickup"] = 0.95 - me.global_position.distance_to(_pickup.global_position) / 60.0
		if d < 6.0:
			scores["fight"] = 0.9          # no weapon in reach: use fists
	elif d > 6.0 and d < 17.0 and _throw_cd <= 0.0 and _clear_line(target) \
			and _rng.randf() < float(level["aggression"]) * 0.35:
		scores["throw"] = 0.9
	var kind := me.weapon_data.kind if me.armed() else &"melee"
	if kind == &"thrown" and d > 3.5 and d < 15.0 and _clear_line(target):
		scores["toss"] = 0.93
	elif kind == &"ranged" and d > 3.0 and d < 22.0 and _clear_line(target):
		scores["shoot"] = 0.96
	if me.armed() and _throw_cd <= 0.0 and kind == &"melee":
		var barrel := _barrel_near(target)
		if barrel:
			_barrel = barrel
			scores["barrel"] = 1.0 * float(level["aggression"]) + 0.2
	if me.health < me.max_health * 0.55:
		_powerup = world.nearest_powerup(me.global_position, 18.0, [&"health", &"shield"])
		if _powerup:
			scores["powerup"] = 0.97
	elif d > 8.0:
		_powerup = world.nearest_powerup(me.global_position, 9.0)
		if _powerup:
			scores["powerup"] = 0.7
	_consider_arena(d, scores)
	if world.arena.wet_time(me) > 0.3:
		var dry := world.arena.dry_spot(me.global_position)
		if dry != Vector3.INF:
			_arena_goal = dry
			_arena_goal_t = 0.0
			scores["arena"] = 0.97          # out of the flood, unless a fight is right here
	_consider_power(d)
	if me.health < me.max_health * 0.3 and target.armed() and d < 5.0:
		scores["backoff"] = 0.75 * (1.0 - float(level["aggression"]))
	var best := "chase"
	var best_s := -1.0
	for k: String in scores:
		if float(scores[k]) > best_s:
			best_s = scores[k]
			best = k
	goal = best


## An intact barrel `f` is standing next to that we can hit from here
## without being in the blast.
## The arena's signature mechanic (a lever, a cannon), when it's worth it.
func _consider_arena(d: float, scores: Dictionary) -> void:
	_arena_goal_t -= 0.1
	var g := world.arena.bot_goal(me, world)
	if g.is_empty() or d < 4.5:
		_arena_goal = Vector3.INF
		return
	if goal == "arena" and _arena_goal_t > 0.0:
		_arena_goal = g["at"]
		scores["arena"] = 1.05
		return
	# Nerve decides how often bots go for it.
	if _rng.randf() < 0.006 + float(level["aggression"]) * 0.008:
		_arena_goal = g["at"]
		_arena_goal_t = 7.0
		scores["arena"] = float(g["score"])


func _barrel_near(f: Fighter) -> Breakable:
	for piece in world.arena.breakables:
		if piece.kind != Breakable.Kind.BARREL or piece.is_broken:
			continue
		var p := piece.global_position
		var them := f.global_position.distance_to(p)
		var us := me.global_position.distance_to(p)
		if them < 3.2 and us > 6.0 and us < 17.0 and _clear_line_to(p):
			return piece
	return null


func _clear_line_to(p: Vector3) -> bool:
	var from := me.global_position + Vector3.UP * 1.4
	var hit := me.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, p, Game.L_WORLD))
	return hit.is_empty() or hit["collider"] is Breakable and (hit["collider"] as Breakable).kind == Breakable.Kind.BARREL


func _nearest_enemy() -> Fighter:
	var best: Fighter
	var best_d := INF
	for f: Fighter in world.fighters:
		if f == me or not f.alive:
			continue
		var d := me.global_position.distance_to(f.global_position)
		if f.is_player:
			d *= 0.8          # bots like a human target
		if d < best_d:
			best_d = d
			best = f
	return best


func _clear_line(f: Fighter) -> bool:
	var from := me.global_position + Vector3.UP * 1.4
	var to := f.global_position + Vector3.UP * 1.2
	return me.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD)).is_empty()


func _steer(dir: Vector3, amount: float) -> void:
	me.input.steer(dir, amount)


func _face_and_stop() -> void:
	me.input.move = Vector2.ZERO


func _go_to(pos: Vector3, amount: float, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0 or _path_i >= _path.size():
		_repath = 0.45
		var map := me.get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, me.global_position, pos, true)
		_path_i = 0
	var next := pos
	while _path_i < _path.size():
		var p := _path[_path_i]
		if Vector2(p.x - me.global_position.x, p.z - me.global_position.z).length() < 0.7:
			_path_i += 1
		else:
			next = p
			break
	var dir := next - me.global_position
	dir.y = 0.0
	if amount >= 1.0 and dir.length() > 6.0:
		me.input.sprint = true
	_steer(dir, amount)
	# Unstick: moving but not getting anywhere -> jump.
	if me.hspeed() < 0.8 and me.input.move.length() > 0.5:
		_stuck_t += delta
		if _stuck_t > 0.5:
			_stuck_t = 0.0
			# Blocked by a crate or railing? Smash it. Otherwise hop.
			var ahead := me.global_position + Vector3(dir.x, 0, dir.z).normalized() * 0.9 + Vector3.UP
			if world.arena.breakable_near(ahead, 0.5) and me.state == Fighter.State.MOVE:
				me.input.attack_held = true
				_hold = 0.03
			else:
				me.input.press(&"jump")
	else:
		_stuck_t = 0.0


## How close we must be to hit with what we hold.
func _reach() -> float:
	if not me.armed():
		return 1.4
	var w := me.weapon_data
	if w.idle_clip == &"Spear_Idle":
		return 2.7
	if w.idle_clip == &"Heavy_Idle":
		return 2.3
	if not w.light_moves.is_empty() and w.light_moves[0] == &"Stab_A":
		return 1.7
	if w.kind == &"melee" and w.light_moves.size() > 0 and w.light_moves[0] == &"Jab":
		return 1.45
	# One-handed swingers: arm's length plus the weapon (ice cream short, sword long).
	return clampf(1.15 + w.hit_to * 0.95, 1.5, 2.2)


func _fight(_delta: float) -> void:
	var d := _dist()
	var reach := _reach()
	var to := target.global_position - me.global_position
	to.y = 0.0
	if _strafe_t <= 0.0:
		_strafe_t = 0.6 + _rng.randf() * 1.2
		_strafe = -_strafe if _rng.randf() < 0.5 else _strafe
	if d > reach:
		_steer(to.normalized(), 0.7)
	elif d < reach * 0.55:
		_steer(-to.normalized(), 0.5)
	else:
		_steer(to.normalized().cross(Vector3.UP) * _strafe, 0.35)
	# A swing is coming: parry it, block it or roll away.
	if target.state in [Fighter.State.ATTACK, Fighter.State.HEAVY] and d < 3.4:
		var swing := target.get_instance_id() + hash(target._attack_clip)
		if swing != _guarded_attack:
			_guarded_attack = swing
			var roll := _rng.randf()
			if roll < float(level["parry"]):
				_parry_pending = true
			elif roll < float(level["parry"]) + float(level["block"]):
				_block_t = _rng.randf_range(0.45, 0.8)
			elif _rng.randf() < float(level["dodge"]):
				me.input.press(&"dodge")
				return
		if _parry_pending:
			var w := BlockBody.hit_window(target._attack_clip)
			var until := (w.x - target.body.action_time) / maxf(target.body.action_speed, 0.1)
			if until <= 0.1:
				_parry_pending = false
				_block_t = 0.35
	_react -= 0.1
	if _attack_cd <= 0.0 and me.state == Fighter.State.MOVE and d < reach + 0.3:
		_attack_cd = float(level["cadence"]) * _rng.randf_range(0.8, 1.3)
		if _rng.randf() < float(level["heavy"]) and me.armed():
			_hold = _rng.randf_range(0.4, 0.95)       # charge a heavy
		else:
			_hold = 0.03
		me.input.attack_held = true


var _parry_pending := false


func _consider_power(d: float) -> void:
	if not me.powers.ready_to_use() or me.state != Fighter.State.MOVE:
		return
	var use := false
	match me.powers.power:
		&"stomp":
			var near := 0
			for f in world.fighters:
				if f != me and f.alive and f.global_position.distance_to(me.global_position) < 4.0:
					near += 1
			use = near >= 1
		&"rage", &"iron_skin", &"bullet_time":
			use = d < 4.5
		&"blink":
			use = d > 7.0 and d < 14.0 and _clear_line(target)
			if use:
				me.input.steer(target.global_position - me.global_position, 1.0)
		&"second_wind":
			use = me.health < me.max_health * 0.45
	if use:
		me.input.press(&"power")


func _handle_attack_button(delta: float) -> void:
	if me.input.attack_held:
		_hold -= delta
		if _hold <= 0.0:
			me.input.attack_held = false


func _react_to_incoming(_delta: float) -> void:
	var p := world.incoming_projectile(me, 0.8)
	if p == null:
		return
	var key := p.get_instance_id()
	if not _decided_catch.has(key):
		_decided_catch[key] = _rng.randf() < float(level["catch"])
		if not _decided_catch[key] and _rng.randf() < float(level["dodge"]):
			me.input.press(&"dodge")
	if _decided_catch[key] and world.time_to_reach(p, me) <= 0.15:
		me.input.press(&"throw")
