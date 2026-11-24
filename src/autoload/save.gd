extends Node
## The save file (user://save.json): coins, unlocks, settings and stats.

const PATH := "user://save.json"
## Coins given once, the first time a save meets the Armory.
const WELCOME_COINS := 500
const DEFAULTS := {
	"coins": 0,
	"unlocks": [],
	"owned": ["sword", "fists"],   # weapons bought in the Armory (Armory)
	"equipped": "sword",           # the weapon you start with ("Your weapon")
	"welcome_bonus": false,
	"upgrades": {"health": 0, "damage": 0, "speed": 0, "power": 0},   # levels 0..5 (Upgrades)
	# Your fighter's look (Look): palette indices and part ids.
	"look": {"skin": 1, "shirt": 0, "pants": 9, "shoes": 11, "hair": "band", "hair_color": 0,
		"hat": "none", "hat_color": 0, "face": "fierce"},
	"looks_owned": [],             # bought parts, "hair:spiky", "hat:crown"... (Look)
	"settings": {
		"quality": 1,             # 0 low, 1 medium (Redmi Pad 2 default), 2 high
		"show_fps": false,
		"look_sensitivity": 1.0,
		"aim_assist": 0.6,        # 0..1
		"vibration": true,
		"master_volume": 0.9,
		"touch_scale": 1.0,
		"touch_opacity": 0.6,
		"touch_on_desktop": false,
		"player_name": "You",
		"camera_mode": "third",      # "third" or "first" (FPP)
		"motion_blur": true,         # first person blur when turning / running
		"button_labels": true,       # touch buttons: picture + name (false: picture only)
		"touch_layout": {},           # action -> [x offset, y offset, size] (TouchControls)
		"bindings": {},               # action -> {"key": physical keycode, "pad": button} (Game)
	},
	"stats": {"matches": 0, "wins": 0, "kills": 0, "deaths": 0},
}

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	var text := FileAccess.get_file_as_string(PATH) if FileAccess.file_exists(PATH) else ""
	data = from_json(text)
	if grant_welcome(data):
		save_data()


## The one-time Armory welcome: some coins to buy a first weapon. Returns
## true if it was granted now.
static func grant_welcome(d: Dictionary) -> bool:
	if bool(d.get("welcome_bonus", false)):
		return false
	d["welcome_bonus"] = true
	d["coins"] = int(d.get("coins", 0)) + WELCOME_COINS
	return true


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(to_json(data))


func setting(key: String) -> Variant:
	if data.is_empty():
		load_data()
	return data["settings"].get(key, DEFAULTS["settings"].get(key))


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_data()


func add_coins(amount: int) -> void:
	data["coins"] = maxi(int(data["coins"]) + amount, 0)
	save_data()


func add_stat(key: String, amount: int = 1) -> void:
	data["stats"][key] = int(data["stats"].get(key, 0)) + amount


## Parses a save file, filling anything missing (or of the wrong type)
## from DEFAULTS, so old or damaged saves still load.
static func from_json(text: String) -> Dictionary:
	var parsed: Variant = null
	var json := JSON.new()
	if not text.is_empty() and json.parse(text) == OK:   # a damaged file just means defaults
		parsed = json.data
	return _merge(DEFAULTS, parsed if parsed is Dictionary else {})


static func to_json(d: Dictionary) -> String:
	return JSON.stringify(d, "\t")


static func _merge(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var out := {}
	for key: String in defaults:
		var def: Variant = defaults[key]
		var val: Variant = loaded.get(key, def)
		if def is Dictionary:
			out[key] = _merge(def, val if val is Dictionary else {})
		elif typeof(def) == TYPE_INT and typeof(val) == TYPE_FLOAT:
			out[key] = int(val)        # JSON stores every number as a float
		elif typeof(def) == TYPE_FLOAT and typeof(val) == TYPE_INT:
			out[key] = float(val)
		elif typeof(val) != typeof(def):
			out[key] = def.duplicate() if def is Array else def
		elif val is Array:
			out[key] = (val as Array).duplicate()   # never the read-only default
		else:
			out[key] = val
	return out
