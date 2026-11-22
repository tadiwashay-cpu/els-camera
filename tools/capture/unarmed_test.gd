extends Node
func _ready() -> void:
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
	cfg.minutes = 5
	cfg.spawners = false
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.started = true
	for f in m.fighters:
		f.freeze(false)
	m.player_input.enabled = false
	m.brains.clear()
	var a := m.fighters[1]
	a.global_position = Vector3(-24, 0.1, 22)
	await get_tree().create_timer(0.4).timeout
	for phase in ["armed", "throw", "unarmed"]:
		if phase == "throw":
			a.input.aim_yaw = -PI * 0.5
			a.input.move = Vector2(0, 0.8)
			await get_tree().create_timer(0.5).timeout
			a.input.press(&"throw")      # throw while running: upper-body move
			for k in 50:
				await get_tree().physics_frame
				if k % 10 == 0:
					print("  t=", k, " state=", Fighter.State.keys()[a.state], " action=", a.body.action, " upper_active=", a.body.tree.get(&"parameters/upper/active"), " act=", a.body.tree.get(&"parameters/act/current_state"), " loco=", a.body.loco, " armed=", a.armed())
			continue
		a.input.aim_yaw = -PI * 0.5
		a.input.move = Vector2(0, 0.8)
		var samples := []
		for i in 30:
			await get_tree().physics_frame
			if phase == "unarmed" and i % 6 == 0:
				print("  u", i, " v=", a.velocity.snapped(Vector3.ONE * 0.01), " move=", a.input.move, " wm=", a.input.world_move().snapped(Vector3.ONE * 0.01), " floor=", a.is_on_floor(), " pos=", a.global_position.snapped(Vector3.ONE * 0.01), " state=", Fighter.State.keys()[a.state], " dodge_cd=", a._dodge_cd, " attack_down=", a._attack_down_at)
			var lf := a.body.skeleton.get_bone_pose(a.body.skeleton.find_bone(&"LeftUpperLeg"))
			samples.append(lf.basis.get_euler().x)
		var lo: float = samples.min()
		var hi: float = samples.max()
		print(phase, " armed=", a.armed(), " state=", Fighter.State.keys()[a.state], " loco=", a.body.loco, " act=", a.body.tree.get(&"parameters/act/current_state"), " upper_active=", a.body.tree.get(&"parameters/upper/active"), " leg swing range=", snappedf(hi - lo, 0.001), " speed=", snappedf(a.hspeed(), 0.1))
		a.input.move = Vector2.ZERO
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()
