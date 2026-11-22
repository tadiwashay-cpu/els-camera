class_name PlayerInput
extends Node
## Reads keyboard, mouse, gamepad and the touch controls into the local
## player's FighterInput, and steers the camera.

var fighter: Fighter
var camera: CameraRig
var touch: TouchControls
var enabled := true
var _mouse_captured := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or camera == null:
		return
	if event is InputEventMouseMotion and _mouse_captured:
		camera.add_look((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not _mouse_captured \
			and not DisplayServer.is_touchscreen_available() and (touch == null or not touch.visible):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = true


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false


func _physics_process(_delta: float) -> void:
	if fighter == null or camera == null:
		return
	var inp := fighter.input
	if not enabled:
		inp.move = Vector2.ZERO
		inp.attack_held = false
		return
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	var keyboard := Input.is_action_pressed(&"move_left") or Input.is_action_pressed(&"move_right") \
		or Input.is_action_pressed(&"move_forward") or Input.is_action_pressed(&"move_back")
	if keyboard and stick.length() > 0.5 and not _pad_moving():
		stick = stick.normalized() * 0.85      # keys run; Shift sprints
	inp.move = stick.limit_length(1.0)
	inp.sprint = Input.is_action_pressed(&"sprint")
	inp.aim_yaw = camera.view_yaw()
	inp.attack_held = Input.is_action_pressed(&"attack")
	inp.jump_held = Input.is_action_pressed(&"jump")
	inp.block_held = Input.is_action_pressed(&"block")
	if Input.is_action_just_pressed(&"power"):
		inp.press(&"power")
	if Input.is_action_just_pressed(&"jump"):
		inp.press(&"jump")
	if Input.is_action_just_pressed(&"throw"):
		inp.press(&"throw")
	if Input.is_action_just_pressed(&"dodge"):
		inp.press(&"dodge")
	if Input.is_action_just_pressed(&"lock_on"):
		_toggle_lock()
	if inp.target and (not is_instance_valid(inp.target) or not (inp.target as Fighter).alive):
		inp.target = null
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length() > 0.1:
		camera.add_look(look * 14.0)
	if touch:
		camera.add_look(touch.take_look())


func _pad_moving() -> bool:
	return absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) > 0.2 or absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) > 0.2


## Locks on to the enemy nearest the centre of the view, or lets go.
func _toggle_lock() -> void:
	var inp := fighter.input
	if inp.target:
		inp.target = null
		return
	var best: Fighter
	var best_score := -INF
	var fwd := -camera.camera.global_basis.z
	for f: Fighter in fighter.world.fighters:
		if f == fighter or not f.alive:
			continue
		var to := f.global_position + Vector3.UP - camera.camera.global_position
		var dist := to.length()
		if dist > 30.0:
			continue
		var score := fwd.dot(to.normalized()) * 2.0 - dist / 30.0
		if score > best_score:
			best_score = score
			best = f
	inp.target = best
