extends Node
## Dev: wall slams (Fighter._wall_slam). A bot on Harbor Factory is knocked
## at a shipping container, lightly (a stagger) and hard (knocked flat),
## and the slams, damage and states are logged; a frame of each is saved.
##   xvfb-run -a godot --path . res://tools/capture/slam_test.tscn -- OUT_DIR

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
	cfg.minutes = 5
	cfg.spawners = false
	cfg.pickups = false
	cfg.arena_id = &"harbor_factory"
	cfg.arena_choice = &"harbor_factory"
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.started = true
	for f in m.fighters:
		f.freeze(false)
	m.brains.clear()
	m.player_input.enabled = false
	var hitter := m.fighters[0]
	var victim := m.fighters[1]
	hitter.respawn(Vector3(-11.0, 0.1, -2.0), PI * 0.5)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(-15.0, 4.0, 6.0)
	cam.look_at(Vector3(-19.0, 1.0, -2.0))
	cam.current = true
	# The container at (-21, -2) turned 90 degrees: its east face is at x = -19.78.
	for case: Vector3 in [Vector3(9.0, 0.0, -15.0), Vector3(12.0, 0.0, -17.5), Vector3(16.0, 1.0, -15.0)]:
		var knock := case.x
		victim.respawn(Vector3(case.z, 0.1, -2.0), PI * 0.5)
		victim.protect = 0.0
		victim.invuln = 0.0
		await get_tree().create_timer(0.4).timeout
		var hp0 := victim.health
		var slams0 := int(victim.stats.get("wall_slams", 0))
		victim.take_hit(4.0, Vector3.LEFT, hitter, case.y > 0.5, victim.global_position + Vector3.UP, knock)
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("%s/slam_%d.png" % [out, int(knock)])
		await get_tree().create_timer(0.9).timeout
		print("SLAM knock=%.0f heavy=%s from %.1f m: slams=%d damage=%.1f state=%s" % [knock, case.y > 0.5, case.z + 19.78,
			int(victim.stats.get("wall_slams", 0)) - slams0, hp0 - victim.health, Fighter.State.keys()[victim.state]])
	get_tree().quit()
