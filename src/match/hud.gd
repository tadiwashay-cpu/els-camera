class_name Hud
extends CanvasLayer
## Match HUD (doc: Match HUD): HP bar, match timer, live kill scoreboard,
## kill feed, centre callouts, lock-on marker, crosshair, pause button and
## the FPS counter. Results and pause screens live here too.

signal pause_pressed
signal rematch_pressed
signal menu_pressed
signal resume_pressed

var match_node: Match
var player: Fighter

var _root: Control
var _hp: ProgressBar
var _hp_label: Label
var _weapon_label: Label
var _timer: Label
var _sub: Label
var _board: VBoxContainer
var _feed: VBoxContainer
var _center: Label
var _small: Label
var _fps: Label
var _marker: Control
var _cross: Control
var _pause_menu: Control
var _results: Control
var _center_tween: Tween
var _power: ProgressBar
var _power_fill: StyleBoxFlat
var _power_label: Label
var _effects: Label
var _tint: ColorRect
var _hp_fill: StyleBoxFlat
var _water: Label
var _locked: Label
var _locked_id: StringName = &""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# HP (top left)
	var hp_box := VBoxContainer.new()
	hp_box.position = Vector2(48, 36)
	hp_box.add_theme_constant_override(&"separation", 4)
	_root.add_child(hp_box)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override(&"font_size", 26)
	hp_box.add_child(_hp_label)
	_hp = ProgressBar.new()
	_hp.custom_minimum_size = Vector2(420, 30)
	_hp.show_percentage = false
	_hp.max_value = 100
	hp_box.add_child(_hp)
	_hp_fill = (UiTheme.get_theme().get_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat).duplicate()
	_hp.add_theme_stylebox_override(&"fill", _hp_fill)
	_power = ProgressBar.new()
	_power.custom_minimum_size = Vector2(300, 14)
	_power.show_percentage = false
	_power.max_value = FighterPowers.FULL
	_power_fill = (UiTheme.get_theme().get_stylebox(&"fill", &"ProgressBar") as StyleBoxFlat).duplicate() as StyleBoxFlat
	_power.add_theme_stylebox_override(&"fill", _power_fill)
	hp_box.add_child(_power)
	_power_label = Label.new()
	_power_label.add_theme_font_size_override(&"font_size", 20)
	hp_box.add_child(_power_label)
	_effects = Label.new()
	_effects.add_theme_font_size_override(&"font_size", 20)
	_effects.add_theme_color_override(&"font_color", Color(1, 0.9, 0.5))
	hp_box.add_child(_effects)
	_tint = ColorRect.new()
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0, 0, 0, 0)
	_root.add_child(_tint)
	_root.move_child(_tint, 0)
	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override(&"font_size", 22)
	_weapon_label.modulate = Color(1, 1, 1, 0.8)
	hp_box.add_child(_weapon_label)

	var danger := DangerIndicator.new()
	danger.match_node = match_node
	_root.add_child(danger)

	# In-the-water warning (upper centre, under the timer).
	_water = UiTheme.title("IN THE WATER!  JUMP ONTO SOMETHING", 30, Color(0.45, 0.85, 1.0))
	_water.anchor_left = 0.5
	_water.anchor_right = 0.5
	_water.offset_left = -500
	_water.offset_right = 500
	_water.offset_top = 150
	_water.visible = false
	_root.add_child(_water)

	# Standing on a weapon this player hasn't bought (lower centre).
	_locked = UiTheme.title("", 28, Color(1.0, 0.8, 0.35))
	_locked.anchor_left = 0.5
	_locked.anchor_right = 0.5
	_locked.anchor_top = 1.0
	_locked.anchor_bottom = 1.0
	_locked.offset_left = -560
	_locked.offset_right = 560
	_locked.offset_top = -250
	_locked.offset_bottom = -200
	_locked.visible = false
	_root.add_child(_locked)

	# Timer (top centre)
	_timer = UiTheme.title("3:00", 64)
	_timer.anchor_left = 0.5
	_timer.anchor_right = 0.5
	_timer.offset_left = -200
	_timer.offset_right = 200
	_timer.offset_top = 18
	_root.add_child(_timer)
	_sub = UiTheme.title("", 28, UiTheme.ACCENT)
	_sub.anchor_left = 0.5
	_sub.anchor_right = 0.5
	_sub.offset_left = -400
	_sub.offset_right = 400
	_sub.offset_top = 96
	_root.add_child(_sub)

	# Scoreboard + feed (top right)
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -420
	right.offset_right = -130
	right.offset_top = 30
	_root.add_child(right)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override(&"separation", 2)
	right.add_child(_board)
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override(&"separation", 2)
	right.add_child(_feed)

	var pause := Button.new()
	pause.text = "II"
	pause.custom_minimum_size = Vector2(84, 84)
	pause.anchor_left = 1.0
	pause.anchor_right = 1.0
	pause.offset_left = -112
	pause.offset_right = -28
	pause.offset_top = 28
	pause.offset_bottom = 112
	pause.focus_mode = Control.FOCUS_NONE
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	_root.add_child(pause)

	# Centre callouts
	_center = UiTheme.title("", 96)
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.offset_left = -700
	_center.offset_right = 700
	_center.offset_top = -230
	_center.offset_bottom = -110
	_center.pivot_offset = Vector2(700, 60)
	_root.add_child(_center)
	_small = UiTheme.title("", 34)
	_small.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_small.offset_left = -700
	_small.offset_right = 700
	_small.offset_top = -100
	_small.offset_bottom = -50
	_root.add_child(_small)

	_cross = Control.new()
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func() -> void:
		_cross.draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.7))
		_cross.draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 2.0))
	_root.add_child(_cross)

	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	_marker.draw.connect(func() -> void:
		var pts := PackedVector2Array([Vector2(0, -26), Vector2(22, 0), Vector2(0, 26), Vector2(-22, 0), Vector2(0, -26)])
		_marker.draw_polyline(pts, UiTheme.ACCENT, 4.0, true))
	_root.add_child(_marker)

	_fps = Label.new()
	_fps.anchor_top = 1.0
	_fps.anchor_bottom = 1.0
	_fps.offset_left = 20
	_fps.offset_top = -44
	_fps.add_theme_font_size_override(&"font_size", 20)
	_fps.modulate = Color(1, 1, 1, 0.7)
	_root.add_child(_fps)


func _process(_delta: float) -> void:
	if match_node == null:
		return
	var race := match_node.race
	var t := race.time_left
	if race.overtime:
		_timer.text = "OVERTIME"
		_timer.modulate = UiTheme.ACCENT
		_sub.text = "NEXT KILL WINS"
	else:
		_timer.text = "%d:%02d" % [int(ceil(t)) / 60, int(ceil(t)) % 60]
		var final := t <= KillRace.FINAL_SECONDS and race.duration > KillRace.FINAL_SECONDS
		_timer.modulate = Color(1, 0.35, 0.3) if final and int(t * 2.0) % 2 == 0 else Color.WHITE
		_timer.scale = Vector2.ONE * (1.0 + (0.08 * absf(sin(t * PI)) if final else 0.0))
		_sub.text = "KILLS COUNT DOUBLE" if final else ""
	if player:
		_hp.value = player.health
		_hp_fill.bg_color = Color(0.35, 0.95, 0.45).lerp(Color(1, 0.25, 0.2), 1.0 - player.health / player.max_health)
		_hp_label.text = "%s   %d HP" % [player.display_name, int(ceil(player.health))]
		var sk := WeaponSkills.info(player.skill_id())
		var power := ""
		if not sk.is_empty():
			var left := player.skill_left()
			power = "   %s %s" % [str(sk["name"]).to_upper(), "READY" if left <= 0.0 else "%ds" % int(ceil(left))]
		if player.armed():
			_weapon_label.text = player.weapon_data.display_name.to_upper() + ("  x%d" % player.ammo if player.weapon_data.uses_ammo() else "") + power
		else:
			_weapon_label.text = "UNARMED - find a weapon" + power
		var pw := player.powers
		var info: Dictionary = FighterPowers.INFO[pw.power]
		_power.value = pw.meter
		_power_fill.bg_color = info["color"] if pw.ready_to_use() and int(Time.get_ticks_msec() / 250) % 2 == 0 else Color(info["color"]).darkened(0.35)
		_power_label.text = "%s%s" % [str(info["name"]).to_upper(), "  READY" if pw.ready_to_use() else ""]
		var fx := []
		for id: StringName in pw.effects:
			var n := FighterPowers.effect_name(id)
			fx.append("%s %ds" % [n.to_upper(), int(ceil(pw.time_left(id)))])
		if pw.shield > 0.0:
			fx.append("SHIELD %d" % int(pw.shield))
		_effects.text = "   ".join(fx)
		var wet := player.alive and match_node.arena.wet_time(player) > 0.4 and match_node.config.hazards
		_water.visible = wet and int(Time.get_ticks_msec() / 300) % 3 != 0
		if wet:
			_water.text = "SWIM TO A LEDGE, JUMP TO CLIMB OUT" if player.swimming else "IN THE WATER!  JUMP ONTO SOMETHING"
		_update_marker()
	_fps.visible = bool(Save.setting("show_fps"))
	if _fps.visible:
		_fps.text = "%d FPS   v%s" % [Engine.get_frames_per_second(), Game.version()]


func _update_marker() -> void:
	var t := player.locked_target()
	var cam := get_viewport().get_camera_3d()
	if t == null or cam == null or cam.is_position_behind(t.global_position):
		_marker.visible = false
		_cross.visible = true
		return
	_marker.visible = true
	_cross.visible = false
	_marker.position = cam.unproject_position(t.global_position + Vector3.UP * 2.25)
	_marker.queue_redraw()


func set_tint(c: Color) -> void:
	var tw := create_tween()
	tw.tween_property(_tint, "color", c, 0.25)


func refresh_board() -> void:
	for c in _board.get_children():
		c.queue_free()
	var race := match_node.race
	for id: int in race.ranking():
		var f := match_node.fighter_by_id(id)
		if f == null:
			continue
		var l := Label.new()
		l.text = "%s   %d" % [f.display_name, int(race.scores[id])]
		l.add_theme_font_size_override(&"font_size", 28 if f.is_player else 26)
		l.add_theme_color_override(&"font_color", f.body.skin.shirt.lightened(0.35))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_board.add_child(l)


func feed(text: String, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 22)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(l)
	while _feed.get_child_count() > 4:
		_feed.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


## A big centre callout that pops in. `hold` 0 = stays until replaced.
func callout(text: String, color: Color = Color.WHITE, small: String = "", hold: float = 1.2) -> void:
	_center.text = text
	_center.add_theme_color_override(&"font_color", color)
	_small.text = small
	_center.modulate.a = 1.0
	_small.modulate.a = 1.0
	_center.scale = Vector2.ONE * 1.5
	if _center_tween:
		_center_tween.kill()
	_center_tween = create_tween()
	_center_tween.tween_property(_center, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_center_tween.tween_interval(hold)
		_center_tween.tween_property(_center, "modulate:a", 0.0, 0.3)
		_center_tween.parallel().tween_property(_small, "modulate:a", 0.0, 0.3)


## Shows that the weapon underfoot is locked (not bought), or hides it (null).
func set_locked(w: WeaponData) -> void:
	var id: StringName = w.id if w else &""
	if id == _locked_id:
		return
	_locked_id = id
	_locked.visible = w != null
	if w:
		_locked.text = "LOCKED: %s  ·  RANK %s  ·  %d COINS IN THE ARMORY" % [w.display_name.to_upper(), w.tier, Armory.price(w)]


func set_small(text: String) -> void:
	_small.text = text
	_small.modulate.a = 1.0


# ----------------------------------------------------------------- screens

func show_pause(on: bool) -> void:
	if on and _pause_menu == null:
		var buttons: Array = [["RESUME", func() -> void: resume_pressed.emit()],
			["RESTART", func() -> void: rematch_pressed.emit()], ["QUIT TO MENU", func() -> void: menu_pressed.emit()]]
		if Net.active:
			buttons = [["RESUME", func() -> void: resume_pressed.emit()], ["LEAVE MATCH", func() -> void: menu_pressed.emit()]]
		_pause_menu = _screen("MENU" if Net.active else "PAUSED", buttons)
	elif not on and _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null


func show_results(winner: Fighter, rows: Array, coins: int) -> void:
	var title := "%s WIN%s" % [winner.display_name.to_upper(), "" if winner.is_player else "S"] if winner else "DRAW"
	var buttons: Array = [["REMATCH", func() -> void: rematch_pressed.emit()], ["MENU", func() -> void: menu_pressed.emit()]]
	if Net.active and not Net.is_host:
		buttons = [["LEAVE", func() -> void: menu_pressed.emit()]]      # the host decides on a rematch
	_results = _screen(title, buttons, rows, coins)


func _screen(title: String, buttons: Array, rows: Array = [], coins: int = -1) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(UiTheme.title(title, 72, UiTheme.ACCENT))
	for r: Array in rows:
		var l := Label.new()
		l.text = "%s   %s" % [r[0], r[1]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override(&"font_size", 34)
		if r.size() > 2:
			l.add_theme_color_override(&"font_color", r[2])
		box.add_child(l)
	if coins >= 0:
		var c := UiTheme.title("+%d COINS" % coins, 34, Color(1, 0.85, 0.3))
		box.add_child(c)
	var first: Button
	for b: Array in buttons:
		var btn := UiTheme.big_button(b[0], 420)
		btn.pressed.connect(b[1])
		box.add_child(btn)
		if first == null:
			first = btn
	if first:
		first.grab_focus.call_deferred()
	return dim
