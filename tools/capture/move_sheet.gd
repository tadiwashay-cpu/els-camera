extends SceneTree
## Dev tool: renders a contact sheet of fighter moves (rows = moves,
## columns = evenly spaced frames, two camera angles).
##   xvfb-run godot --path . --script res://tools/capture/move_sheet.gd -- OUT.png Move1,Move2 [columns]

const GLB := "res://assets/fighters/block_fighter.glb"
const CELL := 220

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var names: PackedStringArray = args[1].split(",")
	var cols := int(args[2]) if args.size() > 2 else 6
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.86, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	vp.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4, 4)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.5, 0.45)
	floor_mi.material_override = fm
	vp.add_child(floor_mi)
	var fighter := (load(GLB) as PackedScene).instantiate() as Node3D
	vp.add_child(fighter)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.55, 0.2)
	for mi in fighter.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	# blade marker on the right-hand socket
	var skel := fighter.find_child("*Skeleton*", true, false) as Skeleton3D
	if skel == null:
		skel = fighter.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var att := BoneAttachment3D.new()
	att.bone_name = "WeaponR"
	skel.add_child(att)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.9, 0.02)
	blade.mesh = bm
	blade.position = Vector3(0, 0.45, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.2, 0.25, 0.9)
	blade.material_override = bmat
	att.add_child(blade)
	var anim := fighter.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	cam.fov = 40
	var sheet := Image.create(CELL * cols, CELL * names.size() * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var font_rows := []
	for r in names.size():
		var clip := names[r]
		if not anim.has_animation(clip):
			push_error("missing clip " + clip)
			continue
		var length := anim.get_animation(clip).length
		for view in 2:
			if view == 0:
				cam.position = Vector3(2.6, 1.5, 3.6)   # front three-quarter (fighter faces +Z)
			else:
				cam.position = Vector3(4.4, 1.2, 0.0)   # from the fighter's left side
			cam.look_at_from_position(cam.position, Vector3(0, 0.95, 0))
			for c in cols:
				var t := length * float(c) / float(max(cols - 1, 1))
				anim.play(clip)
				anim.seek(t, true)
				anim.pause()
				for i in 3:
					await process_frame
				var img := vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, (r * 2 + view) * CELL))
		print("row ", r, " ", clip, " len=", length)
	sheet.save_png(out)
	print("saved ", out)
	quit()
