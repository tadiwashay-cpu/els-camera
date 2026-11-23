class_name TouchLayoutEditor
extends Control
## Move and resize the on-screen buttons: drag one to move it, pick one and
## use the slider to resize it. SAVE keeps the layout ("touch_layout" in the
## save; the match's TouchControls reads it), RESET puts every button back.

signal closed

var controls: TouchControls
var _slider: HSlider
var _hint: Label
var _syncing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	controls = TouchControls.new()
	add_child(controls)
	controls.visible = true
	controls.editing = true
	controls.swap_available = true
	controls.set_power_ready(true)
	controls.selection_changed.connect(_on_select)

	var bar := HBoxContainer.new()
	bar.anchor_right = 1.0
	bar.offset_left = 40
	bar.offset_right = -40
	bar.offset_top = 24
	bar.offset_bottom = 110
	bar.add_theme_constant_override(&"separation", 18)
	add_child(bar)
	_hint = Label.new()
	_hint.text = "Drag a button to move it. Tap one, then slide to resize."
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override(&"font_size", 24)
	bar.add_child(_hint)
	var size_label := Label.new()
	size_label.text = "Size"
	bar.add_child(size_label)
	_slider = HSlider.new()
	_slider.min_value = 0.6
	_slider.max_value = 1.6
	_slider.step = 0.05
	_slider.value = 1.0
	_slider.custom_minimum_size = Vector2(260, 64)
	_slider.editable = false
	_slider.value_changed.connect(_on_size)
	bar.add_child(_slider)
	for spec: Array in [["RESET", _reset], ["CANCEL", _cancel], ["SAVE", _save]]:
		var b := UiTheme.big_button(spec[0], 170)
		b.pressed.connect(spec[1])
		bar.add_child(b)


func _on_select(i: int) -> void:
	_syncing = true
	_slider.editable = true
	_slider.value = controls.button_size(i)
	_hint.text = "%s: drag to move, slide to resize." % TouchControls.BUTTONS[i][1]
	_syncing = false


func _on_size(v: float) -> void:
	if _syncing or controls.selected < 0:
		return
	controls.set_button(controls.selected, controls.button_offset(controls.selected), v)


func _reset() -> void:
	controls.layout.clear()
	controls.queue_redraw()
	if controls.selected >= 0:
		_on_select(controls.selected)


func _save() -> void:
	Save.set_setting("touch_layout", controls.layout.duplicate(true))
	Audio.play(&"ui_confirm")
	closed.emit()
	queue_free()


func _cancel() -> void:
	closed.emit()
	queue_free()
