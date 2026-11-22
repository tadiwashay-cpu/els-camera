extends Node
## Dev: a fighter jumps, double-jumps, then drops off the 5 m tower (hard
## landing); saves a strip of frames and the animation states.
##   xvfb-run godot --path . res://tools/capture/jump_test.tscn -- OUT_DIR

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
	cfg.minutes = 5
	cfg.spawners = false
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.hud.visible = false
	m.started = true
	for f in m.fighters:
		f.freeze(false)
	m.brains.clear()
	m.player_input.enabled = false
	var a := m.fighters[1]
	m.fighters[0].global_position = Vector3(25, 0.1, 25)
	a.global_position = Vector3(-8, 0.1, 22)
	a.rotation.y = PI * 0.5
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 55
	var strip := Image.create(240 * 8, 240 * 2, false, Image.FORMAT_RGBA8)
	var shots := 0
	var script := [[0.3, "jump"], [0.55, "jump"], [2.2, "tower"], [2.6, "walk_off"]]
	var t := 0.0
	var next_shot := 0.15
	while shots < 16:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not script.is_empty() and t >= float(script[0][0]):
			var cmd: String = script.pop_front()[1]
			match cmd:
				"jump":
					a.input.press(&"jump")
				"tower":
					a.global_position = Vector3(0, 5.1, 0)
					a.velocity = Vector3.ZERO
				"walk_off":
					a.input.aim_yaw = -PI * 0.5
					a.input.move = Vector2(0, 0.6)
		if a.global_position.x > 4.5:
			a.input.move = Vector2.ZERO
		if t >= next_shot:
			next_shot += 0.16 if t < 1.4 else 0.13
			var p := a.global_position
			cam.global_position = p + Vector3(0.5, 1.6, 4.2)
			cam.look_at(p + Vector3.UP * 1.0)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(240, 240)
			strip.blit_rect(img, Rect2i(0, 0, 240, 240), Vector2i((shots % 8) * 240, (shots / 8) * 240))
			print(shots, " t=", snappedf(t, 0.01), " state=", Fighter.State.keys()[a.state], " loco=", a.body.loco, " act=", a.body.tree.get(&"parameters/act/current_state"), " vy=", snappedf(a.velocity.y, 0.1), " y=", snappedf(a.global_position.y, 0.01))
			shots += 1
	strip.save_png(out + "/jump_strip.png")
	get_tree().quit()
