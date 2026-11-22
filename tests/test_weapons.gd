extends GutTest
## The weapon roster: data that the rig and the game can actually use.


func test_roster_size_and_pools() -> void:
	assert_eq(Registry.weapons.size(), 25, "24 weapons + fists")
	assert_gt(Registry.weapon_pool(false).size(), 10, "spawner pool")
	var rare := Registry.weapon_pool(true)
	assert_gt(rare.size(), 3, "mystery crate pool")
	for w in rare:
		assert_eq(w.rarity, &"rare")


func test_every_weapon_uses_real_moves() -> void:
	var moves := BlockBody.moves()
	for w: WeaponData in Registry.weapons.values():
		for clip in w.light_moves:
			assert_true(moves.has(String(clip)), "%s: %s" % [w.id, clip])
		assert_true(moves.has(String(w.heavy_move)), "%s heavy %s" % [w.id, w.heavy_move])
		if w.heavy_charge != &"":
			assert_true(bool(moves[String(w.heavy_charge)]["loop"]), "%s charge pose loops" % w.id)
		if w.idle_clip != &"":
			assert_true(bool(moves[String(w.idle_clip)]["loop"]), "%s idle loops" % w.id)
			assert_true(BlockBody.LOCO.has(w.idle_clip), "%s idle is a locomotion loop" % w.id)


func test_melee_moves_have_hit_windows() -> void:
	for w: WeaponData in Registry.weapons.values():
		if w.kind != &"melee":
			continue
		for clip in w.light_moves + [w.heavy_move]:
			var win := BlockBody.hit_window(clip)
			assert_gt(win.y, win.x, "%s %s" % [w.id, clip])


func test_thrown_and_ranged_have_ammo_and_events() -> void:
	for w: WeaponData in Registry.weapons.values():
		if w.kind == &"thrown":
			assert_gt(w.ammo, 0, String(w.id))
			assert_gte(BlockBody.event_time(w.light_moves[0], "release"), 0.0, "%s release" % w.id)
		elif w.kind == &"ranged":
			assert_gt(w.ammo, 0, String(w.id))
			assert_gte(BlockBody.event_time(w.light_moves[0], "fire"), 0.0, "%s fire" % w.id)
			assert_gt(w.projectile_speed, 10.0)


func test_every_weapon_has_a_model() -> void:
	for w: WeaponData in Registry.weapons.values():
		if w.is_fists():
			continue
		assert_not_null(w.mesh(), String(w.id))
		assert_eq(w.part_sizes.size(), w.part_centres.size(), String(w.id))


func test_heavy_slam_event_exists() -> void:
	assert_gte(BlockBody.event_time(&"Smash_Release", "slam"), 0.0)
	assert_gt(Registry.weapon(&"hammer").slam_radius, 1.0)
