extends Node3D

# Main game scene (Hub) — mood summaries, coins, container layout
var game_manager
var selected_menu_item = 0  # 0 = Island, 1 = Vet, 2 = Mini-Game

var _pets_container: VBoxContainer
var _coins_label: Label
var _menu_label: Label
var _welcome_label: Label

func _ready():
	game_manager = get_tree().root.get_node("GameManager")

	_create_island()
	_create_ui()

	if game_manager.get_all_pets().size() == 0:
		_spawn_starting_pets()
	else:
		_refresh_pet_list()

	game_manager.pet_stat_changed.connect(_on_stat_changed)
	game_manager.coins_changed.connect(_on_coins_changed)

	# Show welcome back message if returning from save
	var welcome_msg = game_manager.get_welcome_message()
	if welcome_msg != "":
		_welcome_label.text = welcome_msg
		_welcome_label.visible = true

func _create_island():
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	ground.mesh = plane_mesh
	ground.position.y = -1

	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color.GREEN
	ground.material_override = ground_material
	add_child(ground)

	var light = DirectionalLight3D.new()
	light.rotation.x = -PI / 4
	light.rotation.y = -PI / 4
	add_child(light)

	var camera = Camera3D.new()
	camera.position = Vector3(0, 5, 10)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(camera)

func _create_ui():
	var ui = Control.new()
	ui.anchor_right = 1.0
	ui.anchor_bottom = 1.0
	ui.name = "UI"
	add_child(ui)

	# Main vertical layout
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(400, 600)
	ui.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "HUB - Unicorn Game"
	title.add_theme_font_size_override("font_size", 24)
	title_row.add_child(title)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	# Coins display
	_coins_label = Label.new()
	_coins_label.text = "Coins: %d" % game_manager.coins
	_coins_label.add_theme_font_size_override("font_size", 18)
	_coins_label.add_theme_color_override("font_color", Color.YELLOW)
	title_row.add_child(_coins_label)

	# Welcome back message
	_welcome_label = Label.new()
	_welcome_label.name = "WelcomeLabel"
	_welcome_label.add_theme_font_size_override("font_size", 14)
	_welcome_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_welcome_label.visible = false
	vbox.add_child(_welcome_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Menu options
	_menu_label = Label.new()
	_menu_label.name = "MenuLabel"
	_update_menu_display()
	vbox.add_child(_menu_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Pet summaries header
	var pets_header = Label.new()
	pets_header.text = "Your Pets:"
	pets_header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(pets_header)

	# Pet list container
	_pets_container = VBoxContainer.new()
	_pets_container.name = "PetsContainer"
	vbox.add_child(_pets_container)

	# Separator before tips
	vbox.add_child(HSeparator.new())

	# Gameplay tips
	var tips = Label.new()
	tips.text = "Tips: Visit the Island to feed, play, and rest with your pets.\nEarn coins by playing! Healing at the Vet costs 10 coins.\nTry the Mini-Game to earn extra coins!"
	tips.add_theme_font_size_override("font_size", 12)
	tips.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(tips)

func _refresh_pet_list():
	# Clear existing entries
	for child in _pets_container.get_children():
		child.queue_free()

	var all_pets = game_manager.get_all_pets()
	for pet_id in all_pets.keys():
		var info = all_pets[pet_id]
		var mood = game_manager.get_pet_mood(pet_id)
		var emoji = game_manager.get_mood_emoji(pet_id)

		# Find lowest stat for warning
		var stats = {
			"Health": info["health"],
			"Happiness": info["happiness"],
			"Hunger": info["hunger"],
			"Energy": info["energy"]
		}
		var lowest_name = ""
		var lowest_val = 101
		for sname in stats.keys():
			if stats[sname] < lowest_val:
				lowest_val = stats[sname]
				lowest_name = sname

		var warning = ""
		if lowest_val < 30:
			warning = "  [!%s: %d]" % [lowest_name, lowest_val]

		var row = Label.new()
		row.text = "%s %s (%s) — %s%s" % [emoji, info["name"], info["type"], mood, warning]

		if lowest_val < 20:
			row.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		elif lowest_val < 30:
			row.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

		_pets_container.add_child(row)

func _spawn_starting_pets():
	var pet_names = ["Sparkle", "Rainbow", "Cloud", "Moonlight"]
	var pet_types = ["unicorn", "pegasus", "unicorn", "dragon"]

	for i in range(pet_names.size()):
		var pet_id = game_manager.add_pet(pet_names[i], pet_types[i])
		_spawn_pet_in_world(pet_id)

	_refresh_pet_list()

func _spawn_pet_in_world(pet_id: int):
	var pet_info = game_manager.get_pet_info(pet_id)
	var pet = Pet.new()
	pet.pet_id = pet_id
	pet.pet_name = pet_info["name"]
	pet.pet_type = pet_info["type"]
	pet.position = Vector3(randf_range(-5, 5), 0.5, randf_range(-5, 5))
	add_child(pet)

func _on_stat_changed(_pet_id: int, _stat_name: String, _new_value: int):
	_refresh_pet_list()

func _on_coins_changed(new_amount: int):
	_coins_label.text = "Coins: %d" % new_amount

func _go_to_island():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/Island.tscn")

func _go_to_vet():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/VetClinic.tscn")

func _go_to_minigame():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/MiniGame.tscn")

func _update_menu_display():
	if _menu_label == null:
		return
	var lines = ""
	var items = ["Visit Island (Q)", "Visit Vet (V)", "Play Mini-Game (M)"]
	for i in range(items.size()):
		var prefix = "> " if i == selected_menu_item else "  "
		lines += prefix + items[i] + "\n"
	_menu_label.text = lines.strip_edges()

func _input(event):
	if event is InputEventKey and event.pressed:
		# Dismiss welcome message on any key
		if _welcome_label.visible:
			_welcome_label.visible = false

		if event.keycode == KEY_Q:
			_go_to_island()
			return
		if event.keycode == KEY_V:
			_go_to_vet()
			return
		if event.keycode == KEY_M:
			_go_to_minigame()
			return

		if event.keycode == KEY_UP:
			selected_menu_item = max(0, selected_menu_item - 1)
			_update_menu_display()
			return
		if event.keycode == KEY_DOWN:
			selected_menu_item = min(2, selected_menu_item + 1)
			_update_menu_display()
			return

		if event.keycode == KEY_SPACE:
			if selected_menu_item == 0:
				_go_to_island()
			elif selected_menu_item == 1:
				_go_to_vet()
			else:
				_go_to_minigame()
			return
