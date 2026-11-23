class_name ContactShadow
extends MeshInstance3D
## A soft dark patch on the ground under a fighter: it grounds them (the
## real sun shadow is crisp and may be off on LOW). Follows the floor below
## with one ray a frame; fades and spreads as the fighter rises.

const SHADER := preload("res://src/fighter/contact_shadow.gdshader")
const RANGE := 5.0

var fighter: Node3D
var strength := 0.5


func _ready() -> void:
	top_level = true
	var q := QuadMesh.new()
	q.size = Vector2(1.15, 1.15)
	q.orientation = PlaneMesh.FACE_Y
	mesh = q
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter) or not fighter.is_inside_tree():
		visible = false
		return
	var from := fighter.global_position + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * RANGE, Game.L_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		visible = false
		return
	visible = fighter.visible
	var h := from.y - 0.3 - float(hit["position"].y)
	var n: Vector3 = hit["normal"]
	var basis := Basis(Quaternion(Vector3.UP, n))
	var spread := 1.0 + clampf(h, 0.0, 3.0) * 0.35
	global_transform = Transform3D(basis.scaled(Vector3(spread, 1.0, spread)), hit["position"] + n * 0.03)
	set_instance_shader_parameter(&"alpha", strength * clampf(1.0 - h / RANGE, 0.0, 1.0))
