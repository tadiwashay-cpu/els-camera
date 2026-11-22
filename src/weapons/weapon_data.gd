class_name WeaponData
extends Resource
## One weapon: how it looks, hits, swings and flies. Adding a weapon is a
## new .tres in src/weapons/data/ plus a line in Registry; no fighter code.

@export var id: StringName = &"sword"
@export var display_name := "Sword"
@export_enum("blades", "heavy", "fists", "ranged", "thrown", "gadgets", "elemental", "joke") var family := "blades"
## melee: swings; thrown: ATTACK throws one from the stack; ranged: ATTACK fires.
@export var kind := &"melee"
## common: weapon spawners; rare: only from the mystery crate.
@export var rarity := &"common"

@export_group("Damage")
## Damage at the reference tip speed (doc: damage = base x clamp(speed / ref, 0.5, 2.5)).
@export var base_damage := 14.0
## Tip speed in m/s that deals exactly base_damage.
@export var ref_speed := 9.0
@export var mass := 1.0
@export var knockback := 5.5
## A fully charged heavy attack multiplies damage by this.
@export var heavy_multiplier := 1.7

@export_group("Moves")
## Light combo, in order (tap attack). Clip names in block_fighter.glb.
@export var light_moves: Array[StringName] = [&"Slash_A", &"Slash_B", &"Slash_C"]
## The light move that knocks down (usually the combo finisher).
@export var knockdown_move: StringName = &"Slash_C"
## Held pose while charging a heavy (empty = heavy fires at once).
@export var heavy_charge: StringName = &"Heavy_Charge"
@export var heavy_move: StringName = &"Heavy_Release"
## What lands the hit for each move: "blade" (the weapon), or a bone name.
@export var strikers: Dictionary = {}
@export var attack_speed := 1.0
## Forward push when a standing attack starts (m/s).
@export var lunge := 3.5
## Forward push of the heavy attack (spear lunges travel).
@export var heavy_lunge := 2.0
## Heavy weapons' charged slam knocks back everyone this close to the impact.
@export var slam_radius := 0.0
## Running/standing speed while holding it (heavy weapons slow you).
@export var move_speed := 1.0
## Standing pose while holding it (empty = the sword stance).
@export var idle_clip := &""
## Which hand holds it ("right"; bows are "left").
@export var hand := &"right"
## Show it on both hands (gloves).
@export var both_hands := false
## Extra sound on a hit (e.g. "clang" for the pan, "squeak").
@export var hit_sound := &""
## Iron or steel: crane magnets grab it (and whoever holds it).
@export var metal := false
## Hot: its hits, shots or blast set oil alight.
@export var ignites := false

@export_group("Hitbox")
## The striking part runs along the socket's +Y from hit_from to hit_to.
@export var hit_from := 0.15
@export var hit_to := 1.0
@export var hit_radius := 0.12

@export_group("Throwing")
@export var throwable := true
@export var catchable := true
@export var throw_speed := 24.0
@export var throw_damage := 24.0
## Spin while flying, radians per second (about the socket's X axis).
@export var throw_spin := 16.0
## Thrown/ranged: how many throws or shots (0 = one weapon, thrown whole).
@export var ammo := 0
## Blows up where it lands (bombs).
@export var explosive := false
## Comes back to the thrower (boomerang).
@export var returns := false
## Becomes a pickup where it lands (false: thrown stars and knives are spent).
@export var keep_on_land := true
@export var projectile_speed := 50.0
@export var projectile_damage := 10.0

@export_group("Look")
## Boxes in socket space (+Y runs from the grip to the tip).
@export var part_sizes := PackedVector3Array()
@export var part_centres := PackedVector3Array()
@export var part_colors := PackedColorArray()
## Turn of each part about the socket's Z axis (degrees).
@export var part_yaws := PackedFloat32Array()
## Emissive glow (plasma, gauntlet); alpha 0 = none.
@export var glow := Color(0, 0, 0, 0)
@export var unlock_cost := 0

var _mesh: ArrayMesh


func is_fists() -> bool:
	return id == &"fists"


func uses_ammo() -> bool:
	return ammo > 0


func striker(move: StringName) -> StringName:
	return StringName(strikers.get(move, "blade"))


## Damage from how fast the striking part was moving (pure, unit-tested).
static func speed_damage(base: float, tip_speed: float, ref: float) -> float:
	return base * clampf(tip_speed / maxf(ref, 0.01), 0.5, 2.5)


func mesh() -> ArrayMesh:
	if _mesh == null and part_sizes.size() > 0:
		var b := BoxBuilder.new()
		for i in part_sizes.size():
			var yaw := part_yaws[i] if i < part_yaws.size() else 0.0
			b.box(part_sizes[i], part_centres[i], part_colors[i] if i < part_colors.size() else Color.GRAY, 0,
				Basis(Vector3.BACK, deg_to_rad(yaw)))
		var mat := BoxBuilder.vertex_color_material(0.35)
		if glow.a > 0.0:
			mat.emission_enabled = true
			mat.emission = glow * 0.6
		_mesh = b.commit(mat)
	return _mesh
