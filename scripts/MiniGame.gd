extends Node2D

# Treat-Catching Mini-Game — 5 auto-advancing levels
# L1: Slow fall, few rocks
# L2: Medium fall, some rocks
# L3: Normal fall, 20% rocks
# L4: Fast fall, 25% rocks, golden treats (3 coins)
# L5: Very fast, 30% rocks, golden treats
# Advance: Score 10+

var game_manager
var audio_manager

const ADVANCE_THRESHOLD: int = 10
const CATCHER_SPEED: float = 400.0

# Per-level config: [fall_speed, rock_chance, duration, has_golden]
const LEVEL_CONFIG: Array = [
	[], # unused index 0
	[150.0, 0.10, 30.0, false],
	[200.0, 0.15, 30.0, false],
	[250.0, 0.20, 30.0, false],
	[300.0, 0.25, 35.0, true],
	[350.0, 0.30, 40.0, true],
]

const LEVEL_NAMES: Array = [
	"",
	"Beginner",
	"Easy",
	"Normal",
	"Fast",
	"Expert",
]

var _level: int = 1
var _fall_speed: float = 150.0
var _rock_chance: float = 0.10
var _game_duration: float = 30.0
var _has_golden: bool = false

var _time_remaining: float = 30.0
var _spawn_timer: float = 0.0
var _next_spawn: float = 0.5
var _score: int = 0
var _coins_earned: int = 0
var _game_active: bool = true

var _catcher: ColorRect
var _treats: Array = []
var _time_label: Label
var _score_label: Label
var _level_label: Label
var _result_label: Label
var _screen_width: float = 1152.0
var _screen_height: float = 648.0

var _active_pet_id: int = -1

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")
	game_manager.pending_game = "res://scenes/MiniGame.tscn"

	_level = game_manager.get_game_level("treat_catch")

	var all_pets = game_manager.get_all_pets()
	if all_pets.size() > 0:
		_active_pet_id = all_pets.keys()[0]

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x > 0:
		_screen_width = viewport_size.x
		_screen_height = viewport_size.y

	_apply_level_config()
	_build_ui()

func _apply_level_config():
	var config = LEVEL_CONFIG[_level]
	_fall_speed = config[0]
	_rock_chance = config[1]
	_game_duration = config[2]
	_has_golden = config[3]
	_time_remaining = _game_duration

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

	# Level display
	_level_label = Label.new()
	_level_label.text = "Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	_level_label.position = Vector2(_screen_width / 2.0 - 60, 42)
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(_level_label)

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
	if _has_golden:
		instructions.text += " Golden treats = 3 coins!"
	instructions.position = Vector2(10, _screen_height - 30)
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(instructions)

	# Catcher
	_catcher = ColorRect.new()
	_catcher.size = Vector2(80, 30)
	_catcher.position = Vector2(_screen_width / 2.0 - 40, _screen_height - 70)
	_catcher.color = Color(0.9, 0.6, 0.9)
	add_child(_catcher)

	var catcher_label = Label.new()
	catcher_label.text = "^_^"
	catcher_label.position = Vector2(25, 3)
	catcher_label.add_theme_font_size_override("font_size", 16)
	_catcher.add_child(catcher_label)

	# Result label (hidden)
	_result_label = Label.new()
	_result_label.position = Vector2(_screen_width / 2.0 - 180, _screen_height / 2.0 - 80)
	_result_label.add_theme_font_size_override("font_size", 22)
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
	# Spawn rate scales slightly with level
	var spawn_min = max(0.25, 0.5 - _level * 0.05)
	var spawn_max = max(0.5, 1.0 - _level * 0.1)
	if _spawn_timer >= _next_spawn:
		_spawn_timer = 0.0
		_next_spawn = randf_range(spawn_min, spawn_max)
		_spawn_item()

func _spawn_item():
	var roll = randf()
	var is_rock = roll < _rock_chance
	var is_golden = false
	if not is_rock and _has_golden:
		is_golden = randf() < 0.15  # 15% of treats are golden

	var item = ColorRect.new()
	item.size = Vector2(30, 30)
	item.position = Vector2(randf_range(10, _screen_width - 40), 50)

	if is_rock:
		item.color = Color(0.5, 0.5, 0.5)
		item.set_meta("type", "rock")
	elif is_golden:
		item.color = Color(1.0, 0.84, 0.0)
		item.set_meta("type", "golden")
		var star = Label.new()
		star.text = "$"
		star.position = Vector2(8, 2)
		star.add_theme_font_size_override("font_size", 18)
		item.add_child(star)
	else:
		var colors = [Color.PINK, Color.YELLOW, Color.CYAN, Color(1.0, 0.6, 0.2)]
		item.color = colors[randi() % colors.size()]
		item.set_meta("type", "treat")
		var star = Label.new()
		star.text = "*"
		star.position = Vector2(8, 2)
		star.add_theme_font_size_override("font_size", 18)
		item.add_child(star)

	add_child(item)
	_treats.append(item)

func _handle_falling(delta: float):
	var to_remove = []
	for item in _treats:
		item.position.y += _fall_speed * delta
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
			var item_type = item.get_meta("type")
			if item_type == "rock":
				_coins_earned = max(0, _coins_earned - 1)
				_score -= 1
				if audio_manager:
					audio_manager.play_sfx("wrong")
			elif item_type == "golden":
				_coins_earned += 3
				_score += 3
				if audio_manager:
					audio_manager.play_sfx("coin")
			else:
				_coins_earned += 1
				_score += 1
				if audio_manager:
					audio_manager.play_sfx("coin")
			to_remove.append(item)

	for item in to_remove:
		_treats.erase(item)
		item.queue_free()

func _end_game():
	_game_active = false

	if _coins_earned > 0:
		game_manager.modify_coins(_coins_earned)
	if _active_pet_id >= 0 and _score > 0:
		game_manager.modify_stat(_active_pet_id, "happiness", _score * 2)
		game_manager.add_xp(_active_pet_id, _score)

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_mini_game_score(_score)
		achievement_mgr.check_all()

	# Check for level advance
	var leveled_up = false
	if _score >= ADVANCE_THRESHOLD:
		var new_level = game_manager.advance_game_level("treat_catch")
		if new_level > _level:
			leveled_up = true
			_level = new_level

	var xp_bonus = max(0, _score)
	var result_text = "GAME OVER!\n\nLevel: %d — %s\nScore: %d\nCoins earned: %d\nXP bonus: +%d" % [
		_level, LEVEL_NAMES[_level], _score, max(0, _coins_earned), xp_bonus
	]

	if leveled_up:
		result_text += "\n\nLEVEL UP! Now Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	elif _score < ADVANCE_THRESHOLD:
		result_text += "\n\nNeed score %d to advance (got %d)" % [ADVANCE_THRESHOLD, _score]

	# Award egg for completing the game
	var egg_got = game_manager.collect_egg()
	if egg_got:
		result_text += "\n+1 Egg!"
	else:
		result_text += "\nEgg inventory full!"

	# Clear pending game — player completed it
	game_manager.pending_game = ""

	result_text += "\n\nSPACE: play again | ESC: return to Hub"
	_result_label.text = result_text
	_result_label.visible = true

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

		# Play again after game ends
		if not _game_active and event.keycode == KEY_SPACE:
			get_tree().reload_current_scene()
			return
