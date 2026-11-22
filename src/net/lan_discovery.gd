class_name LanDiscovery
extends Node
## Finds games on the same Wi-Fi or phone hotspot (doc: Discovery). The host
## broadcasts a small UDP packet every second; joiners listen and keep a
## list of games heard from in the last few seconds. Typing the host's IP is
## the fallback when a router blocks broadcasts.

signal games_changed

const PORT := 37778
const TAG := "BlockDuelist3D"
const STALE := 4.0

## Found games: ip -> {"name", "players", "max", "arena", "version", "seen"}
var games: Dictionary = {}
var _sender: PacketPeerUDP
var _listener: PacketPeerUDP
var _info: Dictionary = {}
var _next_send := 0.0
var _clock := 0.0


## Host: announce `info` (name, players, max, arena) every second.
func start_broadcast(info: Dictionary) -> void:
	stop()
	_info = info
	_sender = PacketPeerUDP.new()
	_sender.set_broadcast_enabled(true)
	_next_send = 0.0


func update_info(info: Dictionary) -> void:
	_info = info


## Joiner: listen for hosts.
func start_listening() -> Error:
	stop()
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(PORT, "0.0.0.0")
	if err != OK:
		_listener = null
	games.clear()
	return err


func stop() -> void:
	if _sender:
		_sender.close()
		_sender = null
	if _listener:
		_listener.close()
		_listener = null


## Where to send: the global broadcast plus each local /24's broadcast
## (a phone hotspot often only passes the subnet one).
static func broadcast_addresses() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255"])
	for ip: String in IP.get_local_addresses():
		var parts := ip.split(".")
		if parts.size() == 4 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			var b := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if not out.has(b):
				out.append(b)
	return out


static func encode(info: Dictionary) -> PackedByteArray:
	var d := info.duplicate()
	d["tag"] = TAG
	return JSON.stringify(d).to_utf8_buffer()


## Parses a packet; empty if it isn't one of ours.
static func decode(bytes: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	if str(d.get("tag", "")) != TAG:
		return {}
	return d


func _process(delta: float) -> void:
	_clock += delta
	if _sender and _clock >= _next_send:
		_next_send = _clock + 1.0
		var bytes := encode(_info)
		for addr in broadcast_addresses():
			_sender.set_dest_address(addr, PORT)
			_sender.put_packet(bytes)
	if _listener:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var bytes := _listener.get_packet()
			var ip := _listener.get_packet_ip()
			var d := decode(bytes)
			if d.is_empty():
				continue
			if not games.has(ip):
				changed = true
			d["seen"] = _clock
			games[ip] = d
		for ip: String in games.keys():
			if _clock - float(games[ip]["seen"]) > STALE:
				games.erase(ip)
				changed = true
		if changed:
			games_changed.emit()
