extends Node

func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

# You can expand this later to add fades:
func goto_scene_with_fade(_path: String, _fade_duration: float = 1.5) -> void:
	# fade out, change scene, fade in
	pass
