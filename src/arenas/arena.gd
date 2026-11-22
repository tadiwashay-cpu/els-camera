class_name Arena
extends Node3D
## Base for arenas: geometry under a NavigationRegion3D (so bots can path
## around it), spawn points, weapon spawner spots, the kill height, sun
## and sky. Subclasses build their layout in build().

signal nav_ready
## A barrel went off: the match applies the blast (fighters, other pieces).
signal explosion(at: Vector3, by: Fighter)
## Something everyone should know about (the tide, the crane): the HUD shows it.
signal notice(text: String, color: Color, sub: String)

const GRID_SHADER := preload("res://src/arenas/grid.gdshader")
const THEMED_SHADER := preload("res://src/arenas/themed.gdshader")
const WATER_SHADER := preload("res://src/arenas/water.gdshader")

## Surface looks for themed arenas: [noise amount, noise scale, plank width, roughness].
const SURFACES := {
	&"sand": [0.1, 1.5, 0.0, 0.95], &"rock": [0.22, 0.9, 0.0, 0.9], &"wood": [0.12, 3.0, 0.3, 0.8],
	&"metal": [0.08, 2.0, 0.0, 0.45], &"rust": [0.3, 1.2, 0.0, 0.75], &"concrete": [0.14, 1.0, 0.0, 0.9],
	&"paint": [0.05, 1.0, 0.0, 0.6], &"leaf": [0.25, 2.0, 0.0, 0.9],
}

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
## Rain makes every themed surface wet.
var wet := 0.0
## Default surface for block(); "" = the blockout grid.
var surface := &""
## Themed arenas merge every static box into one mesh per surface (one draw
## call each instead of one per box); collision stays per box.
var merge := false
## Height of the sea / harbour surface (-INF = no water): splashes, drowning.
var water_level := -INF
## Sea water wears you down: wading slowly, swimming faster (hazards on).
@export var wade_dps := 3.0
@export var swim_dps := 6.0
## Kill feed text when the water finishes someone.
var drown_cause := "drowned"
var _wet_time: Dictionary = {}         # fighter id -> seconds in the water
var _water_credit: Dictionary = {}     # fighter id -> who knocked them in
var _drip: Dictionary = {}             # fighter id -> damage not yet applied
## What the arena did this match (cannon shots, crane grabs...): tests, smoke.
var stats: Dictionary = {}
var _merged: Dictionary = {}           # surface kind -> BoxBuilder
var _glow: BoxBuilder                  # merged lit windows, lamps (unshaded)
var _splashed: Dictionary = {}         # fighter id -> was above water
var _rebake_due := -1.0
var _clock := 0.0


func _ready() -> void:
	add_to_group(&"arena")
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
	_commit_merged()


## Turns the boxes collected by block()/deco() into one mesh per surface.
func _commit_merged() -> void:
	if _glow:
		var g := MeshInstance3D.new()
		g.name = "Merged_glow"
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.disable_fog = true
		g.mesh = _glow.commit(m)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		_glow = null
	for kind: StringName in _merged:
		var mi := MeshInstance3D.new()
		mi.name = "Merged_%s" % kind
		mi.mesh = (_merged[kind] as BoxBuilder).commit(surface_material(Color.WHITE, kind, true))
		add_child(mi)
	_merged.clear()


func _merge_box(size: Vector3, xform: Transform3D, color: Color, kind: StringName) -> void:
	if not _merged.has(kind):
		_merged[kind] = BoxBuilder.new()
	(_merged[kind] as BoxBuilder).box(size, xform.origin, color, 0, xform.basis)


## Override: lay out the arena.
func build() -> void:
	pass


func count(stat: String) -> void:
	stats[stat] = int(stats.get(stat, 0)) + 1


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


## A themed surface material (shared per colour and kind). `vertex` = take
## the colour from the mesh (merged boxes) instead of `color`.
func surface_material(color: Color, kind: StringName, vertex: bool = false) -> ShaderMaterial:
	if kind == &"":
		return grid_material(color)
	var key := "%s_%s_%s" % [color.to_html(), kind, vertex]
	if not _materials.has(key):
		var p: Array = SURFACES.get(kind, SURFACES[&"concrete"])
		var m := ShaderMaterial.new()
		m.shader = THEMED_SHADER
		m.set_shader_parameter(&"tint", color)
		m.set_shader_parameter(&"noise_amount", p[0])
		m.set_shader_parameter(&"noise_scale", p[1])
		m.set_shader_parameter(&"planks", p[2])
		m.set_shader_parameter(&"roughness_value", p[3])
		m.set_shader_parameter(&"wet", wet)
		m.set_shader_parameter(&"vertex_tint", vertex)
		_materials[key] = m
	return _materials[key]


## Decoration: a box that looks the part but doesn't collide or block bots.
func deco(size: Vector3, centre: Vector3, color: Color, kind: StringName = &"", yaw_deg: float = 0.0, pitch_deg: float = 0.0, roll_deg: float = 0.0) -> MeshInstance3D:
	if merge:
		var basis := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), deg_to_rad(roll_deg)), EULER_ORDER_YXZ)
		_merge_box(size, Transform3D(basis, centre), color, kind if kind != &"" else surface)
		return null
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = surface_material(color, kind if kind != &"" else surface)
	mi.mesh = bm
	mi.position = centre
	mi.rotation_degrees = Vector3(pitch_deg, yaw_deg, roll_deg)
	add_child(mi)
	return mi


## A sheet of animated water at height y (no collision: fall in and you sink).
func water(size: Vector2, centre: Vector3, shallow: Color, deep: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	m.set_shader_parameter(&"shallow", shallow)
	m.set_shader_parameter(&"deep", deep)
	pm.material = m
	mi.mesh = pm
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## How fast fighters can move here (1 = normal; water slows).
func speed_factor_at(_pos: Vector3) -> float:
	return 1.0


## How well feet grip here (1 = normal; oil is slippery).
func grip_at(_pos: Vector3) -> float:
	return 1.0


## Ground that carries you (conveyor belts), in m/s.
func floor_push(_pos: Vector3) -> Vector3:
	return Vector3.ZERO


## Fire or a blast at `at`: sets oil alight and the like.
func ignite(_at: Vector3, _radius: float, _by: Fighter) -> void:
	pass


## Somewhere a bot could go to use the arena (a lever, a cannon), with how
## much it wants to: {"at": Vector3, "score": float}; empty = nothing.
func bot_goal(_f: Fighter, _m: Match) -> Dictionary:
	return {}


## Per-frame arena life and hazards (tides, sharks, cranes...). Subclasses
## call super() for splashes.
func tick(m: Match, delta: float) -> void:
	if water_level == -INF:
		return
	for f in m.fighters:
		var id := f.fighter_id
		var above := f.global_position.y > water_level
		var was: bool = _splashed.get(id, true)
		if was and not above and f.velocity.y < -3.0:
			Fx.splash(self, Vector3(f.global_position.x, water_level, f.global_position.z), 1.2)
			Audio.play(&"splash", f.global_position, 0.0)
		_splashed[id] = above
		var wet := f.alive and m.config.hazards and water_level - f.global_position.y > 0.15 and not f.held()
		if not wet:
			_wet_time.erase(id)
			_water_credit.erase(id)
			_drip.erase(id)
			continue
		if not _wet_time.has(id) and f.last_hitter and f.last_hitter != f \
				and m.clock - f.last_hit_time <= KillRace.CREDIT_WINDOW:
			_water_credit[id] = f.last_hitter      # knocked in: their kill if we drown
		_wet_time[id] = float(_wet_time.get(id, 0.0)) + delta
		var acc: float = float(_drip.get(id, 0.0)) + (swim_dps if f.swimming else wade_dps) * delta
		if acc >= 2.0:
			_credit_water_kill(m, f)
			f.drain(acc, drown_cause)
			acc = 0.0
		_drip[id] = acc


## Seconds `f` has been standing or swimming in the sea (0 = dry).
func wet_time(f: Fighter) -> float:
	return float(_wet_time.get(f.fighter_id, 0.0))


## Whoever knocked `f` into the water still gets the kill when it finishes them.
func _credit_water_kill(m: Match, f: Fighter) -> void:
	var by: Variant = _water_credit.get(f.fighter_id)
	if by != null and is_instance_valid(by) and (by as Fighter).alive and f.last_hitter in [null, by]:
		f.last_hitter = by
		f.last_hit_time = m.clock


## Where a swimmer should head to climb out (bots).
func swim_exit(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, -bounds, bounds), 0.0, clampf(pos.z, -bounds, bounds))


## Dry ground near `pos` for bots to wait out a flood (INF = nowhere better).
func dry_spot(_pos: Vector3) -> Vector3:
	return Vector3.INF


## A one-way bot shortcut (jump off a ledge, ride a cannon).
func nav_link(from: Vector3, to: Vector3, bidirectional: bool = false) -> NavigationLink3D:
	var link := NavigationLink3D.new()
	link.start_position = from
	link.end_position = to
	link.bidirectional = bidirectional
	add_child(link)
	return link


## A box of steady light merged with the others (windows, distant lamps).
func glow_static(size: Vector3, centre: Vector3, color: Color, yaw_deg: float = 0.0) -> void:
	if _glow == null:
		_glow = BoxBuilder.new()
	_glow.box(size, centre, color, 0, Basis(Vector3.UP, deg_to_rad(yaw_deg)))


## A pole with a box of light on top that flickers (signs, lamps).
func glow_box(size: Vector3, centre: Vector3, color: Color, energy: float = 2.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color * energy
	bm.material = m
	mi.mesh = bm
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


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
	if merge:
		_merge_box(size, b.transform, color, surface)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = surface_material(color, surface)
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
