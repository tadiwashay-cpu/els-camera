class_name TouchControls
extends Control
## On-screen controls (doc: Touch controls).
##   left:  Godot 4.7's VirtualJoystick, floating (push far to sprint)
##   right: swipe anywhere to look; ATTACK (hold to charge), JUMP,
##          THROW/CATCH, DODGE, LOCK
## Size and opacity come from Settings.

const BUTTONS := [
	# action, label, offset from the bottom-right corner, radius
	[&"attack", "ATTACK", Vector2(-150, -150), 94.0],
	[&"jump", "JUMP", Vector2(-340, -112), 68.0],
	[&"throw", "THROW", Vector2(-150, -352), 62.0],
	[&"dodge", "DODGE", Vector2(-318, -292), 58.0],
	[&"lock_on", "LOCK", Vector2(-108, -520), 48.0],
	[&"block", "BLOCK", Vector2(-486, -236), 56.0],
	[&"power", "POWER", Vector2(-322, -470), 56.0],
	[&"swap", "SWAP", Vector2(-500, -420), 52.0],
]

var joystick: VirtualJoystick
var catch_hint := false           # an incoming weapon: THROW reads CATCH
var power_ready := false
var swap_available := false
var _look := Vector2.ZERO
var _look_index := -1
var _held: Dictionary = {}        # touch index -> button index
var _scale := 1.0
var _alpha := 0.6


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or bool(Save.setting("touch_on_desktop"))
	_scale = float(Save.setting("touch_scale"))
	_alpha = float(Save.setting("touch_opacity"))
	joystick = VirtualJoystick.new()
	joystick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	joystick.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	joystick.joystick_size = 230.0 * _scale
	joystick.tip_size = 96.0 * _scale
	joystick.deadzone_ratio = 0.1
	joystick.clampzone_ratio = 1.0
	joystick.action_left = &"move_left"
	joystick.action_right = &"move_right"
	joystick.action_up = &"move_forward"
	joystick.action_down = &"move_back"
	joystick.modulate.a = _alpha + 0.2
	joystick.anchor_left = 0.0
	joystick.anchor_top = 0.3
	joystick.anchor_right = 0.42
	joystick.anchor_bottom = 1.0
	add_child(joystick)


func take_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


func _button_pos(i: int) -> Vector2:
	var b: Array = BUTTONS[i]
	return size + (b[2] as Vector2) * _scale


func _button_radius(i: int) -> float:
	return float(BUTTONS[i][3]) * _scale


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.x < size.x * 0.42:
				return                         # the joystick's side
			for i in BUTTONS.size():
				if BUTTONS[i][0] == &"swap" and not swap_available:
					continue
				if t.position.distance_to(_button_pos(i)) <= _button_radius(i) * 1.15:
					_held[t.index] = i
					Input.action_press(BUTTONS[i][0])
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if _look_index == -1 and t.position.y > 90.0:
				_look_index = t.index
		else:
			if _held.has(t.index):
				Input.action_release(BUTTONS[_held[t.index]][0])
				_held.erase(t.index)
				queue_redraw()
			if t.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _look_index:
			_look += d.relative * 1.4


func release_all() -> void:
	for idx: int in _held:
		Input.action_release(BUTTONS[_held[idx]][0])
	_held.clear()
	_look_index = -1


func set_swap(on: bool) -> void:
	if on != swap_available:
		swap_available = on
		queue_redraw()


func set_power_ready(on: bool) -> void:
	if on != power_ready:
		power_ready = on
		queue_redraw()


func set_catch_hint(on: bool) -> void:
	if on != catch_hint:
		catch_hint = on
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in BUTTONS.size():
		if BUTTONS[i][0] == &"swap" and not swap_available:
			continue
		var p := _button_pos(i)
		var r := _button_radius(i)
		var pressed := _held.values().has(i)
		var accent := Color(1.0, 0.6, 0.15) if not (i == 2 and catch_hint) else Color(0.35, 1.0, 0.55)
		if BUTTONS[i][0] == &"power":
			accent = Color(1.0, 0.9, 0.25) if power_ready else Color(0.45, 0.45, 0.5)
		draw_circle(p, r, Color(0.04, 0.05, 0.07, _alpha * 0.75) if not pressed else Color(accent, _alpha))
		draw_arc(p, r, 0, TAU, 48, Color(accent, minf(_alpha + 0.25, 1.0)), 4.0 * _scale, true)
		var label: String = BUTTONS[i][1]
		if i == 2 and catch_hint:
			label = "CATCH"
		var fs := int((26.0 if r > 70.0 else 21.0) * _scale)
		draw_string(font, p + Vector2(-r, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, minf(_alpha + 0.35, 1.0)))
