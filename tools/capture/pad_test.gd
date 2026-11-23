extends Node
## Dev: drops the player on every bounce pad of an arena and prints where
## they land (should be within a metre or so of the pad's target).
##   godot --headless --path . res://tools/capture/pad_test.tscn -- ARENA

var _match: Match


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cfg := MatchConfig.new()
	cfg.minutes = 2.0
	cfg.bots = 1
	cfg.arena_id = StringName(args[0]) if args.size() > 0 else &"blockout_yard"
	cfg.hazards = false
	Game.match_config = cfg
	_match = (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(_match)
	await _match.ready_to_play
	_match.player_input.enabled = false
	_match.begin()
	while not _match.started:
		await get_tree().physics_frame
	for b in _match.brains:
		b.me.global_position = Vector3(0, 30, 0)        # out of the way
		b.me.freeze(true)
	var p := _match.player
	for i in _match.arena.pads.size():
		var pad: Dictionary = _match.arena.pads[i]
		p.velocity = Vector3.ZERO
		p.global_position = pad["at"] + Vector3.UP * 0.2
		var t := 0.0
		var flew := false
		while t < 4.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if not p.is_on_floor():
				flew = true
			elif flew and t > 0.3:
				break
		var link: NavigationLink3D = (pad["top"] as Node3D).get_parent().get_child(-1) as NavigationLink3D
		var want: Vector3 = (pad["at"] as Vector3) + (link.end_position if link else Vector3.ZERO)
		print("PAD %d from %s landed %s want %s off %.2f m alive=%s" % [i, pad["at"], p.global_position.snapped(Vector3.ONE * 0.1),
			want, Vector2(p.global_position.x - want.x, p.global_position.z - want.z).length(), p.alive])
		await get_tree().create_timer(0.9).timeout
	get_tree().quit()
