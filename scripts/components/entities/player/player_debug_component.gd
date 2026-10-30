class_name PlayerDebugComponent extends PlayerComponent
## Debug keys: screenshot and HUD toggle.


func tick(_delta: float) -> void:
	if Input.is_action_just_pressed("debug2"):
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		var path := "user://screenshots/SCREENSHOT-%s.png" % Time.get_unix_time_from_system()
		get_viewport().get_texture().get_image().save_png(path)

	if Input.is_action_just_pressed("debug1"):
		player.hud.visible = not player.hud.visible
