extends Node
## Dev: screenshots of the Multiplayer screen and the host's lobby.
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
	title.call(&"_show", title.get(&"_mp"))
	await get_tree().create_timer(1.5).timeout
	await _shot(out, "mp_menu")
	Net.host("Tablet", &"rage")
	title.call(&"_show", title.get(&"_lobby"))
	await get_tree().create_timer(0.8).timeout
	await _shot(out, "mp_lobby")
	Net.leave()
	get_tree().quit()
