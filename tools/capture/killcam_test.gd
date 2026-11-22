extends Node
## Dev: a bot kills the player; saves frames of the killcam replay.
##   xvfb-run godot --path . res://tools/capture/killcam_test.tscn -- OUT_DIR

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
	cfg.minutes = 5
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.started = true
	var a := m.fighters[0]
	var b := m.fighters[1]
	for f in m.fighters:
		f.freeze(false)
	m.player_input.enabled = false
	m.brains.clear()
	a.global_position = Vector3(-1.2, 0.1, 12)
	b.global_position = Vector3(1.2, 0.1, 12)
	a.rotation.y = PI * 0.5
	b.rotation.y = -PI * 0.5
	a.health = 1
	await get_tree().create_timer(0.6).timeout
	var tries := 0
	while not m.killcam.playing and tries < 12:
		tries += 1
		b.input.attack_held = true
		await get_tree().physics_frame
		await get_tree().physics_frame
		b.input.attack_held = false
		await get_tree().create_timer(0.5, true, false, true).timeout
		print("try ", tries, " a.alive=", a.alive, " b.state=", Fighter.State.keys()[b.state], " d=", a.global_position.distance_to(b.global_position))
	if not m.killcam.playing:
		get_tree().quit()
		return
	var strip := Image.create(320 * 6, 240, false, Image.FORMAT_RGBA8)
	for i in 6:
		await get_tree().create_timer(0.38, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(320, 240)
		strip.blit_rect(img, Rect2i(0, 0, 320, 240), Vector2i(i * 320, 0))
		var g: BlockBody = m.killcam._ghosts[0]["body"]
		print("i=", i, " t=", snappedf(m.killcam._t, 0.01), " ghost0 hips=", g.bone_position(&"Hips").snapped(Vector3.ONE * 0.01), " cam=", m.killcam._cam.global_position.snapped(Vector3.ONE * 0.1), " visible=", g.visible)
	strip.save_png(out + "/killcam_strip.png")
	get_tree().quit()
