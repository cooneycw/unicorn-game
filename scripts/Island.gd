extends Node3D

# Island scene — pet interactions, egg spawning, environment, keyboard controls
var game_manager
var audio_manager
var pets_in_scene: Array = []
var selected_pet_index: int = 0
var pet_ids: Array = []

var _feedback_label: Label
var _stats_label: Label
var _coins_label: Label
var _pet_list_label: Label
var _feedback_timer: float = 0.0

# Egg spawning
var _egg_spawn_timer: float = 0.0
var _egg_spawn_interval: float = 0.0  # randomized on ready
var _egg_node: MeshInstance3D = null
var _egg_label: Label3D = null
var _egg_available: bool = false

# Environment
var _sun_light: DirectionalLight3D
var _day_time: float = 0.0  # 0-1 representing full day cycle
var _clouds: Array = []

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")

	_create_island_environment()
	_create_trees()
	_create_pond()
	_create_clouds()
	_spawn_all_pets()
	_create_ui()

	game_manager.pet_stat_changed.connect(_on_stat_changed)
	game_manager.coins_changed.connect(_on_coins_changed)

	if pet_ids.size() > 0:
		_highlight_selected()
		_update_stats_display()

	# Randomize first egg spawn (5-10 minutes)
	_egg_spawn_interval = randf_range(300.0, 600.0)

func _create_island_environment():
	# Ground
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(30, 30)
	ground.mesh = plane_mesh
	ground.position.y = -1

	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.25, 0.55, 0.2)
	ground.material_override = ground_material
	add_child(ground)

	# Sunlight with day/night cycle
	_sun_light = DirectionalLight3D.new()
	_sun_light.rotation.x = -PI / 4
	_sun_light.rotation.y = -PI / 4
	_sun_light.light_energy = 1.0
	_sun_light.light_color = Color(1.0, 0.95, 0.8)
	add_child(_sun_light)

	# Camera
	var camera = Camera3D.new()
	camera.position = Vector3(0, 8, 15)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(camera)

func _create_trees():
	var tree_positions = [
		Vector3(-10, -1, -8), Vector3(-8, -1, 5), Vector3(9, -1, -6),
		Vector3(12, -1, 3), Vector3(-6, -1, -12), Vector3(7, -1, 10),
		Vector3(-12, -1, 0), Vector3(11, -1, -10), Vector3(-4, -1, 11),
		Vector3(5, -1, -11), Vector3(-11, -1, 8), Vector3(13, -1, 7),
	]
	for pos in tree_positions:
		_create_tree(pos)

func _create_tree(pos: Vector3):
	var tree_root = Node3D.new()
	tree_root.position = pos

	# Trunk
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 1.5
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.75

	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.3, 0.15)
	trunk.material_override = trunk_mat
	tree_root.add_child(trunk)

	# Canopy (cone)
	var canopy = MeshInstance3D.new()
	var canopy_mesh = CylinderMesh.new()
	canopy_mesh.top_radius = 0.0
	canopy_mesh.bottom_radius = 1.0
	canopy_mesh.height = 2.0
	canopy.mesh = canopy_mesh
	canopy.position.y = 2.5

	var canopy_mat = StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.15, 0.5 + randf() * 0.15, 0.1)
	canopy.material_override = canopy_mat
	tree_root.add_child(canopy)

	add_child(tree_root)

func _create_pond():
	var pond = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 3.0
	disc.bottom_radius = 3.0
	disc.height = 0.05
	pond.mesh = disc
	pond.position = Vector3(8, -0.95, -2)

	var pond_mat = StandardMaterial3D.new()
	pond_mat.albedo_color = Color(0.2, 0.5, 0.8, 0.7)
	pond_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pond.material_override = pond_mat
	add_child(pond)

func _create_clouds():
	for i in range(6):
		var cloud = MeshInstance3D.new()
		var cloud_mesh = SphereMesh.new()
		cloud_mesh.radius = randf_range(1.5, 3.0)
		cloud_mesh.height = randf_range(1.0, 1.5)
		cloud.mesh = cloud_mesh
		cloud.position = Vector3(
			randf_range(-20, 20),
			randf_range(12, 18),
			randf_range(-15, -5)
		)
		cloud.scale = Vector3(1.5, 0.4, 0.8)

		var cloud_mat = StandardMaterial3D.new()
		cloud_mat.albedo_color = Color(1, 1, 1, 0.6)
		cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud.material_override = cloud_mat

		add_child(cloud)
		_clouds.append(cloud)

func _spawn_all_pets():
	var all_pets = game_manager.get_all_pets()

	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]
		var pet = Pet.new()
		pet.pet_id = pet_id
		pet.pet_name = pet_info["name"]
		pet.pet_type = pet_info["type"]
		pet.enable_wandering = true
		pet._wander_bounds = Vector2(8, 8)

		pet.position = Vector3(randf_range(-6, 6), 0.5, randf_range(-6, 6))

		add_child(pet)
		pets_in_scene.append(pet)
		pet_ids.append(pet_id)

func _create_ui():
	var ui = Control.new()
	ui.anchor_right = 1.0
	ui.anchor_bottom = 1.0
	ui.name = "UI"
	add_child(ui)

	# Title
	var title = Label.new()
	title.text = "ISLAND"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)

	# Coins display
	_coins_label = Label.new()
	_coins_label.text = "Coins: %d" % game_manager.coins
	_coins_label.position = Vector2(10, 40)
	_coins_label.add_theme_font_size_override("font_size", 18)
	_coins_label.add_theme_color_override("font_color", Color.YELLOW)
	ui.add_child(_coins_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = "UP/DOWN: select pet | F: feed | P: play | R: rest | E: collect egg | ESC: back"
	instructions.position = Vector2(10, 65)
	instructions.add_theme_font_size_override("font_size", 12)
	ui.add_child(instructions)

	# Pet list
	_pet_list_label = Label.new()
	_pet_list_label.position = Vector2(10, 95)
	ui.add_child(_pet_list_label)

	# Stats for selected pet
	_stats_label = Label.new()
	_stats_label.position = Vector2(10, 220)
	_stats_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(_stats_label)

	# Feedback message
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(10, 380)
	_feedback_label.add_theme_font_size_override("font_size", 16)
	_feedback_label.add_theme_color_override("font_color", Color.GOLD)
	ui.add_child(_feedback_label)

func _highlight_selected():
	if pet_ids.size() == 0:
		return
	var lines = ""
	for i in range(pet_ids.size()):
		var pid = pet_ids[i]
		var info = game_manager.get_pet_info(pid)
		var mood = game_manager.get_mood_emoji(pid)
		var level = game_manager.get_level(pid)
		var prefix = "> " if i == selected_pet_index else "  "
		lines += "%s%s Lv%d (%s) %s\n" % [prefix, info["name"], level, info["type"], mood]
	_pet_list_label.text = lines

func _update_stats_display():
	if pet_ids.size() == 0:
		_stats_label.text = "No pets on island."
		return
	var pid = pet_ids[selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	var mood = game_manager.get_pet_mood(pid)
	var xp_info = game_manager.get_xp_progress(pid)
	var cap = game_manager.get_stat_cap(pid)
	var xp_str = "XP: %d/%d" % [xp_info["current"], xp_info["next"]] if xp_info["next"] > 0 else "XP: MAX"
	_stats_label.text = "--- %s Lv%d (%s) --- Mood: %s\nHealth:    %d/%d\nHappiness: %d/%d\nHunger:    %d/%d\nEnergy:    %d/%d\n%s" % [
		info["name"], info["level"], info["type"], mood,
		info["health"], cap, info["happiness"], cap, info["hunger"], cap, info["energy"], cap,
		xp_str
	]

func _show_feedback(msg: String):
	_feedback_label.text = msg
	_feedback_timer = 2.5

func _process(delta: float):
	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0:
			_feedback_label.text = ""

	# Egg spawn timer
	if not _egg_available:
		_egg_spawn_timer += delta
		if _egg_spawn_timer >= _egg_spawn_interval:
			_spawn_egg()

	# Egg glow animation
	if _egg_node and _egg_available:
		_egg_node.position.y = 0.3 + sin(Time.get_ticks_msec() / 500.0) * 0.1

	# Day/night cycle (full cycle every 5 minutes)
	_day_time += delta / 300.0
	if _day_time > 1.0:
		_day_time -= 1.0

	var sun_angle = _day_time * TAU
	_sun_light.rotation.x = -PI / 4 + sin(sun_angle) * 0.3
	var day_factor = (sin(sun_angle) + 1.0) / 2.0  # 0 = night, 1 = day
	_sun_light.light_energy = lerp(0.3, 1.2, day_factor)
	_sun_light.light_color = Color(
		lerp(0.4, 1.0, day_factor),
		lerp(0.3, 0.95, day_factor),
		lerp(0.6, 0.8, day_factor)
	)

	# Drift clouds
	for cloud in _clouds:
		cloud.position.x += delta * 0.3
		if cloud.position.x > 25:
			cloud.position.x = -25

func _spawn_egg():
	_egg_available = true
	_egg_spawn_timer = 0.0

	_egg_node = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.45
	_egg_node.mesh = sphere
	_egg_node.position = Vector3(randf_range(-8, 8), 0.3, randf_range(-8, 8))

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.4, 0.8)
	mat.emission_energy_multiplier = 0.5
	_egg_node.material_override = mat
	add_child(_egg_node)

	_egg_label = Label3D.new()
	_egg_label.text = "?"
	_egg_label.font_size = 64
	_egg_label.position.y = 0.5
	_egg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_egg_label.no_depth_test = true
	_egg_node.add_child(_egg_label)

func _collect_egg():
	if not _egg_available:
		_show_feedback("No egg to collect! Keep playing and one may appear...")
		return

	var success = game_manager.collect_egg()
	if not success:
		_show_feedback("Egg inventory full! (max %d) Wait for one to hatch." % game_manager.MAX_EGGS)
		return

	_egg_available = false
	if _egg_node:
		_egg_node.queue_free()
		_egg_node = null
		_egg_label = null

	# Reset spawn timer for next egg
	_egg_spawn_interval = randf_range(300.0, 600.0)

	_show_feedback("Egg collected! It will hatch in about 5 minutes.")

	# Check achievements
	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_all()

func _on_stat_changed(_pet_id: int, _stat_name: String, _new_value: int):
	_highlight_selected()
	_update_stats_display()

func _on_coins_changed(new_amount: int):
	_coins_label.text = "Coins: %d" % new_amount

func _get_selected_pet_name() -> String:
	if pet_ids.size() == 0:
		return ""
	var pid = pet_ids[selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	return info["name"]

func _get_selected_pet() -> Pet:
	if selected_pet_index < pets_in_scene.size():
		return pets_in_scene[selected_pet_index]
	return null

func _action_feed():
	if pet_ids.size() == 0:
		return
	if game_manager.coins < 5:
		_show_feedback("Not enough coins! (need 5)")
		return
	var pid = pet_ids[selected_pet_index]
	game_manager.modify_coins(-5)
	game_manager.modify_stat(pid, "hunger", 20)
	game_manager.add_xp(pid, 5)
	var pet_node = _get_selected_pet()
	if pet_node:
		pet_node.do_feed_reaction()
	_show_feedback("%s loved the treats! (+5 XP)" % _get_selected_pet_name())

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_all()

func _action_play():
	if pet_ids.size() == 0:
		return
	var pid = pet_ids[selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	if info["energy"] < 10:
		_show_feedback("%s is too tired to play!" % info["name"])
		return
	game_manager.modify_stat(pid, "happiness", 15)
	game_manager.modify_stat(pid, "energy", -10)
	game_manager.modify_coins(3)
	game_manager.add_xp(pid, 10)
	var pet_node = _get_selected_pet()
	if pet_node:
		pet_node.do_happy_reaction()
	if audio_manager:
		audio_manager.play_sfx("coin")
	_show_feedback("%s had a great time playing! (+3 coins, +10 XP)" % _get_selected_pet_name())

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_all()

func _action_rest():
	if pet_ids.size() == 0:
		return
	var pid = pet_ids[selected_pet_index]
	game_manager.modify_stat(pid, "energy", 20)
	_show_feedback("%s is resting... zzz" % _get_selected_pet_name())

func _go_back():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			_go_back()
			return

		if event.keycode == KEY_UP:
			selected_pet_index = max(0, selected_pet_index - 1)
			_highlight_selected()
			_update_stats_display()
			if audio_manager:
				audio_manager.play_sfx("menu_navigate")
			return

		if event.keycode == KEY_DOWN:
			selected_pet_index = min(pet_ids.size() - 1, selected_pet_index + 1)
			_highlight_selected()
			_update_stats_display()
			if audio_manager:
				audio_manager.play_sfx("menu_navigate")
			return

		if event.keycode == KEY_F:
			_action_feed()
			return

		if event.keycode == KEY_P:
			_action_play()
			return

		if event.keycode == KEY_R:
			_action_rest()
			return

		if event.keycode == KEY_E:
			_collect_egg()
			return
