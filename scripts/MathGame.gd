extends Node2D

# Math Game — Times Tables practice
# UP/DOWN to select answer, SPACE to confirm, difficulty levels, coin rewards

var game_manager
var audio_manager

# Game state
const GAME_DURATION: float = 60.0
var _time_remaining: float = GAME_DURATION
var _game_active: bool = false
var _score: int = 0
var _coins_earned: int = 0
var _correct_count: int = 0
var _wrong_count: int = 0
var _active_pet_id: int = -1
var _streak: int = 0

# Difficulty
var difficulty: int = 1  # 0=easy(1-5), 1=medium(1-10), 2=hard(1-12)
var selecting_difficulty: bool = true

# Current problem
var _factor_a: int = 0
var _factor_b: int = 0
var _correct_answer: int = 0
var _choices: Array = []
var _selected_choice: int = 0

# UI elements
var _time_label: Label
var _score_label: Label
var _problem_label: Label
var _choices_labels: Array = []
var _feedback_label: Label
var _result_label: Label
var _difficulty_label: Label
var _info_label: Label
var _streak_label: Label

var _screen_width: float = 1152.0
var _screen_height: float = 648.0

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")

	var all_pets = game_manager.get_all_pets()
	if all_pets.size() > 0:
		_active_pet_id = all_pets.keys()[0]

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x > 0:
		_screen_width = viewport_size.x
		_screen_height = viewport_size.y

	_build_ui()
	_show_difficulty_select()

func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.15, 0.3)
	bg.size = Vector2(_screen_width, _screen_height)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "MATH CHALLENGE"
	title.position = Vector2(_screen_width / 2.0 - 100, 10)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	add_child(title)

	# Time display
	_time_label = Label.new()
	_time_label.position = Vector2(15, 15)
	_time_label.add_theme_font_size_override("font_size", 20)
	add_child(_time_label)

	# Score display
	_score_label = Label.new()
	_score_label.position = Vector2(_screen_width - 250, 15)
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(_score_label)

	# Streak display
	_streak_label = Label.new()
	_streak_label.position = Vector2(_screen_width - 250, 42)
	_streak_label.add_theme_font_size_override("font_size", 16)
	_streak_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	add_child(_streak_label)

	# Problem display (large, centered)
	_problem_label = Label.new()
	_problem_label.position = Vector2(_screen_width / 2.0 - 120, 120)
	_problem_label.add_theme_font_size_override("font_size", 48)
	_problem_label.add_theme_color_override("font_color", Color.WHITE)
	_problem_label.visible = false
	add_child(_problem_label)

	# Answer choices (4 options)
	for i in range(4):
		var choice = Label.new()
		choice.position = Vector2(_screen_width / 2.0 - 80, 220 + i * 55)
		choice.add_theme_font_size_override("font_size", 28)
		choice.visible = false
		add_child(choice)
		_choices_labels.append(choice)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(_screen_width / 2.0 - 100, 460)
	_feedback_label.add_theme_font_size_override("font_size", 20)
	add_child(_feedback_label)

	# Info/instructions
	_info_label = Label.new()
	_info_label.position = Vector2(15, _screen_height - 30)
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_info_label)

	# Difficulty selector
	_difficulty_label = Label.new()
	_difficulty_label.position = Vector2(300, 200)
	_difficulty_label.add_theme_font_size_override("font_size", 18)
	add_child(_difficulty_label)

	# Result (hidden)
	_result_label = Label.new()
	_result_label.position = Vector2(_screen_width / 2.0 - 150, _screen_height / 2.0 - 80)
	_result_label.add_theme_font_size_override("font_size", 22)
	_result_label.visible = false
	add_child(_result_label)

func _show_difficulty_select():
	selecting_difficulty = true
	_update_difficulty_display()
	_info_label.text = "UP/DOWN: choose difficulty | SPACE: start | ESC: back to hub"

func _update_difficulty_display():
	var lines = ""
	var options = ["Easy (1-5 tables)", "Medium (1-10 tables)", "Hard (1-12 tables)"]
	for i in range(options.size()):
		var prefix = "> " if i == difficulty else "  "
		lines += prefix + options[i] + "\n"
	_difficulty_label.text = "Choose Difficulty:\n\n" + lines

func _start_game():
	selecting_difficulty = false
	_difficulty_label.text = ""
	_game_active = true
	_time_remaining = GAME_DURATION
	_score = 0
	_coins_earned = 0
	_correct_count = 0
	_wrong_count = 0
	_streak = 0

	_problem_label.visible = true
	for label in _choices_labels:
		label.visible = true
	_result_label.visible = false

	_info_label.text = "UP/DOWN: select answer | SPACE: confirm | ESC: back"
	_generate_problem()
	_update_ui()

func _generate_problem():
	var max_factor = 5
	match difficulty:
		0: max_factor = 5
		1: max_factor = 10
		2: max_factor = 12

	_factor_a = randi_range(1, max_factor)
	_factor_b = randi_range(1, max_factor)
	_correct_answer = _factor_a * _factor_b

	# Generate 3 wrong answers (distinct, positive, plausible)
	var wrong_answers: Array = []
	var attempts = 0
	while wrong_answers.size() < 3 and attempts < 50:
		attempts += 1
		var wrong: int
		var strategy = randi() % 4
		match strategy:
			0: wrong = _correct_answer + randi_range(-5, 5)
			1: wrong = _factor_a + _factor_b  # common mistake: addition
			2: wrong = randi_range(1, max_factor) * randi_range(1, max_factor)
			3: wrong = _correct_answer + randi_range(1, 3) * (1 if randi() % 2 == 0 else -1)
		if wrong > 0 and wrong != _correct_answer and wrong not in wrong_answers:
			wrong_answers.append(wrong)

	while wrong_answers.size() < 3:
		wrong_answers.append(_correct_answer + wrong_answers.size() + 1)

	_choices = [_correct_answer] + wrong_answers
	_choices.shuffle()
	_selected_choice = 0

	_problem_label.text = "%d x %d = ?" % [_factor_a, _factor_b]
	_draw_choices()

func _draw_choices():
	for i in range(4):
		var prefix = "> " if i == _selected_choice else "  "
		_choices_labels[i].text = prefix + str(_choices[i])
		if i == _selected_choice:
			_choices_labels[i].add_theme_color_override("font_color", Color.GOLD)
		else:
			_choices_labels[i].add_theme_color_override("font_color", Color.WHITE)

func _submit_answer():
	if _choices[_selected_choice] == _correct_answer:
		_correct_count += 1
		_streak += 1
		var bonus = 2
		if _streak >= 5:
			bonus = 4  # streak bonus
		elif _streak >= 3:
			bonus = 3
		_coins_earned += bonus
		game_manager.modify_coins(bonus)
		if audio_manager:
			audio_manager.play_sfx("correct")
		_feedback_label.text = "Correct! +%d coins" % bonus
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		_wrong_count += 1
		_streak = 0
		if audio_manager:
			audio_manager.play_sfx("wrong")
		_feedback_label.text = "Wrong! %d x %d = %d" % [_factor_a, _factor_b, _correct_answer]
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	# Next problem
	_generate_problem()

func _update_ui():
	_time_label.text = "Time: %d" % ceili(_time_remaining)
	_score_label.text = "Correct: %d | Coins: +%d" % [_correct_count, _coins_earned]
	_streak_label.text = "Streak: %d" % _streak if _streak >= 2 else ""

func _end_game():
	_game_active = false

	if _active_pet_id >= 0 and _correct_count > 0:
		game_manager.modify_stat(_active_pet_id, "happiness", _correct_count * 2)
		game_manager.add_xp(_active_pet_id, _correct_count * 5)

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_math_score(_correct_count)
		achievement_mgr.check_all()

	# Hide game elements
	_problem_label.visible = false
	for label in _choices_labels:
		label.visible = false
	_feedback_label.text = ""

	var xp_bonus = _correct_count * 5
	_result_label.text = "TIME'S UP!\n\nCorrect: %d\nWrong: %d\nCoins earned: %d\nXP bonus: +%d\n\nPress ESC to return to Hub" % [
		_correct_count, _wrong_count, max(0, _coins_earned), xp_bonus
	]
	_result_label.visible = true

func _process(delta: float):
	if not _game_active:
		return

	_time_remaining -= delta
	if _time_remaining <= 0:
		_end_game()
		return

	_update_ui()

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
			return

		if selecting_difficulty:
			if event.keycode == KEY_UP:
				difficulty = max(0, difficulty - 1)
				_update_difficulty_display()
				if audio_manager:
					audio_manager.play_sfx("menu_navigate")
			elif event.keycode == KEY_DOWN:
				difficulty = min(2, difficulty + 1)
				_update_difficulty_display()
				if audio_manager:
					audio_manager.play_sfx("menu_navigate")
			elif event.keycode == KEY_SPACE:
				if audio_manager:
					audio_manager.play_sfx("menu_select")
				_start_game()
			return

		if not _game_active:
			return

		if event.keycode == KEY_UP:
			_selected_choice = max(0, _selected_choice - 1)
			_draw_choices()
		elif event.keycode == KEY_DOWN:
			_selected_choice = min(3, _selected_choice + 1)
			_draw_choices()
		elif event.keycode == KEY_SPACE:
			_submit_answer()
