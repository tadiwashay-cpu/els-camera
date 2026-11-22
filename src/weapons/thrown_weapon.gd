class_name ThrownWeapon
extends Node3D
## A weapon in flight, spinning end over end. It hurts the first fighter it
## meets, can be caught (Fighter._catch) and becomes a pickup once it lands.

const GRAVITY := 12.0

var data: WeaponData
var thrower: Fighter
var world: Match
var velocity := Vector3.ZERO
var harmful := true
var boosted := false
var age := 0.0
var _spin := 0.0
var _axis := Vector3.RIGHT
var _base := Basis.IDENTITY
var _visual: MeshInstance3D
var _trail: BladeTrail
var _bounces := 0


func launch(by: Fighter, weapon: WeaponData, origin: Vector3, dir: Vector3, speed: float, is_boosted: bool) -> void:
	thrower = by
	data = weapon
	boosted = is_boosted
	velocity = dir.normalized() * speed
	global_position = origin
	_axis = velocity.cross(Vector3.UP).normalized()
	if _axis.length() < 0.1:
		_axis = Vector3.RIGHT
	_base = Basis.looking_at(velocity.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	_visual = MeshInstance3D.new()
	_visual.mesh = data.mesh()
	add_child(_visual)
	_trail = BladeTrail.new()
	_trail.color = by.body.skin.trail if by else Color.WHITE
	add_child(_trail)


## Seconds until it reaches `f` if both keep going (INF if moving away).
func time_to(f: Fighter) -> float:
	var to := f.global_position + Vector3.UP * 1.2 - global_position
	var closing := velocity.dot(to.normalized())
	if closing <= 0.5:
		return INF
	return to.length() / closing


func _physics_process(delta: float) -> void:
	age += delta
	velocity.y -= GRAVITY * delta
	if harmful and data:
		_home(delta)
	var from := global_position
	var to := from + velocity * delta
	if harmful:
		for f: Fighter in world.fighters:
			if not f.alive or (f == thrower and age < 0.5) or f.protect > 0.0:
				continue
			var lo := f.global_position + Vector3.UP * Fighter.HURT_LOW
			var hi := f.global_position + Vector3.UP * Fighter.HURT_HIGH
			if Geo.segment_distance(from, to, lo, hi) <= f.hurt_radius + 0.22:
				_hit_fighter(f, Geo.closest_on_segment(from, lo, hi))
				break
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var n: Vector3 = hit["normal"]
		var p: Vector3 = hit["position"]
		var piece := hit["collider"] as Breakable
		if piece and harmful:
			piece.hit(data.throw_damage * (1.5 if boosted else 1.0), p, velocity * 0.3, thrower)
			if piece.is_broken:
				# Smashed straight through: keep flying.
				velocity *= 0.75
				global_position = to
				return
		if harmful:
			Fx.sparks(get_parent(), p, Color(1, 0.9, 0.6), 10)
			Audio.play(&"clang", p, -2.0)
		harmful = false
		_bounces += 1
		if n.y > 0.6 and (velocity.length() < 7.0 or _bounces > 2):
			world.projectile_landed(self, p)
			return
		velocity = velocity.bounce(n) * 0.35
		to = p + n * 0.05
	global_position = to
	_spin += (data.throw_spin if harmful else data.throw_spin * 0.5) * delta
	_visual.basis = Basis(_axis, -_spin) * _base if harmful else Basis(_axis, -_spin) * _base
	var s := global_transform * _visual.transform
	if harmful:
		_trail.add_point(s * Vector3(0, 0.2, 0), s * Vector3(0, data.hit_to, 0))
	else:
		_trail.add_point(Vector3.ZERO, Vector3.ZERO, false)
	if age > 6.0 or global_position.y < world.arena.kill_y:
		world.projectile_landed(self, global_position)


func _home(delta: float) -> void:
	# A little aim assist: bend toward the fighter nearest the flight line.
	var best: Fighter
	var best_score := 0.0
	var dir := velocity.normalized()
	for f: Fighter in world.fighters:
		if f == thrower or not f.alive:
			continue
		var to := f.global_position + Vector3.UP * 1.1 - global_position
		var along := dir.dot(to.normalized())
		if along > 0.94 and along > best_score:
			best_score = along
			best = f
	if best:
		var want := (best.global_position + Vector3.UP * 1.1 - global_position).normalized()
		var speed := velocity.length()
		velocity = dir.slerp(want, clampf(delta * 3.0, 0.0, 1.0)) * speed


func _hit_fighter(f: Fighter, at: Vector3) -> void:
	if f.try_deflect(self):
		return
	var speed := velocity.length()
	var dmg := data.throw_damage * clampf(speed / maxf(data.throw_speed, 1.0), 0.6, 1.6) * (1.25 if boosted else 1.0)
	var by := thrower if thrower and is_instance_valid(thrower) else null
	if by:
		dmg *= by.powers.damage_dealt_mult()
	var dir := Vector3(velocity.x, 0, velocity.z).normalized()
	var dealt := f.take_hit(dmg, dir, by, speed > 20.0 or boosted, at, 6.0)
	if by and dealt > 0.0:
		by.powers.dealt(dealt)
		by.hit_landed.emit(by, f, dealt)
	Audio.play(&"hit_heavy", at, 2.0)
	harmful = false
	velocity = -velocity * 0.15 + Vector3.UP * 4.0


## Parried: fly back at whoever threw it, faster, now "thrown" by `by`.
func reflect(by: Fighter) -> void:
	var back_to := global_position - velocity
	if thrower and is_instance_valid(thrower) and thrower.alive:
		back_to = thrower.global_position + Vector3.UP * 1.1
	var speed := velocity.length() * 1.15
	velocity = (back_to - global_position).normalized() * speed
	thrower = by
	age = 0.0
	harmful = true
	boosted = true
	_axis = velocity.cross(Vector3.UP).normalized()
	_base = Basis.looking_at(velocity.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
