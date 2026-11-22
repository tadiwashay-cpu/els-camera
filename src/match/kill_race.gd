class_name KillRace
extends RefCounted
## Timed Kill Race rules (doc: Core gameplay design). Pure logic: no nodes,
## so tests can drive it directly.
##   - a kill is +1; in the last 30 s it's +2
##   - a hazard death credits whoever hit the victim in the last 5 s,
##     otherwise the victim loses 1
##   - tie when the clock runs out: sudden death, next score change that
##     leaves one leader wins
##   - optional kill target ends the match early

const FINAL_SECONDS := 30.0
const CREDIT_WINDOW := 5.0

var duration := 180.0
var time_left := 180.0
var kill_target := 0
var scores: Dictionary = {}        # fighter id -> int
var overtime := false
var finished := false
var winner := -1
var _final_announced := false


func setup(ids: Array, minutes: float, target: int = 0) -> void:
	duration = maxf(minutes, 0.1) * 60.0
	time_left = duration
	kill_target = target
	scores.clear()
	for id: int in ids:
		scores[id] = 0
	overtime = false
	finished = false
	winner = -1
	_final_announced = false


## Advances the clock. Returns events: "final" (last 30 s start),
## "overtime" (sudden death), "end".
func tick(delta: float) -> Array[String]:
	var events: Array[String] = []
	if finished or overtime:
		return events
	time_left = maxf(time_left - delta, 0.0)
	if not _final_announced and time_left <= FINAL_SECONDS and duration > FINAL_SECONDS:
		_final_announced = true
		events.append("final")
	if time_left <= 0.0:
		var leaders := leaders()
		if leaders.size() == 1:
			finished = true
			winner = leaders[0]
			events.append("end")
		else:
			overtime = true
			events.append("overtime")
	return events


func points_per_kill() -> int:
	return 2 if time_left <= FINAL_SECONDS and not overtime and duration > FINAL_SECONDS else 1


## Records a death and returns {"id": who scored (or lost), "points": n}.
## `killer` is -1 for hazards; `last_hitter_age` is seconds since the
## victim was last hit by `last_hitter`.
func register_death(victim: int, killer: int, last_hitter: int = -1, last_hitter_age: float = INF) -> Dictionary:
	if finished:
		return {"id": -1, "points": 0}
	var credited := killer
	if credited == -1 or credited == victim:
		credited = last_hitter if last_hitter != -1 and last_hitter != victim and last_hitter_age <= CREDIT_WINDOW else -1
	var result := {"id": credited, "points": 0}
	if credited != -1:
		result["points"] = points_per_kill()
		scores[credited] = int(scores.get(credited, 0)) + int(result["points"])
	else:
		result["id"] = victim
		result["points"] = -1
		scores[victim] = int(scores.get(victim, 0)) - 1
	_check_end()
	return result


func leaders() -> Array[int]:
	var best := -1000000
	var out: Array[int] = []
	for id: int in scores:
		var s: int = scores[id]
		if s > best:
			best = s
			out = [id]
		elif s == best:
			out.append(id)
	return out


## Ids ordered by score, best first.
func ranking() -> Array:
	var ids := scores.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b] or (scores[a] == scores[b] and a < b))
	return ids


func _check_end() -> void:
	var leaders := leaders()
	if kill_target > 0 and int(scores.get(leaders[0], 0)) >= kill_target and leaders.size() == 1:
		finished = true
		winner = leaders[0]
	elif overtime and leaders.size() == 1:
		finished = true
		winner = leaders[0]
