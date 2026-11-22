extends GutTest
## Power meter, powers' effects and map pickups.

var p: FighterPowers


func before_each() -> void:
	p = FighterPowers.new()


func test_meter_fills_from_dealing_and_taking_damage() -> void:
	p.dealt(50.0)
	assert_almost_eq(p.meter, 45.0, 0.001)
	p.taken(100.0)
	assert_almost_eq(p.meter, 80.0, 0.001)
	p.dealt(100.0)
	assert_eq(p.meter, FighterPowers.FULL, "capped")
	assert_true(p.ready_to_use())


func test_spend_needs_a_full_meter() -> void:
	p.gain(60.0)
	assert_false(p.spend())
	p.gain(60.0)
	assert_true(p.spend())
	assert_eq(p.meter, 0.0)


func test_rage_and_double_damage_cap() -> void:
	assert_eq(p.damage_dealt_mult(), 1.0)
	p.add_effect(&"rage", 5.0)
	assert_eq(p.damage_dealt_mult(), 2.0)
	p.apply_pickup(&"damage")
	assert_eq(p.damage_dealt_mult(), 2.5, "rage + double damage stack to a cap")


func test_iron_skin() -> void:
	p.add_effect(&"iron_skin", 4.0)
	assert_almost_eq(p.damage_taken_mult(), 0.3, 0.001)
	assert_false(p.can_be_knocked_down())
	p.tick(4.1)
	assert_eq(p.damage_taken_mult(), 1.0, "wears off")
	assert_true(p.can_be_knocked_down())


func test_shield_soaks_damage() -> void:
	p.apply_pickup(&"shield")
	assert_almost_eq(p.absorb(30.0), 0.0, 0.001)
	assert_almost_eq(p.absorb(30.0), 10.0, 0.001, "20 left in the shield, 10 gets through")
	assert_almost_eq(p.shield, 0.0, 0.001)


func test_battery_and_speed() -> void:
	p.apply_pickup(&"battery")
	assert_true(p.ready_to_use())
	p.apply_pickup(&"speed")
	assert_almost_eq(p.speed_mult(), 1.3, 0.001)
	p.tick(10.5)
	assert_almost_eq(p.speed_mult(), 1.0, 0.001)


func test_death_clears_effects_keeps_meter() -> void:
	p.gain(40.0)
	p.add_effect(&"rage", 5.0)
	p.apply_pickup(&"shield")
	p.on_death()
	assert_false(p.has(&"rage"))
	assert_eq(p.shield, 0.0)
	assert_almost_eq(p.meter, 40.0, 0.001)


func test_every_power_has_info_and_an_animation() -> void:
	var moves := BlockBody.moves()
	for id in FighterPowers.IDS:
		var info: Dictionary = FighterPowers.INFO[id]
		assert_true(moves.has(String(info["anim"])), "%s animation" % id)
		assert_true(moves.has(String(info["anim"]) + "_Sword"), "%s sword animation" % id)
	for clip in ["Block", "Block_Fists", "Parry", "Parry_Fists", "Stagger"]:
		assert_true(moves.has(clip), clip)
