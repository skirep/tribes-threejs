extends SceneTree
func _initialize() -> void:
	var actions := OpenXRActionMap.new()
	actions.create_default_action_sets()
	var result := ResourceSaver.save(actions, "res://openxr_action_map.tres")
	if result != OK:
		push_error("Could not save OpenXR action map")
		quit(1)
	else:
		quit(0)
