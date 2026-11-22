extends Node
## Dev: renders the app icon (512 px) and boot splash from a block fighter.
##   xvfb-run godot --path . --resolution 1024x1024 res://tools/capture/icon_render.tscn

func _ready() -> void:
	get_tree().current_scene = null
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_CLEAR_COLOR
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.55, 0.55, 0.62)
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 35, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.2, -1.2)
	rim.light_color = Color(1.0, 0.6, 0.25)
	rim.light_energy = 3.0
	rim.omni_range = 5.0
	vp.add_child(rim)
	var body := BlockBody.new()
	vp.add_child(body)
	body.setup(Registry.skin(0), false)
	var w := MeshInstance3D.new()
	w.mesh = Registry.weapon(&"sword").mesh()
	body.socket_r.add_child(w)
	body.anim.play(&"Victory")
	body.anim.seek(0.5, true)
	body.anim.pause()
	body.rotation_degrees.y = 18
	var cam := Camera3D.new()
	cam.fov = 34
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.55, 1.95, 2.3), Vector3(-0.05, 1.62, 0))
	cam.current = true
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var icon := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	icon.fill(Color(1.0, 0.56, 0.14))
	for y in 1024:          # soft vertical gradient behind the fighter
		var c := Color(1.0, 0.62, 0.18).lerp(Color(0.86, 0.32, 0.08), float(y) / 1023.0)
		icon.fill_rect(Rect2i(0, y, 1024, 1), c)
	icon.blend_rect(img, Rect2i(0, 0, 1024, 1024), Vector2i.ZERO)
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	icon.save_png("res://assets/ui/icon.png")
	var splash := img.duplicate() as Image
	splash.resize(640, 640, Image.INTERPOLATE_LANCZOS)
	splash.save_png("res://assets/ui/splash.png")
	print("ICON saved")
	get_tree().quit()
