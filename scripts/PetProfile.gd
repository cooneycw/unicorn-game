extends Control

# Pet Profile / Inspect screen — shows close-up 3D model with stats
# Accessed from Island by pressing I on the selected pet

var game_manager
var audio_manager
var _pet_id: int = -1

# UI elements
var _name_label: Label
var _type_label: Label
var _level_label: Label
var _xp_label: Label
var _health_bar: ProgressBar
var _happiness_bar: ProgressBar
var _hunger_bar: ProgressBar
var _energy_bar: ProgressBar
var _health_label: Label
var _happiness_label: Label
var _hunger_label: Label
var _energy_label: Label
var _koala_label: Label
var _instructions_label: Label
var _feedback_label: Label

# 3D pet display
var _viewport: SubViewport
var _pet_node: Pet
var _pet_rotation: float = 0.0

# Rename mode
var _renaming: bool = false
var _rename_buffer: String = ""
var _rename_label: Label

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")
	_pet_id = game_manager.inspecting_pet_id

	if _pet_id < 0 or game_manager.get_pet_info(_pet_id) == null:
		# No valid pet — go back
		get_tree().change_scene_to_file("res://scenes/Island.tscn")
		return

	_create_3d_viewport()
	_create_ui()
	_update_stats()

func _create_3d_viewport():
	# SubViewport for 3D pet rendering
	var container = SubViewportContainer.new()
	container.position = Vector2(50, 80)
	container.size = Vector2(400, 400)
	container.stretch = true
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(400, 400)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	# Camera for the pet view
	var camera = Camera3D.new()
	camera.position = Vector3(0, 0.5, 2.5)
	camera.look_at(Vector3(0, 0.2, 0), Vector3.UP)
	_viewport.add_child(camera)

	# Light
	var light = DirectionalLight3D.new()
	light.rotation.x = -PI / 4
	light.rotation.y = -PI / 6
	light.light_energy = 1.2
	_viewport.add_child(light)

	# Ambient light
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.15, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	# Pet model
	var info = game_manager.get_pet_info(_pet_id)
	_pet_node = Pet.new()
	_pet_node.pet_id = _pet_id
	_pet_node.pet_name = info["name"]
	_pet_node.pet_type = info["type"]
	_pet_node.position = Vector3(0, 0, 0)
	_viewport.add_child(_pet_node)

func _create_ui():
	var info = game_manager.get_pet_info(_pet_id)

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.18)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.z_index = -1
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "PET PROFILE"
	title.position = Vector2(50, 15)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	add_child(title)

	# Stats panel — right side
	var stats_x = 500.0
	var y = 100.0
	var line_h = 36.0

	# Name
	_name_label = Label.new()
	_name_label.position = Vector2(stats_x, y)
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_name_label)
	y += line_h + 4

	# Type
	_type_label = Label.new()
	_type_label.position = Vector2(stats_x, y)
	_type_label.add_theme_font_size_override("font_size", 16)
	_type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	add_child(_type_label)
	y += line_h

	# Level + XP
	_level_label = Label.new()
	_level_label.position = Vector2(stats_x, y)
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color.GOLD)
	add_child(_level_label)
	y += line_h - 4

	_xp_label = Label.new()
	_xp_label.position = Vector2(stats_x, y)
	_xp_label.add_theme_font_size_override("font_size", 14)
	_xp_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	add_child(_xp_label)
	y += line_h + 8

	# Stat bars
	_health_bar = _create_stat_bar("Health", stats_x, y, Color(0.2, 0.8, 0.2))
	_health_label = _health_bar.get_meta("value_label")
	y += line_h + 8

	_happiness_bar = _create_stat_bar("Happiness", stats_x, y, Color(1.0, 0.7, 0.8))
	_happiness_label = _happiness_bar.get_meta("value_label")
	y += line_h + 8

	_hunger_bar = _create_stat_bar("Hunger", stats_x, y, Color(1.0, 0.6, 0.2))
	_hunger_label = _hunger_bar.get_meta("value_label")
	y += line_h + 8

	_energy_bar = _create_stat_bar("Energy", stats_x, y, Color(0.4, 0.6, 1.0))
	_energy_label = _energy_bar.get_meta("value_label")
	y += line_h + 16

	# Koala status
	_koala_label = Label.new()
	_koala_label.position = Vector2(stats_x, y)
	_koala_label.add_theme_font_size_override("font_size", 14)
	add_child(_koala_label)
	y += line_h

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(stats_x, y)
	_feedback_label.add_theme_font_size_override("font_size", 15)
	_feedback_label.add_theme_color_override("font_color", Color.GOLD)
	add_child(_feedback_label)

	# Instructions at bottom
	_instructions_label = Label.new()
	_instructions_label.text = "X: Rename | ESC: Back to Island"
	_instructions_label.position = Vector2(50, 500)
	_instructions_label.add_theme_font_size_override("font_size", 14)
	_instructions_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(_instructions_label)

	# Rename label (hidden by default)
	_rename_label = Label.new()
	_rename_label.position = Vector2(stats_x, 480)
	_rename_label.add_theme_font_size_override("font_size", 18)
	_rename_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_rename_label.visible = false
	add_child(_rename_label)

func _create_stat_bar(stat_name: String, x: float, y: float, color: Color) -> ProgressBar:
	var label = Label.new()
	label.text = stat_name
	label.position = Vector2(x, y)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(label)

	var bar = ProgressBar.new()
	bar.position = Vector2(x + 100, y + 2)
	bar.size = Vector2(200, 18)
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false

	# Style the bar fill color
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.25)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg_style)

	add_child(bar)

	# Value label after bar
	var val_label = Label.new()
	val_label.position = Vector2(x + 310, y)
	val_label.add_theme_font_size_override("font_size", 14)
	val_label.add_theme_color_override("font_color", color)
	add_child(val_label)

	bar.set_meta("value_label", val_label)
	return bar

func _update_stats():
	var info = game_manager.get_pet_info(_pet_id)
	if info == null:
		return

	var cap = game_manager.get_stat_cap(_pet_id)
	var xp_info = game_manager.get_xp_progress(_pet_id)
	var mood = game_manager.get_pet_mood(_pet_id)
	var emoji = game_manager.get_mood_emoji(_pet_id)

	_name_label.text = "%s %s" % [info["name"], emoji]
	_type_label.text = "%s — Mood: %s" % [GameManager.display_type(info["type"]).capitalize(), mood.capitalize()]
	_level_label.text = "Level %d" % info["level"]

	if xp_info["next"] > 0:
		_xp_label.text = "XP: %d / %d" % [xp_info["current"], xp_info["next"]]
	else:
		_xp_label.text = "XP: MAX"

	_health_bar.max_value = cap
	_health_bar.value = info["health"]
	_health_label.text = "%d/%d" % [info["health"], cap]

	_happiness_bar.max_value = cap
	_happiness_bar.value = info["happiness"]
	_happiness_label.text = "%d/%d" % [info["happiness"], cap]

	_hunger_bar.max_value = cap
	_hunger_bar.value = info["hunger"]
	_hunger_label.text = "%d/%d" % [info["hunger"], cap]

	_energy_bar.max_value = cap
	_energy_bar.value = info["energy"]
	_energy_label.text = "%d/%d" % [info["energy"], cap]

	if info.get("has_koala", false):
		_koala_label.text = "Koala Rider!"
		_koala_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		_koala_label.text = ""

func _process(delta: float):
	# Slowly rotate the pet model
	if _pet_node:
		_pet_rotation += delta * 0.5
		_pet_node.rotation.y = _pet_rotation

	# Refresh stats in case of decay
	_update_stats()

func _start_rename():
	_renaming = true
	_rename_buffer = ""
	_rename_label.visible = true
	_rename_label.text = "New name: _\n(Type name, ENTER to confirm, ESC to cancel)"

func _finish_rename():
	if _rename_buffer.length() > 0:
		game_manager.pets[_pet_id]["name"] = _rename_buffer
		if _pet_node:
			_pet_node.pet_name = _rename_buffer
		_feedback_label.text = "Renamed to '%s'!" % _rename_buffer
	_renaming = false
	_rename_label.visible = false
	_rename_buffer = ""

func _cancel_rename():
	_renaming = false
	_rename_label.visible = false
	_rename_buffer = ""

func _go_back():
	game_manager.inspecting_pet_id = -1
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/Island.tscn")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Rename mode input handling
		if _renaming:
			if event.keycode == KEY_ESCAPE:
				_cancel_rename()
				return
			if event.keycode == KEY_ENTER:
				_finish_rename()
				return
			if event.keycode == KEY_BACKSPACE:
				if _rename_buffer.length() > 0:
					_rename_buffer = _rename_buffer.substr(0, _rename_buffer.length() - 1)
				_rename_label.text = "New name: %s_\n(Type name, ENTER to confirm, ESC to cancel)" % _rename_buffer
				return
			if event.unicode > 0 and _rename_buffer.length() < 20:
				var ch = char(event.unicode)
				if ch.strip_edges() != "" or ch == " ":
					_rename_buffer += ch
					_rename_label.text = "New name: %s_\n(Type name, ENTER to confirm, ESC to cancel)" % _rename_buffer
			return

		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			_go_back()
			return

		if event.keycode == KEY_X:
			_start_rename()
			return
