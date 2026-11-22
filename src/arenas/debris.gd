class_name DebrisPool
extends Node3D
## Pooled physics chunks for smashed scenery. A fixed number of rigid boxes
## are reused round-robin (never created mid-fight); they tumble, settle,
## shrink away after a few seconds and wait for the next break. They collide
## with the arena and each other, not with fighters (no jitter in fights).

const POOL := 40
const LIFE := 5.0
const L_DEBRIS := 64

var _bodies: Array[RigidBody3D] = []
var _meshes: Array[MeshInstance3D] = []
var _born: Array[float] = []
var _next := 0
var _clock := 0.0
var _mat := BoxBuilder.vertex_color_material(0.85)
var _unit: ArrayMesh


func _ready() -> void:
	var b := BoxBuilder.new()
	b.box(Vector3.ONE, Vector3.ZERO, Color.WHITE)
	_unit = b.commit()
	for i in POOL:
		var body := RigidBody3D.new()
		body.collision_layer = L_DEBRIS
		body.collision_mask = Game.L_WORLD | L_DEBRIS
		body.freeze = true
		body.visible = false
		body.angular_damp = 1.0
		body.linear_damp = 0.2
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		var mi := MeshInstance3D.new()
		mi.mesh = _unit
		mi.material_override = _mat
		body.add_child(mi)
		add_child(body)
		_bodies.append(body)
		_meshes.append(mi)
		_born.append(-100.0)
		body.process_mode = Node.PROCESS_MODE_DISABLED


## Breaks a box of `size` at `centre` into `count` chunks flying out (and along `push`).
func burst(centre: Vector3, size: Vector3, color: Color, count: int, push: Vector3 = Vector3.ZERO) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chunk := (size / maxf(pow(float(count), 1.0 / 3.0), 1.0)).clamp(Vector3.ONE * 0.12, Vector3.ONE * 0.7)
	for i in count:
		var body := _bodies[_next]
		var mi := _meshes[_next]
		_born[_next] = _clock
		_next = (_next + 1) % POOL
		var s := chunk * Vector3(rng.randf_range(0.6, 1.2), rng.randf_range(0.5, 1.1), rng.randf_range(0.6, 1.2))
		((body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = s
		mi.scale = s
		var c := color.darkened(rng.randf_range(0.0, 0.25))
		mi.material_override = _tinted(c)
		var off := Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(-0.4, 0.5) * size.y, rng.randf_range(-0.5, 0.5) * size.z)
		body.process_mode = Node.PROCESS_MODE_INHERIT
		body.freeze = false
		body.visible = true
		body.global_transform = Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)), centre + off)
		body.mass = maxf(s.x * s.y * s.z * 400.0, 0.5)
		body.linear_velocity = off.normalized() * rng.randf_range(2.5, 6.0) + Vector3.UP * rng.randf_range(2.0, 5.0) + push * 0.6
		body.angular_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))


var _tints: Dictionary = {}


func _tinted(c: Color) -> StandardMaterial3D:
	var key := c.to_html(false).substr(0, 5)       # a few shades, shared
	if not _tints.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_tints[key] = m
	return _tints[key]


func _physics_process(delta: float) -> void:
	_clock += delta
	for i in POOL:
		var body := _bodies[i]
		if not body.visible:
			continue
		var age := _clock - _born[i]
		if age > LIFE:
			var k := 1.0 - clampf((age - LIFE) / 0.6, 0.0, 1.0)
			_meshes[i].scale = ((body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size * k
			if k <= 0.0 or body.global_position.y < -20.0:
				body.freeze = true
				body.visible = false
				body.process_mode = Node.PROCESS_MODE_DISABLED


func active_count() -> int:
	var n := 0
	for b in _bodies:
		if b.visible:
			n += 1
	return n
