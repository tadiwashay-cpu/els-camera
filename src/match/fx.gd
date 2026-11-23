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


## A soft round sprite (dust, smoke, flashes): white in the middle, clear at
## the rim; `additive` glows.
static func _soft_material(additive: bool) -> StandardMaterial3D:
	var key := "soft%s" % additive
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.disable_receive_shadows = true
		m.no_depth_test = false
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		m.albedo_texture = t
		_materials[key] = m
	return _materials[key]


## Soft puffs that swell and fade (dust, smoke).
static func _puffs(size: float, additive: bool = false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	q.material = _soft_material(additive)
	p.mesh = q
	p.local_coords = false
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.7))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow
	p.angle_min = 0.0
	p.angle_max = 360.0
	return p


static func dust(parent: Node, at: Vector3, scale: float = 1.0) -> void:
	if parent == null:
		return
	var p := _take("dust", parent, func() -> Node: return _puffs(0.55)) as CPUParticles3D
	p.global_position = at
	p.amount = maxi(int(9 * scale), 3)
	p.lifetime = 0.7
	p.color = Color(0.86, 0.82, 0.74, 1)
	p.direction = Vector3.UP
	p.spread = 85.0
	p.gravity = Vector3(0, 0.8, 0)
	p.initial_velocity_min = 0.8 * scale
	p.initial_velocity_max = 2.6 * scale
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.6 * maxf(scale, 0.5)
	p.scale_amount_max = 1.3 * maxf(scale, 0.5)
	p.restart()


## A bright flash where a blow lands, with a few fast streaks.
static func impact(parent: Node, at: Vector3, color: Color, scale: float = 1.0) -> void:
	if parent == null:
		return
	var p := _take("impact", parent, func() -> Node:
		var q := _puffs(0.9, true)
		q.explosiveness = 1.0
		q.gravity = Vector3.ZERO
		q.spread = 0.0
		q.initial_velocity_min = 0.0
		q.initial_velocity_max = 0.0
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		q.color_ramp = fade
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.3))
		grow.add_point(Vector2(0.4, 1.0))
		grow.add_point(Vector2(1.0, 1.15))
		q.scale_amount_curve = grow
		return q) as CPUParticles3D
	p.global_position = at
	p.amount = 2
	p.lifetime = 0.16
	p.color = color
	p.scale_amount_min = 0.8 * scale
	p.scale_amount_max = 1.1 * scale
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


## Words that pop up over a fighter (PARRY!, RAGE...).
static func floating_text(parent: Node, at: Vector3, text: String, color: Color) -> void:
	if parent == null:
		return
	var l := _take("words", parent, func() -> Node:
		var lab := Label3D.new()
		lab.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.font_size = 56
		lab.outline_size = 14
		lab.pixel_size = 0.006
		return lab) as Label3D
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.global_position = at
	l.scale = Vector3.ONE
	l.visible = true
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", at + Vector3.UP * 0.8, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.chain().tween_callback(func() -> void: l.visible = false)


## A ring of force spreading along the ground (stomp).
static func shockwave(parent: Node, at: Vector3, radius: float, color: Color) -> void:
	if parent == null:
		return
	var ring := _take("rings", parent, func() -> Node:
		var mi := MeshInstance3D.new()
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var tm := TorusMesh.new()
		tm.inner_radius = 0.85
		tm.outer_radius = 1.0
		tm.rings = 24
		tm.ring_segments = 6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.material = m
		mi.mesh = tm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi) as MeshInstance3D
	((ring.mesh as TorusMesh).material as StandardMaterial3D).albedo_color = Color(color, 0.8)
	ring.global_position = at + Vector3.UP * 0.15
	ring.scale = Vector3(0.3, 0.3, 0.3)
	ring.transparency = 0.0
	ring.visible = true
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "transparency", 1.0, 0.35)
	tw.chain().tween_callback(func() -> void: ring.visible = false)


## Water thrown up where something fell in (or a shark struck).
static func splash(parent: Node, at: Vector3, scale: float = 1.0) -> void:
	if parent == null:
		return
	var p := _take("splash", parent, func() -> Node:
		var q := _particles(Color(0.85, 0.95, 1.0), 0.12)
		q.amount = 26
		q.lifetime = 0.9
		q.direction = Vector3.UP
		q.spread = 28.0
		q.initial_velocity_min = 4.0
		q.initial_velocity_max = 8.5
		q.gravity = Vector3(0, -18, 0)
		q.color = Color(0.85, 0.95, 1.0)
		return q) as CPUParticles3D
	p.global_position = at
	p.scale_amount_min = 0.6 * scale
	p.scale_amount_max = 1.4 * scale
	p.restart()
	p.emitting = true


## A lightning strike: a jagged bolt from the sky and a flash of sparks.
static func lightning(parent: Node, at: Vector3) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	var b := BoxBuilder.new()
	var p := Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 9:
		var q := p + Vector3(rng.randf_range(-0.7, 0.7), 2.2, rng.randf_range(-0.7, 0.7))
		var d := q - p
		var basis := Basis.looking_at(d.normalized(), Vector3.RIGHT) if absf(d.normalized().y) > 0.99 else Basis.looking_at(d.normalized(), Vector3.UP)
		b.box(Vector3(0.16, 0.16, d.length() + 0.1), (p + q) * 0.5, Color(0.85, 0.9, 1.0), 0, basis)
		p = q
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(_material(Color(0.9, 0.95, 1.0)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	sparks(parent, at + Vector3.UP * 0.3, Color(0.75, 0.85, 1.0), 24)
	dust(parent, at, 1.0)
	var tw := root.create_tween()
	tw.tween_interval(0.07)
	tw.tween_callback(func() -> void: mi.visible = false)
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void: mi.visible = true)
	tw.tween_interval(0.1)
	tw.tween_callback(root.queue_free)


## A fan's gust: pale streaks rushing forward.
static func gust(parent: Node, at: Vector3, dir: Vector3) -> void:
	if parent == null:
		return
	var p := _take("gust", parent, func() -> Node:
		var q := _particles(Color(0.9, 0.95, 1.0), 0.06)
		q.amount = 22
		q.lifetime = 0.45
		q.spread = 14.0
		q.gravity = Vector3.ZERO
		q.initial_velocity_min = 12.0
		q.initial_velocity_max = 18.0
		q.color = Color(0.9, 0.95, 1.0, 0.7)
		q.scale_amount_min = 0.6
		q.scale_amount_max = 1.6
		return q) as CPUParticles3D
	p.global_position = at
	p.direction = dir
	p.restart()
	p.emitting = true
