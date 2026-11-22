class_name Fighter
extends CharacterBody3D
## A block fighter. It reads a FighterInput each physics frame and never
## knows whether a thumb, a bot or the network filled it.
##
## Combat (doc: Combat rules): hits are swept tests of the weapon's
## striking part against each fighter's body capsule; damage scales with
## how fast that part was moving, so sprinting or falling swings hit
## hardest. Heavy hits ragdoll the target for a moment; at 0 HP the body
## goes fully limp and the weapon drops as a pickup.

signal died(victim: Fighter, killer: Fighter)
signal hurt(victim: Fighter, attacker: Fighter, damage: float, at: Vector3, heavy: bool)
signal hit_landed(attacker: Fighter, victim: Fighter, damage: float)

enum State { MOVE, ATTACK, CHARGE, HEAVY, THROW, CATCH, DODGE, HURT, DOWN, GETUP, DEAD, FROZEN, LAND }

@export_group("Movement")
@export var max_health := 100.0
@export var walk_speed := 2.4
@export var run_speed := 6.8
@export var sprint_speed := 9.8
@export var accel := 48.0
@export var air_accel := 14.0
@export var jump_velocity := 9.6
@export var double_jump_velocity := 9.0
@export var gravity := 24.0
@export var turn_speed := 16.0
@export var dodge_speed := 12.0
@export var coyote_time := 0.12

@export_group("Combat")
## Holding attack this long starts a heavy charge.
@export var charge_threshold := 0.2
@export var charge_full := 0.9
@export var catch_window := 0.2
@export var hurt_radius := 0.38

const HURT_LOW := 0.25
const HURT_HIGH := 1.75
## Where each get-up clip starts the pelvis, in the fighter's local space.
const GETUP_BACK_HIPS := Vector3(0, 0.14, -0.28)
const GETUP_FRONT_HIPS := Vector3(0, 0.16, -0.42)

var fighter_id := 0
var display_name := "Fighter"
var is_player := false
var input := FighterInput.new()
var skin: SkinData
var body: BlockBody
var ragdoll: Ragdoll
var weapon_data: WeaponData
var weapon_visual: MeshInstance3D
var trail: BladeTrail
var world: Match

var health := 100.0
var alive := true
var state := State.MOVE
var state_time := 0.0
var invuln := 0.0
var protect := 0.0               # spawn protection
var last_hitter: Fighter
var last_hit_time := -100.0      # Match clock seconds

var _air_time := 0.0
var _jumps := 0
var _combo := 0
var _combo_window := 0.0
var _queued_attack := false
var _attack_hits: Array[Fighter] = []
var _attack_pieces: Array[Breakable] = []
var _attack_clip := &""
var _attack_upper := false
var _attack_damage_mult := 1.0
var _attack_knockdown := false
var _prev_a := Vector3.ZERO       # striking segment last frame
var _prev_b := Vector3.ZERO
var _have_prev := false
var _attack_down_at := -1.0       # when attack went down (s), -1 = up
var _charge := 0.0
var _boost_until := 0.0           # caught a weapon: next throw flies 1.5x faster
var _threw := false
var _down_time := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _fall_speed := 0.0
var _clock := 0.0


func _ready() -> void:
	add_to_group(&"fighters")
	collision_layer = Game.L_FIGHTERS
	collision_mask = Game.L_WORLD | Game.L_FIGHTERS
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.02
	body = BlockBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(skin if skin else Registry.skin(0))
	ragdoll = body.build_ragdoll()
	trail = BladeTrail.new()
	trail.color = body.skin.trail
	add_child(trail)
	health = max_health
	if weapon_data == null:
		weapon_data = Registry.weapon(&"fists")
	equip(weapon_data)


# ---------------------------------------------------------------- weapons

func armed() -> bool:
	return weapon_data != null and not weapon_data.is_fists()


func equip(data: WeaponData) -> void:
	weapon_data = data if data else Registry.weapon(&"fists")
	if weapon_visual:
		weapon_visual.queue_free()
		weapon_visual = null
	if armed():
		weapon_visual = MeshInstance3D.new()
		weapon_visual.mesh = weapon_data.mesh()
		body.socket_r.add_child(weapon_visual)
	_combo = 0


## Lets go of the held weapon and returns it (null if unarmed).
func unequip() -> WeaponData:
	if not armed():
		return null
	var d := weapon_data
	equip(null)
	return d


func socket_transform() -> Transform3D:
	return body.socket_r.global_transform


# ---------------------------------------------------------------- physics

func _physics_process(delta: float) -> void:
	_clock += delta
	state_time += delta
	invuln = maxf(invuln - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_combo_window = maxf(_combo_window - delta, 0.0)
	if protect > 0.0:
		protect = maxf(protect - delta, 0.0)
		body.flash(0.35 + 0.35 * sin(_clock * 18.0))
	match state:
		State.DEAD:
			_follow_ragdoll()
			return
		State.DOWN:
			_follow_ragdoll()
			if state_time > _down_time and (ragdoll.speed() < 1.5 or state_time > _down_time + 1.5):
				_get_up()
			return
	_track_attack_button()
	if not is_on_floor():
		velocity.y -= gravity * delta
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	match state:
		State.FROZEN:
			_brake(delta, accel)
		State.MOVE:
			_state_move(delta)
		State.ATTACK, State.HEAVY:
			_state_attack(delta)
		State.CHARGE:
			_state_charge(delta)
		State.THROW, State.CATCH:
			_state_throw(delta)
		State.DODGE:
			if state_time > 0.5:
				_set_state(State.MOVE)
			else:
				var k := 1.0 - clampf((state_time - 0.3) / 0.2, 0.0, 1.0)
				velocity.x = _dodge_dir.x * dodge_speed * k
				velocity.z = _dodge_dir.z * dodge_speed * k
		State.HURT:
			_brake(delta, 18.0)
			if body.action_over() or state_time > 0.35:
				body.stop_action()
				_set_state(State.MOVE)
		State.GETUP:
			_brake(delta, accel)
			if body.action_over():
				_set_state(State.MOVE)
		State.LAND:
			# A big drop: knees, a hand down, a moment to come up.
			_brake(delta, 40.0)
			if body.action_over() or state_time > 0.42:
				body.stop_action(0.15)
				_set_state(State.MOVE)
	var was_floor := is_on_floor()
	var pre_speed := velocity.length()
	move_and_slide()
	if pre_speed > 7.0 and state != State.MOVE and world:
		_smash_into_scenery(pre_speed)
	if is_on_floor():
		if not was_floor and _air_time > 0.25:
			_landed()
		_air_time = 0.0
		_jumps = 0
		_fall_speed = 0.0
	_update_trail()
	_animate()


func _set_state(s: State) -> void:
	state = s
	state_time = 0.0


func _brake(delta: float, rate: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, rate * delta)
	velocity.z = move_toward(velocity.z, 0.0, rate * delta)


func hspeed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func forward() -> Vector3:
	return global_basis.z


func _face(dir: Vector3, delta: float, rate: float = -1.0) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * (turn_speed if rate < 0.0 else rate), 0.0, 1.0))


func locked_target() -> Fighter:
	var t := input.target as Fighter
	if t and is_instance_valid(t) and t.alive and t.global_position.distance_to(global_position) < 30.0:
		return t
	return null


# ------------------------------------------------------------------ moving

func _state_move(delta: float) -> void:
	var wish := input.world_move()
	var mag := minf(wish.length(), 1.0)
	var sprinting := (input.sprint or mag > 0.93) and mag > 0.3
	var target := locked_target()
	var speed := 0.0
	if mag > 0.06:
		if mag < 0.5 and not input.sprint:
			speed = walk_speed
		elif sprinting:
			speed = sprint_speed
		else:
			speed = run_speed
		if target and not sprinting:
			speed = minf(speed, run_speed * 0.8)
	var want := wish.normalized() * speed if mag > 0.06 else Vector3.ZERO
	var a := accel if is_on_floor() else air_accel
	velocity.x = move_toward(velocity.x, want.x, a * delta)
	velocity.z = move_toward(velocity.z, want.z, a * delta)
	if target and not sprinting:
		_face(target.global_position - global_position, delta)
	elif mag > 0.06:
		_face(wish, delta)

	if input.consume(&"jump"):
		_jump()
	if input.consume(&"dodge") and _dodge_cd <= 0.0:
		_dodge(wish if mag > 0.2 else forward())
		return
	if _throw_or_catch():
		return
	if _queued_attack or _light_requested():
		_queued_attack = false
		_light_attack()
		return
	if _attack_down_at >= 0.0 and _clock - _attack_down_at >= charge_threshold:
		_start_charge()
		return
	if not armed() and world:
		var pick := world.pickup_near(global_position, 1.3)
		if pick:
			world.take_pickup(pick, self)


func _jump() -> void:
	if is_on_floor() or (_air_time < coyote_time and _jumps == 0 and velocity.y <= 0.5):
		velocity.y = jump_velocity
		_jumps = 1
		_air_time = coyote_time + 0.01
		body.play(_armed_clip(&"Jump_Start"), false, 1.0, 0.04)
		Audio.play(&"swing", global_position, -14.0, 0.6)
	elif is_on_wall_only() and _jumps < 3:
		var n := get_wall_normal()
		velocity = Vector3(n.x, 0, n.z).normalized() * 7.0 + Vector3.UP * double_jump_velocity
		rotation.y = atan2(n.x, n.z)
		_jumps = 2
		body.play(&"Wall_Kick", false, 1.1, 0.05)
		Audio.play(&"swing", global_position, -8.0, 0.8)
		Fx.dust(get_parent(), global_position + Vector3.UP * 1.0 - n * 0.3, 0.8)
	elif _jumps < 2:
		velocity.y = double_jump_velocity
		_jumps = 2
		body.play(_armed_clip(&"Double_Jump"), false, 1.0, 0.05)
		Audio.play(&"swing", global_position, -8.0, 0.7)


func _dodge(dir: Vector3) -> void:
	dir.y = 0.0
	_dodge_dir = dir.normalized()
	rotation.y = atan2(_dodge_dir.x, _dodge_dir.z)
	invuln = 0.38
	_dodge_cd = 0.55
	_set_state(State.DODGE)
	body.play(&"Dodge_Roll", false, 1.2, 0.05)
	Audio.play(&"swing_heavy", global_position, -8.0, 1.3)


func _landed() -> void:
	if _fall_speed > 8.0:
		Fx.dust(get_parent(), global_position + Vector3.UP * 0.05, clampf(_fall_speed / 14.0, 0.6, 1.5))
		Audio.play(&"land", global_position, -6.0 + clampf(_fall_speed - 14.0, 0.0, 6.0))
	if state != State.MOVE:
		return
	if _fall_speed > 15.0:
		# Superhero landing from a big drop.
		body.play(_armed_clip(&"Land_Hard"), false, 1.0, 0.03)
		_set_state(State.LAND)
		if is_player and world:
			world.camera.shake(0.25)
	elif _fall_speed > 6.0 and hspeed() < 3.5:
		body.play(_armed_clip(&"Land"), false, 1.1, 0.04)


## The sword version of a move when holding one (e.g. Fall_Sword).
func _armed_clip(clip: StringName) -> StringName:
	return StringName(String(clip) + "_Sword") if armed() else clip


## Knocked flying into a crate or a railing: it takes the hit (credited to
## whoever sent us flying).
func _smash_into_scenery(speed: float) -> void:
	for i in get_slide_collision_count():
		var piece := get_slide_collision(i).get_collider() as Breakable
		if piece:
			piece.hit(speed * 3.5, get_slide_collision(i).get_position(), velocity, last_hitter)


func _follow_ragdoll() -> void:
	# The fighter's root rides along under the limp body, so the camera and
	# the respawn/get-up logic know where it is.
	var h := ragdoll.hips_position()
	global_position = Vector3(h.x, h.y - 0.3, h.z)
	# A flying body smashes through scenery too.
	if world and ragdoll.active and ragdoll.speed() > 5.0:
		var piece := world.arena.breakable_near(h, 0.45)
		if piece:
			piece.hit(ragdoll.speed() * 4.0, h, (ragdoll.bodies[&"Hips"] as PhysicalBone3D).linear_velocity, last_hitter)


# ---------------------------------------------------------------- attacking

func _track_attack_button() -> void:
	if input.attack_held and _attack_down_at < 0.0:
		_attack_down_at = _clock
	elif not input.attack_held and _attack_down_at >= 0.0:
		if _clock - _attack_down_at < charge_threshold and state != State.CHARGE:
			input.press(&"_light")
		_attack_down_at = -1.0
		if state == State.CHARGE:
			_release_heavy()


func _light_requested() -> bool:
	return input.consume(&"_light", 220)


func _soft_aim() -> void:
	# Turn toward the lock target, or the nearest enemy just in front.
	var best := locked_target()
	if best == null and world:
		var best_d := 4.0
		for f in world.fighters:
			if f == self or not f.alive:
				continue
			var d := f.global_position - global_position
			if d.length() < best_d and forward().dot(d.normalized()) > 0.2:
				best_d = d.length()
				best = f
	if best:
		var d := best.global_position - global_position
		rotation.y = atan2(d.x, d.z)


func _light_attack() -> void:
	var moves := weapon_data.light_moves
	if moves.is_empty():
		return
	if _combo_window <= 0.0:
		_combo = 0
	var clip: StringName = moves[_combo % moves.size()]
	_combo += 1
	_attack_knockdown = clip == weapon_data.knockdown_move
	_start_attack(clip, 1.0, State.ATTACK)


func _start_attack(clip: StringName, damage_mult: float, s: State) -> void:
	protect = 0.0
	_soft_aim()
	_attack_upper = (hspeed() > 3.5 or not is_on_floor()) and s == State.ATTACK
	_attack_damage_mult = damage_mult
	_attack_clip = clip
	_attack_hits.clear()
	_attack_pieces.clear()
	_have_prev = false
	_queued_attack = false
	_set_state(s)
	body.play(clip, _attack_upper, weapon_data.attack_speed, 0.07)
	if not _attack_upper and is_on_floor():
		var lunge := forward() * (3.5 if s == State.ATTACK else 2.0)
		velocity.x = lunge.x
		velocity.z = lunge.z
	var w := BlockBody.hit_window(clip)
	Audio.play(&"swing_heavy" if s == State.HEAVY else &"swing", global_position + Vector3.UP, -4.0,
		0.9 if armed() else 1.25)
	trail.active = armed()
	if w.x < 0.0:
		trail.active = false


func _state_attack(delta: float) -> void:
	var clip := _attack_clip
	var done := body.action != clip      # finished (or replaced)
	var t := body.action_time
	var w := BlockBody.hit_window(clip)
	if _attack_upper:
		# Legs keep going: steer like moving, a bit slower.
		var wish := input.world_move()
		var want := wish * run_speed * 0.6
		velocity.x = move_toward(velocity.x, want.x, accel * delta)
		velocity.z = move_toward(velocity.z, want.z, accel * delta)
	else:
		_brake(delta, 14.0)
	if t >= w.x and t <= w.y:
		_strike(clip, delta)
	else:
		_have_prev = false
	if state == State.HEAVY and t < w.y:
		# The spin carries forward a little.
		var f := forward() * 3.0
		velocity.x = lerpf(velocity.x, f.x, 0.2)
		velocity.z = lerpf(velocity.z, f.z, 0.2)
	if state == State.ATTACK and t > w.x and _light_requested():
		_queued_attack = true
	# A queued attack cancels the recovery once the hit window is over.
	if _queued_attack and t > w.y + 0.04:
		_combo_window = 0.5
		_light_attack()
		return
	if input.consume(&"dodge") and t > w.y and _dodge_cd <= 0.0:
		trail.active = false
		var wish := input.world_move()
		_dodge(wish if wish.length() > 0.2 else forward())
		return
	if done:
		trail.active = false
		_combo_window = 0.45
		body.stop_action(0.15)
		_set_state(State.MOVE)


func _start_charge() -> void:
	if weapon_data.heavy_charge == &"":
		_attack_down_at = -1.0
		_attack_knockdown = true
		_start_attack(weapon_data.heavy_move, weapon_data.heavy_multiplier, State.HEAVY)
		return
	protect = 0.0
	_charge = 0.0
	_set_state(State.CHARGE)


func _state_charge(delta: float) -> void:
	_charge = minf(_charge + delta / charge_full, 1.0)
	_brake(delta, 20.0)
	var target := locked_target()
	if target:
		_face(target.global_position - global_position, delta, 6.0)
	elif input.world_move().length() > 0.2:
		_face(input.world_move(), delta, 6.0)
	if _charge >= 1.0 and int(state_time * 10.0) % 3 == 0:
		body.flash(0.4)
	if state_time > 3.0:
		_release_heavy()


func _release_heavy() -> void:
	if state != State.CHARGE:
		return
	_attack_knockdown = true
	_start_attack(weapon_data.heavy_move, weapon_data.heavy_multiplier * (0.6 + 0.4 * _charge), State.HEAVY)


## The striking segment in world space: the blade, or a fist/foot.
func _strike_segment(clip: StringName) -> PackedVector3Array:
	var who := weapon_data.striker(clip)
	if who == &"blade" and armed():
		var s := socket_transform()
		return PackedVector3Array([s * Vector3(0, weapon_data.hit_from, 0), s * Vector3(0, weapon_data.hit_to, 0)])
	var bone := who if who != &"blade" else &"RightHand"
	var p := body.bone_position(bone)
	return PackedVector3Array([p, p])


func _strike(clip: StringName, delta: float) -> void:
	var seg := _strike_segment(clip)
	var a := seg[0]
	var b := seg[1]
	if not _have_prev:
		_prev_a = a
		_prev_b = b
		_have_prev = true
	var tip_speed := (b - _prev_b).length() / maxf(delta, 0.001)
	if world:
		for f in world.fighters:
			if f == self or not f.alive or _attack_hits.has(f) or f.protect > 0.0:
				continue
			var lo := f.global_position + Vector3.UP * HURT_LOW
			var hi := f.global_position + Vector3.UP * HURT_HIGH
			var reach := weapon_data.hit_radius + f.hurt_radius
			# Swept: now, last frame, and halfway between.
			var hit := Geo.segment_distance(a, b, lo, hi) <= reach \
				or Geo.segment_distance((a + _prev_a) * 0.5, (b + _prev_b) * 0.5, lo, hi) <= reach \
				or Geo.segment_distance(b, _prev_b, lo, hi) <= reach
			if hit:
				_attack_hits.append(f)
				var at := Geo.closest_on_segment((lo + hi) * 0.5, a, b)
				var dmg := WeaponData.speed_damage(weapon_data.base_damage, tip_speed, weapon_data.ref_speed) * _attack_damage_mult
				var dir := f.global_position - global_position
				dir.y = 0.0
				var heavy := _attack_knockdown or state == State.HEAVY
				f.take_hit(dmg, dir.normalized(), self, heavy, at, weapon_data.knockback * (1.6 if heavy else 1.0))
				hit_landed.emit(self, f, dmg)
		# Scenery in the blade's path takes the same blow.
		for piece in world.arena.breakables_on_segment((a + _prev_a) * 0.5, (b + _prev_b) * 0.5, weapon_data.hit_radius) \
				+ world.arena.breakables_on_segment(a, b, weapon_data.hit_radius):
			if _attack_pieces.has(piece):
				continue
			_attack_pieces.append(piece)
			var dmg := WeaponData.speed_damage(weapon_data.base_damage, tip_speed, weapon_data.ref_speed) * _attack_damage_mult
			var push := piece.global_position - global_position
			push.y = 0.0
			piece.hit(dmg * (1.5 if state == State.HEAVY else 1.0), (a + b) * 0.5, push.normalized() * 4.0, self)
	_prev_a = a
	_prev_b = b


# ----------------------------------------------------------------- throwing

func _throw_or_catch() -> bool:
	if world == null:
		return false
	var incoming := world.incoming_projectile(self, 0.6)
	if incoming and input.pressed_recently(&"throw", int(catch_window * 1000.0)):
		if world.time_to_reach(incoming, self) <= catch_window and incoming.data.catchable:
			input.consume(&"throw")
			_catch(incoming)
			return true
		return false          # wait for it (the press stays buffered for the window)
	if input.consume(&"throw") and armed() and weapon_data.throwable:
		protect = 0.0
		_soft_aim()
		_threw = false
		_set_state(State.THROW)
		body.play(&"Throw", hspeed() > 3.0, 1.0, 0.06)
		return true
	return false


func _catch(p: ThrownWeapon) -> void:
	var old := unequip()
	if old and world:
		world.drop_pickup(old, global_position + forward() * 0.6 + Vector3.UP, Vector3.UP * 2.0)
	world.catch_projectile(p, self)
	equip(p.data)
	_boost_until = _clock + 4.0
	_set_state(State.CATCH)
	body.play(&"Catch", hspeed() > 3.0, 1.0, 0.04)
	Audio.play(&"catch", global_position + Vector3.UP * 1.4, 2.0)
	Fx.sparks(get_parent(), socket_transform().origin, body.skin.trail, 10)
	Game.vibrate(30)


func _state_throw(delta: float) -> void:
	var done := body.action_over()
	_brake(delta, 10.0 if not body.action_upper else 4.0)
	if state == State.THROW and not _threw and body.action_time >= BlockBody.event_time(&"Throw", "release"):
		_threw = true
		var data := unequip()
		if data and world:
			var boost := 1.5 if _clock < _boost_until else 1.0
			var origin := socket_transform().origin
			world.spawn_projectile(self, data, origin, _aim_direction(origin, data.throw_speed * boost), data.throw_speed * boost, boost > 1.0)
			Audio.play(&"throw", origin, 0.0, 1.1 if boost > 1.0 else 1.0)
	if done or state_time > 0.9:
		body.stop_action(0.15)
		_set_state(State.MOVE)


func _aim_direction(origin: Vector3, speed: float) -> Vector3:
	if input.aim_point is Vector3:
		var spot: Vector3 = input.aim_point
		input.aim_point = null
		var tt := origin.distance_to(spot) / maxf(speed, 1.0)
		return (spot + Vector3.UP * 0.5 * ThrownWeapon.GRAVITY * tt * tt - origin).normalized()
	var target := locked_target()
	if target == null and world:
		target = world.aim_assist_target(self, float(Save.setting("aim_assist")) if is_player else 0.8)
	if target:
		var aim := target.global_position + Vector3.UP * 1.1
		var t := origin.distance_to(aim) / maxf(speed, 1.0)
		aim += Vector3(target.velocity.x, 0, target.velocity.z) * t * 0.7   # lead the target
		aim += Vector3.UP * 0.5 * ThrownWeapon.GRAVITY * t * t                # arc for the drop
		return (aim - origin).normalized()
	var yaw_dir := Vector3(-sin(input.aim_yaw), 0, -cos(input.aim_yaw)) if is_player else forward()
	return (yaw_dir + Vector3.UP * 0.12).normalized()


# --------------------------------------------------------------- being hit

func take_hit(damage: float, dir: Vector3, attacker: Fighter, heavy: bool, at: Vector3, knock: float) -> void:
	if not alive or invuln > 0.0 or protect > 0.0:
		return
	if state == State.DOWN or state == State.GETUP and invuln > 0.0:
		# Already on the floor: the hit still hurts and shoves the body.
		health = maxf(health - damage * 0.7, 0.0)
		last_hitter = attacker
		last_hit_time = world.clock if world else 0.0
		hurt.emit(self, attacker, damage * 0.7, at, heavy)
		if health <= 0.0:
			die(attacker, dir * knock + Vector3.UP * 3.0, at)
		elif ragdoll.active:
			(ragdoll.bodies[&"UpperChest"] as PhysicalBone3D).apply_central_impulse(dir * knock * 8.0)
		return
	health = maxf(health - damage, 0.0)
	last_hitter = attacker
	last_hit_time = world.clock if world else 0.0
	hurt.emit(self, attacker, damage, at, heavy)
	body.flash(0.9)
	if state == State.CHARGE or state == State.ATTACK or state == State.THROW:
		trail.active = false
	if health <= 0.0:
		die(attacker, dir * (knock * 1.6) + Vector3.UP * 3.0, at)
		return
	if heavy:
		knock_down(dir * knock * 1.3 + Vector3.UP * 4.0, at)
		return
	velocity = dir * knock + Vector3.UP * (1.5 if is_on_floor() else 0.5)
	_set_state(State.HURT)
	var from_front := forward().dot(-dir) > 0.0
	body.play(&"Hit_Front" if from_front else &"Hit_Back", false, 1.3, 0.04)


func knock_down(impulse: Vector3, at: Vector3) -> void:
	_drop_on_hit()
	_set_state(State.DOWN)
	_down_time = 0.7
	collision_layer = 0
	body.stop_action(0.0)
	ragdoll.start(velocity + impulse * 0.4, impulse, _nearest_body_bone(at))


func die(killer: Fighter, impulse: Vector3, at: Vector3 = Vector3.ZERO) -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	trail.active = false
	var dropped := unequip()
	if dropped and world:
		world.drop_pickup(dropped, socket_transform().origin, impulse * 0.3 + Vector3.UP * 4.0)
	_set_state(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	body.stop_action(0.0)
	if not ragdoll.active:
		ragdoll.start(velocity, impulse, _nearest_body_bone(at) if at != Vector3.ZERO else &"UpperChest")
	Audio.play(&"death", global_position + Vector3.UP, 0.0)
	died.emit(self, killer)


func _drop_on_hit() -> void:
	# Heavy knockdowns don't disarm in Phase 1 (they will with parries).
	pass


func _nearest_body_bone(at: Vector3) -> StringName:
	var best := &"UpperChest"
	var best_d := INF
	for bone: StringName in ragdoll.bodies:
		var d := (ragdoll.bodies[bone] as PhysicalBone3D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = bone
	return best


func _get_up() -> void:
	var up := ragdoll.face_up()
	var hips := ragdoll.hips_position()
	var head := ragdoll.head_position()
	var d := head - hips
	d.y = 0.0
	if d.length() < 0.05:
		d = forward()
	d = d.normalized()
	# Lying on the back the clip has the head behind (-Z); face down, in front.
	var yaw := atan2(-d.x, -d.z) if up else atan2(d.x, d.z)
	var offset := GETUP_BACK_HIPS if up else GETUP_FRONT_HIPS
	var ground := hips.y - 0.15
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(hips + Vector3.UP * 0.5, hips + Vector3.DOWN * 3.0, Game.L_WORLD)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		ground = (hit["position"] as Vector3).y
	rotation = Vector3(0, yaw, 0)
	var pos := hips - Basis(Vector3.UP, yaw) * Vector3(offset.x, 0, offset.z)
	global_position = Vector3(pos.x, ground + 0.02, pos.z)
	velocity = Vector3.ZERO
	collision_layer = Game.L_FIGHTERS
	ragdoll.stop(0.35)
	body.play(&"GetUp_Back" if up else &"GetUp_Front", false, 1.15, 0.0)
	invuln = 1.0
	_set_state(State.GETUP)


## Back in the fight at a spawn point.
func respawn(at: Vector3, yaw: float) -> void:
	ragdoll.stop(0.0)
	global_position = at
	rotation = Vector3(0, yaw, 0)
	velocity = Vector3.ZERO
	health = max_health
	alive = true
	protect = 2.0
	collision_layer = Game.L_FIGHTERS
	collision_mask = Game.L_WORLD | Game.L_FIGHTERS
	last_hitter = null
	_jumps = 0
	_attack_down_at = -1.0
	input.clear()
	body.stop_action(0.0)
	_set_state(State.MOVE)
	if world:
		equip(Registry.weapon(world.config.start_weapon))
	Audio.play(&"respawn", at + Vector3.UP, -4.0)


func freeze(on: bool) -> void:
	if on:
		body.stop_action(0.0)
		_set_state(State.FROZEN)
	elif state == State.FROZEN:
		_set_state(State.MOVE)


func celebrate() -> void:
	_set_state(State.FROZEN)
	body.set_loco(&"Victory", 1.0)


# ---------------------------------------------------------------- animation

func _animate() -> void:
	if state == State.FROZEN and body.loco == &"Victory":
		return
	var sword := armed()
	var sfx := "_Sword" if sword else ""
	var hs := hspeed()
	if state == State.CHARGE:
		body.set_loco(&"Heavy_Charge", 1.0)
		return
	if not is_on_floor() and _air_time > 0.08:
		body.set_loco(_armed_clip(&"Jump_Rise" if velocity.y > 1.0 else &"Fall"), 1.0)
		return
	if hs < 0.35:
		body.set_loco(&"Sword_Idle" if sword else &"Idle", 1.0)
		return
	var target := locked_target()
	var clip: StringName
	if target and hs < sprint_speed * 0.8:
		var local := global_basis.inverse() * velocity
		if local.z < -absf(local.x) * 0.7:
			clip = StringName("Backpedal" + sfx)
		elif absf(local.x) > absf(local.z):
			clip = StringName(("Strafe_L" if local.x > 0.0 else "Strafe_R") + sfx)
		else:
			clip = StringName(("Walk" if hs < 3.0 else "Run") + sfx)
	elif hs < 3.2:
		clip = StringName("Walk" + sfx)
	elif hs < 8.2:
		clip = StringName("Run" + sfx)
	else:
		clip = StringName("Sprint" + sfx)
	var native := float(BlockBody.move_info(clip)["speed"])
	body.set_loco(clip, clampf(hs / maxf(native, 0.1), 0.6, 2.2))


func _update_trail() -> void:
	if trail.active and armed():
		var s := socket_transform()
		trail.add_point(s * Vector3(0, weapon_data.hit_from + 0.15, 0), s * Vector3(0, weapon_data.hit_to, 0))
	else:
		trail.add_point(Vector3.ZERO, Vector3.ZERO, false)
