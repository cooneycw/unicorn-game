extends Node3D

# Vet Clinic scene — healing costs coins, keyboard controls
var game_manager
var audio_manager
var selected_pet_id = null
var pet_list = []  # List of pet IDs
var selected_pet_index = 0

var _coins_label: Label

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")

	_create_clinic_environment()
	_create_ui()

	var all_pets = game_manager.get_all_pets()
	for pet_id in all_pets.keys():
		pet_list.append(pet_id)

	if pet_list.size() > 0:
		_select_pet(pet_list[0])

	game_manager.coins_changed.connect(_on_coins_changed)

func _create_clinic_environment():
	var floor_node = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	floor_node.mesh = plane_mesh
	floor_node.position.y = -1

	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color.WHITE
	floor_node.material_override = floor_material
	add_child(floor_node)

	var light = DirectionalLight3D.new()
	light.rotation.x = -PI / 3
	light.rotation.y = 0
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

	# Title
	var title = Label.new()
	title.text = "VETERINARY CLINIC"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)

	# Coins display
	_coins_label = Label.new()
	_coins_label.text = "Coins: %d (Heal costs 10)" % game_manager.coins
	_coins_label.position = Vector2(10, 40)
	_coins_label.add_theme_font_size_override("font_size", 16)
	_coins_label.add_theme_color_override("font_color", Color.YELLOW)
	ui.add_child(_coins_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = "UP/DOWN to select pet, H to heal (10 coins), ESC to go back"
	instructions.position = Vector2(10, 65)
	ui.add_child(instructions)

	# Pet selection area
	var pet_label = Label.new()
	pet_label.text = "Select a pet to heal:"
	pet_label.position = Vector2(10, 100)
	ui.add_child(pet_label)

	var all_pets = game_manager.get_all_pets()
	var y_offset = 125

	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]

		var pet_text = Label.new()
		pet_text.text = "  %s (%s) - Health: %d/100" % [pet_info["name"], pet_info["type"], pet_info["health"]]
		pet_text.position = Vector2(10, y_offset)
		pet_text.name = "Pet_%d" % pet_id
		ui.add_child(pet_text)

		y_offset += 30

	# Status label
	var status_label = Label.new()
	status_label.text = ""
	status_label.position = Vector2(10, y_offset + 20)
	status_label.name = "StatusLabel"
	ui.add_child(status_label)

func _on_coins_changed(new_amount: int):
	_coins_label.text = "Coins: %d (Heal costs 10)" % new_amount

func _select_pet(pet_id: int):
	selected_pet_id = pet_id
	var pet_info = game_manager.get_pet_info(pet_id)
	var mood = game_manager.get_pet_mood(pet_id)

	var status_label = get_node("UI/StatusLabel")
	status_label.text = "> Selected: %s (%s) — Mood: %s\n  Health: %d/100\n  Happiness: %d/100\n  Hunger: %d/100\n  Energy: %d/100\n\nPress H to heal, or UP/DOWN to choose another pet" % [
		pet_info["name"],
		pet_info["type"],
		mood,
		pet_info["health"],
		pet_info["happiness"],
		pet_info["hunger"],
		pet_info["energy"]
	]

	# Update visual highlighting
	var all_pets = game_manager.get_all_pets()
	for pid in all_pets.keys():
		var pet_text = get_node("UI/Pet_%d" % pid)
		var pinfo = all_pets[pid]
		if pid == pet_id:
			pet_text.text = "> %s (%s) - Health: %d/100" % [pinfo["name"], pinfo["type"], pinfo["health"]]
		else:
			pet_text.text = "  %s (%s) - Health: %d/100" % [pinfo["name"], pinfo["type"], pinfo["health"]]

func _heal_pet():
	if selected_pet_id == null:
		return

	if game_manager.coins < 10:
		var status_label = get_node("UI/StatusLabel")
		status_label.text = "Not enough coins! Healing costs 10 coins.\nYou have %d coins.\n\nVisit the Island and play with pets to earn coins!" % game_manager.coins
		return

	var success = game_manager.heal_pet(selected_pet_id, 30)

	if success:
		var pet_info = game_manager.get_pet_info(selected_pet_id)
		var status_label = get_node("UI/StatusLabel")
		status_label.text = "HEALED! %s's health increased to %d (-10 coins, +3 XP)\n\nPress H to heal again, or UP/DOWN to select another pet" % [
			pet_info["name"],
			pet_info["health"]
		]
		if audio_manager:
			audio_manager.play_sfx("heal")

		var pet_text = get_node("UI/Pet_%d" % selected_pet_id)
		pet_text.text = "> %s (%s) - Health: %d/100" % [pet_info["name"], pet_info["type"], pet_info["health"]]

		var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
		if achievement_mgr:
			achievement_mgr.check_all()

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

		# Manual save
		if event.keycode == KEY_S and event.ctrl_pressed:
			var save_manager = get_tree().root.get_node_or_null("SaveManager")
			if save_manager:
				save_manager.save_game()
			var status_label = get_node("UI/StatusLabel")
			status_label.text = "Game saved!"
			return

		if event.keycode == KEY_H:
			_heal_pet()
			return

		if event.keycode == KEY_UP:
			selected_pet_index = max(0, selected_pet_index - 1)
			if selected_pet_index < pet_list.size():
				_select_pet(pet_list[selected_pet_index])
			return

		if event.keycode == KEY_DOWN:
			selected_pet_index = min(pet_list.size() - 1, selected_pet_index + 1)
			if selected_pet_index < pet_list.size():
				_select_pet(pet_list[selected_pet_index])
			return
