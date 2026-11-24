class_name PowerUp
extends Node3D
## A map pickup (doc: Map pickups): health cube, speed boots, double
## damage, shield bubble, power battery. Floats and turns over its spot;
## any fighter who touches it gets it.

const KINDS: Array[StringName] = [&"health", &"speed", &"damage", &"shield", &"battery"]

var kind := &"health"
var point := -1
var _visual: Node3D
var _t := 0.0


func setup(k: StringName, at: Vector3, spot: int) -> void:
	kind = k
	point = spot
	global_position = at + Vector3.UP * 0.9
	var color: Color = FighterPowers.PICKUPS[kind]["color"]
	var b := BoxBuilder.new()
	b.box(Vector3(0.46, 0.46, 0.46), Vector3.ZERO, color.darkened(0.35))
	var w := Color(1, 1, 1)
	match kind:
		&"health":
			b.box(Vector3(0.5, 0.14, 0.14), Vector3.ZERO, w)
			b.box(Vector3(0.14, 0.5, 0.14), Vector3.ZERO, w)
			b.box(Vector3(0.14, 0.14, 0.5), Vector3.ZERO, w)
		&"speed":
			b.box(Vector3(0.5, 0.1, 0.1), Vector3(0, 0.12, 0), w)
			b.box(Vector3(0.36, 0.1, 0.1), Vector3(0.07, -0.02, 0), w)
			b.box(Vector3(0.22, 0.1, 0.1), Vector3(0.14, -0.16, 0), w)
		&"damage":
			b.box(Vector3(0.12, 0.5, 0.12), Vector3(-0.1, 0, 0), w, 0, Basis(Vector3.BACK, 0.5))
			b.box(Vector3(0.12, 0.5, 0.12), Vector3(0.1, 0, 0), w, 0, Basis(Vector3.BACK, -0.5))
		&"shield":
			b.box(Vector3(0.3, 0.36, 0.5), Vector3.ZERO, w)
		&"battery":
			b.box(Vector3(0.26, 0.4, 0.5), Vector3.ZERO, w)
			b.box(Vector3(0.12, 0.08, 0.2), Vector3(0, 0.24, 0), w)
	var mat := BoxBuilder.vertex_color_material(0.4)
	mat.set_shader_parameter(&"glow", color * 0.35)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(mat, BoxBuilder.outline_material(0.7))
	_visual = mi
	add_child(mi)
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 0.02
	cyl.radial_segments = 20
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, 0.35)
	cyl.material = m
	ring.mesh = cyl
	ring.position.y = -0.88
	add_child(ring)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation = Vector3(0.4, _t * 2.0, 0.0)
	_visual.position.y = sin(_t * 3.0) * 0.1
