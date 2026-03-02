extends Node

# Singleton to manage game state

signal pet_stat_changed(pet_id: int, stat_name: String, new_value: int)
signal coins_changed(new_amount: int)
signal pet_mood_changed(pet_id: int, new_mood: String)
signal welcome_back(message: String)
signal pet_leveled_up(pet_id: int, new_level: int)
signal pet_added(pet_id: int)
signal pet_returned_from_journey(pet_id: int, quest_name: String, rewards: Dictionary)
signal postcard_received(pet_name: String, message: String)

var pets = {}
var coins: int = 50
var total_coins_earned: int = 0
var current_location = "hub"

# Adventure journeys — pets currently on quests
# Each entry: { "pet_id": int, "quest_id": String, "quest_name": String,
#   "depart_time": float, "return_time": float, "postcards_sent": int,
#   "next_postcard_time": float }
var active_journeys: Array = []

# Pending return notifications — checked on Hub load
var journey_returns: Array = []  # Array of { "pet_id", "quest_name", "rewards" }

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

# Mini-game persistence — forces return to same game if player ESCs out
var pending_game: String = ""

# Pet inspection — transient, not saved
var inspecting_pet_id: int = -1

# Adoption system
var kindness_stars: int = 0
var adopted_registry: Array = []  # Array of { pet_id, name, type, family, level, adopted_time }
var postcards: Array = []  # Array of { pet_name, family, message, coins, read }

signal kindness_stars_changed(new_amount: int)

# Per-game level progression (auto-advance, kids don't choose)
var game_levels: Dictionary = {
	"math": 1,
	"spelling": 1,
	"logic_grid": 1,
	"treat_catch": 1,
	"memory": 1,
}

const GAME_MAX_LEVELS: Dictionary = {
	"math": 10,
	"spelling": 10,
	"logic_grid": 6,
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

static func is_macos() -> bool:
	return OS.get_name() == "macOS"

static func display_type(internal_type: String) -> String:
	if is_macos() and internal_type == "caticorn":
		return "sloth"
	return internal_type

# Color variants per pet type (caticorn colors also used for sloth on macOS)
const COLOR_VARIANTS = {
	"unicorn": [Color.WHITE, Color(1.0, 0.75, 0.8), Color(0.68, 0.85, 1.0), Color(1.0, 0.84, 0.0)],
	"pegasus": [Color.LIGHT_GRAY, Color(0.75, 0.75, 0.75), Color(0.53, 0.81, 0.92), Color(0.73, 0.56, 0.87)],
	"dragon": [Color(0.0, 0.6, 0.0), Color(0.0, 0.75, 0.0), Color(0.4, 0.0, 0.6), Color(1.0, 0.5, 0.0)],
	"alicorn": [Color(0.6, 0.2, 0.8), Color(0.1, 0.1, 0.7), Color.WHITE],
	"dogicorn": [Color(0.72, 0.53, 0.34), Color(0.95, 0.87, 0.73), Color(0.3, 0.3, 0.3), Color(1.0, 0.85, 0.6)],
	"caticorn": [Color(0.95, 0.6, 0.2), Color(0.2, 0.2, 0.2), Color(0.85, 0.85, 0.85), Color(0.75, 0.55, 0.35)],
}

# Sloth color variants used on macOS instead of caticorn colors
const SLOTH_COLOR_VARIANTS = [Color(0.55, 0.4, 0.25), Color(0.65, 0.55, 0.4), Color(0.4, 0.35, 0.3), Color(0.7, 0.6, 0.45)]

func _ready():
	_load_saved_data()

var _journey_check_timer: float = 0.0

func _process(delta: float):
	total_play_time += delta

	_decay_timer += delta
	if _decay_timer >= DECAY_INTERVAL:
		_decay_timer -= DECAY_INTERVAL
		_tick_stat_decay()

	# Tick egg hatch timers
	_tick_eggs(delta)

	# Check journey returns every 10 seconds (uses Unix time, no need for frequent checks)
	_journey_check_timer += delta
	if _journey_check_timer >= 10.0:
		_journey_check_timer = 0.0
		_tick_journeys()

func _load_saved_data():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager == null:
		return

	var data = save_manager.load_game()
	if data.is_empty():
		# Fallback: try importing pets from old CSV export
		data = save_manager.import_pets_from_csv()
		if data.is_empty():
			return
		print("Imported pets from CSV backup")

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
		# Map old type names to new names
		var loaded_type = str(pet_data.get("type", "unicorn"))
		if loaded_type == "dogocorn":
			loaded_type = "dogicorn"
		elif loaded_type == "catocorn":
			loaded_type = "caticorn"
		pets[pet_id] = {
			"name": str(pet_data.get("name", "Pet")),
			"type": loaded_type,
			"health": int(pet_data.get("health", 100)),
			"happiness": int(pet_data.get("happiness", 100)),
			"hunger": int(pet_data.get("hunger", 50)),
			"energy": int(pet_data.get("energy", 100)),
			"location": str(pet_data.get("location", "hub")),
			"xp": int(pet_data.get("xp", 0)),
			"level": int(pet_data.get("level", 1)),
			"color_variant": int(pet_data.get("color_variant", 0)),
			"has_koala": bool(pet_data.get("has_koala", false)),
			"status": int(pet_data.get("status", 0)),  # default ACTIVE for old saves
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
		# Migrate old "sudoku" key to "logic_grid"
		var mapped_key = "logic_grid" if key == "sudoku" else key
		game_levels[mapped_key] = int(saved_levels[key])

	# Restore pending mini-game (force return to same game on ESC)
	pending_game = str(data.get("pending_game", ""))

	# Restore adoption data
	kindness_stars = int(data.get("kindness_stars", 0))
	var saved_registry = data.get("adopted_registry", [])
	adopted_registry = []
	for entry in saved_registry:
		adopted_registry.append({
			"pet_id": int(entry.get("pet_id", 0)),
			"name": str(entry.get("name", "")),
			"type": str(entry.get("type", "")),
			"family": str(entry.get("family", "")),
			"level": int(entry.get("level", 1)),
			"adopted_time": float(entry.get("adopted_time", 0)),
		})
	var saved_postcards = data.get("postcards", [])
	postcards = []
	for pc in saved_postcards:
		postcards.append({
			"pet_name": str(pc.get("pet_name", "")),
			"family": str(pc.get("family", "")),
			"message": str(pc.get("message", "")),
			"coins": int(pc.get("coins", 0)),
			"read": bool(pc.get("read", false)),
		})

	# Restore active journeys
	var saved_journeys = data.get("active_journeys", [])
	active_journeys = []
	for j in saved_journeys:
		active_journeys.append({
			"pet_id": int(j.get("pet_id", 0)),
			"quest_id": str(j.get("quest_id", "")),
			"quest_name": str(j.get("quest_name", "")),
			"theme": str(j.get("theme", "beach")),
			"coin_reward": int(j.get("coin_reward", 20)),
			"depart_time": float(j.get("depart_time", 0)),
			"return_time": float(j.get("return_time", 0)),
			"postcards_sent": int(j.get("postcards_sent", 0)),
			"next_postcard_time": float(j.get("next_postcard_time", 0)),
		})

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
		return "dogicorn"
	elif roll < 0.89:
		return "caticorn"
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
		"status": 0,  # PetPopulationManager.Status.ACTIVE
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
	var type_variants = SLOTH_COLOR_VARIANTS if is_macos() and pet["type"] == "caticorn" else COLOR_VARIANTS.get(pet["type"], [])
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
	var type_variants = SLOTH_COLOR_VARIANTS if is_macos() and pet["type"] == "caticorn" else COLOR_VARIANTS.get(pet["type"], [Color.WHITE])
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

func get_active_pets() -> Dictionary:
	var result = {}
	for pet_id in pets.keys():
		if pets[pet_id].get("status", 0) == 0:  # ACTIVE
			result[pet_id] = pets[pet_id]
	return result

func modify_kindness_stars(amount: int):
	kindness_stars = max(0, kindness_stars + amount)
	kindness_stars_changed.emit(kindness_stars)

func adopt_pet(pet_id: int, family_name: String) -> bool:
	if pet_id not in pets:
		return false
	var pet = pets[pet_id]
	if pet.get("status", 0) != 0:  # not ACTIVE
		return false

	# Record in adopted registry before changing status
	adopted_registry.append({
		"pet_id": pet_id,
		"name": pet["name"],
		"type": pet["type"],
		"family": family_name,
		"level": pet["level"],
		"adopted_time": Time.get_unix_time_from_system(),
	})

	# Transition pet status
	var pop_manager = get_tree().root.get_node_or_null("PetPopulationManager")
	if pop_manager:
		pop_manager.transition_pet(pet_id, 2)  # Status.ADOPTED
	else:
		pet["status"] = 2

	# Rewards
	var coin_reward = 15 + pet["level"] * 2
	modify_coins(coin_reward)
	modify_kindness_stars(1)

	# Generate a "thank you" postcard that arrives immediately
	_generate_postcard(pet["name"], family_name)

	return true

func _generate_postcard(pet_name: String, family_name: String):
	var messages = [
		"%s loves their new garden! The %s family sends their thanks." % [pet_name, family_name],
		"The %s family says %s is settling in wonderfully!" % [family_name, pet_name],
		"%s made a new friend at the %s house! Here's a little gift." % [pet_name, family_name],
		"The %s family built %s a cozy bed. They're so happy!" % [family_name, pet_name],
		"%s has been playing in the park near the %s home every day!" % [pet_name, family_name],
	]
	postcards.append({
		"pet_name": pet_name,
		"family": family_name,
		"message": messages[randi() % messages.size()],
		"coins": randi_range(3, 8),
		"read": false,
	})

func get_unread_postcards() -> Array:
	var unread = []
	for pc in postcards:
		if not pc["read"]:
			unread.append(pc)
	return unread

func read_postcard(index: int):
	if index >= 0 and index < postcards.size():
		if not postcards[index]["read"]:
			postcards[index]["read"] = true
			modify_coins(postcards[index]["coins"])

# --- Adventure Journeys ---

# Quest catalog — id, name, description, duration_minutes, min_level, theme
const QUEST_CATALOG: Array = [
	{"id": "rainbow_shells", "name": "Find Rainbow Shells", "desc": "Explore Crystal Cove for shimmering shells!", "duration": 10, "min_level": 1, "theme": "beach", "coin_reward": 15},
	{"id": "cloud_caves", "name": "Map the Cloud Caves", "desc": "Chart the mysterious caves above the clouds!", "duration": 20, "min_level": 2, "theme": "sky", "coin_reward": 25},
	{"id": "flower_valley", "name": "Visit Flower Valley", "desc": "A beautiful valley full of magical blooms!", "duration": 15, "min_level": 1, "theme": "garden", "coin_reward": 20},
	{"id": "snow_mountain", "name": "Deliver Medicine to Snow Mountain", "desc": "Help the animals on the snowy peaks!", "duration": 30, "min_level": 3, "theme": "mountain", "coin_reward": 35},
	{"id": "desert_oasis", "name": "Scout the Desert Oasis", "desc": "Find the hidden oasis in the golden sands!", "duration": 20, "min_level": 2, "theme": "desert", "coin_reward": 25},
	{"id": "starlight_forest", "name": "Explore Starlight Forest", "desc": "A forest that glows at night with magical starlight!", "duration": 25, "min_level": 3, "theme": "forest", "coin_reward": 30},
	{"id": "coral_reef", "name": "Dive to Coral Reef", "desc": "Discover the colorful underwater world!", "duration": 35, "min_level": 4, "theme": "ocean", "coin_reward": 40},
	{"id": "crystal_kingdom", "name": "Visit the Crystal Kingdom", "desc": "A kingdom made entirely of sparkling crystals!", "duration": 45, "min_level": 5, "theme": "crystal", "coin_reward": 50},
]

# Postcard templates per theme
const POSTCARD_TEMPLATES: Dictionary = {
	"beach": [
		"%s found a beautiful seashell!",
		"%s is splashing in the waves!",
		"%s built a sandcastle!",
	],
	"sky": [
		"%s is flying above the clouds!",
		"%s found a hidden cave entrance!",
		"%s made friends with a cloud sprite!",
	],
	"garden": [
		"%s is rolling in the flowers!",
		"%s found a rare golden bloom!",
		"%s is chasing butterflies!",
	],
	"mountain": [
		"%s reached the snowy peak!",
		"%s helped a lost mountain goat!",
		"%s is sledding down a hill!",
	],
	"desert": [
		"%s found the hidden oasis!",
		"%s rode a sand dune!",
		"%s spotted a mirage!",
	],
	"forest": [
		"%s is watching the fireflies!",
		"%s found a glowing mushroom!",
		"%s heard a magical owl singing!",
	],
	"ocean": [
		"%s is swimming with colorful fish!",
		"%s found a treasure chest!",
		"%s met a friendly sea turtle!",
	],
	"crystal": [
		"%s is amazed by the crystal towers!",
		"%s found a magic crystal shard!",
		"%s met the Crystal Guardian!",
	],
}

func get_available_quests() -> Array:
	var available = []
	for quest in QUEST_CATALOG:
		# Check if any pet is already on this quest
		var in_progress = false
		for journey in active_journeys:
			if journey["quest_id"] == quest["id"]:
				in_progress = true
				break
		if not in_progress:
			available.append(quest)
	return available

func get_eligible_pets_for_quest(quest: Dictionary) -> Array:
	var eligible = []
	for pet_id in pets.keys():
		var pet = pets[pet_id]
		if pet.get("status", 0) != 0:  # not ACTIVE
			continue
		if pet["level"] < quest["min_level"]:
			continue
		eligible.append(pet_id)
	return eligible

func send_pet_on_journey(pet_id: int, quest: Dictionary) -> bool:
	if pet_id not in pets:
		return false
	var pet = pets[pet_id]
	if pet.get("status", 0) != 0:
		return false
	if pet["level"] < quest["min_level"]:
		return false

	var pop_manager = get_tree().root.get_node_or_null("PetPopulationManager")
	if pop_manager:
		pop_manager.transition_pet(pet_id, 1)  # ON_JOURNEY

	var now = Time.get_unix_time_from_system()
	var duration_seconds = quest["duration"] * 60.0
	var postcard_interval = duration_seconds / 3.0  # send ~2 postcards during journey

	active_journeys.append({
		"pet_id": pet_id,
		"quest_id": quest["id"],
		"quest_name": quest["name"],
		"theme": quest["theme"],
		"coin_reward": quest["coin_reward"],
		"depart_time": now,
		"return_time": now + duration_seconds,
		"postcards_sent": 0,
		"next_postcard_time": now + postcard_interval,
	})

	return true

func _tick_journeys():
	var now = Time.get_unix_time_from_system()
	var completed_indices: Array = []

	for i in range(active_journeys.size()):
		var journey = active_journeys[i]
		var pet_id = journey["pet_id"]

		# Check for postcard
		if now >= journey["next_postcard_time"] and journey["postcards_sent"] < 2:
			var pet = pets.get(pet_id, null)
			if pet:
				var theme = journey["theme"]
				var templates = POSTCARD_TEMPLATES.get(theme, ["%s is having an adventure!"])
				var msg = templates[randi() % templates.size()] % pet["name"]
				postcard_received.emit(pet["name"], msg)
				journey["postcards_sent"] += 1
				var remaining = journey["return_time"] - now
				journey["next_postcard_time"] = now + remaining / 2.0

		# Check for return
		if now >= journey["return_time"]:
			completed_indices.append(i)

	# Process returns (reverse order to preserve indices)
	completed_indices.reverse()
	for i in completed_indices:
		_complete_journey(i)

func _complete_journey(index: int):
	var journey = active_journeys[index]
	var pet_id = journey["pet_id"]
	active_journeys.remove_at(index)

	if pet_id not in pets:
		return

	var pet = pets[pet_id]
	var level = pet["level"]

	# Calculate rewards — higher level = better rewards
	var base_coins = journey.get("coin_reward", 20)
	var bonus_coins = level * 3
	var total_coins = base_coins + bonus_coins
	var xp_reward = 15 + level * 5

	# Transition back to active
	var pop_manager = get_tree().root.get_node_or_null("PetPopulationManager")
	if pop_manager:
		pop_manager.transition_pet(pet_id, 0)  # ACTIVE

	# Apply rewards
	modify_coins(total_coins)
	add_xp(pet_id, xp_reward)
	modify_stat(pet_id, "happiness", 20)

	var rewards = {
		"coins": total_coins,
		"xp": xp_reward,
		"quest_name": journey["quest_name"],
	}

	journey_returns.append({
		"pet_id": pet_id,
		"pet_name": pet["name"],
		"quest_name": journey["quest_name"],
		"rewards": rewards,
	})

	pet_returned_from_journey.emit(pet_id, journey["quest_name"], rewards)

	# Check achievement
	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_journey_sent()

func get_journey_for_pet(pet_id: int) -> Dictionary:
	for journey in active_journeys:
		if journey["pet_id"] == pet_id:
			return journey
	return {}

func get_journey_time_remaining(pet_id: int) -> float:
	var journey = get_journey_for_pet(pet_id)
	if journey.is_empty():
		return 0.0
	var now = Time.get_unix_time_from_system()
	return maxf(0.0, journey["return_time"] - now)

func pop_journey_returns() -> Array:
	var returns = journey_returns.duplicate()
	journey_returns.clear()
	return returns
