extends Node
## Dev: smash scenery and save frames: a slash into a crate stack, a thrown
## sword into a barrel next to a bot, a bot knocked into a railing.
##   xvfb-run godot --path . res://tools/capture/break_test.tscn -- OUT_DIR

var _m: Match
var _cam: Camera3D
var _strip: Image
var _n := 0


func _shot(focus: Vector3, from: Vector3) -> void:
	_cam.global_position = focus + from
	_cam.look_at(focus)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(256, 192)
	_strip.blit_rect(img, Rect2i(0, 0, 256, 192), Vector2i((_n % 6) * 256, (_n / 6) * 192))
	_n += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
	cfg.minutes = 5
	cfg.spawners = false
	Game.match_config = cfg
	_m = (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(_m)
	await _m.ready_to_play
	_m.hud.visible = false
	_m.started = true
	for f in _m.fighters:
		f.freeze(false)
	_m.brains.clear()
	_m.player_input.enabled = false
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_strip = Image.create(256 * 6, 192 * 3, false, Image.FORMAT_RGBA8)
	var a := _m.fighters[1]
	var b := _m.fighters[0]
	b.global_position = Vector3(25, 0.1, 25)
	# 1) slash a crate stack at (-14, 0, -6)
	a.global_position = Vector3(-10, 0.1, -6.6)
	a.rotation.y = 0.0
	await _wait(0.3)
	var focus := Vector3(-10, 1.0, -5.5)
	await _shot(focus, Vector3(3.5, 2.0, -3.0))
	a.input.attack_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	a.input.attack_held = false
	await _wait(0.6)
	a.input.attack_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	a.input.attack_held = false
	for i in 5:
		await _wait(0.15)
		await _shot(focus, Vector3(3.5, 2.0, -3.0))
	# 2) a sword thrown into a barrel next to the other fighter
	b.global_position = Vector3(6.4, 0.1, -10.4)
	a.global_position = Vector3(4.5, 0.1, -12.4)
	a.rotation.y = 0.0
	a.equip(Registry.weapon(&"sword"))
	await _wait(0.4)
	focus = Vector3(5.0, 1.0, -11)
	await _shot(focus, Vector3(-5.0, 3.0, 4.0))
	a.input.attack_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	a.input.attack_held = false
	await _wait(0.5)
	a.input.attack_held = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	a.input.attack_held = false
	for i in 5:
		await _wait(0.14)
		await _shot(focus, Vector3(-5.0, 3.0, 4.0))
	# 3) a heavy hit sends a fighter into a railing at z = 27.5
	await _wait(1.5)
	b.global_position = Vector3(-14.75, 0.1, 25.8)
	b.respawn(Vector3(-14.75, 0.1, 25.8), 0.0)
	b.protect = 0.0
	await _wait(0.3)
	focus = Vector3(-14.75, 0.8, 26.5)
	b.take_hit(5.0, Vector3(0, 0, 1), a, true, b.global_position + Vector3.UP, 12.0)
	for i in 6:
		await _shot(focus, Vector3(5.0, 2.5, -3.5))
		await _wait(0.12)
	var broken := []
	for p in _m.arena.breakables:
		if p.is_broken:
			broken.append(Breakable.Kind.keys()[p.kind])
	print("BROKEN ", broken, " a.hp=", a.health, " debris=", _m.arena.debris.active_count(), " b.hp=", b.health, " b.state=", Fighter.State.keys()[b.state])
	_strip.save_png(out + "/break_strip.png")
	get_tree().quit()
