class_name UiTheme
extends RefCounted
## The game's UI look, built in code: chunky rounded panels and buttons,
## orange accent. Buttons are at least 64 px tall (doc: UI rules).

const ACCENT := Color(1.0, 0.56, 0.14)
const INK := Color(0.96, 0.97, 1.0)
const PANEL := Color(0.07, 0.08, 0.11, 0.88)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 28
	t.set_color(&"font_color", &"Label", INK)
	t.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.7))
	t.set_constant(&"outline_size", &"Label", 6)
	t.set_stylebox(&"normal", &"Button", _box(Color(0.12, 0.13, 0.17, 0.92), Color(1, 1, 1, 0.12)))
	t.set_stylebox(&"hover", &"Button", _box(Color(0.18, 0.19, 0.24, 0.95), ACCENT))
	t.set_stylebox(&"pressed", &"Button", _box(ACCENT.darkened(0.15), ACCENT))
	t.set_stylebox(&"focus", &"Button", _box(Color(0.18, 0.19, 0.24, 0.95), ACCENT))
	t.set_stylebox(&"disabled", &"Button", _box(Color(0.1, 0.1, 0.12, 0.6), Color(1, 1, 1, 0.05)))
	t.set_color(&"font_color", &"Button", INK)
	t.set_color(&"font_hover_color", &"Button", Color.WHITE)
	t.set_color(&"font_pressed_color", &"Button", Color.BLACK)
	t.set_color(&"font_disabled_color", &"Button", Color(1, 1, 1, 0.35))
	t.set_font_size(&"font_size", &"Button", 30)
	t.set_stylebox(&"panel", &"PanelContainer", _box(PANEL, Color(1, 1, 1, 0.08), 18))
	t.set_stylebox(&"panel", &"Panel", _box(PANEL, Color(1, 1, 1, 0.08), 18))
	t.set_stylebox(&"background", &"ProgressBar", _box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 8))
	t.set_stylebox(&"fill", &"ProgressBar", _box(Color(0.35, 0.95, 0.45), Color(0, 0, 0, 0), 8))
	t.set_font_size(&"font_size", &"OptionButton", 28)
	t.set_stylebox(&"normal", &"OptionButton", _box(Color(0.12, 0.13, 0.17, 0.92), Color(1, 1, 1, 0.12)))
	t.set_stylebox(&"slider", &"HSlider", _box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 6))
	t.set_constant(&"separation", &"VBoxContainer", 14)
	t.set_constant(&"separation", &"HBoxContainer", 14)
	_theme = t
	return t


static func _box(bg: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func big_button(text: String, min_width: float = 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 78)
	b.pressed.connect(func() -> void: Audio.play(&"ui_click"))
	return b


static func title(text: String, size: int = 64, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", maxi(size / 6, 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
