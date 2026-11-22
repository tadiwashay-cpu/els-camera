extends Node
## Dev/CI: a real LAN match between two Godot processes on this machine.
## One hosts, one joins 127.0.0.1; bot brains play for both humans (the
## joiner's bot drives its puppet's input, which goes over the network).
##   godot --headless --path . res://tools/capture/net_smoke.tscn -- host SECONDS ARENA
##   godot --headless --path . res://tools/capture/net_smoke.tscn -- join [OUT_DIR for screenshots]
## Each prints "NETSMOKE <role> end ..." with scores; they must match.

var _role := "host"
var _m: Match
var _brain: AIBrain
var _moved := 0.0
var _last := Vector3.INF
var _t := 0.0
var _out := ""
var _shots := [8.0, 16.0, 24.0, 32.0]


func _ready() -> void:
	get_tree().current_scene = null
	var args := OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "host"
	Save.set_setting("player_name", "Host" if _role == "host" else "Joiner")
	if _role == "host":
		var seconds := float(args[1]) if args.size() > 1 else 40.0
		Net.host("Host", &"rage")
		Net.set_setting("minutes", seconds / 60.0)
		Net.set_setting("bots", 1)
		Net.set_setting("difficulty", 2)
		Net.set_setting("arena_choice", args[2] if args.size() > 2 else "blockout_yard")
		Net.set_setting("start_weapon", "random")
		var wait := 0.0
		while Net.players.size() < 2 and wait < 30.0:
			await get_tree().create_timer(0.25).timeout
			wait += 0.25
		print("NETSMOKE host: players=", Net.players.size())
		Net.start_match()
	else:
		_out = args[1] if args.size() > 1 else ""
		Net.left.connect(func(reason: String) -> void: print("NETSMOKE join left: ", reason))
		var tries := 0
		while tries < 20:
			Net.join("127.0.0.1", "Joiner", &"stomp")
			await get_tree().create_timer(1.0).timeout
			if Net.players.size() >= 2:
				break
			tries += 1
		print("NETSMOKE join: lobby players=", Net.players.size())
	while not (get_tree().current_scene is Match):
		await get_tree().process_frame
	_m = get_tree().current_scene as Match
	while not _m.started:
		await get_tree().process_frame
	print("NETSMOKE %s started: fighters=%d authority=%s player=%s" % [_role, _m.fighters.size(), _m.authority, _m.player.display_name])
	_m.player_input.set_physics_process(false)      # the bot holds the stick
	_brain = AIBrain.new(_m.player, _m, 2)


func _physics_process(delta: float) -> void:
	if _m == null or not is_instance_valid(_m) or not _m.started or _brain == null:
		return
	_t += delta
	_brain.update(delta)
	if _out != "" and not _shots.is_empty() and _t >= _shots[0]:
		_shots.pop_front()
		_shot.call_deferred("join_%02d" % int(_t))
	var p := _m.player.global_position
	if _last != Vector3.INF and p.distance_to(_last) < 2.0:
		_moved += p.distance_to(_last)
	_last = p
	if int(_t * 60.0) % 300 == 0:
		var others := ""
		for f in _m.fighters:
			if f != _m.player:
				others += " %s@%s" % [f.display_name, f.global_position.snapped(Vector3.ONE * 0.1)]
		print("NETSMOKE %s t=%.0f pos=%s hp=%.0f state=%s stats=%s others:%s" % [_role, _t, p.snapped(Vector3.ONE * 0.1), _m.player.health,
			Fighter.State.keys()[_m.player.state], _m.net.stats if _m.net else {}, others])


func _process(_delta: float) -> void:
	if _m and is_instance_valid(_m) and _m.ended and not has_meta("done"):
		set_meta("done", true)
		await get_tree().create_timer(2.0).timeout
		print("NETSMOKE %s end: scores=%s time_left=%.1f moved=%.1f stats=%s" % [_role, _m.race.scores, _m.race.time_left,
			_moved, _m.net.stats if _m.net else {}])
		await get_tree().create_timer(2.0 if _role == "host" else 0.2).timeout
		get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot_name])
	print("SHOT ", shot_name)
