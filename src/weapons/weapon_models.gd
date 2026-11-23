class_name WeaponModels
extends RefCounted
## The weapons' curved models, built in Blender by tools/blender/build_weapons.py
## into one GLB (a mesh per weapon id, in socket space, colours with the
## finish in alpha). WeaponData.mesh() uses these, falling back to its box
## parts for a weapon without a model.

const PATH := "res://assets/weapons/weapon_models.glb"

static var _meshes: Dictionary = {}       # id -> Mesh
static var _loaded := false


static func mesh_for(id: StringName) -> Mesh:
	if not _loaded:
		_load()
	return _meshes.get(id)


static func has_model(id: StringName) -> bool:
	return mesh_for(id) != null


static func _load() -> void:
	_loaded = true
	if not ResourceLoader.exists(PATH):
		return
	var scene := load(PATH) as PackedScene
	if scene == null:
		return
	var root := scene.instantiate()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh:
			_meshes[StringName(String(mi.name))] = mi.mesh
	root.free()
