extends GutTest
## The weapon roster: data that the rig and the game can actually use.


func test_roster_size_and_pools() -> void:
	assert_eq(Registry.weapons.size(), 48, "47 weapons + fists")
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


func test_every_shot_style_exists() -> void:
	for w: WeaponData in Registry.weapons.values():
		if w.kind == &"ranged":
			assert_true(w.projectile == &"wind" or Bolt.STYLES.has(w.projectile), "%s fires a known shot (%s)" % [w.id, w.projectile])
			assert_gt(w.hit_to, 0.1, "%s has a muzzle" % w.id)


func test_finishes_are_matte_metal_or_glow() -> void:
	for w: WeaponData in Registry.weapons.values():
		for c in w.part_colors:
			assert_true(is_equal_approx(c.a, 1.0) or is_equal_approx(c.a, 0.5) or is_equal_approx(c.a, 0.0),
				"%s part finish %s" % [w.id, c.a])


func test_special_weapons_are_wired() -> void:
	assert_true(Registry.weapon(&"thunderbolt").lightning)
	assert_gt(Registry.weapon(&"saw_blade").bounces, 0)
	assert_eq(Registry.weapon(&"snowball").effect, &"chill")
	assert_eq(Registry.weapon(&"ice_cream").effect, &"chill")
	assert_true(Registry.weapon(&"umbrella").glide)
	assert_lt(Registry.weapon(&"shield").block_mult, 0.5, "shields soak blocked hits")
	assert_eq(Registry.weapon(&"shield").hand, &"left")
	assert_true(Registry.weapon(&"rocket_fist").returns)
	assert_gt(Registry.weapon(&"sniper").fire_cooldown, 0.5, "the sniper can't spam")
	for id: StringName in [&"bazooka", &"sniper", &"thunderbolt", &"scepter"]:
		assert_eq(Registry.weapon(id).rarity, &"rare", "%s comes from the mystery crate" % id)


func test_chill_slows() -> void:
	var p := FighterPowers.new()
	assert_eq(p.speed_mult(), 1.0)
	p.add_effect(&"chill", 2.0)
	assert_lt(p.speed_mult(), 0.7)
	assert_eq(FighterPowers.effect_name(&"chill"), "CHILLED")
	p.tick(2.5)
	assert_eq(p.speed_mult(), 1.0, "it wears off")
