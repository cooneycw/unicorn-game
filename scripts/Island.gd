extends Node3D

# Island scene - place to find and interact with pets
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
	add_child(ui)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back to Hub"
	back_btn.rect_position = Vector2(10, 10)
	back_btn.rect_size = Vector2(150, 40)
	back_btn.connect("pressed", self, "_go_back")
	ui.add_child(back_btn)

	# Info label
	var info_label = Label.new()
	info_label.text = "Island - Click on pets to pet them!"
	info_label.rect_position = Vector2(10, 60)
	info_label.text_size = 14
	ui.add_child(info_label)

func _go_back():
	get_tree().change_scene("res://scenes/Main.tscn")

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("Clicked on island at: ", event.position)
