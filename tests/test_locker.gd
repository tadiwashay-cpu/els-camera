extends GutTest
## Customisation (Look) and upgrades (Upgrades).

var _saved: Dictionary


func before_each() -> void:
	_saved = Save.data.duplicate(true)


func after_each() -> void:
	Save.data = _saved
	Save.save_data()


func test_clean_fixes_bad_looks() -> void:
	var c := Look.clean({"skin": 99, "shirt": -1, "hair": "laser", "hat": "crown", "face": 7})
	assert_lt(int(c["skin"]), Look.SKIN_TONES.size())
	assert_gte(int(c["shirt"]), 0)
	assert_eq(c["hair"], "band", "unknown hair falls back")
	assert_eq(c["hat"], "crown")
	assert_eq(c["face"], "fierce")
	assert_eq(Look.clean(null), Look.DEFAULT, "nothing -> the default look")


func test_free_parts_are_owned_paid_ones_bought() -> void:
	Save.data["coins"] = 1000
	Save.data["looks_owned"] = []
	assert_true(Look.owns(&"hair", &"short"))
	assert_false(Look.owns(&"hat", &"crown"))
	assert_true(Look.buy(&"hat", &"crown"))
	assert_true(Look.owns(&"hat", &"crown"))
	assert_eq(int(Save.data["coins"]), 200)
	assert_false(Look.buy(&"hair", &"mohawk"), "can't afford")


func test_unbought_parts_are_not_saved() -> void:
	Save.data["looks_owned"] = []
	var look := Look.mine()
	look["hat"] = "crown"
	look["shirt"] = 5
	Look.save_mine(look)
	assert_eq(Look.mine()["hat"], "none", "the crown wasn't bought")
	assert_eq(int(Look.mine()["shirt"]), 5, "colours are free")


func test_every_part_builds_a_body() -> void:
	for kind: StringName in Look.KINDS:
		for id: StringName in Look.KINDS[kind]:
			var look := Look.DEFAULT.duplicate()
			look[String(kind)] = String(id)
			var b := BlockBody.new()
			add_child_autofree(b)
			b.setup(Look.skin_data(look), false)
			assert_not_null(b.mesh_instance.mesh, "%s %s" % [kind, id])
			assert_lt(b.mesh_instance.mesh.get_faces().size() / 3, 900, "a body stays light")


func test_upgrades_cost_and_cap() -> void:
	Save.data["coins"] = 10000
	Save.data["upgrades"] = {"health": 0, "damage": 0, "speed": 0, "power": 0}
	for i in Upgrades.MAX_LEVEL:
		assert_true(Upgrades.buy(&"health"))
	assert_eq(Upgrades.level(&"health"), 5)
	assert_false(Upgrades.buy(&"health"), "maxed")
	assert_eq(int(Save.data["coins"]), 10000 - 3800)


func test_upgrades_change_the_fighter() -> void:
	var f := Fighter.new()
	var base_run := f.run_speed
	Upgrades.apply(f, {"health": 5, "damage": 2, "speed": 5, "power": 5})
	add_child_autofree(f)
	assert_almost_eq(f.max_health, 125.0, 0.01)
	assert_almost_eq(f.health, 125.0, 0.01, "starts full")
	assert_almost_eq(f.powers.damage_dealt_mult(), 1.08, 0.001)
	assert_almost_eq(f.run_speed, base_run * 1.1, 0.001)
	assert_almost_eq(f.skill_cd_mult, 0.7, 0.001)


func test_network_levels_are_clamped() -> void:
	var c := Upgrades.clean({"health": 99, "damage": -3, "speed": "x"})
	assert_eq(int(c["health"]), 5)
	assert_eq(int(c["damage"]), 0)
	assert_eq(int(c["speed"]), 0)
	assert_eq(int(c["power"]), 0)
