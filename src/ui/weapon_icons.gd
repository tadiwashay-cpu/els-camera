class_name WeaponIcons
extends SubViewport
## Weapon icons for the Armory, drawn from the real models: every weapon is
## rendered once, in one frame, into a grid (an atlas); each icon is a
## region of it. The viewport frees itself when the picture is taken.
## Headless runs get no picture: icon() then returns null.

signal finished

const CELL := 128
const COLS := 8

static var _atlas: ImageTexture
static var _cells: Dictionary = {}       # weapon id -> cell index


static func icon(id: StringName) -> Texture2D:
	if _atlas == null or not _cells.has(id):
		return null
	var i: int = _cells[id]
	var t := AtlasTexture.new()
	t.atlas = _atlas
	t.region = Rect2((i % COLS) * CELL, (i / COLS) * CELL, CELL, CELL)
	return t


static func ready_now() -> bool:
	return _atlas != null


## Adds the renderer under `parent` (if the icons aren't drawn yet).
static func ensure(parent: Node) -> WeaponIcons:
	if _atlas != null or DisplayServer.get_name() == "headless":
		return null
	var v := WeaponIcons.new()
	parent.add_child(v)
	return v


func _ready() -> void:
	var ids: Array = []
	for id: StringName in Registry.weapons.keys():
		var w: WeaponData = Registry.weapons[id]
		if not w.is_fists() and w.mesh() and w.mesh().get_aabb().size.length() > 0.01:
			ids.append(id)
	ids.sort()
	var rows := int(ceil(ids.size() / float(COLS)))
	size = Vector2i(COLS * CELL, rows * CELL)
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.74, 0.82)
	env.ambient_light_energy = 1.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 2.0
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 1.0
	rim.light_color = Color(0.7, 0.8, 1.0)
	add_child(rim)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(rows)
	cam.position = Vector3(COLS * 0.5, -rows * 0.5, 10.0)
	add_child(cam)
	cam.current = true
	for i in ids.size():
		var w: WeaponData = Registry.weapons[ids[i]]
		var mi := MeshInstance3D.new()
		mi.mesh = w.mesh()
		# Diagonal, turned a little towards the light, sized to the cell.
		var basis := Basis.from_euler(Vector3(deg_to_rad(10), deg_to_rad(-25), deg_to_rad(-42)))
		var box := Transform3D(basis, Vector3.ZERO) * w.mesh().get_aabb()
		var fit := 0.8 / maxf(maxf(box.size.x, box.size.y), 0.25)
		var centre := Vector3(i % COLS + 0.5, -(i / COLS + 0.5), 0.0)
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * fit), centre - Vector3(box.get_center().x, box.get_center().y, 0.0) * fit)
		add_child(mi)
		_cells[ids[i]] = i
	_capture.call_deferred()


func _capture() -> void:
	for k in 3:
		await RenderingServer.frame_post_draw
	var img := get_texture().get_image()
	if img and not img.is_empty():
		img.generate_mipmaps()
		_atlas = ImageTexture.create_from_image(img)
	finished.emit()
	queue_free()
