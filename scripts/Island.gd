extends Node3D

# Island scene — pet interactions with keyboard controls
var game_manager
var pets_in_scene: Array = []
var selected_pet_index: int = 0
var pet_ids: Array = []

var _feedback_label: Label
var _stats_label: Label
var _coins_label: Label
var _pet_list_label: Label
var _feedback_timer: float = 0.0

func _ready():
	game_manager = get_tree().root.get_node("GameManager")

	_create_island_environment()
	_spawn_all_pets()
	_create_ui()

	game_manager.pet_stat_changed.connect(_on_stat_changed)
	game_manager.coins_changed.connect(_on_coins_changed)

	if pet_ids.size() > 0:
		_highlight_selected()
		_update_stats_display()

func _create_island_environment():
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(30, 30)
	ground.mesh = plane_mesh
	ground.position.y = -1

	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.2, 0.6, 0.2)
	ground.material_override = ground_material
	add_child(ground)

	var light = DirectionalLight3D.new()
	light.rotation.x = -PI / 4
	light.rotation.y = -PI / 4
	add_child(light)

	var camera = Camera3D.new()
	camera.position = Vector3(0, 8, 15)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(camera)

func _spawn_all_pets():
	var all_pets = game_manager.get_all_pets()

	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]
		var pet = Pet.new()
		pet.pet_id = pet_id
		pet.pet_name = pet_info["name"]
		pet.pet_type = pet_info["type"]

		pet.position = Vector3(randf_range(-10, 10), 0.5, randf_range(-10, 10))

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

	# Coins display (top right)
	_coins_label = Label.new()
	_coins_label.text = "Coins: %d" % game_manager.coins
	_coins_label.position = Vector2(10, 40)
	_coins_label.add_theme_font_size_override("font_size", 18)
	_coins_label.add_theme_color_override("font_color", Color.YELLOW)
	ui.add_child(_coins_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = "UP/DOWN: select pet | F: feed (-5 coins) | P: play (+3 coins) | R: rest | ESC: back"
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
	_feedback_label.position = Vector2(10, 340)
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
		var prefix = "> " if i == selected_pet_index else "  "
		lines += "%s%s (%s) %s\n" % [prefix, info["name"], info["type"], mood]
	_pet_list_label.text = lines

func _update_stats_display():
	if pet_ids.size() == 0:
		_stats_label.text = "No pets on island."
		return
	var pid = pet_ids[selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	var mood = game_manager.get_pet_mood(pid)
	_stats_label.text = "--- %s (%s) --- Mood: %s\nHealth:    %d/100\nHappiness: %d/100\nHunger:    %d/100\nEnergy:    %d/100" % [
		info["name"], info["type"], mood,
		info["health"], info["happiness"], info["hunger"], info["energy"]
	]

func _show_feedback(msg: String):
	_feedback_label.text = msg
	_feedback_timer = 2.5

func _process(delta: float):
	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0:
			_feedback_label.text = ""

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
	var pet_node = _get_selected_pet()
	if pet_node:
		pet_node.do_happy_reaction()
	_show_feedback("%s loved the treats!" % _get_selected_pet_name())

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
	var pet_node = _get_selected_pet()
	if pet_node:
		pet_node.do_happy_reaction()
	_show_feedback("%s had a great time playing! (+3 coins)" % _get_selected_pet_name())

func _action_rest():
	if pet_ids.size() == 0:
		return
	var pid = pet_ids[selected_pet_index]
	game_manager.modify_stat(pid, "energy", 20)
	_show_feedback("%s is resting... zzz" % _get_selected_pet_name())

func _go_back():
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
			return

		if event.keycode == KEY_DOWN:
			selected_pet_index = min(pet_ids.size() - 1, selected_pet_index + 1)
			_highlight_selected()
			_update_stats_display()
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
