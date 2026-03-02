extends Control

# Adoption Center — send pets to loving families in nearby towns
# Two views: Adoption (match pets to families) and Friends Book (gallery of adopted pets)

var game_manager
var pop_manager
var audio_manager

# Adoption request data
var _current_request: Dictionary = {}
var _active_pet_ids: Array = []
var _selected_pet_index: int = 0

# View state
enum View { REQUESTS, PET_SELECT, FAREWELL, FRIENDS_BOOK, POSTCARDS }
var _current_view: int = View.REQUESTS

# UI elements
var _title_label: Label
var _main_label: Label
var _instructions_label: Label
var _feedback_label: Label
var _feedback_timer: float = 0.0
var _stars_label: Label

# Farewell animation
var _farewell_timer: float = 0.0
var _farewell_pet_name: String = ""
var _farewell_family: String = ""

# Family name pools
const FAMILY_NAMES: Array = [
	"Miller", "Johnson", "Patel", "Garcia", "Chen",
	"Williams", "Brown", "Kim", "Anderson", "Taylor",
	"Wilson", "Nakamura", "Singh", "Lopez", "Thompson",
	"O'Brien", "Rossi", "Nguyen", "Martinez", "Park",
]

const TOWN_NAMES: Array = [
	"Rainbow Village", "Sunflower Town", "Moonbeam Meadows",
	"Starlight Valley", "Crystal Lake", "Blossom Hill",
]

const TRAIT_PREFERENCES: Array = [
	"playful", "gentle", "brave", "cuddly", "energetic", "calm",
]

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	pop_manager = get_tree().root.get_node_or_null("PetPopulationManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")

	_create_ui()
	_refresh_active_pets()
	_generate_request()
	_show_request_view()

func _create_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.12, 0.2)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(30, 20)
	vbox.size = Vector2(740, 560)
	add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "Adoption Center"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.9))
	title_row.add_child(_title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	_stars_label = Label.new()
	_stars_label.add_theme_font_size_override("font_size", 16)
	_stars_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_update_stars_display()
	title_row.add_child(_stars_label)

	vbox.add_child(HSeparator.new())

	# Main content
	_main_label = Label.new()
	_main_label.add_theme_font_size_override("font_size", 14)
	_main_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_label.custom_minimum_size = Vector2(700, 350)
	vbox.add_child(_main_label)

	vbox.add_child(HSeparator.new())

	# Instructions
	_instructions_label = Label.new()
	_instructions_label.add_theme_font_size_override("font_size", 12)
	_instructions_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(_instructions_label)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 15)
	_feedback_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(_feedback_label)

func _update_stars_display():
	if _stars_label:
		_stars_label.text = "Kindness Stars: %d  |  Coins: %d" % [game_manager.kindness_stars, game_manager.coins]

func _refresh_active_pets():
	_active_pet_ids = []
	var active = game_manager.get_active_pets()
	for pid in active.keys():
		_active_pet_ids.append(pid)
	if _selected_pet_index >= _active_pet_ids.size():
		_selected_pet_index = max(0, _active_pet_ids.size() - 1)

func _generate_request():
	var family = FAMILY_NAMES[randi() % FAMILY_NAMES.size()]
	var town = TOWN_NAMES[randi() % TOWN_NAMES.size()]
	var trait_pref = TRAIT_PREFERENCES[randi() % TRAIT_PREFERENCES.size()]

	# Sometimes request a specific type, sometimes any
	var pet_types = ["unicorn", "pegasus", "dragon", "alicorn", "dogicorn", "caticorn"]
	var type_pref = ""
	if randf() < 0.6:
		type_pref = pet_types[randi() % pet_types.size()]

	_current_request = {
		"family": family,
		"town": town,
		"trait": trait_pref,
		"type": type_pref,
	}

func _show_request_view():
	_current_view = View.REQUESTS

	var req = _current_request
	var type_str = GameManager.display_type(req["type"]).capitalize() if req["type"] != "" else "any pet"
	var text = "A family is looking for a new friend!\n\n"
	text += "The %s family from %s\n" % [req["family"], req["town"]]
	text += "is hoping to adopt a %s %s.\n\n" % [req["trait"], type_str]
	text += "They promise a loving home with a big garden!\n\n"

	if _active_pet_ids.size() <= 1:
		text += "[You need at least 2 active pets to adopt one out.]\n"
	elif pop_manager and pop_manager.is_near_cap():
		text += "[Your island is getting crowded — adoption helps make room!]\n"

	# Show Friends Book summary
	var adopted_count = game_manager.adopted_registry.size()
	if adopted_count > 0:
		text += "\nFriends Book: %d pet%s adopted so far" % [adopted_count, "s" if adopted_count != 1 else ""]

	# Show unread postcards
	var unread = game_manager.get_unread_postcards()
	if unread.size() > 0:
		text += "\nYou have %d unread postcard%s!" % [unread.size(), "s" if unread.size() != 1 else ""]

	_main_label.text = text
	_instructions_label.text = "SPACE: Choose a pet to adopt  |  F: Friends Book  |  P: Postcards  |  N: New request  |  ESC: Back"

func _show_pet_select_view():
	_current_view = View.PET_SELECT
	_refresh_active_pets()

	if _active_pet_ids.size() <= 1:
		_show_feedback("You need at least 2 active pets to adopt one out!")
		_show_request_view()
		return

	var text = "Choose a pet for the %s family:\n\n" % _current_request["family"]

	for i in range(_active_pet_ids.size()):
		var pid = _active_pet_ids[i]
		var info = game_manager.get_pet_info(pid)
		var level = game_manager.get_level(pid)
		var mood = game_manager.get_mood_emoji(pid)
		var prefix = "> " if i == _selected_pet_index else "  "

		# Show match quality
		var match_str = ""
		if _current_request["type"] != "" and info["type"] == _current_request["type"]:
			match_str = " [Great match!]"

		text += "%s%s %s Lv%d (%s) %s%s\n" % [prefix, mood, info["name"], level, GameManager.display_type(info["type"]), game_manager.get_pet_mood(pid), match_str]

	_main_label.text = text
	_instructions_label.text = "UP/DOWN: Select pet  |  SPACE: Confirm adoption  |  ESC: Cancel"

func _show_farewell_view(pet_name: String, family: String):
	_current_view = View.FAREWELL
	_farewell_timer = 4.0
	_farewell_pet_name = pet_name
	_farewell_family = family

	var frames = [
		"%s packs a tiny suitcase with their favorite toy..." % pet_name,
		"",
		"The %s family arrives with a cozy pet bed and big smiles!" % family,
		"",
		"%s waves goodbye to all their friends on the island." % pet_name,
		"",
		"\"We'll take wonderful care of %s!\" says the %s family." % [pet_name, family],
		"",
		"%s trots happily to their new home!" % pet_name,
	]

	_main_label.text = "\n".join(frames)
	_instructions_label.text = "[Farewell in progress... please wait]"

func _show_friends_book():
	_current_view = View.FRIENDS_BOOK

	var registry = game_manager.adopted_registry
	if registry.size() == 0:
		_main_label.text = "Friends Book\n\nNo pets adopted yet. Your friends are waiting for loving homes!"
		_instructions_label.text = "ESC: Back to Adoption Center"
		return

	var text = "Friends Book — Your Adopted Pets\n\n"
	for entry in registry:
		text += "%s (Lv%d %s) — Living with the %s family\n" % [
			entry["name"], entry["level"], GameManager.display_type(entry["type"]).capitalize(), entry["family"]
		]
	text += "\nTotal adoptions: %d" % registry.size()

	_main_label.text = text
	_instructions_label.text = "ESC: Back to Adoption Center"

func _show_postcards():
	_current_view = View.POSTCARDS

	var all_postcards = game_manager.postcards
	if all_postcards.size() == 0:
		_main_label.text = "Postcards\n\nNo postcards yet! Adopt a pet and they'll write to you."
		_instructions_label.text = "ESC: Back to Adoption Center"
		return

	var text = "Postcards from Adopted Pets\n\n"
	for i in range(all_postcards.size()):
		var pc = all_postcards[i]
		var read_marker = "" if pc["read"] else " [NEW]"
		text += "%s%s\n  %s\n  Gift: +%d coins\n\n" % [read_marker, pc["pet_name"], pc["message"], pc["coins"]]

	# Auto-read all unread postcards
	for i in range(all_postcards.size()):
		game_manager.read_postcard(i)
	_update_stars_display()

	_main_label.text = text
	_instructions_label.text = "ESC: Back to Adoption Center"

func _confirm_adoption():
	if _active_pet_ids.size() <= 1:
		_show_feedback("You need at least 2 active pets!")
		return

	var pid = _active_pet_ids[_selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	var pet_name = info["name"]
	var family = _current_request["family"]

	var success = game_manager.adopt_pet(pid, family)
	if not success:
		_show_feedback("Couldn't adopt this pet right now.")
		return

	if audio_manager:
		audio_manager.play_sfx("coin")

	# Check achievement
	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_adoption(game_manager.adopted_registry.size())

	_show_farewell_view(pet_name, family)

func _show_feedback(msg: String):
	_feedback_label.text = msg
	_feedback_timer = 2.5

func _process(delta: float):
	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0:
			_feedback_label.text = ""

	# Farewell animation timer
	if _current_view == View.FAREWELL:
		_farewell_timer -= delta
		if _farewell_timer <= 0:
			_show_feedback("%s is happy in their new home with the %s family! +1 Kindness Star" % [_farewell_pet_name, _farewell_family])
			_refresh_active_pets()
			_generate_request()
			_update_stars_display()
			_show_request_view()

func _input(event):
	if event is InputEventKey and event.pressed:
		if _current_view == View.FAREWELL:
			return  # no input during farewell

		if event.keycode == KEY_ESCAPE:
			if _current_view == View.PET_SELECT:
				_show_request_view()
			elif _current_view == View.FRIENDS_BOOK or _current_view == View.POSTCARDS:
				_show_request_view()
			else:
				_go_back()
			return

		if _current_view == View.REQUESTS:
			if event.keycode == KEY_SPACE:
				_show_pet_select_view()
				return
			if event.keycode == KEY_F:
				_show_friends_book()
				return
			if event.keycode == KEY_P:
				_show_postcards()
				return
			if event.keycode == KEY_N:
				_generate_request()
				_show_request_view()
				if audio_manager:
					audio_manager.play_sfx("menu_navigate")
				return

		if _current_view == View.PET_SELECT:
			if event.keycode == KEY_UP:
				_selected_pet_index = max(0, _selected_pet_index - 1)
				_show_pet_select_view()
				if audio_manager:
					audio_manager.play_sfx("menu_navigate")
				return
			if event.keycode == KEY_DOWN:
				_selected_pet_index = min(_active_pet_ids.size() - 1, _selected_pet_index + 1)
				_show_pet_select_view()
				if audio_manager:
					audio_manager.play_sfx("menu_navigate")
				return
			if event.keycode == KEY_SPACE:
				_confirm_adoption()
				return

func _go_back():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
