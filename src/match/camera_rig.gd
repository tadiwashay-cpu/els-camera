class_name CameraRig
extends Node3D
## Third-person camera over the right shoulder (doc: Camera). A SpringArm3D
## pulls in so walls never block the view; lock-on orbits to keep the
## target in frame; trauma-based shake for hits.

@export var distance := 3.9
@export var shoulder := 0.62
@export var height := 1.58
@export var fov := 68.0

var target: Fighter
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
	pitch = clampf(pitch - delta_px.y * s, -1.05, 0.55)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func kick_fov(amount: float) -> void:
	_fov_kick = maxf(_fov_kick, amount)


func snap() -> void:
	_pivot_set = false


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var real := delta / maxf(Engine.time_scale, 0.02)
	var goal := target.global_position + Vector3.UP * height
	if not _pivot_set or _pivot.distance_to(goal) > 15.0:
		_pivot = goal
		_pivot_set = true
	_pivot.x = lerpf(_pivot.x, goal.x, clampf(real * 12.0, 0.0, 1.0))
	_pivot.z = lerpf(_pivot.z, goal.z, clampf(real * 12.0, 0.0, 1.0))
	_pivot.y = lerpf(_pivot.y, goal.y, clampf(real * 7.0, 0.0, 1.0))

	var lock := target.locked_target()
	if lock:
		var to := lock.global_position - target.global_position
		var want_yaw := atan2(-to.x, -to.z)
		yaw = lerp_angle(yaw, want_yaw, clampf(real * 6.0, 0.0, 1.0))
		var dist := Vector2(to.x, to.z).length()
		var want_pitch := clampf(-0.12 - 1.2 / maxf(dist, 1.0) * 0.3 + (lock.global_position.y - target.global_position.y) * 0.03, -0.6, 0.2)
		pitch = lerpf(pitch, want_pitch, clampf(real * 3.0, 0.0, 1.0))

	global_position = _pivot
	rotation = Vector3(pitch, yaw, 0.0)
	spring.position = Vector3(shoulder, 0.0, 0.0)
	var running := clampf((target.hspeed() - 7.0) / 3.0, 0.0, 1.0)
	_fov_kick = maxf(_fov_kick - real * 30.0, 0.0)
	camera.fov = lerpf(camera.fov, fov + 7.0 * running + _fov_kick, clampf(real * 4.0, 0.0, 1.0))

	# Shake: squared trauma, smooth noise, decays in real time.
	_noise_t += real * 30.0
	var s := _trauma * _trauma
	camera.h_offset = s * 0.25 * sin(_noise_t * 1.7)
	camera.v_offset = s * 0.25 * sin(_noise_t * 2.3 + 1.0)
	camera.rotation.z = s * 0.06 * sin(_noise_t * 1.3 + 2.0)
	_trauma = maxf(_trauma - real * 1.8, 0.0)


## Camera yaw for steering (the stick is relative to the view).
func view_yaw() -> float:
	return yaw
