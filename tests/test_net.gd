extends GutTest
## LAN plumbing that doesn't need two phones: discovery packets, settings
## round trips, offline defaults.


func test_discovery_packets_round_trip() -> void:
	var bytes := LanDiscovery.encode({"name": "Tablet", "players": 2, "max": 4, "version": "0.3.0"})
	var d := LanDiscovery.decode(bytes)
	assert_eq(str(d["name"]), "Tablet")
	assert_eq(int(d["players"]), 2)


func test_discovery_ignores_other_packets() -> void:
	assert_true(LanDiscovery.decode("hello".to_utf8_buffer()).is_empty())
	assert_true(LanDiscovery.decode(JSON.stringify({"tag": "SomeOtherGame"}).to_utf8_buffer()).is_empty())


func test_broadcasts_go_everywhere() -> void:
	var addrs := LanDiscovery.broadcast_addresses()
	assert_true(addrs.has("255.255.255.255"), "the global broadcast")
	for a in addrs:
		assert_true(a.ends_with(".255"), "%s is a broadcast address" % a)


func test_match_settings_survive_the_trip() -> void:
	var c := MatchConfig.new()
	c.minutes = 5.0
	c.bots = 2
	c.difficulty = 2
	c.arena_choice = &"harbor_factory"
	c.start_weapon = &"random"
	c.hazards = false
	var s := Net._settings_from(c)
	s["arena_id"] = "harbor_factory"
	s["seed"] = 42
	var back := MatchConfig.new()
	Net._apply_settings(back, s)
	assert_eq(back.minutes, 5.0)
	assert_eq(back.bots, 2)
	assert_eq(back.difficulty, 2)
	assert_eq(back.arena_id, &"harbor_factory")
	assert_eq(back.start_weapon, &"random")
	assert_false(back.hazards)
	assert_eq(back.seed, 42)


func test_offline_this_phone_is_the_authority() -> void:
	assert_false(Net.active)
	assert_true(Net.authority(), "offline matches run their own rules")
