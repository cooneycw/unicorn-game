extends Node

# Autoloaded singleton — tracks and awards achievements

signal achievement_unlocked(achievement_id: String)

const ACHIEVEMENTS = {
	"first_friend": {"name": "First Friend", "desc": "Adopt your first pet", "reward": 10},
	"full_house": {"name": "Full House", "desc": "Have 8 pets at once", "reward": 50},
	"dragon_keeper": {"name": "Dragon Keeper", "desc": "Own 3 dragons", "reward": 30},
	"happy_family": {"name": "Happy Family", "desc": "All pets at 90+ happiness", "reward": 40},
	"mini_game_master": {"name": "Mini-Game Master", "desc": "Score 50+ in mini-game", "reward": 30},
	"coin_collector": {"name": "Coin Collector", "desc": "Earn 500 total coins", "reward": 50},
	"dedicated_caretaker": {"name": "Dedicated Caretaker", "desc": "Play for 1 hour total", "reward": 30},
	"dog_lover": {"name": "Dog Lover", "desc": "Own 3 dog-o-corns", "reward": 30},
	"cat_lover": {"name": "Cat Lover", "desc": "Own 3 cat-o-corns", "reward": 30},
	"animal_ark": {"name": "Animal Ark", "desc": "Own one of every pet type", "reward": 100},
	"koala_friend": {"name": "Koala Friend", "desc": "Have a pet with a koala rider", "reward": 20},
	"math_whiz": {"name": "Math Whiz", "desc": "Get 20 correct in Math Challenge", "reward": 40},
	"puzzle_solver": {"name": "Puzzle Solver", "desc": "Complete 5 Sudoku puzzles", "reward": 30},
	"no_hints": {"name": "No Hints Needed", "desc": "Complete a Sudoku without hints", "reward": 20},
	"spelling_bee": {"name": "Spelling Bee", "desc": "Get 15 correct in Spelling Game", "reward": 35},
	"word_master": {"name": "Word Master", "desc": "Get 10 correct on Hard spelling", "reward": 50},
}

var _unlocked: Array = []
var _game_manager

var _check_timer: float = 0.0

func _ready():
	_game_manager = get_tree().root.get_node_or_null("GameManager")

func _process(delta: float):
	_check_timer += delta
	if _check_timer >= 5.0:
		_check_timer = 0.0
		check_all()

func get_unlocked_count() -> int:
	return _unlocked.size()

func load_unlocked(ids: Array):
	_unlocked = []
	for id in ids:
		_unlocked.append(str(id))

func get_unlocked_ids() -> Array:
	return _unlocked.duplicate()

func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in _unlocked

func check_all():
	if _game_manager == null:
		_game_manager = get_tree().root.get_node_or_null("GameManager")
	if _game_manager == null:
		return

	var all_pets = _game_manager.get_all_pets()

	# First Friend
	if all_pets.size() >= 1:
		_try_unlock("first_friend")

	# Full House
	if all_pets.size() >= 8:
		_try_unlock("full_house")

	# Dragon Keeper
	var dragon_count = 0
	for pid in all_pets.keys():
		if all_pets[pid]["type"] == "dragon":
			dragon_count += 1
	if dragon_count >= 3:
		_try_unlock("dragon_keeper")

	# Dog Lover
	var dog_count = 0
	for pid in all_pets.keys():
		if all_pets[pid]["type"] == "dogocorn":
			dog_count += 1
	if dog_count >= 3:
		_try_unlock("dog_lover")

	# Cat Lover
	var cat_count = 0
	for pid in all_pets.keys():
		if all_pets[pid]["type"] == "catocorn":
			cat_count += 1
	if cat_count >= 3:
		_try_unlock("cat_lover")

	# Animal Ark (one of every pet type)
	var types_owned = {}
	for pid in all_pets.keys():
		types_owned[all_pets[pid]["type"]] = true
	if types_owned.size() >= 6:
		_try_unlock("animal_ark")

	# Koala Friend
	for pid in all_pets.keys():
		if all_pets[pid].get("has_koala", false):
			_try_unlock("koala_friend")
			break

	# Happy Family
	if all_pets.size() > 0:
		var all_happy = true
		for pid in all_pets.keys():
			if all_pets[pid]["happiness"] < 90:
				all_happy = false
				break
		if all_happy:
			_try_unlock("happy_family")

	# Coin Collector
	if _game_manager.total_coins_earned >= 500:
		_try_unlock("coin_collector")

	# Dedicated Caretaker
	if _game_manager.total_play_time >= 3600.0:
		_try_unlock("dedicated_caretaker")

func check_mini_game_score(score: int):
	if score >= 50:
		_try_unlock("mini_game_master")

func check_math_score(correct_count: int):
	if correct_count >= 20:
		_try_unlock("math_whiz")

func check_sudoku_complete(puzzles_completed: int, hints_used: int):
	if puzzles_completed >= 5:
		_try_unlock("puzzle_solver")
	if hints_used == 0:
		_try_unlock("no_hints")

func check_spelling_score(correct_count: int, was_hard: bool):
	if correct_count >= 15:
		_try_unlock("spelling_bee")
	if was_hard and correct_count >= 10:
		_try_unlock("word_master")

func _try_unlock(achievement_id: String):
	if achievement_id in _unlocked:
		return
	_unlocked.append(achievement_id)
	achievement_unlocked.emit(achievement_id)

	# Award coin bonus
	if _game_manager and achievement_id in ACHIEVEMENTS:
		var reward = ACHIEVEMENTS[achievement_id]["reward"]
		_game_manager.modify_coins(reward)
