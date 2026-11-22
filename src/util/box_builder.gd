class_name BoxBuilder
extends RefCounted
## Builds flat-shaded, vertex-coloured box meshes: the look of every block
## fighter and weapon. Optionally rigid-skinned (one bone per box).

const _FACES := [
	# normal, then 4 corners as signs of (x, y, z), counter-clockwise seen from outside
	[Vector3.RIGHT, [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
	[Vector3.LEFT, [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
	[Vector3.UP, [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
	[Vector3.DOWN, [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
	[Vector3.BACK, [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3.FORWARD, [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
]

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var bones := PackedInt32Array()
var weights := PackedFloat32Array()
var indices := PackedInt32Array()
var skinned := false


func _init(use_skin: bool = false) -> void:
	skinned = use_skin


## Adds a box of `size` centred at `centre`, optionally rotated by `basis`.
## Each face gets a slightly different shade so edges read even unlit.
func box(size: Vector3, centre: Vector3, color: Color, bone: int = 0, basis: Basis = Basis.IDENTITY) -> void:
	var h := size * 0.5
	for face: Array in _FACES:
		var n: Vector3 = basis * (face[0] as Vector3)
		var base := verts.size()
		for c: Vector3 in face[1]:
			verts.append(centre + basis * (c * h))
			normals.append(n)
			colors.append(color)
			if skinned:
				bones.append_array([bone, 0, 0, 0])
				weights.append_array([1.0, 0.0, 0.0, 0.0])
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


func commit(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	if skinned:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	return mesh


static func vertex_color_material(roughness: float = 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	return m
