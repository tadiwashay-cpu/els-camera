extends Node
## Dev: knocks a fighter down (ragdoll -> get up) and kills another, and
## saves a strip of frames of each.
##   xvfb-run godot --path . res://tools/capture/ragdoll_test.tscn -- OUT_DIR

var _out := ""


func _ready() -> void:
	_out = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
	cfg.minutes = 5
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.hud.visible = false
	m.started = true
	var a := m.fighters[0]
	var b := m.fighters[1]
	for f in m.fighters:
		f.freeze(false)
	m.player_input.enabled = false
	a.global_position = Vector3(-4, 0.1, 12)
	b.global_position = Vector3(4, 0.1, 12)
	a.rotation.y = PI * 0.5
	b.rotation.y = -PI * 0.5
	m.brains.clear()
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 50
	await get_tree().create_timer(0.5).timeout
	# a (the player) is knocked down and gets up; b (a bot) is killed.
	a.take_hit(20.0, Vector3(-1, 0, 0), b, true, a.global_position + Vector3.UP * 1.3, 6.0)
	b.die(a, Vector3(7, 4, 0), b.global_position + Vector3.UP * 1.3)
	var strip := Image.create(320 * 8, 480, false, Image.FORMAT_RGBA8)
	var times := [0.05, 0.25, 0.5, 0.8, 1.2, 1.6, 2.0, 2.6]
	var t0 := Time.get_ticks_msec()
	for i in times.size():
		while Time.get_ticks_msec() - t0 < int(times[i] * 1000.0):
			await get_tree().process_frame
		var was := get_tree().paused
		get_tree().paused = true
		for row in 2:
			var f := a if row == 0 else b
			var c := f.ragdoll.hips_position() if f.state != Fighter.State.GETUP and f.state != Fighter.State.MOVE else f.global_position + Vector3.UP * 0.8
			cam.global_position = c + Vector3(0, 1.4, 3.2)
			cam.look_at(c)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(320, 240)
			strip.blit_rect(img, Rect2i(0, 0, 320, 240), Vector2i(i * 320, row * 240))
		get_tree().paused = was
		print("t=", times[i], " a.state=", Fighter.State.keys()[a.state], " b.hips=", b.ragdoll.hips_position().snapped(Vector3.ONE * 0.01), " a.hips=", a.ragdoll.hips_position().snapped(Vector3.ONE * 0.01))
	strip.save_png(_out + "/ragdoll_strip.png")
	get_tree().quit()
