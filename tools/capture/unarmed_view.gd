extends Node
## Dev: everyone starts unarmed; follows one bot and saves a strip of frames
## plus its state, to check unarmed movement and animation.
##   xvfb-run godot --path . res://tools/capture/unarmed_view.tscn -- OUT_DIR

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
	cfg.minutes = 5
	cfg.start_weapon = &"fists"
	cfg.spawners = false
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.hud.visible = false
	m.begin()
	while not m.started:
		await get_tree().process_frame
	var brain := AIBrain.new(m.player, m, 1)
	m.player_input.enabled = false
	var b := m.fighters[1]
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var strip := Image.create(256 * 8, 256 * 2, false, Image.FORMAT_RGBA8)
	var n := 0
	var t := 0.0
	while n < 16:
		await get_tree().physics_frame
		brain.update(get_physics_process_delta_time())
		t += get_physics_process_delta_time()
		var p := b.global_position
		cam.global_position = p + Vector3(2.6, 1.8, 2.6)
		cam.look_at(p + Vector3.UP)
		if t > 0.35:
			t = 0.0
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(256, 256)
			strip.blit_rect(img, Rect2i(0, 0, 256, 256), Vector2i((n % 8) * 256, (n / 8) * 256))
			print(n, " state=", Fighter.State.keys()[b.state], " action=", b.body.action, " act=", b.body.tree.get(&"parameters/act/current_state"), " loco=", b.body.loco, " hs=", snappedf(b.hspeed(), 0.1), " goal=", m.brains[0].goal)
			n += 1
	strip.save_png(out + "/unarmed_strip.png")
	get_tree().quit()
