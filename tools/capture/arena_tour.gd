extends Node
## Dev: overview shots of an arena from fixed cameras, then a few gameplay
## frames from the player's camera (bots on all sides).
##   xvfb-run -a godot --path . --resolution 1600x1000 res://tools/capture/arena_tour.tscn -- OUT_DIR ARENA_ID [skip_seconds]

const VIEWS := {
	&"beach_island": [
		[Vector3(30, 22, 34), Vector3(-2, 0, 0)],
		[Vector3(24, 6, 2), Vector3(-16, 8, 6)],
		[Vector3(0, 3.5, -4), Vector3(0, 1.5, -18)],
		[Vector3(6, 4, 15), Vector3(-4, 0, 28)],
		[Vector3(14, 4, -14), Vector3(32, 0, -7)],
		[Vector3(-10, 15, 14), Vector3(-15.6, 12, 6)],
		[Vector3(36, 18, 16), Vector3(62, 1, -9)],        # Palm Cove from the pier
		[Vector3(82, 9, 8), Vector3(63, 3, -10)],
		[Vector3(57, 4, -3), Vector3(68, 6, -15)],        # the lookout
	],
	&"harbor_factory": [
		[Vector3(30, 24, 30), Vector3(-4, 0, -4)],
		[Vector3(8, 7, -6), Vector3(-12, 4, -16)],
		[Vector3(10, 5, 4), Vector3(18, 1, 16)],
		[Vector3(-2, 4, -12), Vector3(-6, 4, -28)],
		[Vector3(14, 3, 8), Vector3(22, 0.5, 14.5)],
		[Vector3(2, 9, 10), Vector3(-10, 0, -4)],
		[Vector3(-24, 16, 26), Vector3(-50, 1, 0)],       # West Rail Yard
		[Vector3(-36, 4, -2), Vector3(-60, 3, -6)],
	],
	&"blockout_yard": [
		[Vector3(30, 22, 30), Vector3(0, 0, 0)],
	],
}

var _out := ""


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot_name])
	var vp := get_viewport().get_viewport_rid()
	print("SHOT %s draws=%d tris=%d" % [shot_name,
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var arena_id := StringName(args[1]) if args.size() > 1 else &"beach_island"
	var skip := float(args[2]) if args.size() > 2 else 0.0
	get_tree().current_scene = null
	Save.set_setting("show_fps", true)
	Save.set_setting("touch_on_desktop", true)
	var cfg := MatchConfig.new()
	cfg.minutes = 3.0
	cfg.bots = 3
	cfg.difficulty = 2
	cfg.seed = 5
	cfg.arena_id = arena_id
	cfg.arena_choice = arena_id
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.begin()
	while not m.started:
		await get_tree().process_frame
	m.clock += skip
	var brain := AIBrain.new(m.player, m, 2)
	m.player_input.enabled = false
	m.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.current = true
	var i := 0
	for v: Array in VIEWS.get(arena_id, []):
		cam.look_at_from_position(v[0], v[1])
		for k in 20:
			await get_tree().physics_frame
			brain.update(get_physics_process_delta_time())
		await _shot("%s_view%d" % [arena_id, i])
		i += 1
	m.hud.visible = true
	m.camera.camera.current = true
	var t := 0.0
	var shots := [3.0, 9.0, 16.0]
	while t < 18.0 and not m.ended:
		await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		if not get_tree().paused:
			t += d
			brain.update(d)
		if not shots.is_empty() and t >= shots[0]:
			shots.pop_front()
			await _shot("%s_play%d" % [arena_id, 3 - shots.size()])
	print("TOUR stats=", m.arena.stats)
	get_tree().quit()
