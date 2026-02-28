extends Node2D

# 2D Treat-Catching Mini-Game
# Arrow keys to move catcher left/right. Catch treats for coins + happiness.
# Gray rocks cost 1 coin. Game lasts 30 seconds.

var game_manager

const GAME_DURATION: float = 30.0
const CATCHER_SPEED: float = 400.0
const SPAWN_INTERVAL_MIN: float = 0.4
const SPAWN_INTERVAL_MAX: float = 1.0
const FALL_SPEED: float = 250.0
const ROCK_CHANCE: float = 0.2

var _time_remaining: float = GAME_DURATION
var _spawn_timer: float = 0.0
var _next_spawn: float = 0.5
var _score: int = 0
var _coins_earned: int = 0
var _game_active: bool = true

var _catcher: ColorRect
var _treats: Array = []
var _time_label: Label
var _score_label: Label
var _result_label: Label
var _screen_width: float = 1152.0
var _screen_height: float = 648.0

# Which pet benefits from this mini-game (first pet by default)
var _active_pet_id: int = -1

func _ready():
	game_manager = get_tree().root.get_node("GameManager")

	# Pick first pet as active pet for happiness bonus
	var all_pets = game_manager.get_all_pets()
	if all_pets.size() > 0:
		_active_pet_id = all_pets.keys()[0]

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x > 0:
		_screen_width = viewport_size.x
		_screen_height = viewport_size.y

	_build_ui()

func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.2, 0.35)
	bg.size = Vector2(_screen_width, _screen_height)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "TREAT CATCH!"
	title.position = Vector2(_screen_width / 2.0 - 80, 10)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	# Time display
	_time_label = Label.new()
	_time_label.position = Vector2(10, 10)
	_time_label.add_theme_font_size_override("font_size", 20)
	add_child(_time_label)

	# Score display
	_score_label = Label.new()
	_score_label.position = Vector2(_screen_width - 200, 10)
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(_score_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = "LEFT/RIGHT arrows to move | Catch treats, avoid rocks!"
	instructions.position = Vector2(10, _screen_height - 30)
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(instructions)

	# Catcher (pet representation at bottom)
	_catcher = ColorRect.new()
	_catcher.size = Vector2(80, 30)
	_catcher.position = Vector2(_screen_width / 2.0 - 40, _screen_height - 70)
	_catcher.color = Color(0.9, 0.6, 0.9)
	add_child(_catcher)

	# Catcher label
	var catcher_label = Label.new()
	catcher_label.text = "^_^"
	catcher_label.position = Vector2(25, 3)
	catcher_label.add_theme_font_size_override("font_size", 16)
	_catcher.add_child(catcher_label)

	# Result label (hidden initially)
	_result_label = Label.new()
	_result_label.position = Vector2(_screen_width / 2.0 - 150, _screen_height / 2.0 - 60)
	_result_label.add_theme_font_size_override("font_size", 24)
	_result_label.visible = false
	add_child(_result_label)

	_update_ui()

func _update_ui():
	_time_label.text = "Time: %d" % ceili(_time_remaining)
	_score_label.text = "Score: %d | Coins: +%d" % [_score, _coins_earned]

func _process(delta: float):
	if not _game_active:
		return

	_time_remaining -= delta
	if _time_remaining <= 0:
		_end_game()
		return

	_handle_movement(delta)
	_handle_spawning(delta)
	_handle_falling(delta)
	_check_collisions()
	_update_ui()

func _handle_movement(delta: float):
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0

	_catcher.position.x += direction * CATCHER_SPEED * delta
	_catcher.position.x = clampf(_catcher.position.x, 0, _screen_width - _catcher.size.x)

func _handle_spawning(delta: float):
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn:
		_spawn_timer = 0.0
		_next_spawn = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
		_spawn_item()

func _spawn_item():
	var is_rock = randf() < ROCK_CHANCE
	var item = ColorRect.new()
	item.size = Vector2(30, 30)
	item.position = Vector2(randf_range(10, _screen_width - 40), 50)

	if is_rock:
		item.color = Color(0.5, 0.5, 0.5)
		item.set_meta("is_rock", true)
	else:
		# Treats are colorful
		var colors = [Color.PINK, Color.YELLOW, Color.CYAN, Color(1.0, 0.6, 0.2)]
		item.color = colors[randi() % colors.size()]
		item.set_meta("is_rock", false)

		# Star shape indicator
		var star = Label.new()
		star.text = "*" if not is_rock else "x"
		star.position = Vector2(8, 2)
		star.add_theme_font_size_override("font_size", 18)
		item.add_child(star)

	add_child(item)
	_treats.append(item)

func _handle_falling(delta: float):
	var to_remove = []
	for item in _treats:
		item.position.y += FALL_SPEED * delta
		if item.position.y > _screen_height:
			to_remove.append(item)

	for item in to_remove:
		_treats.erase(item)
		item.queue_free()

func _check_collisions():
	var catcher_rect = Rect2(_catcher.position, _catcher.size)
	var to_remove = []

	for item in _treats:
		var item_rect = Rect2(item.position, item.size)
		if catcher_rect.intersects(item_rect):
			if item.get_meta("is_rock"):
				_coins_earned = max(0, _coins_earned - 1)
				_score -= 1
			else:
				_coins_earned += 1
				_score += 1
			to_remove.append(item)

	for item in to_remove:
		_treats.erase(item)
		item.queue_free()

func _end_game():
	_game_active = false

	# Apply rewards
	if _coins_earned > 0:
		game_manager.modify_coins(_coins_earned)
	if _active_pet_id >= 0 and _score > 0:
		game_manager.modify_stat(_active_pet_id, "happiness", _score * 2)

	# Show results
	_result_label.text = "GAME OVER!\n\nScore: %d\nCoins earned: %d\nHappiness bonus: +%d\n\nPress ESC to return to Hub" % [
		_score, max(0, _coins_earned), max(0, _score * 2)
	]
	_result_label.visible = true

	# Clear remaining treats
	for item in _treats:
		item.queue_free()
	_treats.clear()

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
