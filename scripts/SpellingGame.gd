extends Node2D

# Spelling Game — multiple choice: which is the correct spelling?
# UP/DOWN to highlight choice, SPACE to confirm

var game_manager
var audio_manager

# Word lists by difficulty
const WORDS_EASY: Array = [
	{"word": "cat", "wrong": ["kat", "catt", "cht"]},
	{"word": "dog", "wrong": ["dgo", "dogg", "dag"]},
	{"word": "sun", "wrong": ["son", "sunn", "san"]},
	{"word": "red", "wrong": ["rad", "redd", "erd"]},
	{"word": "big", "wrong": ["bag", "bigg", "beg"]},
	{"word": "hat", "wrong": ["hatt", "het", "hit"]},
	{"word": "run", "wrong": ["rann", "runn", "rin"]},
	{"word": "cup", "wrong": ["kup", "cupp", "cap"]},
	{"word": "bed", "wrong": ["bedd", "beed", "bid"]},
	{"word": "map", "wrong": ["mapp", "mep", "nap"]},
	{"word": "fish", "wrong": ["fich", "fis", "fhis"]},
	{"word": "book", "wrong": ["bouk", "buk", "bok"]},
	{"word": "tree", "wrong": ["tre", "trea", "trey"]},
	{"word": "star", "wrong": ["starr", "sdar", "sttar"]},
	{"word": "moon", "wrong": ["mune", "monn", "moun"]},
	{"word": "bird", "wrong": ["brid", "birrd", "burd"]},
	{"word": "frog", "wrong": ["frogg", "forg", "froq"]},
	{"word": "cake", "wrong": ["caek", "kake", "cak"]},
]

const WORDS_MEDIUM: Array = [
	{"word": "happy", "wrong": ["hapy", "hppy", "happey"]},
	{"word": "friend", "wrong": ["freind", "frend", "freend"]},
	{"word": "school", "wrong": ["skool", "scool", "shool"]},
	{"word": "because", "wrong": ["becuase", "becuz", "becouse"]},
	{"word": "people", "wrong": ["peple", "poeple", "peeple"]},
	{"word": "animal", "wrong": ["animle", "anmal", "anmial"]},
	{"word": "family", "wrong": ["famly", "famliy", "famely"]},
	{"word": "garden", "wrong": ["gardan", "graden", "gardin"]},
	{"word": "dragon", "wrong": ["dragin", "dragan", "dragen"]},
	{"word": "castle", "wrong": ["castel", "cassle", "cassel"]},
	{"word": "magic", "wrong": ["majic", "magik", "maigc"]},
	{"word": "princess", "wrong": ["prinsess", "princes", "prinses"]},
	{"word": "rainbow", "wrong": ["rainbo", "ranbow", "rainebow"]},
	{"word": "sparkle", "wrong": ["sparcle", "sparkl", "spakle"]},
	{"word": "special", "wrong": ["speshal", "specal", "spechial"]},
	{"word": "unicorn", "wrong": ["unikorn", "unicron", "unocorn"]},
	{"word": "kitchen", "wrong": ["kichen", "kitchin", "kitchan"]},
	{"word": "weather", "wrong": ["wether", "wheather", "weater"]},
]

const WORDS_HARD: Array = [
	{"word": "adventure", "wrong": ["adventur", "advenchure", "advencher"]},
	{"word": "treasure", "wrong": ["tresure", "treasur", "tresher"]},
	{"word": "mysterious", "wrong": ["misterious", "mystirious", "mysterius"]},
	{"word": "enormous", "wrong": ["enormus", "enourmous", "enormos"]},
	{"word": "brilliant", "wrong": ["brillant", "briliant", "brillent"]},
	{"word": "incredible", "wrong": ["incredable", "increadible", "incredibel"]},
	{"word": "beautiful", "wrong": ["beutiful", "beautful", "butiful"]},
	{"word": "imagination", "wrong": ["imagenation", "imaginashun", "imanigation"]},
	{"word": "extraordinary", "wrong": ["extrordinary", "extraodinary", "extreordinary"]},
	{"word": "disappear", "wrong": ["dissapear", "disapear", "disappeer"]},
	{"word": "different", "wrong": ["diffrent", "differant", "diferent"]},
	{"word": "necessary", "wrong": ["neccessary", "necesary", "neccesary"]},
	{"word": "separate", "wrong": ["seperate", "separete", "seprate"]},
	{"word": "Wednesday", "wrong": ["Wensday", "Wedensday", "Wendesday"]},
	{"word": "strength", "wrong": ["strenth", "strenght", "stength"]},
]

# Game state
const GAME_DURATION: float = 60.0
var _time_remaining: float = GAME_DURATION
var _game_active: bool = false
var _correct_count: int = 0
var _wrong_count: int = 0
var _coins_earned: int = 0
var _active_pet_id: int = -1

# Difficulty
var difficulty: int = 0
var selecting_difficulty: bool = true

# Current question
var _current_word: String = ""
var _choices: Array = []
var _selected_choice: int = 0
var _used_words: Array = []

# UI
var _time_label: Label
var _score_label: Label
var _prompt_label: Label
var _choices_labels: Array = []
var _feedback_label: Label
var _result_label: Label
var _difficulty_label: Label
var _info_label: Label
var _feedback_timer: float = 0.0
var _waiting_next: bool = false

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
	bg.color = Color(0.15, 0.1, 0.2)
	bg.size = Vector2(_screen_width, _screen_height)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "SPELLING BEE"
	title.position = Vector2(_screen_width / 2.0 - 80, 10)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
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

	# Prompt
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(_screen_width / 2.0 - 200, 100)
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	_prompt_label.visible = false
	add_child(_prompt_label)

	# Choice labels
	for i in range(4):
		var choice = Label.new()
		choice.position = Vector2(_screen_width / 2.0 - 120, 180 + i * 55)
		choice.add_theme_font_size_override("font_size", 26)
		choice.visible = false
		add_child(choice)
		_choices_labels.append(choice)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(_screen_width / 2.0 - 180, 420)
	_feedback_label.add_theme_font_size_override("font_size", 18)
	add_child(_feedback_label)

	# Info
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
	var options = ["Easy (simple words)", "Medium (everyday words)", "Hard (challenge words)"]
	for i in range(options.size()):
		var prefix = "> " if i == difficulty else "  "
		lines += prefix + options[i] + "\n"
	_difficulty_label.text = "Choose Difficulty:\n\n" + lines

func _start_game():
	selecting_difficulty = false
	_difficulty_label.text = ""
	_game_active = true
	_time_remaining = GAME_DURATION
	_correct_count = 0
	_wrong_count = 0
	_coins_earned = 0
	_used_words.clear()
	_waiting_next = false

	_prompt_label.visible = true
	for label in _choices_labels:
		label.visible = true
	_result_label.visible = false

	_info_label.text = "UP/DOWN: select answer | SPACE: confirm | ESC: back"
	_generate_question()
	_update_ui()

func _get_word_list() -> Array:
	match difficulty:
		0: return WORDS_EASY
		1: return WORDS_MEDIUM
		2: return WORDS_HARD
		_: return WORDS_EASY

func _generate_question():
	var word_list = _get_word_list()

	# Avoid repeats within session
	var available: Array = []
	for entry in word_list:
		if entry["word"] not in _used_words:
			available.append(entry)

	# If all used, reset
	if available.size() == 0:
		_used_words.clear()
		available = word_list.duplicate()

	var entry = available[randi() % available.size()]
	_current_word = entry["word"]
	_used_words.append(_current_word)

	# Build choices: correct + 3 wrong, shuffled
	_choices = [_current_word]
	for w in entry["wrong"]:
		_choices.append(w)
	_choices.shuffle()
	_selected_choice = 0

	_prompt_label.text = "Which spelling is correct?"
	_draw_choices()

func _draw_choices():
	for i in range(4):
		if i < _choices.size():
			var prefix = "> " if i == _selected_choice else "  "
			_choices_labels[i].text = prefix + _choices[i]
			if i == _selected_choice:
				_choices_labels[i].add_theme_color_override("font_color", Color.GOLD)
			else:
				_choices_labels[i].add_theme_color_override("font_color", Color.WHITE)
			_choices_labels[i].visible = true
		else:
			_choices_labels[i].visible = false

func _submit_answer():
	_waiting_next = true

	if _choices[_selected_choice] == _current_word:
		_correct_count += 1
		_coins_earned += 3
		game_manager.modify_coins(3)
		if audio_manager:
			audio_manager.play_sfx("correct")
		_feedback_label.text = "Correct! '%s' is right!" % _current_word
		_feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		_wrong_count += 1
		if audio_manager:
			audio_manager.play_sfx("wrong")
		_feedback_label.text = "Oops! The correct spelling is '%s'" % _current_word
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))

	_update_ui()

	# Auto-advance after 1.2 seconds
	get_tree().create_timer(1.2).timeout.connect(_next_question)

func _next_question():
	if not _game_active:
		return
	_waiting_next = false
	_feedback_label.text = ""
	_generate_question()

func _update_ui():
	_time_label.text = "Time: %d" % ceili(_time_remaining)
	_score_label.text = "Correct: %d | Coins: +%d" % [_correct_count, _coins_earned]

func _end_game():
	_game_active = false
	_waiting_next = false

	if _active_pet_id >= 0 and _correct_count > 0:
		game_manager.modify_stat(_active_pet_id, "happiness", _correct_count * 2)
		game_manager.add_xp(_active_pet_id, _correct_count * 5)

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_spelling_score(_correct_count, difficulty == 2)
		achievement_mgr.check_all()

	_prompt_label.visible = false
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

		if not _game_active or _waiting_next:
			return

		if event.keycode == KEY_UP:
			_selected_choice = max(0, _selected_choice - 1)
			_draw_choices()
		elif event.keycode == KEY_DOWN:
			_selected_choice = min(_choices.size() - 1, _selected_choice + 1)
			_draw_choices()
		elif event.keycode == KEY_SPACE:
			_submit_answer()
