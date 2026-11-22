class_name Killcam
extends Node3D
## Records the last couple of seconds of every fighter's pose and replays
## a kill in slow motion (doc: Killcam). The replay is exact: ghost bodies
## are posed from the recorded bones (ragdoll included), so what the victim
## sees is what happened.

signal finished

const BUFFER_SECONDS := 2.5

var match_node: Match
var playing := false
var _frames: Array = []          # {"t": float, "f": {id: [root, PackedTransforms, weapon id]}, "p": [[xform, id]]}
var _ghosts: Dictionary = {}     # fighter id -> {"body": BlockBody, "weapon": MeshInstance3D, "weapon_id": StringName}
var _proj_ghosts: Array[MeshInstance3D] = []
var _cam: Camera3D
var _t := 0.0
var _t0 := 0.0
var _t1 := 0.0
var _speed := 0.5
var _focus: Array[int] = []
var _prev_cam: Camera3D
var _bars: CanvasLayer
var _caption: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Moved every frame, not every physics tick: no interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_bars = CanvasLayer.new()
	_bars.layer = 20
	_bars.visible = false
	add_child(_bars)
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, 0.85)
		r.anchor_right = 1.0
		if top:
			r.anchor_bottom = 0.0
			r.offset_bottom = 90
		else:
			r.anchor_top = 1.0
			r.anchor_bottom = 1.0
			r.offset_top = -90
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.add_child(r)
	_caption = Label.new()
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -78
	_caption.offset_bottom = -12
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override(&"font_size", 40)
	_bars.add_child(_caption)


## Called every physics frame by the match (not while replaying).
func record(clock: float) -> void:
	if playing:
		return
	var fr := {"t": clock, "f": {}, "p": []}
	for f: Fighter in match_node.fighters:
		var sk := f.body.skeleton
		f.body.keep_final_pose = true
		if f.body.final_pose.is_empty():
			continue
		fr["f"][f.fighter_id] = [sk.global_transform, f.body.final_pose.duplicate(), f.weapon_data.id if f.armed() else &""]
	for p: ThrownWeapon in match_node.projectiles:
		if is_instance_valid(p) and p._visual:
			fr["p"].append([p._visual.global_transform, p.data.id])
	_frames.append(fr)
	while not _frames.is_empty() and clock - float(_frames[0]["t"]) > BUFFER_SECONDS:
		_frames.pop_front()


## Replays [kill_t - before, kill_t + after] at `speed`, framing the fighters
## in `focus` (ids).
func play(kill_t: float, before: float, after: float, speed: float, focus: Array[int], caption: String) -> void:
	if _frames.size() < 4:
		finished.emit()
		return
	playing = true
	_t0 = maxf(kill_t - before, float(_frames[0]["t"]))
	_t1 = minf(kill_t + after, float(_frames[-1]["t"]))
	_t = _t0
	_speed = speed
	_focus = focus
	_caption.text = caption
	_bars.visible = true
	_prev_cam = get_viewport().get_camera_3d()
	for f: Fighter in match_node.fighters:
		f.visible = false
		_ghost(f)
	for p: ThrownWeapon in match_node.projectiles:
		p.visible = false
	_cam.current = true
	_apply(_t)


func skip() -> void:
	if playing:
		_t = _t1


func _ghost(f: Fighter) -> void:
	if not _ghosts.has(f.fighter_id):
		var b := BlockBody.new()
		add_child(b)
		b.setup(f.body.skin, false)
		b.anim.stop()
		b.anim.active = false
		_ghosts[f.fighter_id] = {"body": b, "weapon": null, "weapon_id": &""}
	(_ghosts[f.fighter_id]["body"] as BlockBody).visible = true


func _process(delta: float) -> void:
	if not playing:
		return
	var real := delta / maxf(Engine.time_scale, 0.02)
	_t += real * _speed
	if _t >= _t1:
		_end()
		return
	_apply(_t)


func _frame_at(t: float) -> Dictionary:
	for fr: Dictionary in _frames:
		if float(fr["t"]) >= t:
			return fr
	return _frames[-1]


func _apply(t: float) -> void:
	var fr := _frame_at(t)
	var centre := Vector3.ZERO
	var n := 0
	for id: int in fr["f"]:
		if not _ghosts.has(id):
			continue
		var g: Dictionary = _ghosts[id]
		var b: BlockBody = g["body"]
		var rec: Array = fr["f"][id]
		b.global_transform = Transform3D.IDENTITY
		b.skeleton.global_transform = rec[0]
		var poses: Array = rec[1]
		for i in poses.size():
			b.skeleton.set_bone_global_pose(i, poses[i])
		var wid: StringName = rec[2]
		if wid != g["weapon_id"]:
			if g["weapon"]:
				(g["weapon"] as Node).queue_free()
				g["weapon"] = null
			if wid != &"":
				var mi := MeshInstance3D.new()
				mi.mesh = Registry.weapon(wid).mesh()
				b.socket_r.add_child(mi)
				g["weapon"] = mi
			g["weapon_id"] = wid
		if _focus.has(id):
			centre += (rec[0] as Transform3D) * (poses[b.skeleton.find_bone("Hips")] as Transform3D).origin
			n += 1
	# Thrown weapons
	var projs: Array = fr["p"]
	while _proj_ghosts.size() < projs.size():
		var mi := MeshInstance3D.new()
		add_child(mi)
		_proj_ghosts.append(mi)
	for i in _proj_ghosts.size():
		var mi := _proj_ghosts[i]
		mi.visible = i < projs.size()
		if mi.visible:
			mi.mesh = Registry.weapon(projs[i][1]).mesh()
			mi.global_transform = projs[i][0]
	if n > 0:
		centre /= n
		var u := (t - _t0) / maxf(_t1 - _t0, 0.01)
		var ang := 0.9 + u * 0.8
		var r := 4.6 - u * 1.0
		_cam.global_position = centre + Vector3(cos(ang) * r, 1.1 + u * 0.4, sin(ang) * r)
		_cam.look_at(centre + Vector3.UP * 0.4, Vector3.UP)


func _end() -> void:
	playing = false
	_bars.visible = false
	for g: Dictionary in _ghosts.values():
		(g["body"] as BlockBody).visible = false
	for mi in _proj_ghosts:
		mi.visible = false
	for f: Fighter in match_node.fighters:
		f.visible = true
	for p: ThrownWeapon in match_node.projectiles:
		if is_instance_valid(p):
			p.visible = true
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.current = true
	finished.emit()
