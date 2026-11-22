class_name LoadingScreen
extends CanvasLayer
## Every scene change goes through here (doc: Loading screen design):
## a block fighter on a turntable, the next arena's title card, a progress
## bar driven by the real threaded load, rotating tips, at least 0.8 s on
## screen. A scene that has `ready_to_play` (the match) keeps it up while
## it bakes navigation and warms up shaders, then gets `begin()`.

const MIN_TIME := 0.8
const TIPS := [
	"Catch a thrown sword to throw it back 1.5x faster.",
	"Damage comes from blade speed: a sprinting swing hits hardest.",
	"Hold ATTACK to charge a spinning heavy slash.",
	"Knock them off the edge: the kill is yours if you hit them in the last 5 seconds.",
	"LOCK keeps your opponent in view and aims your throws.",
	"The last 30 seconds: every kill counts double.",
	"Roll through a swing: dodging makes you untouchable for a moment.",
	"Jump twice to flip; jump at a wall to kick off it.",
]

var _path := ""
var _scene: Node
var _phase := "load"
var _start := 0
var _bar: ProgressBar
var _tip: Label
var _tip_i := 0
var _tip_t := 0.0
var _turntable: Node3D
var _root: Control
var _progress := [0.0]


func start(path: String, card: Dictionary) -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_path = path
	_start = Time.get_ticks_msec()
	_tip_i = randi() % TIPS.size()
	_build(card)
	ResourceLoader.load_threaded_request(path, "PackedScene", true)


func _build(card: Dictionary) -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# Turntable fighter (own little 3D world).
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.anchor_left = 0.5
	svc.anchor_right = 1.0
	svc.anchor_bottom = 1.0
	svc.offset_bottom = -120
	_root.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 3.4)
	cam.fov = 42
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2, 2, 2)
	fill.light_color = Color(1.0, 0.6, 0.3)
	fill.light_energy = 1.4
	vp.add_child(fill)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.5, 0.55, 0.65)
	we.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(we)
	_turntable = Node3D.new()
	vp.add_child(_turntable)
	var body := BlockBody.new()
	_turntable.add_child(body)
	body.setup(Registry.skin(randi() % 4), false)
	var w := MeshInstance3D.new()
	w.mesh = Registry.weapon(&"sword").mesh()
	body.socket_r.add_child(w)
	body.anim.play([&"Sword_Idle", &"Victory", &"Heavy_Charge"].pick_random())
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.0
	cyl.height = 0.16
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.22, 0.28)
	cyl.material = pm
	plinth.mesh = cyl
	plinth.position.y = -0.08
	_turntable.add_child(plinth)

	var left := VBoxContainer.new()
	left.anchor_top = 0.5
	left.anchor_bottom = 0.5
	left.offset_left = 90
	left.offset_right = 820
	left.offset_top = -200
	left.offset_bottom = 120
	_root.add_child(left)
	var t := UiTheme.title(str(card.get("title", "")), 84, card.get("color", UiTheme.ACCENT))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(t)
	var sub := Label.new()
	sub.text = str(card.get("subtitle", ""))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(1, 1, 1, 0.75)
	left.add_child(sub)

	_bar = ProgressBar.new()
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.anchor_right = 1.0
	_bar.offset_left = 90
	_bar.offset_right = -90
	_bar.offset_top = -100
	_bar.offset_bottom = -76
	_bar.show_percentage = false
	_bar.max_value = 1.0
	var bar_fill := (UiTheme.get_theme().get_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar_fill.bg_color = UiTheme.ACCENT
	_bar.add_theme_stylebox_override(&"fill", bar_fill)
	_root.add_child(_bar)
	_tip = Label.new()
	_tip.anchor_top = 1.0
	_tip.anchor_bottom = 1.0
	_tip.anchor_right = 1.0
	_tip.offset_left = 90
	_tip.offset_right = -90
	_tip.offset_top = -170
	_tip.offset_bottom = -112
	_tip.add_theme_font_size_override(&"font_size", 30)
	_tip.text = TIPS[_tip_i]
	_root.add_child(_tip)


func _process(delta: float) -> void:
	_turntable.rotate_y(delta * 0.6)
	_tip_t += delta
	if _tip_t > 2.8:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % TIPS.size()
		_tip.text = TIPS[_tip_i]
	match _phase:
		"load":
			var status := ResourceLoader.load_threaded_get_status(_path, _progress)
			_bar.value = lerpf(_bar.value, float(_progress[0]) * 0.5, 0.3)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_swap((ResourceLoader.load_threaded_get(_path) as PackedScene))
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Could not load " + _path)
				_phase = "done"
		"prepare":
			_bar.value = lerpf(_bar.value, 0.5 + 0.5 * float(_scene.get("load_progress")), 0.2)
		"done":
			_bar.value = lerpf(_bar.value, 1.0, 0.4)
			if Time.get_ticks_msec() - _start >= int(MIN_TIME * 1000.0):
				_finish()


func _swap(packed: PackedScene) -> void:
	var tree := get_tree()
	if tree.current_scene:
		tree.current_scene.queue_free()
	_scene = packed.instantiate()
	tree.root.add_child(_scene)
	tree.current_scene = _scene
	if _scene.has_signal(&"ready_to_play"):
		_phase = "prepare"
		_scene.connect(&"ready_to_play", func() -> void: _phase = "done", CONNECT_ONE_SHOT)
	else:
		_phase = "done"


func _finish() -> void:
	_phase = "fading"
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		if _scene and _scene.has_method(&"begin"):
			_scene.call(&"begin")
		queue_free())
