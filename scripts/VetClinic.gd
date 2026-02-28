extends Node3D

# Vet Clinic scene - heal injured pets
var game_manager
var selected_pet_id = null
var pet_buttons = {}

func _ready():
	game_manager = get_tree().root.get_node("GameManager")

	# Create clinic environment
	_create_clinic_environment()

	# Create UI
	_create_ui()

func _create_clinic_environment():
	# Floor (white clinic floor)
	var floor = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	floor.mesh = plane_mesh
	floor.position.y = -1

	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color.WHITE
	floor.material_override = floor_material
	add_child(floor)

	# Light (bright clinic light)
	var light = DirectionalLight3D.new()
	light.rotation.x = -PI / 3
	light.rotation.y = 0
	add_child(light)

	# Camera
	var camera = Camera3D.new()
	camera.position = Vector3(0, 5, 10)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(camera)

func _create_ui():
	var ui = Control.new()
	ui.anchor_right = 1.0
	ui.anchor_bottom = 1.0
	add_child(ui)

	# Title
	var title = Label.new()
	title.text = "Unicorn Veterinary Clinic"
	title.rect_position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back to Hub"
	back_btn.rect_position = Vector2(10, 50)
	back_btn.rect_size = Vector2(150, 40)
	back_btn.connect("pressed", self, "_go_back")
	ui.add_child(back_btn)

	# Pet selection area
	var all_pets = game_manager.get_all_pets()
	var y_offset = 100

	var pet_label = Label.new()
	pet_label.text = "Select a pet to heal:"
	pet_label.rect_position = Vector2(10, y_offset)
	ui.add_child(pet_label)

	y_offset += 30

	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]
		var health_text = "Health: %d/100" % pet_info["health"]

		var pet_btn = Button.new()
		pet_btn.text = "%s (%s) - %s" % [pet_info["name"], pet_info["type"], health_text]
		pet_btn.rect_position = Vector2(10, y_offset)
		pet_btn.rect_size = Vector2(300, 40)
		pet_btn.connect("pressed", self, "_select_pet", [pet_id])
		ui.add_child(pet_btn)

		pet_buttons[pet_id] = pet_btn

		y_offset += 50

	# Heal button
	var heal_btn = Button.new()
	heal_btn.text = "Heal Selected Pet (Click to Heal!)"
	heal_btn.rect_position = Vector2(10, y_offset)
	heal_btn.rect_size = Vector2(300, 60)
	heal_btn.name = "HealButton"
	heal_btn.connect("pressed", self, "_heal_pet")
	ui.add_child(heal_btn)

	# Status label
	var status_label = Label.new()
	status_label.text = "No pet selected"
	status_label.rect_position = Vector2(350, 100)
	status_label.name = "StatusLabel"
	ui.add_child(status_label)

func _select_pet(pet_id: int):
	selected_pet_id = pet_id
	var pet_info = game_manager.get_pet_info(pet_id)

	var status_label = get_node("Control/StatusLabel")
	status_label.text = "Selected: %s\nHealth: %d/100\nHappiness: %d/100" % [
		pet_info["name"],
		pet_info["health"],
		pet_info["happiness"]
	]

	# Highlight the selected button
	for pid in pet_buttons.keys():
		if pid == pet_id:
			pet_buttons[pid].modulate = Color(0.7, 1.0, 0.7)  # Light green
		else:
			pet_buttons[pid].modulate = Color.WHITE

func _heal_pet():
	if selected_pet_id == null:
		print("No pet selected!")
		return

	var success = game_manager.heal_pet(selected_pet_id, 30)

	if success:
		var pet_info = game_manager.get_pet_info(selected_pet_id)
		var status_label = get_node("Control/StatusLabel")
		status_label.text = "Healed! %s's health: %d/100" % [
			pet_info["name"],
			pet_info["health"]
		]

		# Update the pet button text
		var pet_btn = pet_buttons[selected_pet_id]
		pet_btn.text = "%s - Health: %d/100" % [
			pet_info["name"],
			pet_info["health"]
		]

		print("Healed pet: ", pet_info["name"])

func _go_back():
	get_tree().change_scene("res://scenes/Main.tscn")
