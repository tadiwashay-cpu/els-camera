extends Node
## Lists every weapon, skin and arena. Weapons: every .tres in
## src/weapons/data (made by tools/gen_weapons.py); ResourceLoader.list_directory
## also works in exported builds, where resources are remapped.

const WEAPON_DIR := "res://src/weapons/data/"
const SKINS := ["res://src/fighter/skins/ember.tres", "res://src/fighter/skins/frost.tres",
	"res://src/fighter/skins/moss.tres", "res://src/fighter/skins/violet.tres"]
const ARENAS := ["res://src/arenas/data/blockout_yard.tres"]

var weapons: Dictionary = {}
var skins: Array[SkinData] = []
var arenas: Dictionary = {}


func _ready() -> void:
	for file: String in ResourceLoader.list_directory(WEAPON_DIR):
		if file.ends_with(".tres"):
			var w := load(WEAPON_DIR + file) as WeaponData
			if w:
				weapons[w.id] = w
	for p: String in SKINS:
		skins.append(load(p) as SkinData)
	for p: String in ARENAS:
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
	return skins[posmod(index, skins.size())]


func arena(id: StringName) -> ArenaData:
	return arenas.get(id, arenas.values()[0])
