extends Node

# Singleton to manage game state

signal pet_stat_changed(pet_id: int, stat_name: String, new_value: int)
signal coins_changed(new_amount: int)
signal pet_mood_changed(pet_id: int, new_mood: String)
signal welcome_back(message: String)
signal pet_leveled_up(pet_id: int, new_level: int)
signal pet_added(pet_id: int)

var pets = {}
var coins: int = 50
var total_coins_earned: int = 0
var current_location = "hub"

var _next_pet_id: int = 1
var _decay_timer: float = 0.0
const DECAY_INTERVAL: float = 60.0

# Persistence fields
var total_play_time: float = 0.0
var last_login_date: String = ""
var _welcome_message: String = ""

# Egg inventory — collected but not yet hatched
var egg_inventory: Array = []  # Array of { "time_remaining": float, "type": String }
const MAX_EGGS: int = 3

# Per-game level progression (auto-advance, kids don't choose)
var game_levels: Dictionary = {
	"math": 1,
	"spelling": 1,
	"sudoku": 1,
	"treat_catch": 1,
	"memory": 1,
}

const GAME_MAX_LEVELS: Dictionary = {
	"math": 10,
	"spelling": 10,
	"sudoku": 6,
	"treat_catch": 5,
	"memory": 5,
}

func get_game_level(game_name: String) -> int:
	return game_levels.get(game_name, 1)

func advance_game_level(game_name: String) -> int:
	var current = game_levels.get(game_name, 1)
	var max_level = GAME_MAX_LEVELS.get(game_name, 10)
	if current < max_level:
		game_levels[game_name] = current + 1
	return game_levels[game_name]

# XP thresholds for levels 1-10
const LEVEL_THRESHOLDS: Array = [0, 50, 120, 250, 500, 900, 1400, 2000, 2800, 3800]

# Whimsical name parts for hatched pets
const NAME_PREFIXES: Array = ["Star", "Moon", "Sun", "Cloud", "Crystal", "Shadow",
	"Glitter", "Shimmer", "Frost", "Ember", "Misty", "Velvet", "Dream", "Dusk", "Dawn",
	"Biscuit", "Honey", "Whisker", "Paws", "Clover"]
const NAME_SUFFIXES: Array = ["whisper", "beam", "hooves", "mane", "spark", "shine",
	"dancer", "song", "flight", "heart", "dust", "glow", "petal", "breeze", "storm",
	"paws", "nose", "fur", "tail", "ears"]

# Color variants per pet type
const COLOR_VARIANTS = {
	"unicorn": [Color.WHITE, Color(1.0, 0.75, 0.8), Color(0.68, 0.85, 1.0), Color(1.0, 0.84, 0.0)],
	"pegasus": [Color.LIGHT_GRAY, Color(0.75, 0.75, 0.75), Color(0.53, 0.81, 0.92), Color(0.73, 0.56, 0.87)],
	"dragon": [Color.RED, Color(0.0, 0.75, 0.0), Color(0.4, 0.0, 0.6), Color(1.0, 0.5, 0.0)],
	"alicorn": [Color(0.6, 0.2, 0.8), Color(0.1, 0.1, 0.7), Color.WHITE],
	"dogocorn": [Color(0.72, 0.53, 0.34), Color(0.95, 0.87, 0.73), Color(0.3, 0.3, 0.3), Color(1.0, 0.85, 0.6)],
	"catocorn": [Color(0.95, 0.6, 0.2), Color(0.2, 0.2, 0.2), Color(0.85, 0.85, 0.85), Color(0.75, 0.55, 0.35)],
}

func _ready():
	_load_saved_data()

func _process(delta: float):
	total_play_time += delta

	_decay_timer += delta
	if _decay_timer >= DECAY_INTERVAL:
		_decay_timer -= DECAY_INTERVAL
		_tick_stat_decay()

	# Tick egg hatch timers
	_tick_eggs(delta)

func _load_saved_data():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager == null:
		return

	var data = save_manager.load_game()
	if data.is_empty():
		return

	# Restore state
	coins = data.get("coins", 50)
	total_coins_earned = int(data.get("total_coins_earned", 0))
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
			"xp": int(pet_data.get("xp", 0)),
			"level": int(pet_data.get("level", 1)),
			"color_variant": int(pet_data.get("color_variant", 0)),
			"has_koala": bool(pet_data.get("has_koala", false)),
		}

	# Restore egg inventory
	var saved_eggs = data.get("egg_inventory", [])
	egg_inventory = []
	for egg_data in saved_eggs:
		egg_inventory.append({
			"time_remaining": float(egg_data.get("time_remaining", 300.0)),
			"type": str(egg_data.get("type", "unicorn")),
		})

	# Restore game levels
	var saved_levels = data.get("game_levels", {})
	for key in saved_levels.keys():
		game_levels[key] = int(saved_levels[key])

	# Restore achievements
	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		var saved_achievements = data.get("achievements", [])
		achievement_mgr.load_unlocked(saved_achievements)

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
		return

	var elapsed_minutes = elapsed_seconds / 60.0
	elapsed_minutes = minf(elapsed_minutes, 480.0)

	var ticks = int(elapsed_minutes)

	var any_decay = false
	for pet_id in pets.keys():
		var pet = pets[pet_id]
		if pet["health"] <= 0:
			continue

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
			continue

		var hunger_decay = -2
		var happiness_decay = -1

		if pet["hunger"] < 20:
			happiness_decay -= 1

		if pet["happiness"] < 20:
			modify_stat(pet_id, "health", -1)

		modify_stat(pet_id, "hunger", hunger_decay)
		modify_stat(pet_id, "happiness", happiness_decay)

func _tick_eggs(delta: float):
	var hatched_indices: Array = []
	for i in range(egg_inventory.size()):
		egg_inventory[i]["time_remaining"] -= delta
		if egg_inventory[i]["time_remaining"] <= 0:
			hatched_indices.append(i)

	hatched_indices.reverse()
	for i in hatched_indices:
		_hatch_egg(i)

func _hatch_egg(index: int):
	var egg = egg_inventory[index]
	egg_inventory.remove_at(index)

	var pet_type = egg["type"]
	var pet_name = _generate_whimsical_name()
	var pet_id = add_pet(pet_name, pet_type)
	pet_added.emit(pet_id)

func _generate_whimsical_name() -> String:
	var prefix = NAME_PREFIXES[randi() % NAME_PREFIXES.size()]
	var suffix = NAME_SUFFIXES[randi() % NAME_SUFFIXES.size()]
	return prefix + suffix

func _roll_egg_type() -> String:
	var roll = randf()
	if roll < 0.30:
		return "unicorn"
	elif roll < 0.50:
		return "pegasus"
	elif roll < 0.65:
		return "dragon"
	elif roll < 0.77:
		return "dogocorn"
	elif roll < 0.89:
		return "catocorn"
	else:
		return "alicorn"

func collect_egg() -> bool:
	if egg_inventory.size() >= MAX_EGGS:
		return false
	var pet_type = _roll_egg_type()
	egg_inventory.append({
		"time_remaining": 300.0,
		"type": pet_type
	})
	return true

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
		"location": "hub",
		"xp": 0,
		"level": 1,
		"color_variant": 0,
		"has_koala": randf() < 0.2,
	}
	return pet_id

func get_stat_cap(pet_id: int) -> int:
	if pet_id not in pets:
		return 100
	return 100 + pets[pet_id]["level"] * 5

func modify_stat(pet_id: int, stat_name: String, amount: int):
	if pet_id not in pets:
		return
	if stat_name not in ["health", "happiness", "hunger", "energy"]:
		return

	var old_value = pets[pet_id][stat_name]
	var floor_value = 10 if stat_name in ["hunger", "happiness"] else 0
	var cap = get_stat_cap(pet_id)
	var new_value = clampi(old_value + amount, floor_value, cap)
	pets[pet_id][stat_name] = new_value

	if new_value != old_value:
		pet_stat_changed.emit(pet_id, stat_name, new_value)

	var new_mood = get_pet_mood(pet_id)
	pet_mood_changed.emit(pet_id, new_mood)

	if stat_name == "health" and new_value <= 0:
		pets[pet_id]["health"] = 0

func add_xp(pet_id: int, amount: int):
	if pet_id not in pets:
		return
	var pet = pets[pet_id]
	pet["xp"] += amount
	var old_level = pet["level"]

	while pet["level"] < LEVEL_THRESHOLDS.size() and pet["xp"] >= LEVEL_THRESHOLDS[pet["level"]]:
		pet["level"] += 1

	if pet["level"] > old_level:
		pet_leveled_up.emit(pet_id, pet["level"])

func get_level(pet_id: int) -> int:
	if pet_id not in pets:
		return 1
	return pets[pet_id]["level"]

func get_xp_progress(pet_id: int) -> Dictionary:
	if pet_id not in pets:
		return {"current": 0, "next": 50, "level": 1}
	var pet = pets[pet_id]
	var level = pet["level"]
	var current_xp = pet["xp"]
	var next_threshold = LEVEL_THRESHOLDS[level] if level < LEVEL_THRESHOLDS.size() else -1
	return {"current": current_xp, "next": next_threshold, "level": level}

func set_color_variant(pet_id: int, variant: int) -> bool:
	if pet_id not in pets:
		return false
	var pet = pets[pet_id]
	if pet["level"] < 5:
		return false
	if coins < 50:
		return false
	var type_variants = COLOR_VARIANTS.get(pet["type"], [])
	if variant < 0 or variant >= type_variants.size():
		return false
	modify_coins(-50)
	pet["color_variant"] = variant
	pet_stat_changed.emit(pet_id, "color_variant", variant)
	return true

func get_pet_color(pet_id: int) -> Color:
	if pet_id not in pets:
		return Color.WHITE
	var pet = pets[pet_id]
	var type_variants = COLOR_VARIANTS.get(pet["type"], [Color.WHITE])
	var variant = pet["color_variant"]
	if variant >= 0 and variant < type_variants.size():
		return type_variants[variant]
	return type_variants[0]

func modify_coins(amount: int):
	coins = max(0, coins + amount)
	if amount > 0:
		total_coins_earned += amount
	coins_changed.emit(coins)

func heal_pet(pet_id: int, heal_amount: int = 30) -> bool:
	if pet_id not in pets:
		return false
	if coins < 10:
		return false
	modify_coins(-10)
	modify_stat(pet_id, "health", heal_amount)
	add_xp(pet_id, 3)
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
