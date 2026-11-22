extends GutTest
## Scenery that breaks: damage, shattering, the blast signal and rebuilding.

var arena: Arena


func before_each() -> void:
	arena = Arena.new()
	add_child_autofree(arena)


func test_crate_takes_damage_then_shatters() -> void:
	var crate := arena.breakable(Breakable.Kind.CRATE, Vector3.ONE, Vector3(0, 0.5, 0), Color.BROWN)
	crate.hit(crate.max_hp * 0.5, crate.global_position, Vector3.ZERO, null)
	assert_false(crate.is_broken)
	crate.hit(crate.max_hp, crate.global_position, Vector3.ZERO, null)
	assert_true(crate.is_broken)
	assert_eq(crate.collision_layer, 0, "a broken piece stops blocking")
	assert_gt(arena.debris.active_count(), 0, "debris flies")


func test_broken_pieces_ignore_hits_and_queries() -> void:
	var crate := arena.breakable(Breakable.Kind.CRATE, Vector3.ONE, Vector3(0, 0.5, 0), Color.BROWN)
	crate.shatter()
	crate.hit(100.0, Vector3.ZERO, Vector3.ZERO, null)
	assert_null(arena.breakable_near(Vector3(0, 0.5, 0), 0.5))
	assert_eq(arena.breakables_on_segment(Vector3(-2, 0.5, 0), Vector3(2, 0.5, 0), 0.1).size(), 0)


func test_segment_query_finds_pieces_in_the_way() -> void:
	arena.breakable(Breakable.Kind.PILLAR, Vector3(1, 4, 1), Vector3(0, 2, 0), Color.GRAY)
	assert_eq(arena.breakables_on_segment(Vector3(-2, 1, 0), Vector3(2, 1, 0), 0.1).size(), 1)
	assert_eq(arena.breakables_on_segment(Vector3(-2, 1, 3), Vector3(2, 1, 3), 0.1).size(), 0)


func test_barrel_signals_an_explosion_with_the_culprit() -> void:
	var barrel := arena.breakable(Breakable.Kind.BARREL, Vector3(0.8, 1.1, 0.8), Vector3(3, 0.55, 0), Color.RED)
	watch_signals(arena)
	barrel.hit(999.0, barrel.global_position, Vector3.ZERO, null)
	assert_signal_emitted(arena, "explosion")


func test_rebuilds_after_a_while() -> void:
	var crate := arena.breakable(Breakable.Kind.CRATE, Vector3.ONE, Vector3(0, 0.5, 9), Color.BROWN)
	crate.shatter()
	crate._respawn_at = crate._clock + 0.2
	await wait_seconds(0.5)
	assert_false(crate.is_broken, "back after its respawn time")
	assert_almost_eq(crate.hp, crate.max_hp, 0.001)
