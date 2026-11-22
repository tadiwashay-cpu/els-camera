extends Node
## Lists every weapon, skin and arena. Explicit paths (not a folder scan)
## so exported builds, where resources are remapped, find them too.

const WEAPONS := ["res://src/weapons/data/sword.tres", "res://src/weapons/data/fists.tres"]
const SKINS := ["res://src/fighter/skins/ember.tres", "res://src/fighter/skins/frost.tres",
	"res://src/fighter/skins/moss.tres", "res://src/fighter/skins/violet.tres"]
const ARENAS := ["res://src/arenas/data/blockout_yard.tres"]

var weapons: Dictionary = {}
var skins: Array[SkinData] = []
var arenas: Dictionary = {}


func _ready() -> void:
	for p: String in WEAPONS:
		var w := load(p) as WeaponData
		weapons[w.id] = w
	for p: String in SKINS:
		skins.append(load(p) as SkinData)
	for p: String in ARENAS:
		var a := load(p) as ArenaData
		arenas[a.id] = a


func weapon(id: StringName) -> WeaponData:
	return weapons.get(id, weapons[&"fists"])


func skin(index: int) -> SkinData:
	return skins[posmod(index, skins.size())]


func arena(id: StringName) -> ArenaData:
	return arenas.get(id, arenas.values()[0])
