extends Node3D
## Dev: every Blender prop (Props) in a row, lit like Beach Island, seen
## from the side and from below (fronds), for checking without a device.
##   xvfb-run -a godot --path . --resolution 1600x700 res://tools/capture/prop_sheet.tscn -- OUT.png [low]

func _ready() -> void:
	var low := OS.get_cmdline_user_args().has("low")
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.16, 0.45, 0.9)
	sm.sky_horizon_color = Color(0.62, 0.85, 0.95)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-64, -30, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 30)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.93, 0.84, 0.62)
	pm.material = gm
	ground.mesh = pm
	add_child(ground)
	var ids: Array = Props.INFO.keys()
	for i in ids.size():
		var mi := MeshInstance3D.new()
		mi.mesh = Props.mesh(ids[i])
		mi.material_override = Props.material(ids[i])
		mi.position = Vector3(-24.0 + i * 4.4, 0, 0)
		var big: bool = String(ids[i]).begins_with("grass") or ids[i] == &"starfish"
		mi.scale = Vector3.ONE * (3.0 if big else 1.0)
		add_child(mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0 if low else 4.0, 26)
	add_child(cam)
	cam.look_at(Vector3(0, 4.0 if low else 2.0, 0))
	cam.fov = 50
	cam.current = true
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
