class_name Bolt
extends Node3D
## A shot from a ranged weapon: a blaster bolt (straight, fast) or an arrow
## (a little drop). Hurts the first fighter it meets, chips scenery, can be
## blocked or parried back, and fizzles after a while.

var owner_fighter: Fighter
var world: Match
var velocity := Vector3.ZERO
var damage := 10.0
var gravity := 0.0
var age := 0.0
var _hit_owner_ok := false
var _visual: MeshInstance3D


func launch(by: Fighter, at: Vector3, dir: Vector3, speed: float, dmg: float, arrow: bool) -> void:
	owner_fighter = by
	damage = dmg
	velocity = dir.normalized() * speed
	gravity = 6.0 if arrow else 0.0
	global_position = at
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_visual = MeshInstance3D.new()
	var b := BoxBuilder.new()
	if arrow:
		b.box(Vector3(0.025, 0.025, 0.7), Vector3.ZERO, Color(0.5, 0.34, 0.18))
		b.box(Vector3(0.06, 0.06, 0.1), Vector3(0, 0, -0.38), Color(0.8, 0.82, 0.88))
		b.box(Vector3(0.1, 0.01, 0.12), Vector3(0, 0, 0.3), Color(0.95, 0.95, 0.95))
		_visual.mesh = b.commit(BoxBuilder.vertex_color_material(0.6))
	else:
		b.box(Vector3(0.07, 0.07, 0.55), Vector3.ZERO, Color(0.5, 1.0, 0.65))
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_visual.mesh = b.commit(m)
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	_face()


func _face() -> void:
	if velocity.length() > 0.1:
		_visual.global_basis = Basis.looking_at(velocity.normalized(), Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


## Parried: back at whoever fired it.
func reflect(by: Fighter) -> void:
	var back := -velocity
	if owner_fighter and is_instance_valid(owner_fighter) and owner_fighter.alive:
		back = owner_fighter.global_position + Vector3.UP * 1.2 - global_position
	velocity = back.normalized() * velocity.length() * 1.1
	owner_fighter = by
	age = 0.0
	_face()


func _physics_process(delta: float) -> void:
	age += delta
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	for f: Fighter in world.fighters:
		if not f.alive or f == owner_fighter or f.protect > 0.0:
			continue
		var lo := f.global_position + Vector3.UP * Fighter.HURT_LOW
		var hi := f.global_position + Vector3.UP * Fighter.HURT_HIGH
		if Geo.segment_distance(from, to, lo, hi) <= f.hurt_radius + 0.06:
			if f.try_deflect_bolt(self):
				return
			var by := owner_fighter if owner_fighter and is_instance_valid(owner_fighter) else null
			var dmg := damage * (by.powers.damage_dealt_mult() if by else 1.0)
			var dealt := f.take_hit(dmg, Vector3(velocity.x, 0, velocity.z).normalized(), by, false,
				Geo.closest_on_segment(from, lo, hi), 2.5)
			if by and dealt > 0.0:
				by.powers.dealt(dealt)
				by.hit_landed.emit(by, f, dealt)
			Fx.sparks(get_parent(), to, Color(0.6, 1.0, 0.7), 8)
			queue_free()
			return
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD))
	if not hit.is_empty():
		var piece := hit["collider"] as Breakable
		if piece:
			piece.hit(damage, hit["position"], velocity * 0.1, owner_fighter)
		Fx.sparks(get_parent(), hit["position"], Color(0.7, 1.0, 0.8), 6)
		queue_free()
		return
	global_position = to
	if gravity > 0.0:
		_face()
	if age > 1.6 or global_position.y < -30.0:
		queue_free()
