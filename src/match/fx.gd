class_name Fx
extends RefCounted
## Pooled hit effects: sparks, dust, bursts and damage numbers. Nodes are
## reused round-robin, never created and freed mid-fight (doc: memory plan).

const POOL := 8
static var _pools: Dictionary = {}       # kind -> {"parent": Node, "items": Array, "next": int}
static var _materials: Dictionary = {}


static func _material(color: Color, unshaded: bool = true) -> StandardMaterial3D:
	var key := "%s%s" % [color.to_html(), unshaded]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_materials[key] = m
	return _materials[key]


static func _take(kind: String, parent: Node, make: Callable) -> Node:
	var pool: Dictionary = _pools.get(kind, {})
	if pool.is_empty() or not is_instance_valid(pool["parent"]) or pool["parent"] != parent:
		pool = {"parent": parent, "items": [], "next": 0}
		_pools[kind] = pool
	var items: Array = pool["items"]
	if items.size() < POOL:
		var n: Node = make.call()
		parent.add_child(n)
		items.append(n)
		return n
	var i: int = pool["next"]
	pool["next"] = (i + 1) % POOL
	return items[i]


static func _particles(color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	box.material = _material(Color.WHITE)
	p.mesh = box
	p.spread = 180.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.local_coords = false
	return p


static func sparks(parent: Node, at: Vector3, color: Color, amount: int = 14) -> void:
	if parent == null:
		return
	var p := _take("sparks", parent, func() -> Node: return _particles(color, 0.05)) as CPUParticles3D
	p.global_position = at
	p.amount = amount
	p.lifetime = 0.35
	p.color = color
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.restart()


static func dust(parent: Node, at: Vector3, scale: float = 1.0) -> void:
	if parent == null:
		return
	var p := _take("dust", parent, func() -> Node: return _particles(Color(0.8, 0.78, 0.72), 0.12)) as CPUParticles3D
	p.global_position = at
	p.amount = int(10 * scale)
	p.lifetime = 0.55
	p.color = Color(0.82, 0.8, 0.74, 1)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 1.0 * scale
	p.initial_velocity_max = 3.0 * scale
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.restart()


## A big puff of the fighter's colours (KO, respawn).
static func burst(parent: Node, at: Vector3, color: Color) -> void:
	if parent == null:
		return
	var p := _take("burst", parent, func() -> Node: return _particles(color, 0.14)) as CPUParticles3D
	p.global_position = at
	p.amount = 28
	p.lifetime = 0.8
	p.color = color
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, -9, 0)
	p.restart()


static func damage_number(parent: Node, at: Vector3, amount: float, color: Color) -> void:
	if parent == null:
		return
	var l := _take("numbers", parent, func() -> Node:
		var lab := Label3D.new()
		lab.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.font_size = 64
		lab.outline_size = 14
		lab.pixel_size = 0.006
		return lab) as Label3D
	l.text = str(int(round(amount)))
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.global_position = at + Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2))
	l.scale = Vector3.ONE * clampf(0.8 + amount / 40.0, 0.8, 1.8)
	l.visible = true
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3.UP * 1.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(func() -> void: l.visible = false)


## A barrel going off: fireball flash, smoke and chunks.
static func explosion(parent: Node, at: Vector3, radius: float) -> void:
	if parent == null:
		return
	burst(parent, at, Color(1.0, 0.55, 0.12))
	dust(parent, at, 2.0)
	sparks(parent, at + Vector3.UP * 0.4, Color(1.0, 0.85, 0.3), 24)
	var ball := _take("blast", parent, func() -> Node:
		var mi := MeshInstance3D.new()
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 16
		sm.rings = 8
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.6, 0.2, 0.55)
		sm.material = m
		mi.mesh = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi) as MeshInstance3D
	ball.global_position = at
	ball.scale = Vector3.ONE * 0.3
	ball.visible = true
	ball.transparency = 0.0
	var tw := ball.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * radius, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ball, "transparency", 1.0, 0.32)
	tw.chain().tween_callback(func() -> void: ball.visible = false)
