class_name FighterPowers
extends RefCounted
## A fighter's power meter, the power they picked, and timed effects from
## powers and map pickups (doc: Powers, Map pickups). Pure state: the
## Fighter asks it for multipliers; tests drive it directly.

const IDS: Array[StringName] = [&"rage", &"stomp", &"blink", &"iron_skin", &"bullet_time", &"second_wind"]
const INFO := {
	&"blink": {"name": "Blink", "desc": "Teleport 8 m forward, through enemies", "color": Color(0.45, 0.8, 1.0), "anim": &"Power_Blink", "time": 0.0},
	&"bullet_time": {"name": "Bullet Time", "desc": "Everyone else moves at half speed", "color": Color(0.55, 0.65, 1.0), "anim": &"Power_Roar", "time": 3.0},
	&"stomp": {"name": "Shockwave Stomp", "desc": "Knocks everyone within 5 m into the air", "color": Color(1.0, 0.72, 0.25), "anim": &"Power_Stomp", "time": 0.0},
	&"rage": {"name": "Rage", "desc": "Double damage", "color": Color(1.0, 0.22, 0.18), "anim": &"Power_Roar", "time": 5.0},
	&"iron_skin": {"name": "Iron Skin", "desc": "70% less damage, can't be knocked down", "color": Color(0.78, 0.8, 0.88), "anim": &"Power_Roar", "time": 4.0},
	&"second_wind": {"name": "Second Wind", "desc": "Heal 50% and get straight back up", "color": Color(0.4, 1.0, 0.5), "anim": &"Power_Roar", "time": 0.0},
}
## Map pickups: id -> what they do.
const PICKUPS := {
	&"health": {"name": "+35 HP", "color": Color(0.35, 1.0, 0.45)},
	&"speed": {"name": "SPEED", "color": Color(0.3, 0.9, 1.0), "time": 10.0},
	&"damage": {"name": "DOUBLE DAMAGE", "color": Color(1.0, 0.55, 0.15), "time": 10.0},
	&"shield": {"name": "SHIELD", "color": Color(0.45, 0.6, 1.0)},
	&"battery": {"name": "POWER CHARGED", "color": Color(1.0, 0.9, 0.3)},
}

## Statuses weapons put on you.
const STATUS := {
	&"chill": {"name": "CHILLED", "color": Color(0.55, 0.85, 1.0)},
	&"overclock": {"name": "OVERCLOCK", "color": Color(1.0, 0.5, 0.2)},
	&"bulwark": {"name": "BULWARK", "color": Color(0.45, 0.7, 1.0)},
	&"overdrive": {"name": "OVERDRIVE", "color": Color(1.0, 0.35, 0.75)},
}

const FULL := 100.0
const DEAL_GAIN := 0.9         # meter per point of damage dealt
const TAKE_GAIN := 0.35        # ... and taken
const SHIELD := 50.0

var power := &"rage"
var meter := 0.0
var shield := 0.0
var effects: Dictionary = {}   # effect id -> seconds left


func ready_to_use() -> bool:
	return meter >= FULL


func gain(amount: float) -> void:
	meter = clampf(meter + amount, 0.0, FULL)


func dealt(damage: float) -> void:
	gain(damage * DEAL_GAIN)


func taken(damage: float) -> void:
	gain(damage * TAKE_GAIN)


## Empties a full meter; false if it wasn't full.
func spend() -> bool:
	if meter < FULL:
		return false
	meter = 0.0
	return true


func add_effect(id: StringName, seconds: float) -> void:
	effects[id] = maxf(float(effects.get(id, 0.0)), seconds)


func has(id: StringName) -> bool:
	return float(effects.get(id, 0.0)) > 0.0


func time_left(id: StringName) -> float:
	return maxf(float(effects.get(id, 0.0)), 0.0)


func tick(delta: float) -> void:
	for id: StringName in effects.keys():
		effects[id] = float(effects[id]) - delta
		if effects[id] <= 0.0:
			effects.erase(id)


func damage_dealt_mult() -> float:
	var m := 1.0
	if has(&"rage"):
		m *= 2.0
	if has(&"damage"):
		m *= 2.0
	if has(&"overclock"):
		m *= 1.3
	return minf(m, 2.5)


func damage_taken_mult() -> float:
	if has(&"bulwark"):
		return 0.15
	return 0.3 if has(&"iron_skin") else 1.0


func can_be_knocked_down() -> bool:
	return not has(&"iron_skin")


func speed_mult() -> float:
	var m := 1.3 if has(&"speed") else 1.0
	if has(&"chill"):
		m *= 0.55
	return m


## Takes what the shield can soak up; returns the damage left over.
func absorb(damage: float) -> float:
	var used := minf(shield, damage)
	shield -= used
	return damage - used


## Applies a map pickup; returns what to tell the player.
func apply_pickup(kind: StringName) -> String:
	match kind:
		&"speed", &"damage":
			add_effect(kind, float(PICKUPS[kind]["time"]))
		&"shield":
			shield = SHIELD
		&"battery":
			meter = FULL
	return str(PICKUPS[kind]["name"])


## Death clears effects and the shield; the meter is kept.
func on_death() -> void:
	effects.clear()
	shield = 0.0


## The colour of the strongest active effect (for the body's glow), or black.
func aura() -> Color:
	for id: StringName in [&"rage", &"iron_skin", &"bullet_time", &"damage", &"speed", &"chill"]:
		if has(id):
			return effect_color(id)
	return Color.BLACK


## The HUD name of any effect (power, pickup or status).
static func effect_name(id: StringName) -> String:
	for table: Dictionary in [INFO, PICKUPS, STATUS]:
		if table.has(id):
			return str(table[id]["name"])
	return String(id).to_upper()


static func effect_color(id: StringName) -> Color:
	for table: Dictionary in [INFO, PICKUPS, STATUS]:
		if table.has(id):
			return table[id]["color"]
	return Color.WHITE
