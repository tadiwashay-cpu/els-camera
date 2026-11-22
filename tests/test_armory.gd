extends GutTest
## The Armory: ranked prices, buying, equipping, what a fighter may hold.


func _fresh() -> Dictionary:
	return Save.from_json("")


func test_every_weapon_has_a_rank_and_a_price() -> void:
	for w: WeaponData in Registry.weapons.values():
		assert_true(Armory.RANKS.has(w.tier), "%s rank %s" % [w.id, w.tier])
		if Armory.FREE.has(w.id):
			assert_eq(Armory.price(w), 0, "%s is free" % w.id)
		else:
			assert_eq(Armory.price(w), int(Armory.PRICES[w.tier]), String(w.id))
	assert_gt(Armory.PRICES["S+"], Armory.PRICES["S"])
	assert_gt(Armory.PRICES["S"], Armory.PRICES["A"])
	assert_gt(Armory.PRICES["A"], Armory.PRICES["B"])
	assert_gt(Armory.PRICES["B"], Armory.PRICES["C"])


func test_catalogue_is_sorted_by_rank() -> void:
	var list := Armory.catalogue()
	assert_eq(list.size(), Registry.weapons.size())
	for i in range(1, list.size()):
		assert_true(Armory.RANKS.find(list[i - 1].tier) <= Armory.RANKS.find(list[i].tier))


func test_every_power_has_a_description() -> void:
	for w: WeaponData in Registry.weapons.values():
		assert_ne(WeaponSkills.describe(w.skill), "", "%s power %s" % [w.id, w.skill])


func test_new_save_owns_only_the_free_weapons() -> void:
	var d := _fresh()
	assert_true(Armory.owns(&"sword", d))
	assert_true(Armory.owns(&"fists", d))
	assert_false(Armory.owns(&"katana", d))
	assert_eq(Armory.equipped(d), &"sword")


func test_buy_takes_coins_and_unlocks() -> void:
	var d := _fresh()
	var katana := Registry.weapon(&"katana")
	d["coins"] = Armory.price(katana) - 1
	assert_false(Armory.buy(katana, d), "too dear")
	assert_false(Armory.owns(&"katana", d))
	d["coins"] = Armory.price(katana) + 20
	assert_true(Armory.buy(katana, d))
	assert_eq(int(d["coins"]), 20)
	assert_true(Armory.owns(&"katana", d))
	assert_false(Armory.buy(katana, d), "already owned")
	assert_eq(int(d["coins"]), 20)
	assert_true(Armory.equip(&"katana", d))
	assert_eq(Armory.equipped(d), &"katana")
	assert_false(Armory.equip(&"bazooka", d), "can't equip what you don't own")
	assert_eq(Armory.equipped(d), &"katana")


func test_save_round_trip_keeps_the_locker() -> void:
	var d := _fresh()
	d["owned"].append("bow")
	d["equipped"] = "bow"
	var back := Save.from_json(Save.to_json(d))
	assert_true(Armory.owns(&"bow", back))
	assert_eq(Armory.equipped(back), &"bow")


func test_damaged_locker_falls_back() -> void:
	var d := Save.from_json('{"owned": "nonsense", "equipped": "laser_cannon"}')
	assert_true(Armory.owns(&"sword", d))
	assert_eq(Armory.equipped(d), &"sword")
	var tidy := Armory.clean_locker(["katana", "not_a_weapon", 7])
	assert_true(tidy.has("katana"))
	assert_true(tidy.has("sword"))
	assert_false(tidy.has("not_a_weapon"))


func test_welcome_bonus_once() -> void:
	var d := _fresh()
	assert_true(Save.grant_welcome(d))
	assert_eq(int(d["coins"]), Save.WELCOME_COINS)
	assert_false(Save.grant_welcome(d), "only once")
	assert_eq(int(d["coins"]), Save.WELCOME_COINS)


func test_match_coins() -> void:
	assert_eq(Armory.match_coins(0, false), Armory.COINS_FOR_PLAYING)
	assert_eq(Armory.match_coins(4, true), 4 * Armory.COINS_PER_KILL + Armory.COINS_FOR_WIN + Armory.COINS_FOR_PLAYING)
	assert_eq(Armory.match_coins(-2, false), Armory.COINS_FOR_PLAYING, "negative scores pay nothing extra")


func test_fighter_locker() -> void:
	var f := Fighter.new()
	assert_true(f.can_use(Registry.weapon(&"bazooka")), "an empty locker (a bot) holds anything")
	f.set_locker(["sword", "fists", "bow"])
	assert_true(f.can_use(Registry.weapon(&"bow")))
	assert_false(f.can_use(Registry.weapon(&"bazooka")))
	assert_true(f.can_use(Registry.weapon(&"fists")))
	f.free()
