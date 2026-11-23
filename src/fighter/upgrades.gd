class_name Upgrades
extends RefCounted
## Fighter upgrades bought with coins (Locker screen): health, damage,
## speed and power, five levels each. Kept in the save ("upgrades"); online
## each player's levels go to the host in the hello and ride the roster, so
## every machine builds the same fighter. Bots get a level or two by
## difficulty so upgraded players still meet a fight.

const STATS: Array[StringName] = [&"health", &"damage", &"speed", &"power"]
const NAMES := {&"health": "HEALTH", &"damage": "DAMAGE", &"speed": "SPEED", &"power": "POWER"}
const MAX_LEVEL := 5
const COSTS: Array[int] = [200, 400, 700, 1000, 1500]
## What one level adds.
const PER_LEVEL := {&"health": 0.05, &"damage": 0.04, &"speed": 0.02, &"power": 0.06}
const COLORS := {&"health": Color(0.4, 1.0, 0.5), &"damage": Color(1.0, 0.38, 0.28),
	&"speed": Color(0.45, 0.8, 1.0), &"power": Color(1.0, 0.8, 0.3)}


static func describe(stat: StringName) -> String:
	var pct := int(round(float(PER_LEVEL[stat]) * 100.0))
	match stat:
		&"health": return "+%d%% health per level" % pct
		&"damage": return "+%d%% damage per level" % pct
		&"speed": return "+%d%% run and sprint speed per level" % pct
		&"power": return "Weapon power back %d%% sooner, power meter fills %d%% faster, per level" % [pct, pct]
	return ""


## Your levels, from the save.
static func levels() -> Dictionary:
	return clean(Save.data.get("upgrades", {}))


static func level(stat: StringName) -> int:
	return int(levels().get(stat, 0))


## Coins for the next level of `stat` (-1 when maxed).
static func next_cost(stat: StringName) -> int:
	var l := level(stat)
	return COSTS[l] if l < MAX_LEVEL else -1


static func can_buy(stat: StringName) -> bool:
	var c := next_cost(stat)
	return c > 0 and int(Save.data["coins"]) >= c


static func buy(stat: StringName) -> bool:
	if not can_buy(stat):
		return false
	var lv := levels()
	Save.data["coins"] = int(Save.data["coins"]) - next_cost(stat)
	lv[String(stat)] = int(lv.get(stat, 0)) + 1
	Save.data["upgrades"] = lv
	Save.save_data()
	return true


## Levels from anywhere (the save, the network) made safe: known stats, 0..5.
static func clean(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for stat in STATS:
			var v: Variant = (raw as Dictionary).get(String(stat), (raw as Dictionary).get(stat, 0))
			out[String(stat)] = clampi(int(v) if (v is int or v is float) else 0, 0, MAX_LEVEL)
	else:
		for stat in STATS:
			out[String(stat)] = 0
	return out


## Bots: a level in everything on Normal, two on Hard.
static func for_bot(difficulty: int) -> Dictionary:
	var out := {}
	for stat in STATS:
		out[String(stat)] = clampi(difficulty, 0, 2)
	return out


## Before the fighter enters the tree (its health fills from max_health).
static func apply(f: Fighter, lv: Dictionary) -> void:
	var c := clean(lv)
	f.max_health *= 1.0 + float(PER_LEVEL[&"health"]) * int(c["health"])
	f.powers.damage_bonus = 1.0 + float(PER_LEVEL[&"damage"]) * int(c["damage"])
	var sp := 1.0 + float(PER_LEVEL[&"speed"]) * int(c["speed"])
	f.run_speed *= sp
	f.sprint_speed *= sp
	var pw := float(PER_LEVEL[&"power"]) * int(c["power"])
	f.skill_cd_mult = 1.0 - pw
	f.powers.gain_mult = 1.0 + pw
	f.upgrades = c
