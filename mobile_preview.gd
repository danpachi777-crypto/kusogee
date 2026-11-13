extends SceneTree


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var game = load("res://main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	await process_frame
	DisplayServer.window_set_title("温泉宿の消えた記録 - スマホ操作プレビュー")
	game._show_story("第一章　消えた入館記録\n幼なじみが残した手紙には、温泉宿で消えた記録を探してほしいとあった。\n主人公は変装して宿へ。受付や館内を調べ、奥の入口を目指す。")
