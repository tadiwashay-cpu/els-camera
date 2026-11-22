class_name ArenaData
extends Resource
## An arena as the menus and loading screen see it.

@export var id: StringName = &"blockout_yard"
@export var display_name := "Blockout Yard"
@export var tagline := ""
@export var title_color := Color(1.0, 0.6, 0.2)
@export_file("*.tscn") var scene_path := ""
@export var tips: PackedStringArray = []
