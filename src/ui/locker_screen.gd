class_name LockerScreen
extends Control
## The Locker (title screen): your fighter's look (skin tone, clothes,
## hair, hat, face; colours are free, some parts cost coins) and upgrades
## (health, damage, speed, power; five levels each). The title scene shows
## your fighter turning on the left (`look_changed`).

signal look_changed(look: Dictionary)
signal back

const SWATCH := Vector2(58, 58)

var _look: Dictionary
var _look_tab: Control
var _up_tab: Control
var _tab_buttons: Array[Button] = []
var _swatches: Dictionary = {}       # look key -> Array[Button]
var _parts: Dictionary = {}          # kind -> {id: Button}
var _action: Button
var _status: Label
var _up_rows: Dictionary = {}        # stat -> {"pips": Array[Panel], "button": Button}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look = Look.mine()
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -900
	panel.offset_right = -36
	panel.offset_top = 86
	panel.offset_bottom = -24
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := UiTheme.title("LOCKER", 52, UiTheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	for spec: Array in [["LOOK", 0], ["UPGRADES", 1]]:
		var b := UiTheme.big_button(spec[0], 220)
		b.toggle_mode = true
		var idx: int = spec[1]
		b.pressed.connect(func() -> void: _tab(idx))
		head.add_child(b)
		_tab_buttons.append(b)
	_look_tab = _build_look()
	box.add_child(_look_tab)
	_up_tab = _build_upgrades()
	box.add_child(_up_tab)
	var bottom := HBoxContainer.new()
	box.add_child(bottom)
	var back_b := UiTheme.big_button("BACK", 220)
	back_b.pressed.connect(_on_back)
	bottom.add_child(back_b)
	_action = UiTheme.big_button("", 330)
	_action.pressed.connect(_on_action)
	bottom.add_child(_action)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 21)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_status)
	_tab(0)


## Called when the screen opens: start from the saved look.
func open() -> void:
	_look = Look.mine()
	_status.text = ""
	_refresh()
	look_changed.emit(_look)


func _tab(i: int) -> void:
	_look_tab.visible = i == 0
	_up_tab.visible = i == 1
	for k in _tab_buttons.size():
		_tab_buttons[k].button_pressed = k == i
	_action.visible = i == 0
	_refresh()


# ------------------------------------------------------------------ look

func _build_look() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 14
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 10)
	scroll.add_child(col)
	_section(col, "SKIN")
	_colors(col, "skin", Look.SKIN_TONES)
	_section(col, "FACE")
	_part_row(col, &"face")
	_section(col, "HAIR")
	_part_row(col, &"hair")
	_colors(col, "hair_color", Look.HAIR_COLORS)
	_section(col, "HAT")
	_part_row(col, &"hat")
	_colors(col, "hat_color", Look.CLOTH)
	_section(col, "SHIRT")
	_colors(col, "shirt", Look.CLOTH)
	_section(col, "PANTS")
	_colors(col, "pants", Look.CLOTH)
	_section(col, "SHOES")
	_colors(col, "shoes", Look.CLOTH)
	return scroll


func _section(col: VBoxContainer, text: String) -> void:
	var l := UiTheme.title(text, 26, Color(1, 1, 1, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(l)


func _colors(col: VBoxContainer, key: String, palette: Array[Color]) -> void:
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	col.add_child(grid)
	var list: Array[Button] = []
	for i in palette.size():
		var b := Button.new()
		b.custom_minimum_size = SWATCH
		b.focus_mode = Control.FOCUS_NONE
		for st: StringName in [&"normal", &"hover", &"pressed"]:
			var s := StyleBoxFlat.new()
			s.bg_color = palette[i]
			s.set_corner_radius_all(10)
			s.set_border_width_all(4)
			s.border_color = Color(1, 1, 1, 0.15)
			b.add_theme_stylebox_override(st, s)
		b.pressed.connect(func() -> void:
			Audio.play(&"ui_click")
			_look[key] = i
			_changed())
		grid.add_child(b)
		list.append(b)
	_swatches[key] = list


func _part_row(col: VBoxContainer, kind: StringName) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 8)
	flow.add_theme_constant_override(&"v_separation", 8)
	col.add_child(flow)
	var table: Dictionary = Look.KINDS[kind]
	var buttons := {}
	for id: StringName in table:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 64)
		b.add_theme_font_size_override(&"font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			Audio.play(&"ui_click")
			_look[String(kind)] = String(id)
			_changed())
		flow.add_child(b)
		buttons[id] = b
	_parts[kind] = buttons


## The first part of the look not owned yet: [kind, id] or [].
func _unowned() -> Array:
	for kind: StringName in Look.KINDS:
		var id := StringName(_look[String(kind)])
		if not Look.owns(kind, id):
			return [kind, id]
	return []


func _changed() -> void:
	if _unowned().is_empty():
		Look.save_mine(_look)
		_status.text = "Saved."
	else:
		_status.text = ""
	_refresh()
	look_changed.emit(_look)


func _on_action() -> void:
	var need := _unowned()
	if need.is_empty():
		return
	if Look.buy(need[0], need[1]):
		Audio.play(&"buy")
		_changed()
		_status.text = "Bought and saved."
	else:
		Audio.play(&"ui_back")


func _on_back() -> void:
	# Leave with what's saved (a part you didn't buy isn't kept).
	_look = Look.mine()
	look_changed.emit(_look)
	back.emit()


# -------------------------------------------------------------- upgrades

func _build_upgrades() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 18)
	var sub := Label.new()
	sub.text = "Upgrades count in every match, online too. Bots train as well: a level on Normal, two on Hard."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override(&"font_size", 21)
	sub.modulate = Color(1, 1, 1, 0.75)
	col.add_child(sub)
	for stat: StringName in Upgrades.STATS:
		var row := PanelContainer.new()
		col.add_child(row)
		var h := HBoxContainer.new()
		row.add_child(h)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override(&"separation", 6)
		h.add_child(left)
		var name_l := UiTheme.title(Upgrades.NAMES[stat], 32, Upgrades.COLORS[stat])
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(name_l)
		var pips_box := HBoxContainer.new()
		pips_box.add_theme_constant_override(&"separation", 6)
		left.add_child(pips_box)
		var pips: Array[Panel] = []
		for i in Upgrades.MAX_LEVEL:
			var p := Panel.new()
			p.custom_minimum_size = Vector2(54, 16)
			pips_box.add_child(p)
			pips.append(p)
		var d := Label.new()
		d.text = Upgrades.describe(stat)
		d.add_theme_font_size_override(&"font_size", 19)
		d.modulate = Color(1, 1, 1, 0.7)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(d)
		var b := UiTheme.big_button("", 250)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			if Upgrades.buy(stat):
				Audio.play(&"buy")
			else:
				Audio.play(&"ui_back")
			_refresh())
		h.add_child(b)
		_up_rows[stat] = {"pips": pips, "button": b}
	return col


# ------------------------------------------------------------------- refresh

func _refresh() -> void:
	for key: String in _swatches:
		var list: Array = _swatches[key]
		for i in list.size():
			var on := int(_look.get(key, -1)) == i
			for st: StringName in [&"normal", &"hover", &"pressed"]:
				var s := (list[i] as Button).get_theme_stylebox(st) as StyleBoxFlat
				s.border_color = UiTheme.ACCENT if on else Color(1, 1, 1, 0.15)
				s.set_border_width_all(6 if on else 3)
	for kind: StringName in _parts:
		var table: Dictionary = Look.KINDS[kind]
		for id: StringName in _parts[kind]:
			var b: Button = _parts[kind][id]
			var owned := Look.owns(kind, id)
			b.text = str(table[id][0]) if owned else "%s  %d" % [table[id][0], table[id][1]]
			var on := StringName(_look[String(kind)]) == id
			var col := UiTheme.ACCENT if on else (UiTheme.INK if owned else Color(1.0, 0.85, 0.35))
			b.add_theme_color_override(&"font_color", col)
			b.add_theme_color_override(&"font_hover_color", col.lightened(0.2))
			var st := (UiTheme.get_theme().get_stylebox(&"normal", &"Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
			st.content_margin_left = 10
			st.content_margin_right = 10
			if on:
				st.border_color = UiTheme.ACCENT
				st.bg_color = Color(0.2, 0.17, 0.12, 0.95)
			b.add_theme_stylebox_override(&"normal", st)
	var need := _unowned()
	if need.is_empty():
		_action.text = "SAVED"
		_action.disabled = true
	else:
		var table: Dictionary = Look.KINDS[need[0]]
		var cost := Look.price(need[0], need[1])
		_action.text = "BUY %s  %d" % [str(table[need[1]][0]).to_upper(), cost]
		_action.disabled = int(Save.data["coins"]) < cost
		if _action.disabled:
			_status.text = "%d more coins: win matches and get kills." % (cost - int(Save.data["coins"]))
	for stat: StringName in _up_rows:
		var row: Dictionary = _up_rows[stat]
		var l := Upgrades.level(stat)
		var pips: Array = row["pips"]
		for i in pips.size():
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(5)
			s.bg_color = (Upgrades.COLORS[stat] as Color) if i < l else Color(1, 1, 1, 0.12)
			(pips[i] as Panel).add_theme_stylebox_override(&"panel", s)
		var b: Button = row["button"]
		var cost := Upgrades.next_cost(stat)
		if cost < 0:
			b.text = "MAX"
			b.disabled = true
		else:
			b.text = "UPGRADE  %d" % cost
			b.disabled = not Upgrades.can_buy(stat)
