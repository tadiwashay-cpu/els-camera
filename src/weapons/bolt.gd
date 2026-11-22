class_name Bolt
extends Node3D
## A shot from a ranged weapon. The style decides how it flies and lands:
##   bolt / plasma  straight and fast (blasters); hot: sets oil alight
##   arrow          a little drop (bows)
##   pebble         a real arc, big knockback (slingshot)
##   slug           very fast, hits hard, leaves a tracer (sniper)
##   rocket         slower, explodes on whatever it touches (bazooka)
##   orb            slow magic that curves toward the nearest enemy (scepter)
##   hook           a grappling hook on a rope: pulls you to a wall, or
##                  yanks a fighter to you
## Every shot can be blocked, and parried back.

const STYLES := {
	&"bolt": {"gravity": 0.0, "life": 1.6, "knock": 2.5, "color": Color(0.5, 1.0, 0.65)},
	&"plasma": {"gravity": 0.0, "life": 1.4, "knock": 2.0, "color": Color(1.0, 0.35, 0.75)},
	&"arrow": {"gravity": 6.0, "life": 2.0, "knock": 3.0, "color": Color(0.9, 0.9, 0.85)},
	&"pebble": {"gravity": 11.0, "life": 2.0, "knock": 8.0, "color": Color(0.55, 0.52, 0.48)},
	&"slug": {"gravity": 0.0, "life": 0.7, "knock": 6.0, "color": Color(1.0, 0.85, 0.4)},
	&"rocket": {"gravity": 1.5, "life": 3.0, "knock": 0.0, "color": Color(1.0, 0.55, 0.2)},
	&"orb": {"gravity": 0.0, "life": 3.0, "knock": 4.0, "color": Color(0.75, 0.5, 1.0)},
	&"hook": {"gravity": 4.0, "life": 0.9, "knock": 0.0, "color": Color(0.7, 0.72, 0.78)},
}

var owner_fighter: Fighter
var world: Match
var velocity := Vector3.ZERO
var damage := 10.0
var style := &"bolt"
var gravity := 0.0
var life := 1.6
var age := 0.0
var _visual: MeshInstance3D
var _rope: MeshInstance3D


func launch(by: Fighter, at: Vector3, dir: Vector3, speed: float, dmg: float, kind: StringName = &"bolt") -> void:
	owner_fighter = by
	damage = dmg
	style = kind if STYLES.has(kind) else &"bolt"
	var info: Dictionary = STYLES[style]
	gravity = info["gravity"]
	life = info["life"]
	velocity = dir.normalized() * speed
	global_position = at
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh_for(style, info["color"])
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	if style == &"hook":
		_rope = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.025, 1.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.45, 0.3)
		bm.material = m
		_rope.mesh = bm
		_rope.top_level = true
		add_child(_rope)
	_face()


static var _meshes: Dictionary = {}


static func _mesh_for(kind: StringName, c: Color) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var b := BoxBuilder.new()
	var lit := true
	match kind:
		&"arrow":
			b.box(Vector3(0.025, 0.025, 0.7), Vector3.ZERO, Color(0.5, 0.34, 0.18))
			b.box(Vector3(0.06, 0.06, 0.1), Vector3(0, 0, -0.38), Color(0.8, 0.82, 0.88))
			b.box(Vector3(0.1, 0.01, 0.12), Vector3(0, 0, 0.3), Color(0.95, 0.95, 0.95))
		&"pebble":
			b.box(Vector3(0.11, 0.1, 0.12), Vector3.ZERO, c)
		&"rocket":
			b.box(Vector3(0.14, 0.14, 0.5), Vector3.ZERO, Color(0.35, 0.4, 0.3))
			b.box(Vector3(0.1, 0.1, 0.16), Vector3(0, 0, -0.32), Color(0.85, 0.2, 0.15))
			b.box(Vector3(0.3, 0.03, 0.12), Vector3(0, 0, 0.22), Color(0.3, 0.32, 0.28))
			b.box(Vector3(0.03, 0.3, 0.12), Vector3(0, 0, 0.22), Color(0.3, 0.32, 0.28))
			b.box(Vector3(0.1, 0.1, 0.12), Vector3(0, 0, 0.32), Color(1.0, 0.7, 0.2))
		&"hook":
			b.box(Vector3(0.05, 0.05, 0.3), Vector3.ZERO, c)
			b.box(Vector3(0.26, 0.04, 0.04), Vector3(0, 0, -0.12), c)
			b.box(Vector3(0.04, 0.04, 0.1), Vector3(0.12, 0, -0.08), c)
			b.box(Vector3(0.04, 0.04, 0.1), Vector3(-0.12, 0, -0.08), c)
		&"orb":
			lit = false
			b.box(Vector3(0.22, 0.22, 0.22), Vector3.ZERO, c)
			b.box(Vector3(0.12, 0.12, 0.12), Vector3.ZERO, Color(1, 1, 1), 0, Basis.from_euler(Vector3(0.6, 0.6, 0)))
		&"slug":
			lit = false
			b.box(Vector3(0.04, 0.04, 1.6), Vector3.ZERO, c)
		_:
			lit = false
			b.box(Vector3(0.07, 0.07, 0.55), Vector3.ZERO, c)
	var mat: Material
	if lit:
		mat = BoxBuilder.vertex_color_material(0.6)
	else:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		mat = m
	_meshes[kind] = b.commit(mat)
	return _meshes[kind]


func _face() -> void:
	if velocity.length() > 0.1:
		var d := velocity.normalized()
		_visual.global_basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT)


## Parried: back at whoever fired it.
func reflect(by: Fighter) -> void:
	var back := -velocity
	if owner_fighter and is_instance_valid(owner_fighter) and owner_fighter.alive:
		back = owner_fighter.global_position + Vector3.UP * 1.2 - global_position
	velocity = back.normalized() * velocity.length() * 1.1
	owner_fighter = by
	age = 0.0
	_face()


func _by() -> Fighter:
	return owner_fighter if owner_fighter and is_instance_valid(owner_fighter) else null


func _physics_process(delta: float) -> void:
	age += delta
	velocity.y -= gravity * delta
	if style == &"orb":
		_home(delta)
	if style == &"rocket" and int(age * 30.0) % 3 == 0:
		Fx.sparks(get_parent(), global_position - velocity.normalized() * 0.35, Color(1.0, 0.6, 0.2), 3)
	var from := global_position
	var to := from + velocity * delta
	for f: Fighter in world.fighters:
		if not f.alive or f == owner_fighter or f.protect > 0.0:
			continue
		var lo := f.global_position + Vector3.UP * Fighter.HURT_LOW
		var hi := f.global_position + Vector3.UP * Fighter.HURT_HIGH
		if Geo.segment_distance(from, to, lo, hi) <= f.hurt_radius + (0.18 if style == &"orb" else 0.06):
			if f.try_deflect_bolt(self):
				return
			_hit_fighter(f, Geo.closest_on_segment(from, lo, hi), to)
			return
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD))
	if not hit.is_empty():
		_hit_world(hit["position"], hit["normal"], hit["collider"] as Breakable)
		return
	global_position = to
	if gravity > 0.0 or style == &"orb":
		_face()
	if _rope:
		_update_rope()
	if age > life or global_position.y < -30.0:
		queue_free()


func _hit_fighter(f: Fighter, at: Vector3, to: Vector3) -> void:
	var by := _by()
	if style == &"rocket":
		world.explode(to, by, 3.6)
		queue_free()
		return
	if style == &"hook":
		# Yank them over to us.
		if by:
			var pull := by.global_position - f.global_position
			pull.y = 0.0
			f.take_hit(5.0, pull.normalized(), by, false, at, 0.5)
			f.velocity = pull.normalized() * minf(pull.length() * 2.2, 16.0) + Vector3.UP * 4.5
		Audio.play(&"clunk", at, 0.0, 1.4)
		queue_free()
		return
	var dmg := damage * (by.powers.damage_dealt_mult() if by else 1.0)
	var knock: float = STYLES[style]["knock"]
	var dealt := f.take_hit(dmg, Vector3(velocity.x, 0, velocity.z).normalized(), by, style == &"slug" and dmg > 30.0, at, knock)
	if by and dealt > 0.0:
		by.powers.dealt(dealt)
		by.hit_landed.emit(by, f, dealt)
	if style == &"slug":
		Fx.sparks(get_parent(), at, Color(1.0, 0.3, 0.2), 16)
	Fx.sparks(get_parent(), to, STYLES[style]["color"], 8)
	queue_free()


func _hit_world(p: Vector3, n: Vector3, piece: Breakable) -> void:
	var by := _by()
	if style == &"rocket":
		world.explode(p + n * 0.3, by, 3.6)
		queue_free()
		return
	if style == &"hook":
		# Reel in: fly to where it bit.
		if by and by.alive:
			var to := p + n * 0.6 - by.global_position
			by.launch(to.normalized() * clampf(to.length() * 2.4, 9.0, 20.0) + Vector3.UP * 5.0, 0.5)
			by.count("grapples")
		Audio.play(&"clunk", p, -2.0, 1.6)
		Fx.sparks(get_parent(), p, Color(0.9, 0.9, 0.95), 8)
		queue_free()
		return
	if piece:
		piece.hit(damage, p, velocity * 0.1, by)
	Fx.sparks(get_parent(), p, STYLES[style]["color"], 6)
	if style in [&"bolt", &"plasma"] and world:
		world.arena.ignite(p, 1.0, by)       # hot shots set oil alight
	queue_free()


## Magic orbs drift toward the nearest enemy in front of them.
func _home(delta: float) -> void:
	var best: Fighter
	var best_d := 22.0
	var dir := velocity.normalized()
	for f: Fighter in world.fighters:
		if f == owner_fighter or not f.alive:
			continue
		var to := f.global_position + Vector3.UP * 1.1 - global_position
		if to.length() < best_d and dir.dot(to.normalized()) > 0.3:
			best_d = to.length()
			best = f
	if best:
		var want := (best.global_position + Vector3.UP * 1.1 - global_position).normalized()
		velocity = dir.slerp(want, clampf(delta * 2.6, 0.0, 1.0)) * velocity.length()


func _update_rope() -> void:
	var by := _by()
	if by == null:
		_rope.visible = false
		return
	var a := by.socket_transform().origin
	var b := global_position
	var d := b - a
	if d.length() < 0.05:
		return
	var look := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	_rope.global_transform = Transform3D(look * Basis.from_scale(Vector3(1, 1, d.length())), (a + b) * 0.5)
