extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	await process_frame
	assert(not game.player.get_child(1).visible, "Player model must be hidden in first person")
	assert(game.camera.global_position.distance_to(game.player.global_position + Vector3.UP * 1.62) < 0.2, "Camera is not at eye height")
	var lobby_actions := ["schedule", "shoes", "towel", "tea", "map", "radio", "bell", "light", "pass", "note"]
	for id in lobby_actions:
		for point in game.interaction_points:
			if point["id"] == id:
				game.player.position = point["at"] + Vector3.UP * 0.05
				game.story_open = false
				game._interact()
				break
	assert(game.quiet_steps and game.towel_cover and game.route_known and game.radio_on and game.lights_dim, "Lobby action effects failed")
	assert(game.story_flags.get("note", false) and game.clues == 1, "Story clue failed")
	game.player.position = Vector3(5, 0.05, -11.3)
	game._check_goal()
	assert(game.chapter == 2 and not game.finished, "First doorway should continue the story")
	game.story_open = false
	game.player.position = Vector3(3.8, 0.05, -16.0)
	game._interact()
	assert(game.story_flags.get("key", false), "Archive key failed")
	game.player.position = Vector3(5.8, 0.05, -19.4)
	game._interact()
	assert(game.chapter == 3 and game.clues == 2, "Archive chapter failed")
	game.story_open = false
	game.player.position = Vector3(0, 0.05, 5.4)
	game._check_goal()
	assert(game.chapter == 4 and not game.finished, "Return chapter failed")
	print("GAMEPLAY_SMOKE_OK")
	quit(0)
