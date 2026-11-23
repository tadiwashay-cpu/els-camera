extends Node3D
## Title screen: two block fighters squaring off on a plinth under an
## orbiting camera, the logo, and the Play / Settings panels.
##   Play -> match setup (time, bots, difficulty, weapon, kill target) -> loading screen -> match
##   Armory -> buy and equip weapons (ArmoryScreen); a fighter shows the pick.

const STARTS: Array[StringName] = [&"loadout", &"sword", &"random", &"fists"]
const START_NAMES := ["Your weapon", "Sword", "Random (owned)", "Fists"]

var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _main: Control
var _setup: Control
var _settings: Control
var _mp: Control
var _lobby: Control
var _armory: ArmoryScreen
var _locker: LockerScreen
var _controls: Control
var _bind_buttons: Dictionary = {}       # action -> [key Button, pad Button]
var _bind_status: Label
var _capture: Array = []                 # [action, "key"|"pad"] while waiting for a press
var _bodies: Array[BlockBody] = []
var _coins: Label
var _band: Control
## Armory inspect: the weapon alone, big, turned by dragging.
var _inspect: Node3D
var _inspect_mesh: MeshInstance3D
var _inspect_idle := 0.0
var _version: Label
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
		b.setup(Look.skin_data(Look.mine()) if i == 0 else Registry.skin(1), false)
		b.position = Vector3(-1.1 if i == 0 else 1.1, 0, 0)
		b.rotation.y = PI * 0.5 if i == 0 else -PI * 0.5
		var w := MeshInstance3D.new()
		w.mesh = Registry.weapon(&"sword").mesh()
		b.socket_r.add_child(w)
		b.anim.play(&"Sword_Idle" if i == 0 else &"Heavy_Charge")
		b.anim.seek(randf() * 1.5, true)
		_bodies.append(b)
	_inspect = Node3D.new()
	_inspect.position = Vector3(-1.1, 1.15, 0.0)
	_inspect.visible = false
	add_child(_inspect)
	_inspect_mesh = MeshInstance3D.new()
	_inspect.add_child(_inspect_mesh)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.2, 1.0, 2.4)
	fill.omni_range = 6.0
	fill.light_energy = 1.6
	fill.light_color = Color(1.0, 0.95, 0.9)
	_inspect.add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = 45
	add_child(_cam)
	_cam.current = true


func _process(delta: float) -> void:
	_t += delta * 0.18
	if _locker and _locker.visible:
		# The Locker: your fighter up close, turning slowly.
		var b := _bodies[0]
		b.rotation.y += delta * 0.6
		_cam.position = b.position + Vector3(0, 1.45, 4.6)
		_cam.look_at(b.position + Vector3(0, 1.15, 0), Vector3.UP)
		_cam.h_offset = 1.25
		_cam.v_offset = -0.05
	elif _armory and _armory.visible:
		# The Armory: one fighter, turning slowly, holding the selected weapon
		# (or the weapon alone, big, when inspecting).
		var b := _bodies[0]
		b.rotation.y += delta * 0.5
		b.visible = not _armory.inspecting
		_inspect.visible = _armory.inspecting
		_inspect_idle += delta
		if _inspect_idle > 2.0:
			_inspect.rotation.y += delta * 0.6
			_inspect.rotation.x = lerpf(_inspect.rotation.x, 0.0, delta * 1.5)
		if _armory.inspecting:
			_cam.position = _inspect.position + Vector3(0, 0.15, 3.4)
			_cam.look_at(_inspect.position, Vector3.UP)
			_cam.h_offset = -1.15
			_cam.v_offset = -0.55
		else:
			_cam.position = b.position + Vector3(0, 1.3, 6.0)
			_cam.look_at(b.position + Vector3(0, 1.0, 0), Vector3.UP)
			_cam.h_offset = -1.8
			_cam.v_offset = -0.95
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
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
	_band = _poster_band()
	_ui.add_child(_band)
	_ui.move_child(_band, 0)
	var ver := Label.new()
	ver.text = "v%s  ·  first person weapon, locker and new look playtest" % Game.version()
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = 30
	ver.offset_top = -50
	ver.add_theme_font_size_override(&"font_size", 22)
	ver.modulate = Color(1, 1, 1, 0.6)
	_ui.add_child(ver)
	_version = ver
	_main = _main_menu()
	_setup = _match_setup()
	_settings = _settings_panel()
	_mp = _multiplayer_panel()
	_lobby = _lobby_panel()
	_controls = _controls_panel()
	_armory = ArmoryScreen.new()
	_ui.add_child(_armory)
	_armory.back.connect(func() -> void: _show(_main))
	_armory.selected.connect(_preview_weapon)
	_armory.inspect_toggled.connect(func(_on: bool) -> void:
		_inspect.rotation = Vector3(0.0, 0.6, 0.0)
		_inspect_idle = 0.0)
	_locker = LockerScreen.new()
	_ui.add_child(_locker)
	_locker.back.connect(func() -> void: _show(_main))
	_locker.look_changed.connect(func(look: Dictionary) -> void:
		if not _bodies.is_empty():
			_bodies[0].set_skin(Look.skin_data(look)))
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
	for c in [_main, _setup, _settings, _mp, _lobby, _armory, _controls, _locker]:
		if c:
			c.visible = c == which
	var solo := which == _armory or which == _locker
	if _version:
		_version.visible = not solo
	if _band:
		_band.visible = not solo
	if _bodies.size() > 1:
		_bodies[1].visible = not solo
		if not solo:
			_bodies[0].rotation.y = PI * 0.5
			_preview_weapon(Registry.weapon(&"sword"))
		elif which == _armory:
			_preview_weapon(_armory.current)
		else:
			_preview_weapon(Registry.weapon(Armory.equipped()))
	if which == _locker:
		_locker.open()
	if which != _armory and _armory:
		_armory.stop_inspect()
		_inspect.visible = false
		_bodies[0].visible = true
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


## A slanted dark band with a yellow stripe behind the menus (poster look).
func _poster_band() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec: Array in [[-260.0, 880.0, Color(UiTheme.NAVY, 0.62)], [880.0, 904.0, UiTheme.ACCENT], [918.0, 926.0, Color(UiTheme.HOT, 0.9)]]:
		var p := Panel.new()
		var s := StyleBoxFlat.new()
		s.bg_color = spec[2]
		s.skew = Vector2(0.28, 0.0)
		p.add_theme_stylebox_override(&"panel", s)
		p.anchor_bottom = 1.0
		p.offset_left = spec[0]
		p.offset_right = spec[1]
		p.offset_top = -40
		p.offset_bottom = 40
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
	return root


## Armory inspect: drag anywhere off the panels to turn the weapon.
func _unhandled_input(event: InputEvent) -> void:
	if not (_armory and _armory.visible and _armory.inspecting):
		return
	var rel := Vector2.ZERO
	if event is InputEventScreenDrag:
		rel = (event as InputEventScreenDrag).relative
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
		rel = (event as InputEventMouseMotion).relative
	if rel != Vector2.ZERO:
		_inspect.rotation.y += rel.x * 0.012
		_inspect.rotation.x = clampf(_inspect.rotation.x + rel.y * 0.01, -1.2, 1.2)
		_inspect_idle = 0.0


## The title fighter holds `w` (the Armory's pick) in its idle pose; the
## inspect stand shows it alone, centred and scaled to fit.
func _preview_weapon(w: WeaponData) -> void:
	if _bodies.is_empty() or w == null:
		return
	if _inspect_mesh:
		_inspect_mesh.mesh = null if w.is_fists() else w.mesh()
		if _inspect_mesh.mesh:
			var box := _inspect_mesh.mesh.get_aabb()
			var fit := 1.6 / maxf(maxf(box.size.x, box.size.y), maxf(box.size.z, 0.2))
			# Lying along the screen, tip to the right.
			var lay := Basis(Vector3.BACK, -PI * 0.5) * Basis.from_scale(Vector3.ONE * fit)
			_inspect_mesh.transform = Transform3D(lay, -(lay * box.get_center()))
	var b := _bodies[0]
	for sock: BoneAttachment3D in [b.socket_r, b.socket_l]:
		for c in sock.get_children():
			c.queue_free()
	if not w.is_fists():
		var socks: Array[BoneAttachment3D] = [b.socket_l if w.hand == &"left" else b.socket_r]
		if w.both_hands:
			socks = [b.socket_r, b.socket_l]
		for sock in socks:
			var mi := MeshInstance3D.new()
			mi.mesh = w.mesh()
			sock.add_child(mi)
	var clip: StringName = w.idle_clip if w.idle_clip != &"" else (&"Idle" if w.is_fists() else &"Sword_Idle")
	if b.anim.current_animation != clip:
		b.anim.play(clip, 0.2)


func _main_menu() -> Control:
	var box := _panel("")
	var logo := UiTheme.title("BLOCK DUELIST", 96, Color.WHITE)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(logo)
	var logo2 := UiTheme.tag("3D", 60, UiTheme.ACCENT)
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
	var arm := UiTheme.big_button("ARMORY")
	arm.pressed.connect(func() -> void: _show(_armory))
	box.add_child(arm)
	var lock := UiTheme.big_button("LOCKER")
	lock.pressed.connect(func() -> void: _show(_locker))
	box.add_child(lock)
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
	var bot_counts: Array = []
	for n in range(1, Match.MAX_FIGHTERS):
		bot_counts.append("%d bot%s" % [n, "" if n == 1 else "s"])
	_option(box, "Opponents", bot_counts, clampi(cfg.bots - 1, 0, bot_counts.size() - 1), func(i: int) -> void: cfg.bots = i + 1)
	_option(box, "Difficulty", ["Easy", "Normal", "Hard"], cfg.difficulty, func(i: int) -> void: cfg.difficulty = i)
	_option(box, "Start with", START_NAMES, maxi(STARTS.find(cfg.start_weapon), 0),
		func(i: int) -> void: cfg.start_weapon = STARTS[i])
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
	var bot_counts: Array = ["None"]
	for n in range(1, Match.MAX_FIGHTERS):
		bot_counts.append("%d bot%s" % [n, "" if n == 1 else "s"])
	_option(_lobby_opts, "Bots", bot_counts, clampi(int(s.get("bots", 1)), 0, Match.MAX_FIGHTERS - 1),
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
	_option(_lobby_opts, "Start with", START_NAMES, maxi(STARTS.find(StringName(str(s.get("start_weapon", "loadout")))), 0),
		func(i: int) -> void: Net.set_setting("start_weapon", String(STARTS[i])))
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
	_option(box, "Camera", ["Third person (TPP)", "First person (FPP)"], 1 if str(Save.setting("camera_mode")) == "first" else 0,
		func(i: int) -> void: Save.set_setting("camera_mode", "first" if i == 1 else "third"))
	_option(box, "FPP motion blur", ["On", "Off"], 0 if bool(Save.setting("motion_blur")) else 1,
		func(i: int) -> void: Save.set_setting("motion_blur", i == 0))
	_toggle(box, "Show FPS", "show_fps")
	_toggle(box, "Vibration", "vibration")
	_toggle(box, "Touch controls on desktop", "touch_on_desktop")
	var controls := UiTheme.big_button("CONTROLS")
	controls.pressed.connect(func() -> void:
		_refresh_bindings()
		_show(_controls))
	box.add_child(controls)
	var back := UiTheme.big_button("BACK")
	back.pressed.connect(func() -> void: _show(_main))
	box.add_child(back)
	return box


## Controls: the touch layout editor, and every action's key and pad button
## (tap one, then press the new key or button; a clash swaps the two).
func _controls_panel() -> Control:
	var box := _panel("CONTROLS")
	var edit := UiTheme.big_button("EDIT TOUCH LAYOUT")
	edit.pressed.connect(_open_layout_editor)
	box.add_child(edit)
	var head := HBoxContainer.new()
	for spec: Array in [["Action", 290], ["Keyboard", 160], ["Gamepad", 140]]:
		var l := Label.new()
		l.text = spec[0]
		l.custom_minimum_size.x = spec[1]
		l.modulate = Color(1, 1, 1, 0.6)
		l.add_theme_font_size_override(&"font_size", 22)
		head.add_child(l)
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(list)
	for action: StringName in Game.REBINDABLE:
		var row := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = str(Game.ACTION_NAMES.get(action, action))
		name_l.custom_minimum_size.x = 290
		name_l.add_theme_font_size_override(&"font_size", 24)
		row.add_child(name_l)
		var key_b := Button.new()
		key_b.custom_minimum_size = Vector2(150, 56)
		key_b.pressed.connect(func() -> void: _start_capture(action, "key"))
		row.add_child(key_b)
		var pad_b := Button.new()
		pad_b.custom_minimum_size = Vector2(130, 56)
		pad_b.pressed.connect(func() -> void: _start_capture(action, "pad"))
		row.add_child(pad_b)
		_bind_buttons[action] = [key_b, pad_b]
		list.add_child(row)
	_bind_status = Label.new()
	_bind_status.add_theme_font_size_override(&"font_size", 22)
	_bind_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bind_status.custom_minimum_size.x = 600
	box.add_child(_bind_status)
	var reset := UiTheme.big_button("RESET KEYS")
	reset.pressed.connect(func() -> void:
		Game.reset_bindings()
		_bind_status.text = "Keys and buttons back to the defaults."
		_refresh_bindings())
	box.add_child(reset)
	var back := UiTheme.big_button("BACK")
	back.pressed.connect(func() -> void:
		_capture = []
		_show(_settings))
	box.add_child(back)
	return box


func _refresh_bindings() -> void:
	for action: StringName in _bind_buttons:
		var pair: Array = _bind_buttons[action]
		(pair[0] as Button).text = Game.key_name(action)
		(pair[1] as Button).text = Game.pad_name(action)


func _start_capture(action: StringName, kind: String) -> void:
	_capture = [action, kind]
	_bind_status.text = "Press a %s for %s (Esc cancels)" % ["key" if kind == "key" else "gamepad button", Game.ACTION_NAMES.get(action, action)]
	var pair: Array = _bind_buttons[action]
	(pair[0 if kind == "key" else 1] as Button).text = "..."


func _input(event: InputEvent) -> void:
	if _capture.is_empty():
		return
	var action: StringName = _capture[0]
	var kind: String = _capture[1]
	var taken: InputEvent = null
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_capture = []
			_bind_status.text = ""
			_refresh_bindings()
			get_viewport().set_input_as_handled()
			return
		if kind == "key":
			taken = event
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and kind == "pad":
		taken = event
	if taken == null:
		return
	get_viewport().set_input_as_handled()
	_capture = []
	var other := Game.rebind(action, taken)
	if other == &"pause":
		_bind_status.text = "That one pauses the game; pick another."
	elif other != &"":
		_bind_status.text = "Swapped with %s." % Game.ACTION_NAMES.get(other, other)
	else:
		_bind_status.text = "Saved."
	Audio.play(&"ui_confirm")
	_refresh_bindings()


func _open_layout_editor() -> void:
	var editor := TouchLayoutEditor.new()
	_ui.add_child(editor)
	_controls.visible = false
	editor.closed.connect(func() -> void: _show(_controls))
