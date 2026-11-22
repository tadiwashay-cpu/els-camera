extends Node
## Lists every weapon, skin and arena. Weapons: every .tres in
## src/weapons/data (made by tools/gen_weapons.py); ResourceLoader.list_directory
## also works in exported builds, where resources are remapped.

const WEAPON_DIR := "res://src/weapons/data/"
const SKINS := ["res://src/fighter/skins/ember.tres", "res://src/fighter/skins/frost.tres",
	"res://src/fighter/skins/moss.tres", "res://src/fighter/skins/violet.tres"]
const ARENAS := ["res://src/arenas/data/blockout_yard.tres", "res://src/arenas/data/beach_island.tres",
	"res://src/arenas/data/harbor_factory.tres"]

var weapons: Dictionary = {}
var skins: Array[SkinData] = []
var arenas: Dictionary = {}
var _variants: Dictionary = {}


func _ready() -> void:
	for file: String in ResourceLoader.list_directory(WEAPON_DIR):
		if file.ends_with(".tres"):
			var w := load(WEAPON_DIR + file) as WeaponData
			if w:
				weapons[w.id] = w
	for p: String in SKINS:
		skins.append(load(p) as SkinData)
	for p: String in ARENAS:
		if not ResourceLoader.exists(p):
			continue
		var a := load(p) as ArenaData
		arenas[a.id] = a


func weapon(id: StringName) -> WeaponData:
	return weapons.get(id, weapons[&"fists"])


## Weapons a spawner can hand out, or only the mystery crate's rare ones.
func weapon_pool(rare: bool) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w: WeaponData in weapons.values():
		if w.is_fists():
			continue
		if (w.rarity == &"rare") == rare:
			out.append(w)
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.id < b.id)
	return out


func skin(index: int) -> SkinData:
	if index < skins.size():
		return skins[posmod(index, skins.size())]
	# More fighters than skins: the same outfits with new colours.
	var key := "variant_%d" % index
	if not _variants.has(key):
		var base := skins[index % skins.size()]
		var v := base.duplicate() as SkinData
		var shift := 0.13 + 0.21 * float(index / skins.size())
		for prop: String in ["shirt", "sleeve", "trail", "pants"]:
			var c: Color = v.get(prop)
			v.set(prop, Color.from_hsv(fmod(c.h + shift, 1.0), c.s, c.v))
		v.id = StringName(key)
		_variants[key] = v
	return _variants[key]


func arena(id: StringName) -> ArenaData:
	return arenas.get(id, arenas.values()[0])


## Arena ids in menu order.
func arena_ids() -> Array:
	var out: Array = []
	for p: String in ARENAS:
		for a: ArenaData in arenas.values():
			if a.resource_path == p:
				out.append(a.id)
	return out


## The arena to play: `id`, or any of them for &"random".
func pick_arena(id: StringName) -> ArenaData:
	if id == &"random":
		var ids := arena_ids()
		return arena(ids[randi() % ids.size()])
	return arena(id)
