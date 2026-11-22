class_name FighterInput
extends RefCounted
## What a fighter is being asked to do this frame. Touch controls, the bot
## brain and (later) the network all fill one of these; the Fighter never
## knows which.

## Stick: x = right, y = forward, relative to `aim_yaw`. Length 0..1.
var move := Vector2.ZERO
## Yaw of the view the stick is relative to (camera yaw for players).
var aim_yaw := 0.0
var sprint := false
var attack_held := false
var jump_held := false
var block_held := false
## Who to face and aim at (lock-on), or null.
var target: Node3D
## A spot to throw at instead of a fighter (bots aiming at barrels), or null.
var aim_point: Variant = null

## Buffered presses: action -> time pressed (ms).
var _presses: Dictionary = {}


func press(action: StringName) -> void:
	_presses[action] = Time.get_ticks_msec()


## True (once) if `action` was pressed within the last `buffer_ms`.
func consume(action: StringName, buffer_ms: int = 160) -> bool:
	if not _presses.has(action):
		return false
	var age: int = Time.get_ticks_msec() - int(_presses[action])
	_presses.erase(action)
	return age <= buffer_ms


func pressed_recently(action: StringName, buffer_ms: int = 160) -> bool:
	return _presses.has(action) and Time.get_ticks_msec() - int(_presses[action]) <= buffer_ms


func clear() -> void:
	move = Vector2.ZERO
	sprint = false
	attack_held = false
	jump_held = false
	block_held = false
	aim_point = null
	_presses.clear()


## The stick as a world direction on the ground plane (length 0..1).
func world_move() -> Vector3:
	var forward := Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))
	var right := Vector3(cos(aim_yaw), 0.0, -sin(aim_yaw))
	return right * move.x + forward * move.y


## Points the stick at a world direction (used by bots).
func steer(world_dir: Vector3, amount: float) -> void:
	var d := Vector3(world_dir.x, 0.0, world_dir.z)
	if d.length() < 0.001:
		move = Vector2.ZERO
		return
	d = d.normalized()
	aim_yaw = atan2(-d.x, -d.z)
	move = Vector2(0.0, clampf(amount, 0.0, 1.0))
