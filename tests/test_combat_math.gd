extends GutTest
## Damage from blade speed, hit geometry and spawn choice.


func test_damage_scales_with_tip_speed() -> void:
	assert_almost_eq(WeaponData.speed_damage(16.0, 9.0, 9.0), 16.0, 0.001)
	assert_almost_eq(WeaponData.speed_damage(16.0, 18.0, 9.0), 32.0, 0.001)


func test_damage_is_clamped() -> void:
	assert_almost_eq(WeaponData.speed_damage(10.0, 0.0, 9.0), 5.0, 0.001, "slow swings still do half")
	assert_almost_eq(WeaponData.speed_damage(10.0, 100.0, 9.0), 25.0, 0.001, "capped at 2.5x")


func test_segment_distance_parallel_and_crossing() -> void:
	var d := Geo.segment_distance(Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(1, 1, 0))
	assert_almost_eq(d, 1.0, 0.0001)
	d = Geo.segment_distance(Vector3(-1, 0.5, 0.3), Vector3(1, 0.5, 0.3), Vector3(0, 0, 0), Vector3(0, 1, 0))
	assert_almost_eq(d, 0.3, 0.0001)


func test_segment_distance_endpoints() -> void:
	var d := Geo.segment_distance(Vector3(0, 2, 0), Vector3(0, 3, 0), Vector3(0, 0, 0), Vector3(0, 1, 0))
	assert_almost_eq(d, 1.0, 0.0001)
	d = Geo.segment_distance(Vector3(2, 0, 0), Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0))
	assert_almost_eq(d, 2.0, 0.0001, "a point against a segment")


func test_farthest_spawn() -> void:
	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(-20, 0, 0)]
	var enemies: Array[Vector3] = [Vector3(1, 0, 0)]
	assert_eq(Arena.farthest_spawn(points, enemies), 2)
	enemies = [Vector3(-19, 0, 0), Vector3(0, 0, 1)]
	assert_eq(Arena.farthest_spawn(points, enemies), 1)


func test_fighter_input_world_move() -> void:
	var inp := FighterInput.new()
	inp.aim_yaw = 0.0
	inp.move = Vector2(0, 1)
	assert_almost_eq(inp.world_move().distance_to(Vector3(0, 0, -1)), 0.0, 0.0001, "forward is -Z at yaw 0")
	inp.move = Vector2(1, 0)
	assert_almost_eq(inp.world_move().distance_to(Vector3(1, 0, 0)), 0.0, 0.0001)
	inp.steer(Vector3(3, 0, 0), 0.5)
	assert_almost_eq(inp.world_move().distance_to(Vector3(0.5, 0, 0)), 0.0, 0.0001, "steer round-trips")


func test_fighter_input_buffer() -> void:
	var inp := FighterInput.new()
	inp.press(&"jump")
	assert_true(inp.pressed_recently(&"jump"))
	assert_true(inp.consume(&"jump"))
	assert_false(inp.consume(&"jump"), "a press is used once")
