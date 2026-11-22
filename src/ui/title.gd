extends Node3D
## Title screen: two block fighters squaring off on a plinth under an
## orbiting camera, the logo, and the Play / Settings panels.
##   Play -> match setup (time, bots, difficulty, weapon, kill target) -> loading screen -> match

var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _main: Control
var _setup: Control
var _settings: Control
var _coins: Label


func _ready() -> void:
	_build_world()
	_build_ui()
	_show(_main)


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var m := ProceduralSkyMaterial.new()
	m.sky_top_color = Color(0.16, 0.22, 0.4)
	m.sky_horizon_color = Color(0.95, 0.6, 0.38)
	m.ground_horizon_color = Color(0.5, 0.36, 0.3)
	m.ground_bottom_color = Color(0.1, 0.1, 0.14)
	sky.sky_material = m
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, 60, 0)
	sun.light_color = Color(1.0, 0.78, 0.6)
	sun.shadow_enabled = true
	add_child(sun)
	var plinth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(7, 1, 7)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.28, 0.3, 0.36)
	box.material = pm
	plinth.mesh = box
	plinth.position.y = -0.5
	add_child(plinth)
	for i in 2:
		var b := BlockBody.new()
		add_child(b)
		b.setup(Registry.skin(i * 1), false)
		b.position = Vector3(-1.1 if i == 0 else 1.1, 0, 0)
		b.rotation.y = PI * 0.5 if i == 0 else -PI * 0.5
		var w := MeshInstance3D.new()
		w.mesh = Registry.weapon(&"sword").mesh()
		b.socket_r.add_child(w)
		b.anim.play(&"Sword_Idle" if i == 0 else &"Heavy_Charge")
		b.anim.seek(randf() * 1.5, true)
	_cam = Camera3D.new()
	_cam.fov = 45
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta * 0.18
	_cam.position = Vector3(sin(_t) * 6.0, 2.0, cos(_t) * 6.0)
	_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	if _coins:
		_coins.text = "%d COINS" % int(Save.data["coins"])


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UiTheme.get_theme()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_coins = UiTheme.title("", 30, Color(1, 0.85, 0.3))
	_coins.anchor_left = 1.0
	_coins.anchor_right = 1.0
	_coins.offset_left = -360
	_coins.offset_right = -40
	_coins.offset_top = 30
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(_coins)
	var ver := Label.new()
	ver.text = "v%s  ·  Phase 1 playtest" % Game.version()
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 30
	ver.offset_top = -50
	ver.add_theme_font_size_override(&"font_size", 22)
	ver.modulate = Color(1, 1, 1, 0.6)
	_ui.add_child(ver)
	_main = _main_menu()
	_setup = _match_setup()
	_settings = _settings_panel()


func _panel(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 80
	box.offset_right = 700
	box.offset_top = -380
	box.offset_bottom = 400
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ui.add_child(box)
	if title != "":
		var t := UiTheme.title(title, 56, UiTheme.ACCENT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(t)
	return box


func _show(which: Control) -> void:
	for c in [_main, _setup, _settings]:
		c.visible = c == which
	for c in which.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus.call_deferred()
			break


func _main_menu() -> Control:
	var box := _panel("")
	var logo := UiTheme.title("BLOCK DUELIST", 96, Color.WHITE)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(logo)
	var logo2 := UiTheme.title("3D", 64, UiTheme.ACCENT)
	logo2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(logo2)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	box.add_child(spacer)
	var play := UiTheme.big_button("PLAY")
	play.pressed.connect(func() -> void: _show(_setup))
	box.add_child(play)
	var mp := UiTheme.big_button("MULTIPLAYER  (soon)")
	mp.disabled = true
	mp.tooltip_text = "LAN and hotspot play arrive in Phase 3"
	box.add_child(mp)
	var cust := UiTheme.big_button("CUSTOMIZE  (soon)")
	cust.disabled = true
	box.add_child(cust)
	var st := UiTheme.big_button("SETTINGS")
	st.pressed.connect(func() -> void: _show(_settings))
	box.add_child(st)
	return box


func _option(box: VBoxContainer, label: String, items: Array, selected: int, on_pick: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 260
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(300, 64)
	for it: String in items:
		ob.add_item(it)
	ob.select(selected)
	ob.item_selected.connect(on_pick)
	row.add_child(ob)
	box.add_child(row)
	return ob


func _match_setup() -> Control:
	var cfg := Game.match_config
	var box := _panel("KILL RACE")
	var sub := Label.new()
	sub.text = "Most kills when the clock hits zero wins."
	sub.modulate = Color(1, 1, 1, 0.75)
	box.add_child(sub)
	var times: Array = []
	for m in MatchConfig.TIMES:
		times.append("%d min" % m)
	_option(box, "Match time", times, MatchConfig.TIMES.find(int(cfg.minutes)), func(i: int) -> void: cfg.minutes = MatchConfig.TIMES[i])
	_option(box, "Opponents", ["1 bot", "2 bots", "3 bots"], cfg.bots - 1, func(i: int) -> void: cfg.bots = i + 1)
	_option(box, "Difficulty", ["Easy", "Normal", "Hard"], cfg.difficulty, func(i: int) -> void: cfg.difficulty = i)
	var starts := [&"sword", &"random", &"fists"]
	_option(box, "Start with", ["Sword", "Random weapon", "Fists"], maxi(starts.find(cfg.start_weapon), 0),
		func(i: int) -> void: cfg.start_weapon = starts[i])
	var targets := [0, 5, 10, 20]
	_option(box, "Kill target", ["Off", "First to 5", "First to 10", "First to 20"], targets.find(cfg.kill_target),
		func(i: int) -> void: cfg.kill_target = targets[i])
	var power_names: Array = []
	for id in FighterPowers.IDS:
		power_names.append(FighterPowers.INFO[id]["name"])
	_option(box, "Power", power_names, FighterPowers.IDS.find(cfg.power), func(i: int) -> void: cfg.power = FighterPowers.IDS[i])
	_option(box, "Arena", ["Blockout Yard"], 0, func(_i: int) -> void: pass)
	var go := UiTheme.big_button("START")
	go.pressed.connect(func() -> void:
		Audio.play(&"ui_confirm")
		Game.start_match())
	box.add_child(go)
	var back := UiTheme.big_button("BACK")
	back.pressed.connect(func() -> void: _show(_main))
	box.add_child(back)
	return box


func _slider(box: VBoxContainer, label: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 260
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Save.setting(key))
	s.custom_minimum_size = Vector2(300, 64)
	s.value_changed.connect(func(v: float) -> void:
		Save.set_setting(key, v)
		if key == "master_volume":
			Audio.set_master_volume(v))
	row.add_child(s)
	box.add_child(row)


func _toggle(box: VBoxContainer, label: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = bool(Save.setting(key))
	c.custom_minimum_size.y = 64
	c.toggled.connect(func(on: bool) -> void: Save.set_setting(key, on))
	box.add_child(c)


func _settings_panel() -> Control:
	var box := _panel("SETTINGS")
	_option(box, "Graphics", ["Low", "Medium", "High"], int(Save.setting("quality")), func(i: int) -> void:
		Save.set_setting("quality", i)
		Game.apply_graphics())
	_slider(box, "Look speed", "look_sensitivity", 0.3, 2.5, 0.05)
	_slider(box, "Aim assist", "aim_assist", 0.0, 1.0, 0.05)
	_slider(box, "Volume", "master_volume", 0.0, 1.0, 0.05)
	_slider(box, "Button size", "touch_scale", 0.7, 1.4, 0.05)
	_slider(box, "Button opacity", "touch_opacity", 0.2, 1.0, 0.05)
	_toggle(box, "Show FPS", "show_fps")
	_toggle(box, "Vibration", "vibration")
	_toggle(box, "Touch controls on desktop", "touch_on_desktop")
	var back := UiTheme.big_button("BACK")
	back.pressed.connect(func() -> void: _show(_main))
	box.add_child(back)
	return box
