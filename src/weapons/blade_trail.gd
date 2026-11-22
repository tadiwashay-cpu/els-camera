class_name BladeTrail
extends MeshInstance3D
## A fading ribbon behind a swinging blade.

const LIFE := 0.14

var color := Color.WHITE
var active := false
var _points: Array = []           # [base, tip, time]
var _clock := 0.0
var _im := ImmediateMesh.new()


func _ready() -> void:
	# Moved every frame, not every physics tick: no interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m


func add_point(base: Vector3, tip: Vector3, valid: bool = true) -> void:
	if valid:
		_points.append([base, tip, _clock])
	while not _points.is_empty() and _clock - float(_points[0][2]) > LIFE:
		_points.pop_front()


func _physics_process(delta: float) -> void:
	_clock += delta


func _process(_delta: float) -> void:
	_im.clear_surfaces()
	if _points.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p: Array in _points:
		var a := clampf(1.0 - (_clock - float(p[2])) / LIFE, 0.0, 1.0)
		_im.surface_set_color(Color(color.r, color.g, color.b, a * 0.15))
		_im.surface_add_vertex(p[0])
		_im.surface_set_color(Color(color.r, color.g, color.b, a * 0.75))
		_im.surface_add_vertex(p[1])
	_im.surface_end()
