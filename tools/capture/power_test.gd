extends Node
## Dev: a parry, a stomp and Rage, as a strip of frames.
##   xvfb-run godot --path . res://tools/capture/power_test.tscn -- OUT_DIR

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 2
	cfg.minutes = 5
	cfg.spawners = false
	cfg.pickups = false
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
	var b := m.fighters[2]
	m.fighters[0].global_position = Vector3(25, 0.1, 25)
	a.global_position = Vector3(-1.1, 0.1, 14)
	b.global_position = Vector3(1.1, 0.1, 14)
	a.rotation.y = PI * 0.5
	b.rotation.y = -PI * 0.5
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0.5, 2.2, 18.5)
	cam.look_at(Vector3(0, 1.0, 14))
	var strip := Image.create(256 * 6, 192 * 2, false, Image.FORMAT_RGBA8)
	var n := [0]
	var shot := func() -> void:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(256, 192)
		strip.blit_rect(img, Rect2i(0, 0, 256, 192), Vector2i((n[0] % 6) * 256, (n[0] / 6) * 192))
		n[0] += 1
	await get_tree().create_timer(0.4).timeout
	# b swings; a raises the guard just before it lands -> parry
	b.input.attack_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	b.input.attack_held = false
	await get_tree().create_timer(0.06).timeout
	a.input.block_held = true
	for i in 3:
		await get_tree().create_timer(0.12).timeout
		await shot.call()
	a.input.block_held = false
	print("after parry: a.stats=", a.stats, " b.state=", Fighter.State.keys()[b.state])
	await get_tree().create_timer(0.8).timeout
	# a: Shockwave Stomp
	a.powers.power = &"stomp"
	a.powers.meter = FighterPowers.FULL
	a.input.press(&"power")
	for i in 4:
		await get_tree().create_timer(0.14).timeout
		await shot.call()
	print("after stomp: b.state=", Fighter.State.keys()[b.state], " b.hp=", b.health)
	await get_tree().create_timer(2.5).timeout
	# b: Rage (red glow)
	b.global_position = Vector3(1.1, 0.1, 14)
	b.powers.power = &"rage"
	b.powers.meter = FighterPowers.FULL
	b.input.press(&"power")
	for i in 5:
		await get_tree().create_timer(0.16).timeout
		await shot.call()
	print("rage active=", b.powers.has(&"rage"), " aura=", b.body.aura)
	strip.save_png(out + "/power_strip.png")
	get_tree().quit()
