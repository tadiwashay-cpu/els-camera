extends Node
## Dev: every face, hair style and hat (Look) on a row of heads, for
## checking the parts without a device.
##   xvfb-run -a godot --path . --resolution 1800x900 res://tools/capture/look_sheet.tscn -- OUT.png


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	add_child(sun)
	var rows: Array = [[&"face", Look.FACES.keys()], [&"hair", Look.HAIR.keys()], [&"hat", Look.HATS.keys()]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for r in rows.size():
		var kind: StringName = rows[r][0]
		var ids: Array = rows[r][1]
		for i in ids.size():
			var look := Look.DEFAULT.duplicate()
			look["hair"] = "short"
			look["hair_color"] = (i + r * 3) % Look.HAIR_COLORS.size()
			look["hat_color"] = (i * 3 + 1) % Look.CLOTH.size()
			look["shirt"] = (i * 2 + r) % Look.CLOTH.size()
			look[String(kind)] = String(ids[i])
			var b := BlockBody.new()
			add_child(b)
			b.setup(Look.skin_data(look), false)
			b.anim.play(&"Idle")
			b.anim.seek(0.0, true)
			b.anim.pause()
			b.position = Vector3(float(i) * 0.75, -float(r) * 0.9, 0.0)
			b.rotation.y = 0.45 if r == 1 else 0.25
			var l := Label3D.new()
			l.text = String(ids[i])
			l.font_size = 40
			l.pixel_size = 0.003
			l.position = b.position + Vector3(0, 1.2, 0.3)
			add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2
	cam.position = Vector3(2.25, 1.7 - 0.9, 5.0)
	add_child(cam)
	cam.current = true
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("LOOK_SHEET saved ", out)
	get_tree().quit()
