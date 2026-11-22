class_name Breakable
extends StaticBody3D
## A piece of the arena that can be smashed: crates, pillars, railings and
## explosive barrels. Blades, thrown weapons, bodies slammed into it and
## explosions wear it down; at 0 it bursts into physics debris, stops
## blocking (and the bots' nav mesh is rebaked), then rebuilds later so long
## matches don't end up flat.

signal broken(piece: Breakable, by: Fighter)

enum Kind { CRATE, PILLAR, RAIL, BARREL }

const STATS := {
	Kind.CRATE: {"hp": 30.0, "chunks": 7, "respawn": 30.0, "sound": &"crash_wood", "chip": Color(0.86, 0.7, 0.45)},
	Kind.PILLAR: {"hp": 70.0, "chunks": 9, "respawn": 40.0, "sound": &"crash_stone", "chip": Color(0.75, 0.76, 0.8)},
	Kind.RAIL: {"hp": 40.0, "chunks": 6, "respawn": 35.0, "sound": &"crash_stone", "chip": Color(0.7, 0.72, 0.78)},
	Kind.BARREL: {"hp": 12.0, "chunks": 6, "respawn": 40.0, "sound": &"boom", "chip": Color(1.0, 0.4, 0.2)},
}

var kind := Kind.CRATE
var size := Vector3.ONE
var color := Color.WHITE
var max_hp := 30.0
var hp := 30.0
var is_broken := false
var last_hitter: Fighter
var arena: Arena
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _wobble := 0.0
var _respawn_at := -1.0
var _clock := 0.0


func setup(k: Kind, box_size: Vector3, tint: Color, owner_arena: Arena) -> void:
	kind = k
	size = box_size
	color = tint
	arena = owner_arena
	max_hp = float(STATS[kind]["hp"]) * clampf(box_size.x * box_size.y * box_size.z, 0.6, 2.0)
	hp = max_hp
	collision_layer = Game.L_WORLD
	collision_mask = 0
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _build_mesh()
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	add_child(_shape)
	add_to_group(&"breakables")


func _build_mesh() -> Mesh:
	var b := BoxBuilder.new()
	match kind:
		Kind.CRATE:
			# Planked crate: body plus darker frame strips on the faces.
			b.box(size, Vector3.ZERO, color)
			var frame := color.darkened(0.35)
			var t := 0.06
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					b.box(Vector3(t, t, size.z + 0.01), Vector3(sx * (size.x * 0.5 - t * 0.5), sy * (size.y * 0.5 - t * 0.5), 0), frame)
					b.box(Vector3(size.x + 0.01, t, t), Vector3(0, sy * (size.y * 0.5 - t * 0.5), sx * (size.z * 0.5 - t * 0.5)), frame)
					b.box(Vector3(t, size.y + 0.01, t), Vector3(sx * (size.x * 0.5 - t * 0.5), 0, sy * (size.z * 0.5 - t * 0.5)), frame)
		Kind.BARREL:
			b.box(Vector3(size.x * 0.86, size.y, size.z * 0.86), Vector3.ZERO, color)
			b.box(Vector3(size.x, size.y * 0.12, size.z), Vector3(0, size.y * 0.25, 0), Color(1.0, 0.85, 0.15))
			b.box(Vector3(size.x, size.y * 0.12, size.z), Vector3(0, -size.y * 0.25, 0), Color(1.0, 0.85, 0.15))
			b.box(Vector3(size.x * 0.3, 0.06, size.z * 0.3), Vector3(0, size.y * 0.5 + 0.03, 0), Color(0.2, 0.2, 0.22))
		_:
			b.box(size, Vector3.ZERO, color)
			b.box(Vector3(size.x + 0.04, 0.12, size.z + 0.04), Vector3(0, size.y * 0.5 - 0.06, 0), color.lightened(0.15))
	return b.commit(BoxBuilder.vertex_color_material(0.8))


## World-space bounds (for hit tests).
func bounds() -> AABB:
	return AABB(global_position - size * 0.5, size)


## Damage from anything. `at` is where it landed, `dir` the push.
func hit(damage: float, at: Vector3, dir: Vector3, by: Fighter) -> void:
	if is_broken or damage <= 0.0:
		return
	if by:
		last_hitter = by
	hp -= damage
	_wobble = minf(_wobble + damage / max_hp * 1.5 + 0.2, 1.0)
	Fx.sparks(get_parent(), at, STATS[kind]["chip"], 8)
	Audio.play(&"hit" if kind == Kind.CRATE else &"clang", at, -6.0, 0.8 if kind == Kind.CRATE else 1.0)
	if hp <= 0.0:
		shatter(dir)


func shatter(dir: Vector3 = Vector3.ZERO) -> void:
	if is_broken:
		return
	is_broken = true
	_mesh.visible = false
	_shape.disabled = true
	collision_layer = 0
	var stats: Dictionary = STATS[kind]
	Audio.play(stats["sound"], global_position, 2.0)
	Fx.dust(get_parent(), global_position, clampf(size.length(), 0.8, 2.0))
	if arena:
		arena.debris.burst(global_position, size, color, int(stats["chunks"]), dir)
		arena.request_rebake()
	_respawn_at = _clock + float(stats["respawn"])
	broken.emit(self, last_hitter)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _wobble > 0.0:
		_wobble = maxf(_wobble - delta * 4.0, 0.0)
		var w := _wobble * 0.08
		_mesh.rotation = Vector3(sin(_clock * 47.0) * w, 0.0, cos(_clock * 53.0) * w)
	if is_broken and _respawn_at > 0.0 and _clock >= _respawn_at:
		_try_rebuild()


func _try_rebuild() -> void:
	# Never rebuild on top of someone.
	for f in get_tree().get_nodes_in_group(&"fighters"):
		var fighter := f as Fighter
		if bounds().grow(0.6).has_point(fighter.global_position + Vector3.UP * 0.9):
			_respawn_at = _clock + 2.0
			return
	is_broken = false
	hp = max_hp
	last_hitter = null
	_shape.disabled = false
	collision_layer = Game.L_WORLD
	_mesh.visible = true
	_mesh.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if arena:
		arena.request_rebake()
