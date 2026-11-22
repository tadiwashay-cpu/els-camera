extends GutTest
## Save file parsing and the data the game ships with.


func test_empty_or_broken_save_gives_defaults() -> void:
	var d := Save.from_json("")
	assert_eq(d["coins"], 0)
	assert_eq(d["settings"]["quality"], 1)
	d = Save.from_json("{ not json")
	assert_eq(d["settings"]["show_fps"], false)


func test_save_round_trip_keeps_types() -> void:
	var d := Save.from_json("")
	d["coins"] = 120
	d["settings"]["look_sensitivity"] = 1.4
	var back := Save.from_json(Save.to_json(d))
	assert_eq(back["coins"], 120)
	assert_typeof(back["coins"], TYPE_INT, "JSON floats come back as ints")
	assert_almost_eq(float(back["settings"]["look_sensitivity"]), 1.4, 0.0001)


func test_old_save_gets_new_keys() -> void:
	var back := Save.from_json('{"coins": 5, "settings": {"quality": 2}}')
	assert_eq(back["settings"]["quality"], 2)
	assert_true(back["settings"].has("aim_assist"))
	assert_true(back.has("stats"))


func test_wrong_types_fall_back() -> void:
	var back := Save.from_json('{"coins": "lots", "settings": {"vibration": 3}}')
	assert_eq(back["coins"], 0)
	assert_eq(back["settings"]["vibration"], true)


func test_every_weapon_move_exists_in_the_rig() -> void:
	var moves := BlockBody.moves()
	assert_gt(moves.size(), 30)
	for w: WeaponData in Registry.weapons.values():
		for clip in w.light_moves:
			assert_true(moves.has(String(clip)), "%s: %s" % [w.id, clip])
		assert_true(moves.has(String(w.heavy_move)), "%s heavy" % w.id)
		if w.heavy_charge != &"":
			assert_true(bool(moves[String(w.heavy_charge)]["loop"]), "charge pose loops")


func test_attacks_have_hit_windows_inside_the_clip() -> void:
	for clip in ["Slash_A", "Slash_B", "Slash_C", "Heavy_Release", "Jab", "Cross", "Kick"]:
		var w := BlockBody.hit_window(StringName(clip))
		assert_gt(w.y, w.x, clip)
		assert_lt(w.y, BlockBody.move_length(StringName(clip)) + 0.001, clip)


func test_locomotion_loops_have_speeds() -> void:
	for clip in ["Walk", "Run", "Sprint", "Strafe_L", "Strafe_R", "Backpedal", "Run_Sword"]:
		var info := BlockBody.move_info(StringName(clip))
		assert_true(bool(info["loop"]), clip)
		assert_gt(float(info["speed"]), 0.5, clip)
