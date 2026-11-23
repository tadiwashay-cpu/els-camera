extends GutTest
## The three arenas: registry and menu order, every layout's spawn points
## stand on solid ground, and the hazard rules (tide, sharks, cannon arc,
## crane patrol, oil, conveyor).

const BEACH := preload("res://src/arenas/beach_island.gd")
const HARBOR := preload("res://src/arenas/harbor_factory.gd")


func test_registry_lists_three_arenas_in_menu_order() -> void:
	assert_eq(Registry.arena_ids(), [&"blockout_yard", &"beach_island", &"harbor_factory"])
	for id: StringName in Registry.arena_ids():
		var a := Registry.arena(id)
		assert_true(ResourceLoader.exists(a.scene_path), "%s has a scene" % id)
		assert_gt(a.tips.size(), 2, "%s has loading tips" % id)
	var picked := Registry.pick_arena(&"random")
	assert_true(Registry.arena_ids().has(picked.id), "random picks a real arena")


func _ground_below(arena: Arena, p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 1.5, Game.L_WORLD)
	return not arena.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _check_layout(path: String) -> Arena:
	var arena := (load(path) as PackedScene).instantiate() as Arena
	add_child_autofree(arena)
	await wait_physics_frames(3)
	assert_gte(arena.spawn_points.size(), 6, "%s: spawn points" % path)
	assert_gte(arena.spawner_points.size(), 4, "%s: weapon spawners" % path)
	assert_eq(arena.pickup_points.size(), 6, "%s: pickup points" % path)
	for p in arena.spawn_points:
		assert_true(_ground_below(arena, p), "%s: spawn %s stands on ground" % [path, p])
		assert_gt(p.y, arena.water_level + 0.3, "%s: spawn %s is above the water" % [path, p])
		# Not on the brink: solid ground 1.5 m round in every direction.
		for k in 8:
			var a := TAU * k / 8.0
			assert_true(_ground_below(arena, p + Vector3(cos(a), 0, sin(a)) * 1.5), "%s: spawn %s has room round it (%d)" % [path, p, k])
	for p in arena.spawner_points + arena.pickup_points:
		assert_true(_ground_below(arena, p + Vector3.UP * 0.1), "%s: item spot %s is on ground" % [path, p])
	assert_true(arena.mystery_point == Vector3.INF or _ground_below(arena, arena.mystery_point + Vector3.UP * 0.1),
		"%s: mystery crate lands on something" % path)
	return arena


func test_yard_layout_is_sound() -> void:
	await _check_layout("res://src/arenas/blockout_yard.tscn")


func test_beach_layout_is_sound() -> void:
	await _check_layout("res://src/arenas/beach_island.tscn")


func test_harbor_layout_is_sound() -> void:
	await _check_layout("res://src/arenas/harbor_factory.tscn")


func test_themed_arenas_merge_static_meshes() -> void:
	var arena := (load("res://src/arenas/harbor_factory.tscn") as PackedScene).instantiate() as Arena
	add_child_autofree(arena)
	var merged := 0
	for c in arena.get_children():
		if c.name.begins_with("Merged_"):
			merged += 1
	assert_between(merged, 2, 8, "one mesh per surface type, not one per box")


func test_tide_comes_in_every_two_minutes() -> void:
	assert_eq(BEACH.tide_at(0.0), 0.0, "low at the start")
	assert_eq(BEACH.tide_at(44.0), 0.0)
	assert_between(BEACH.tide_at(48.0), 0.1, 0.9, "rising")
	assert_eq(BEACH.tide_at(60.0), 1.0, "high")
	assert_eq(BEACH.tide_at(100.0), 0.0, "back out")
	assert_eq(BEACH.tide_at(180.0), 1.0, "high again 2 minutes later")


func test_wading_slows_with_depth() -> void:
	assert_eq(BEACH.wading_factor(-1.0), 1.0, "dry")
	assert_eq(BEACH.wading_factor(0.05), 1.0, "a splash doesn't slow you")
	assert_lt(BEACH.wading_factor(0.5), 0.8, "knee deep is slow")
	assert_lt(BEACH.wading_factor(0.9), BEACH.wading_factor(0.5), "deeper is slower")


func test_cannon_arc_lands_on_the_lighthouse() -> void:
	var g := 24.0
	var from: Vector3 = BEACH.CANNON_MUZZLE
	var to: Vector3 = BEACH.LIGHTHOUSE_TOP
	var v: Vector3 = BEACH.ballistic(from, to, 1.6, g)
	var p := from
	var dt := 1.0 / 60.0
	for i in 96:
		v.y -= g * dt
		p += v * dt
	assert_lt(Vector2(p.x - to.x, p.z - to.z).length(), 0.6, "lands on the top")
	assert_almost_eq(p.y, to.y, 0.8)


func test_sharks_only_past_the_shelf() -> void:
	var beach := (load("res://src/arenas/beach_island.tscn") as PackedScene).instantiate() as Arena
	add_child_autofree(beach)
	assert_false(beach.in_deep_water(Vector3(0, -1.0, 0)), "wading on the sand shelf is safe")
	assert_true(beach.in_deep_water(Vector3(36, -1.5, -7)), "off the end of the pier: sharks")
	assert_true(beach.in_deep_water(Vector3(-4, -1.5, 25)), "under the rope bridge: sharks")
	assert_false(beach.in_deep_water(Vector3(36, 0.6, -7)), "on the pier: dry")


func test_crane_patrol_stays_on_its_rails() -> void:
	var t := 0.0
	var reached_water := false
	while t < 300.0:
		var p: Vector2 = HARBOR.patrol_at(t)
		assert_between(p.x, HARBOR.GANTRY_X.x - 0.01, HARBOR.GANTRY_X.y + 0.01)
		assert_between(p.y, HARBOR.TROLLEY_Z.x - 0.01, HARBOR.TROLLEY_Z.y + 0.01)
		if p.y < HARBOR.DUMP_Z + 0.5:
			reached_water = true
		t += 0.5
	assert_true(reached_water, "the magnet swings out over the water")


func test_oil_is_slippery_and_burns() -> void:
	var harbor := (load("res://src/arenas/harbor_factory.tscn") as PackedScene).instantiate() as Arena
	add_child_autofree(harbor)
	var spill: Vector3 = harbor.oil[0]["pos"]
	assert_lt(harbor.grip_at(spill), 0.5, "oil is slippery")
	assert_eq(harbor.grip_at(spill + Vector3(8, 0, 0)), 1.0, "concrete grips")
	harbor.ignite(spill + Vector3(1, 0.5, 0), 2.0, null)
	assert_gt(float(harbor.oil[0]["burn"]), 0.0, "a blast sets it alight")
	assert_eq(int(harbor.stats.get("fire", 0)), 1)


func test_conveyor_carries_you_toward_the_crusher() -> void:
	var harbor := (load("res://src/arenas/harbor_factory.tscn") as PackedScene).instantiate() as Arena
	add_child_autofree(harbor)
	var on_belt := Vector3(14, HARBOR.BELT_TOP, 14.5)
	assert_gt(harbor.floor_push(on_belt).x, 1.0, "the belt pushes toward the press")
	assert_eq(harbor.floor_push(Vector3(14, 0.0, 18)), Vector3.ZERO, "the floor doesn't")


func test_you_can_kick_out_of_the_water() -> void:
	var rise := Fighter.SWIM_JUMP * Fighter.SWIM_JUMP / (2.0 * 24.0)
	var quay_above_feet := Fighter.SWIM_DEPTH + (0.0 - HARBOR.WATER_Y)
	assert_gt(rise, quay_above_feet, "a swimmer's kick clears the harbour quay")


func test_outcrops_stay_dry_at_high_tide() -> void:
	var beach := (load("res://src/arenas/beach_island.tscn") as PackedScene).instantiate() as Arena
	add_child_autofree(beach)
	await wait_physics_frames(2)
	for o: Vector3 in BEACH.OUTCROPS:
		var q := PhysicsRayQueryParameters3D.create(o + Vector3.UP * 6.0, o + Vector3.DOWN * 2.0, Game.L_WORLD)
		var hit := beach.get_world_3d().direct_space_state.intersect_ray(q)
		assert_false(hit.is_empty(), "outcrop at %s is solid" % o)
		if not hit.is_empty():
			assert_gt((hit["position"] as Vector3).y, BEACH.TIDE_HIGH + 0.3, "outcrop at %s is above high tide" % o)


func test_water_wears_you_down_slowly() -> void:
	var beach := (load("res://src/arenas/beach_island.tscn") as PackedScene).instantiate() as Arena
	add_child_autofree(beach)
	assert_between(beach.wade_dps, 1.0, 5.0, "wading is a slow drain")
	assert_gt(beach.swim_dps, beach.wade_dps, "swimming drains faster")
	var exit: Vector3 = beach.swim_exit(Vector3(-36, -1.5, 0))
	assert_gt(exit.x, -30.0, "swimmers head back to the shelf")
	var pier: Vector3 = beach.swim_exit(Vector3(40, -1.5, -4))
	assert_lt(pier.distance_to(Vector3(40, pier.y, -4)), 4.0, "or the nearest pier")


func test_start_spots_never_stack() -> void:
	var pts: Array[Vector3] = []
	for k in 9:
		pts.append(Vector3(k * 5.0, 0, 0))
	var spots := Match.start_spots(pts, 9, 1234)
	var seen := {}
	for p in spots:
		assert_false(seen.has(p), "each fighter gets its own spawn point")
		seen[p] = true
	assert_eq(Match.start_spots(pts, 9, 1234), spots, "the same on every phone")
	var more := Match.start_spots(pts, 12, 5)
	assert_eq(more.size(), 12)
	assert_ne(more[9], more[0], "extra fighters stand beside a point, not on it")
