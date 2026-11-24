extends Arena
## Beach Island: a bright midday tropical island (doc: Arenas). A sand beach
## with a wrecked ship, a lighthouse on a rock, a wooden pier, palms, a rope
## bridge to a rock islet and a waterfall over a cave.
##   Hazards: every 2 minutes the tide floods the low beach (wading is slow);
##   deep water past the sand shelf has sharks (instant KO, credited to
##   whoever knocked you in).
##   Signature: climb into the wreck's cannon to be fired onto the lighthouse.
##   Twists: Turtle Rock, a dry rock out west in shark water, and bounce pads
##   (beach -> rock and back, beach -> ridge, beach -> islet).

const SAND := Color(0.93, 0.83, 0.6)
const WET_SAND := Color(0.78, 0.68, 0.48)
const ROCK := Color(0.52, 0.5, 0.47)
const DARK_ROCK := Color(0.4, 0.38, 0.36)
const WOOD := Color(0.55, 0.38, 0.22)
const OLD_WOOD := Color(0.42, 0.3, 0.2)
const LEAF := Color(0.25, 0.6, 0.25)
const WHITE := Color(0.95, 0.94, 0.9)
const RED := Color(0.85, 0.18, 0.15)

## Sand shelf under the shallows (x0, z0, x1, z1): past it is deep water.
const SHELF := Rect2(-30.0, -30.0, 60.0, 52.0)
const TIDE_LOW := -0.35
const TIDE_HIGH := 0.5
## Tide cycle (s): rises at 45 s, then every 2 minutes.
const TIDE_PERIOD := 120.0
const TIDE_START := 45.0
const TIDE_RISE := 6.0
const TIDE_HOLD := 24.0

const CANNON_BREECH := Vector3(17.2, 2.2, -1.0)
const CANNON_MUZZLE := Vector3(14.2, 4.4, -1.0)
const LIGHTHOUSE_TOP := Vector3(-15.6, 12.5, 6.0)
const CANNON_FLIGHT := 1.6

var tide := 0.0                     # 0 low .. 1 high
var _water: MeshInstance3D
var _pool: MeshInstance3D
var _fins: Array[MeshInstance3D] = []
var _fin_paths: Array[Vector4] = []     # centre x, centre z, radius, speed
var _fin_hidden: Array[float] = []
var _shark: Node3D
var _beam: Node3D
var _cannon_wait: Dictionary = {}       # fighter id -> seconds in the breech
var _cannon_cd: Dictionary = {}         # fighter id -> clock it may fire again
var _ring: MeshInstance3D
var _tide_phase := -1
var _deep: Dictionary = {}              # fighter id -> seconds since the last shark bite
## Shark water: the first bite comes after this long, then one every this long.
const SHARK_EVERY := 2.5
const SHARK_BITE := 22.0
## Places bots climb out onto: islet and pier (x0, z0, x1, z1).
const ISLET := Rect2(-8.5, 27.6, 9.0, 9.0)
const PIER := Rect2(19.0, -9.0, 19.0, 3.5)
## High ground bots wait out the tide on.
const DRY: Array[Vector3] = [Vector3(-14, 2.5, 2.5), Vector3(-13, 4.5, -17), Vector3(13, 4.5, -17),
	Vector3(15, 2.2, 4), Vector3(25, 0.6, -7.25), Vector3(-20.5, 0.65, 15.5), Vector3(-37.5, 1.0, 4.0)]
## Rock outcrops in the shallows: dry even at high tide (jump onto them).
const OUTCROPS: Array[Vector3] = [Vector3(-27, 0, -10), Vector3(-28, 0, 15), Vector3(27, 0, 15), Vector3(27.5, 0, 2),
	Vector3(-14, 0, -27), Vector3(14, 0, -27), Vector3(14, 0, 21)]
var _clock_t := 0.0
var _clouds: Node3D
var _gulls: Array[Node3D] = []
var _buoys: Array[Node3D] = []
var _boat: Node3D


func build() -> void:
	merge = true
	surface = &"sand"
	kill_y = -12.0
	bounds = 42.0
	water_level = TIDE_LOW
	_look()

	# Sea floor far below (looks), the sand shelf under the shallows, the beach.
	deco(Vector3(170, 1, 170), Vector3(0, -9.5, 0), DARK_ROCK.darkened(0.2), &"sand")
	block(Vector3(SHELF.size.x, 1, SHELF.size.y), Vector3(SHELF.get_center().x, -1.5, SHELF.get_center().y), WET_SAND)
	block(Vector3(44, 1.2, 34), Vector3(0, -0.6, 3), SAND)
	for sx: float in [-1.0, 1.0]:
		ramp(Vector3(sx * 26.5, -1.0, 3), Vector3(sx * 22.0, 0.0, 3), 34.0, SAND.lerp(WET_SAND, 0.5))
	_ridge()
	_lighthouse()
	_wreck()
	_pier()
	_bridge_and_islet()
	_details()
	for p: Vector3 in [Vector3(-8, 0, 15), Vector3(5, 0, 17), Vector3(-19, 0, -10), Vector3(20, 0, -10),
			Vector3(-6, 4.5, -21), Vector3(18, 4.5, -21), Vector3(-2, 0.1, 33.5)]:
		_palm(p, p.x * 3.1 + p.z)

	# Washed-up cargo and explosive barrels.
	surface = &"wood"
	for p: Vector3 in [Vector3(-4, 1, -4), Vector3(6, 1, 3), Vector3(-10, 1, 14), Vector3(6, 1, -10)]:
		breakable(Breakable.Kind.CRATE, Vector3(2, 2, 2), p, Color(0.8, 0.64, 0.4))
	for base: Vector3 in [Vector3(9, 0, 14), Vector3(-15, 4.5, -17)]:
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(-0.55, 0.5, 0), Color(0.82, 0.66, 0.42))
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(0.55, 0.5, 0.1), Color(0.76, 0.6, 0.38))
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(0.0, 1.5, 0.05), Color(0.8, 0.64, 0.4))
	for p: Vector3 in [Vector3(-2, 0.55, 8), Vector3(10, 0.55, -8), Vector3(16.5, 2.75, 9.5), Vector3(6, 5.05, -18),
			Vector3(-6, 0.65, 31), Vector3(31, 1.15, -6.2)]:
		breakable(Breakable.Kind.BARREL, Vector3(0.8, 1.1, 0.8), p, Color(0.85, 0.16, 0.12))
	for p: Vector3 in [Vector3(-9, 2, -9), Vector3(5, 2, 9)]:
		breakable(Breakable.Kind.PILLAR, Vector3(1.1, 4, 1.1), p, ROCK.lightened(0.1))
	surface = &"sand"

	_turtle_rock()

	spawn_points = [Vector3(-6, 0.1, -8), Vector3(6, 0.1, -8), Vector3(-17, 0.1, 17), Vector3(8, 0.1, 17),
		Vector3(0, 0.1, 5), Vector3(-14, 2.6, 2.5), Vector3(-12, 4.6, -18), Vector3(12, 4.6, -18),
		Vector3(-38, 1.1, 6)]
	spawner_points = [Vector3(-17, 4.5, -18), Vector3(0, 0.0, -20.5), Vector3(15, 2.2, 6.0),
		Vector3(36, 0.6, -7.25), Vector3(-4, 0.1, 32.5), Vector3(1, 0.0, 12), Vector3(-38.5, 1.0, 1.5)]
	pickup_points = [Vector3(-6, 0.0, 1), Vector3(9, 0.0, -4), Vector3(17, 4.5, -18), Vector3(-19.5, 2.5, 2.5),
		Vector3(19, 0.0, 16), Vector3(-15, 0.0, -6)]
	mystery_point = LIGHTHOUSE_TOP

	_water = water(Vector2(170, 170), Vector3(0, TIDE_LOW, 0), Color(0.1, 0.62, 0.66, 0.42), Color(0.02, 0.26, 0.48, 0.93))
	var wm := (_water.mesh as PlaneMesh).material as ShaderMaterial
	wm.set_shader_parameter(&"shelf", Vector4(SHELF.position.x, SHELF.position.y, SHELF.end.x, SHELF.end.y))
	wm.set_shader_parameter(&"falloff", 7.0)
	_sharks()


func _look() -> void:
	var mat := env.sky.sky_material as ProceduralSkyMaterial
	mat.sky_top_color = Color(0.16, 0.45, 0.9)
	mat.sky_horizon_color = Color(0.62, 0.85, 0.95)
	mat.ground_horizon_color = Color(0.5, 0.78, 0.85)
	mat.ground_bottom_color = Color(0.1, 0.35, 0.5)
	env.fog_light_color = Color(0.65, 0.85, 0.95)
	env.fog_density = 0.003
	env.ambient_light_energy = 0.7
	env.adjustment_saturation = 1.2
	sun.rotation_degrees = Vector3(-64, -30, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.97, 0.88)


# ------------------------------------------------------------------ layout

## The rock ridge along the north with the waterfall cave through it.
func _ridge() -> void:
	surface = &"rock"
	for sx: float in [-1.0, 1.0]:
		block(Vector3(18, 5.5, 10), Vector3(sx * 13.0, 1.75, -19.0), ROCK)
		ramp(Vector3(sx * 13.0, 0.0, -4.5), Vector3(sx * 13.0, 4.5, -14.0), 4.0, ROCK.lightened(0.08))
	# The cave: 8 m wide, 3.4 m high, a pool at the back.
	block(Vector3(8, 1.1, 10), Vector3(0, 3.95, -19.0), ROCK)
	block(Vector3(8, 5.5, 1.5), Vector3(0, 1.75, -24.75), DARK_ROCK)
	block(Vector3(8, 1, 10), Vector3(0, -0.5, -19.0), WET_SAND)
	deco(Vector3(7.8, 0.05, 7.6), Vector3(0, 3.38, -19.2), DARK_ROCK.darkened(0.3), &"rock")
	# Boulders on top.
	for p: Vector4 in [Vector4(-19, 5.0, -21, 1.6), Vector4(-8, 5.0, -16, 1.0), Vector4(20, 5.0, -16, 1.3), Vector4(9, 5.0, -22, 1.1)]:
		block(Vector3(p.w * 1.4, p.w, p.w * 1.2), Vector3(p.x, 4.5 + p.w * 0.5, p.z), ROCK.lightened(0.05), p.x * 7.0)
	surface = &"sand"
	# Waterfall over the cave mouth, splashing into a pool.
	var fall := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6.5, 5.2)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://src/arenas/fx/waterfall.gdshader")
	q.material = sm
	fall.mesh = q
	fall.position = Vector3(0, 2.0, -13.8)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fall)
	_pool = water(Vector2(8, 3.5), Vector3(0, 0.04, -12.4), Color(0.3, 0.8, 0.85, 0.7), Color(0.3, 0.8, 0.85, 0.7))
	var spray := CPUParticles3D.new()
	spray.amount = 28
	spray.lifetime = 0.8
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(3.0, 0.1, 0.3)
	spray.direction = Vector3(0, 1, 0.4)
	spray.spread = 35.0
	spray.initial_velocity_min = 1.5
	spray.initial_velocity_max = 3.5
	spray.gravity = Vector3(0, -9, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.12
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(0.92, 0.97, 1.0)
	bm.material = white
	spray.mesh = bm
	spray.position = Vector3(0, 0.1, -13.4)
	add_child(spray)


## Lighthouse on a rock plateau to the west: only the cannon gets you up.
func _lighthouse() -> void:
	surface = &"rock"
	block(Vector3(10, 3.5, 10), Vector3(-17, 0.75, 6), ROCK)
	ramp(Vector3(-6.0, 0.0, 6.0), Vector3(-12.0, 2.5, 6.0), 4.0, ROCK.lightened(0.08))
	surface = &"paint"
	block(Vector3(3.6, 9.5, 3.6), Vector3(-17, 7.25, 6), WHITE)
	for y: float in [4.2, 7.4, 10.6]:
		deco(Vector3(3.7, 1.3, 3.7), Vector3(-17, y, 6), RED, &"paint")
	block(Vector3(6.5, 0.5, 6.5), Vector3(-17, 12.25, 6), Color(0.3, 0.3, 0.32))
	# Lamp room on the west half (the landing spot is the east half).
	block(Vector3(2.2, 1.0, 2.4), Vector3(-19.0, 13.0, 6), RED)
	deco(Vector3(2.6, 0.3, 2.8), Vector3(-19.0, 14.65, 6), Color(0.25, 0.25, 0.28), &"metal")
	surface = &"sand"
	glow_box(Vector3(1.7, 1.0, 1.9), Vector3(-19.0, 14.0, 6), Color(1.0, 0.92, 0.55), 1.6)
	# The turning beam.
	_beam = Node3D.new()
	_beam.position = Vector3(-19.0, 14.0, 6)
	add_child(_beam)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.9, 0.55, 0.08)
	for sgn: float in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.5, 16)
		bm.material = m
		b.mesh = bm
		b.position = Vector3(0, 0, sgn * 8.8)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.add_child(b)
	# Bots: jump off the top to come down.
	nav_link(Vector3(-14.1, 12.5, 4.5), Vector3(-9.0, 0.0, 3.0))


## The wreck on the east beach, with its cannon aimed at the lighthouse.
func _wreck() -> void:
	surface = &"wood"
	block(Vector3(6, 2.2, 14), Vector3(15, 1.1, 4), OLD_WOOD)
	ramp(Vector3(8.0, 0.0, 9.0), Vector3(12.0, 2.2, 9.0), 3.0, WOOD)
	block(Vector3(0.35, 0.8, 14), Vector3(17.85, 2.6, 4), OLD_WOOD.darkened(0.15))
	block(Vector3(0.35, 0.8, 10), Vector3(12.15, 2.6, 2), OLD_WOOD.darkened(0.15))
	block(Vector3(6, 1.4, 0.35), Vector3(15, 2.9, -2.85), OLD_WOOD.darkened(0.15))
	# Bow and keel (looks), the broken mast and a torn sail.
	deco(Vector3(4.2, 2.6, 4.2), Vector3(15, 1.0, 11.6), OLD_WOOD, &"wood", 45.0)
	deco(Vector3(6.4, 0.6, 14.4), Vector3(15, -0.1, 4), OLD_WOOD.darkened(0.3), &"wood")
	deco(Vector3(0.45, 8.0, 0.45), Vector3(14.6, 5.8, 3.5), WOOD.darkened(0.1), &"wood", 0.0, 8.0, -14.0)
	deco(Vector3(0.25, 0.25, 4.5), Vector3(14.0, 8.0, 3.8), WOOD.darkened(0.1), &"wood", 90.0, 0.0, 10.0)
	deco(Vector3(3.6, 2.6, 0.06), Vector3(14.2, 6.6, 3.9), Color(0.9, 0.86, 0.75), &"paint", 85.0, 0.0, -12.0)
	# Cannon: carriage, wheels, barrel tilted up toward the lighthouse.
	deco(Vector3(1.8, 0.5, 1.3), Vector3(16.0, 2.45, -1.0), WOOD.darkened(0.2), &"wood")
	for z: float in [-1.75, -0.25]:
		deco(Vector3(1.0, 1.0, 0.2), Vector3(16.0, 2.6, z), OLD_WOOD.darkened(0.3), &"wood")
	var dir := (CANNON_MUZZLE - CANNON_BREECH - Vector3.UP * 0.7).normalized()
	var mid := (CANNON_BREECH + Vector3.UP * 0.7 + CANNON_MUZZLE) * 0.5
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	var pitch := -rad_to_deg(asin(dir.y))
	deco(Vector3(0.85, 0.85, 3.4), mid, Color(0.16, 0.16, 0.18), &"metal", yaw, pitch)
	deco(Vector3(1.05, 1.05, 0.3), CANNON_MUZZLE, Color(0.12, 0.12, 0.14), &"metal", yaw, pitch)
	surface = &"sand"
	# A glowing ring marks the breech: stand in it to be fired.
	_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.75
	cyl.height = 0.03
	cyl.radial_segments = 20
	cyl.rings = 1
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.55, 0.2, 0.55)
	cyl.material = rm
	_ring.mesh = cyl
	_ring.position = CANNON_BREECH + Vector3.UP * 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# Bots: the cannon is the way up the lighthouse.
	var link := nav_link(CANNON_BREECH, LIGHTHOUSE_TOP)
	link.enter_cost = 6.0


## A wooden pier out over deep water, with railings you can smash.
func _pier() -> void:
	surface = &"wood"
	block(Vector3(19, 0.3, 3.5), Vector3(28.5, 0.45, -7.25), WOOD)
	ramp(Vector3(16.5, 0.0, -7.25), Vector3(19.0, 0.6, -7.25), 3.5, WOOD)
	for x: float in [20.0, 24.0, 28.0, 32.0, 36.0]:
		for z: float in [-9.0, -5.5]:
			deco(Vector3(0.35, 4.0, 0.35), Vector3(x, -1.6, z), OLD_WOOD, &"wood")
	surface = &"sand"
	for x: float in [22.3, 26.6, 30.9, 35.2]:
		for z: float in [-8.85, -5.65]:
			breakable(Breakable.Kind.RAIL, Vector3(4.2, 0.9, 0.22), Vector3(x, 1.05, z), WOOD.lightened(0.1))


## A rope bridge of breakable planks from the south beach to a rock islet.
func _bridge_and_islet() -> void:
	surface = &"rock"
	block(Vector3(9, 6, 9), Vector3(-4, -2.9, 32.1), ROCK)
	surface = &"sand"
	deco(Vector3(8.6, 0.06, 8.6), Vector3(-4, 0.12, 32.1), SAND, &"sand")
	for i in 8:
		breakable(Breakable.Kind.RAIL, Vector3(2.4, 0.25, 0.94), Vector3(-4, -0.025, 20.475 + i * 0.95), WOOD.lightened(0.05 * float(i % 2)))
	for x: float in [-5.4, -2.6]:
		deco(Vector3(0.06, 0.06, 8.0), Vector3(x, 1.0, 24.0), Color(0.75, 0.65, 0.45), &"wood")
		for z: float in [19.8, 28.2]:
			deco(Vector3(0.25, 1.4, 0.25), Vector3(x, 0.6, z), OLD_WOOD, &"wood")


## The things that make it a place: outcrops to escape the water onto, a
## fishing hut and campfire, driftwood, shells, seaweed, grass, wreck ribs,
## lighthouse windows and railing, pier lamps, a rowboat, buoys, gulls,
## clouds and far islands. Static boxes merge into a few meshes.
func _details() -> void:
	# Rock outcrops standing out of the shallows.
	surface = &"rock"
	for i in OUTCROPS.size():
		var o := OUTCROPS[i]
		var yaw := float(i) * 37.0
		var rocks: Array[StringName] = [&"rock_a", &"rock_b", &"rock_c", &"rock_d"]
		prop(rocks[i % 4], o + Vector3(0, -0.75, 0), yaw, 2.2)
		prop(rocks[(i + 1) % 4], o + Vector3(1.3, -0.9, -0.6), yaw + 70.0, 1.2)
		prop(rocks[(i + 2) % 4], o + Vector3(-1.4, -1.0, 0.9), yaw - 30.0, 1.0)
		deco(Vector3(2.7, 0.12, 2.3), o + Vector3(0, -0.35, 0), Color(0.3, 0.45, 0.25), &"leaf", yaw)   # weed line
	# Fishing hut on stilts by the lighthouse rock, with a campfire.
	surface = &"wood"
	var hut := Vector3(-20.5, 0, 15.5)
	block(Vector3(3.2, 0.25, 3.2), hut + Vector3(0, 0.525, 0), WOOD)
	ramp(hut + Vector3(3.1, 0, 0), hut + Vector3(1.6, 0.65, 0), 1.4, OLD_WOOD, 0.2)
	block(Vector3(0.15, 2.2, 3.2), hut + Vector3(-1.55, 1.75, 0), OLD_WOOD)
	block(Vector3(3.2, 2.2, 0.15), hut + Vector3(0, 1.75, 1.55), OLD_WOOD)
	for c: Vector2 in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		deco(Vector3(0.2, 3.4, 0.2), hut + Vector3(c.x, 1.5, c.y), OLD_WOOD.darkened(0.2), &"wood")
	deco(Vector3(3.9, 0.18, 2.2), hut + Vector3(0, 3.35, -0.85), Color(0.72, 0.6, 0.32), &"leaf", 0.0, -22.0)
	deco(Vector3(3.9, 0.18, 2.2), hut + Vector3(0, 3.35, 0.85), Color(0.66, 0.55, 0.3), &"leaf", 0.0, 22.0)
	deco(Vector3(1.2, 0.08, 0.9), hut + Vector3(-0.8, 1.6, -1.2), Color(0.45, 0.4, 0.35), &"wood", 0.0, 0.0, 0.0)   # net shelf
	deco(Vector3(1.4, 1.0, 0.04), hut + Vector3(-1.45, 1.7, -0.5), Color(0.5, 0.48, 0.4), &"wood", 90.0)            # hanging net
	var fire_at := Vector3(-15.5, 0, 13.0)
	for k in 7:
		var a := TAU * float(k) / 7.0
		deco(Vector3(0.3, 0.2, 0.3), fire_at + Vector3(cos(a) * 0.65, 0.1, sin(a) * 0.65), DARK_ROCK, &"rock", rad_to_deg(a))
	deco(Vector3(0.18, 0.18, 1.0), fire_at + Vector3(0, 0.12, 0), OLD_WOOD.darkened(0.3), &"wood", 35.0)
	deco(Vector3(0.18, 0.18, 1.0), fire_at + Vector3(0, 0.18, 0), OLD_WOOD.darkened(0.3), &"wood", -40.0)
	deco(Vector3(0.25, 0.4, 1.8), fire_at + Vector3(1.6, 0.2, 0.3), OLD_WOOD, &"wood", 15.0)   # log bench
	glow_box(Vector3(0.3, 0.2, 0.3), fire_at + Vector3(0, 0.25, 0), Color(1.0, 0.55, 0.15), 1.4)
	var flames := CPUParticles3D.new()
	flames.amount = 14
	flames.lifetime = 0.6
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.2
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.initial_velocity_min = 0.8
	flames.initial_velocity_max = 1.6
	flames.gravity = Vector3(0, 1.5, 0)
	var fm := BoxMesh.new()
	fm.size = Vector3.ONE * 0.16
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.vertex_color_use_as_albedo = true
	fm.material = fmat
	flames.mesh = fm
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3))
	grad.set_color(1, Color(0.9, 0.2, 0.05))
	flames.color_ramp = grad
	flames.position = fire_at + Vector3.UP * 0.3
	add_child(flames)
	# Driftwood, shells, starfish, seaweed.
	for d: Vector4 in [Vector4(-16, 19.0, 2.6, 20), Vector4(12, 18.5, 2.0, -35), Vector4(-21, -2, 2.4, 80), Vector4(21.5, 9, 1.8, 10),
			Vector4(2, -12.5, 1.6, 60)]:
		deco(Vector3(0.32, 0.28, d.z), Vector3(d.x, 0.12, d.y), Color(0.62, 0.55, 0.45), &"wood", d.w, 0.0, 6.0)
		deco(Vector3(0.12, 0.12, 0.6), Vector3(d.x + 0.4, 0.1, d.y + 0.3), Color(0.6, 0.52, 0.42), &"wood", d.w + 50.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 26:
		var p := Vector3(rng.randf_range(-21, 21), 0.03, rng.randf_range(-13, 19.5))
		if absf(p.x - 15) < 4 and p.z < 13 or absf(p.x) < 5 and p.z < -11:
			continue
		var c := [Color(1.0, 0.85, 0.8), Color(0.95, 0.75, 0.6), Color(1.0, 0.95, 0.9)][k % 3] as Color
		if k % 5 == 0:
			deco(Vector3(0.32, 0.04, 0.07), p, Color(1.0, 0.45, 0.2), &"paint", rng.randf() * 180.0)
			deco(Vector3(0.32, 0.04, 0.07), p, Color(1.0, 0.45, 0.2), &"paint", rng.randf() * 180.0)
		else:
			deco(Vector3(0.13, 0.06, 0.1), p, c, &"paint", rng.randf() * 180.0)
	for k in 14:
		var side := -1.0 if k % 2 == 0 else 1.0
		var p := Vector3(side * rng.randf_range(23.0, 29.0), -0.97, rng.randf_range(-26, 20))
		deco(Vector3(rng.randf_range(0.8, 1.6), 0.04, rng.randf_range(0.4, 0.9)), p, Color(0.2, 0.42, 0.22), &"leaf", rng.randf() * 180.0)
	# Grass on the rocks, a few dunes on the sand.
	for k in 40:
		var on_ridge := k < 26
		var p := Vector3(rng.randf_range(-21, 21), 4.5, rng.randf_range(-23.5, -14.5)) if on_ridge \
			else Vector3(rng.randf_range(-21.5, -12.5), 2.5, rng.randf_range(1.5, 10.5))
		if on_ridge and absf(p.x) < 4.5 or not on_ridge and absf(p.x + 17) < 2.2 and absf(p.z - 6) < 2.2:
			continue
		prop(&"grass" if k % 3 else &"grass_dry", p, rng.randf() * 360.0, rng.randf_range(0.8, 1.3))
	# Beach life from Blender: dune grass, starfish, driftwood, bushes by the ridge.
	for k in 26:
		var p := Vector3(rng.randf_range(-20.5, 20.5), 0.0, rng.randf_range(-12.0, 19.0))
		if absf(p.x) < 3.0 and absf(p.z) < 3.0:
			continue
		prop(&"grass_dry" if k % 2 else &"grass", p, rng.randf() * 360.0, rng.randf_range(0.9, 1.4))
	for k in 7:
		prop(&"starfish", Vector3(rng.randf_range(-21.0, 21.0), 0.0, (-13.0 if k % 2 == 0 else 19.5) + rng.randf_range(-1.0, 1.0)), rng.randf() * 360.0)
	for p: Vector3 in [Vector3(-13.5, 0.0, 18.5), Vector3(16.0, 0.0, -12.5), Vector3(3.0, 0.0, 19.5)]:
		prop(&"driftwood", p, rng.randf() * 360.0, 1.1)
	for p: Vector3 in [Vector3(-16.0, 0.0, -12.5), Vector3(-11.0, 0.0, -12.8), Vector3(12.0, 0.0, -12.6), Vector3(19.5, 0.0, -11.0),
			Vector3(-20.0, 0.0, 12.0)]:
		prop(&"bush", p, rng.randf() * 360.0, rng.randf_range(0.9, 1.3))
	for d: Vector4 in [Vector4(-12, -10, 6, 15), Vector4(10, 15, 5, -20), Vector4(-2, 18, 7, 5)]:
		deco(Vector3(d.z, 0.5, d.z * 0.5), Vector3(d.x, -0.17, d.y), SAND.lightened(0.04), &"sand", d.w, 0.0, 2.0)
	# Wreck: ribs out of the sand, portholes, barnacles.
	surface = &"wood"
	for z: float in [12.5, 14.0, 15.5]:
		deco(Vector3(0.25, 2.4, 0.3), Vector3(19.0, 0.9, z), OLD_WOOD.darkened(0.25), &"wood", 0.0, 0.0, -25.0)
		deco(Vector3(0.25, 2.4, 0.3), Vector3(11.0, 0.9, z + 0.3), OLD_WOOD.darkened(0.25), &"wood", 0.0, 0.0, 25.0)
	for z: float in [-1.0, 2.0, 5.0]:
		deco(Vector3(0.06, 0.4, 0.4), Vector3(11.98, 1.3, z), Color(0.12, 0.12, 0.12), &"metal")
		deco(Vector3(0.08, 0.5, 0.5), Vector3(11.97, 1.3, z), Color(0.6, 0.45, 0.2), &"metal", 0.0, 45.0)
		deco(Vector3(0.06, 0.4, 0.4), Vector3(18.02, 1.3, z + 1.0), Color(0.12, 0.12, 0.12), &"metal")
	for k in 10:
		deco(Vector3(0.14, 0.1, 0.14), Vector3(rng.randf_range(12.2, 17.8), rng.randf_range(0.1, 0.6), -3.02),
			Color(0.75, 0.75, 0.7), &"rock", rng.randf() * 90.0)
	# Lighthouse: a door, windows, a railing round the top, a gallery rim.
	surface = &"paint"
	deco(Vector3(1.1, 1.9, 0.06), Vector3(-17, 3.45, 7.82), Color(0.35, 0.22, 0.14), &"wood")
	deco(Vector3(1.3, 0.12, 0.08), Vector3(-17, 4.45, 7.84), Color(0.25, 0.25, 0.28), &"metal")
	for y: float in [5.8, 9.0]:
		deco(Vector3(0.5, 0.7, 0.06), Vector3(-17, y, 7.82), Color(0.15, 0.2, 0.28), &"metal")
		deco(Vector3(0.06, 0.7, 0.5), Vector3(-15.18, y + 1.0, 6), Color(0.15, 0.2, 0.28), &"metal")
	for k in 24:
		var t := float(k) / 24.0 * 4.0
		var e := 3.15
		var p := Vector3(-17, 12.95, 6)
		if t < 1.0:
			p += Vector3(-e + 2.0 * e * t, 0, -e)
		elif t < 2.0:
			p += Vector3(e, 0, -e + 2.0 * e * (t - 1.0))
		elif t < 3.0:
			p += Vector3(e - 2.0 * e * (t - 2.0), 0, e)
		else:
			p += Vector3(-e, 0, e - 2.0 * e * (t - 3.0))
		deco(Vector3(0.06, 0.9, 0.06), p, Color(0.2, 0.2, 0.22), &"metal")
	for r: Vector4 in [Vector4(0, -3.15, 6.4, 0), Vector4(0, 3.15, 6.4, 0), Vector4(-3.15, 0, 6.4, 90), Vector4(3.15, 0, 6.4, 90)]:
		deco(Vector3(r.z, 0.06, 0.06), Vector3(-17 + r.x, 13.4, 6 + r.y), Color(0.2, 0.2, 0.22), &"metal", r.w)
	deco(Vector3(6.8, 0.12, 6.8), Vector3(-17, 12.0, 6), Color(0.85, 0.85, 0.82), &"paint")
	# Pier lamps and a coil of rope.
	surface = &"wood"
	for x: float in [24.0, 32.0]:
		deco(Vector3(0.15, 2.4, 0.15), Vector3(x, 1.8, -9.1), OLD_WOOD, &"wood")
		deco(Vector3(0.5, 0.08, 0.12), Vector3(x, 3.0, -8.9), OLD_WOOD, &"wood", 90.0)
		glow_box(Vector3(0.25, 0.32, 0.25), Vector3(x, 2.8, -8.7), Color(1.0, 0.85, 0.5), 1.2)
	deco(Vector3(0.6, 0.16, 0.6), Vector3(36.6, 0.68, -8.4), Color(0.75, 0.65, 0.45), &"wood", 45.0)
	deco(Vector3(0.4, 0.3, 0.4), Vector3(37.6, 0.75, -5.7), OLD_WOOD.darkened(0.3), &"wood")   # bollard
	surface = &"sand"
	# Far islands on the horizon.
	for h: Vector4 in [Vector4(-130, -80, 40, 14), Vector4(140, 30, 55, 18), Vector4(30, 150, 35, 10), Vector4(-90, 120, 25, 8)]:
		deco(Vector3(h.z, h.w, h.z * 0.7), Vector3(h.x, h.w * 0.5 - 2.0, h.y), Color(0.3, 0.45, 0.32), &"leaf", h.x)
		deco(Vector3(h.z * 0.6, h.w * 0.5, h.z * 0.45), Vector3(h.x + 3, h.w + h.w * 0.2 - 2.0, h.y), Color(0.28, 0.42, 0.3), &"leaf", h.x + 20)
		deco(Vector3(h.z * 1.1, 1.0, h.z * 0.8), Vector3(h.x, -1.2, h.y), SAND, &"sand", h.x)
	_life()


## Things that move: clouds, gulls, bobbing buoys and a rowboat.
func _life() -> void:
	_clouds = Node3D.new()
	var cb := BoxBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 12:
		var c := Vector3(rng.randf_range(-160, 160), rng.randf_range(42, 60), rng.randf_range(-160, 160))
		for puff in 4:
			cb.box(Vector3(rng.randf_range(14, 26), rng.randf_range(4, 7), rng.randf_range(10, 18)),
				c + Vector3(rng.randf_range(-10, 10), rng.randf_range(-1.5, 2), rng.randf_range(-6, 6)), Color(1, 1, 1))
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1, 1, 1, 0.85)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cmi := MeshInstance3D.new()
	cmi.mesh = cb.commit(cm)
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.add_child(cmi)
	add_child(_clouds)
	var gull := BoxBuilder.new()
	gull.box(Vector3(0.18, 0.16, 0.6), Vector3.ZERO, Color(0.95, 0.95, 0.95))
	gull.box(Vector3(0.1, 0.08, 0.16), Vector3(0, 0.05, -0.36), Color(0.95, 0.75, 0.2))
	gull.box(Vector3(0.9, 0.04, 0.26), Vector3(0.5, 0.1, 0.0), Color(0.85, 0.87, 0.9), 0, Basis(Vector3.BACK, 0.35))
	gull.box(Vector3(0.9, 0.04, 0.26), Vector3(-0.5, 0.1, 0.0), Color(0.85, 0.87, 0.9), 0, Basis(Vector3.BACK, -0.35))
	gull.box(Vector3(0.3, 0.03, 0.12), Vector3(0.98, 0.25, 0.0), Color(0.2, 0.2, 0.22), 0, Basis(Vector3.BACK, 0.35))
	gull.box(Vector3(0.3, 0.03, 0.12), Vector3(-0.98, 0.25, 0.0), Color(0.2, 0.2, 0.22), 0, Basis(Vector3.BACK, -0.35))
	var gm := gull.commit(BoxBuilder.vertex_color_material(0.8))
	for k in 3:
		var g := MeshInstance3D.new()
		g.mesh = gm
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		_gulls.append(g)
	var buoy := BoxBuilder.new()
	buoy.box(Vector3(0.7, 0.6, 0.7), Vector3(0, 0.1, 0), Color(0.9, 0.15, 0.1))
	buoy.box(Vector3(0.72, 0.18, 0.72), Vector3(0, 0.25, 0), Color(0.95, 0.95, 0.95))
	buoy.box(Vector3(0.12, 0.8, 0.12), Vector3(0, 0.75, 0), Color(0.3, 0.3, 0.32))
	buoy.box(Vector3(0.2, 0.2, 0.2), Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.3))
	var bm := buoy.commit(BoxBuilder.vertex_color_material(0.6))
	for p: Vector3 in [Vector3(36, 0, -16), Vector3(-36, 0, 6), Vector3(9, 0, 32)]:
		var bn := MeshInstance3D.new()
		bn.mesh = bm
		bn.position = p
		add_child(bn)
		_buoys.append(bn)
	var boat := BoxBuilder.new()
	boat.box(Vector3(1.4, 0.5, 3.4), Vector3(0, 0.1, 0), Color(0.25, 0.5, 0.65))
	boat.box(Vector3(1.5, 0.12, 3.5), Vector3(0, 0.38, 0), Color(0.9, 0.9, 0.85))
	boat.box(Vector3(1.1, 0.3, 3.0), Vector3(0, 0.25, 0), Color(0.5, 0.36, 0.22))
	boat.box(Vector3(1.2, 0.08, 0.3), Vector3(0, 0.36, 0.4), Color(0.45, 0.32, 0.2))
	boat.box(Vector3(0.9, 0.5, 0.8), Vector3(0, 0.2, -1.6), Color(0.25, 0.5, 0.65), 0, Basis(Vector3.UP, PI * 0.25))
	boat.box(Vector3(0.06, 0.06, 1.6), Vector3(0.5, 0.45, 0.6), Color(0.6, 0.48, 0.3), 0, Basis(Vector3.UP, 0.4))
	_boat = MeshInstance3D.new()
	(_boat as MeshInstance3D).mesh = boat.commit(BoxBuilder.vertex_color_material(0.7))
	_boat.position = Vector3(37.0, 0, -3.6)
	add_child(_boat)


func _tick_life(delta: float) -> void:
	_clouds.position.x = fmod(_clouds.position.x + delta * 0.8 + 160.0, 320.0) - 160.0
	for i in _gulls.size():
		var g := _gulls[i]
		var a := _clock_t * (0.32 + 0.07 * float(i)) + float(i) * 2.1
		var r := 16.0 + 6.0 * float(i)
		g.position = Vector3(cos(a) * r - 2.0, 19.0 + 3.0 * float(i) + sin(_clock_t * 0.7 + i) * 1.2, sin(a) * r)
		g.rotation = Vector3(0, -a, 0.35)
		g.scale = Vector3(1.0, 1.0 + 0.25 * sin(_clock_t * 7.0 + i * 1.3), 1.0)
	for i in _buoys.size():
		var b := _buoys[i]
		b.position.y = water_level - 0.15 + sin(_clock_t * 1.6 + i) * 0.12
		b.rotation = Vector3(sin(_clock_t * 1.3 + i) * 0.12, 0, cos(_clock_t * 1.1 + i) * 0.12)
	_boat.position.y = water_level - 0.2 + sin(_clock_t * 1.4) * 0.06
	_boat.rotation = Vector3(sin(_clock_t * 1.2) * 0.04, 0.12, cos(_clock_t * 0.9) * 0.05)


## A palm tree from Blender (Props), with a trunk you bump into.
func _palm(base: Vector3, seed_value: float) -> void:
	var ids: Array[StringName] = [&"palm_a", &"palm_b", &"palm_c"]
	var pick := ids[int(absf(seed_value * 7.0)) % ids.size()]
	prop(pick, base, fmod(seed_value * 37.0, 360.0), 0.95 + fmod(absf(seed_value), 3.0) * 0.06)


## Fins circling in the deep and the shark that strikes.
func _sharks() -> void:
	var fin_mesh := _fin_mesh()
	for path: Vector4 in [Vector4(10, 30, 5.0, 0.5), Vector4(36, 4, 4.0, -0.6), Vector4(-10, -36, 5.0, 0.4), Vector4(-17, 30, 5.0, -0.45)]:
		var f := MeshInstance3D.new()
		f.mesh = fin_mesh
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		_fins.append(f)
		_fin_paths.append(path)
		_fin_hidden.append(0.0)
	_shark = Node3D.new()
	_shark.visible = false
	var mi := MeshInstance3D.new()
	var b := BoxBuilder.new()
	var grey := Color(0.45, 0.5, 0.56)
	b.box(Vector3(1.3, 1.1, 2.6), Vector3(0, 0, 0), grey)
	b.box(Vector3(1.2, 0.45, 1.2), Vector3(0, -0.55, 1.0), Color(0.92, 0.9, 0.86))
	b.box(Vector3(1.25, 0.4, 1.3), Vector3(0, 0.5, 1.05), grey)
	for i in 5:
		var x := -0.5 + i * 0.25
		b.box(Vector3(0.1, 0.18, 0.1), Vector3(x, 0.22, 1.6), Color.WHITE)
		b.box(Vector3(0.1, 0.18, 0.1), Vector3(x, -0.25, 1.55), Color.WHITE)
	b.box(Vector3(0.14, 0.14, 0.14), Vector3(0.55, 0.45, 1.0), Color(0.05, 0.05, 0.05))
	b.box(Vector3(0.14, 0.14, 0.14), Vector3(-0.55, 0.45, 1.0), Color(0.05, 0.05, 0.05))
	b.box(Vector3(0.15, 1.0, 0.8), Vector3(0, 1.0, -0.3), grey)
	mi.mesh = b.commit(BoxBuilder.vertex_color_material(0.5))
	_shark.add_child(mi)
	add_child(_shark)


func _fin_mesh() -> ArrayMesh:
	var b := BoxBuilder.new()
	var c := Color(0.35, 0.4, 0.46)
	b.box(Vector3(0.12, 0.35, 0.9), Vector3(0, 0.17, 0), c)
	b.box(Vector3(0.12, 0.3, 0.6), Vector3(0, 0.5, -0.15), c)
	b.box(Vector3(0.12, 0.25, 0.3), Vector3(0, 0.77, -0.3), c)
	return b.commit(BoxBuilder.vertex_color_material(0.5))


# ------------------------------------------------------------------ rules

## Tide height 0 (low) .. 1 (high) at match time `t` (pure, for tests).
static func tide_at(t: float) -> float:
	if t < TIDE_START:
		return 0.0
	var p := fmod(t - TIDE_START, TIDE_PERIOD)
	if p < TIDE_RISE:
		return smoothstep(0.0, TIDE_RISE, p)
	if p < TIDE_RISE + TIDE_HOLD:
		return 1.0
	if p < TIDE_RISE * 2.0 + TIDE_HOLD:
		return 1.0 - smoothstep(TIDE_RISE + TIDE_HOLD, TIDE_RISE * 2.0 + TIDE_HOLD, p)
	return 0.0


## Wading through water slows you, the deeper the slower.
static func wading_factor(depth: float) -> float:
	if depth <= 0.12:
		return 1.0
	return 1.0 - clampf(depth, 0.0, 0.9) * 0.55


## Past the sand shelf, below the surface: shark water.
func in_deep_water(pos: Vector3) -> bool:
	return pos.y < water_level - 0.6 and not SHELF.has_point(Vector2(pos.x, pos.z))


## Velocity that carries a body from `from` to `to` in `t` seconds under `g`.
static func ballistic(from: Vector3, to: Vector3, t: float, g: float) -> Vector3:
	var v := (to - from) / t
	v.y += 0.5 * g * t
	return v


func speed_factor_at(pos: Vector3) -> float:
	return wading_factor(water_level - pos.y)


## Turtle Rock: a flat-topped rock out west past the sand shelf (sharks all
## round), dry at high tide, with a palm, cover and a weapon spawner.
func _turtle_rock() -> void:
	var was := surface
	surface = &"rock"
	block(Vector3(9, 7, 10), Vector3(-37.5, -2.5, 4), ROCK)
	for p: Vector3 in [Vector3(-42.2, -0.4, 0.5), Vector3(-33.0, -0.6, 8.5), Vector3(-41.5, -0.6, 8.0)]:
		deco(Vector3(2.4, 2.2, 2.6), p, DARK_ROCK, &"rock", p.x * 13.0)
	surface = &"wood"
	breakable(Breakable.Kind.CRATE, Vector3(2, 2, 2), Vector3(-40.5, 2.0, 6.5), Color(0.8, 0.64, 0.4))
	breakable(Breakable.Kind.BARREL, Vector3(0.8, 1.1, 0.8), Vector3(-35.0, 1.55, 0.2), Color(0.85, 0.16, 0.12))
	surface = was
	_palm(Vector3(-40.5, 1.0, 1.0), 9.0)
	bounce_pad(Vector3(-18.0, 0.0, -6.5), Vector3(-36.5, 1.0, 2.5), 3.5)
	bounce_pad(Vector3(-34.5, 1.0, 7.0), Vector3(-17.5, 0.0, 13.5), 3.5, Color(0.3, 0.85, 1.0))
	bounce_pad(Vector3(-6.0, 0.0, -10.0), Vector3(-12.0, 4.5, -18.0), 2.5)
	bounce_pad(Vector3(-3.0, 0.0, 18.5), Vector3(-4.0, 0.1, 30.5), 3.0, Color(0.3, 0.85, 1.0))


func bot_goal(f: Fighter, m: Match) -> Dictionary:
	if f.global_position.y > 10.0:
		return {}
	var on_top := 0
	for o in m.fighters:
		if o != f and o.alive and o.global_position.y > 11.0:
			on_top += 1
	if on_top > 0:
		return {"at": CANNON_BREECH, "score": 0.92}
	return {"at": CANNON_BREECH, "score": 0.72}


func tick(m: Match, delta: float) -> void:
	_clock_t += delta
	var hazards := m.config.hazards
	# Tide.
	tide = tide_at(m.clock) if hazards else 0.0
	water_level = lerpf(TIDE_LOW, TIDE_HIGH, tide)
	_water.position.y = water_level
	_pool.visible = water_level < 0.03
	var phase := 0 if tide <= 0.0 else (1 if tide < 1.0 and fmod(m.clock - TIDE_START, TIDE_PERIOD) < TIDE_RISE else 2)
	if phase != _tide_phase:
		if phase == 1 and _tide_phase == 0:
			notice.emit("THE TIDE IS COMING IN", Color(0.4, 0.9, 1.0), "Get to high ground")
			count("tide")
			Audio.play(&"splash", null, -4.0, 0.6)
		_tide_phase = phase
	super.tick(m, delta)
	# Lighthouse beam, fins, clouds, gulls, buoys.
	_tick_life(delta)
	_beam.rotation.y += delta * 0.7
	for i in _fins.size():
		var fin := _fins[i]
		var path := _fin_paths[i]
		_fin_hidden[i] = maxf(_fin_hidden[i] - delta, 0.0)
		fin.visible = _fin_hidden[i] <= 0.0 and hazards
		var a := _clock_t * path.w + float(i) * 1.7
		fin.position = Vector3(path.x + cos(a) * path.z, water_level - 0.05 + sin(_clock_t * 2.0 + i) * 0.04, path.y + sin(a) * path.z)
		fin.rotation.y = atan2(-sin(a) * signf(path.w), cos(a) * signf(path.w))
	_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(_clock_t * 5.0))
	for f in m.fighters:
		if not f.alive or not m.authority:
			continue
		if hazards and f.swimming and in_deep_water(f.global_position):
			# Sharks circle in, then bite every few seconds.
			var t: float = float(_deep.get(f.fighter_id, 0.0)) + delta
			if t >= SHARK_EVERY:
				t = 0.0
				_shark_attack(m, f)
			_deep[f.fighter_id] = t
			continue
		_deep.erase(f.fighter_id)
		_cannon(m, f, delta)


func swim_exit(pos: Vector3) -> Vector3:
	var p := Vector2(pos.x, pos.z)
	var best := Vector2.INF
	for r: Rect2 in [SHELF.grow(-1.0), ISLET.grow(-1.0), PIER.grow(-0.6)]:
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if p.distance_to(q) < p.distance_to(best):
			best = q
	return Vector3(best.x, water_level, best.y)


func dry_spot(pos: Vector3) -> Vector3:
	if tide <= 0.0:
		return Vector3.INF
	var best := Vector3.INF
	for d in DRY:
		if pos.distance_to(d) < pos.distance_to(best):
			best = d
	return best


func _shark_attack(m: Match, f: Fighter) -> void:
	var at := Vector3(f.global_position.x, water_level, f.global_position.z)
	_credit_water_kill(m, f)
	f.drain(SHARK_BITE, "shark")
	f.velocity += Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	count("shark")
	if m.net:
		m.net.event("shark", [at])
	_shark_show(at)


## The jaws coming up out of the water (on every phone).
func _shark_show(at: Vector3) -> void:
	var nearest := 0
	for i in _fins.size():
		if _fins[i].position.distance_to(at) < _fins[nearest].position.distance_to(at):
			nearest = i
	_fin_hidden[nearest] = 4.0
	Fx.splash(self, at, 1.6)
	Audio.play(&"chomp", at, 2.0)
	Audio.play(&"splash", at, 0.0, 0.8)
	_shark.visible = true
	_shark.position = at + Vector3.DOWN * 2.2
	_shark.rotation = Vector3(deg_to_rad(-35.0), randf() * TAU, 0.0)
	var tw := create_tween()
	tw.tween_property(_shark, "position:y", at.y + 0.4, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.25)
	tw.tween_property(_shark, "position:y", at.y - 2.6, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _shark.visible = false)


## Stand in the breech ring a moment and the cannon fires you at the lighthouse.
func _cannon(m: Match, f: Fighter, delta: float) -> void:
	var p := f.global_position
	var in_ring := Vector2(p.x - CANNON_BREECH.x, p.z - CANNON_BREECH.z).length() < 0.9 \
		and absf(p.y - CANNON_BREECH.y) < 0.4 and f.state == Fighter.State.MOVE
	if not in_ring or m.clock < float(_cannon_cd.get(f.fighter_id, 0.0)):
		_cannon_wait.erase(f.fighter_id)
		return
	var waited: float = _cannon_wait.get(f.fighter_id, 0.0) + delta
	_cannon_wait[f.fighter_id] = waited
	if waited < 0.45:
		if int(waited / delta) % 6 == 0:
			Fx.sparks(self, CANNON_BREECH + Vector3.UP * 0.8, Color(1.0, 0.6, 0.2), 4)
		return
	_cannon_wait.erase(f.fighter_id)
	_cannon_cd[f.fighter_id] = m.clock + 2.5
	f.global_position = CANNON_MUZZLE + Vector3.DOWN * 0.9
	f.rotation.y = atan2(LIGHTHOUSE_TOP.x - CANNON_MUZZLE.x, LIGHTHOUSE_TOP.z - CANNON_MUZZLE.z)
	f.launch(ballistic(f.global_position, LIGHTHOUSE_TOP + Vector3.UP * 0.1, CANNON_FLIGHT, f.gravity), CANNON_FLIGHT + 0.4)
	Audio.play(&"cannon", CANNON_MUZZLE, 2.0, 1.15)
	count("cannon")
	if m.net:
		m.net.event("sound", ["cannon", CANNON_MUZZLE, 2.0, 1.15])
		m.net.event("fx", ["dust", CANNON_MUZZLE, 1.3])
	Fx.dust(self, CANNON_MUZZLE, 1.3)
	Fx.sparks(self, CANNON_MUZZLE, Color(1.0, 0.7, 0.3), 16)
	if f == m.player:
		m.camera.shake(0.4)
		m.hud.callout("FIRE!", Color(1.0, 0.6, 0.2), "", 0.5)
