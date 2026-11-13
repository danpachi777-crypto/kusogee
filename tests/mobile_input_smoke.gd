extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	return event


func _drag(index: int, at: Vector2, motion: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.screen_relative = motion
	return event


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	await process_frame
	game._input(_touch(0, Vector2(170, 530), true))
	game._input(_drag(0, Vector2(170, 430), Vector2(0, -100)))
	assert(game.move_touch_vector.y > 0.9, "Left swipe did not set forward movement")
	var previous_yaw: float = game.camera_yaw
	game._input(_touch(1, Vector2(950, 350), true))
	game._input(_drag(1, Vector2(1010, 375), Vector2(60, 25)))
	assert(game.camera_yaw < previous_yaw and game.camera_pitch < 0.0, "Right swipe did not orbit camera")
	assert(game.move_touch_vector.y > 0.9, "Looking interrupted left movement")
	var old_position: Vector3 = game.player.global_position
	await create_timer(0.35).timeout
	assert(game.player.global_position.distance_to(old_position) > 0.1, "Swipe movement did not move player")
	game._input(_touch(0, Vector2(170, 430), false))
	assert(game.move_touch_vector == Vector2.ZERO and game.look_touch_index == 1, "Finger release state failed")
	game._input(_touch(1, Vector2(1010, 375), false))
	assert(game.look_touch_index == -1, "Camera finger release failed")
	var view: Vector2 = game.get_viewport().get_visible_rect().size
	game._input(_touch(2, Vector2(view.x - 60, view.y - 30), true))
	assert(game.look_touch_index == -1, "Action button area captured a camera swipe")
	print("MOBILE_INPUT_SMOKE_OK")
	quit(0)
