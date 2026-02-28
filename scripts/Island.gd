extends Node3D

# Island scene - Keyboard only controls
var game_manager
var pets_in_scene = []

func _ready():
	game_manager = get_tree().root.get_node("GameManager")

	# Create island environment
	_create_island_environment()

	# Spawn all pets on the island
	_spawn_all_pets()

	# Create UI
	_create_ui()

func _create_island_environment():
	# Ground
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(30, 30)
	ground.mesh = plane_mesh
	ground.position.y = -1

	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.2, 0.6, 0.2)  # Green island
	ground.material_override = ground_material
	add_child(ground)

	# Light
	var light = DirectionalLight3D.new()
	light.rotation.x = -PI / 4
	light.rotation.y = -PI / 4
	add_child(light)

	# Camera
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
		pet.health = pet_info["health"]
		pet.happiness = pet_info["happiness"]

		# Random position on island
		pet.position = Vector3(randf_range(-10, 10), 0.5, randf_range(-10, 10))

		add_child(pet)
		pets_in_scene.append(pet)

func _create_ui():
	var ui = Control.new()
	ui.anchor_right = 1.0
	ui.anchor_bottom = 1.0
	ui.name = "UI"
	add_child(ui)

	# Title
	var title = Label.new()
	title.text = "ISLAND"
	title.rect_position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Press ESC or B to go back to Hub"
	instructions.rect_position = Vector2(10, 60)
	ui.add_child(instructions)

	# Pet list
	var pets_label = Label.new()
	pets_label.text = "\nPets on this island:"
	pets_label.rect_position = Vector2(10, 110)
	ui.add_child(pets_label)

	var y_offset = 140
	var all_pets = game_manager.get_all_pets()
	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]
		var pet_text = Label.new()
		pet_text.text = "• %s (%s) - Health: %d/100, Happiness: %d/100" % [
			pet_info["name"],
			pet_info["type"],
			pet_info["health"],
			pet_info["happiness"]
		]
		pet_text.rect_position = Vector2(20, y_offset)
		ui.add_child(pet_text)
		y_offset += 25

func _go_back():
	get_tree().change_scene("res://scenes/Main.tscn")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Go back with ESC or B
		if event.scancode == KEY_ESCAPE or event.scancode == KEY_B:
			_go_back()
			return
