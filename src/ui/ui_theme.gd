class_name UiTheme
extends RefCounted
## The game's UI look, built in code. Street-racing-poster style (0.7):
## slanted parallelogram buttons with a thick bottom lip, dark navy panels
## with a yellow stripe down the left, bold italic condensed type
## (Barlow Condensed, OFL: assets/ui/fonts). Buttons are at least 64 px
## tall (doc: UI rules).

const ACCENT := Color(1.0, 0.78, 0.1)          # yellow: selection, titles, the stripe
const HOT := Color(1.0, 0.36, 0.2)             # orange-red: alerts, second accent
const COOL := Color(0.3, 0.85, 1.0)            # cyan: info
const INK := Color(0.97, 0.98, 1.0)
const NAVY := Color(0.06, 0.08, 0.14)
const PANEL := Color(0.06, 0.08, 0.14, 0.9)
const BUTTON := Color(0.14, 0.17, 0.27, 0.96)
## How far buttons lean (StyleBoxFlat.skew).
const SLANT := 0.22

const FONT_BODY := preload("res://assets/ui/fonts/BarlowCondensed-Medium.woff2")
const FONT_BUTTON := preload("res://assets/ui/fonts/BarlowCondensed-BoldItalic.woff2")
const FONT_TITLE := preload("res://assets/ui/fonts/BarlowCondensed-ExtraBoldItalic.woff2")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT_BODY
	t.default_font_size = 30
	t.set_color(&"font_color", &"Label", INK)
	t.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.75))
	t.set_constant(&"outline_size", &"Label", 6)
	for kind: StringName in [&"Button", &"OptionButton", &"CheckButton"]:
		t.set_font(&"font", kind, FONT_BUTTON)
		t.set_stylebox(&"normal", kind, button_box(BUTTON, Color(1, 1, 1, 0.1)))
		t.set_stylebox(&"hover", kind, button_box(BUTTON.lightened(0.08), ACCENT))
		t.set_stylebox(&"pressed", kind, button_box(ACCENT, ACCENT.darkened(0.35)))
		t.set_stylebox(&"focus", kind, button_box(BUTTON.lightened(0.08), ACCENT))
		t.set_stylebox(&"disabled", kind, button_box(Color(0.1, 0.11, 0.16, 0.7), Color(1, 1, 1, 0.04)))
		t.set_color(&"font_color", kind, INK)
		t.set_color(&"font_hover_color", kind, Color.WHITE)
		t.set_color(&"font_pressed_color", kind, NAVY)
		t.set_color(&"font_hover_pressed_color", kind, NAVY)
		t.set_color(&"font_focus_color", kind, INK)
		t.set_color(&"font_disabled_color", kind, Color(1, 1, 1, 0.32))
	t.set_font_size(&"font_size", &"Button", 34)
	t.set_font_size(&"font_size", &"OptionButton", 30)
	t.set_stylebox(&"panel", &"PanelContainer", panel_box())
	t.set_stylebox(&"panel", &"Panel", panel_box())
	t.set_stylebox(&"background", &"ProgressBar", _flat(Color(0, 0, 0, 0.55), 3))
	t.set_stylebox(&"fill", &"ProgressBar", _flat(Color(0.35, 0.95, 0.45), 3))
	t.set_stylebox(&"slider", &"HSlider", _flat(Color(0, 0, 0, 0.5), 3))
	t.set_stylebox(&"grabber_area", &"HSlider", _flat(ACCENT, 3))
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", _flat(ACCENT.lightened(0.2), 3))
	t.set_stylebox(&"panel", &"PopupMenu", panel_box())
	t.set_font(&"font", &"PopupMenu", FONT_BUTTON)
	t.set_font_size(&"font_size", &"PopupMenu", 30)
	t.set_constant(&"separation", &"VBoxContainer", 14)
	t.set_constant(&"separation", &"HBoxContainer", 14)
	_theme = t
	return t


## A slanted button face with a darker lip along the bottom.
static func button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.border_width_bottom = 7
	if border.a < 0.5:
		s.border_color = Color(bg.darkened(0.45), 1.0)
		s.set_border_width_all(0)
		s.border_width_bottom = 7
	s.set_corner_radius_all(4)
	s.skew = Vector2(SLANT, 0.0)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 10
	s.content_margin_bottom = 14
	s.anti_aliasing = true
	return s


## A panel: dark navy, square-ish, a yellow stripe down the left edge.
static func panel_box(stripe: Color = ACCENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = stripe
	s.border_width_left = 10
	s.set_corner_radius_all(6)
	s.corner_radius_top_left = 0
	s.corner_radius_bottom_left = 0
	s.content_margin_left = 34
	s.content_margin_right = 26
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(6, 8)
	return s


static func _flat(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	return s


## Kept for screens that build their own boxes (Armory cards).
static func _box(bg: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var s := button_box(bg, border)
	s.set_corner_radius_all(radius)
	return s


static func big_button(text: String, min_width: float = 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 80)
	b.pressed.connect(func() -> void: Audio.play(&"ui_click"))
	return b


static func title(text: String, size: int = 64, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT_TITLE)
	l.add_theme_font_size_override(&"font_size", int(size * 1.08))
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", maxi(size / 6, 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A slanted coloured tag behind a short text ("3D", "RANK S"...).
static func tag(text: String, size: int, bg: Color, fg: Color = NAVY) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.skew = Vector2(SLANT, 0.0)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override(&"panel", s)
	var l := title(text, size, fg)
	l.add_theme_constant_override(&"outline_size", 0)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p
