class_name CameraRig
extends Node3D
## Third-person camera over the right shoulder (doc: Camera). A SpringArm3D
## pulls in so walls never block the view; lock-on orbits to keep the
## target in frame; trauma-based shake for hits. Feel: it leans into
## sideways running, dips when you land hard, gets knocked away from hits
## and widens (FOV kick) when you're launched or dash.

@export var distance := 3.9
@export var shoulder := 0.62
@export var height := 1.58
@export var fov := 68.0

var target: Fighter
## First person (FPP): the eye sits in the head, the body turns with the view.
var first_person := false
@export var fp_fov := 78.0
var yaw := 0.0
var pitch := -0.18
var spring: SpringArm3D
var camera: Camera3D
var _pivot := Vector3.ZERO
var _pivot_set := false
var _trauma := 0.0
var _rng := RandomNumberGenerator.new()
var _fov_kick := 0.0
var _noise_t := 0.0
var _punch := Vector2.ZERO          # screen-space knock (h, v offsets)
var _roll := 0.0
var _dip := 0.0
var _dip_vel := 0.0
var _was_air := false
var _air_vy := 0.0


func _ready() -> void:
	# Moved every frame, not every physics tick: no interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	spring = SpringArm3D.new()
	spring.spring_length = distance
	spring.margin = 0.25
	spring.collision_mask = Game.L_WORLD
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	spring.shape = shape
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = fov
	camera.near = 0.08
	camera.far = 160.0
	spring.add_child(camera)
	camera.current = true


func add_look(delta_px: Vector2) -> void:
	var s := 0.0042 * float(Save.setting("look_sensitivity"))
	yaw -= delta_px.x * s
	pitch = clampf(pitch - delta_px.y * s, -1.35 if first_person else -1.05, 1.3 if first_person else 0.55)


func set_first_person(on: bool) -> void:
	first_person = on
	if not on:
		pitch = clampf(pitch, -1.05, 0.55)
	_pivot_set = false


## First person needs a body that's up and in control; knocked down, dead
## or held, the view pulls back out so the ragdoll doesn't spin the eye.
func eye_view() -> bool:
	return first_person and target != null and target.alive and not target.ragdoll.active \
		and target.state not in [Fighter.State.DOWN, Fighter.State.DEAD, Fighter.State.HELD]


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func kick_fov(amount: float) -> void:
	_fov_kick = maxf(_fov_kick, amount)


## A hit from world direction `from_dir` (pointing at us): the view is
## knocked the way the blow travels.
func punch(from_dir: Vector3, amount: float) -> void:
	var right := global_transform.basis.x
	var side := right.dot(from_dir.normalized())
	_punch += Vector2(side, 0.35) * amount


func snap() -> void:
	_pivot_set = false


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var real := delta / maxf(Engine.time_scale, 0.02)
	var eye := eye_view()
	# First person: the eye in the head (a touch forward), lightly smoothed
	# so swings don't jolt the view. Third person: over the shoulder.
	var goal := target.global_position + Vector3.UP * height
	if eye:
		goal = target.body.bone_position(&"Head") + Vector3.UP * 0.13 + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.07
	if not _pivot_set or _pivot.distance_to(goal) > 15.0:
		_pivot = goal
		_pivot_set = true
	# Frame-rate independent smoothing (1 - e^(-rate dt)), not a fixed lerp.
	var k_flat := 1.0 - exp(-(30.0 if eye else 12.0) * real)
	var k_up := 1.0 - exp(-(30.0 if eye else 7.0) * real)
	_pivot.x = lerpf(_pivot.x, goal.x, k_flat)
	_pivot.z = lerpf(_pivot.z, goal.z, k_flat)
	_pivot.y = lerpf(_pivot.y, goal.y, k_up)
	var want_len := 0.0 if eye else distance
	if not is_equal_approx(spring.spring_length, want_len):
		spring.spring_length = want_len
	if target.health_bar:
		target.health_bar.hidden_for_view = eye

	var lock := target.locked_target()
	if lock:
		var to := lock.global_position - target.global_position
		var want_yaw := atan2(-to.x, -to.z)
		yaw = lerp_angle(yaw, want_yaw, clampf(real * 6.0, 0.0, 1.0))
		var dist := Vector2(to.x, to.z).length()
		var want_pitch := clampf(-0.12 - 1.2 / maxf(dist, 1.0) * 0.3 + (lock.global_position.y - target.global_position.y) * 0.03, -0.6, 0.2)
		pitch = lerpf(pitch, want_pitch, clampf(real * 3.0, 0.0, 1.0))

	global_position = _pivot
	if not eye:
		pitch = clampf(pitch, -1.05, 0.55)
	rotation = Vector3(pitch, yaw, 0.0)
	spring.position = Vector3(0.0 if eye else shoulder, 0.0, 0.0)
	var running := clampf((target.hspeed() - 7.0) / 3.0, 0.0, 1.0)
	_fov_kick = maxf(_fov_kick - real * 30.0, 0.0)
	var base_fov := fp_fov if eye else fov
	camera.fov = lerpf(camera.fov, base_fov + 7.0 * running + _fov_kick, 1.0 - exp(-4.0 * real))

	# Lean into sideways movement (relative to the view).
	var right := global_transform.basis.x
	var side := Vector3(target.velocity.x, 0.0, target.velocity.z).dot(Vector3(right.x, 0.0, right.z))
	_roll = lerpf(_roll, clampf(-side * (0.003 if eye else 0.006), -0.05, 0.05), 1.0 - exp(-5.0 * real))
	# Landing dip: a spring pushed down by how hard we hit the ground.
	var air := not target.is_on_floor()
	if air:
		_air_vy = minf(_air_vy, target.velocity.y)
	elif _was_air:
		if _air_vy < -7.0:
			_dip_vel -= clampf((-_air_vy - 7.0) * 0.12, 0.0, 1.4)
		_air_vy = 0.0
	_was_air = air
	_dip_vel += (-_dip * 90.0 - _dip_vel * 14.0) * real
	_dip += _dip_vel * real
	_punch = _punch.lerp(Vector2.ZERO, clampf(real * 9.0, 0.0, 1.0))

	# Shake: squared trauma, smooth noise, decays in real time.
	_noise_t += real * 30.0
	var s := _trauma * _trauma * (0.45 if eye else 1.0)
	camera.h_offset = s * 0.25 * sin(_noise_t * 1.7) + _punch.x * 0.3
	camera.v_offset = s * 0.25 * sin(_noise_t * 2.3 + 1.0) + _punch.y * 0.3 + _dip
	camera.rotation.z = s * 0.06 * sin(_noise_t * 1.3 + 2.0) + _roll - _punch.x * 0.04
	_trauma = maxf(_trauma - real * 1.8, 0.0)


## Camera yaw for steering (the stick is relative to the view).
func view_yaw() -> float:
	return yaw
