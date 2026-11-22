class_name Ragdoll
extends RefCounted
## Physics body for a block fighter: 11 physical bones (doc budget) under a
## PhysicalBoneSimulator3D. Big hits blend it in for a moment, death runs
## it fully; the boxes it moves are the same boxes the fighter is made of.

## bone, box size, box centre (model space), cone swing (deg), twist (deg), mass (kg)
const BODIES := [
	[&"Hips", Vector3(0.34, 0.2, 0.22), Vector3(0, 0.98, 0), 0.0, 0.0, 11.0],
	[&"UpperChest", Vector3(0.42, 0.4, 0.24), Vector3(0, 1.3, 0), 30.0, 25.0, 14.0],
	[&"Head", Vector3(0.3, 0.3, 0.3), Vector3(0, 1.72, 0.01), 40.0, 35.0, 5.0],
	[&"LeftUpperArm", Vector3(0.26, 0.12, 0.12), Vector3(0.32, 1.44, 0), 95.0, 40.0, 2.5],
	[&"LeftLowerArm", Vector3(0.36, 0.11, 0.11), Vector3(0.64, 1.44, 0), 85.0, 15.0, 2.0],
	[&"RightUpperArm", Vector3(0.26, 0.12, 0.12), Vector3(-0.32, 1.44, 0), 95.0, 40.0, 2.5],
	[&"RightLowerArm", Vector3(0.36, 0.11, 0.11), Vector3(-0.64, 1.44, 0), 85.0, 15.0, 2.0],
	[&"LeftUpperLeg", Vector3(0.15, 0.42, 0.15), Vector3(0.11, 0.73, 0), 75.0, 20.0, 7.5],
	[&"LeftLowerLeg", Vector3(0.13, 0.5, 0.15), Vector3(0.11, 0.29, 0.02), 85.0, 10.0, 4.5],
	[&"RightUpperLeg", Vector3(0.15, 0.42, 0.15), Vector3(-0.11, 0.73, 0), 75.0, 20.0, 7.5],
	[&"RightLowerLeg", Vector3(0.13, 0.5, 0.15), Vector3(-0.11, 0.29, 0.02), 85.0, 10.0, 4.5],
]

var skeleton: Skeleton3D
var sim: PhysicalBoneSimulator3D
var bodies: Dictionary = {}          # bone name -> PhysicalBone3D
var active := false
var _blend_tween: Tween


func build(skel: Skeleton3D, head_scale: float = 1.0) -> void:
	skeleton = skel
	sim = PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skeleton.add_child(sim)
	for row: Array in BODIES:
		var bone: StringName = row[0]
		var idx := skeleton.find_bone(bone)
		if idx < 0:
			continue
		var size: Vector3 = row[1]
		var centre: Vector3 = row[2]
		if bone == &"Head":
			size *= head_scale
			centre = BlockBody.HEAD_ORIGIN + (centre - BlockBody.HEAD_ORIGIN) * head_scale
		var rest := skeleton.get_bone_global_rest(idx)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone
		pb.bone_name = bone
		# The box stays aligned with the model at rest: body = bone * offset.
		pb.body_offset = Transform3D(rest.basis.inverse(), rest.affine_inverse() * centre)
		var swing: float = row[3]
		if swing > 0.0:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			var along := rest.basis.y.normalized()        # bone direction
			var side := along.cross(Vector3.FORWARD if absf(along.z) < 0.9 else Vector3.UP).normalized()
			var joint_basis := Basis(along, side, along.cross(side))
			pb.joint_offset = Transform3D(joint_basis, rest.origin - centre)
			pb.set(&"joint_constraints/swing_span", swing)
			pb.set(&"joint_constraints/twist_span", float(row[4]))
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		pb.mass = row[5]
		pb.friction = 0.9
		pb.bounce = 0.05
		pb.linear_damp = 0.15
		pb.angular_damp = 1.2
		pb.collision_layer = Game.L_RAGDOLL
		pb.collision_mask = Game.L_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		pb.add_child(shape)
		sim.add_child(pb)
		bodies[bone] = pb
	sim.active = false


## Goes limp, keeping the body's motion and adding a hit.
func start(velocity: Vector3, impulse: Vector3, hit_bone: StringName = &"UpperChest") -> void:
	if _blend_tween:
		_blend_tween.kill()
	sim.influence = 1.0
	sim.active = true
	sim.physical_bones_start_simulation()
	active = true
	for pb: PhysicalBone3D in bodies.values():
		pb.linear_velocity = velocity
		pb.angular_velocity = Vector3.ZERO
	var target: PhysicalBone3D = bodies.get(hit_bone, bodies[&"UpperChest"])
	target.apply_central_impulse(impulse * target.mass)
	(bodies[&"Hips"] as PhysicalBone3D).apply_central_impulse(impulse * 0.6 * (bodies[&"Hips"] as PhysicalBone3D).mass)


## Hands the body back to animation over `seconds`.
func stop(seconds: float = 0.3) -> void:
	if not active:
		return
	active = false
	if _blend_tween:
		_blend_tween.kill()
	if seconds <= 0.0:
		_finish()
		return
	_blend_tween = sim.create_tween()
	_blend_tween.tween_property(sim, "influence", 0.0, seconds)
	_blend_tween.tween_callback(_finish)


func _finish() -> void:
	sim.physical_bones_stop_simulation()
	sim.active = false
	sim.influence = 1.0


func hips_position() -> Vector3:
	return (bodies[&"Hips"] as PhysicalBone3D).global_position


func head_position() -> Vector3:
	return (bodies[&"Head"] as PhysicalBone3D).global_position


## True when lying on the back (chest facing the sky).
func face_up() -> bool:
	return (bodies[&"UpperChest"] as PhysicalBone3D).global_basis.z.y > 0.0


func speed() -> float:
	return (bodies[&"Hips"] as PhysicalBone3D).linear_velocity.length()
