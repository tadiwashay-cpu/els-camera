extends Node
## Dev: screenshots of the title, the loading screen and a live match
## (bots on both sides), for checking the look without a device.
##   xvfb-run godot --path . res://tools/capture/shots.tscn -- OUT_DIR

var _out := ""


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot_name])
	print("SHOT ", shot_name)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	_out = OS.get_cmdline_user_args()[0]
	# Survive scene changes: the loading screen frees the current scene.
	get_tree().current_scene = null
	Save.set_setting("show_fps", true)
	Save.set_setting("touch_on_desktop", true)
	var title := (load(Game.TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await _wait(1.0)
	await _shot("01_title")
	title.queue_free()
	var cfg := MatchConfig.new()
	cfg.minutes = 1.0
	cfg.bots = 2
	cfg.difficulty = 2
	cfg.seed = 3
	Game.match_config = cfg
	Game.start_match()
	await _wait(0.35)
	await _shot("02_loading")
	while get_tree().current_scene == null or not (get_tree().current_scene is Match):
		await get_tree().process_frame
	var m := get_tree().current_scene as Match
	while not m.started:
		await get_tree().process_frame
	var brain := AIBrain.new(m.player, m, 2)
	m.player_input.enabled = false
	var t := 0.0
	var shots := [2.0, 6.0, 11.0, 17.0, 24.0]
	var n := 3
	while not m.ended and t < 40.0:
		await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		if not get_tree().paused:
			t += d / maxf(Engine.time_scale, 0.02)
			brain.update(d)
		if not shots.is_empty() and t >= shots[0]:
			shots.pop_front()
			await _shot("%02d_match" % n)
			n += 1
		if m.killcam.playing and n < 20:
			await _wait(0.4)
			await _shot("%02d_killcam" % n)
			n += 1
			while m.killcam.playing:
				await get_tree().process_frame
	await _wait(0.5)
	get_tree().quit()
