extends Node
## Dev/CI: plays a whole match with bots only (the "player" is driven by a
## bot brain too), headless, and prints what happened.
##   godot --headless --path . res://tools/capture/smoke.tscn -- [seconds] [bots] [difficulty]

var _match: Match
var _brain: AIBrain
var _hits := 0
var _throws := 0
var _catches := 0
var _deaths := 0
var _downs := 0
var _kinds: Dictionary = {}
var _last_state: Dictionary = {}
var _breaks: Dictionary = {}
var _held: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 60.0
	var cfg := MatchConfig.new()
	cfg.minutes = seconds / 60.0
	cfg.bots = int(args[1]) if args.size() > 1 else 1
	cfg.difficulty = int(args[2]) if args.size() > 2 else 2
	cfg.seed = 7
	if args.size() > 3:
		cfg.start_weapon = StringName(args[3])
	Game.match_config = cfg
	_match = (load(Game.MATCH_SCENE) as PackedScene).instantiate() as Match
	add_child(_match)
	await _match.ready_to_play
	print("SMOKE ready: fighters=", _match.fighters.size(), " nav polys=", _match.arena.nav.navigation_mesh.get_polygon_count())
	_brain = AIBrain.new(_match.player, _match, 2)
	_match.player_input.enabled = false
	for f in _match.fighters:
		f.hit_landed.connect(func(_a: Fighter, _v: Fighter, _d: float) -> void: _hits += 1)
		f.died.connect(func(_v: Fighter, _k: Fighter) -> void: _deaths += 1)
		f.hurt.connect(func(v: Fighter, a: Fighter, d: float, _at: Vector3, heavy: bool) -> void:
			var k := "%s%s" % ["thrown" if a and a.state != Fighter.State.ATTACK and a.state != Fighter.State.HEAVY else (a.body.action if a else "?"), "!" if heavy else ""]
			_kinds[k] = int(_kinds.get(k, 0)) + 1)
	for piece in _match.arena.breakables:
		piece.broken.connect(func(p: Breakable, _by: Fighter) -> void:
			var k: String = Breakable.Kind.keys()[p.kind]
			_breaks[k] = int(_breaks.get(k, 0)) + 1)
	_match.begin()
	Engine.time_scale = 1.0
	var t0 := Time.get_ticks_msec()
	while not _match.ended:
		await get_tree().physics_frame
		if _match.started:
			_brain.update(get_physics_process_delta_time())
		for f in _match.fighters:
			if f.armed():
				_held[String(f.weapon_data.id)] = true
			var prev: int = _last_state.get(f.fighter_id, -1)
			if f.state != prev:
				match f.state:
					Fighter.State.THROW: _throws += 1
					Fighter.State.CATCH: _catches += 1
					Fighter.State.DOWN: _downs += 1
				_last_state[f.fighter_id] = f.state
		if Time.get_ticks_msec() - t0 > int(seconds * 1000.0) + 30000:
			print("SMOKE timeout")
			break
	print("SMOKE end: scores=", _match.race.scores, " winner=", _match.race.winner, " hits=", _hits,
		" deaths=", _deaths, " throws=", _throws, " catches=", _catches, " knockdowns=", _downs,
		" pickups_left=", _match.pickups.size(), " kinds=", _kinds, " breaks=", _breaks, " debris_active=", _match.arena.debris.active_count(), "\n  weapons used=", _held.keys(), " fps=", Engine.get_frames_per_second())
	for f in _match.fighters:
		print("  ", f.display_name, " power=", f.powers.power, " stats=", f.stats, " hp=", f.health, " state=", Fighter.State.keys()[f.state], " pos=", f.global_position.snapped(Vector3.ONE * 0.1), " armed=", f.armed())
	await get_tree().create_timer(1.5, true, false, true).timeout
	get_tree().quit()
