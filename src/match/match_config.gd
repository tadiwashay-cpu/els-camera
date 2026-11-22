class_name MatchConfig
extends RefCounted
## Settings for one match (doc: Match rules).

const TIMES: Array[int] = [1, 3, 5, 8, 10, 15]
const DIFFICULTIES: Array[String] = ["EASY", "NORMAL", "HARD"]

var minutes := 3.0
var bots := 1                       # opponents (1..3)
var difficulty := 1                 # 0 easy, 1 normal, 2 hard
var arena_id := &"blockout_yard"
var start_weapon := &"sword"        # weapon id, or &"fists"
var spawners := true
var spawner_seconds := 15.0
var hazards := true
var kill_target := 0                # 0 = off; first to N ends the match
var seed := 0


func describe() -> String:
	return "%d min · %d bot%s · %s" % [int(minutes), bots, "" if bots == 1 else "s", DIFFICULTIES[difficulty]]
