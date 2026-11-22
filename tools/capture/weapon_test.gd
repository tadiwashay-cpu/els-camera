extends Node
## Dev: each special weapon used on a target bot 7 m away; logs damage and
## ammo and saves a frame of each.
##   xvfb-run godot --path . res://tools/capture/weapon_test.tscn -- OUT_DIR

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var cfg := MatchConfig.new()
	cfg.bots = 1
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
	var b := m.fighters[0]
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var args := OS.get_cmdline_user_args()
	var ids: Array = ["blaster", "bow", "shuriken", "bomb", "boomerang", "hammer", "spear", "boxing_gloves"]
	if args.size() > 1:
		ids = args[1].split(",")
	var skill_mode := args.size() > 2 and args[2] == "skill"
	if skill_mode and args[1] == "all":
		ids = []
		for id: StringName in Registry.weapons:
			ids.append(String(id))
		ids.sort()
	var strip := Image.create(240 * 4, 180 * int(ceil(ids.size() / 4.0)), false, Image.FORMAT_RGBA8)
	for i in ids.size():
		var id: String = ids[i]
		b.respawn(Vector3(0, 0.1, 14), PI)
		b.protect = 0.0
		var near := id in ["hammer", "spear", "boxing_gloves", "ice_cream", "flail", "scythe", "lance", "guitar", "nunchucks",
			"wrench", "shovel", "umbrella", "fan", "shield", "sword", "katana", "battle_axe", "frying_pan"]
		var gap := 1.5 if id in ["ice_cream", "flail", "nunchucks", "wrench", "umbrella", "shield"] else 2.2
		if skill_mode:
			var sk := WeaponSkills.info(Registry.weapon(StringName(id)).skill)
			near = true
			gap = clampf(float(sk.get("range", 3.0)) * 0.6, 1.6, 9.0)
		a.respawn(Vector3(0, 0.1, 14 + (gap if near else -7.0)) if near else Vector3(0, 0.1, 7.0), 0.0 if not near else PI)
		a.protect = 0.0
		a.equip(Registry.weapon(StringName(id)))
		a.input.target = b
		await get_tree().create_timer(0.3).timeout
		var hp0 := b.health
		var ammo0 := a.ammo
		var hold := 0.7 if id in ["bow", "hammer"] else 0.03
		if skill_mode:
			a.input.press(&"skill")
		else:
			a.input.attack_held = true
			await get_tree().create_timer(hold).timeout
			a.input.attack_held = false
		await get_tree().create_timer(0.45).timeout
		cam.global_position = Vector3(6.0, 3.0, 11.5)
		cam.look_at(Vector3(0, 1.0, 11.0))
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(240, 180)
		strip.blit_rect(img, Rect2i(0, 0, 240, 180), Vector2i((i % 4) * 240, (i / 4) * 180))
		await get_tree().create_timer(1.6).timeout
		if skill_mode:
			id = "%s/%s" % [id, Registry.weapon(StringName(id)).skill]
		print("%-14s dmg=%5.1f  ammo %d->%d  armed=%s  b.state=%s  b.moved=%.1f  effects=%s  a.pos=%s" % [id, hp0 - b.health,
			ammo0, a.ammo, a.armed(), Fighter.State.keys()[b.state], Vector2(b.global_position.x, b.global_position.z - 14).length(),
			b.powers.effects.keys(), a.global_position.snapped(Vector3.ONE * 0.1)])
	strip.save_png(out + "/weapon_strip.png")
	get_tree().quit()
