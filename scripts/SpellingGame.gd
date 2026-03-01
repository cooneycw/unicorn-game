extends Node2D

# Spelling Game — 10 auto-advancing levels
# L1: 3-letter easy  L2: 3-4 letter  L3: 4-letter common
# L4: 4-5 letter  L5: 5-letter common  L6: 5-6 letter
# L7: 6-7 letter  L8: 7-8 letter challenge
# L9: Hard words  L10: Expert words
# Advance: 6+ correct in 60 seconds

var game_manager
var audio_manager

# 10 word tiers
const WORDS_L1: Array = [
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
]

const WORDS_L2: Array = [
	{"word": "fish", "wrong": ["fich", "fis", "fhis"]},
	{"word": "book", "wrong": ["bouk", "buk", "bok"]},
	{"word": "tree", "wrong": ["tre", "trea", "trey"]},
	{"word": "star", "wrong": ["starr", "sdar", "sttar"]},
	{"word": "moon", "wrong": ["mune", "monn", "moun"]},
	{"word": "bird", "wrong": ["brid", "birrd", "burd"]},
	{"word": "frog", "wrong": ["frogg", "forg", "froq"]},
	{"word": "cake", "wrong": ["caek", "kake", "cak"]},
	{"word": "door", "wrong": ["dor", "dorr", "doir"]},
	{"word": "play", "wrong": ["plae", "plai", "paly"]},
]

const WORDS_L3: Array = [
	{"word": "blue", "wrong": ["bloo", "blew", "bleu"]},
	{"word": "jump", "wrong": ["jamp", "jupm", "jomp"]},
	{"word": "milk", "wrong": ["milc", "mlk", "melk"]},
	{"word": "hand", "wrong": ["hnad", "handd", "hend"]},
	{"word": "food", "wrong": ["fud", "foud", "foode"]},
	{"word": "rain", "wrong": ["rane", "rian", "rayn"]},
	{"word": "boat", "wrong": ["bote", "bot", "baot"]},
	{"word": "king", "wrong": ["kng", "kinng", "kign"]},
	{"word": "wolf", "wrong": ["wlof", "wulf", "wolff"]},
	{"word": "farm", "wrong": ["fam", "farme", "frum"]},
]

const WORDS_L4: Array = [
	{"word": "happy", "wrong": ["hapy", "hppy", "happey"]},
	{"word": "sunny", "wrong": ["suny", "sunney", "sonny"]},
	{"word": "cloud", "wrong": ["clowd", "claud", "cloude"]},
	{"word": "funny", "wrong": ["funy", "funney", "funnee"]},
	{"word": "light", "wrong": ["lite", "lihgt", "liht"]},
	{"word": "water", "wrong": ["watter", "warter", "woter"]},
	{"word": "green", "wrong": ["grean", "gren", "greeen"]},
	{"word": "sleep", "wrong": ["sleap", "slep", "slepe"]},
	{"word": "house", "wrong": ["hous", "howse", "houes"]},
	{"word": "small", "wrong": ["smal", "smaul", "smoll"]},
]

const WORDS_L5: Array = [
	{"word": "friend", "wrong": ["freind", "frend", "freend"]},
	{"word": "school", "wrong": ["skool", "scool", "shool"]},
	{"word": "garden", "wrong": ["gardan", "graden", "gardin"]},
	{"word": "dragon", "wrong": ["dragin", "dragan", "dragen"]},
	{"word": "castle", "wrong": ["castel", "cassle", "cassel"]},
	{"word": "orange", "wrong": ["oraneg", "oringe", "oreneg"]},
	{"word": "flower", "wrong": ["flouwer", "flowr", "flowur"]},
	{"word": "winter", "wrong": ["wintr", "wintir", "wynter"]},
	{"word": "dinner", "wrong": ["diner", "dinnr", "dinnar"]},
	{"word": "sister", "wrong": ["sistr", "sistir", "sistor"]},
]

const WORDS_L6: Array = [
	{"word": "because", "wrong": ["becuase", "becuz", "becouse"]},
	{"word": "people", "wrong": ["peple", "poeple", "peeple"]},
	{"word": "animal", "wrong": ["animle", "anmal", "anmial"]},
	{"word": "family", "wrong": ["famly", "famliy", "famely"]},
	{"word": "magic", "wrong": ["majic", "magik", "maigc"]},
	{"word": "kitchen", "wrong": ["kichen", "kitchin", "kitchan"]},
	{"word": "weather", "wrong": ["wether", "wheather", "weater"]},
	{"word": "special", "wrong": ["speshal", "specal", "spechial"]},
	{"word": "picture", "wrong": ["pictur", "piccher", "pikture"]},
	{"word": "monster", "wrong": ["monstor", "monstar", "monstir"]},
]

const WORDS_L7: Array = [
	{"word": "princess", "wrong": ["prinsess", "princes", "prinses"]},
	{"word": "rainbow", "wrong": ["rainbo", "ranbow", "rainebow"]},
	{"word": "sparkle", "wrong": ["sparcle", "sparkl", "spakle"]},
	{"word": "unicorn", "wrong": ["unikorn", "unicron", "unocorn"]},
	{"word": "dolphin", "wrong": ["dolfin", "dolphon", "dolpin"]},
	{"word": "brought", "wrong": ["brougt", "brough", "brougth"]},
	{"word": "thought", "wrong": ["thougt", "thougth", "thort"]},
	{"word": "holiday", "wrong": ["holliday", "holyday", "holladay"]},
	{"word": "journey", "wrong": ["journy", "jerney", "journee"]},
	{"word": "trouble", "wrong": ["truble", "troubel", "trubbel"]},
]

const WORDS_L8: Array = [
	{"word": "adventure", "wrong": ["adventur", "advenchure", "advencher"]},
	{"word": "treasure", "wrong": ["tresure", "treasur", "tresher"]},
	{"word": "different", "wrong": ["diffrent", "differant", "diferent"]},
	{"word": "disappear", "wrong": ["dissapear", "disapear", "disappeer"]},
	{"word": "important", "wrong": ["importent", "importint", "imporant"]},
	{"word": "dangerous", "wrong": ["dangrous", "dangerus", "dangeros"]},
	{"word": "character", "wrong": ["charactor", "charectar", "charackter"]},
	{"word": "celebrate", "wrong": ["celebrait", "celibrate", "celebreat"]},
	{"word": "invisible", "wrong": ["invisable", "invisibel", "invisble"]},
	{"word": "wonderful", "wrong": ["wonderfull", "wanderful", "wunderful"]},
]

const WORDS_L9: Array = [
	{"word": "mysterious", "wrong": ["misterious", "mystirious", "mysterius"]},
	{"word": "enormous", "wrong": ["enormus", "enourmous", "enormos"]},
	{"word": "brilliant", "wrong": ["brillant", "briliant", "brillent"]},
	{"word": "incredible", "wrong": ["incredable", "increadible", "incredibel"]},
	{"word": "beautiful", "wrong": ["beutiful", "beautful", "butiful"]},
	{"word": "knowledge", "wrong": ["knolwedge", "knowlege", "nowledge"]},
	{"word": "excitable", "wrong": ["exciteable", "exiteable", "exitable"]},
	{"word": "yesterday", "wrong": ["yestarday", "yesturday", "yesterdey"]},
	{"word": "attention", "wrong": ["atention", "attension", "atenshun"]},
	{"word": "delicious", "wrong": ["delishus", "delicous", "delisious"]},
]

const WORDS_L10: Array = [
	{"word": "imagination", "wrong": ["imagenation", "imaginashun", "imanigation"]},
	{"word": "extraordinary", "wrong": ["extrordinary", "extraodinary", "extreordinary"]},
	{"word": "necessary", "wrong": ["neccessary", "necesary", "neccesary"]},
	{"word": "separate", "wrong": ["seperate", "separete", "seprate"]},
	{"word": "Wednesday", "wrong": ["Wensday", "Wedensday", "Wendesday"]},
	{"word": "strength", "wrong": ["strenth", "strenght", "stength"]},
	{"word": "environment", "wrong": ["enviroment", "enviornment", "envirnoment"]},
	{"word": "temperature", "wrong": ["temperture", "tempurature", "tempreture"]},
	{"word": "independent", "wrong": ["independant", "independint", "indipendent"]},
	{"word": "encyclopedia", "wrong": ["encylopedia", "encyclopaedia", "enciclopedia"]},
]

const ALL_WORD_LEVELS: Array = [
	[], # unused index 0
	WORDS_L1, WORDS_L2, WORDS_L3, WORDS_L4, WORDS_L5,
	WORDS_L6, WORDS_L7, WORDS_L8, WORDS_L9, WORDS_L10,
]

const LEVEL_NAMES: Array = [
	"",
	"Tiny Words",
	"Short Words",
	"Common Words",
	"Growing Words",
	"Everyday Words",
	"Tricky Words",
	"Bigger Words",
	"Challenge Words",
	"Hard Words",
	"Expert Words",
]

# Game state
const GAME_DURATION: float = 60.0
const ADVANCE_THRESHOLD: int = 6
var _time_remaining: float = GAME_DURATION
var _game_active: bool = false
var _correct_count: int = 0
var _wrong_count: int = 0
var _coins_earned: int = 0
var _active_pet_id: int = -1
var _level: int = 1

# Current question
var _current_word: String = ""
var _choices: Array = []
var _selected_choice: int = 0
var _used_words: Array = []

# UI
var _time_label: Label
var _score_label: Label
var _level_label: Label
var _prompt_label: Label
var _choices_labels: Array = []
var _feedback_label: Label
var _result_label: Label
var _info_label: Label
var _waiting_next: bool = false

var _screen_width: float = 1152.0
var _screen_height: float = 648.0

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")
	game_manager.pending_game = "res://scenes/SpellingGame.tscn"

	_level = game_manager.get_game_level("spelling")

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

	# Level display
	_level_label = Label.new()
	_level_label.position = Vector2(_screen_width / 2.0 - 80, 45)
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

	# Prompt
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(_screen_width / 2.0 - 200, 100)
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	add_child(_prompt_label)

	# Choice labels
	for i in range(4):
		var choice = Label.new()
		choice.position = Vector2(_screen_width / 2.0 - 120, 170 + i * 55)
		choice.add_theme_font_size_override("font_size", 26)
		add_child(choice)
		_choices_labels.append(choice)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(_screen_width / 2.0 - 180, 410)
	_feedback_label.add_theme_font_size_override("font_size", 18)
	add_child(_feedback_label)

	# Info
	_info_label = Label.new()
	_info_label.position = Vector2(15, _screen_height - 30)
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_info_label.text = "UP/DOWN: select answer | SPACE: confirm | ESC: back"
	add_child(_info_label)

	# Result (hidden)
	_result_label = Label.new()
	_result_label.position = Vector2(_screen_width / 2.0 - 150, _screen_height / 2.0 - 80)
	_result_label.add_theme_font_size_override("font_size", 22)
	_result_label.visible = false
	add_child(_result_label)

func _start_game():
	_game_active = true
	_time_remaining = GAME_DURATION
	_correct_count = 0
	_wrong_count = 0
	_coins_earned = 0
	_used_words.clear()
	_waiting_next = false

	_level_label.text = "Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	_prompt_label.visible = true
	for label in _choices_labels:
		label.visible = true
	_result_label.visible = false

	_generate_question()
	_update_ui()

func _generate_question():
	var word_list = ALL_WORD_LEVELS[_level]

	var available: Array = []
	for entry in word_list:
		if entry["word"] not in _used_words:
			available.append(entry)

	if available.size() == 0:
		_used_words.clear()
		available = word_list.duplicate()

	var entry = available[randi() % available.size()]
	_current_word = entry["word"]
	_used_words.append(_current_word)

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
		achievement_mgr.check_spelling_score(_correct_count, _level >= 9)
		achievement_mgr.check_all()

	# Check for level advance
	var leveled_up = false
	if _correct_count >= ADVANCE_THRESHOLD:
		var new_level = game_manager.advance_game_level("spelling")
		if new_level > _level:
			leveled_up = true
			_level = new_level

	_prompt_label.visible = false
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

		if _waiting_next:
			return

		if event.keycode == KEY_UP:
			_selected_choice = max(0, _selected_choice - 1)
			_draw_choices()
		elif event.keycode == KEY_DOWN:
			_selected_choice = min(_choices.size() - 1, _selected_choice + 1)
			_draw_choices()
		elif event.keycode == KEY_SPACE:
			_submit_answer()
