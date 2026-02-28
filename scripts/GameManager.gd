extends Node

# Singleton to manage game state

signal pet_stat_changed(pet_id: int, stat_name: String, new_value: int)
signal coins_changed(new_amount: int)
signal pet_mood_changed(pet_id: int, new_mood: String)

var pets = {}
var coins: int = 50
var current_location = "hub"

var _next_pet_id: int = 1
var _decay_timer: float = 0.0
const DECAY_INTERVAL: float = 60.0

func _ready():
	pass

func _process(delta: float):
	_decay_timer += delta
	if _decay_timer >= DECAY_INTERVAL:
		_decay_timer -= DECAY_INTERVAL
		_tick_stat_decay()

func _tick_stat_decay():
	for pet_id in pets.keys():
		var pet = pets[pet_id]
		if pet["health"] <= 0:
			continue  # resting pets don't decay

		# Base decay: hunger -2, happiness -1 (floor at 10)
		var hunger_decay = -2
		var happiness_decay = -1

		# Low hunger (<20) accelerates happiness decay
		if pet["hunger"] < 20:
			happiness_decay -= 1

		# Low happiness (<20) causes slow health decay
		if pet["happiness"] < 20:
			modify_stat(pet_id, "health", -1)

		modify_stat(pet_id, "hunger", hunger_decay)
		modify_stat(pet_id, "happiness", happiness_decay)

func add_pet(pet_name: String, pet_type: String) -> int:
	var pet_id = _next_pet_id
	_next_pet_id += 1
	pets[pet_id] = {
		"name": pet_name,
		"type": pet_type,
		"health": 100,
		"happiness": 100,
		"hunger": 50,
		"energy": 100,
		"location": "hub"
	}
	return pet_id

func modify_stat(pet_id: int, stat_name: String, amount: int):
	if pet_id not in pets:
		return
	if stat_name not in ["health", "happiness", "hunger", "energy"]:
		return

	var old_value = pets[pet_id][stat_name]
	var floor_value = 10 if stat_name in ["hunger", "happiness"] else 0
	var new_value = clampi(old_value + amount, floor_value, 100)
	pets[pet_id][stat_name] = new_value

	if new_value != old_value:
		pet_stat_changed.emit(pet_id, stat_name, new_value)

	# Check for mood change
	var new_mood = get_pet_mood(pet_id)
	pet_mood_changed.emit(pet_id, new_mood)

	# Health at 0 = resting state
	if stat_name == "health" and new_value <= 0:
		pets[pet_id]["health"] = 0

func modify_coins(amount: int):
	coins = max(0, coins + amount)
	coins_changed.emit(coins)

func heal_pet(pet_id: int, heal_amount: int = 30) -> bool:
	if pet_id not in pets:
		return false
	if coins < 10:
		return false
	modify_coins(-10)
	modify_stat(pet_id, "health", heal_amount)
	return true

func get_pet_mood(pet_id: int) -> String:
	if pet_id not in pets:
		return "content"
	var pet = pets[pet_id]
	if pet["health"] <= 0:
		return "resting"
	if pet["hunger"] < 20:
		return "hungry"
	if pet["happiness"] >= 70:
		return "happy"
	if pet["happiness"] >= 40:
		return "content"
	return "sad"

func get_mood_emoji(pet_id: int) -> String:
	match get_pet_mood(pet_id):
		"happy":
			return "^_^"
		"content":
			return "-_-"
		"sad":
			return "T_T"
		"hungry":
			return ">_<"
		"resting":
			return "zzZ"
		_:
			return "-_-"

func update_pet_location(pet_id: int, location: String):
	if pet_id in pets:
		pets[pet_id]["location"] = location

func get_pet_info(pet_id: int):
	if pet_id in pets:
		return pets[pet_id]
	return null

func get_all_pets():
	return pets
