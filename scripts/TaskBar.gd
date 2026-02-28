extends CanvasLayer

# Persistent top task bar — Save button + Fullscreen toggle
# Autoloaded so it appears on every scene automatically.

var _save_button: Button
var _fullscreen_button: Button
var _save_feedback: Label
var _feedback_timer: float = 0.0

func _ready():
	layer = 100  # render above everything

	var panel = PanelContainer.new()
	panel.anchor_right = 1.0
	panel.size = Vector2(0, 36)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.25, 0.85)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Save button
	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.custom_minimum_size = Vector2(70, 28)
	_save_button.pressed.connect(_on_save_pressed)
	hbox.add_child(_save_button)

	# Save feedback text
	_save_feedback = Label.new()
	_save_feedback.text = ""
	_save_feedback.add_theme_font_size_override("font_size", 13)
	_save_feedback.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	hbox.add_child(_save_feedback)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Fullscreen button
	_fullscreen_button = Button.new()
	_fullscreen_button.custom_minimum_size = Vector2(110, 28)
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_update_fullscreen_label()
	hbox.add_child(_fullscreen_button)

func _process(delta: float):
	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0:
			_save_feedback.text = ""

func _on_save_pressed():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.save_game()
	_save_feedback.text = "Saved!"
	_feedback_timer = 2.0

func _on_fullscreen_pressed():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_label()

func _update_fullscreen_label():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		_fullscreen_button.text = "Windowed"
	else:
		_fullscreen_button.text = "Fullscreen"
