extends Node3D

# Main game scene (Hub) - Keyboard only controls
var game_manager
var selected_menu_item = 0  # 0 = Island, 1 = Vet

func _ready():
	# Get the game manager singleton
	game_manager = get_tree().root.get_node("GameManager")

	# Create the island environment
	_create_island()

	# Create UI
	_create_ui()

	# Spawn some starting pets
	if game_manager.get_all_pets().size() == 0:
		_spawn_starting_pets()

func _create_island():
	# Create ground plane
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	ground.mesh = plane_mesh
	ground.position.y = -1

	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color.GREEN
	ground.material_override = ground_material

	add_child(ground)

	# Create a simple light
	var light = DirectionalLight3D.new()
	light.rotation.x = -PI / 4
	light.rotation.y = -PI / 4
	add_child(light)

	# Create camera
	var camera = Camera3D.new()
	camera.position = Vector3(0, 5, 10)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(camera)

func _create_ui():
	# Create UI
	var ui = Control.new()
	ui.anchor_right = 1.0
	ui.anchor_bottom = 1.0
	ui.name = "UI"
	add_child(ui)

	# Title
	var title = Label.new()
	title.text = "HUB - Unicorn Game"
	title.rect_position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)

	# Menu options
	var menu_label = Label.new()
	menu_label.text = "> Visit Island (Q or UP+SPACE)\n  Visit Vet (V or DOWN+SPACE)"
	menu_label.rect_position = Vector2(10, 50)
	menu_label.name = "MenuLabel"
	ui.add_child(menu_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Use ARROW KEYS to navigate, SPACE to select"
	instructions.rect_position = Vector2(10, 150)
	instructions.add_theme_font_size_override("font_size", 12)
	ui.add_child(instructions)

	# Pet list
	var pets_label = Label.new()
	pets_label.text = "\n\nYour Pets:"
	pets_label.rect_position = Vector2(10, 200)
	ui.add_child(pets_label)

	var y_offset = 230
	var all_pets = game_manager.get_all_pets()
	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]
		var pet_text = Label.new()
		pet_text.text = "• %s (%s) - Health: %d/100" % [pet_info["name"], pet_info["type"], pet_info["health"]]
		pet_text.rect_position = Vector2(20, y_offset)
		ui.add_child(pet_text)
		y_offset += 25

func _spawn_starting_pets():
	# Create a few starting pets
	var pet_names = ["Sparkle", "Rainbow", "Cloud", "Moonlight"]
	var pet_types = ["unicorn", "pegasus", "unicorn", "dragon"]

	for i in range(pet_names.size()):
		var pet_id = game_manager.add_pet(pet_names[i], pet_types[i])
		_spawn_pet_in_world(pet_id)

func _spawn_pet_in_world(pet_id: int):
	var pet_info = game_manager.get_pet_info(pet_id)
	var pet = Pet.new()
	pet.pet_id = pet_id
	pet.pet_name = pet_info["name"]
	pet.pet_type = pet_info["type"]

	# Random position on the island
	pet.position = Vector3(randf_range(-5, 5), 0.5, randf_range(-5, 5))

	add_child(pet)

func _go_to_island():
	get_tree().change_scene("res://scenes/Island.tscn")

func _go_to_vet():
	get_tree().change_scene("res://scenes/VetClinic.tscn")

func _update_menu_display():
	var menu_label = get_node("UI/MenuLabel")
	if selected_menu_item == 0:
		menu_label.text = "> Visit Island (Q or UP+ENTER)\n  Visit Vet (V or DOWN+ENTER)"
	else:
		menu_label.text = "  Visit Island (Q or UP+ENTER)\n> Visit Vet (V or DOWN+ENTER)"

func _input(event):
	if event is InputEventKey and event.pressed:
		# Quick keys
		if event.scancode == KEY_Q:
			_go_to_island()
			return
		if event.scancode == KEY_V:
			_go_to_vet()
			return

		# Arrow key navigation
		if event.scancode == KEY_UP:
			selected_menu_item = 0
			_update_menu_display()
			return
		if event.scancode == KEY_DOWN:
			selected_menu_item = 1
			_update_menu_display()
			return

		# Space to select
		if event.scancode == KEY_SPACE:
			if selected_menu_item == 0:
				_go_to_island()
			else:
				_go_to_vet()
			return
