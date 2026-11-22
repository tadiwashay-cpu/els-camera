extends GutTest
## Timed Kill Race rules.

var race: KillRace


func before_each() -> void:
	race = KillRace.new()
	race.setup([0, 1, 2], 3.0)


func test_a_kill_scores_one() -> void:
	var r := race.register_death(1, 0)
	assert_eq(r["id"], 0)
	assert_eq(r["points"], 1)
	assert_eq(race.scores[0], 1)


func test_hazard_death_credits_recent_hitter() -> void:
	var r := race.register_death(1, -1, 2, 3.0)
	assert_eq(r["id"], 2, "hit within 5 s: the hitter gets the kill")
	assert_eq(race.scores[2], 1)


func test_hazard_death_without_recent_hit_costs_a_point() -> void:
	var r := race.register_death(1, -1, 2, 6.0)
	assert_eq(r["id"], 1)
	assert_eq(r["points"], -1)
	assert_eq(race.scores[1], -1)


func test_self_hit_is_not_credit() -> void:
	race.register_death(1, 1, 1, 1.0)
	assert_eq(race.scores[1], -1)


func test_last_30_seconds_double() -> void:
	race.tick(race.duration - 29.0)
	assert_eq(race.points_per_kill(), 2)
	race.register_death(2, 0)
	assert_eq(race.scores[0], 2)


func test_final_event_fires_once() -> void:
	var first := race.tick(race.duration - 29.0)
	var second := race.tick(1.0)
	assert_has(first, "final")
	assert_does_not_have(second, "final")


func test_time_up_with_a_leader_ends() -> void:
	race.register_death(1, 0)
	var ev := race.tick(race.duration + 1.0)
	assert_has(ev, "end")
	assert_true(race.finished)
	assert_eq(race.winner, 0)


func test_tie_goes_to_sudden_death_and_next_kill_wins() -> void:
	race.register_death(1, 0)
	race.register_death(0, 1)
	var ev := race.tick(race.duration + 1.0)
	assert_has(ev, "overtime")
	assert_false(race.finished)
	assert_eq(race.points_per_kill(), 1, "overtime kills count 1")
	race.register_death(0, 1)
	assert_true(race.finished)
	assert_eq(race.winner, 1)


func test_kill_target_ends_early() -> void:
	race.setup([0, 1], 5.0, 2)
	race.register_death(1, 0)
	assert_false(race.finished)
	race.register_death(1, 0)
	assert_true(race.finished)
	assert_eq(race.winner, 0)


func test_ranking_is_best_first() -> void:
	race.register_death(0, 2)
	race.register_death(1, 2)
	race.register_death(2, 1)
	assert_eq(race.ranking(), [2, 1, 0])
