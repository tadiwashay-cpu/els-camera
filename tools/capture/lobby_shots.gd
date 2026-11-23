extends Node
## Dev: screenshots of the Armory (a locked and an owned weapon), the
## Controls screen, the touch layout editor, the Multiplayer screen and the
## host's lobby.
##   xvfb-run -a godot --path . --resolution 1600x1000 res://tools/capture/lobby_shots.tscn -- OUT_DIR

func _shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
	print("SHOT ", n)


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	get_tree().current_scene = null
	var title := (load(Game.TITLE_SCENE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().create_timer(0.8).timeout
	var armory: ArmoryScreen = title.get(&"_armory")
	title.call(&"_show", armory)
	await get_tree().create_timer(1.5).timeout
	armory.call(&"_select", Registry.weapon(&"thunderbolt"))
	await get_tree().create_timer(0.6).timeout
	await _shot(out, "armory_locked")
	armory.call(&"_select", Registry.weapon(&"sword"))
	await get_tree().create_timer(0.6).timeout
	await _shot(out, "armory_owned")
	armory.call(&"_select", Registry.weapon(&"bazooka"))
	await get_tree().create_timer(0.6).timeout
	await _shot(out, "armory_bazooka")
	title.call(&"_refresh_bindings")
	title.call(&"_show", title.get(&"_controls"))
	await get_tree().create_timer(0.6).timeout
	await _shot(out, "controls")
	title.call(&"_open_layout_editor")
	await get_tree().create_timer(0.6).timeout
	await _shot(out, "touch_editor")
	for c in title.get(&"_ui").get_children():
		if c is TouchLayoutEditor:
			(c as TouchLayoutEditor).call(&"_cancel")
	title.call(&"_show", title.get(&"_mp"))
	await get_tree().create_timer(1.5).timeout
	await _shot(out, "mp_menu")
	Net.host("Tablet", &"rage")
	title.call(&"_show", title.get(&"_lobby"))
	await get_tree().create_timer(0.8).timeout
	await _shot(out, "mp_lobby")
	Net.leave()
	get_tree().quit()
