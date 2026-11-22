class_name WeaponPickup
extends Node3D
## A weapon lying in the arena: it hovers and turns until an unarmed
## fighter walks over it. Dropped ones fall first and vanish after a while.

var data: WeaponData
var spawner := -1                 # index of the spawner that made it, or -1
var velocity := Vector3.ZERO
var settled := false
var age := 0.0
var lifetime := 25.0
var _visual: MeshInstance3D
var _ring: MeshInstance3D
var _ground_y := 0.0


func setup(weapon: WeaponData, at: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	data = weapon
	global_position = at
	velocity = vel
	_visual = MeshInstance3D.new()
	_visual.mesh = data.mesh()
	_visual.rotation_degrees = Vector3(0, 0, 70)
	add_child(_visual)
	_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.02
	cyl.radial_segments = 20
	cyl.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.35)
	cyl.material = m
	_ring.mesh = cyl
	_ring.visible = false
	add_child(_ring)


func can_take() -> bool:
	return age > 0.4


func _physics_process(delta: float) -> void:
	age += delta
	if not settled:
		velocity.y -= 22.0 * delta
		var from := global_position
		var to := from + velocity * delta
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to + Vector3.DOWN * 0.6, Game.L_WORLD))
		if not hit.is_empty() and velocity.y <= 0.0:
			_ground_y = (hit["position"] as Vector3).y
			global_position = Vector3(to.x, _ground_y + 0.6, to.z)
			settled = true
			_ring.visible = true
			_ring.position.y = -0.58
		else:
			global_position = to
		_visual.rotate_object_local(Vector3.FORWARD, delta * 9.0)
	else:
		_visual.rotation = Vector3(0, age * 2.2, 1.2)
		_visual.position.y = sin(age * 3.0) * 0.08
	if spawner < 0 and age > lifetime:
		queue_free()
