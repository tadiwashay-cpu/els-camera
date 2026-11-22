class_name ArmoryScreen
extends Control
## The Armory (title screen): every weapon by rank, with its price; buy one
## with coins, then equip it to start every life with it. The title scene
## shows the selected weapon in a fighter's hands (`selected`).

signal selected(w: WeaponData)
signal back

const CARD := Vector2(124, 150)

var _grid_box: VBoxContainer
var _cards: Dictionary = {}             # weapon id -> Button
var current: WeaponData
var _name: Label
var _rank: Label
var _power: Label
var _desc: Label
var _traits: Label
var _action: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_list()
	_build_detail()
	var icons := WeaponIcons.ensure(self)
	if icons:
		icons.finished.connect(_refresh)
	_refresh()
	var start := Registry.weapon(Armory.equipped())
	_select(start)


func _build_list() -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 36
	panel.offset_right = 770
	panel.offset_top = 24
	panel.offset_bottom = -24
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var t := UiTheme.title("ARMORY", 52, UiTheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(t)
	var sub := Label.new()
	sub.text = "Buy a weapon to use it: pick it up, catch it, or start with it."
	sub.add_theme_font_size_override(&"font_size", 20)
	sub.modulate = Color(1, 1, 1, 0.75)
	box.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 14
	box.add_child(scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_box)
	var by_rank: Dictionary = {}
	for w in Armory.catalogue():
		if not by_rank.has(w.tier):
			by_rank[w.tier] = []
		(by_rank[w.tier] as Array).append(w)
	for rank: String in Armory.RANKS:
		if not by_rank.has(rank):
			continue
		var head := UiTheme.title("RANK %s   ·   %d COINS" % [rank, Armory.PRICES[rank]], 24, Armory.rank_color(rank))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_grid_box.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override(&"h_separation", 10)
		grid.add_theme_constant_override(&"v_separation", 10)
		_grid_box.add_child(grid)
		for w: WeaponData in by_rank[rank]:
			grid.add_child(_card(w))
	var back_b := UiTheme.big_button("BACK")
	back_b.pressed.connect(func() -> void: back.emit())
	box.add_child(back_b)


func _card(w: WeaponData) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.clip_text = true
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override(&"font_size", 17)
	b.add_theme_constant_override(&"icon_max_width", 92)
	for st: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var box := (UiTheme.get_theme().get_stylebox(st, &"Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.content_margin_left = 6
		box.content_margin_right = 6
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		b.add_theme_stylebox_override(st, box)
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		_select(w))
	_cards[w.id] = b
	return b


func _build_detail() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -780
	panel.offset_right = -36
	panel.offset_top = -360
	panel.offset_bottom = -24
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	_name = UiTheme.title("", 44)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name)
	_rank = UiTheme.title("", 30)
	row.add_child(_rank)
	_power = UiTheme.title("", 28)
	_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_power)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override(&"font_size", 22)
	box.add_child(_desc)
	_traits = Label.new()
	_traits.add_theme_font_size_override(&"font_size", 20)
	_traits.modulate = Color(1, 1, 1, 0.7)
	_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_traits)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_action = UiTheme.big_button("", 340)
	_action.pressed.connect(_on_action)
	actions.add_child(_action)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 22)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(_status)


func _select(w: WeaponData) -> void:
	current = w
	_refresh()
	selected.emit(w)


func _on_action() -> void:
	var w := current
	if w == null:
		return
	if not Armory.owns(w.id):
		if Armory.buy(w):
			Audio.play(&"buy")
			Armory.equip(w.id)
			_status.text = "Bought and equipped."
		else:
			Audio.play(&"ui_back")
	elif Armory.equipped() != w.id:
		Armory.equip(w.id)
		Audio.play(&"ui_confirm")
		_status.text = "Equipped. Start a match with \"Your weapon\"."
	_refresh(false)


func _refresh(clear_status: bool = true) -> void:
	var eq := Armory.equipped()
	for id: StringName in _cards:
		var w := Registry.weapon(id)
		var b: Button = _cards[id]
		b.icon = WeaponIcons.icon(id)
		var owned := Armory.owns(id)
		var state := "EQUIPPED" if id == eq else ("OWNED" if owned else "%d" % Armory.price(w))
		b.text = "%s\n%s" % [w.display_name, state]
		var col := UiTheme.ACCENT if id == eq else (UiTheme.INK if owned else Color(1.0, 0.85, 0.35))
		if not owned and not Armory.can_afford(w):
			col = Color(1, 1, 1, 0.45)
		b.add_theme_color_override(&"font_color", col)
		b.add_theme_color_override(&"font_hover_color", col.lightened(0.2))
		b.add_theme_color_override(&"font_focus_color", col)
		b.self_modulate = Color(1, 1, 1, 1) if owned else Color(0.75, 0.75, 0.8)
		var normal := b.get_theme_stylebox(&"normal") as StyleBoxFlat
		normal.border_color = UiTheme.ACCENT if current and current.id == id else Color(1, 1, 1, 0.12)
		normal.bg_color = Color(0.2, 0.17, 0.12, 0.95) if current and current.id == id else Color(0.12, 0.13, 0.17, 0.92)
	var w := current
	if w == null:
		return
	_name.text = w.display_name.to_upper()
	_rank.text = "RANK %s" % w.tier
	_rank.add_theme_color_override(&"font_color", Armory.rank_color(w.tier))
	var sk := WeaponSkills.info(w.skill)
	if sk.is_empty():
		_power.text = "NO POWER"
		_power.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.5))
		_desc.text = ""
	else:
		_power.text = "POWER: %s" % str(sk["name"]).to_upper()
		_power.add_theme_color_override(&"font_color", sk["color"])
		_desc.text = WeaponSkills.describe(w.skill)
	_traits.text = Armory.traits(w)
	if clear_status:
		_status.text = ""
	var coins := int(Save.data["coins"])
	if Armory.owns(w.id):
		_action.text = "EQUIPPED" if eq == w.id else "EQUIP"
		_action.disabled = eq == w.id
	elif Armory.can_afford(w):
		_action.text = "BUY  %d" % Armory.price(w)
		_action.disabled = false
	else:
		_action.text = "BUY  %d" % Armory.price(w)
		_action.disabled = true
		if clear_status:
			_status.text = "%d more coins: win matches and get kills." % (Armory.price(w) - coins)
