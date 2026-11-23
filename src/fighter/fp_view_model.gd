class_name FPViewModel
extends Node3D
## First person (FPP): only the weapon, floating in front of the camera; no
## arms, no body (the fighter's own body is on a layer the eye camera
## doesn't draw: Fighter.set_eye_hidden). Big FPS games do the same: the
## weapon is its own thing drawn for the viewer.
##   Pose = the weapon family's rest pose + a first-person move made in
##   Blender (tools/blender/fp_moves.py -> assets/fighters/fp_weapon.glb),
##   picked from the move the fighter is playing and stretched so its
##   strike lands in that move's hit window.
##   On top: sway when the view turns, bob when walking, a dip on landing,
##   and pulling back (tip up) near a wall so the weapon never pokes through.

const GLB := "res://assets/fighters/fp_weapon.glb"
const INFO := "res://assets/fighters/fp_weapon.json"

## Third-person move -> first-person move.
const FROM_MOVE := {
	&"Slash_A": &"FP_SlashA", &"Slash_B": &"FP_SlashB", &"Slash_C": &"FP_Chop",
	&"Stab_A": &"FP_Stab", &"Stab_B": &"FP_Stab", &"Stab_C": &"FP_Stab", &"Thrust": &"FP_Stab", &"Thrust_B": &"FP_Stab",
	&"Rocket_Punch": &"FP_Stab",
	&"Spear_Thrust_A": &"FP_Thrust", &"Spear_Thrust_B": &"FP_Thrust", &"Spear_Lunge": &"FP_Lunge", &"Spear_Sweep": &"FP_Sweep",
	&"Smash_A": &"FP_Smash", &"Smash_B": &"FP_Smash", &"Smash_Release": &"FP_Slam", &"Smash_Charge": &"FP_SmashCharge",
	&"Heavy_Charge": &"FP_Charge", &"Heavy_Release": &"FP_Spin",
	&"Toss": &"FP_Throw", &"Throw": &"FP_Throw", &"Bomb_Lob": &"FP_Throw",
	&"Shoot": &"FP_Recoil", &"Bow_Draw": &"FP_BowDraw", &"Bow_Release": &"FP_BowRelease",
	&"Parry": &"FP_Parry", &"Parry_Fists": &"FP_Parry", &"Shield_Parry": &"FP_Parry",
	&"Shield_Bash": &"FP_ShieldBash", &"Shield_Bash_B": &"FP_ShieldBash", &"Shield_Slam": &"FP_ShieldSlam",
	&"Shield_Raise": &"FP_ShieldRaise",
	&"Power_Roar": &"FP_Cast", &"Power_Roar_Sword": &"FP_Cast", &"Power_Stomp": &"FP_Cast", &"Power_Stomp_Sword": &"FP_Cast",
	&"Power_Blink": &"FP_Cast", &"Power_Blink_Sword": &"FP_Cast", &"Cast_Forward": &"FP_Cast", &"Cast_Sky": &"FP_CastSky",
	&"Cast_Ground": &"FP_Smash", &"Cast_Buff": &"FP_CastSky", &"Cast_Pull": &"FP_Pull",
	&"Catch": &"FP_Catch", &"Pickup": &"FP_Equip",
	&"Land": &"FP_Dip", &"Land_Sword": &"FP_Dip", &"Land_Hard": &"FP_Dip", &"Land_Hard_Sword": &"FP_Dip",
	&"Hit_Front": &"FP_Dip", &"Hit_Back": &"FP_Dip", &"Stagger": &"FP_Dip",
}

## Rest pose per weapon family, camera space: [grip position, aim in
## degrees (yaw: tip to the right +, pitch: tip up +, roll: spin about the
## weapon's length); see tools/blender/fp_moves.py].
const REST := {
	&"blade": [Vector3(0.28, -0.32, -0.50), Vector3(-12.0, 60.0, 15.0)],
	&"heavy": [Vector3(0.30, -0.40, -0.52), Vector3(-25.0, 45.0, 0.0)],
	&"polearm": [Vector3(0.22, -0.36, -0.40), Vector3(-6.0, 15.0, 0.0)],
	&"ranged": [Vector3(0.18, -0.20, -0.36), Vector3(-4.0, 4.0, 0.0)],
	&"thrown": [Vector3(0.26, -0.30, -0.45), Vector3(-10.0, 50.0, 20.0)],
	&"shield": [Vector3(-0.30, -0.30, -0.55), Vector3(-35.0, 90.0, 0.0)],
	&"bow": [Vector3(-0.20, -0.14, -0.50), Vector3(0.0, 82.0, 180.0)],
	&"fist": [Vector3(0.24, -0.26, -0.45), Vector3(0.0, 10.0, 0.0)],
}

static var _anims: Dictionary = {}       # name -> Animation
static var _strike: Dictionary = {}      # name -> Vector2 (0..1) or null
static var _loaded := false

var fighter: Fighter
var camera: Camera3D
## Dev (tools/capture/fp_sheet.gd): show this weapon and move at a fixed
## point instead of following the fighter.
var preview_weapon: WeaponData
var preview_move := &""
var preview_t := -1.0
var _pivots: Array[Node3D] = []
var _meshes: Array[MeshInstance3D] = []
var _weapon: WeaponData
var _clock := 0.0
var _equip := 1.0
var _last_rot := Vector2.INF
var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _bob := 0.0
var _retract := 0.0
var _was_floor := true
var _land := 0.0


static func load_moves() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(GLB):
		var root := (load(GLB) as PackedScene).instantiate()
		for n in root.find_children("*", "AnimationPlayer", true, false):
			var ap := n as AnimationPlayer
			for name in ap.get_animation_list():
				_anims[StringName(name)] = ap.get_animation(name)
		root.free()
	var text := FileAccess.get_file_as_string(INFO)
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if data is Dictionary:
		var moves: Dictionary = (data as Dictionary).get("moves", {})
		for name: String in moves:
			var s: Variant = moves[name].get("strike")
			_strike[StringName(name)] = Vector2(float(s[0]), float(s[1])) if s is Array else null


static func has_move(name: StringName) -> bool:
	load_moves()
	return _anims.has(name)


## The first-person move for a third-person one (&"" if none).
static func fp_move_for(clip: StringName) -> StringName:
	return FROM_MOVE.get(clip, &"")


## How far into the first-person move we are, given how far (0..1) into the
## third-person move: the strike part is stretched onto its hit window.
static func warp(u: float, clip: StringName, fp: StringName) -> float:
	var s: Variant = _strike.get(fp)
	if not s is Vector2:
		return u
	var length := maxf(BlockBody.move_length(clip), 0.001)
	var hit := BlockBody.hit_window(clip)
	var e0 := -1.0
	var e1 := -1.0
	if hit.y > hit.x:
		e0 = hit.x / length
		e1 = hit.y / length
	else:
		for ev: String in ["power", "release", "fire", "slam", "catch"]:
			var t := BlockBody.event_time(clip, ev)
			if t >= 0.0:
				e0 = t / length
				e1 = minf(e0 + 0.06, 0.999)
				break
	if e0 < 0.0 or e1 <= e0:
		return u
	var sv := s as Vector2
	if u < e0:
		return sv.x * u / maxf(e0, 0.001)
	if u < e1:
		return sv.x + (sv.y - sv.x) * (u - e0) / (e1 - e0)
	return sv.y + (1.0 - sv.y) * (u - e1) / maxf(1.0 - e1, 0.001)


## The offset [grip position, aim (radians)] of first-person move `name`
## at t (0..1). The GLB has two empties: "FP" (grip) and "Aim" (its
## location carries yaw, pitch, roll).
static func sample(name: StringName, t: float) -> Array:
	var a: Animation = _anims.get(name)
	if a == null:
		return [Vector3.ZERO, Vector3.ZERO]
	var p := Vector3.ZERO
	var aim := Vector3.ZERO
	var time := clampf(t, 0.0, 1.0) * a.length
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var v := a.position_track_interpolate(i, time)
		if String(a.track_get_path(i)).get_file() == "Aim":
			aim = v
		else:
			p = v
	return [p, aim]


## Aim (yaw, pitch, roll in radians) -> rotation of a weapon whose tip is
## +Y: roll about its length, tip tipped down from straight up to `pitch`,
## then turned to `yaw`.
static func aim_basis(aim: Vector3) -> Basis:
	return Basis(Vector3.UP, -aim.x) * Basis(Vector3.RIGHT, aim.y - PI * 0.5) * Basis(Vector3.UP, aim.z)


static func family(w: WeaponData) -> StringName:
	if w == null or w.is_fists():
		return &""
	if w.id == &"shield":
		return &"shield"
	if w.id == &"bow":
		return &"bow"
	if w.kind == &"ranged":
		return &"ranged"
	if w.kind == &"thrown":
		return &"fist" if w.id == &"rocket_fist" else &"thrown"
	if w.heavy_charge == &"Smash_Charge":
		return &"heavy"
	if w.idle_clip == &"Spear_Idle" or w.light_moves.has(&"Spear_Thrust_A") or w.light_moves.has(&"Spear_Sweep"):
		return &"polearm"
	return &"blade"


func _ready() -> void:
	load_moves()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _set_weapon(w: WeaponData) -> void:
	_weapon = w
	for p in _pivots:
		p.queue_free()
	_pivots.clear()
	_meshes.clear()
	if w == null or w.is_fists():
		return
	var copies := 2 if w.both_hands else 1
	for k in copies:
		var pivot := Node3D.new()
		add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = w.mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		_pivots.append(pivot)
		_meshes.append(mi)
	_equip = 0.0


func _process(delta: float) -> void:
	if preview_t >= 0.0:
		_preview()
		return
	if fighter == null or not is_instance_valid(fighter) or camera == null:
		visible = false
		return
	var w := fighter.weapon_data if fighter.armed() else null
	if w != _weapon:
		_set_weapon(w)
	if not visible or _meshes.is_empty():
		return
	_clock += delta
	_equip = minf(_equip + delta * 2.5, 1.0)
	var fam := family(_weapon)

	# Which first-person move, and how far into it.
	var name: StringName = &""
	var t := 0.0
	var body := fighter.body
	if fighter.blocking:
		name = &"FP_ShieldBlock" if fam == &"shield" else &"FP_Block"
		t = fmod(_clock, 1.0)
	elif body.action != &"":
		name = fp_move_for(body.action)
		var length := maxf(BlockBody.move_length(body.action), 0.001)
		var u := body.action_time / length
		t = fmod(u, 1.0) if bool(BlockBody.move_info(body.action).get("loop", false)) else warp(clampf(u, 0.0, 1.0), body.action, name)
	if name == &"" and _equip < 1.0:
		name = &"FP_Equip"
		t = _equip
	var off: Array = sample(name, t) if name != &"" else [Vector3.ZERO, Vector3.ZERO]

	# Sway: the weapon lags a little behind the turning view.
	var rot := Vector2(camera.global_rotation.y, camera.global_rotation.x)
	if _last_rot != Vector2.INF:
		var d := Vector2(wrapf(rot.x - _last_rot.x, -PI, PI), rot.y - _last_rot.y)
		_sway_vel += Vector2(d.x, d.y) * 6.0
	_last_rot = rot
	_sway_vel += (-_sway * 120.0 - _sway_vel * 16.0) * delta
	_sway += _sway_vel * delta
	_sway = _sway.limit_length(0.25)

	# Bob with the stride; a dip on landing.
	var hs := fighter.hspeed()
	var on_floor := fighter.is_on_floor()
	if on_floor and hs > 0.5:
		_bob += delta * (6.0 + hs * 0.9)
	var amp := clampf(hs / 7.0, 0.0, 1.0) * (1.0 if on_floor else 0.3)
	var bob := Vector3(sin(_bob) * 0.012 * amp, -absf(cos(_bob)) * 0.016 * amp, 0.0)
	if on_floor and not _was_floor:
		_land = 1.0
	_was_floor = on_floor
	_land = maxf(_land - delta * 4.0, 0.0)
	var breathe := sin(_clock * 1.6) * 0.004

	# Near a wall: pull back and raise the tip so nothing pokes through.
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 1.1, Game.L_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var want := 0.0
	if not hit.is_empty():
		want = clampf(1.0 - (from.distance_to(hit["position"]) - 0.25) / 0.85, 0.0, 1.0)
	_retract = move_toward(_retract, want, delta * 5.0)

	# Sway turns the tip against the turn; near a wall the tip goes up.
	var extra_aim := Vector3(-_sway.x * 0.8, -_sway.y * 0.8 + deg_to_rad(40.0) * _retract, _sway.x * 0.6)
	var extra := bob + Vector3(0.0, breathe - _land * 0.06, 0.0) \
		+ Vector3(_sway.x * 0.15, -_sway.y * 0.12, 0.0) + Vector3(0.0, -0.05, 0.28) * _retract
	_place(fam, off, extra_aim, extra)
	# The power-ready glow, as on the real weapon.
	var glow: Variant = fighter.weapon_visual.get_instance_shader_parameter(&"charge") if fighter.weapon_visual else null
	for m in _meshes:
		m.set_instance_shader_parameter(&"charge", glow if glow is Color else Color(0, 0, 0, 0))


## Rest pose + move offset (+ procedural extras) -> the weapon's transform;
## a pair (pistols, gloves) gets a mirror image on the left.
func _place(fam: StringName, off: Array, extra_aim: Vector3, extra_pos: Vector3) -> void:
	if _pivots.is_empty():
		return
	var rest: Array = REST.get(fam, REST[&"blade"])
	var aim: Vector3 = (rest[1] as Vector3) * (PI / 180.0) + (off[1] as Vector3) + extra_aim
	var pos: Vector3 = (rest[0] as Vector3) + (off[0] as Vector3) + extra_pos
	var xf := Transform3D(aim_basis(aim), pos)
	_pivots[0].transform = xf
	if _pivots.size() > 1:
		var mirror := Basis.from_scale(Vector3(-1, 1, 1))
		_pivots[1].transform = Transform3D(mirror * xf.basis * mirror, Vector3(-pos.x, pos.y, pos.z))


func _preview() -> void:
	if preview_weapon != _weapon:
		_set_weapon(preview_weapon)
	visible = true
	var off: Array = sample(preview_move, preview_t) if preview_move != &"" else [Vector3.ZERO, Vector3.ZERO]
	_place(family(_weapon), off, Vector3.ZERO, Vector3.ZERO)
