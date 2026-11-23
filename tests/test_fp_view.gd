extends GutTest
## The first-person floating weapon (FPViewModel) and its Blender moves.


func test_every_mapped_move_was_built() -> void:
	for clip: StringName in FPViewModel.FROM_MOVE:
		var fp: StringName = FPViewModel.FROM_MOVE[clip]
		assert_true(FPViewModel.has_move(fp), "%s -> %s is in fp_weapon.glb" % [clip, fp])
	for extra: StringName in [&"FP_Block", &"FP_ShieldBlock", &"FP_Equip"]:
		assert_true(FPViewModel.has_move(extra), "%s is built" % extra)


func test_every_weapon_has_a_rest_pose() -> void:
	for id: StringName in Registry.weapons:
		var w: WeaponData = Registry.weapons[id]
		var fam := FPViewModel.family(w)
		if w.is_fists():
			assert_eq(fam, &"", "fists float nothing")
		else:
			assert_true(FPViewModel.REST.has(fam), "%s has a family (%s)" % [id, fam])


func test_aim_points_the_tip() -> void:
	var up := FPViewModel.aim_basis(Vector3(0.0, PI * 0.5, 0.0)) * Vector3.UP
	assert_almost_eq(up.y, 1.0, 0.001, "pitch 90: tip straight up")
	var ahead := FPViewModel.aim_basis(Vector3.ZERO) * Vector3.UP
	assert_almost_eq(ahead.z, -1.0, 0.001, "pitch 0: tip straight ahead")
	var right := FPViewModel.aim_basis(Vector3(PI * 0.5, 0.0, 0.0)) * Vector3.UP
	assert_almost_eq(right.x, 1.0, 0.001, "yaw 90: tip to the right")


func test_moves_start_and_end_at_rest() -> void:
	for fp: StringName in [&"FP_SlashA", &"FP_Smash", &"FP_Thrust", &"FP_Cast"]:
		var a: Array = FPViewModel.sample(fp, 0.0)
		var b: Array = FPViewModel.sample(fp, 1.0)
		assert_almost_eq((a[0] as Vector3).length() + (a[1] as Vector3).length(), 0.0, 0.01, "%s starts at rest" % fp)
		assert_almost_eq((b[0] as Vector3).length() + (b[1] as Vector3).length(), 0.0, 0.01, "%s ends at rest" % fp)


func test_the_swing_lands_in_the_hit_window() -> void:
	FPViewModel.load_moves()
	var clip := &"Slash_A"
	var hit := BlockBody.hit_window(clip)
	assert_true(hit.y > hit.x, "Slash_A has a hit window")
	var length := BlockBody.move_length(clip)
	var start := FPViewModel.warp(hit.x / length, clip, &"FP_SlashA")
	var end := FPViewModel.warp(hit.y / length, clip, &"FP_SlashA")
	assert_almost_eq(start, 0.30, 0.001, "the swing starts as the hit window opens")
	assert_almost_eq(end, 0.52, 0.001, "and is across when it shuts")
	assert_almost_eq(FPViewModel.warp(0.0, clip, &"FP_SlashA"), 0.0, 0.001)
	assert_almost_eq(FPViewModel.warp(1.0, clip, &"FP_SlashA"), 1.0, 0.001)


func test_eye_hidden_moves_the_body_off_the_eye_layer() -> void:
	var f := Fighter.new()
	f.weapon_data = Registry.weapon(&"sword")
	add_child_autofree(f)
	f.set_eye_hidden(true)
	assert_eq(f.body.mesh_instance.layers, Fighter.EYE_LAYER)
	assert_eq(f.weapon_visual.layers, Fighter.EYE_LAYER)
	f.equip(Registry.weapon(&"hammer"))
	assert_eq(f.weapon_visual.layers, Fighter.EYE_LAYER, "a new weapon stays hidden too")
	f.set_eye_hidden(false)
	assert_eq(f.body.mesh_instance.layers, 1)
