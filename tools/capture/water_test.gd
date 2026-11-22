extends Node
## Dev: drops the player into the sea and checks they float, lose health
## slowly, get bitten in shark water, and (bot-driven) climb back out.
##   godot --headless --path . res://tools/capture/water_test.tscn -- ARENA X Y Z

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cfg := MatchConfig.new()
	cfg.minutes = 3.0
	cfg.bots = 1
	cfg.seed = 2
	cfg.arena_id = StringName(args[0]) if args.size() > 0 else &"harbor_factory"
	Game.match_config = cfg
	var m := (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(m)
	await m.ready_to_play
	m.begin()
	m.player_input.enabled = false
	var bot := m.fighters[1]
	bot.global_position = Vector3(0, 30, 0) if cfg.arena_id == &"harbor_factory" else Vector3(-13, 5, -17)
	var at := Vector3(float(args[1]), float(args[2]), float(args[3])) if args.size() > 3 else Vector3(-10, 0, -21.5)
	m.player.protect = 0.0
	m.player.global_position = at
	var brain := AIBrain.new(m.player, m, 1)
	var t := 0.0
	var swam := false
	var out_at := -1.0
	var hp0 := m.player.health
	while t < 14.0:
		await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		t += d
		if t > 3.0:
			brain.update(d)
		if m.player.swimming:
			swam = true
		if swam and out_at < 0.0 and not m.player.swimming and m.player.global_position.y > m.arena.water_level:
			out_at = t
		if int(t * 60.0) % 60 == 0:
			print("WATER t=%.1f y=%.2f swim=%s hp=%.1f wet=%.1f alive=%s" % [t, m.player.global_position.y, m.player.swimming,
				m.player.health, m.arena.wet_time(m.player), m.player.alive])
		if not m.player.alive:
			break
	print("WATER result: swam=%s climbed_out_at=%.1f hp %.0f -> %.0f stats=%s" % [swam, out_at, hp0, m.player.health, m.arena.stats])
	get_tree().quit()
