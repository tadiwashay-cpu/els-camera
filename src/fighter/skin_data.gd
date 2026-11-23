class_name SkinData
extends Resource
## A fighter's look. Skins are data, not models: BlockBody builds the
## body from these colours and proportions.

@export var id: StringName = &"ember"
@export var display_name := "Ember"
@export var skin := Color(0.96, 0.78, 0.6)
@export var shirt := Color(0.95, 0.45, 0.12)
@export var sleeve := Color(0.85, 0.35, 0.1)
@export var belt := Color(0.15, 0.13, 0.12)
@export var pants := Color(0.2, 0.22, 0.3)
@export var shoes := Color(0.12, 0.12, 0.14)
@export var eyes := Color(0.08, 0.08, 0.1)
@export var trail := Color(1.0, 0.7, 0.3)
## Head size multiplier (big heads read better at a distance).
@export_range(0.8, 1.4) var head_scale := 1.1
## Width of torso and limbs.
@export_range(0.8, 1.3) var bulk := 1.0
@export var unlock_cost := 0
## Customisation (Look): hair style and colour, hat and its colour, face.
@export var hair := &"band"
@export var hair_color := Color(0.12, 0.09, 0.07)
@export var hat := &"none"
@export var hat_color := Color(0.2, 0.25, 0.6)
@export var face := &"fierce"


func color(role: StringName) -> Color:
	match role:
		&"skin": return skin
		&"shirt": return shirt
		&"sleeve": return sleeve
		&"belt": return belt
		&"pants": return pants
		&"shoes": return shoes
		&"eyes": return eyes
	return Color.MAGENTA
