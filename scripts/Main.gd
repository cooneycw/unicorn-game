extends Node3D

# Main game scene (Hub)
var game_manager
var pet_spawn_location = Vector3.ZERO
var selected_pet_id = null

func _ready():
	# Get the game manager singleton
	game_manager = get_tree().root.get_node("GameManager")

	# Create the island environment
	_create_island()

	# Create UI buttons
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
	# Create a simple UI with buttons
	var ui = Control.new()
	ui.anchor_right = 1.0
	ui.anchor_bottom = 1.0
	add_child(ui)

	# Island button
	var island_btn = Button.new()
	island_btn.text = "Visit Island"
	island_btn.rect_position = Vector2(10, 10)
	island_btn.rect_size = Vector2(150, 40)
	island_btn.connect("pressed", self, "_go_to_island")
	ui.add_child(island_btn)

	# Vet button
	var vet_btn = Button.new()
	vet_btn.text = "Visit Vet"
	vet_btn.rect_position = Vector2(170, 10)
	vet_btn.rect_size = Vector2(150, 40)
	vet_btn.connect("pressed", self, "_go_to_vet")
	ui.add_child(vet_btn)

	# Pet info label
	var pet_label = Label.new()
	pet_label.text = "Click a pet to see info"
	pet_label.rect_position = Vector2(10, 60)
	ui.add_child(pet_label)

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

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# Raycast to select pets
		var camera = get_node("Camera3D")
		var from = camera.project_ray_origin(event.position)
		var normal = camera.project_ray_normal(event.position)

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, from + normal * 1000)
		var result = space_state.intersect_ray(query)

		if result:
			print("Clicked on something: ", result.collider)
