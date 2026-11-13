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
	game.story_open = false
	var before_move: Vector3 = game.player.global_position
	game.touch["up"] = true
	await create_timer(0.45).timeout
	game.touch["up"] = false
	assert(game.player.global_position.distance_to(before_move) > 0.15, "Annex movement failed")
	for id in ["call_a", "call_b", "call_c", "call_order"]:
		_use(game, id)
	game._campaign_choice(1)
	assert(game.chapter == 5 and game.story_flags.get("phone_correct", false), "Phone puzzle failed")
	_use(game, "awning")
	game.story_open = false
	game.player.position = Vector3(30, 0.05, 4.5)
	game._campaign_goal()
	assert(game.chapter == 6 and game.story_flags.get("dry_crossing", false), "Rain route failed")
	for id in ["ledger_a", "ledger_b", "ledger_compare"]:
		_use(game, id)
	game._campaign_choice(0)
	assert(game.chapter == 7 and game.story_flags.get("ledger_match", false), "Ledger puzzle failed")
	_use(game, "night_staff")
	game._campaign_choice(1)
	assert(game.chapter == 8 and game.story_flags.get("night_trust", false), "Night staff conversation failed")
	_use(game, "breaker")
	game._campaign_choice(0)
	assert(game.chapter == 9 and not game.lights_dim, "Power choice failed")
	for id in ["guest_3", "guest_1", "guest_2", "testimony_compare"]:
		_use(game, id)
	game._campaign_choice(1)
	assert(game.chapter == 10 and game.story_flags.get("witness_bonus", false), "Guest testimony failed")
	for id in ["old_photo", "old_plan", "sealed_room"]:
		_use(game, id)
	game._campaign_choice(0)
	assert(game.chapter == 11 and game.story_flags.get("sealed_found", false), "Photo puzzle failed")
	_use(game, "caretaker")
	game._campaign_choice(0)
	assert(game.chapter == 12 and game.story_flags.get("caretaker_help", false), "Caretaker negotiation failed")
	_use(game, "copy_start")
	_use(game, "copy_align")
	game._campaign_choice(0)
	_use(game, "copy_finish")
	assert(game.chapter == 13 and game.story_flags.get("copy_success", false), "Timed copy failed")
	_use(game, "truth")
	game._campaign_choice(0)
	assert(game.chapter == 14 and game.story_flags.get("ending", "") == "公表と保護", "Branching ending failed")
	_use(game, "next_place")
	game._campaign_choice(0)
	assert(game.chapter == 15 and game.story_flags.get("next_destination", "") == "湖畔の資料館", "Next destination failed")
	game.story_open = false
	var region_start: Vector3 = game.player.global_position
	game.touch["up"] = true
	await create_timer(0.35).timeout
	game.touch["up"] = false
	assert(game.player.global_position.distance_to(region_start) > 0.1, "Lakeside movement failed")
	for id in ["lake_index", "lake_map", "lake_compare"]:
		_use(game, id)
	game._campaign_choice(0)
	assert(game.chapter == 16 and game.story_flags.get("recovered_record", false), "Lakeside follow-up failed")
	print("CAMPAIGN_SMOKE_OK")
	quit(0)
