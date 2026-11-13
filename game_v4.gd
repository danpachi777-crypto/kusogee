extends Node3D

const FONT_PATH := "res://assets/NotoSansJP.ttf"
const WALK_SPEED := 2.55
const RUN_SPEED := 4.8
const CROUCH_SPEED := 1.35
const GUARD_SPEED := 1.45
const GUARD_ACCEL := 4.2
const SAVE_PATH := "user://onsen_story_save.json"
const HUMAN_ASSET_PATH := "res://assets/people/"
const RECEPTION_POINT := Vector3(4.4, 0, 5.4)

var player: CharacterBody3D
var player_visual: Dictionary
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := -0.22
var mouse_look := false
var guards: Array[Dictionary] = []
var suspicion := 0.0
var disguise := 0.55
var trust_time := 0.0
var coins := 2
var has_ticket := false
var mirror_used := false
var finished := false
var run_touch := false
var crouch_touch := false
var touch := {"left": false, "right": false, "up": false, "down": false, "pose": false}
var player_speed := 0.0
var status_label: Label
var hint_label: Label
var meter: ProgressBar
var inventory_label: Label
var restart_button: Button
var font: Font
var elapsed := 0.0
var chapter := 1
var clues := 0
var story_flags: Dictionary = {}
var quiet_steps := false
var towel_cover := false
var lights_dim := false
var radio_on := false
var route_known := false
var breathing := false
var guard_slow_until := 0.0
var message_time := 0.0
var breath_cooldown := 0.0
var bell_cooldown := 0.0
var testing := false
var objective_label: Label
var chapter_label: Label
var interaction_points: Array[Dictionary] = []
var story_panel: PanelContainer
var story_backdrop: ColorRect
var story_text: Label
var story_button: Button
var story_open := false
var campaign_points: Array[Dictionary] = []
var campaign_actors: Array[Dictionary] = []
var choice_buttons: Array[Button] = []
var copy_time := -1.0
var rain_footprint_timer := 0.0
var ending_text := ""
var choice_context := ""
var story_queue: Array[String] = []
var human_textures: Dictionary = {}
var washi_texture: Texture2D
var wood_texture: Texture2D
var wood_normal: Texture2D
var move_touch_index := -1
var look_touch_index := -1
var look_touch_last := Vector2.ZERO
var move_touch_origin := Vector2.ZERO
var move_touch_vector := Vector2.ZERO
var move_pad_base: Panel
var move_pad_knob: Panel
var mouse_swipe_side := -1
var mouse_swipe_origin := Vector2.ZERO
const TOUCH_RADIUS := 86.0


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	_load_human_textures()
	washi_texture = load("res://assets/textures/washi_plaster.png")
	wood_texture = load("res://assets/textures/wood_floor_worn_diff_1k.jpg")
	wood_normal = load("res://assets/textures/wood_floor_worn_nor_gl_1k.jpg")
	_build_world()
	_build_annex()
	_build_followup_regions()
	_build_player()
	_build_guards()
	_build_interactions()
	_build_campaign_points()
	_build_ui()
	_load_progress()
	_update_camera(1.0)
	_update_ui()


func _physics_process(delta: float) -> void:
	elapsed += delta
	message_time = maxf(0.0, message_time - delta)
	breath_cooldown = maxf(0.0, breath_cooldown - delta)
	bell_cooldown = maxf(0.0, bell_cooldown - delta)
	_campaign_tick(delta)
	if story_open:
		_update_camera(delta)
		return
	trust_time = maxf(0.0, trust_time - delta)
	_move_player(delta)
	_move_guards(delta)
	_check_perception(delta)
	_animate_visual(player_visual, player_speed, delta, 0.0)
	for guard in guards:
		_animate_visual(guard["visual"], (guard["velocity"] as Vector3).length(), delta, guard["head_turn"])
	for actor in campaign_actors:
		_animate_visual(actor["visual"], 0.0, delta, 0.0)
	_update_person_sprites()
	_update_camera(delta)
	_check_goal()
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_interact()
			KEY_Q:
				_throw_coin()
			KEY_B:
				_breathe()
			KEY_TAB:
				_show_journal()
			KEY_R:
				_restart_chapter()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_look = event.pressed
	if event is InputEventMouseMotion and mouse_look:
		_orbit(event.relative.x, event.relative.y)


func _input(event: InputEvent) -> void:
	if story_open:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_swipe_button(event)
	elif event is InputEventMouseMotion and mouse_swipe_side != -1:
		_handle_mouse_swipe_motion(event)


func _handle_mouse_swipe_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		if mouse_swipe_side == 0:
			move_touch_index = -1
			move_touch_vector = Vector2.ZERO
			_update_move_pad()
		mouse_swipe_side = -1
		return
	var view := get_viewport().get_visible_rect().size
	if event.position.x < view.x * 0.48 and event.position.y > view.y * 0.28:
		mouse_swipe_side = 0
		mouse_swipe_origin = event.position
		move_touch_index = 0
		move_touch_origin = event.position
		move_touch_vector = Vector2.ZERO
		_update_move_pad()
	elif event.position.x >= view.x * 0.48 and event.position.y < view.y - 120.0:
		mouse_swipe_side = 1
		mouse_swipe_origin = event.position


func _handle_mouse_swipe_motion(event: InputEventMouseMotion) -> void:
	if mouse_swipe_side == 0:
		var displacement := event.position - mouse_swipe_origin
		move_touch_vector = Vector2(displacement.x, -displacement.y).limit_length(TOUCH_RADIUS) / TOUCH_RADIUS
		_update_move_pad()
	else:
		var motion := event.relative.limit_length(56.0)
		_orbit(motion.x, motion.y)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var view := get_viewport().get_visible_rect().size
	if event.pressed:
		if move_touch_index == -1 and event.position.x < view.x * 0.48 and event.position.y > view.y * 0.28:
			move_touch_index = event.index
			move_touch_origin = event.position
			move_touch_vector = Vector2.ZERO
			_update_move_pad()
		elif look_touch_index == -1 and event.position.x >= view.x * 0.48 and event.position.y < view.y - 120.0:
			look_touch_index = event.index
			look_touch_last = event.position
	else:
		if event.index == move_touch_index:
			move_touch_index = -1
			move_touch_vector = Vector2.ZERO
			_update_move_pad()
		if event.index == look_touch_index:
			look_touch_index = -1


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == move_touch_index:
		var displacement := event.position - move_touch_origin
		move_touch_vector = Vector2(displacement.x, -displacement.y).limit_length(TOUCH_RADIUS) / TOUCH_RADIUS
		_update_move_pad()
	elif event.index == look_touch_index:
		var motion := event.screen_relative
		if motion.length() > 80.0:
			motion = event.position - look_touch_last
		look_touch_last = event.position
		motion = motion.limit_length(56.0)
		_orbit(motion.x, motion.y)


func _update_move_pad() -> void:
	if move_pad_base == null or move_pad_knob == null:
		return
	move_pad_base.visible = true
	move_pad_knob.visible = true
	if move_touch_index == -1:
		move_pad_base.position = Vector2(58, 493)
		move_pad_knob.position = Vector2(118, 553)
		return
	move_pad_base.position = move_touch_origin - Vector2(TOUCH_RADIUS, TOUCH_RADIUS)
	move_pad_knob.position = move_touch_origin + Vector2(move_touch_vector.x, -move_touch_vector.y) * TOUCH_RADIUS - Vector2(26, 26)


func _clear_touch_swipes() -> void:
	move_touch_index = -1
	look_touch_index = -1
	move_touch_vector = Vector2.ZERO
	_update_move_pad()


func _orbit(dx: float, dy: float) -> void:
	camera_yaw -= dx * 0.005
	camera_pitch = clampf(camera_pitch - dy * 0.0035, -1.1, 1.1)


func _build_world() -> void:
	var lobby: Node3D = load("res://assets/onsen_lobby.glb").instantiate()
	for mesh: MeshInstance3D in lobby.find_children("*", "MeshInstance3D", true, false):
		var object_name := str(mesh.name)
		if object_name.begins_with("lounge ") or object_name.begins_with("table leg") or object_name.begins_with("tea cup"):
			mesh.visible = false
	add_child(lobby)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("142023")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e9e7e2")
	env.ambient_light_energy = 0.58
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color("f8f2e8")
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	add_child(sun)
	for point in [Vector3(-6.8, 3.5, 1.2), Vector3(6.8, 3.5, -4.7), Vector3(0, 3.5, -8.0), Vector3(-4.5, 3.4, 4.5), Vector3(4.5, 3.4, 4.5)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.light_color = Color("ffc883")
		lamp.light_energy = 0.60
		lamp.omni_range = 8.0
		lamp.shadow_enabled = true
		add_child(lamp)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.08
	add_child(camera)
	camera.current = true
	_block("floor", Vector3(0, -0.15, 0), Vector3(20, 0.3, 24))
	_block("left wall", Vector3(-10, 1.5, 0), Vector3(0.3, 3, 24))
	_block("right wall", Vector3(10, 1.5, 0), Vector3(0.3, 3, 24))
	_block("front wall", Vector3(0, 1.5, 12), Vector3(20, 3, 0.3))
	for item in [[-8.5, 3.0], [0.0, 6.0], [8.5, 3.0]]:
		_block("rear wall", Vector3(item[0], 1.5, -11.7), Vector3(item[1], 3, 0.35))
	_block("counter", Vector3(4.4, 0.56, 4), Vector3(3.6, 1.12, 1.05))
	_block("screen A", Vector3(-6.8, 1.05, -7), Vector3(2.4, 2.1, 0.24))
	_block("screen B", Vector3(6.8, 1.05, -6), Vector3(2.4, 2.1, 0.24))
	_block("lounge table", Vector3(-5, 0.45, 3), Vector3(1.15, 0.9, 0.75))
	for chair in [Vector3(-6.5, 0.49, 3), Vector3(-3.5, 0.49, 3), Vector3(-5, 0.49, 4.7)]:
		_block("lounge chair", chair, Vector3(1.1, 0.98, 1.15))
	_block("rear lounge table", Vector3(-5, 0.45, -3.5), Vector3(1.15, 0.9, 0.75))
	for chair in [Vector3(-6.5, 0.49, -3.5), Vector3(-3.5, 0.49, -3.5), Vector3(-5, 0.49, -5.2)]:
		_block("rear lounge chair", chair, Vector3(1.1, 0.98, 1.15))
	for x in [-7.8, 7.8]:
		_block("bench", Vector3(x, 0.45, 1.8), Vector3(2.5, 0.9, 0.7))
	_block("mirror stool", Vector3(-7.5, 0.45, -2), Vector3(0.8, 0.9, 0.8))
	_box_prop("cedar ceiling", Vector3(0, 4.17, 0), Vector3(19.8, 0.18, 23.5), Color("8d7458"))
	# A small service passage makes the second chapter a playable place.
	_box_prop("passage floor", Vector3(5, -0.13, -17.2), Vector3(4.0, 0.26, 10.5), Color("56615e"))
	_box_prop("passage left wall", Vector3(2.85, 1.4, -17.2), Vector3(0.25, 2.8, 10.5), Color("aa987d"))
	_box_prop("passage right wall", Vector3(7.15, 1.4, -17.2), Vector3(0.25, 2.8, 10.5), Color("aa987d"))
	_box_prop("passage end wall", Vector3(5, 1.4, -22.5), Vector3(4.5, 2.8, 0.25), Color("aa987d"))
	_box_prop("archive cabinet", Vector3(5.9, 0.9, -19.9), Vector3(1.2, 1.8, 0.65), Color("614637"))
	_box_prop("small desk", Vector3(3.8, 0.75, -16.0), Vector3(1.0, 0.14, 1.0), Color("866446"))
	_add_lobby_windows()
	_add_lobby_plants()
	_add_lounge_furniture()
	var passage_light := OmniLight3D.new()
	passage_light.position = Vector3(5, 2.45, -17)
	passage_light.light_color = Color("ffe0a4")
	passage_light.light_energy = 0.85
	passage_light.omni_range = 8.0
	add_child(passage_light)


func _box_prop(name: String, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if "wall" in name and name != "sealed wall":
		material.albedo_color = Color.WHITE
		material.albedo_texture = washi_texture
		material.roughness = 0.92
		material.uv1_scale = Vector3(maxf(1.0, maxf(dimensions.x, dimensions.z) / 3.0), 1.0, 1.0)
	elif "floor" in name or "ceiling" in name:
		if "ceiling" in name:
			material.albedo_color = Color(0.87, 0.82, 0.75)
		material.albedo_texture = wood_texture
		material.normal_enabled = true
		material.normal_texture = wood_normal
		material.roughness = 0.73
		material.uv1_scale = Vector3(maxf(1.0, dimensions.x / 3.0), maxf(1.0, dimensions.z / 3.0), 1.0)
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	_block(name + " collision", at, dimensions)


func _add_lobby_windows() -> void:
	for window in [
		{"x": 9.80, "z": 3.6, "texture": "garden_day.png", "yaw": -PI / 2.0},
		{"x": 9.80, "z": -3.6, "texture": "garden_dusk.png", "yaw": -PI / 2.0},
		{"x": -9.80, "z": -5.2, "texture": "onsen_garden_view.png", "yaw": PI / 2.0},
	]:
		var center: float = window["z"]
		var side: float = window["x"]
		var view := Sprite3D.new()
		view.name = "Garden glazing"
		view.texture = load("res://assets/textures/" + window["texture"])
		view.pixel_size = 4.4 / float(view.texture.get_width())
		view.position = Vector3(side, 2.0, center)
		view.rotation.y = window["yaw"]
		view.shaded = false
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
		var frame_x := side - signf(side) * 0.11
		for edge_z in [center - 2.25, center, center + 2.25]:
			_decor_box("dark cedar window mullion", Vector3(frame_x, 2.0, edge_z), Vector3(0.11, 2.7, 0.08), Color("34291e"))
		for edge_y in [0.67, 3.33]:
			_decor_box("dark cedar window rail", Vector3(frame_x, edge_y, center), Vector3(0.11, 0.09, 4.55), Color("34291e"))
		_decor_box("stone window sill", Vector3(frame_x - signf(side) * 0.08, 0.67, center), Vector3(0.26, 0.07, 4.6), Color("7a7567"))


func _add_lobby_plants() -> void:
	var plant_texture: Texture2D = load("res://assets/people/lobby_maple.png")
	for at in [Vector3(-8.3, 0, 8.5), Vector3(8.3, 0, 8.5), Vector3(-8.4, 0, -8.8)]:
		var plant := Sprite3D.new()
		plant.name = "Indoor maple"
		plant.texture = plant_texture
		plant.pixel_size = 1.65 / float(plant_texture.get_height())
		plant.position = at + Vector3.UP * 0.825
		plant.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		plant.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		plant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plant)


func _add_lounge_furniture() -> void:
	var chair_scene: PackedScene = load("res://assets/models/mid_century_lounge_chair/mid_century_lounge_chair_2k.gltf")
	var table_scene: PackedScene = load("res://assets/models/chinese_tea_table/chinese_tea_table_2k.gltf")
	for z in [3.0, -3.5]:
		var table: Node3D = table_scene.instantiate()
		table.name = "Photoreal tea table"
		table.position = Vector3(-5, 0, z)
		table.scale = Vector3.ONE * 1.2
		add_child(table)
		for item in [
			{"at": Vector3(-6.5, 0, z), "yaw": -PI / 2.0},
			{"at": Vector3(-3.5, 0, z), "yaw": PI / 2.0},
			{"at": Vector3(-5, 0, z + 1.7), "yaw": 0.0},
		]:
			var chair: Node3D = chair_scene.instantiate()
			chair.name = "Photoreal lounge chair"
			chair.position = item["at"]
			chair.rotation.y = item["yaw"]
			add_child(chair)


func _build_annex() -> void:
	# The ten continuation chapters share a compact, explorable mountain annex.
	_box_prop("annex floor", Vector3(35, -0.16, 0), Vector3(26, 0.32, 30), Color("654632"))
	_box_prop("annex ceiling", Vector3(35, 3.13, 0), Vector3(26, 0.2, 30), Color("373530"))
	for x in [22.0, 48.0]:
		_box_prop("annex outer wall", Vector3(x, 1.55, 0), Vector3(0.28, 3.1, 31), Color("d8c49c"))
	for z in [-15.3, 15.3]:
		_box_prop("annex end wall", Vector3(35, 1.55, z), Vector3(26, 3.1, 0.28), Color("d8c49c"))
	_box_prop("rain walkway", Vector3(35, 0.025, 7.4), Vector3(24, 0.05, 5.2), Color("395f73"))
	for x in range(23, 48, 2):
		_decor_box("floor board", Vector3(x, 0.01, -5.0), Vector3(1.92, 0.025, 20), Color("876345"))
	for z in [-10, -5, 0, 5, 10]:
		_decor_box("ceiling beam", Vector3(35, 2.97, z), Vector3(25, 0.25, 0.28), Color("483622"))
	for x in [24.0, 46.0]:
		for z in [-11.0, -4.0, 4.0, 11.0]:
			_box_prop("cedar support", Vector3(x, 1.55, z), Vector3(0.26, 3.1, 0.26), Color("483522"))
	for table in [[28, 1, 4.0, 1.0], [42, 1, 4.0, 1.0], [27, -7, 2.8, 1.2], [43, -7, 4.5, 1.3], [27, -12, 4.0, 1.2], [43, -12, 4.0, 1.2]]:
		_box_prop("annex work table", Vector3(table[0], 0.72, table[1]), Vector3(table[2], 0.13, table[3]), Color("7b583d"))
	_box_prop("sealed wall", Vector3(35, 1.5, -13.6), Vector3(4.0, 3.0, 0.22), Color("6c665c"))
	for x in [28.0, 35.0, 42.0]:
		_decor_box("telephone pedestal", Vector3(x, 0.55, 11.8), Vector3(0.8, 1.1, 0.55), Color("574536"))
		_decor_box("telephone receiver", Vector3(x, 1.17, 11.8), Vector3(0.5, 0.12, 0.19), Color("1b2529"))
	for x in [26.0, 28.0, 42.0, 44.0]:
		_decor_box("records cabinet", Vector3(x, 1.05, -0.1), Vector3(0.9, 2.1, 0.6), Color("70543d"))
	for x in [26.0, 28.0]:
		_decor_box("photo frame", Vector3(x, 1.5, -14.9), Vector3(1.1, 0.8, 0.08), Color("d7bd8e"))
	_decor_box("power panel", Vector3(23.0, 1.3, -6.7), Vector3(0.12, 1.0, 0.75), Color("2b373b"))
	_decor_box("copy machine", Vector3(43.0, 1.0, -12.0), Vector3(1.2, 0.5, 0.9), Color("b4c5c0"))
	_decor_box("copy light", Vector3(43.0, 1.28, -11.75), Vector3(0.65, 0.03, 0.3), Color("84ded5"))
	for spot in [[27,-12],[43,-12],[27,-1],[43,-1],[35,10]]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(spot[0], 2.55, spot[1])
		lamp.light_color = Color("ffd49b")
		lamp.light_energy = 0.78
		lamp.omni_range = 7.0
		add_child(lamp)
	for spot in [[25,7],[30,7],[35,7],[40,7],[45,7]]:
		for i in range(5):
			_decor_box("rain streak", Vector3(spot[0] + i * 0.17, 1.2 + i * 0.12, spot[1] - 0.4), Vector3(0.018, 0.65, 0.02), Color("7699a2"))
	_add_story_actor("夜勤の従業員", Vector3(42.2, 0, -2.5), 0.0)
	_add_story_actor("宿泊客", Vector3(41.2, 0, -8.8), -0.4)
	_add_story_actor("宿泊客", Vector3(44.0, 0, -8.8), 0.3)
	_add_story_actor("管理人", Vector3(27.0, 0, -10.3), 0.5)


func _decor_box(name: String, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)


func _add_story_actor(title: String, at: Vector3, yaw: float) -> void:
	var actor := Node3D.new()
	actor.name = title
	actor.position = at
	actor.rotation.y = yaw
	add_child(actor)
	var model: Node3D = load("res://assets/attendant.glb").instantiate()
	model.visible = false
	actor.add_child(model)
	var kind := "attendant_idle"
	if title == "管理人":
		kind = "caretaker"
	elif title == "宿泊客":
		kind = "guest" if campaign_actors.size() == 1 else "guest_man"
	var sprite := _make_person_sprite(kind)
	actor.add_child(sprite)
	actor.add_child(_make_person_shadow())
	campaign_actors.append({"node": actor, "visual": _visual_nodes(model), "sprite": sprite})


func _build_followup_regions() -> void:
	for origin in [65.0, -35.0]:
		var lakeside: bool = origin > 0.0
		var wall_color := Color("a9c1bc") if lakeside else Color("c2b493")
		_box_prop("regional floor", Vector3(origin, -0.15, 3), Vector3(15, 0.3, 16), Color("676663") if lakeside else Color("806448"))
		_box_prop("regional ceiling", Vector3(origin, 3.1, 3), Vector3(15, 0.2, 16), Color("4c5654"))
		for x in [origin - 7.5, origin + 7.5]:
			_box_prop("regional side wall", Vector3(x, 1.55, 3), Vector3(0.25, 3.1, 16.5), wall_color)
		for z in [-5.0, 11.0]:
			_box_prop("regional end wall", Vector3(origin, 1.55, z), Vector3(15, 3.1, 0.25), wall_color)
		for x in [origin - 4, origin + 4]:
			_decor_box("archive shelves", Vector3(x, 1.0, 0), Vector3(1.8, 2.0, 0.6), Color("455f61") if lakeside else Color("71563d"))
			_decor_box("archive files", Vector3(x, 1.2, 0.35), Vector3(1.4, 0.65, 0.14), Color("d6c59b"))
		_decor_box("archive desk", Vector3(origin, 0.65, 4), Vector3(2.2, 0.15, 1.1), Color("846547"))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(origin, 2.6, 3)
		lamp.light_color = Color("d8f0ed") if lakeside else Color("ffe0b2")
		lamp.light_energy = 1.1
		lamp.omni_range = 11.0
		add_child(lamp)


func _block(name: String, at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 2
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.05, 8.0)
	player.collision_layer = 1
	player.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.75
	collision.shape = shape
	collision.position.y = 0.88
	player.add_child(collision)
	var model: Node3D = load("res://assets/player.glb").instantiate()
	model.rotation.y = PI
	player.add_child(model)
	model.visible = false
	add_child(player)
	player_visual = _visual_nodes(model)


func _build_guards() -> void:
	_add_guard(Vector3(7.0, 0, 3.0), Vector3(7.0, 0, -1.8))
	_add_guard(Vector3(-5.8, 0, -6.6), Vector3(5.8, 0, -6.6))
	_add_guard(Vector3(35, 0, 2.0), Vector3(35, 0, -9.5))


func _add_guard(start: Vector3, end: Vector3) -> void:
	var actor := Node3D.new()
	actor.name = "Attendant"
	actor.position = start
	var model: Node3D = load("res://assets/attendant.glb").instantiate()
	model.rotation.y = PI
	model.visible = false
	actor.add_child(model)
	var sprite := _make_person_sprite("attendant_idle")
	actor.add_child(sprite)
	actor.add_child(_make_person_shadow())
	add_child(actor)
	guards.append({
		"node": actor, "visual": _visual_nodes(model), "sprite": sprite,
		"a": start, "b": end, "to_b": true,
		"velocity": Vector3.ZERO, "facing": (end - start).normalized(),
		"pause": 0.0, "investigate": 0.0, "target": start,
		"head_turn": 0.0, "talk_cooldown": 0.0
	})


func _visual_nodes(model: Node3D) -> Dictionary:
	var result := {"root": model.find_child("body_root", true, false), "phase": 0.0}
	for part in ["left_hip", "right_hip", "left_knee", "right_knee", "left_shoulder", "right_shoulder", "head_joint"]:
		result[part] = model.find_child(part, true, false)
	return result


func _load_human_textures() -> void:
	for kind in ["attendant_idle", "attendant_walk", "attendant_back", "caretaker", "guest", "guest_man"]:
		human_textures[kind] = load(HUMAN_ASSET_PATH + kind + ".png")


func _make_person_sprite(kind: String) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = "Photo person"
	sprite.texture = human_textures[kind]
	sprite.pixel_size = 1.82 / float(sprite.texture.get_height())
	sprite.position.y = 0.91
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


func _make_person_shadow() -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "Ground shadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.32
	disc.bottom_radius = 0.32
	disc.height = 0.01
	shadow.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.02, 0.02, 0.27)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	shadow.position.y = 0.03
	return shadow


func _update_person_sprites() -> void:
	for guard in guards:
		var sprite: Sprite3D = guard["sprite"]
		var actor: Node3D = guard["node"]
		var speed: float = (guard["velocity"] as Vector3).length()
		var toward := player.global_position - actor.global_position
		var facing: Vector3 = guard["facing"]
		var face_visible := toward.length() < 0.01 or facing.dot(toward.normalized()) > -0.1
		var kind := "attendant_back" if not face_visible else "attendant_walk" if speed > 0.25 else "attendant_idle"
		sprite.texture = human_textures[kind]
		sprite.position.y = 0.91 + absf(sin(elapsed * 5.5)) * minf(speed, 1.0) * 0.028
		sprite.flip_h = speed > 0.25 and sin(elapsed * 5.5) < 0.0
	for actor in campaign_actors:
		var sprite: Sprite3D = actor["sprite"]
		sprite.position.y = 0.91 + sin(elapsed * 1.2) * 0.007


func _build_interactions() -> void:
	# Ten lobby choices, then two archive actions for the next chapter.
	_add_point("schedule", "勤務表を読む", Vector3(-8.0, 0, 5.3), 1)
	_add_point("shoes", "静かな履物に替える", Vector3(8.0, 0, 6.1), 1)
	_add_point("towel", "タオルを持つ", Vector3(7.8, 0, 1.8), 1)
	_add_point("tea", "お茶を飲んで落ち着く", Vector3(-7.8, 0, 1.8), 1)
	_add_point("map", "館内図を調べる", Vector3(-8.0, 0, -5.0), 1)
	_add_point("radio", "ラジオを切り替える", Vector3(8.0, 0, -2.2), 1)
	_add_point("bell", "受付の呼び鈴を鳴らす", Vector3(2.1, 0, 5.3), 1)
	_add_point("light", "照明を切り替える", Vector3(8.0, 0, -6.1), 1)
	_add_point("pass", "落とし物の入館証を確認", Vector3(-4.7, 0, 3.5), 1)
	_add_point("note", "古い伝言を読む", Vector3(-7.8, 0, -8.3), 1)
	_add_point("key", "棚の鍵を見つける", Vector3(3.8, 0, -16.0), 2)
	_add_point("ledger", "失踪者の台帳を調べる", Vector3(5.8, 0, -19.4), 2)


func _add_point(id: String, title: String, at: Vector3, from_chapter: int) -> void:
	interaction_points.append({"id": id, "title": title, "at": at, "chapter": from_chapter})
	var marker := MeshInstance3D.new()
	marker.name = "Interact " + id
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.09
	cylinder.bottom_radius = 0.12
	cylinder.height = 0.34
	marker.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d8b26a") if from_chapter == 1 else Color("86b6ad")
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.3
	marker.material_override = material
	marker.position = at + Vector3.UP * 0.23
	add_child(marker)


func _build_campaign_points() -> void:
	_add_campaign_point(4, "call_a", "録音Aを聞く", Vector3(28, 0, 11.8))
	_add_campaign_point(4, "call_b", "録音Bを聞く", Vector3(35, 0, 11.8))
	_add_campaign_point(4, "call_c", "録音Cを聞く", Vector3(42, 0, 11.8))
	_add_campaign_point(4, "call_order", "通話の順序を整理する", Vector3(35, 0, 9.5))
	_add_campaign_point(5, "awning", "雨よけのひさしを開く", Vector3(30, 0, 9.0))
	_add_campaign_point(5, "boots", "防水の履物を選ぶ", Vector3(40, 0, 9.0))
	_add_campaign_point(6, "ledger_a", "古い台帳を読む", Vector3(28, 0, 1.8))
	_add_campaign_point(6, "ledger_b", "新しい台帳を読む", Vector3(42, 0, 1.8))
	_add_campaign_point(6, "ledger_compare", "二冊を照合する", Vector3(35, 0, 1.0))
	_add_campaign_point(7, "night_staff", "夜勤の従業員と話す", Vector3(42.2, 0, -2.5))
	_add_campaign_point(8, "breaker", "分電盤を調べる", Vector3(27, 0, -6.7))
	_add_campaign_point(9, "guest_1", "旅人の証言を聞く", Vector3(40.0, 0, -8.4))
	_add_campaign_point(9, "guest_2", "常連客の証言を聞く", Vector3(43.0, 0, -8.4))
	_add_campaign_point(9, "guest_3", "記者の証言を聞く", Vector3(46.0, 0, -8.4))
	_add_campaign_point(9, "testimony_compare", "証言を整理する", Vector3(43.0, 0, -6.0))
	_add_campaign_point(10, "old_photo", "古い写真を調べる", Vector3(26.0, 0, -11.0))
	_add_campaign_point(10, "old_plan", "改築図を調べる", Vector3(29.0, 0, -11.0))
	_add_campaign_point(10, "sealed_room", "封鎖された壁を調べる", Vector3(35.0, 0, -12.0))
	_add_campaign_point(11, "caretaker", "管理人と交渉する", Vector3(27.0, 0, -9.7))
	_add_campaign_point(12, "copy_start", "証拠の複写を始める", Vector3(42.0, 0, -10.6))
	_add_campaign_point(12, "copy_align", "原本の位置を合わせる", Vector3(43.0, 0, -10.6))
	_add_campaign_point(12, "copy_finish", "複写して原本を戻す", Vector3(44.5, 0, -10.6))
	_add_campaign_point(13, "truth", "集めた証拠から結論を選ぶ", Vector3(35.0, 0, -12.0))
	_add_campaign_point(14, "next_place", "次の目的地を確認する", Vector3(35.0, 0, 11.0))
	_add_campaign_point(15, "lake_index", "資料館の目録を読む", Vector3(62.5, 0, 6.5))
	_add_campaign_point(15, "lake_map", "古い境界図を調べる", Vector3(67.5, 0, 3.0))
	_add_campaign_point(15, "lake_compare", "境界図を照合する", Vector3(65.0, 0, 0.5))
	_add_campaign_point(15, "town_docket", "町役場の受理簿を読む", Vector3(-37.5, 0, 6.5))
	_add_campaign_point(15, "town_register", "封印された登記を調べる", Vector3(-32.5, 0, 3.0))
	_add_campaign_point(15, "town_compare", "登記を照合する", Vector3(-35.0, 0, 0.5))
	_add_campaign_point(16, "lake_epilogue", "資料館で次の事件を確認する", Vector3(65.0, 0, 7.0))
	_add_campaign_point(16, "town_epilogue", "町役場で次の事件を確認する", Vector3(-35.0, 0, 7.0))
	_refresh_campaign_markers()


func _add_campaign_point(needed_chapter: int, id: String, title: String, at: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "Story " + id
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7dc7c1")
	material.emission_enabled = true
	material.emission = Color("307e80")
	marker.material_override = material
	marker.position = at + Vector3.UP * 0.35
	add_child(marker)
	campaign_points.append({"chapter": needed_chapter, "id": id, "title": title, "at": at, "marker": marker})


func _refresh_campaign_markers() -> void:
	for point in campaign_points:
		(point["marker"] as MeshInstance3D).visible = _campaign_point_active(point)


func _campaign_point_active(point: Dictionary) -> bool:
	if int(point["chapter"]) != chapter:
		return false
	var id: String = point["id"]
	if chapter >= 15:
		if id.begins_with("lake"):
			return story_flags.get("next_destination", "") == "湖畔の資料館"
		if id.begins_with("town"):
			return story_flags.get("next_destination", "") == "町役場の記録室"
	return true


func _nearest_campaign_point() -> Dictionary:
	var result: Dictionary = {}
	var best := 1.75
	for point in campaign_points:
		if not _campaign_point_active(point):
			continue
		var distance := player.global_position.distance_to(point["at"])
		if distance < best:
			best = distance
			result = point
	return result


func _animate_visual(visual: Dictionary, speed: float, delta: float, head_turn: float) -> void:
	var blend := clampf(speed / WALK_SPEED, 0.0, 1.5)
	visual["phase"] += delta * (1.5 + speed * 3.4)
	var phase: float = visual["phase"]
	var swing := sin(phase) * 0.42 * blend
	var left_hip: Node3D = visual["left_hip"]
	var right_hip: Node3D = visual["right_hip"]
	var left_knee: Node3D = visual["left_knee"]
	var right_knee: Node3D = visual["right_knee"]
	var left_shoulder: Node3D = visual["left_shoulder"]
	var right_shoulder: Node3D = visual["right_shoulder"]
	var head: Node3D = visual["head_joint"]
	var root: Node3D = visual["root"]
	if left_hip == null or right_hip == null or root == null:
		return
	left_hip.rotation.x = swing
	right_hip.rotation.x = -swing
	left_knee.rotation.x = maxf(0.0, -swing) * 0.38
	right_knee.rotation.x = maxf(0.0, swing) * 0.38
	left_shoulder.rotation.x = -swing * 0.6
	right_shoulder.rotation.x = swing * 0.6
	root.position.y = absf(sin(phase)) * 0.035 * blend + sin(elapsed * 1.7) * 0.006
	root.rotation.z = sin(phase) * 0.016 * blend
	head.rotation.y = lerpf(head.rotation.y, head_turn + sin(elapsed * 0.7) * 0.035, minf(1.0, delta * 3.0))


func _movement_input() -> Vector2:
	var direction := move_touch_vector
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or touch["left"]:
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or touch["right"]:
		direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch["up"]:
		direction.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or touch["down"]:
		direction.y -= 1
	return direction.limit_length(1.0)


func _is_crouching() -> bool:
	return crouch_touch or Input.is_key_pressed(KEY_CTRL)


func _is_running() -> bool:
	return run_touch or Input.is_key_pressed(KEY_SHIFT)


func _is_posing() -> bool:
	return touch["pose"] or Input.is_key_pressed(KEY_SPACE)


func _move_player(delta: float) -> void:
	var input := _movement_input()
	var basis := Basis(Vector3.UP, camera_yaw)
	var target_direction := (basis * Vector3(input.x, 0, -input.y)).normalized()
	var speed := WALK_SPEED
	if _is_crouching():
		speed = CROUCH_SPEED
	elif _is_running():
		speed = RUN_SPEED
	if _is_posing():
		speed = 0.0
	var desired := target_direction * speed
	var horizontal := Vector3(player.velocity.x, 0, player.velocity.z)
	horizontal = horizontal.move_toward(desired, delta * 13.0)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	player.velocity.y = -0.1 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player_speed = Vector2(player.velocity.x, player.velocity.z).length()
	player.rotation.y = camera_yaw


func _move_guards(delta: float) -> void:
	for guard in guards:
		guard["talk_cooldown"] = maxf(0.0, guard["talk_cooldown"] - delta)
		var actor: Node3D = guard["node"]
		var destination: Vector3 = guard["b"] if guard["to_b"] else guard["a"]
		if guard["investigate"] > 0.0:
			guard["investigate"] -= delta
			destination = guard["target"]
		elif guard["pause"] > 0.0:
			guard["pause"] -= delta
		else:
			if actor.position.distance_to(destination) < 0.18:
				guard["to_b"] = not guard["to_b"]
				guard["pause"] = 0.8 + randf() * 0.8
				guard["head_turn"] = randf_range(-0.35, 0.35)
				destination = actor.position
		var delta_to := destination - actor.position
		var desired := Vector3.ZERO
		if delta_to.length() > 0.2 and guard["pause"] <= 0.0:
			desired = delta_to.normalized() * GUARD_SPEED * (0.65 if elapsed < guard_slow_until else 1.0)
		guard["velocity"] = (guard["velocity"] as Vector3).move_toward(desired, GUARD_ACCEL * delta)
		actor.position += (guard["velocity"] as Vector3) * delta
		if (guard["velocity"] as Vector3).length() > 0.1:
			var direction: Vector3 = (guard["velocity"] as Vector3).normalized()
			guard["facing"] = direction
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 5.0))
			guard["head_turn"] = lerpf(guard["head_turn"], 0.0, minf(1.0, delta * 3.0))


func _check_perception(delta: float) -> void:
	var gain := 0.0
	for guard in guards:
		var actor: Node3D = guard["node"]
		var toward := player.global_position - actor.global_position
		var distance := toward.length()
		if distance < 0.01:
			continue
		var rain_masks_steps := chapter == 5 and player.global_position.x > 23.0 and player.global_position.z > 4.5 and player.global_position.z < 10.0
		if _is_running() and player_speed > 3.0 and distance < (2.1 if quiet_steps or radio_on or rain_masks_steps else 5.0) and guard["investigate"] <= 0.0:
			guard["investigate"] = 2.4
			guard["target"] = player.global_position
			gain = maxf(gain, 6.0)
		var view_range := 4.6 if _is_crouching() else 6.7
		if lights_dim:
			view_range *= 0.8
		if distance > view_range:
			continue
		var facing: Vector3 = guard["facing"]
		if facing.dot(toward.normalized()) < 0.22:
			continue
		var eye := actor.global_position + Vector3.UP * 1.65
		var target := player.global_position + Vector3.UP * (0.75 if _is_crouching() else 1.35)
		var ray := PhysicsRayQueryParameters3D.create(eye, target, 2)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var factor := 1.2 - disguise * 0.55
		if has_ticket:
			factor *= 0.74
		if story_flags.get("pass", false):
			factor *= 0.82
		if towel_cover:
			factor *= 0.78
		if trust_time > 0.0:
			factor *= 0.55
		if _is_crouching():
			factor *= 0.55
		if _is_posing():
			factor *= 0.63
		if _is_running():
			factor *= 1.85
		gain = maxf(gain, (22.0 + (view_range - distance) * 3.0) * factor)
		guard["head_turn"] = lerpf(guard["head_turn"], 0.15, minf(1.0, delta * 3.0))
	if gain > 0.0:
		suspicion += gain * delta
	else:
		suspicion -= (25.0 if breathing else 18.0 if _is_posing() else 12.0) * delta
	breathing = false
	suspicion = clampf(suspicion, 0.0, 100.0)
	if suspicion >= 100.0:
		_caught()


func _update_camera(delta: float) -> void:
	var head_height := 1.12 if _is_crouching() else 1.62
	var bob := sin(elapsed * (7.0 if _is_running() else 5.0)) * minf(player_speed / WALK_SPEED, 1.0) * 0.018
	var desired := player.global_position + Vector3(0, head_height + bob, 0)
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 15.0))
	camera.rotation = Vector3(camera_pitch, camera_yaw, 0)


func _interact() -> void:
	if _interact_campaign():
		return
	if _interact_v3():
		return
	if finished:
		return
	var at := player.global_position
	if at.distance_to(RECEPTION_POINT) < 2.1 and not has_ticket:
		has_ticket = true
		suspicion = maxf(0.0, suspicion - 10.0)
		_show_status("受付で入館札を受け取った。視線が少し和らぐ。")
		return
	if at.distance_to(Vector3(-7.4, 0, -2.0)) < 2.2 and not mirror_used:
		mirror_used = true
		disguise = 1.0
		suspicion = maxf(0.0, suspicion - 30.0)
		_show_status("鏡で変装を整えた。しばらく落ち着いて進める。")
		return
	for guard in guards:
		var actor: Node3D = guard["node"]
		if at.distance_to(actor.global_position) < 2.2 and guard["talk_cooldown"] <= 0.0:
			guard["talk_cooldown"] = 13.0
			guard["pause"] = 2.0
			guard["velocity"] = Vector3.ZERO
			guard["facing"] = (player.global_position - actor.global_position).normalized()
			if suspicion < 58.0:
				trust_time = 10.0
				suspicion = maxf(0.0, suspicion - 18.0)
				_show_status("従業員に道を聞いた。会話で緊張がほぐれた。")
			else:
				suspicion = minf(100.0, suspicion + 14.0)
				_show_status("話しかけたが、様子を疑われた。")
			return
	_show_status("近くに調べられるものはない。")


func _throw_coin() -> void:
	if finished or story_open or coins <= 0:
		return
	coins -= 1
	var forward := -player.global_transform.basis.z
	var target := player.global_position + forward * 4.2
	target.x = clampf(target.x, -9.2, 9.2)
	target.z = clampf(target.z, -10.8, 10.8)
	target.y = 0.08
	var coin := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	coin.mesh = sphere
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("e8b354")
	gold.metallic = 0.8
	coin.material_override = gold
	coin.position = target
	add_child(coin)
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(coin):
			coin.queue_free()
	)
	for guard in guards:
		var actor: Node3D = guard["node"]
		if actor.global_position.distance_to(target) < 9.0:
			guard["target"] = target
			guard["investigate"] = 6.0
			guard["pause"] = 0.0
	_show_status("小銭の音で従業員の注意をそらした。")


func _check_goal() -> void:
	if chapter >= 4:
		_campaign_goal()
		return
	if chapter == 1 and player.global_position.z < -11.15 and player.global_position.x > 3.3 and player.global_position.x < 6.7:
		_advance_chapter(2)
		return
	if chapter == 3 and player.global_position.distance_to(RECEPTION_POINT) < 2.1:
		_advance_chapter(4)
		return
	if chapter >= 2:
		return
	if player.global_position.z < -11.15 and player.global_position.x > 3.3 and player.global_position.x < 6.7:
		_finish(true)


func _finish(won: bool) -> void:
	if finished:
		return
	finished = true
	status_label.text = "成功。女湯の入口を通った。" if won else "見つかった。もう一度挑戦しよう。"
	restart_button.visible = true
	for key in touch:
		touch[key] = false


func _show_status(message: String) -> void:
	status_label.text = message
	message_time = 7.0


func _build_ui() -> void:
	_build_ui_v3()
	return
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud)
	status_label = _label(hud, "変装して赤いのれんを目指す。", Vector2(20, 18), 22)
	status_label.custom_minimum_size = Vector2(550, 38)
	meter = ProgressBar.new()
	meter.position = Vector2(20, 61)
	meter.custom_minimum_size = Vector2(310, 22)
	meter.max_value = 100
	meter.show_percentage = false
	hud.add_child(meter)
	inventory_label = _label(hud, "", Vector2(20, 90), 18)
	hint_label = _label(hud, "", Vector2(20, 118), 18)
	_label(hud, "WASD 移動 / 右ドラッグ 視点 / Shift 走る / Ctrl しゃがむ / E 行動 / Q 小銭 / Space 平静", Vector2(20, 151), 15)
	_touch_hold(hud, "↑", "up", Vector2(104, 532), Vector2(70, 70))
	_touch_hold(hud, "←", "left", Vector2(28, 608), Vector2(70, 70))
	_touch_hold(hud, "↓", "down", Vector2(104, 608), Vector2(70, 70))
	_touch_hold(hud, "→", "right", Vector2(180, 608), Vector2(70, 70))
	_touch_toggle(hud, "走る", Vector2(800, 608), "run")
	_touch_toggle(hud, "しゃがむ", Vector2(890, 608), "crouch")
	_touch_action(hud, "小銭", Vector2(980, 608), func(): _throw_coin())
	_touch_hold(hud, "平静", "pose", Vector2(1070, 608), Vector2(82, 70))
	_touch_action(hud, "行動", Vector2(1160, 608), func(): _interact())
	restart_button = Button.new()
	restart_button.text = "もう一度"
	restart_button.custom_minimum_size = Vector2(200, 64)
	restart_button.anchor_left = 0.5
	restart_button.anchor_right = 0.5
	restart_button.anchor_top = 1.0
	restart_button.anchor_bottom = 1.0
	restart_button.offset_left = -100
	restart_button.offset_right = 100
	restart_button.offset_top = -110
	restart_button.offset_bottom = -46
	restart_button.add_theme_font_size_override("font_size", 22)
	_set_font(restart_button)
	restart_button.visible = false
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	hud.add_child(restart_button)
	_apply_safe_area(hud)


func _label(parent: Control, words: String, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff4df"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	_set_font(label)
	parent.add_child(label)
	return label


func _touch_hold(parent: Control, words: String, action: String, at: Vector2, size: Vector2) -> void:
	var button := _button(parent, words, at, size)
	button.button_down.connect(func(): touch[action] = true)
	button.button_up.connect(func(): touch[action] = false)


func _touch_toggle(parent: Control, words: String, at: Vector2, action: String) -> void:
	var button := _button(parent, words, at, Vector2(84, 70))
	button.toggle_mode = true
	if action == "run":
		button.toggled.connect(func(on: bool): run_touch = on)
	else:
		button.toggled.connect(func(on: bool): crouch_touch = on)


func _touch_action(parent: Control, words: String, at: Vector2, action: Callable) -> void:
	var button := _button(parent, words, at, Vector2(84, 70))
	button.pressed.connect(action)


func _button(parent: Control, words: String, at: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = words
	button.custom_minimum_size = size
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_top = at.y - 720.0
	button.offset_bottom = button.offset_top + size.y
	if at.x >= 700.0:
		button.anchor_left = 1.0
		button.anchor_right = 1.0
		button.offset_left = at.x - 1280.0
	else:
		button.offset_left = at.x
	button.offset_right = button.offset_left + size.x
	button.add_theme_font_size_override("font_size", 20)
	_set_font(button)
	parent.add_child(button)
	return button


func _apply_safe_area(hud: Control) -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or screen.x <= 0 or screen.y <= 0:
		return
	var view := get_viewport().get_visible_rect().size
	var left := float(safe.position.x) / float(screen.x) * view.x
	var top := float(safe.position.y) / float(screen.y) * view.y
	var right := float(screen.x - safe.end.x) / float(screen.x) * view.x
	var bottom := float(screen.y - safe.end.y) / float(screen.y) * view.y
	for child in hud.get_children():
		if child is Label or child is ProgressBar:
			child.position += Vector2(left, top)
		elif child is Button:
			if child != restart_button:
				var shift := -right if child.anchor_left >= 0.9 else left
				child.offset_left += shift
				child.offset_right += shift
			child.offset_top -= bottom
			child.offset_bottom -= bottom


func _set_font(control: Control) -> void:
	if font != null:
		control.add_theme_font_override("font", font)


func _update_ui() -> void:
	_update_ui_v3()
	return
	meter.value = suspicion
	inventory_label.text = "疑い %d%%  |  小銭 %d  |  入館札 %s" % [roundi(suspicion), coins, "あり" if has_ticket else "なし"]
	if finished:
		hint_label.text = ""
		return
	var at := player.global_position
	if at.distance_to(RECEPTION_POINT) < 2.1 and not has_ticket:
		hint_label.text = "E / 行動: 受付で入館札を受け取る"
	elif at.distance_to(Vector3(-7.4, 0, -2.0)) < 2.2 and not mirror_used:
		hint_label.text = "E / 行動: 鏡で変装を整える"
	else:
		hint_label.text = "衝立・会話・小銭・歩き方を使い分けよう"
		for guard in guards:
			if at.distance_to((guard["node"] as Node3D).global_position) < 2.2 and guard["talk_cooldown"] <= 0.0:
				hint_label.text = "E / 行動: 従業員に道を聞く"
				break


func _nearest_point() -> Dictionary:
	var nearest: Dictionary = {}
	var best := 1.7
	for point in interaction_points:
		if chapter < int(point["chapter"]):
			continue
		var distance := player.global_position.distance_to(point["at"])
		if distance < best:
			best = distance
			nearest = point
	return nearest


func _interact_v3() -> bool:
	if story_open:
		return true
	var point := _nearest_point()
	if point.is_empty():
		return false
	var id: String = point["id"]
	match id:
		"schedule":
			guard_slow_until = elapsed + 22.0
			story_flags[id] = true
			_show_status("勤務表を読んだ。交代前の巡回はしばらくゆっくりになる。")
		"shoes":
			quiet_steps = true
			story_flags[id] = true
			_show_status("履物を替えた。走っても足音が届きにくい。")
		"towel":
			towel_cover = true
			story_flags[id] = true
			_show_status("タオルを持った。自然な身支度で視線を集めにくい。")
		"tea":
			if story_flags.get(id, false):
				_show_status("お茶はもう飲んだ。")
			else:
				story_flags[id] = true
				suspicion = maxf(0.0, suspicion - 35.0)
				_show_status("温かいお茶で落ち着いた。疑いが大きく下がる。")
		"map":
			route_known = true
			story_flags[id] = true
			_show_status("館内図で従業員の巡回ルートを把握した。")
		"radio":
			radio_on = not radio_on
			story_flags[id] = radio_on
			_show_status("ラジオをつけた。足音が聞こえにくくなる。" if radio_on else "ラジオを消した。")
		"bell":
			if bell_cooldown > 0.0:
				_show_status("呼び鈴は少し待ってから使える。")
			else:
				bell_cooldown = 18.0
				_lure_guards(Vector3(2.1, 0, 4.5), 6.0)
				_show_status("呼び鈴に従業員が向かった。巡回の隙ができた。")
		"light":
			lights_dim = not lights_dim
			story_flags[id] = lights_dim
			_show_status("照明を落とした。見つかる距離が短くなる。" if lights_dim else "照明を戻した。")
		"pass":
			story_flags[id] = true
			suspicion = maxf(0.0, suspicion - 8.0)
			_show_status("落とし物の入館証を確認した。案内を尋ねる口実ができた。")
		"note":
			if not story_flags.get(id, false):
				clues += 1
			story_flags[id] = true
			_show_story("伝言の切れ端\n『帳簿は奥の保管棚へ。鍵は机の下』\n誰かが入館記録を移したらしい。")
		"key":
			story_flags[id] = true
			_show_status("机の下から保管棚の鍵を見つけた。")
		"ledger":
			if not story_flags.get("key", false):
				_show_status("保管棚には鍵がかかっている。近くの机を調べよう。")
			else:
				story_flags[id] = true
				clues += 1
				_advance_chapter(3)
	_save_progress()
	return true


func _lure_guards(target: Vector3, duration: float) -> void:
	for guard in guards:
		guard["target"] = target
		guard["investigate"] = duration
		guard["pause"] = 0.0


func _breathe() -> void:
	if story_open:
		return
	if breath_cooldown > 0.0:
		_show_status("深呼吸はあと少し待とう。")
		return
	if player_speed > 0.3:
		_show_status("立ち止まってから深呼吸しよう。")
		return
	breath_cooldown = 15.0
	suspicion = maxf(0.0, suspicion - 16.0)
	_show_status("深呼吸で動揺を抑えた。")


func _advance_chapter(next_chapter: int) -> void:
	if next_chapter >= 4:
		_advance_campaign(next_chapter)
		return
	chapter = next_chapter
	suspicion = minf(suspicion, 20.0)
	if chapter == 2:
		player.position = Vector3(5, 0.05, -12.9)
		_show_story("第二章　奥の保管通路\n入口を抜けると、無人の連絡通路が続いていた。\n消えた入館記録の手掛かりを探す。机の鍵を見つけ、保管棚を調べよう。")
	elif chapter == 3:
		_show_story("第三章　台帳の欠落\n台帳の一頁だけが破り取られている。そこには昔の利用者の名前があった。\n証拠を持って受付へ戻り、今夜の出来事を整理しよう。")
	elif chapter == 4:
		finished = false
		_show_story("第四章への予告\n受付に戻ると、記録に残っていない客から電話が入った。\n『次は山の離れで会おう』。事件はまだ続く。\n自由に館内を調べられる。Tabで記録、Rで章の最初から。")
	_save_progress()
	_update_ui_v3()


func _caught() -> void:
	suspicion = 30.0
	if chapter == 1:
		player.position = Vector3(0, 0.05, 8.0)
	elif chapter == 2 or chapter == 3:
		player.position = Vector3(5, 0.05, -13.0)
	else:
		player.position = _campaign_spawn(chapter)
	_show_story("従業員に呼び止められた。\nその場を離れ、章の開始地点からやり直す。調べた情報は残っている。")
	_save_progress()


func _restart_chapter() -> void:
	story_open = false
	suspicion = 0.0
	if chapter == 12:
		copy_time = -1.0
		story_flags.erase("copy_aligned")
		story_flags.erase("copy_started")
	player.velocity = Vector3.ZERO
	player.position = _campaign_spawn(chapter) if chapter >= 4 else Vector3(0, 0.05, 8.0) if chapter == 1 else Vector3(5, 0.05, -13.0)
	_show_status("章の開始地点に戻った。")
	_save_progress()


func _save_progress() -> void:
	if testing:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"chapter": chapter, "flags": story_flags, "clues": clues}))


func _load_progress() -> void:
	if testing:
		return
	if not FileAccess.file_exists(SAVE_PATH):
		_show_story("第一章　消えた入館記録\n幼なじみが残した手紙には、温泉宿で消えた記録を探してほしいとあった。\n主人公は変装して宿へ。受付や館内を調べ、奥の入口を目指す。")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var value = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		return
	chapter = clampi(int(value.get("chapter", 1)), 1, 16)
	story_flags = value.get("flags", {})
	clues = int(value.get("clues", 0))
	quiet_steps = story_flags.get("shoes", false)
	towel_cover = story_flags.get("towel", false)
	radio_on = story_flags.get("radio", false)
	lights_dim = story_flags.get("light", false)
	route_known = story_flags.get("map", false)
	if chapter >= 4:
		player.position = _campaign_spawn(chapter)
	elif chapter >= 2:
		has_ticket = true
		player.position = Vector3(5, 0.05, -13.0)
	_refresh_campaign_markers()
	_show_status("第%d章から再開した。Tabで記録を確認できる。" % chapter)


func _show_journal() -> void:
	if chapter >= 4:
		_show_choices("調査記録　第%d章\n今ある証拠 %d/9。どの記録を見る？" % [chapter, _evidence_score()], ["証拠と推理", "人物と信頼", "行動と次の目的"], "journal")
		return
	var found: Array[String] = []
	for point in interaction_points:
		if story_flags.get(point["id"], false):
			found.append(point["title"])
	var log_text := "記録　/　第%d章\n調べたこと: %s\n手掛かり: %d\n\n" % [chapter, "、".join(found) if not found.is_empty() else "まだない", clues]
	log_text += _objective_text()
	_show_story(log_text)


func _show_story(words: String) -> void:
	story_queue.clear()
	_display_story(words)


func _display_story(words: String) -> void:
	story_text.text = words
	_clear_touch_swipes()
	story_button.visible = true
	for button in choice_buttons:
		button.visible = false
	story_backdrop.visible = true
	story_panel.visible = true
	story_open = true
	for key in touch:
		touch[key] = false


func _show_sequence(pages: Array[String]) -> void:
	if pages.is_empty():
		return
	story_queue.clear()
	for i in range(1, pages.size()):
		story_queue.append(pages[i])
	_display_story(pages[0])


func _continue_story() -> void:
	if not story_queue.is_empty():
		_display_story(story_queue.pop_front())
		return
	story_open = false
	story_panel.visible = false
	story_backdrop.visible = false


func _objective_text() -> String:
	if chapter >= 4:
		return _campaign_objective()
	match chapter:
		1:
			return "目的: 館内を調べて奥の赤い入口へ向かう"
		2:
			return "目的: 机の鍵を探し、保管棚の台帳を調べる"
		3:
			return "目的: 証拠を持って受付へ戻る"
		_:
			return "次章: 山の離れに残された記録を追う"


func _build_ui_v3() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud)
	chapter_label = _label(hud, "", Vector2(20, 12), 25)
	objective_label = _label(hud, "", Vector2(20, 47), 19)
	status_label = _label(hud, "", Vector2(20, 82), 19)
	status_label.custom_minimum_size = Vector2(700, 32)
	meter = ProgressBar.new()
	meter.position = Vector2(20, 120)
	meter.custom_minimum_size = Vector2(290, 20)
	meter.max_value = 100
	meter.show_percentage = false
	hud.add_child(meter)
	inventory_label = _label(hud, "", Vector2(20, 147), 17)
	hint_label = _label(hud, "", Vector2(20, 181), 18)
	var crosshair := _label(hud, "+", Vector2.ZERO, 24)
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -8
	crosshair.offset_right = 8
	crosshair.offset_top = -17
	crosshair.offset_bottom = 17
	_label(hud, "左側をスワイプ: 移動 / 右側をスワイプ: 見回す / PC: WASD・右ドラッグ", Vector2(20, 217), 15)
	move_pad_base = _touch_pad(hud, 172, Color(0.87, 0.93, 0.91, 0.14), Color(0.8, 0.95, 0.92, 0.65))
	move_pad_knob = _touch_pad(hud, 52, Color(0.75, 0.94, 0.9, 0.48), Color(0.8, 0.95, 0.92, 0.8))
	_update_move_pad()
	_touch_toggle(hud, "走る", Vector2(710, 608), "run")
	_touch_toggle(hud, "しゃがむ", Vector2(800, 608), "crouch")
	_touch_action(hud, "小銭", Vector2(890, 608), func(): _throw_coin())
	_touch_action(hud, "深呼吸", Vector2(980, 608), func(): _breathe())
	_touch_action(hud, "調べる", Vector2(1070, 608), func(): _interact())
	_touch_action(hud, "記録", Vector2(1160, 608), func(): _show_journal())
	story_backdrop = ColorRect.new()
	story_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_backdrop.color = Color(0.025, 0.04, 0.045, 0.78)
	story_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	story_backdrop.visible = false
	hud.add_child(story_backdrop)
	story_panel = PanelContainer.new()
	story_panel.anchor_left = 0.5
	story_panel.anchor_right = 0.5
	story_panel.anchor_top = 0.5
	story_panel.anchor_bottom = 0.5
	story_panel.offset_left = -390
	story_panel.offset_right = 390
	story_panel.offset_top = -155
	story_panel.offset_bottom = 155
	story_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("192c2e")
	panel_style.border_color = Color("bba77d")
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(20)
	story_panel.add_theme_stylebox_override("panel", panel_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	story_panel.add_child(column)
	story_text = Label.new()
	story_text.custom_minimum_size = Vector2(750, 210)
	story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_text.add_theme_font_size_override("font_size", 24)
	_set_font(story_text)
	column.add_child(story_text)
	story_button = Button.new()
	story_button.text = "続ける"
	story_button.custom_minimum_size = Vector2(200, 52)
	story_button.add_theme_font_size_override("font_size", 23)
	_set_font(story_button)
	story_button.pressed.connect(_continue_story)
	column.add_child(story_button)
	for i in range(3):
		var option := Button.new()
		option.visible = false
		option.custom_minimum_size = Vector2(710, 44)
		option.add_theme_font_size_override("font_size", 19)
		_set_font(option)
		option.pressed.connect(Callable(self, "_campaign_choice").bind(i))
		column.add_child(option)
		choice_buttons.append(option)
	hud.add_child(story_panel)
	_apply_safe_area(hud)


func _touch_pad(parent: Control, diameter: float, fill: Color, outline: Color) -> Panel:
	var pad := Panel.new()
	pad.custom_minimum_size = Vector2(diameter, diameter)
	pad.size = Vector2(diameter, diameter)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(diameter * 0.5))
	pad.add_theme_stylebox_override("panel", style)
	pad.visible = false
	parent.add_child(pad)
	return pad


func _update_ui_v3() -> void:
	if meter == null:
		return
	meter.value = suspicion
	chapter_label.text = "温泉宿の消えた記録　｜　第%d章" % chapter
	objective_label.text = _objective_text()
	var guard_info := ""
	if route_known and not guards.is_empty():
		var nearest := 999.0
		for guard in guards:
			nearest = minf(nearest, player.global_position.distance_to((guard["node"] as Node3D).global_position))
		guard_info = "  |  近くの従業員 %.1fm" % nearest
	inventory_label.text = "警戒 %d%%  |  小銭 %d  |  手掛かり %d%s" % [roundi(suspicion), coins, clues, guard_info]
	if chapter >= 4:
		inventory_label.text += "  |  証拠 %d/9" % _evidence_score()
	if chapter == 12 and copy_time >= 0.0:
		inventory_label.text += "  |  残り %d秒" % ceili(copy_time)
	if message_time <= 0.0:
		status_label.text = "身のこなしと周囲の物を使って進もう。"
	var point := _nearest_point()
	var campaign_point := _nearest_campaign_point()
	if not campaign_point.is_empty():
		hint_label.text = "E / 調べる: " + str(campaign_point["title"])
	elif not point.is_empty():
		hint_label.text = "E / 調べる: " + str(point["title"])
	elif chapter == 1 and player.global_position.distance_to(RECEPTION_POINT) < 2.1 and not has_ticket:
		hint_label.text = "E / 調べる: 受付で入館札を受け取る"
	elif chapter == 1 and player.global_position.distance_to(Vector3(-7.4, 0, -2.0)) < 2.2 and not mirror_used:
		hint_label.text = "E / 調べる: 鏡で変装を整える"
	else:
		hint_label.text = "立ち止まる・巡回を読む・周囲を調べる。Tabで記録。"
		for guard in guards:
			if player.global_position.distance_to((guard["node"] as Node3D).global_position) < 2.2 and guard["talk_cooldown"] <= 0.0:
				hint_label.text = "E / 調べる: 従業員に道を聞く"
				break


func _campaign_spawn(stage: int) -> Vector3:
	match stage:
		4, 5:
			return Vector3(35, 0.05, 12.5)
		6:
			return Vector3(35, 0.05, 3.0)
		7:
			return Vector3(39, 0.05, -2.0)
		8:
			return Vector3(31, 0.05, -5.0)
		9:
			return Vector3(39, 0.05, -5.5)
		10:
			return Vector3(31, 0.05, -10.0)
		11:
			return Vector3(30, 0.05, -9.0)
		12:
			return Vector3(40, 0.05, -10.0)
		13:
			return Vector3(35, 0.05, -10.0)
		15, 16:
			return Vector3(65, 0.05, 8.0) if story_flags.get("next_destination", "") == "湖畔の資料館" else Vector3(-35, 0.05, 8.0)
		_:
			return Vector3(35, 0.05, 11.0)


func _campaign_objective() -> String:
	match chapter:
		4:
			return "目的: 3件の通話を聞き、時系列に並べる"
		5:
			return "目的: 雨の渡り廊下を越える。濡れた床の足跡に注意"
		6:
			return "目的: 二冊の台帳を読み、偽名を照合する"
		7:
			return "目的: 夜勤の従業員から事情を聞く"
		8:
			return "目的: 停電の復旧方法を選ぶ"
		9:
			return "目的: 3人の証言を聞き、矛盾を見つける"
		10:
			return "目的: 古い写真と改築図から封鎖室を探す"
		11:
			return "目的: 管理人に協力を求める"
		12:
			return "目的: 制限時間内に証拠を複写し、原本を戻す"
		13:
			return "目的: 集めた証拠から結論と公表方法を選ぶ"
		15:
			return "目的: 次の地域で足りない記録を再調査する"
		16:
			return "次の事件: 共有地の移転先を追う"
		_:
			return "次の調査: 湖畔の資料館か町役場へ向かう"


func _campaign_intro(stage: int) -> String:
	match stage:
		4:
			return "第四章　山の離れからの電話\n声は幼なじみの美緒に似ていた。通話は三つに分断され、順番が入れ替わっている。\n時間を並べ直し、待ち合わせ場所を特定しよう。"
		5:
			return "第五章　雨の渡り廊下\n離れへ続く廊下は雨で濡れていた。雨音は足音を消すが、濡れた靴跡は残る。\nひさしと履物を調べ、通り方を決めよう。"
		6:
			return "第六章　二冊目の台帳\n古い帳簿と新しい帳簿では、同じ日の客名が違う。\n美緒が追っていた偽名を見つければ、宿の隠した記録に近づける。"
		7:
			return "第七章　夜勤の従業員\n従業員は美緒を見たと言うが、話すたびに時刻が変わる。" + ("濡れた足跡を追って誰かが来た。\n" if story_flags.get("footprints", false) else "\n") + "記録を基に本当の話を引き出そう。"
		8:
			return "第八章　停電の時間\n" + ("従業員は『管理人が美緒を守った』と打ち明けた。\n" if story_flags.get("night_trust", false) else "従業員は口を閉ざし、管理人の意図は分からない。\n") + "灯りを復旧するか暗いまま進むかで、巡回と後の調査が変わる。"
		9:
			return "第九章　宿泊客の証言\n三人の客が、同じ夜を違う言葉で語る。\n誰から聞くか、誰を信じるかを決めよう。順番も手掛かりになる。"
		10:
			return "第十章　失われた写真\n" + ("常連客の証言で、偽名の人物が同じ部屋へ入ったと分かった。\n" if story_flags.get("guest_reliable", false) else "証言は割れ、人物の行方はまだ曖昧だ。\n") + "写真と改築図を重ね、壁の向こうの部屋を探そう。"
		11:
			return "第十一章　離れの管理人\n管理人は扉の鍵を持っている。美緒を守ろうとして沈黙していたのかもしれない。\n証拠、紹介、直接の頼みのどれで協力を得るか選ぼう。"
		12:
			return "第十二章　記録の持ち出し\n" + ("管理人が鍵と見張り役を引き受けた。\n" if story_flags.get("caretaker_help", false) else "管理人の協力は得られず、巡回の隙を使うしかない。\n") + "偽造記録を複写し、原本を戻すまで時間は限られている。"
		13:
			return "第十三章　真相と次の目的地\n美緒は土地売買の偽造を告発する準備をしていた。" + ("複写した原本が証拠になる。\n" if story_flags.get("copy_success", false) else "複写は不完全で、町の原本がまだ必要だ。\n") + "公表、保護、継続調査から選ぼう。"
		15:
			return "第十五章　次の地域の記録\n" + str(story_flags.get("next_destination", "記録室")) + "に着いた。離れで欠けた証拠を補い、美緒の父が残した地番を追おう。\n二つの資料を読み、食い違いを照合する。"
		16:
			return "第十六章　つながる土地\n別の地域にも同じ署名が見つかった。宿だけの事件ではない。\n新しい記録を手に、美緒と次の調査を始める。"
		_:
			return "次の調査\n町の古い記録にも同じ署名がある。ここで得た証拠と人の信頼が、次の場所で役に立つ。\n離れを自由に調べ、次の行き先を確認できる。"


func _campaign_scene(stage: int) -> String:
	match stage:
		4:
			return "美緒の手紙には『私が消えたと思っても、誰も責めないで』とあった。\n彼女の父は町の測量士で、土地の境界を巡って宿主と争っていた。\n電話が示す順序には、美緒が隠れた理由が残っている。"
		5:
			return "渡り廊下の先に、父と歩いた山道が見える。\n雨の夜、誰かが美緒を追ったのなら、床の足跡も証言になる。\n急げば追いつける。でも、跡を残せば相手にも居場所を教える。"
		6:
			return "宿の台帳には、美緒の父が守ろうとした地番が書かれていた。\n同じ客を別名で記したのは、売買の立会人を消すためだろうか。\n名前を照合すれば、偽造された契約に近づける。"
		7:
			return "夜勤の従業員は宿主に家族の住まいを借りている。\n逆らえば仕事も家も失う。責める言葉では口を閉ざすだろう。\n美緒を守った人がいるなら、その人の名前だけでも聞きたい。"
		8:
			return "停電は偶然ではなかった。配電盤には新しい傷がある。\n誰かが記録を読む時間を奪おうとした。\n明かりを戻せば見つかりやすいが、複写には十分な光が要る。"
		9:
			return "旅人、常連客、記者。三人とも同じ時刻の廊下を見た。\n誰かは嘘をついている。しかし美緒を守るための嘘かもしれない。\n証言の順番と台帳を並べて、理由を考えよう。"
		10:
			return "写真の端には、美緒と父が子どもの頃に写っていた。\nその背後の扉だけが、今の宿から消えている。\n改築図で消された部屋に、父が残した測量の原本があるはずだ。"
		11:
			return "管理人は美緒の父と長く働いていた。\n『あの子まで失うわけにはいかない』と、鍵を握ったまま言う。\n相手が守りたいものを理解してから、協力を求めよう。"
		12:
			return "封鎖室の原本には、村の共有地を宿主へ移した偽造の印がある。\n美緒は証人を守るため姿を隠し、原本をここへ戻した。\n持ち出せば証拠が消されたと疑われる。複写だけを残そう。"
		13:
			return "美緒から短い音声が届く。『真実だけでは人を守れない。順番を考えて』。\n証拠の量、協力者の信頼、証人の安全。\nどれを優先するかで、同じ真相でも結末は変わる。"
		15:
			return "宿の原本だけでは、村の共有地がどこへ移されたか分からない。\n美緒の父は二つの場所に記録を分けた。どちらを選んでも、残された地番へたどり着ける。"
		16:
			return "受理番号の先に、さらに三件の土地移転が続いていた。\n美緒は『今度は一人で消えない』と約束する。\n調査はここで終わらない。集めた記録は次の事件へ引き継がれる。"
		_:
			return "美緒の父の資料には二つの地名が残る。湖畔の資料館と町役場。\n次の記録はそこにある。誰を守り、何を公表したかを抱えて進む。"


func _advance_campaign(next_stage: int) -> void:
	chapter = next_stage
	copy_time = -1.0
	suspicion = minf(suspicion, 25.0)
	if chapter == 7 and story_flags.get("footprints", false):
		suspicion += 15.0
		_lure_guards(Vector3(35, 0, 7), 5.0)
	player.velocity = Vector3.ZERO
	player.position = _campaign_spawn(chapter)
	_refresh_campaign_markers()
	_show_sequence([_campaign_intro(chapter), _campaign_scene(chapter)])
	_save_progress()
	_update_ui_v3()


func _campaign_tick(delta: float) -> void:
	if chapter == 5 and not story_open and player_speed > 0.2 and player.global_position.x > 32.0 and player.global_position.x < 38.0 and player.global_position.z > 4.7 and player.global_position.z < 10.0:
		rain_footprint_timer -= delta
		if rain_footprint_timer <= 0.0:
			rain_footprint_timer = 0.42
			story_flags["footprints"] = true
			_spawn_footprint()
	if story_open or chapter != 12 or copy_time < 0.0:
		return
	copy_time -= delta
	if copy_time <= 0.0:
		copy_time = -1.0
		story_flags["copy_incomplete"] = true
		_show_story("時間切れ。原本は戻せたが、複写は一部しか読めない。\n不完全な証拠でも、真相をどう扱うか決めなくてはならない。")
		_save_progress()
		chapter = 13
		player.position = _campaign_spawn(13)
		_refresh_campaign_markers()


func _campaign_goal() -> void:
	if chapter == 5 and player.global_position.z < 4.7:
		var wet_path := player.global_position.x > 32.0 and player.global_position.x < 38.0
		story_flags["footprints"] = story_flags.get("footprints", false) or (wet_path and not story_flags.get("awning", false))
		if story_flags["footprints"]:
			suspicion = minf(95.0, suspicion + 16.0)
			_show_status("濡れた床に足跡が残った。後で追跡されるかもしれない。")
		else:
			story_flags["dry_crossing"] = true
		_advance_campaign(6)


func _spawn_footprint() -> void:
	var mark := MeshInstance3D.new()
	mark.name = "wet footprint"
	var box := BoxMesh.new()
	box.size = Vector3(0.11, 0.012, 0.25)
	mark.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.08, 0.1, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.material_override = material
	mark.position = Vector3(player.global_position.x + (0.12 if int(elapsed * 3) % 2 == 0 else -0.12), 0.065, player.global_position.z)
	mark.rotation.y = camera_yaw
	add_child(mark)
	get_tree().create_timer(24.0).timeout.connect(func():
		if is_instance_valid(mark):
			mark.queue_free()
	)


func _evidence_score() -> int:
	var score := 0
	for key in ["phone_correct", "dry_crossing", "ledger_match", "night_trust", "guest_reliable", "sealed_found", "caretaker_help", "copy_success", "copy_accurate"]:
		if story_flags.get(key, false):
			score += 1
	return score


func _interact_campaign() -> bool:
	if story_open:
		return true
	var point := _nearest_campaign_point()
	if point.is_empty():
		return false
	var id: String = point["id"]
	match id:
		"call_a":
			story_flags[id] = true
			_show_story("録音A　22時20分\n『管理人さん、帳簿を移してください。あの人に見つかる前に』\n声は美緒に似ているが、最後の一語が雑音で消える。")
		"call_b":
			story_flags[id] = true
			_show_story("録音B　22時10分\n『渡り廊下で待っている。雨が強いから、足跡には気をつけて』\n通話の相手は美緒を知っている人物らしい。")
		"call_c":
			story_flags[id] = true
			_show_story("録音C　22時30分\n『封鎖された部屋に原本を置いた。町の記録と比べれば分かる』\n電話はここで切れている。")
		"call_order":
			if not _has_all(["call_a", "call_b", "call_c"]):
				_show_story("通話はまだ三件そろっていない。離れの電話機を調べよう。")
			else:
				_show_choices("通話の時刻を並べ直す。\n最初に渡り廊下、次に帳簿、最後に封鎖室だったはずだ。", ["A → B → C", "B → A → C", "C → B → A"], "phone")
		"awning":
			story_flags[id] = true
			_show_story("ひさしを開いた。廊下の左端は雨を避けられる。\nそこを通れば靴跡を残さず奥へ進める。")
		"boots":
			story_flags[id] = true
			quiet_steps = true
			_show_story("防水の履物に替えた。雨の中でも足音は小さい。\nただし濡れた場所を通れば靴跡は残る。")
		"ledger_a":
			story_flags[id] = true
			_show_story("古い台帳\n22時15分『木村 実』。署名の横に、美緒の取材メモと同じ星印。\nこの人が原本を預かったのだろうか。")
		"ledger_b":
			story_flags[id] = true
			_show_story("新しい台帳\n22時15分『高瀬 真』。部屋番号は古い台帳と同じ。\n誰かが名前だけを差し替えている。")
		"ledger_compare":
			if not _has_all(["ledger_a", "ledger_b"]):
				_show_story("二冊を読んでから照合しよう。")
			else:
				_show_choices("22時15分、同じ部屋にいたのは誰か。", ["木村 実と高瀬 真は同一人物", "別々の二人がいた", "台帳の時刻が誤り"], "ledger")
		"night_staff":
			_show_choices("従業員『美緒さんは見ていません。私はその時間ずっと巡回を……』\n相手は目をそらした。何から話す？", ["美緒を隠したと責める", "22時20分の帳簿の移動を尋ねる", "何も知らないふりをする"], "staff")
		"breaker":
			_show_choices("分電盤には古い配線が残る。復旧すると記録が読みやすいが、巡回も戻る。", ["明かりを復旧する", "暗いまま進む", "一部だけ点灯する"], "power")
		"guest_1", "guest_2", "guest_3":
			_interview_guest(id)
		"testimony_compare":
			if not _has_all(["guest_1", "guest_2", "guest_3"]):
				_show_story("三人の証言を聞き終えてから整理しよう。")
			else:
				_show_choices("証言の時刻と台帳を合わせる。誰の話が最も確かか。", ["旅人の『22時には出発した』", "常連客の『22時15分に同じ部屋へ入った』", "記者の『誰も来なかった』"], "guests")
		"old_photo":
			story_flags[id] = true
			_show_story("古い写真には北側の壁に細い扉が写っている。\n扉の上の木彫りは、今も廊下の梁に残っている。")
		"old_plan":
			story_flags[id] = true
			_show_story("改築図では北側の物置が『壁内保管庫』に変更されている。\n図の余白に、美緒の筆跡で『写真と重ねる』とある。")
		"sealed_room":
			if not _has_all(["old_photo", "old_plan"]):
				_show_story("壁だけでは場所を絞れない。写真と改築図を先に調べよう。")
			else:
				_show_choices("写真と改築図を重ねた。封鎖室の入口はどこか。", ["北壁の木彫りの真下", "受付の床下", "渡り廊下の窓際"], "photo")
		"caretaker":
			_show_choices("管理人『鍵は渡せません。美緒さんの安全がかかっている』\nどう話を進める？", ["台帳と写真の証拠を示す", "従業員からの紹介を頼る", "事情を伏せて鍵だけ求める"], "caretaker")
		"copy_start":
			if copy_time >= 0.0:
				_show_story("複写は進行中。原本の位置を合わせよう。")
			else:
				copy_time = 46.0 if not lights_dim else 34.0
				if story_flags.get("caretaker_help", false):
					copy_time += 8.0
				story_flags["copy_started"] = true
				_show_story("原本には土地売買の偽造印と、宿主の署名がある。\n複写を始めた。時間内に位置を合わせ、原本を戻そう。")
		"copy_align":
			if copy_time < 0.0:
				_show_story("先に複写機を起動しよう。")
			elif story_flags.get("copy_aligned", false):
				_show_story("位置は合わせた。複写を終え、原本を戻そう。")
			else:
				_show_choices("文字の端が薄い。位置を慎重に直すか、時間を優先するか。", ["12秒かけて正確に合わせる", "3秒で急いで合わせる", "複写を中断する"], "copy_align")
		"copy_finish":
			if copy_time < 0.0 or not story_flags.get("copy_aligned", false):
				_show_story("複写を始め、原本の位置を合わせる必要がある。")
			else:
				story_flags["copy_success"] = true
				_advance_campaign(13)
		"truth":
			_show_choices("証拠の強さ %d/9。\n美緒の身の安全と、偽造の公表をどう両立させる？" % _evidence_score(), ["今ある証拠を公表する", "管理人と美緒に託す", "公表を待ち、町の記録を追う"], "ending")
		"next_place":
			_show_choices("電話の最後に残った地名は二つ。次の調査先を選ぶ。", ["湖畔の資料館", "町役場の記録室", "離れで再調査する"], "next")
		"lake_index":
			story_flags[id] = true
			_show_story("資料館の目録\n美緒の父が寄贈した測量記録には、共有地の境界番号が残る。\n番号の末尾だけが帳簿と違う。")
		"lake_map":
			story_flags[id] = true
			_show_story("古い境界図\n紙の裏に『移転先は第七区画』と鉛筆で書かれていた。\n宿の原本にない地番だ。")
		"lake_compare":
			if not _has_all(["lake_index", "lake_map"]):
				_show_story("目録と境界図を両方調べよう。")
			else:
				_show_choices("境界図の裏書きと目録。欠けた記録につながるのは？", ["第七区画の移転先", "宿の部屋番号", "古い電話番号"], "region")
		"town_docket":
			story_flags[id] = true
			_show_story("町役場の受理簿\n記者が預かった番号は、共有地の所有権移転の受理番号だった。\n申請者の署名は宿主のものと似ている。")
		"town_register":
			story_flags[id] = true
			_show_story("封印された登記\n受理番号の下に、第七区画への再移転が記されている。\n宿の原本だけでは見えなかった行き先だ。")
		"town_compare":
			if not _has_all(["town_docket", "town_register"]):
				_show_story("受理簿と封印された登記を両方調べよう。")
			else:
				_show_choices("受理簿と登記を照合する。真相を補強するのは？", ["宿の部屋番号", "第七区画への再移転", "夜勤の勤務表"], "region")
		"lake_epilogue", "town_epilogue":
			_show_story("第七区画にも宿主と同じ署名が残る。\n美緒と連絡を取り、次の土地移転を追う。記録と選択は保存されている。")
	_save_progress()
	return true


func _has_all(keys: Array) -> bool:
	for key in keys:
		if not story_flags.get(key, false):
			return false
	return true


func _interview_guest(id: String) -> void:
	if not story_flags.has("first_witness"):
		story_flags["first_witness"] = id
	story_flags[id] = true
	match id:
		"guest_1":
			_show_story("旅人『私は22時には宿を出た。雨の前だったから、靴は乾いていた』\nだが受付の傘立てには、同じ印の濡れた傘がある。")
		"guest_2":
			_show_story("常連客『22時15分、木村さんが部屋へ入るのを見た。後で高瀬さんと呼ばれていた』\n二冊の台帳の食い違いと一致する。")
		"guest_3":
			if story_flags["first_witness"] == id:
				story_flags["witness_bonus"] = true
				_show_story("記者『先に私を訪ねてくれてよかった。美緒さんから預かった封筒がある』\n中には町役場の受理番号が書かれていた。")
			else:
				_show_story("記者『美緒さんが私に何か残したけれど、今は確信がない』\n話す順番で相手の警戒が変わったようだ。")


func _show_choices(words: String, options: Array, context: String) -> void:
	story_queue.clear()
	choice_context = context
	story_text.text = words
	story_text.custom_minimum_size.y = 145
	story_panel.offset_top = -210
	story_panel.offset_bottom = 210
	story_button.visible = false
	for i in range(choice_buttons.size()):
		var button := choice_buttons[i]
		button.visible = i < options.size()
		if button.visible:
			button.text = str(options[i])
	story_backdrop.visible = true
	story_panel.visible = true
	story_open = true


func _campaign_choice(index: int) -> void:
	story_open = false
	story_panel.visible = false
	story_backdrop.visible = false
	story_text.custom_minimum_size.y = 210
	story_panel.offset_top = -155
	story_panel.offset_bottom = 155
	match choice_context:
		"journal":
			_show_story(_journal_page(index))
		"phone":
			if index == 1:
				story_flags["phone_correct"] = true
				clues += 1
				_advance_campaign(5)
			else:
				suspicion += 12.0
				_show_story("時刻が矛盾する。録音を聞き直そう。\n間違った相手に連絡しかけ、周囲の警戒も上がった。")
		"ledger":
			if index == 0:
				story_flags["ledger_match"] = true
				clues += 1
				_advance_campaign(7)
			else:
				suspicion += 15.0
				_show_story("部屋番号と時刻が一致する。二人別々では説明できない。\nもう一度、名前の欄を比べよう。")
		"staff":
			if index == 1:
				story_flags["night_trust"] = true
				clues += 1
				_show_status("従業員が、管理人は美緒をかくまったと教えてくれた。")
			else:
				suspicion = minf(95.0, suspicion + (18.0 if index == 0 else 6.0))
			_advance_campaign(8)
		"power":
			story_flags["power_choice"] = index
			lights_dim = index != 0
			story_flags["light"] = lights_dim
			if guards.size() >= 3:
				var annex_guard := guards[2]
				annex_guard["a"] = Vector3(35, 0, 0) if index == 0 else Vector3(35, 0, 5)
				annex_guard["b"] = Vector3(35, 0, -11) if index == 0 else Vector3(35, 0, -2)
			_advance_campaign(9)
		"guests":
			if index == 1:
				story_flags["guest_reliable"] = true
				clues += 1 + (1 if story_flags.get("witness_bonus", false) else 0)
			else:
				story_flags["guest_misread"] = true
				suspicion = minf(95.0, suspicion + 10.0)
			_advance_campaign(10)
		"photo":
			if index == 0:
				story_flags["sealed_found"] = true
				clues += 1
				_advance_campaign(11)
			else:
				_show_story("壁に扉の痕跡はない。写真の木彫りと改築図をもう一度重ねよう。")
		"caretaker":
			var earned_trust: bool = (index == 0 and _evidence_score() >= 4) or (index == 1 and bool(story_flags.get("night_trust", false)))
			story_flags["caretaker_help"] = earned_trust
			if not earned_trust:
				suspicion = minf(95.0, suspicion + 12.0)
			_advance_campaign(12)
		"copy_align":
			if index == 2:
				story_flags["copy_incomplete"] = true
				_advance_campaign(13)
			else:
				copy_time -= 12.0 if index == 0 else 3.0
				story_flags["copy_aligned"] = true
				story_flags["copy_accurate"] = index == 0 and copy_time > 0.0
				if copy_time <= 0.0:
					story_flags["copy_incomplete"] = true
					_advance_campaign(13)
				else:
					_show_story("原本の位置を合わせた。残り時間内に複写を終えて棚へ戻そう。")
		"ending":
			var score := _evidence_score()
			if index == 0:
				if score >= 6:
					story_flags["ending"] = "公表と保護"
					ending_text = "美緒と証人を守りながら偽造を公表した。宿主の署名は町の記録にも残る。\n美緒から短い返事が届く。『次の一冊を見つけて』"
				else:
					story_flags["ending"] = "早すぎる告発"
					ending_text = "公表は広まったが、欠けた証拠を突かれた。美緒は姿を隠し、町の原本を探す必要が生まれた。"
			elif index == 1:
				story_flags["ending"] = "静かな保護" if story_flags.get("caretaker_help", false) else "証人不在"
				ending_text = "管理人は美緒を安全な場所へ案内した。表に出ない調査が続く。" if story_flags.get("caretaker_help", false) else "管理人の協力は得られず、別の証人を探すことになった。"
			else:
				story_flags["ending"] = "継続調査"
				ending_text = "結論を急がず、町の記録と照合する道を選んだ。美緒への手紙を預け、次の場所へ向かう。"
			_advance_campaign(14)
			_show_story(ending_text + "\n\n続きは離れの電話で行き先を選ぼう。")
		"next":
			var destination: String = ["湖畔の資料館", "町役場の記録室", "離れの再調査"][index]
			story_flags["next_destination"] = destination
			if index == 2:
				_show_story("離れに残って調べ直す。\n準備ができたら電話から湖畔の資料館か町役場を選べる。")
			else:
				_advance_campaign(15)
		"region":
			var lake: bool = story_flags.get("next_destination", "") == "湖畔の資料館"
			if index == (0 if lake else 1):
				story_flags["recovered_record"] = true
				if story_flags.get("ending", "") == "早すぎる告発" or story_flags.get("copy_incomplete", false):
					story_flags["revised_ending"] = "追加の原本で裏付け完了"
				_advance_campaign(16)
			else:
				_show_story("地番が一致しない。受理番号と第七区画をもう一度見比べよう。")
	_save_progress()
	_update_ui_v3()


func _journal_page(page: int) -> String:
	if page == 0:
		var lines: Array[String] = ["証拠と推理　%d/9" % _evidence_score()]
		if story_flags.get("phone_correct", false):
			lines.append("通話: 渡り廊下 → 帳簿 → 封鎖室")
		if story_flags.get("ledger_match", false):
			lines.append("台帳: 木村 実と高瀬 真は同一人物")
		if story_flags.get("guest_reliable", false):
			lines.append("証言: 常連客の時刻が台帳と一致")
		if story_flags.get("sealed_found", false):
			lines.append("写真: 北壁の木彫りの下に封鎖室")
		if story_flags.get("copy_success", false):
			lines.append("原本: 土地売買の偽造署名を複写")
		if lines.size() == 1:
			lines.append("証拠はまだ集まっていない。")
		return "\n".join(PackedStringArray(lines))
	if page == 1:
		return "人物と信頼\n美緒: 消えた入館記録を追う幼なじみ\n夜勤の従業員: %s\n管理人: %s\n証言の補足: %s" % ["協力的" if story_flags.get("night_trust", false) else "警戒中", "協力者" if story_flags.get("caretaker_help", false) else "保留", "受理番号あり" if story_flags.get("witness_bonus", false) else "未入手"]
	return "行動と次の目的\n雨の足跡: %s\n停電: %s\n複写: %s\n%s" % ["残った" if story_flags.get("footprints", false) else "残していない", "暗いまま" if lights_dim else "復旧", "完了" if story_flags.get("copy_success", false) else "未完", _campaign_objective()]
