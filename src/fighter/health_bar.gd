class_name HealthBar
extends MeshInstance3D
## A life bar about the size of the head, floating over it and turning to
## face the camera; it drains when the fighter is hit (a pale trail shows
## the damage just taken). Its rim is the fighter's colour. Follows the head
## bone, so it stays with a ragdoll.

const SHADER := preload("res://src/fighter/health_bar.gdshader")

var fighter: Fighter
## Hidden for our own fighter in first person.
var hidden_for_view := false
var _trail := 1.0


func _ready() -> void:
	top_level = true
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 0.075)
	mesh = q
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.render_priority = 2
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if fighter and fighter.body:
		set_instance_shader_parameter(&"tint", fighter.body.skin.shirt.lightened(0.15))


func _process(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter) or fighter.body == null:
		visible = false
		return
	visible = fighter.alive and fighter.visible and not hidden_for_view
	if not visible:
		_trail = 1.0
		return
	global_position = fighter.body.bone_position(&"Head") + Vector3.UP * 0.62
	var fill := clampf(fighter.health / maxf(fighter.max_health, 1.0), 0.0, 1.0)
	_trail = fill if fill > _trail else move_toward(_trail, fill, delta * 0.6)
	set_instance_shader_parameter(&"fill", fill)
	set_instance_shader_parameter(&"trail", _trail)
