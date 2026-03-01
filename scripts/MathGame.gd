extends Node2D

# Math Game — 10 auto-advancing levels
# L1-3: Addition (1-5, 1-10, 1-20)
# L4: Subtraction (1-10)
# L5-7: Multiplication (1-5, 1-10, 1-12)
# L8: Division (whole numbers)
# L9: Mixed add/subtract (1-20)
# L10: Mixed all operations (1-12)
# Advance: 8+ correct in 60 seconds

var game_manager
var audio_manager

# Game state
const GAME_DURATION: float = 60.0
const ADVANCE_THRESHOLD: int = 8
var _time_remaining: float = GAME_DURATION
var _game_active: bool = false
var _correct_count: int = 0
var _wrong_count: int = 0
var _coins_earned: int = 0
var _active_pet_id: int = -1
var _streak: int = 0
var _level: int = 1

# Current problem
var _question_text: String = ""
var _correct_answer: int = 0
var _choices: Array = []
var _selected_choice: int = 0

# UI elements
var _time_label: Label
var _score_label: Label
var _level_label: Label
var _problem_label: Label
var _choices_labels: Array = []
var _feedback_label: Label
var _result_label: Label
var _info_label: Label
var _streak_label: Label

var _screen_width: float = 1152.0
var _screen_height: float = 648.0

# Level descriptions shown to player
const LEVEL_NAMES: Array = [
	"", # unused index 0
	"Addition (1-5)",
	"Addition (1-10)",
	"Addition (1-20)",
	"Subtraction (1-10)",
	"Multiplication (1-5)",
	"Multiplication (1-10)",
	"Multiplication (1-12)",
	"Division",
	"Mixed Add/Subtract",
	"Mixed All Operations",
]

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")
	game_manager.pending_game = "res://scenes/MathGame.tscn"

	_level = game_manager.get_game_level("math")

	var all_pets = game_manager.get_all_pets()
	if all_pets.size() > 0:
		_active_pet_id = all_pets.keys()[0]

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x > 0:
		_screen_width = viewport_size.x
		_screen_height = viewport_size.y

	_build_ui()
	_start_game()

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

	# Level display
	_level_label = Label.new()
	_level_label.position = Vector2(_screen_width / 2.0 - 100, 45)
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(_level_label)

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
	_problem_label.position = Vector2(_screen_width / 2.0 - 120, 100)
	_problem_label.add_theme_font_size_override("font_size", 48)
	_problem_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_problem_label)

	# Answer choices (4 options)
	for i in range(4):
		var choice = Label.new()
		choice.position = Vector2(_screen_width / 2.0 - 80, 200 + i * 55)
		choice.add_theme_font_size_override("font_size", 28)
		add_child(choice)
		_choices_labels.append(choice)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(_screen_width / 2.0 - 100, 440)
	_feedback_label.add_theme_font_size_override("font_size", 20)
	add_child(_feedback_label)

	# Info/instructions
	_info_label = Label.new()
	_info_label.position = Vector2(15, _screen_height - 30)
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_info_label.text = "UP/DOWN: select answer | SPACE: confirm | ESC: back"
	add_child(_info_label)

	# Result (hidden)
	_result_label = Label.new()
	_result_label.position = Vector2(_screen_width / 2.0 - 180, _screen_height / 2.0 - 100)
	_result_label.add_theme_font_size_override("font_size", 22)
	_result_label.visible = false
	add_child(_result_label)

func _start_game():
	_game_active = true
	_time_remaining = GAME_DURATION
	_correct_count = 0
	_wrong_count = 0
	_coins_earned = 0
	_streak = 0

	_level_label.text = "Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	_problem_label.visible = true
	for label in _choices_labels:
		label.visible = true
	_result_label.visible = false

	_generate_problem()
	_update_ui()

func _generate_problem():
	match _level:
		1: _gen_addition(1, 5)
		2: _gen_addition(1, 10)
		3: _gen_addition(1, 20)
		4: _gen_subtraction(1, 10)
		5: _gen_multiplication(1, 5)
		6: _gen_multiplication(1, 10)
		7: _gen_multiplication(1, 12)
		8: _gen_division()
		9: _gen_mixed_add_sub(1, 20)
		10: _gen_mixed_all()

	_make_choices()
	_selected_choice = 0
	_problem_label.text = _question_text
	_draw_choices()

func _gen_addition(min_val: int, max_val: int):
	var a = randi_range(min_val, max_val)
	var b = randi_range(min_val, max_val)
	_question_text = "%d + %d = ?" % [a, b]
	_correct_answer = a + b

func _gen_subtraction(min_val: int, max_val: int):
	var a = randi_range(min_val, max_val)
	var b = randi_range(min_val, max_val)
	if b > a:
		var tmp = a
		a = b
		b = tmp
	_question_text = "%d - %d = ?" % [a, b]
	_correct_answer = a - b

func _gen_multiplication(min_val: int, max_val: int):
	var a = randi_range(min_val, max_val)
	var b = randi_range(min_val, max_val)
	_question_text = "%d x %d = ?" % [a, b]
	_correct_answer = a * b

func _gen_division():
	# Generate division with whole number result
	var divisor = randi_range(1, 10)
	var result = randi_range(1, 10)
	var dividend = divisor * result
	_question_text = "%d / %d = ?" % [dividend, divisor]
	_correct_answer = result

func _gen_mixed_add_sub(min_val: int, max_val: int):
	if randi() % 2 == 0:
		_gen_addition(min_val, max_val)
	else:
		_gen_subtraction(min_val, max_val)

func _gen_mixed_all():
	var op = randi() % 4
	match op:
		0: _gen_addition(1, 20)
		1: _gen_subtraction(1, 20)
		2: _gen_multiplication(1, 12)
		3: _gen_division()

func _make_choices():
	var wrong_answers: Array = []
	var attempts = 0
	while wrong_answers.size() < 3 and attempts < 50:
		attempts += 1
		var wrong: int
		var strategy = randi() % 4
		match strategy:
			0: wrong = _correct_answer + randi_range(-5, 5)
			1: wrong = _correct_answer + randi_range(1, 3)
			2: wrong = _correct_answer - randi_range(1, 3)
			3: wrong = abs(_correct_answer + randi_range(-10, 10))
		if wrong >= 0 and wrong != _correct_answer and wrong not in wrong_answers:
			wrong_answers.append(wrong)

	while wrong_answers.size() < 3:
		wrong_answers.append(_correct_answer + wrong_answers.size() + 1)

	_choices = [_correct_answer] + wrong_answers
	_choices.shuffle()

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
			bonus = 4
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
		_feedback_label.text = "Wrong! Answer: %d" % _correct_answer
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

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

	# Check for level advance
	var leveled_up = false
	if _correct_count >= ADVANCE_THRESHOLD:
		var new_level = game_manager.advance_game_level("math")
		if new_level > _level:
			leveled_up = true
			_level = new_level

	# Hide game elements
	_problem_label.visible = false
	for label in _choices_labels:
		label.visible = false
	_feedback_label.text = ""

	var xp_bonus = _correct_count * 5
	var result_text = "TIME'S UP!\n\nLevel: %d — %s\nCorrect: %d\nWrong: %d\nCoins earned: %d\nXP bonus: +%d" % [
		_level, LEVEL_NAMES[_level], _correct_count, _wrong_count, max(0, _coins_earned), xp_bonus
	]

	if leveled_up:
		result_text += "\n\nLEVEL UP! Now Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	elif _correct_count < ADVANCE_THRESHOLD:
		result_text += "\n\nNeed %d correct to advance (got %d)" % [ADVANCE_THRESHOLD, _correct_count]

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

		if not _game_active:
			if event.keycode == KEY_SPACE:
				get_tree().reload_current_scene()
			return

		if event.keycode == KEY_UP:
			_selected_choice = max(0, _selected_choice - 1)
			_draw_choices()
		elif event.keycode == KEY_DOWN:
			_selected_choice = min(3, _selected_choice + 1)
			_draw_choices()
		elif event.keycode == KEY_SPACE:
			_submit_answer()
