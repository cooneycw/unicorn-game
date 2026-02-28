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

func _try_unlock(achievement_id: String):
	if achievement_id in _unlocked:
		return
	_unlocked.append(achievement_id)
	achievement_unlocked.emit(achievement_id)

	# Award coin bonus
	if _game_manager and achievement_id in ACHIEVEMENTS:
		var reward = ACHIEVEMENTS[achievement_id]["reward"]
		_game_manager.modify_coins(reward)
