class_name Arena
extends Node3D
## Base for arenas: geometry under a NavigationRegion3D (so bots can path
## around it), spawn points, weapon spawner spots, the kill height, sun
## and sky. Subclasses build their layout in build().

signal nav_ready
## A barrel went off: the match applies the blast (fighters, other pieces).
signal explosion(at: Vector3, by: Fighter)

const GRID_SHADER := preload("res://src/arenas/grid.gdshader")

var spawn_points: Array[Vector3] = []
var spawner_points: Array[Vector3] = []
var pickup_points: Array[Vector3] = []
## Where the mystery crate drops (Vector3.INF = no crate here).
var mystery_point := Vector3.INF
var kill_y := -14.0
var bounds := 34.0                 # half-size of the play area (camera, bots)
var nav: NavigationRegion3D
var sun: DirectionalLight3D
var env: Environment
var debris: DebrisPool
var breakables: Array[Breakable] = []
var _materials: Dictionary = {}
var _baking := false
var _rebake_due := -1.0
var _clock := 0.0


func _ready() -> void:
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Game.L_WORLD
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 42.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav.navigation_mesh = nm
	add_child(nav)
	debris = DebrisPool.new()
	debris.name = "Debris"
	add_child(debris)
	_sky()
	build()


## Override: lay out the arena.
func build() -> void:
	pass


## Bakes the bot navigation mesh on a thread; emits nav_ready.
func bake_navigation() -> void:
	_baking = true
	nav.bake_finished.connect(func() -> void:
		_baking = false
		nav_ready.emit(), CONNECT_ONE_SHOT)
	nav.bake_navigation_mesh(true)


## Something broke or rebuilt: rebake the nav mesh soon (batched, on a thread).
func request_rebake() -> void:
	if _rebake_due < 0.0:
		_rebake_due = _clock + 0.6


func _physics_process(delta: float) -> void:
	_clock += delta
	if _rebake_due > 0.0 and _clock >= _rebake_due and not _baking:
		_rebake_due = -1.0
		bake_navigation()


## A breakable box (crate, pillar, rail, barrel) that is also a nav obstacle.
func breakable(kind: Breakable.Kind, size: Vector3, centre: Vector3, color: Color) -> Breakable:
	var b := Breakable.new()
	b.position = centre
	nav.add_child(b)
	b.setup(kind, size, color, self)
	if kind == Breakable.Kind.BARREL:
		b.broken.connect(func(piece: Breakable, by: Fighter) -> void: explosion.emit(piece.global_position, by))
	breakables.append(b)
	return b


## Pieces whose box a segment passes within `radius` of.
func breakables_on_segment(a: Vector3, b: Vector3, radius: float) -> Array[Breakable]:
	var out: Array[Breakable] = []
	for piece in breakables:
		if piece.is_broken:
			continue
		var box := piece.bounds().grow(radius)
		if box.has_point(a) or box.has_point(b) or box.intersects_segment(a, b) != null:
			out.append(piece)
	return out


func breakable_near(pos: Vector3, radius: float) -> Breakable:
	for piece in breakables:
		if not piece.is_broken and piece.bounds().grow(radius).has_point(pos):
			return piece
	return null


func grid_material(color: Color, cell: float = 1.0) -> ShaderMaterial:
	var key := "%s_%s" % [color.to_html(), cell]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = GRID_SHADER
		m.set_shader_parameter(&"tint", color)
		m.set_shader_parameter(&"cell", cell)
		_materials[key] = m
	return _materials[key]


## A solid box: mesh + collision, part of the nav source.
func block(size: Vector3, centre: Vector3, color: Color, yaw_deg: float = 0.0, pitch_deg: float = 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Game.L_WORLD
	b.collision_mask = 0
	b.position = centre
	b.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = grid_material(color)
	mi.mesh = bm
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	nav.add_child(b)
	return b


## A ramp from `from` (bottom centre) up to `to` (top centre), `width` wide.
func ramp(from: Vector3, to: Vector3, width: float, color: Color, thickness: float = 0.5) -> StaticBody3D:
	var d := to - from
	var flat := Vector2(d.x, d.z).length()
	var length := d.length()
	var yaw := rad_to_deg(atan2(d.x, d.z))
	var pitch := -rad_to_deg(atan2(d.y, flat))
	var centre := (from + to) * 0.5 - Vector3.UP * thickness * 0.5 * cos(atan2(d.y, flat))
	return block(Vector3(width, thickness, length), centre, color, yaw, pitch)


func _sky() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.28, 0.5, 0.86)
	mat.sky_horizon_color = Color(0.72, 0.82, 0.92)
	mat.ground_bottom_color = Color(0.2, 0.26, 0.34)
	mat.ground_horizon_color = Color(0.62, 0.7, 0.8)
	mat.sun_angle_max = 20.0
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.88)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_blur = 1.2
	add_child(sun)


## The spawn point farthest from every enemy (doc: Respawn).
static func farthest_spawn(points: Array[Vector3], enemies: Array[Vector3]) -> int:
	var best := 0
	var best_score := -1.0
	for i in points.size():
		var nearest := INF
		for e in enemies:
			nearest = minf(nearest, points[i].distance_to(e))
		if enemies.is_empty():
			nearest = randf()
		if nearest > best_score:
			best_score = nearest
			best = i
	return best
