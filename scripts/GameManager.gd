extends Node

# Singleton to manage game state

signal pet_stat_changed(pet_id: int, stat_name: String, new_value: int)
signal coins_changed(new_amount: int)
signal pet_mood_changed(pet_id: int, new_mood: String)
signal welcome_back(message: String)

var pets = {}
var coins: int = 50
var current_location = "hub"

var _next_pet_id: int = 1
var _decay_timer: float = 0.0
const DECAY_INTERVAL: float = 60.0

# Persistence fields
var total_play_time: float = 0.0
var last_login_date: String = ""
var _welcome_message: String = ""

func _ready():
	_load_saved_data()

func _process(delta: float):
	total_play_time += delta

	_decay_timer += delta
	if _decay_timer >= DECAY_INTERVAL:
		_decay_timer -= DECAY_INTERVAL
		_tick_stat_decay()

func _load_saved_data():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager == null:
		return

	var data = save_manager.load_game()
	if data.is_empty():
		return

	# Restore state
	coins = data.get("coins", 50)
	_next_pet_id = int(data.get("next_pet_id", 1))
	total_play_time = float(data.get("total_play_time", 0.0))
	last_login_date = str(data.get("last_login_date", ""))

	# Restore pets — JSON deserializes keys as strings, convert to int
	var saved_pets = data.get("pets", {})
	pets = {}
	for key in saved_pets.keys():
		var pet_id = int(key)
		var pet_data = saved_pets[key]
		pets[pet_id] = {
			"name": str(pet_data.get("name", "Pet")),
			"type": str(pet_data.get("type", "unicorn")),
			"health": int(pet_data.get("health", 100)),
			"happiness": int(pet_data.get("happiness", 100)),
			"hunger": int(pet_data.get("hunger", 50)),
			"energy": int(pet_data.get("energy", 100)),
			"location": str(pet_data.get("location", "hub")),
		}

	# Offline stat decay
	var last_played = float(data.get("last_played", 0))
	if last_played > 0:
		_apply_offline_decay(last_played)

	# Daily login bonus
	_check_daily_bonus()

func _apply_offline_decay(last_played: float):
	var now = Time.get_unix_time_from_system()
	var elapsed_seconds = now - last_played
	if elapsed_seconds < 60:
		return  # Less than a minute, skip

	var elapsed_minutes = elapsed_seconds / 60.0
	# Cap decay at 8 hours worth (480 minutes)
	elapsed_minutes = minf(elapsed_minutes, 480.0)

	var ticks = int(elapsed_minutes)  # One tick per minute of absence

	var any_decay = false
	for pet_id in pets.keys():
		var pet = pets[pet_id]
		if pet["health"] <= 0:
			continue

		# Hunger decays 2 per tick, happiness 1 per tick (same rate as live decay)
		var hunger_loss = ticks * 2
		var happiness_loss = ticks * 1

		var new_hunger = max(15, pet["hunger"] - hunger_loss)
		var new_happiness = max(15, pet["happiness"] - happiness_loss)

		if new_hunger != pet["hunger"] or new_happiness != pet["happiness"]:
			any_decay = true
			pet["hunger"] = new_hunger
			pet["happiness"] = new_happiness

	if any_decay:
		var hours = int(elapsed_seconds / 3600)
		var minutes = int(fmod(elapsed_seconds, 3600) / 60)
		var time_str = ""
		if hours > 0:
			time_str = "%dh %dm" % [hours, minutes]
		else:
			time_str = "%dm" % minutes

		_welcome_message = "Welcome back! You were away for %s.\nYour pets missed you — their hunger and happiness dropped a bit." % time_str
	else:
		_welcome_message = "Welcome back!"

func _check_daily_bonus():
	var today = Time.get_date_string_from_system()
	if today != last_login_date:
		last_login_date = today
		if coins > 0 or pets.size() > 0:
			# Only give bonus if this isn't a brand new game
			coins += 20
			if _welcome_message == "":
				_welcome_message = "Welcome back! Daily bonus: +20 coins!"
			else:
				_welcome_message += "\nDaily bonus: +20 coins!"

func get_welcome_message() -> String:
	var msg = _welcome_message
	_welcome_message = ""
	return msg

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
