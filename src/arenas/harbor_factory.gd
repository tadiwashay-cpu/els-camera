extends Arena
## Abandoned Harbor Factory: a rusty dockyard at dusk in light rain (doc:
## Arenas). A container maze, a warehouse with catwalks, a cargo ship at the
## quay, broken neon. Water on every side: knock people in.
##   Hazards: a gantry crane's magnet sweeps the yard, grabbing loose metal
##   weapons and anyone holding one; a conveyor feeds a crusher.
##   Signature: stand on the lever pad to take over the crane for 10 s (it
##   hunts your enemies and dunks them); oil spills are slippery and burn
##   when a blast or a blaster bolt hits them.
##   Twists: a floating barge off the east quay, bounce pads onto it, onto the
##   stacked containers and up onto the ship's deck.

const CONCRETE := Color(0.5, 0.5, 0.52)
const DARK := Color(0.22, 0.23, 0.26)
const RUST := Color(0.55, 0.3, 0.18)
const STEEL := Color(0.42, 0.45, 0.5)
const YELLOW := Color(0.95, 0.72, 0.12)
const HULL := Color(0.2, 0.28, 0.4)
const CONTAINER_COLORS: Array[Color] = [Color(0.7, 0.2, 0.15), Color(0.15, 0.38, 0.65), Color(0.2, 0.5, 0.3),
	Color(0.85, 0.45, 0.12), Color(0.55, 0.55, 0.58), Color(0.45, 0.22, 0.5)]

const WATER_Y := -1.6
const MAG_Y := 6.3                 # magnet's bottom
const GANTRY_X := Vector2(-21.0, -1.0)
const TROLLEY_Z := Vector2(-23.0, 3.0)
const DUMP_Z := -21.5              # over the water between the quay and the ship
const GRAB_RADIUS := 2.0
const LEVER := Vector3(16.0, 0.0, -14.5)
const CONTROL_TIME := 10.0
const LEVER_COOLDOWN := 20.0
const BELT := Rect2(10.0, 13.4, 13.0, 2.2)     # x, z, length (+X), width
const BELT_TOP := 0.45
const BELT_SPEED := 2.6
const CRUSH := Rect2(21.0, 13.4, 2.0, 2.2)
const CRUSH_PERIOD := 4.0

var _gx := -11.0
var _tz := -8.0
var _gantry: Node3D
var _trolley: Node3D
var _magnet: Node3D
var _magnet_light: StandardMaterial3D
var _stuck: Array = []                 # [{"data": WeaponData, "mesh": MeshInstance3D, "t": float}]
var _grab_cd: Dictionary = {}          # fighter id -> clock
var controller: Fighter
var _control_until := -1.0
var _lever_ready_at := 0.0
var _lever_wait: Dictionary = {}
var _lever_ring: MeshInstance3D
var _lever_arm: MeshInstance3D
var _hunt: Fighter
var _press: MeshInstance3D
var _press_light: StandardMaterial3D
var _press_t := 0.0
var _slammed := false
var _warned := false
var _belt_crates: Array[Breakable] = []
var _next_crate := 3.0
var oil: Array = []                    # [{"pos", "r", "burn", "gone", "mesh", "fire", "by", "tick"}]
var _neon: Array = []                  # [{"mesh", "base", "broken", "off"}]
var _beacons: Array[MeshInstance3D] = []
var _rain: GPUParticles3D
var _t := 0.0
var _swimmers: Dictionary = {}
## The quay you climb back onto (x0, z0, x1, z1).
const QUAY := Rect2(-28.0, -20.0, 56.0, 44.0)


func build() -> void:
	wet = 0.55
	merge = true
	surface = &"concrete"
	kill_y = -6.0
	bounds = 44.0
	water_level = WATER_Y
	_look()

	# The yard: a concrete quay with water on every side.
	block(Vector3(56, 5, 44), Vector3(0, -2.5, 2), CONCRETE)
	deco(Vector3(56.2, 0.06, 0.4), Vector3(0, 0.03, -19.6), YELLOW, &"paint")
	for x: float in [-22.0, -12.0, -2.0, 14.0, 22.0]:
		deco(Vector3(0.5, 0.6, 0.5), Vector3(x, 0.3, -19.5), DARK, &"metal")
	_curbs()
	_containers()
	_warehouse()
	_ship()
	_crane()
	_lever_booth()
	_conveyor()
	_oil_and_lamps()
	_details()

	# Crates and explosive barrels (some parked next to the oil).
	surface = &"wood"
	for p: Vector3 in [Vector3(13, 1, -17), Vector3(-14, 1, 14), Vector3(20, 1, 19), Vector3(-1, 1, 21)]:
		breakable(Breakable.Kind.CRATE, Vector3(2, 2, 2), p, Color(0.72, 0.58, 0.38))
	for base: Vector3 in [Vector3(2, 0, 13), Vector3(-22, 0, 21), Vector3(24, 0, -6)]:
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(-0.55, 0.5, 0), Color(0.74, 0.6, 0.4))
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(0.55, 0.5, 0.1), Color(0.68, 0.54, 0.36))
		breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), base + Vector3(0.0, 1.5, 0.05), Color(0.72, 0.58, 0.38))
	for p: Vector3 in [Vector3(-14, 0.55, -8.8), Vector3(4.5, 0.55, -6.5), Vector3(15.5, 0.55, 1.5), Vector3(-16, 4.05, -30.5),
			Vector3(24, 0.55, 10.5), Vector3(-24, 0.55, -16)]:
		breakable(Breakable.Kind.BARREL, Vector3(0.8, 1.1, 0.8), p, Color(0.85, 0.16, 0.12))
	surface = &"concrete"

	_barge()

	spawn_points = [Vector3(-8, 0.1, -16), Vector3(10, 0.1, -11), Vector3(-16, 0.1, 0.5), Vector3(0, 0.1, 3),
		Vector3(16, 0.1, 18), Vector3(24, 0.1, 17), Vector3(-20, 0.1, 14), Vector3(2, 0.1, 18),
		Vector3(39, 0.4, 7)]
	spawner_points = [Vector3(-6, 3.5, -27), Vector3(26.5, 3.0, 22.4), Vector3(-7.5, 0.0, -9.5),
		Vector3(9, 0.0, 19), Vector3(-20, 0.0, 18), Vector3(20, 0.0, -16), Vector3(40.5, 0.3, 0.5)]
	pickup_points = [Vector3(-16, 0.0, -16), Vector3(-1, 0.0, -9), Vector3(20, 0.0, 11), Vector3(-12, 3.5, -31),
		Vector3(4, 0.0, 11), Vector3(-23, 0.0, 9)]
	mystery_point = Vector3(6, 3.5, -30)

	var w := water(Vector2(200, 200), Vector3(0, WATER_Y, 0), Color(0.12, 0.2, 0.22, 0.9), Color(0.05, 0.09, 0.12, 0.96))
	var wm := (w.mesh as PlaneMesh).material as ShaderMaterial
	wm.set_shader_parameter(&"shelf", Vector4(1e4, 1e4, 1e4, 1e4))
	wm.set_shader_parameter(&"swell", 0.05)
	_rain_fx()


func _look() -> void:
	var mat := env.sky.sky_material as ProceduralSkyMaterial
	mat.sky_top_color = Color(0.1, 0.1, 0.24)
	mat.sky_horizon_color = Color(0.86, 0.46, 0.32)
	mat.ground_horizon_color = Color(0.42, 0.3, 0.32)
	mat.ground_bottom_color = Color(0.06, 0.07, 0.1)
	mat.sun_angle_max = 30.0
	env.fog_light_color = Color(0.42, 0.36, 0.44)
	env.fog_density = 0.009
	env.ambient_light_energy = 0.65
	env.ambient_light_color = Color(0.55, 0.55, 0.7)
	env.glow_intensity = 0.8
	env.glow_bloom = 0.12
	env.adjustment_saturation = 1.05
	sun.rotation_degrees = Vector3(-16, 62, 0)
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.62, 0.4)


# ------------------------------------------------------------------ layout

## Low curbs along the open quay edges (you can still go over them).
func _curbs() -> void:
	surface = &"paint"
	var c := YELLOW.darkened(0.25)
	block(Vector3(0.4, 0.4, 4.5), Vector3(-27.8, 0.2, -17.75), c)
	block(Vector3(0.4, 0.4, 4.5), Vector3(-27.8, 0.2, 21.75), c)
	block(Vector3(34, 0.4, 0.4), Vector3(-11, 0.2, 23.8), c)
	block(Vector3(0.4, 0.4, 28), Vector3(27.8, 0.2, -6), c)
	surface = &"concrete"


## Shipping containers: a one-high maze under the crane, two-high walls west.
func _containers() -> void:
	surface = &"rust"
	var i := 0
	for c: Vector3 in [Vector3(-19, -12, 0), Vector3(-10, -10, 90), Vector3(-3, -13, 0), Vector3(-21, -2, 90),
			Vector3(-13, -3, 0), Vector3(-4, -4, 90), Vector3(-18, 7.5, 0), Vector3(-8, 8, 0)]:
		_container(Vector3(c.x, 0.0, c.y), c.z, CONTAINER_COLORS[i % CONTAINER_COLORS.size()])
		i += 1
	for z: float in [-12.0, -5.0, 2.0, 9.0, 16.0]:
		_container(Vector3(-26.5, 0.0, z), 90.0, CONTAINER_COLORS[i % CONTAINER_COLORS.size()])
		i += 1
		if int(z) % 2 == 0:
			_container(Vector3(-26.5, 2.6, z), 90.0, CONTAINER_COLORS[(i + 2) % CONTAINER_COLORS.size()])
	surface = &"concrete"


func _container(base: Vector3, yaw: float, color: Color) -> void:
	var size := Vector3(6.1, 2.6, 2.44)
	var centre := base + Vector3.UP * 1.3
	block(size, centre, color, yaw)
	# Corrugation ribs and a door end (looks).
	var basis := Basis.from_euler(Vector3(0, deg_to_rad(yaw), 0))
	for k in 5:
		var off := basis * Vector3(-2.4 + k * 1.2, 0, 0)
		deco(Vector3(0.12, 2.5, 2.5), centre + off, color.darkened(0.18), &"rust", yaw)
	deco(Vector3(0.08, 2.4, 2.3), centre + basis * Vector3(3.07, 0, 0), color.darkened(0.3), &"metal", yaw)


## The warehouse: open roof, a big door, catwalks along two walls.
func _warehouse() -> void:
	surface = &"concrete"
	var wall := Color(0.46, 0.43, 0.42)
	block(Vector3(22, 7, 0.6), Vector3(17, 3.5, 23.7), wall)
	block(Vector3(0.6, 7, 16), Vector3(27.7, 3.5, 16), wall)
	block(Vector3(0.6, 7, 6), Vector3(6.3, 3.5, 11), wall)
	block(Vector3(0.6, 7, 6), Vector3(6.3, 3.5, 21), wall)
	block(Vector3(0.6, 2, 4), Vector3(6.3, 6, 16), wall)
	block(Vector3(6, 7, 0.6), Vector3(9, 3.5, 8.3), wall)
	block(Vector3(6, 7, 0.6), Vector3(25, 3.5, 8.3), wall)
	block(Vector3(10, 2, 0.6), Vector3(17, 6, 8.3), wall)
	deco(Vector3(21.2, 0.04, 15.2), Vector3(17, 0.02, 16), Color(0.36, 0.36, 0.38), &"concrete")
	for z: float in [12.0, 16.0, 20.0]:
		deco(Vector3(22, 0.35, 0.35), Vector3(17, 7.1, z), RUST.darkened(0.2), &"metal")
	# Catwalks (3 m), a stair ramp up, thin rails along the edges.
	surface = &"metal"
	block(Vector3(15, 0.3, 2), Vector3(20, 2.85, 22.4), STEEL)
	block(Vector3(2, 0.3, 12.4), Vector3(26.5, 2.85, 15.2), STEEL)
	ramp(Vector3(6.9, 0.0, 22.4), Vector3(12.5, 3.0, 22.4), 2.0, STEEL.darkened(0.1), 0.3)
	deco(Vector3(15, 0.06, 0.06), Vector3(20, 3.95, 21.42), YELLOW, &"paint")
	deco(Vector3(0.06, 0.06, 12.4), Vector3(25.52, 3.95, 15.2), YELLOW, &"paint")
	for x: float in [13.0, 17.0, 21.0, 25.5]:
		deco(Vector3(0.06, 1.0, 0.06), Vector3(x, 3.45, 21.42), YELLOW, &"paint")
	# Work lights hanging from the trusses.
	for x: float in [11.5, 22.5]:
		glow_box(Vector3(1.6, 0.12, 0.5), Vector3(x, 6.85, 16), Color(0.85, 0.92, 1.0), 1.6)
		var l := OmniLight3D.new()
		l.position = Vector3(x, 6.4, 16)
		l.light_color = Color(0.85, 0.9, 1.0)
		l.light_energy = 1.8
		l.omni_range = 13.0
		add_child(l)
	surface = &"concrete"
	# Broken neon over the door and on the west stack.
	_neon_bar(Vector3(4.6, 0.2, 0.12), Vector3(17, 7.5, 7.9), Color(1.0, 0.2, 0.6), false)
	_neon_bar(Vector3(4.6, 0.2, 0.12), Vector3(17, 8.6, 7.9), Color(1.0, 0.2, 0.6), true)
	_neon_bar(Vector3(0.2, 1.3, 0.12), Vector3(14.8, 8.05, 7.9), Color(1.0, 0.2, 0.6), false)
	_neon_bar(Vector3(0.2, 1.3, 0.12), Vector3(19.2, 8.05, 7.9), Color(1.0, 0.2, 0.6), true)
	_neon_bar(Vector3(2.6, 0.22, 0.12), Vector3(17, 8.05, 7.9), Color(0.2, 0.95, 1.0), true)
	_neon_bar(Vector3(0.14, 3.2, 1.4), Vector3(-25.0, 3.6, 2.0), Color(1.0, 0.85, 0.2), true)


func _neon_bar(size: Vector3, at: Vector3, color: Color, broken: bool) -> void:
	_neon.append({"mesh": glow_box(size, at, color, 2.4), "broken": broken, "off": 0.0})


## The cargo ship at the quay: two gangways up, rails you can smash.
## A rusty barge moored 5 m off the east quay (sprint-jump it, or use the
## pad), with cargo to hide behind; bounce pads up onto the containers and
## the ship.
func _barge() -> void:
	var was := surface
	surface = &"metal"
	block(Vector3(11, 2.2, 16), Vector3(38.5, -0.8, 4), Color(0.46, 0.2, 0.14))
	deco(Vector3(11.3, 1.2, 16.3), Vector3(38.5, -1.4, 4), HULL, &"paint")
	for z: float in [-3.6, 11.6]:
		deco(Vector3(11, 0.5, 0.3), Vector3(38.5, 0.55, z), RUST, &"rust")
	surface = &"wood"
	breakable(Breakable.Kind.CRATE, Vector3(2, 2, 2), Vector3(41.5, 1.3, 9.0), Color(0.72, 0.58, 0.38))
	breakable(Breakable.Kind.CRATE, Vector3(1, 1, 1), Vector3(35.5, 0.8, 9.5), Color(0.74, 0.6, 0.4))
	breakable(Breakable.Kind.BARREL, Vector3(0.8, 1.1, 0.8), Vector3(42.5, 0.85, -1.5), Color(0.85, 0.16, 0.12))
	surface = was
	bounce_pad(Vector3(25.0, 0.0, 1.0), Vector3(37.5, 0.3, 3.0), 3.5)
	bounce_pad(Vector3(35.0, 0.3, -1.5), Vector3(21.0, 0.0, -1.5), 3.5, Color(0.3, 0.85, 1.0))
	bounce_pad(Vector3(-20.0, 0.0, 3.8), Vector3(-26.5, 5.2, 2.0), 2.0)
	bounce_pad(Vector3(1.5, 0.0, -17.5), Vector3(-4.0, 3.6, -27.5), 2.5)


func _ship() -> void:
	surface = &"metal"
	block(Vector3(36, 6, 10), Vector3(-6, 0.5, -28), HULL)
	deco(Vector3(7, 6, 7), Vector3(12, 0.5, -28), HULL, &"metal", 45.0)
	deco(Vector3(36.2, 0.5, 10.2), Vector3(-6, 3.35, -28), Color(0.55, 0.15, 0.12), &"paint")
	deco(Vector3(36.4, 2.0, 10.4), Vector3(-6, -1.7, -28), Color(0.5, 0.12, 0.1), &"paint")
	block(Vector3(6, 5, 8), Vector3(-21, 6, -28), Color(0.85, 0.85, 0.8))
	deco(Vector3(2.2, 3.0, 2.2), Vector3(-21.5, 10.0, -28), Color(0.2, 0.2, 0.22), &"metal")
	for z: float in [-30.0, -28.0, -26.0]:
		glow_box(Vector3(0.1, 0.8, 1.2), Vector3(-17.95, 7.2, z), Color(1.0, 0.85, 0.5), 1.4)
	for x: float in [5.0, 10.0]:
		ramp(Vector3(x, 0.0, -16.5), Vector3(x, 3.5, -23.5), 2.4, STEEL.darkened(0.15), 0.3)
	surface = &"rust"
	_container(Vector3(-12, 3.5, -26), 0.0, CONTAINER_COLORS[1])
	_container(Vector3(-4, 3.5, -31), 0.0, CONTAINER_COLORS[3])
	_container(Vector3(0, 3.5, -28), 90.0, CONTAINER_COLORS[2])
	surface = &"concrete"
	for x: float in [-15.6, -11.0, -6.4, -1.8, 2.8, 7.4]:
		breakable(Breakable.Kind.RAIL, Vector3(4.4, 1.0, 0.25), Vector3(x, 4.0, -32.75), STEEL.lightened(0.1))
	for x: float in [-15.6, -11.0, -6.4, -1.8]:
		breakable(Breakable.Kind.RAIL, Vector3(4.4, 1.0, 0.25), Vector3(x, 4.0, -23.25), STEEL.lightened(0.1))


## The gantry crane: legs on rails across the yard, a beam reaching out over
## the water, a trolley and the magnet.
func _crane() -> void:
	for z: float in [-18.0, 4.0]:
		deco(Vector3(30, 0.08, 0.3), Vector3(-11, 0.04, z), Color(0.3, 0.3, 0.33), &"metal")
	_gantry = Node3D.new()
	add_child(_gantry)
	var b := BoxBuilder.new()
	for z: float in [-18.0, 4.0]:
		for sx: float in [-1.0, 1.0]:
			b.box(Vector3(0.7, 10.4, 0.7), Vector3(sx * 1.4, 5.2, z), YELLOW, 0, Basis(Vector3.BACK, sx * 0.09))
		b.box(Vector3(3.6, 0.6, 1.0), Vector3(0, 0.3, z), YELLOW.darkened(0.3))
		b.box(Vector3(3.6, 0.5, 0.8), Vector3(0, 6.0, z), YELLOW)
	b.box(Vector3(1.4, 1.1, 30.5), Vector3(0, 10.6, -9.25), YELLOW)
	b.box(Vector3(1.6, 0.2, 30.5), Vector3(0, 11.2, -9.25), YELLOW.darkened(0.2))
	b.box(Vector3(2.4, 2.2, 2.6), Vector3(0, 12.2, 3.0), Color(0.3, 0.3, 0.33))
	var gm := MeshInstance3D.new()
	gm.mesh = b.commit(BoxBuilder.vertex_color_material(0.55))
	_gantry.add_child(gm)
	_trolley = Node3D.new()
	add_child(_trolley)
	var tb := BoxBuilder.new()
	tb.box(Vector3(2.0, 0.7, 1.6), Vector3(0, 9.8, 0), DARK)
	tb.box(Vector3(0.08, 9.8 - MAG_Y - 0.6, 0.08), Vector3(0, (9.8 + MAG_Y + 0.6) * 0.5, 0), Color(0.15, 0.15, 0.15))
	var tm := MeshInstance3D.new()
	tm.mesh = tb.commit(BoxBuilder.vertex_color_material(0.6))
	_trolley.add_child(tm)
	_magnet = Node3D.new()
	add_child(_magnet)
	var mb := BoxBuilder.new()
	mb.box(Vector3(2.2, 0.5, 2.2), Vector3(0, 0.25, 0), Color(0.18, 0.18, 0.2))
	mb.box(Vector3(2.3, 0.12, 2.3), Vector3(0, 0.45, 0), YELLOW)
	mb.box(Vector3(0.6, 0.5, 0.6), Vector3(0, 0.75, 0), DARK)
	var mm := MeshInstance3D.new()
	mm.mesh = mb.commit(BoxBuilder.vertex_color_material(0.4))
	_magnet.add_child(mm)
	var light := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.6, 0.06, 1.6)
	_magnet_light = StandardMaterial3D.new()
	_magnet_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_magnet_light.albedo_color = Color(0.4, 0.8, 1.0)
	lm.material = _magnet_light
	light.mesh = lm
	light.position.y = -0.02
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_magnet.add_child(light)
	_place_crane()


func _place_crane() -> void:
	_gantry.position = Vector3(_gx, 0, 0)
	_trolley.position = Vector3(_gx, 0, _tz)
	_magnet.position = Vector3(_gx, MAG_Y, _tz)


## The control booth and its lever pad.
func _lever_booth() -> void:
	surface = &"metal"
	block(Vector3(2.6, 2.8, 2.4), Vector3(LEVER.x, 1.4, LEVER.z - 2.6), Color(0.3, 0.42, 0.5))
	surface = &"concrete"
	glow_box(Vector3(2.0, 0.8, 0.06), Vector3(LEVER.x, 1.9, LEVER.z - 1.38), Color(0.6, 0.9, 1.0), 1.2)
	deco(Vector3(2.8, 0.2, 2.6), Vector3(LEVER.x, 2.9, LEVER.z - 2.6), DARK, &"metal")
	deco(Vector3(0.6, 0.9, 0.4), Vector3(LEVER.x + 0.9, 0.45, LEVER.z - 1.1), DARK, &"metal")
	_lever_arm = MeshInstance3D.new()
	var b := BoxBuilder.new()
	b.box(Vector3(0.1, 0.8, 0.1), Vector3(0, 0.4, 0), Color(0.7, 0.7, 0.72))
	b.box(Vector3(0.22, 0.22, 0.22), Vector3(0, 0.82, 0), Color(0.9, 0.15, 0.1))
	_lever_arm.mesh = b.commit(BoxBuilder.vertex_color_material(0.5))
	_lever_arm.position = Vector3(LEVER.x + 0.9, 0.9, LEVER.z - 1.1)
	_lever_arm.rotation.x = 0.5
	add_child(_lever_arm)
	_lever_ring = _ring_mesh(Color(1.0, 0.8, 0.2, 0.5), 0.85)
	_lever_ring.position = LEVER + Vector3.UP * 0.03
	add_child(_lever_ring)


func _ring_mesh(color: Color, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.03
	cyl.radial_segments = 20
	cyl.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	cyl.material = m
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The conveyor carrying crates (and careless fighters) into the crusher.
func _conveyor() -> void:
	surface = &"metal"
	var c := BELT.get_center()
	block(Vector3(BELT.size.x, BELT_TOP, BELT.size.y), Vector3(c.x, BELT_TOP * 0.5, c.y), DARK)
	for z: float in [BELT.position.y - 0.12, BELT.end.y + 0.12]:
		deco(Vector3(BELT.size.x, 0.3, 0.24), Vector3(c.x, BELT_TOP + 0.05, z), YELLOW, &"paint")
	# Crusher frame and the hopper it dumps into.
	var cc := CRUSH.get_center()
	for z: float in [CRUSH.position.y - 0.55, CRUSH.end.y + 0.55]:
		block(Vector3(0.7, 5.2, 0.7), Vector3(cc.x, 2.6, z), STEEL)
	block(Vector3(2.8, 1.4, 4.0), Vector3(cc.x, 5.6, cc.y), RUST)
	block(Vector3(2.0, 1.6, 3.2), Vector3(CRUSH.end.x + 1.0, 0.8, cc.y), DARK.lightened(0.1))
	surface = &"concrete"
	var belt := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(BELT.size.x, 0.02, BELT.size.y - 0.1)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://src/arenas/fx/belt.gdshader")
	sm.set_shader_parameter(&"speed", BELT_SPEED)
	q.material = sm
	belt.mesh = q
	belt.position = Vector3(c.x, BELT_TOP + 0.005, c.y)
	add_child(belt)
	_press = MeshInstance3D.new()
	var pb := BoxBuilder.new()
	pb.box(Vector3(1.9, 1.3, 2.3), Vector3(0, 0.65, 0), Color(0.35, 0.36, 0.4))
	for k in 4:
		pb.box(Vector3(1.95, 0.12, 0.3), Vector3(0, 0.1, -0.9 + k * 0.6), YELLOW if k % 2 == 0 else DARK)
	_press.mesh = pb.commit(BoxBuilder.vertex_color_material(0.5))
	_press.position = Vector3(cc.x, 3.6, cc.y)
	add_child(_press)
	var lamp := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.4, 0.4, 0.4)
	_press_light = StandardMaterial3D.new()
	_press_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_press_light.albedo_color = Color(0.3, 0.05, 0.05)
	lb.material = _press_light
	lamp.mesh = lb
	lamp.position = Vector3(cc.x - 1.5, 5.8, cc.y)
	add_child(lamp)


## Oil spills (slippery, flammable), yard lamps.
func _oil_and_lamps() -> void:
	var oil_mat := StandardMaterial3D.new()
	oil_mat.albedo_color = Color(0.03, 0.03, 0.04)
	oil_mat.metallic = 0.6
	oil_mat.roughness = 0.04
	for p: Vector4 in [Vector4(-16, 0, -7, 1.8), Vector4(-7, 0, 1.5, 1.6), Vector4(2.5, 0, -8, 1.6), Vector4(13, 0, 3.5, 2.0)]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = p.w
		cyl.bottom_radius = p.w
		cyl.height = 0.02
		cyl.radial_segments = 18
		cyl.rings = 1
		cyl.material = oil_mat
		mi.mesh = cyl
		mi.position = Vector3(p.x, 0.012, p.z)
		mi.scale = Vector3(1.0, 1.0, 0.75)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var fire := CPUParticles3D.new()
		fire.emitting = false
		fire.amount = 40
		fire.lifetime = 0.7
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = p.w * 0.8
		fire.direction = Vector3.UP
		fire.spread = 15.0
		fire.initial_velocity_min = 1.5
		fire.initial_velocity_max = 3.5
		fire.gravity = Vector3(0, 2, 0)
		fire.scale_amount_min = 0.6
		fire.scale_amount_max = 1.4
		var fm := BoxMesh.new()
		fm.size = Vector3.ONE * 0.32
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.vertex_color_use_as_albedo = true
		fm.material = fmat
		fire.mesh = fm
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.9, 0.4))
		grad.set_color(1, Color(0.8, 0.15, 0.05))
		fire.color_ramp = grad
		fire.scale = Vector3(1.0, 1.0, 0.75)
		fire.position = Vector3(p.x, 0.15, p.z)
		add_child(fire)
		oil.append({"pos": Vector3(p.x, 0.0, p.z), "r": p.w, "burn": 0.0, "gone": 0.0, "mesh": mi, "fire": fire, "by": null, "tick": 0.0})
	# Yard lamps: posts with a warm light.
	for p: Vector3 in [Vector3(-12, 0, -18.8), Vector3(8, 0, -18.8), Vector3(3, 0, 6), Vector3(-24, 0, 22)]:
		deco(Vector3(0.25, 6, 0.25), p + Vector3.UP * 3.0, DARK, &"metal")
		deco(Vector3(1.4, 0.15, 0.4), p + Vector3(0.6, 6.0, 0), DARK, &"metal")
		glow_box(Vector3(0.8, 0.12, 0.3), p + Vector3(0.9, 5.9, 0), Color(1.0, 0.8, 0.5), 1.8)
		var l := OmniLight3D.new()
		l.position = p + Vector3(0.9, 5.6, 0)
		l.light_color = Color(1.0, 0.72, 0.45)
		l.light_energy = 1.4
		l.omni_range = 11.0
		add_child(l)


## What makes it a real dock: a city skyline over the water, mooring
## ropes and ladders, pallets, tyres, a forklift, barriers, cones, drums,
## puddles, warehouse windows, racks and pipes, ship railings, a lifeboat,
## portholes and rust. Static boxes merge into a few meshes.
func _details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# City across the bay (north) and the far shore (east): dark silhouettes
	# against the sunset (no fog on them), lit windows.
	var city := BoxBuilder.new()
	for k in 34:
		var north := k < 24
		var w := rng.randf_range(8, 18)
		var h := rng.randf_range(14, 62)
		var c := Vector3(-200 + k * 17.0 + rng.randf_range(-3, 3), h * 0.5 - 2.0, -170 + rng.randf_range(-15, 15)) if north \
			else Vector3(170 + rng.randf_range(-12, 12), h * 0.5 - 2.0, -80 + (k - 24) * 20.0)
		var tint := Color(0.05, 0.05, 0.09).lerp(Color(0.1, 0.09, 0.14), rng.randf())
		city.box(Vector3(w, h, w * 0.8), c, tint)
		for floor_y in range(3, int(h) - 2, 3):
			if rng.randf() < 0.55:
				var lit := Color(1.0, 0.85, 0.55) if rng.randf() < 0.8 else Color(0.6, 0.85, 1.0)
				var face := w * 0.4 + 0.05
				var off := Vector3(0, floor_y - h * 0.5, face * (1 if north else 0))
				if not north:
					off = Vector3(-face, floor_y - h * 0.5, 0)
				var size := Vector3(w * rng.randf_range(0.3, 0.8), 0.6, 0.1) if north else Vector3(0.1, 0.6, w * 0.8 * rng.randf_range(0.3, 0.8))
				glow_static(size, c + off, lit * rng.randf_range(0.5, 0.9))
		if h > 45.0 and rng.randf() < 0.6:
			var beacon := glow_box(Vector3(0.8, 0.8, 0.8), c + Vector3(0, h * 0.5 + 0.6, 0), Color(1.0, 0.15, 0.1), 2.0)
			((beacon.mesh as BoxMesh).material as StandardMaterial3D).disable_fog = true
			_beacons.append(beacon)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.vertex_color_use_as_albedo = true
	cm.disable_fog = true
	var skyline := MeshInstance3D.new()
	skyline.mesh = city.commit(cm)
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skyline)
	# Ladders down the quay walls (where you climb out of the water).
	for l: Vector4 in [Vector4(-18, -20.08, 0, 0), Vector4(0, -20.08, 0, 0), Vector4(20, -20.08, 0, 0),
			Vector4(-28.08, -12, 90, 0), Vector4(-28.08, 21, 90, 0), Vector4(-15, 24.08, 0, 0), Vector4(28.08, -10, 90, 0)]:
		var along := Vector3(1, 0, 0) if l.z == 0 else Vector3(0, 0, 1)
		for sgn: float in [-0.25, 0.25]:
			deco(Vector3(0.06, 2.9, 0.06), Vector3(l.x, -1.05, l.y) + along * sgn, Color(0.25, 0.27, 0.3), &"metal")
		for r in 6:
			deco(Vector3(0.5, 0.05, 0.05) if l.z == 0 else Vector3(0.05, 0.05, 0.5), Vector3(l.x, 0.05 - r * 0.48, l.y), Color(0.25, 0.27, 0.3), &"metal")
	# Mooring ropes from the bollards to the ship, lifebuoys on posts.
	for x: float in [-22.0, -12.0, -2.0]:
		var a := Vector3(x, 0.55, -19.5)
		var b := Vector3(x + 1.5, 3.7, -23.1)
		var d := b - a
		deco(Vector3(0.06, 0.06, d.length()), (a + b) * 0.5, Color(0.7, 0.62, 0.45), &"wood",
			rad_to_deg(atan2(d.x, d.z)), -rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))
	for x: float in [-6.0, 15.0]:
		deco(Vector3(0.12, 1.4, 0.12), Vector3(x, 0.7, -19.6), Color(0.3, 0.3, 0.33), &"metal")
		for k in 4:
			var a := float(k) * 90.0
			deco(Vector3(0.36, 0.1, 0.1), Vector3(x, 1.1, -19.52) + Vector3(cos(deg_to_rad(a)), sin(deg_to_rad(a)), 0) * 0.22,
				Color(1.0, 0.4, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.9), &"paint", 0.0, 0.0, a + 90.0)
	# Yard props you can stand on or hide behind.
	surface = &"metal"
	var fork := Vector3(6.5, 0, 1.0)
	block(Vector3(1.3, 1.2, 2.0), fork + Vector3(0, 0.75, 0), YELLOW.darkened(0.1), 20.0)
	deco(Vector3(1.2, 0.06, 1.0), fork + Vector3(-0.1, 2.3, 0.3), DARK, &"metal", 20.0)
	for c: Vector2 in [Vector2(-0.6, -0.2), Vector2(0.55, -0.6), Vector2(-0.4, 0.8), Vector2(0.7, 0.4)]:
		deco(Vector3(0.06, 1.0, 0.06), fork + Vector3(c.x, 1.8, c.y), DARK, &"metal", 20.0)
	deco(Vector3(0.8, 2.4, 0.12), fork + Vector3(-0.38, 1.2, -1.05), DARK, &"metal", 20.0)
	deco(Vector3(0.12, 0.06, 1.0), fork + Vector3(-0.6, 0.12, -1.5), STEEL, &"metal", 20.0)
	deco(Vector3(0.12, 0.06, 1.0), fork + Vector3(-0.1, 0.12, -1.65), STEEL, &"metal", 20.0)
	for c: Vector2 in [Vector2(-0.65, -0.55), Vector2(0.65, -0.55), Vector2(-0.65, 0.7), Vector2(0.65, 0.7)]:
		deco(Vector3(0.25, 0.5, 0.5), fork + Vector3(c.x, 0.25, c.y), Color(0.1, 0.1, 0.1), &"rust", 20.0)
	surface = &"wood"
	for p: Vector3 in [Vector3(-1.5, 0, 14.0), Vector3(-24.5, 0, -17.0), Vector3(12.0, 0, -12.5)]:
		block(Vector3(1.2, 0.9, 1.0), p + Vector3(0, 0.45, 0), Color(0.62, 0.5, 0.32))
		for k in 6:
			deco(Vector3(1.24, 0.03, 1.04), p + Vector3(0, 0.07 + k * 0.15, 0), Color(0.45, 0.36, 0.22), &"wood")
	surface = &"rust"
	for p: Vector3 in [Vector3(24.0, 0, 2.0), Vector3(-25.0, 0, 13.0)]:
		block(Vector3(1.0, 1.25, 1.0), p + Vector3(0, 0.625, 0), Color(0.1, 0.1, 0.11))
		for k in 5:
			deco(Vector3(1.05, 0.08, 1.05), p + Vector3(0, 0.12 + k * 0.25, 0), Color(0.18, 0.18, 0.19), &"rust", float(k) * 18.0)
		deco(Vector3(0.95, 0.25, 0.95), p + Vector3(1.0, 0.125, 0.4), Color(0.1, 0.1, 0.11), &"rust", 30.0)
	for p: Vector3 in [Vector3(25.5, 0, 6.0), Vector3(26.3, 0, 6.6), Vector3(25.6, 0, 7.3)]:
		block(Vector3(0.7, 1.0, 0.7), p + Vector3(0, 0.5, 0), Color(0.15, 0.35, 0.65))
		deco(Vector3(0.72, 0.06, 0.72), p + Vector3(0, 0.7, 0), Color(0.1, 0.25, 0.5), &"rust")
	surface = &"concrete"
	for b: Vector4 in [Vector4(1.0, -2.5, 20, 0), Vector4(-23.0, -7.5, 90, 0), Vector4(4.0, 21.5, 0, 0)]:
		block(Vector3(3.0, 0.8, 0.6), Vector3(b.x, 0.4, b.y), Color(0.7, 0.7, 0.68), b.z)
		deco(Vector3(3.02, 0.1, 0.62), Vector3(b.x, 0.62, b.y), Color(0.9, 0.3, 0.2), &"paint", b.z)
	for k in 9:
		var p := Vector3(rng.randf_range(-20, 4), 0.0, rng.randf_range(-16, 20))
		if p.distance_to(Vector3(-16, 0, -7)) < 2.5 or p.distance_to(Vector3(-7, 0, 1.5)) < 2.5:
			continue
		deco(Vector3(0.32, 0.06, 0.32), p + Vector3(0, 0.03, 0), Color(0.15, 0.15, 0.15), &"paint")
		deco(Vector3(0.18, 0.5, 0.18), p + Vector3(0, 0.3, 0), Color(1.0, 0.45, 0.1), &"paint")
		deco(Vector3(0.19, 0.08, 0.19), p + Vector3(0, 0.36, 0), Color(0.95, 0.95, 0.95), &"paint")
	# Rain puddles (shiny, not slippery).
	var pb := BoxBuilder.new()
	for k in 10:
		var p := Vector3(rng.randf_range(-24, 26), 0.008, rng.randf_range(-18, 7))
		var r := rng.randf_range(0.6, 1.4)
		pb.box(Vector3(r * 2.0, 0.01, r * 1.4), p, Color(0.2, 0.22, 0.26), 0, Basis(Vector3.UP, rng.randf() * PI))
		pb.box(Vector3(r * 1.4, 0.012, r * 2.0), p, Color(0.2, 0.22, 0.26), 0, Basis(Vector3.UP, rng.randf() * PI))
	var pm := BoxBuilder.vertex_color_material(0.05)
	pm.metallic = 0.5
	var puddles := MeshInstance3D.new()
	puddles.mesh = pb.commit(pm)
	puddles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puddles)
	# Warehouse: corrugated walls, high windows, a rolled-up door, pipes, a rack.
	for x in range(7, 28):
		deco(Vector3(0.12, 6.8, 0.08), Vector3(float(x), 3.4, 24.04), Color(0.4, 0.38, 0.37), &"rust")
	for z in range(9, 24):
		deco(Vector3(0.08, 6.8, 0.12), Vector3(28.04, 3.4, float(z)), Color(0.4, 0.38, 0.37), &"rust")
	for x: float in [9.0, 13.0, 21.0, 25.0]:
		glow_static(Vector3(1.6, 0.7, 0.06), Vector3(x, 5.6, 7.97), Color(0.9, 0.75, 0.45) * 0.7)
	for z: float in [11.0, 15.0, 19.0]:
		glow_static(Vector3(0.06, 0.7, 1.6), Vector3(28.03, 5.6, z), Color(0.9, 0.75, 0.45) * 0.6)
	deco(Vector3(10.2, 0.6, 0.6), Vector3(17, 4.75, 8.3), Color(0.55, 0.5, 0.45), &"rust")
	for k in 9:
		deco(Vector3(10.0, 0.04, 0.05), Vector3(17, 4.45 - k * 0.04, 8.55), Color(0.5, 0.46, 0.42), &"rust")
	for y: float in [5.2, 5.6]:
		deco(Vector3(20.5, 0.18, 0.18), Vector3(17, y, 23.25), Color(0.5, 0.35, 0.25), &"metal")
	deco(Vector3(0.18, 5.6, 0.18), Vector3(7.2, 2.8, 23.25), Color(0.5, 0.35, 0.25), &"metal")
	surface = &"metal"
	block(Vector3(5.0, 2.4, 1.0), Vector3(12.5, 1.2, 19.5), DARK.lightened(0.1))
	for y: float in [0.6, 1.4, 2.2]:
		deco(Vector3(5.1, 0.06, 1.05), Vector3(12.5, y, 19.5), YELLOW.darkened(0.2), &"paint")
	for k in 6:
		deco(Vector3(0.7, 0.55, 0.7), Vector3(10.6 + k * 0.75, 2.68, 19.5), Color(0.72, 0.58, 0.38), &"wood")
	surface = &"concrete"
	for v: Vector3 in [Vector3(12, 7.3, 23.4), Vector3(23, 7.3, 23.4)]:
		deco(Vector3(0.6, 0.6, 0.6), v, Color(0.45, 0.45, 0.48), &"metal")
		var steam := CPUParticles3D.new()
		steam.amount = 10
		steam.lifetime = 2.2
		steam.direction = Vector3.UP
		steam.spread = 10.0
		steam.initial_velocity_min = 0.8
		steam.initial_velocity_max = 1.4
		steam.gravity = Vector3(0.4, 0.2, 0)
		steam.scale_amount_min = 1.0
		steam.scale_amount_max = 2.2
		var sm := BoxMesh.new()
		sm.size = Vector3.ONE * 0.4
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(0.75, 0.75, 0.8, 0.25)
		sm.material = smat
		steam.mesh = sm
		steam.position = v + Vector3.UP * 0.4
		add_child(steam)
	# Ship: railings, portholes, rust streaks, a lifeboat, a mast light, hatches, an anchor.
	for x in range(-17, 12):
		deco(Vector3(0.06, 1.0, 0.06), Vector3(float(x), 4.0, -32.95), Color(0.85, 0.85, 0.82), &"paint")
	for x in range(-17, 3):
		deco(Vector3(0.06, 1.0, 0.06), Vector3(float(x), 4.0, -23.05), Color(0.85, 0.85, 0.82), &"paint")
	for x in range(-22, 11, 2):
		deco(Vector3(0.35, 0.35, 0.04), Vector3(float(x), 1.6, -22.98), Color(0.08, 0.08, 0.1), &"metal")
		if rng.randf() < 0.5:
			deco(Vector3(0.2, rng.randf_range(0.8, 2.0), 0.03), Vector3(float(x) + 0.6, 0.6, -22.97), Color(0.45, 0.25, 0.15), &"rust")
	deco(Vector3(1.4, 0.9, 4.2), Vector3(-21.0, 6.2, -33.0), Color(1.0, 0.45, 0.1), &"paint")
	deco(Vector3(1.5, 0.25, 4.3), Vector3(-21.0, 6.75, -33.0), Color(0.95, 0.95, 0.92), &"paint")
	deco(Vector3(0.15, 5.0, 0.15), Vector3(-20.0, 13.5, -28.0), Color(0.85, 0.85, 0.82), &"paint")
	deco(Vector3(2.0, 0.12, 0.12), Vector3(-20.0, 15.0, -28.0), Color(0.85, 0.85, 0.82), &"paint", 90.0)
	var mast := glow_box(Vector3(0.3, 0.3, 0.3), Vector3(-20.0, 16.1, -28.0), Color(1.0, 0.15, 0.1), 2.0)
	_beacons.append(mast)
	for x: float in [-8.0, 4.0]:
		deco(Vector3(3.0, 0.3, 2.6), Vector3(x, 3.65, -25.0 if x > 0 else -28.0), Color(0.3, 0.32, 0.36), &"metal")
	deco(Vector3(0.5, 1.2, 0.2), Vector3(14.0, 1.2, -23.4), Color(0.2, 0.2, 0.22), &"metal")
	deco(Vector3(1.0, 0.2, 0.2), Vector3(14.0, 0.6, -23.4), Color(0.2, 0.2, 0.22), &"metal")
	for k in 6:
		deco(Vector3(0.12, 0.2, 0.06) if k % 2 == 0 else Vector3(0.06, 0.2, 0.12), Vector3(14.0, 2.0 - k * 0.22, -23.45 + float(k) * 0.05),
			Color(0.25, 0.22, 0.2), &"metal")


func _rain_fx() -> void:
	_rain = GPUParticles3D.new()
	var q := clampi(int(Save.setting("quality")), 0, 2)
	_rain.amount = [250, 450, 700][q]
	_rain.lifetime = 0.8
	_rain.visibility_aabb = AABB(Vector3(-20, -16, -20), Vector3(40, 20, 40))
	_rain.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 0.5, 16)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 24.0
	pm.gravity = Vector3.ZERO
	_rain.process_material = pm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	dm.billboard_keep_scale = true
	drop.material = dm
	_rain.draw_pass_1 = drop
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


# ------------------------------------------------------------------ rules

## Where the magnet wanders when nobody runs the crane (pure, for tests).
static func patrol_at(t: float) -> Vector2:
	var x := lerpf(GANTRY_X.x, GANTRY_X.y, 0.5 + 0.5 * sin(t * 0.13))
	var z := lerpf(TROLLEY_Z.x, TROLLEY_Z.y, 0.5 + 0.5 * sin(t * 0.21 + 1.0))
	return Vector2(x, z)


## Inside an oil spill that is there and not burning.
func oil_at(pos: Vector3) -> Dictionary:
	if absf(pos.y) > 0.4:
		return {}
	for o: Dictionary in oil:
		if float(o["gone"]) > 0.0:
			continue
		var op: Vector3 = o["pos"]
		var d := Vector2(pos.x - op.x, (pos.z - op.z) / 0.75)
		if d.length() < float(o["r"]):
			return o
	return {}


func grip_at(pos: Vector3) -> float:
	var o := oil_at(pos)
	return 0.12 if not o.is_empty() and float(o["burn"]) <= 0.0 else 1.0


func floor_push(pos: Vector3) -> Vector3:
	if pos.y > BELT_TOP - 0.12 and pos.y < BELT_TOP + 0.4 and BELT.has_point(Vector2(pos.x, pos.z)):
		return Vector3(BELT_SPEED, 0, 0)
	return Vector3.ZERO


func ignite(at: Vector3, radius: float, by: Fighter) -> void:
	for o: Dictionary in oil:
		if float(o["gone"]) > 0.0 or float(o["burn"]) > 0.0:
			continue
		var op: Vector3 = o["pos"]
		var d := Vector2(at.x - op.x, at.z - op.z).length()
		if d < radius + float(o["r"]) and absf(at.y - op.y) < 2.5:
			o["burn"] = 8.0
			o["by"] = by
			(o["fire"] as CPUParticles3D).emitting = true
			Audio.play(&"boom", op, -6.0, 1.6)
			Fx.dust(self, op + Vector3.UP * 0.3, 1.2)
			count("fire")


func swim_exit(pos: Vector3) -> Vector3:
	var r := QUAY.grow(-1.0)
	return Vector3(clampf(pos.x, r.position.x, r.end.x), 0.0, clampf(pos.z, r.position.y, r.end.y))


func lever_available(clock: float) -> bool:
	return controller == null and clock >= _lever_ready_at


func bot_goal(f: Fighter, m: Match) -> Dictionary:
	if not m.config.hazards or not lever_available(m.clock):
		return {}
	return {"at": LEVER, "score": 0.8}


func tick(m: Match, delta: float) -> void:
	_t += delta
	super.tick(m, delta)
	if _rain:
		_rain.global_position = m.camera.global_position + Vector3(0, 10, 0)
	for f in m.fighters:
		if f.alive and f.swimming:
			_swimmers[f.fighter_id] = true
		elif _swimmers.has(f.fighter_id):
			_swimmers.erase(f.fighter_id)
			if f.alive:
				count("climbed_out")
	_tick_neon(delta)
	if not m.authority:
		_show_press(m)                  # crane, fires and lever come from the host
		return
	_tick_oil(m, delta)
	_tick_belt(m, delta)
	if m.config.hazards:
		_tick_lever(m, delta)
		_tick_crane(m, delta)


func net_state() -> Array:
	var fires := PackedByteArray()
	for o: Dictionary in oil:
		fires.append((1 if float(o["burn"]) > 0.0 else 0) | (2 if float(o["gone"]) > 0.0 else 0))
	return [_gx, _tz, controller.fighter_id if controller else -1, _press_t, fires, _lever_ring.visible]


func apply_net_state(st: Array) -> void:
	if st.size() < 6:
		return
	_gx = float(st[0])
	_tz = float(st[1])
	_place_crane()
	var ctrl := int(st[2])
	var m := get_parent() as Match
	var f := m.fighter_by_id(ctrl) if m and ctrl >= 0 else null
	if (f != null) != (controller != null):
		Audio.play(&"clunk", LEVER, 0.0, 1.3)
	controller = f
	_magnet_light.albedo_color = f.body.skin.shirt.lightened(0.2) * 1.5 if f else Color(0.4, 0.8, 1.0)
	_lever_arm.rotation.x = -0.5 if f else 0.5
	_press_t = float(st[3])
	var fires: PackedByteArray = st[4]
	for i in mini(fires.size(), oil.size()):
		var o: Dictionary = oil[i]
		var burning := fires[i] & 1 != 0
		var gone := fires[i] & 2 != 0
		var fire := o["fire"] as CPUParticles3D
		if burning and not fire.emitting:
			Audio.play(&"boom", o["pos"], -6.0, 1.6)
		fire.emitting = burning
		(o["mesh"] as MeshInstance3D).visible = not gone
	_lever_ring.visible = bool(st[5])


func _tick_neon(delta: float) -> void:
	for i in _beacons.size():
		_beacons[i].visible = fmod(_t + float(i) * 0.37, 1.6) < 0.5
	for n: Dictionary in _neon:
		var mesh := n["mesh"] as MeshInstance3D
		n["off"] = float(n["off"]) - delta
		if bool(n["broken"]) and randf() < delta * 1.6:
			n["off"] = randf_range(0.04, 0.5)
		mesh.visible = float(n["off"]) <= 0.0


func _tick_oil(m: Match, delta: float) -> void:
	for o: Dictionary in oil:
		var mesh := o["mesh"] as MeshInstance3D
		if float(o["gone"]) > 0.0:
			o["gone"] = float(o["gone"]) - delta
			if float(o["gone"]) <= 0.0:
				mesh.visible = true
				mesh.scale = Vector3(0.05, 1, 0.04)
				create_tween().tween_property(mesh, "scale", Vector3(1, 1, 0.75), 1.5)
			continue
		if float(o["burn"]) <= 0.0:
			continue
		o["burn"] = float(o["burn"]) - delta
		o["tick"] = float(o["tick"]) - delta
		if float(o["tick"]) <= 0.0:
			o["tick"] = 0.5
			var by := o["by"] as Fighter
			if by and not is_instance_valid(by):
				by = null
			var op: Vector3 = o["pos"]
			for f in m.fighters:
				if not f.alive:
					continue
				var p := f.global_position
				var d := Vector2(p.x - op.x, (p.z - op.z) / 0.75)
				if d.length() < float(o["r"]) + 0.3 and absf(p.y) < 1.0:
					var away := Vector3(d.x, 0, d.y).normalized()
					f.take_hit(6.0, away, by if by != f else null, false, p + Vector3.UP, 1.2)
		if float(o["burn"]) <= 0.0:
			(o["fire"] as CPUParticles3D).emitting = false
			mesh.visible = false
			o["gone"] = 25.0


func _tick_belt(m: Match, delta: float) -> void:
	# Crates ride the belt into the press.
	_next_crate -= delta
	_belt_crates = _belt_crates.filter(func(c: Breakable) -> bool: return is_instance_valid(c) and not c.is_broken)
	if _next_crate <= 0.0 and _belt_crates.size() < 3:
		_next_crate = 7.0
		var c := Breakable.new()
		c.rebuilds = false
		c.affects_nav = false
		add_child(c)
		c.setup(Breakable.Kind.CRATE, Vector3(1, 1, 1), Color(0.74, 0.6, 0.4), self)
		c.global_position = Vector3(BELT.position.x + 0.7, BELT_TOP + 0.5, BELT.get_center().y)
		breakables.append(c)
		_belt_crates.append(c)
	for c in _belt_crates:
		c.global_position.x = minf(c.global_position.x + BELT_SPEED * delta, CRUSH.end.x - 0.6)
	# The press: rest, warn, slam, hold, rise.
	_press_t = fmod(_press_t + delta, CRUSH_PERIOD)
	if _show_press(m):
		_slam(m)


## Moves the press and its warning light for `_press_t`; true on the slam.
func _show_press(m: Match) -> bool:
	var y := 3.6
	var warn := _press_t > 2.4 and _press_t < 3.2
	if _press_t < 2.4:
		y = 3.6
	elif _press_t < 3.2:
		y = 3.6 + 0.25 * sin((_press_t - 2.4) / 0.8 * PI)
	elif _press_t < 3.3:
		y = lerpf(3.6, BELT_TOP, (_press_t - 3.2) / 0.1)
	elif _press_t < 3.55:
		y = BELT_TOP
	else:
		y = lerpf(BELT_TOP, 3.6, (_press_t - 3.55) / 0.45)
	_press.position.y = y
	_press_light.albedo_color = Color(1.0, 0.1, 0.05) * (1.6 if int(_press_t * 8.0) % 2 == 0 else 0.3) if warn else Color(0.3, 0.05, 0.05)
	if warn and not _warned:
		_warned = true
		Audio.play(&"alarm", _press.global_position, -10.0)
	elif _press_t < 2.4:
		_warned = false
	if _press_t >= 3.3 and not _slammed:
		_slammed = true
		if not m.authority:
			var at := Vector3(CRUSH.get_center().x, BELT_TOP, CRUSH.get_center().y)
			Audio.play(&"clunk", at, 2.0)
			Fx.dust(self, at + Vector3.UP * 0.2, 1.1)
		return true
	elif _press_t < 3.3:
		_slammed = false
	return false


func _slam(m: Match) -> void:
	var at := Vector3(CRUSH.get_center().x, BELT_TOP, CRUSH.get_center().y)
	Audio.play(&"clunk", at, 2.0)
	Audio.play(&"crash_stone", at, -2.0, 0.7)
	Fx.dust(self, at + Vector3.UP * 0.2, 1.1)
	for c in _belt_crates:
		if is_instance_valid(c) and not c.is_broken and CRUSH.grow(0.2).has_point(Vector2(c.global_position.x, c.global_position.z)):
			c.shatter(Vector3.UP * 2.0)
			count("crushed_crate")
	if not m.config.hazards:
		return
	for f in m.fighters:
		var p := f.global_position
		if f.alive and p.y < 2.0 and CRUSH.grow(0.25).has_point(Vector2(p.x, p.z)):
			m.hazard_kill(f, "crushed", Vector3(0, -2, 0))
			count("crush")
			if m.camera.global_position.distance_to(at) < 20.0:
				m.camera.shake(0.5)


func _tick_lever(m: Match, delta: float) -> void:
	_lever_ring.visible = lever_available(m.clock)
	_lever_arm.rotation.x = lerpf(_lever_arm.rotation.x, -0.5 if controller else 0.5, clampf(delta * 8.0, 0.0, 1.0))
	if controller and (m.clock >= _control_until or not is_instance_valid(controller) or not controller.alive):
		controller = null
		_hunt = null
		_lever_ready_at = m.clock + LEVER_COOLDOWN
		_magnet_light.albedo_color = Color(0.4, 0.8, 1.0)
		for f in m.fighters:
			if f.held():
				f.release()
	if not lever_available(m.clock):
		_lever_wait.clear()
		return
	for f in m.fighters:
		var p := f.global_position
		var on := f.alive and f.state == Fighter.State.MOVE and absf(p.y - LEVER.y) < 0.5 \
			and Vector2(p.x - LEVER.x, p.z - LEVER.z).length() < 0.95
		if not on:
			_lever_wait.erase(f.fighter_id)
			continue
		var w: float = _lever_wait.get(f.fighter_id, 0.0) + delta
		_lever_wait[f.fighter_id] = w
		_lever_ring.scale = Vector3.ONE * (1.0 - clampf(w, 0.0, 0.9) * 0.6)
		if w >= 1.0:
			_take_crane(m, f)
			return
	if _lever_wait.is_empty():
		_lever_ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(_t * 5.0))


func _take_crane(m: Match, f: Fighter) -> void:
	controller = f
	_control_until = m.clock + CONTROL_TIME
	_lever_wait.clear()
	_magnet_light.albedo_color = f.body.skin.shirt.lightened(0.2) * 1.5
	Audio.play(&"clunk", LEVER, 0.0, 1.3)
	Audio.play(&"alarm", null, -6.0, 0.8)
	count("lever")
	f.count("crane")
	if f == m.player:
		notice.emit("THE CRANE IS YOURS", Color(1.0, 0.8, 0.2), "It hunts your enemies for 10 s")
	else:
		notice.emit("%s TOOK THE CRANE" % f.display_name.to_upper(), Color(1.0, 0.55, 0.2), "Run from the magnet!")


func _tick_crane(m: Match, delta: float) -> void:
	var want := patrol_at(_t)
	var speed := 3.0
	var carrying := false
	for f in m.fighters:
		if f.held():
			carrying = true
	if controller:
		speed = 6.5
		if carrying:
			want = Vector2(_gx, DUMP_Z)
		else:
			if _hunt == null or not is_instance_valid(_hunt) or not _hunt.alive or _hunt.held():
				_hunt = _nearest_enemy(m, controller)
			if _hunt:
				want = Vector2(clampf(_hunt.global_position.x, GANTRY_X.x, GANTRY_X.y), clampf(_hunt.global_position.z, TROLLEY_Z.x, TROLLEY_Z.y))
	_gx = move_toward(_gx, clampf(want.x, GANTRY_X.x, GANTRY_X.y), speed * 0.6 * delta)
	_tz = move_toward(_tz, clampf(want.y, TROLLEY_Z.x, TROLLEY_Z.y), speed * delta)
	_place_crane()
	var mpos := _magnet.global_position
	# Over the water with someone on: let go.
	if carrying and _tz < DUMP_Z + 0.6 and _tz > DUMP_Z - 1.0:
		for f in m.fighters:
			if f.held():
				f.release()
				count("drop")
	# Grab.
	for f in m.fighters:
		if not f.alive or f.held() or m.clock < float(_grab_cd.get(f.fighter_id, 0.0)):
			continue
		var p := f.global_position
		var dy := mpos.y - p.y
		if dy < 1.5 or dy > 7.5 or Vector2(p.x - mpos.x, p.z - mpos.z).length() > GRAB_RADIUS:
			continue
		var hunted := controller != null and f != controller
		var magnetic := f.armed() and f.weapon_data.metal
		if not hunted and not magnetic:
			continue
		if f.grab(_magnet, 6.0 if hunted else 2.6, controller if hunted else null):
			_grab_cd[f.fighter_id] = m.clock + 4.0
			Audio.play(&"clunk", mpos, 0.0, 0.9)
			count("grab")
	# Loose metal weapons fly up and stick for a while.
	for item: Variant in m.pickups.duplicate():
		if not is_instance_valid(item) or _stuck.size() >= 4:
			continue
		var pick := item as WeaponPickup
		if pick.spawner >= 0 or not pick.data.metal:
			continue
		var pp := pick.global_position
		if mpos.y - pp.y < 8.0 and Vector2(pp.x - mpos.x, pp.z - mpos.z).length() < GRAB_RADIUS + 0.5:
			_stick(pick.data)
			m.pickups.erase(pick)
			pick.queue_free()
	for s: Dictionary in _stuck.duplicate():
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			_stuck.erase(s)
			(s["mesh"] as Node).queue_free()
			m.drop_pickup(s["data"], mpos + Vector3.DOWN * 0.6, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))


func _stick(data: WeaponData) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = data.mesh()
	mi.rotation = Vector3(PI * 0.5, randf() * TAU, 0)
	mi.position = Vector3(randf_range(-0.6, 0.6), -0.1, randf_range(-0.6, 0.6))
	_magnet.add_child(mi)
	_stuck.append({"data": data, "mesh": mi, "t": 9.0})
	Audio.play(&"clang", _magnet.global_position, -4.0, 1.3)
	count("stuck")


func _nearest_enemy(m: Match, of: Fighter) -> Fighter:
	var best: Fighter
	var best_d := INF
	for f in m.fighters:
		if f == of or not f.alive or f.protect > 0.0:
			continue
		var p := f.global_position
		if p.x < GANTRY_X.x - 3.0 or p.x > GANTRY_X.y + 3.0 or p.z < TROLLEY_Z.x - 3.0 or p.z > TROLLEY_Z.y + 3.0:
			continue
		var d := p.distance_to(of.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best
