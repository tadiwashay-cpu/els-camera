extends Node
## Global game state: the match about to be played, scene changes through
## the loading screen, graphics presets, the input map and time effects
## (hit-stop, slow motion).

const TITLE_SCENE := "res://src/ui/title.tscn"
const MATCH_SCENE := "res://src/match/match.tscn"

## Physics layers (see project settings > layer names).
const L_WORLD := 1
const L_FIGHTERS := 2
const L_WEAPONS := 4
const L_RAGDOLL := 8
const L_HITBOX := 16
const L_TRIGGERS := 32

## Graphics presets (doc: Performance on the Redmi Pad 2). `scale` is the
## 3D render scale; the HUD always draws at full resolution.
const PRESETS: Array[Dictionary] = [
	{"name": "LOW", "scale": 0.5, "fps": 30, "shadow": false, "shadow_size": 1024, "glow": false, "detail": 0.25, "far": 70.0},
	{"name": "MEDIUM", "scale": 0.6, "fps": 60, "shadow": true, "shadow_size": 1024, "glow": true, "detail": 0.6, "far": 110.0},
	{"name": "HIGH", "scale": 0.75, "fps": 60, "shadow": true, "shadow_size": 2048, "glow": true, "detail": 1.0, "far": 160.0},
]

signal settings_changed

## What the next match is (filled by the match setup screen).
var match_config := MatchConfig.new()

var _loading: LoadingScreen
var _hitstop_until := 0
var _slowmo_until := 0
var _slowmo_scale := 1.0
## Dynamic resolution: steps the render scale down when frames run long.
var _dyn_scale := 1.0
var _slow_frames := 0
var _fast_frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	apply_graphics()


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


# ---------------------------------------------------------------- scenes

## Changes scene behind the loading screen. `card` is shown on it:
## {"title": "BLOCKOUT YARD", "color": Color, "subtitle": "..."}.
func goto_scene(path: String, card: Dictionary = {}) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if _loading and is_instance_valid(_loading):
		return
	_loading = (load("res://src/ui/loading_screen.tscn") as PackedScene).instantiate() as LoadingScreen
	get_tree().root.add_child(_loading)
	_loading.start(path, card)


func goto_title() -> void:
	goto_scene(TITLE_SCENE, {"title": "BLOCK DUELIST 3D", "color": Color(1.0, 0.55, 0.15)})


func start_match() -> void:
	var arena := Registry.pick_arena(match_config.arena_choice)
	match_config.arena_id = arena.id
	goto_scene(MATCH_SCENE, {"title": arena.display_name.to_upper(), "color": arena.title_color, "subtitle": arena.tagline})


# ------------------------------------------------------------- time juice

## Freezes the game for a few milliseconds so a heavy hit "lands".
func hit_stop(ms: int) -> void:
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + ms)


## Everything runs at `scale` speed for `seconds` of real time.
func slow_motion(scale: float, seconds: float) -> void:
	_slowmo_scale = scale
	_slowmo_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var want := 1.0
	if now < _slowmo_until:
		want = _slowmo_scale
	if now < _hitstop_until:
		want = 0.02
	Engine.time_scale = want
	_govern_resolution(delta / maxf(Engine.time_scale, 0.02))


func _govern_resolution(real_delta: float) -> void:
	# Frames over 20 ms for a while: drop the render scale 0.05 (doc rule);
	# plenty of headroom for a while: give it back.
	if get_tree().paused:
		return
	if real_delta > 0.020 and preset()["fps"] >= 60:
		_slow_frames += 1
		_fast_frames = 0
	elif real_delta < 0.013:
		_fast_frames += 1
		_slow_frames = 0
	if _slow_frames > 90:
		_slow_frames = 0
		_dyn_scale = maxf(_dyn_scale - 0.08, 0.6)
		_apply_scale()
	elif _fast_frames > 600 and _dyn_scale < 1.0:
		_fast_frames = 0
		_dyn_scale = minf(_dyn_scale + 0.08, 1.0)
		_apply_scale()


# --------------------------------------------------------------- graphics

func preset() -> Dictionary:
	return PRESETS[clampi(int(Save.setting("quality")), 0, PRESETS.size() - 1)]


func apply_graphics() -> void:
	_dyn_scale = 1.0
	Engine.max_fps = int(preset()["fps"])
	_apply_scale()
	settings_changed.emit()


func _apply_scale() -> void:
	var vp := get_tree().root
	# FSR1 needs Forward+; the Mobile renderer upscales bilinearly.
	var fsr := RenderingServer.get_current_rendering_method() == "forward_plus"
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if fsr else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = clampf(float(preset()["scale"]) * _dyn_scale, 0.35, 1.0)


## Applies the preset to a match's sun and environment.
func apply_to_world(sun: DirectionalLight3D, env: Environment, camera: Camera3D) -> void:
	var p := preset()
	sun.shadow_enabled = bool(p["shadow"])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if p["name"] != "HIGH" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0 if p["name"] != "HIGH" else 60.0
	RenderingServer.directional_shadow_atlas_set_size(int(p["shadow_size"]), true)
	env.glow_enabled = bool(p["glow"])
	if camera:
		camera.far = float(p["far"])


# ------------------------------------------------------------------ input

const _KEYS := {
	&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
	&"move_forward": [KEY_W, KEY_UP], &"move_back": [KEY_S, KEY_DOWN],
	&"sprint": [KEY_SHIFT], &"attack": [KEY_J], &"jump": [KEY_SPACE], &"throw": [KEY_K],
	&"dodge": [KEY_L, KEY_CTRL], &"lock_on": [KEY_Q, KEY_TAB], &"pause": [KEY_ESCAPE, KEY_P],
	&"block": [KEY_F], &"power": [KEY_E], &"swap": [KEY_R],
	&"look_left": [], &"look_right": [], &"look_up": [], &"look_down": [],
}
const _PAD_BUTTONS := {
	&"attack": [JOY_BUTTON_X], &"jump": [JOY_BUTTON_A], &"throw": [JOY_BUTTON_Y],
	&"dodge": [JOY_BUTTON_B], &"lock_on": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_RIGHT_STICK],
	&"sprint": [JOY_BUTTON_LEFT_STICK], &"pause": [JOY_BUTTON_START], &"block": [JOY_BUTTON_LEFT_SHOULDER], &"swap": [JOY_BUTTON_DPAD_UP],
}
const _PAD_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0], &"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	&"look_left": [JOY_AXIS_RIGHT_X, -1.0], &"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"look_up": [JOY_AXIS_RIGHT_Y, -1.0], &"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	&"power": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


func _setup_inputs() -> void:
	for action: StringName in _KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: int in _KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
	for action: StringName in _PAD_BUTTONS:
		for b: int in _PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b as JoyButton
			InputMap.action_add_event(action, ev)
	for action: StringName in _PAD_AXES:
		var ev := InputEventJoypadMotion.new()
		ev.axis = _PAD_AXES[action][0]
		ev.axis_value = _PAD_AXES[action][1]
		InputMap.action_add_event(action, ev)
	# Mouse buttons only where there's no touch screen: touches are also
	# sent as mouse clicks (so menus work) and must not swing the sword.
	if not DisplayServer.is_touchscreen_available():
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"attack", mouse)
		var rmb := InputEventMouseButton.new()
		rmb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(&"throw", rmb)
		var mmb := InputEventMouseButton.new()
		mmb.button_index = MOUSE_BUTTON_MIDDLE
		InputMap.action_add_event(&"block", mmb)


func vibrate(ms: int) -> void:
	if bool(Save.setting("vibration")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
