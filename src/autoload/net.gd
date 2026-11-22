extends Node
## LAN and hotspot multiplayer (doc: Multiplayer): one phone hosts, up to
## three join. Godot's high-level multiplayer over ENet. The host is the
## authority: it runs the whole match; joiners send inputs and show what the
## host sends back (NetSync, inside the match).
##   Lobby: host() / join(ip) / leave(); players and settings sync to all.
##   Start: the host picks the roster and settings; everyone loads; the
##   countdown starts once every phone has loaded.

signal lobby_changed
signal status_changed(text: String)
signal left(reason: String)

const PORT := 37777
const MAX_PLAYERS := 4
## Waiting for slow phones to load before starting anyway (s).
const LOAD_TIMEOUT := 20.0

var peer: ENetMultiplayerPeer
var discovery: LanDiscovery
## In a networked session (lobby or match).
var active := false
var is_host := false
var in_match := false
## peer id -> {"name", "power", "skin"}
var players: Dictionary = {}
## Host's match settings, mirrored to everyone in the lobby.
var settings: Dictionary = {}
## The fighters of the match being played: [{"id", "name", "skin", "peer", "power"}].
var roster: Array = []
## The NetSync of the running match (it handles snapshots, inputs, events).
var sync: NetSync
var status := ""
var _loaded: Dictionary = {}
var _load_wait := -1.0


func _ready() -> void:
	discovery = LanDiscovery.new()
	discovery.name = "Discovery"
	add_child(discovery)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail("Couldn't connect to that game"))
	multiplayer.server_disconnected.connect(func() -> void: _fail("The host left"))


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


## Is this the phone that runs the match? (Always true offline.)
func authority() -> bool:
	return not active or is_host


# --------------------------------------------------------------- lobby

func host(player_name: String, power: StringName) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_set_status("Couldn't start a game (port busy?)")
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	players = {1: {"name": player_name, "power": String(power), "skin": 0}}
	settings = _settings_from(Game.match_config)
	discovery.start_broadcast(_announce())
	_set_status("Hosting on %s" % ", ".join(local_ips()))
	lobby_changed.emit()
	return OK


func join(ip: String, player_name: String, power: StringName) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		_set_status("Couldn't reach %s" % ip)
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	players = {}
	set_meta("pending_hello", {"name": player_name, "power": String(power)})
	_set_status("Connecting to %s..." % ip)
	return OK


func leave() -> void:
	discovery.stop()
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	active = false
	is_host = false
	in_match = false
	players.clear()
	roster.clear()
	sync = null
	_loaded.clear()
	_load_wait = -1.0


## This phone's addresses others can type in (no loopback).
static func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for ip: String in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append(ip)
	return out


## Host: change a match setting (time, arena, bots...) for everyone.
func set_setting(key: String, value: Variant) -> void:
	if not is_host:
		return
	settings[key] = value
	_push_lobby()


func _on_connected() -> void:
	var hello: Dictionary = get_meta("pending_hello", {})
	_hello.rpc_id(1, str(hello.get("name", "Player")), str(hello.get("power", "rage")), Game.version())
	_set_status("Connected, waiting for the host")


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	if players.has(id):
		var who := str(players[id]["name"])
		players.erase(id)
		_loaded.erase(id)
		_push_lobby()
		if in_match and sync:
			sync.peer_left(id, who)


func _fail(reason: String) -> void:
	var was_match := in_match
	leave()
	_set_status(reason)
	left.emit(reason)
	if was_match:
		Game.goto_title()


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)


func _announce() -> Dictionary:
	return {"name": str(players.get(1, {}).get("name", "Host")), "players": players.size(), "max": MAX_PLAYERS,
		"arena": str(settings.get("arena_choice", "")), "version": Game.version(), "port": PORT, "in_match": in_match}


func _push_lobby() -> void:
	if not is_host:
		return
	# Skins follow join order.
	var i := 0
	for id: int in _sorted_ids():
		players[id]["skin"] = i
		i += 1
	_lobby.rpc(players, settings)
	discovery.update_info(_announce())
	lobby_changed.emit()


func _sorted_ids() -> Array:
	var ids: Array = players.keys()
	ids.sort()
	ids.erase(1)
	ids.push_front(1)
	return ids


@rpc("any_peer", "reliable")
func _hello(player_name: String, power: String, version: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if version != Game.version():
		_refused.rpc_id(id, "Different game versions (host %s, you %s)" % [Game.version(), version])
		return
	if players.size() >= MAX_PLAYERS or in_match:
		_refused.rpc_id(id, "That game is full or already playing")
		return
	players[id] = {"name": player_name.substr(0, 16), "power": power, "skin": 0}
	_push_lobby()


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	_fail(reason)


@rpc("authority", "reliable")
func _lobby(p: Dictionary, s: Dictionary) -> void:
	players = p
	settings = s
	lobby_changed.emit()


# --------------------------------------------------------------- match

## Host: start a match with everyone in the lobby (bots fill the rest).
func start_match() -> void:
	if not is_host:
		return
	roster.clear()
	var fid := 0
	for id: int in _sorted_ids():
		var p: Dictionary = players[id]
		roster.append({"id": fid, "name": p["name"], "skin": int(p["skin"]), "peer": id, "power": p["power"]})
		fid += 1
	var bots := clampi(int(settings.get("bots", 1)), 0, MAX_PLAYERS - roster.size())
	if roster.size() == 1:
		bots = maxi(bots, 1)
	for b in bots:
		roster.append({"id": fid, "name": Match.BOT_NAMES[b % Match.BOT_NAMES.size()], "skin": fid, "peer": 0,
			"power": String(FighterPowers.IDS[(fid * 2 + randi()) % FighterPowers.IDS.size()])})
		fid += 1
	var s := settings.duplicate()
	s["arena_id"] = String(Registry.pick_arena(StringName(str(s.get("arena_choice", "blockout_yard")))).id)
	s["seed"] = randi() % 100000 + 1
	_start.rpc(s, roster)
	_start(s, roster)


@rpc("authority", "reliable")
func _start(s: Dictionary, r: Array) -> void:
	roster = r
	in_match = true
	_loaded.clear()
	_load_wait = LOAD_TIMEOUT if is_host else -1.0
	var cfg := MatchConfig.new()
	_apply_settings(cfg, s)
	Game.match_config = cfg
	var arena := Registry.arena(cfg.arena_id)
	Game.goto_scene(Game.MATCH_SCENE, {"title": arena.display_name.to_upper(), "color": arena.title_color,
		"subtitle": "LAN match: %d fighters" % roster.size()})
	if is_host:
		discovery.update_info(_announce())


## The match on this phone has loaded: tell the host (the host waits for all).
func report_loaded() -> void:
	if is_host:
		_mark_loaded(1)
	else:
		_loaded_up.rpc_id(1)


@rpc("any_peer", "reliable")
func _loaded_up() -> void:
	if is_host:
		_mark_loaded(multiplayer.get_remote_sender_id())


func _mark_loaded(id: int) -> void:
	_loaded[id] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	for id: int in players:
		if not _loaded.has(id):
			return
	_load_wait = -1.0
	_go.rpc()
	_go()


@rpc("authority", "reliable")
func _go() -> void:
	if sync:
		sync.start_countdown()


func _process(delta: float) -> void:
	if _load_wait > 0.0:
		_load_wait -= delta
		if _load_wait <= 0.0 and _loaded.has(1):
			_load_wait = -1.0
			_go.rpc()
			_go()


## Back from a match to the lobby (host: everyone).
func end_match() -> void:
	in_match = false
	sync = null
	if is_host:
		discovery.update_info(_announce())


# ------------------------------------------------- match traffic (NetSync)

func send_input(bytes: PackedByteArray) -> void:
	_rx_input.rpc_id(1, bytes)


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _rx_input(bytes: PackedByteArray) -> void:
	if is_host and sync:
		sync.receive_input(multiplayer.get_remote_sender_id(), bytes)


func send_snapshot(bytes: PackedByteArray) -> void:
	_rx_snapshot.rpc(bytes)


@rpc("authority", "unreliable_ordered", "call_remote", 2)
func _rx_snapshot(bytes: PackedByteArray) -> void:
	if sync:
		sync.receive_snapshot(bytes)


func send_event(kind: String, data: Array) -> void:
	_rx_event.rpc(kind, data)


@rpc("authority", "reliable")
func _rx_event(kind: String, data: Array) -> void:
	if sync:
		sync.receive_event(kind, data)


# --------------------------------------------------------------- settings

static func _settings_from(c: MatchConfig) -> Dictionary:
	return {"minutes": c.minutes, "bots": c.bots, "difficulty": c.difficulty, "arena_choice": String(c.arena_choice),
		"start_weapon": String(c.start_weapon), "hazards": c.hazards, "kill_target": c.kill_target, "pickups": c.pickups,
		"spawners": c.spawners}


static func _apply_settings(c: MatchConfig, s: Dictionary) -> void:
	c.minutes = float(s.get("minutes", 3.0))
	c.bots = int(s.get("bots", 0))
	c.difficulty = int(s.get("difficulty", 1))
	c.arena_choice = StringName(str(s.get("arena_choice", "blockout_yard")))
	c.arena_id = StringName(str(s.get("arena_id", "blockout_yard")))
	c.start_weapon = StringName(str(s.get("start_weapon", "sword")))
	c.hazards = bool(s.get("hazards", true))
	c.kill_target = int(s.get("kill_target", 0))
	c.pickups = bool(s.get("pickups", true))
	c.spawners = bool(s.get("spawners", true))
	c.seed = int(s.get("seed", 0))
