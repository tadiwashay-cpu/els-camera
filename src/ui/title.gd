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
var _mp: Control
var _lobby: Control
var _coins: Label
var _mp_status: Label
var _games_box: VBoxContainer
var _lobby_players: VBoxContainer
var _lobby_info: Label
var _lobby_opts: VBoxContainer
var _lobby_start: Button


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
	ver.text = "v%s  ·  Phase 3 playtest" % Game.version()
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
	_mp = _multiplayer_panel()
	_lobby = _lobby_panel()
	Net.lobby_changed.connect(_refresh_lobby)
	Net.status_changed.connect(func(t: String) -> void: _mp_status.text = t)
	Net.left.connect(func(reason: String) -> void:
		_mp_status.text = reason
		if is_instance_valid(_mp):
			_show(_mp))
	Net.discovery.games_changed.connect(_refresh_games)
	if Net.active and not Net.in_match:
		_show.call_deferred(_lobby)


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
	for c in [_main, _setup, _settings, _mp, _lobby]:
		if c:
			c.visible = c == which
	if which == _mp:
		Net.discovery.start_listening()
		_refresh_games()
	elif which != _lobby:
		if not Net.is_host:
			Net.discovery.stop()
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
	var mp := UiTheme.big_button("MULTIPLAYER")
	mp.pressed.connect(func() -> void: _show(_mp))
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
	var arena_ids: Array = Registry.arena_ids()
	var arena_names: Array = []
	for id: StringName in arena_ids:
		arena_names.append(Registry.arena(id).display_name)
	arena_ids.append(&"random")
	arena_names.append("Random")
	var saved: Variant = Save.setting("arena")
	if saved is String and arena_ids.has(StringName(saved)):
		cfg.arena_choice = StringName(saved)
	_option(box, "Arena", arena_names, maxi(arena_ids.find(cfg.arena_choice), 0), func(i: int) -> void:
		cfg.arena_choice = arena_ids[i]
		Save.set_setting("arena", String(arena_ids[i])))
	_option(box, "Hazards", ["On", "Off"], 0 if cfg.hazards else 1, func(i: int) -> void: cfg.hazards = i == 0)
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


# ---------------------------------------------------------- multiplayer

## Host or join a game on the same Wi-Fi or phone hotspot.
func _multiplayer_panel() -> Control:
	var box := _panel("MULTIPLAYER")
	var sub := Label.new()
	sub.text = "Same Wi-Fi or a phone's hotspot. Up to 4 fighters."
	sub.modulate = Color(1, 1, 1, 0.75)
	box.add_child(sub)
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Your name"
	l.custom_minimum_size.x = 260
	row.add_child(l)
	var name_edit := LineEdit.new()
	name_edit.text = str(Save.setting("player_name"))
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(300, 64)
	name_edit.text_changed.connect(func(t: String) -> void: Save.set_setting("player_name", t.strip_edges() if t.strip_edges() != "" else "Player"))
	row.add_child(name_edit)
	box.add_child(row)
	var host := UiTheme.big_button("HOST A GAME")
	host.pressed.connect(func() -> void:
		Audio.play(&"ui_confirm")
		if Net.host(str(Save.setting("player_name")), Game.match_config.power) == OK:
			_show(_lobby))
	box.add_child(host)
	var found := Label.new()
	found.text = "Games nearby:"
	box.add_child(found)
	_games_box = VBoxContainer.new()
	box.add_child(_games_box)
	var ip_row := HBoxContainer.new()
	var ip := LineEdit.new()
	ip.placeholder_text = "Host's IP, e.g. 192.168.43.1"
	ip.text = str(Save.setting("last_ip")) if Save.setting("last_ip") != null else ""
	ip.custom_minimum_size = Vector2(380, 64)
	ip_row.add_child(ip)
	var join := UiTheme.big_button("JOIN", 180)
	join.pressed.connect(func() -> void:
		if ip.text.strip_edges() == "":
			return
		Save.set_setting("last_ip", ip.text.strip_edges())
		_join(ip.text.strip_edges()))
	ip_row.add_child(join)
	box.add_child(ip_row)
	_mp_status = Label.new()
	_mp_status.modulate = Color(1, 0.85, 0.5)
	_mp_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mp_status)
	var back := UiTheme.big_button("BACK")
	back.pressed.connect(func() -> void:
		Net.leave()
		_show(_main))
	box.add_child(back)
	return box


func _join(ip: String) -> void:
	Audio.play(&"ui_confirm")
	if Net.join(ip, str(Save.setting("player_name")), Game.match_config.power) == OK:
		_show(_lobby)


func _refresh_games() -> void:
	if _games_box == null:
		return
	for c in _games_box.get_children():
		c.queue_free()
	if Net.discovery.games.is_empty():
		var none := Label.new()
		none.text = "  Looking... (or type the host's IP below)"
		none.modulate = Color(1, 1, 1, 0.6)
		_games_box.add_child(none)
		return
	for ip: String in Net.discovery.games:
		var g: Dictionary = Net.discovery.games[ip]
		var b := UiTheme.big_button("%s   %d/%d" % [str(g.get("name", "?")), int(g.get("players", 1)), int(g.get("max", 4))], 520)
		b.disabled = bool(g.get("in_match", false)) or str(g.get("version", "")) != Game.version()
		b.pressed.connect(func() -> void: _join(ip))
		_games_box.add_child(b)


## Who's in, the host's settings, START (host) or waiting (joiners).
func _lobby_panel() -> Control:
	var box := _panel("LOBBY")
	_lobby_info = Label.new()
	_lobby_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_info.modulate = Color(1, 1, 1, 0.8)
	box.add_child(_lobby_info)
	_lobby_players = VBoxContainer.new()
	box.add_child(_lobby_players)
	_lobby_opts = VBoxContainer.new()
	box.add_child(_lobby_opts)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	_lobby_start = UiTheme.big_button("START", 300)
	_lobby_start.pressed.connect(func() -> void:
		Audio.play(&"ui_confirm")
		Net.start_match())
	row.add_child(_lobby_start)
	var leave := UiTheme.big_button("LEAVE", 240)
	leave.pressed.connect(func() -> void:
		Net.leave()
		_show(_mp))
	row.add_child(leave)
	box.add_child(row)
	return box


func _refresh_lobby() -> void:
	if _lobby == null:
		return
	for c in _lobby_players.get_children():
		c.queue_free()
	for id: int in Net.players:
		var p: Dictionary = Net.players[id]
		var l := Label.new()
		l.text = "  %s%s%s" % [str(p["name"]), "   (host)" if id == 1 else "", "   (you)" if id == Net.my_id() else ""]
		l.add_theme_color_override(&"font_color", Registry.skin(int(p.get("skin", 0))).shirt.lightened(0.35))
		l.add_theme_font_size_override(&"font_size", 30)
		_lobby_players.add_child(l)
	var s := Net.settings
	var arena_name := "Random" if str(s.get("arena_choice", "")) == "random" else Registry.arena(StringName(str(s.get("arena_choice", "blockout_yard")))).display_name
	var summary := "%d min · %s · %d bot%s · %s" % [int(round(float(s.get("minutes", 3.0)))), arena_name, int(s.get("bots", 0)),
		"" if int(s.get("bots", 0)) == 1 else "s", MatchConfig.DIFFICULTIES[clampi(int(s.get("difficulty", 1)), 0, 2)]]
	if Net.is_host:
		_lobby_info.text = "Others join from MULTIPLAYER on the same Wi-Fi/hotspot, or type: %s" % ", ".join(Net.local_ips())
	else:
		_lobby_info.text = "Waiting for the host to start.   " + summary
	_lobby_start.visible = Net.is_host
	_lobby_opts.visible = Net.is_host
	if Net.is_host and _lobby_opts.get_child_count() == 0:
		_build_lobby_options()


func _build_lobby_options() -> void:
	var s := Net.settings
	var times: Array = []
	for mins in MatchConfig.TIMES:
		times.append("%d min" % mins)
	_option(_lobby_opts, "Match time", times, maxi(MatchConfig.TIMES.find(int(round(float(s.get("minutes", 3.0))))), 0),
		func(i: int) -> void: Net.set_setting("minutes", float(MatchConfig.TIMES[i])))
	_option(_lobby_opts, "Bots", ["None", "1 bot", "2 bots", "3 bots"], clampi(int(s.get("bots", 1)), 0, 3),
		func(i: int) -> void: Net.set_setting("bots", i))
	_option(_lobby_opts, "Bot skill", ["Easy", "Normal", "Hard"], clampi(int(s.get("difficulty", 1)), 0, 2),
		func(i: int) -> void: Net.set_setting("difficulty", i))
	var ids: Array = Registry.arena_ids()
	var names: Array = []
	for id: StringName in ids:
		names.append(Registry.arena(id).display_name)
	ids.append(&"random")
	names.append("Random")
	_option(_lobby_opts, "Arena", names, maxi(ids.find(StringName(str(s.get("arena_choice", "blockout_yard")))), 0),
		func(i: int) -> void: Net.set_setting("arena_choice", String(ids[i])))
	var starts := ["sword", "random", "fists"]
	_option(_lobby_opts, "Start with", ["Sword", "Random weapon", "Fists"], maxi(starts.find(str(s.get("start_weapon", "sword"))), 0),
		func(i: int) -> void: Net.set_setting("start_weapon", starts[i]))
	_option(_lobby_opts, "Hazards", ["On", "Off"], 0 if bool(s.get("hazards", true)) else 1,
		func(i: int) -> void: Net.set_setting("hazards", i == 0))


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
