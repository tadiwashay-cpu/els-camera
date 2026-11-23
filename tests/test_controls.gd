extends GutTest
## Rebinding keys and pad buttons, the touch layout, first person input.

var _saved_bindings: Variant


func before_each() -> void:
	_saved_bindings = Save.setting("bindings")
	Game.reset_bindings()


func after_each() -> void:
	Game.reset_bindings()
	Save.set_setting("bindings", _saved_bindings if _saved_bindings is Dictionary else {})
	Game.apply_bindings()


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	return k


func test_rebind_a_free_key() -> void:
	assert_eq(Game.rebind(&"jump", _key(KEY_B)), &"", "nothing else used B")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_B
	assert_true(InputMap.action_has_event(&"jump", k), "jump is on B now")
	var saved: Dictionary = Save.setting("bindings")
	assert_eq(int(saved["jump"]["key"]), KEY_B, "saved")


func test_a_clash_swaps_the_two() -> void:
	var old_jump := Game.key_name(&"jump")
	assert_eq(Game.rebind(&"jump", _key(KEY_J)), &"attack", "J was attack's")
	assert_eq(Game.key_name(&"attack"), old_jump, "attack took jump's old key")


func test_pause_cannot_be_taken() -> void:
	var before := Game.key_name(&"jump")
	assert_eq(Game.rebind(&"jump", _key(KEY_ESCAPE)), &"pause")
	assert_eq(Game.key_name(&"jump"), before, "nothing changed")


func test_pad_rebind_works_on_any_pad() -> void:
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_DPAD_DOWN
	b.pressed = true
	Game.rebind(&"dodge", b)
	assert_eq(Game.pad_name(&"dodge"), "D-down")
	for ev in InputMap.action_get_events(&"dodge"):
		if ev is InputEventJoypadButton:
			assert_eq(ev.device, -1, "every pad, not only the first")


func test_reset_restores_defaults() -> void:
	Game.rebind(&"jump", _key(KEY_B))
	Game.reset_bindings()
	assert_eq(Game.key_name(&"jump"), OS.get_keycode_string(KEY_SPACE))
	assert_true((Save.setting("bindings") as Dictionary).is_empty())


func test_touch_layout_overrides() -> void:
	var t := TouchControls.new()
	add_child_autofree(t)
	var i := 1                                   # JUMP
	assert_eq(t.button_offset(i), TouchControls.BUTTONS[i][2], "default place")
	assert_eq(t.button_size(i), 1.0)
	t.set_button(i, Vector2(-500, -300), 1.3)
	assert_eq(t.button_offset(i), Vector2(-500, -300))
	assert_almost_eq(t.button_size(i), 1.3, 0.001)
	t.set_button(i, Vector2(-500, -300), 5.0)
	assert_almost_eq(t.button_size(i), 1.6, 0.001, "sizes are kept sensible")


func test_first_person_faces_the_view() -> void:
	var inp := FighterInput.new()
	inp.face_view = true
	inp.aim_yaw = 0.0
	assert_eq(inp.world_move(), Vector3.ZERO, "no stick, no move")
	inp.move = Vector2(1, 0)
	assert_almost_eq(inp.world_move().x, 1.0, 0.001, "the stick strafes relative to the view")
