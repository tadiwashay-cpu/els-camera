extends Node
## Dev: a sheet of every weapon model (labelled), and fighters holding a
## few of them in their idle pose, for checking the looks without a device.
##   xvfb-run -a godot --path . --resolution 1800x1100 res://tools/capture/weapon_sheet.tscn -- OUT_DIR

const HOLD := [&"sword", &"shield", &"scythe", &"guitar", &"bazooka", &"sniper", &"plasma_pistols", &"flail",
	&"nunchucks", &"umbrella", &"lance", &"rocket_fist"]


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_COLOR
	env.background_energy_multiplier = 1.0
	env.background_color = Color(0.13, 0.16, 0.22)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var ids: Array = []
	for id: StringName in Registry.weapons.keys():
		if id != &"fists":
			ids.append(String(id))
	ids.sort()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	add_child(cam)
	cam.current = true
	var per_page := 24
	var cols := 8
	for page in int(ceil(ids.size() / float(per_page))):
		for c in get_children():
			if c is MeshInstance3D or c is Label3D:
				c.queue_free()
		for k in per_page:
			var i := page * per_page + k
			if i >= ids.size():
				break
			var w: WeaponData = Registry.weapons[StringName(ids[i])]
			var x := float(k % cols) * 1.0
			var y := -float(k / cols) * 1.6
			var mi := MeshInstance3D.new()
			mi.mesh = w.mesh()
			var aabb := w.mesh().get_aabb()
			var fit := 1.15 / maxf(aabb.size.y, maxf(aabb.size.x, 0.3))
			mi.scale = Vector3.ONE * fit
			mi.position = Vector3(x, y + 0.15, 0) - Vector3(aabb.get_center().x, aabb.get_center().y, 0) * fit
			mi.rotation_degrees = Vector3(0, 18, 0)
			add_child(mi)
			var label := Label3D.new()
			label.text = w.display_name
			label.font_size = 28
			label.pixel_size = 0.004
			label.position = Vector3(x, y - 0.58, 0.3)
			label.modulate = Color(1, 0.85, 0.4) if w.rarity == &"rare" else Color.WHITE
			add_child(label)
		cam.look_at_from_position(Vector3(3.5, -1.45, 10), Vector3(3.5, -1.45, 0))
		for k in 8:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/weapons_sheet%d.png" % page)
		print("SHOT weapons_sheet%d" % page)
	# Fighters holding weapons.
	for c in get_children():
		if c is MeshInstance3D or c is Label3D:
			c.queue_free()
	for i in HOLD.size():
		var w := Registry.weapon(HOLD[i])
		var body := BlockBody.new()
		add_child(body)
		body.setup(Registry.skin(i), false)
		var sockets: Array = [body.socket_l if w.hand == &"left" else body.socket_r]
		if w.both_hands:
			sockets = [body.socket_r, body.socket_l]
		for s: Node3D in sockets:
			var mi := MeshInstance3D.new()
			mi.mesh = w.mesh()
			s.add_child(mi)
		var clip := w.idle_clip if w.idle_clip != &"" else &"Sword_Idle"
		if w.kind == &"melee" and HOLD[i] == &"shield":
			clip = &"Block_Fists"
		body.anim.play(clip)
		body.anim.seek(0.3, true)
		body.anim.pause()
		body.position = Vector3(float(i % 6) * 1.5, -float(i / 6) * 2.6 - 1.0, 0)
		body.rotation_degrees.y = 35
		var label := Label3D.new()
		label.text = w.display_name
		label.font_size = 40
		label.pixel_size = 0.004
		label.position = body.position + Vector3(0, -0.15, 0.4)
		add_child(label)
	cam.size = 6.4
	cam.look_at_from_position(Vector3(3.75, -1.6, 10), Vector3(3.75, -1.6, 0))
	for k in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/weapons_held.png")
	print("SHOT weapons_held")
	get_tree().quit()
