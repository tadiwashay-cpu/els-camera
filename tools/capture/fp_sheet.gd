extends Node
## Dev: a sheet of the first-person floating weapon (fp_view_model.gd): one
## row per weapon, its rest pose and points through its moves, seen from
## the eye with the game's 90 degree view.
##   xvfb-run -a godot --path . --resolution 800x500 res://tools/capture/fp_sheet.tscn -- OUT.png [weapon,...]

const ROWS := {
	&"sword": [[&"", 0.0], [&"FP_SlashA", 0.30], [&"FP_SlashA", 0.42], [&"FP_SlashA", 0.52], [&"FP_Chop", 0.47], [&"FP_Chop", 0.56], [&"FP_Block", 0.0]],
	&"hammer": [[&"", 0.0], [&"FP_Smash", 0.40], [&"FP_Smash", 0.50], [&"FP_Smash", 0.58], [&"FP_Spin", 0.12], [&"FP_Spin", 0.32], [&"FP_SmashCharge", 0.0]],
	&"spear": [[&"", 0.0], [&"FP_Thrust", 0.30], [&"FP_Thrust", 0.50], [&"FP_Sweep", 0.30], [&"FP_Sweep", 0.45], [&"FP_Sweep", 0.62], [&"FP_Block", 0.0]],
	&"blaster": [[&"", 0.0], [&"FP_Recoil", 0.12], [&"FP_Equip", 0.2], [&"FP_Cast", 0.3], [&"FP_Cast", 0.55], [&"FP_Dip", 0.25], [&"FP_Catch", 0.0]],
	&"plasma_pistols": [[&"", 0.0], [&"FP_Recoil", 0.12], [&"FP_Equip", 0.2], [&"FP_Cast", 0.3], [&"FP_Cast", 0.55], [&"FP_Dip", 0.25], [&"FP_Catch", 0.0]],
	&"bow": [[&"", 0.0], [&"FP_BowDraw", 0.0], [&"FP_BowRelease", 0.12], [&"FP_Cast", 0.3], [&"FP_Cast", 0.55], [&"FP_Dip", 0.25], [&"FP_Equip", 0.2]],
	&"shield": [[&"", 0.0], [&"FP_ShieldBash", 0.30], [&"FP_ShieldBash", 0.48], [&"FP_ShieldBlock", 0.0], [&"FP_ShieldRaise", 0.0], [&"FP_ShieldSlam", 0.2], [&"FP_Parry", 0.1]],
	&"boomerang": [[&"", 0.0], [&"FP_Throw", 0.32], [&"FP_Throw", 0.45], [&"FP_Throw", 0.6], [&"FP_Catch", 0.0], [&"FP_Catch", 0.35], [&"FP_Equip", 0.2]],
	&"rocket_fist": [[&"", 0.0], [&"FP_Throw", 0.32], [&"FP_Throw", 0.45], [&"FP_Stab", 0.48], [&"FP_Catch", 0.0], [&"FP_Cast", 0.55], [&"FP_Equip", 0.2]],
	&"katana": [[&"", 0.0], [&"FP_SlashB", 0.33], [&"FP_SlashB", 0.45], [&"FP_Stab", 0.30], [&"FP_Stab", 0.46], [&"FP_Parry", 0.1], [&"FP_Block", 0.0]],
}
const CELL := Vector2i(400, 250)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var only: Array = []
	if args.size() > 1:
		for id in args[1].split(","):
			only.append(StringName(id))
	get_tree().current_scene = null
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.82, 0.74, 0.55)
	plane.material = gm
	ground.mesh = plane
	add_child(ground)
	for i in 6:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 1.8, 1.2)
		box.mesh = bm
		box.position = Vector3(-6.0 + i * 2.6, 0.9, -7.0 - (i % 3) * 2.0)
		add_child(box)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.7, 0)
	cam.rotation = Vector3(-0.12, 0, 0)
	cam.near = 0.08
	var aspect := float(CELL.x) / float(CELL.y)
	cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(90.0) * 0.5) / aspect))
	add_child(cam)
	cam.current = true
	var vm := FPViewModel.new()
	vm.camera = cam
	cam.add_child(vm)

	var ids: Array = ROWS.keys().filter(func(id: StringName) -> bool: return only.is_empty() or only.has(id))
	var cols := 7
	var sheet := Image.create(CELL.x * cols, CELL.y * ids.size(), false, Image.FORMAT_RGB8)
	for r in ids.size():
		var id: StringName = ids[r]
		var frames: Array = ROWS[id]
		vm.preview_weapon = Registry.weapon(id)
		for c in frames.size():
			vm.preview_move = frames[c][0]
			vm.preview_t = frames[c][1]
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, r * CELL.y))
		print("FP_SHEET ", id)
	sheet.save_png(out)
	print("FP_SHEET saved ", out)
	get_tree().quit()
