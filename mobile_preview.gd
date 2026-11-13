extends SceneTree


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	Input.emulate_touch_from_mouse = false
	var game = load("res://main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	await process_frame
	DisplayServer.window_set_title("温泉宿の消えた記録 - スマホ操作プレビュー")
	game._show_status("第一章から開始。左側をドラッグして移動、右側をドラッグして見回す。")
