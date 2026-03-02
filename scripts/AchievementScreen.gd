extends Control

# Achievement sticker book — grid display of unlocked/locked achievements

var _game_manager
var _achievement_manager

func _ready():
	_game_manager = get_tree().root.get_node("GameManager")
	_achievement_manager = get_tree().root.get_node("AchievementManager")

	_build_ui()

func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.2)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(700, 500)
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "ACHIEVEMENT STICKER BOOK"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	var subtitle = Label.new()
	var unlocked_count = _achievement_manager.get_unlocked_ids().size()
	var total_count = _achievement_manager.ACHIEVEMENTS.size()
	subtitle.text = "Unlocked: %d / %d" % [unlocked_count, total_count]
	subtitle.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Achievement grid (using VBoxContainer with rows)
	var grid = VBoxContainer.new()
	grid.name = "Grid"
	vbox.add_child(grid)

	for achievement_id in _achievement_manager.ACHIEVEMENTS.keys():
		var info = _achievement_manager.get_display_info(achievement_id)
		var unlocked = _achievement_manager.is_unlocked(achievement_id)

		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 50

		# Status indicator
		var status = Label.new()
		if unlocked:
			status.text = "[*] "
			status.add_theme_color_override("font_color", Color.GOLD)
		else:
			status.text = "[?] "
			status.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		status.add_theme_font_size_override("font_size", 20)
		row.add_child(status)

		# Name and description
		var text_vbox = VBoxContainer.new()
		var name_label = Label.new()
		if unlocked:
			name_label.text = info["name"]
			name_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			name_label.text = "???"
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		name_label.add_theme_font_size_override("font_size", 16)
		text_vbox.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = info["desc"]
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		text_vbox.add_child(desc_label)

		row.add_child(text_vbox)

		# Spacer
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		# Reward
		var reward_label = Label.new()
		reward_label.text = "+%d coins" % info["reward"]
		reward_label.add_theme_font_size_override("font_size", 14)
		if unlocked:
			reward_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			reward_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		row.add_child(reward_label)

		grid.add_child(row)

	vbox.add_child(HSeparator.new())

	# Back instruction
	var back_label = Label.new()
	back_label.text = "Press ESC to return to Hub"
	back_label.add_theme_font_size_override("font_size", 14)
	back_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(back_label)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			var save_manager = get_tree().root.get_node_or_null("SaveManager")
			if save_manager:
				save_manager.on_scene_transition()
			get_tree().change_scene_to_file("res://scenes/Main.tscn")
