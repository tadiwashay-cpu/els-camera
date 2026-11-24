class_name Props
extends RefCounted
## Organic scenery made in Blender (tools/blender/build_props.py ->
## assets/props/props.glb): palms, faceted rocks, bushes, driftwood, beach
## grass, starfish. Arena.prop() places them; each kind is drawn as one
## MultiMesh (src/shaders/props.gdshader). Collision: a trunk for palms, a
## convex hull for rocks, nothing for the small stuff.

const PATH := "res://assets/props/props.glb"
const SHADER := preload("res://src/shaders/props.gdshader")
## How far away each kind is still drawn (0 = always).
const DRAW_RANGE := {&"grass": 38.0, &"grass_dry": 38.0, &"starfish": 30.0, &"bush": 70.0, &"driftwood": 60.0}
## id -> [sway, casts shadow, collision ("trunk" | "hull" | "")]
const INFO := {
	&"palm_a": [0.35, true, "trunk"], &"palm_b": [0.35, true, "trunk"], &"palm_c": [0.35, true, "trunk"],
	&"rock_a": [0.0, true, "hull"], &"rock_b": [0.0, true, "hull"], &"rock_c": [0.0, true, "hull"], &"rock_d": [0.0, true, "hull"],
	&"bush": [1.5, true, ""], &"driftwood": [0.0, true, ""],
	&"grass": [9.0, false, ""], &"grass_dry": [9.0, false, ""], &"starfish": [0.0, false, ""],
}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _hulls: Dictionary = {}
static var _loaded := false


static func mesh(id: StringName) -> Mesh:
	if not _loaded:
		_loaded = true
		if ResourceLoader.exists(PATH):
			var root := (load(PATH) as PackedScene).instantiate()
			for n in root.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi.mesh:
					_meshes[StringName(String(mi.name))] = mi.mesh
			root.free()
	return _meshes.get(id)


static func material(id: StringName) -> ShaderMaterial:
	if not _materials.has(id):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter(&"sway", float(INFO.get(id, [0.0])[0]))
		_materials[id] = m
	return _materials[id]


## A convex hull of the prop at `scale` (cached).
static func hull(id: StringName, scale: float) -> ConvexPolygonShape3D:
	var key := "%s_%.2f" % [id, scale]
	if not _hulls.has(key):
		var m := mesh(id)
		var pts := PackedVector3Array()
		if m:
			for v in m.get_faces():
				pts.append(v * scale)
		var s := ConvexPolygonShape3D.new()
		s.points = pts
		_hulls[key] = s
	return _hulls[key]
