extends Node3D

# Vet Clinic scene - Keyboard only controls
var game_manager
var selected_pet_id = null
var pet_list = []  # List of pet IDs
var selected_pet_index = 0

func _ready():
	game_manager = get_tree().root.get_node("GameManager")

	# Create clinic environment
	_create_clinic_environment()

	# Create UI
	_create_ui()

	# Build pet list
	var all_pets = game_manager.get_all_pets()
	for pet_id in all_pets.keys():
		pet_list.append(pet_id)

	if pet_list.size() > 0:
		_select_pet(pet_list[0])

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
	ui.name = "UI"
	add_child(ui)

	# Title
	var title = Label.new()
	title.text = "VETERINARY CLINIC"
	title.rect_position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)

	# Instructions
	var instructions = Label.new()
	instructions.text = "UP/DOWN to select pet, H to heal, ESC to go back"
	instructions.rect_position = Vector2(10, 60)
	ui.add_child(instructions)

	# Pet selection area
	var pet_label = Label.new()
	pet_label.text = "\nSelect a pet to heal:"
	pet_label.rect_position = Vector2(10, 110)
	ui.add_child(pet_label)

	var all_pets = game_manager.get_all_pets()
	var y_offset = 140

	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]

		var pet_text = Label.new()
		pet_text.text = "  %s (%s) - Health: %d/100" % [pet_info["name"], pet_info["type"], pet_info["health"]]
		pet_text.rect_position = Vector2(10, y_offset)
		pet_text.name = "Pet_%d" % pet_id
		ui.add_child(pet_text)

		y_offset += 30

	# Status label
	var status_label = Label.new()
	status_label.text = ""
	status_label.rect_position = Vector2(10, y_offset + 30)
	status_label.name = "StatusLabel"
	ui.add_child(status_label)

func _select_pet(pet_id: int):
	selected_pet_id = pet_id
	var pet_info = game_manager.get_pet_info(pet_id)

	var status_label = get_node("UI/StatusLabel")
	status_label.text = "\n> Selected: %s (%s)\n  Health: %d/100\n  Happiness: %d/100\n\nPress H to heal, or UP/DOWN to choose another pet" % [
		pet_info["name"],
		pet_info["type"],
		pet_info["health"],
		pet_info["happiness"]
	]

	# Update visual highlighting
	var all_pets = game_manager.get_all_pets()
	for pid in all_pets.keys():
		var pet_text = get_node("UI/Pet_%d" % pid)
		if pid == pet_id:
			pet_text.text = "> %s (%s) - Health: %d/100" % [all_pets[pid]["name"], all_pets[pid]["type"], all_pets[pid]["health"]]
		else:
			pet_text.text = "  %s (%s) - Health: %d/100" % [all_pets[pid]["name"], all_pets[pid]["type"], all_pets[pid]["health"]]

func _heal_pet():
	if selected_pet_id == null:
		print("No pet selected!")
		return

	var success = game_manager.heal_pet(selected_pet_id, 30)

	if success:
		var pet_info = game_manager.get_pet_info(selected_pet_id)
		var status_label = get_node("UI/StatusLabel")
		status_label.text = "\n✓ HEALED! %s's health increased to %d/100\n\nPress H to heal again, or UP/DOWN to select another pet" % [
			pet_info["name"],
			pet_info["health"]
		]

		# Update pet display
		var pet_text = get_node("UI/Pet_%d" % selected_pet_id)
		pet_text.text = "> %s (%s) - Health: %d/100" % [pet_info["name"], pet_info["type"], pet_info["health"]]

		print("Healed pet: ", pet_info["name"])

func _go_back():
	get_tree().change_scene("res://scenes/Main.tscn")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Go back with ESC
		if event.scancode == KEY_ESCAPE or event.scancode == KEY_B:
			_go_back()
			return

		# Heal with H
		if event.scancode == KEY_H:
			_heal_pet()
			return

		# Navigate pets with arrow keys
		if event.scancode == KEY_UP:
			selected_pet_index = max(0, selected_pet_index - 1)
			if selected_pet_index < pet_list.size():
				_select_pet(pet_list[selected_pet_index])
			return

		if event.scancode == KEY_DOWN:
			selected_pet_index = min(pet_list.size() - 1, selected_pet_index + 1)
			if selected_pet_index < pet_list.size():
				_select_pet(pet_list[selected_pet_index])
			return
