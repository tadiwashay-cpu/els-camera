class_name DangerIndicator
extends Control
## Danger sense: something thrown or fired is about to hit you. A pulsing
## "!" over your head, a chevron at the edge of a ring pointing where it's
## coming from, and a quick tingle the moment it's noticed (the cue to
## block, dodge or catch).

const HORIZON := 0.9           # seconds of warning
const RADIUS := 230.0

var match_node: Match
var _threats: Array = []       # [{"pos": Vector3, "t": float}]
var _known: Dictionary = {}
var _clock := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_clock += delta
	var f := match_node.player if match_node else null
	_threats.clear()
	if f == null or not f.alive or match_node.ended:
		queue_redraw()
		return
	var seen := {}
	for th: Dictionary in match_node.threats_to(f, HORIZON):
		_threats.append(th)
		seen[th["id"]] = true
		if not _known.has(th["id"]):
			Audio.play(&"tingle", null, -4.0)
	_known = seen
	queue_redraw()


func _draw() -> void:
	if _threats.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var f := match_node.player
	if cam == null or f == null:
		return
	var pulse := 0.6 + 0.4 * sin(_clock * 18.0)
	var head := f.global_position + Vector3.UP * 2.35
	if not cam.is_position_behind(head):
		var p := cam.unproject_position(head)
		var font := get_theme_default_font()
		var col := Color(1.0, 0.85, 0.2, pulse)
		draw_string_outline(font, p + Vector2(-14, 18), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 64, 10, Color(0.6, 0.1, 0.05, pulse))
		draw_string(font, p + Vector2(-14, 18), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 64, col)
	var centre := size * 0.5
	for th: Dictionary in _threats:
		var to: Vector3 = th["pos"] - f.global_position
		var local := cam.global_basis.inverse() * to
		var ang := atan2(local.x, -local.z)              # 0 = ahead (up the screen)
		var urgency := clampf(1.0 - float(th["t"]) / HORIZON, 0.2, 1.0)
		var tip := centre + Vector2(sin(ang), -cos(ang)) * (RADIUS + 20.0)
		var base := centre + Vector2(sin(ang), -cos(ang)) * RADIUS
		var side := Vector2(cos(ang), sin(ang)) * (26.0 + 14.0 * urgency)
		var c := Color(1.0, 0.25 + 0.5 * (1.0 - urgency), 0.15, 0.55 + 0.4 * urgency * pulse)
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), c)
		draw_polyline(PackedVector2Array([tip, base + side, base - side, tip]), Color(1, 1, 1, 0.6 * urgency), 3.0)
