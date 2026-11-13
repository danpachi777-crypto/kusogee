extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _use(game: Node, id: String) -> void:
	for point in game.campaign_points:
		if point["id"] == id:
			game.story_open = false
			game.player.position = point["at"] + Vector3.UP * 0.05
			assert(game._interact_campaign(), "Cannot interact with " + id)
			return
	assert(false, "Missing point " + id)


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.testing = true
	root.add_child(game)
	await process_frame
	game._advance_campaign(4)
	for id in ["call_a", "call_b", "call_c", "call_order"]:
		_use(game, id)
	game._campaign_choice(0)
	assert(game.chapter == 4, "Wrong phone order should allow retry")
	_use(game, "call_order")
	game._campaign_choice(1)
	game.story_open = false
	game.player.position = Vector3(35, 0.05, 4.5)
	game._campaign_goal()
	assert(game.chapter == 6 and game.story_flags.get("footprints", false), "Wet crossing branch failed")
	for id in ["ledger_a", "ledger_b", "ledger_compare"]:
		_use(game, id)
	game._campaign_choice(1)
	assert(game.chapter == 6, "Wrong ledger answer should allow retry")
	_use(game, "ledger_compare")
	game._campaign_choice(0)
	_use(game, "night_staff")
	game._campaign_choice(0)
	assert(game.chapter == 8 and not game.story_flags.get("night_trust", false), "Staff distrust branch failed")
	_use(game, "breaker")
	game._campaign_choice(1)
	assert(game.lights_dim, "Dark route failed")
	for id in ["guest_1", "guest_2", "guest_3", "testimony_compare"]:
		_use(game, id)
	game._campaign_choice(0)
	assert(game.chapter == 10 and not game.story_flags.get("guest_reliable", false), "Unreliable testimony branch failed")
	for id in ["old_photo", "old_plan", "sealed_room"]:
		_use(game, id)
	game._campaign_choice(2)
	assert(game.chapter == 10, "Wrong photo answer should allow retry")
	_use(game, "sealed_room")
	game._campaign_choice(0)
	_use(game, "caretaker")
	game._campaign_choice(1)
	assert(game.chapter == 12 and not game.story_flags.get("caretaker_help", false), "Caretaker refusal branch failed")
	_use(game, "copy_start")
	game.story_open = false
	game.copy_time = 0.01
	await create_timer(0.2).timeout
	assert(game.chapter == 13 and game.story_flags.get("copy_incomplete", false), "Copy timeout branch failed")
	_use(game, "truth")
	game._campaign_choice(0)
	assert(game.chapter == 14 and game.story_flags.get("ending", "") == "早すぎる告発", "Weak evidence ending failed")
	_use(game, "next_place")
	game._campaign_choice(1)
	assert(game.chapter == 15 and game.story_flags.get("next_destination", "") == "町役場の記録室", "Town branch failed")
	for id in ["town_docket", "town_register", "town_compare"]:
		_use(game, id)
	game._campaign_choice(1)
	assert(game.chapter == 16 and game.story_flags.get("revised_ending", "") == "追加の原本で裏付け完了", "Town recovery failed")
	print("CAMPAIGN_BRANCH_SMOKE_OK")
	quit(0)
