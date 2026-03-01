extends Node

# Centralized pet lifecycle and population management
# Owns all pet lifecycle transitions and enforces soft population cap

signal pet_hatched(pet_id: int)
signal pet_adopted(pet_id: int)
signal pet_sent_adventure(pet_id: int)
signal pet_graduated(pet_id: int)
signal population_changed(active_count: int, total_count: int)

enum Status { ACTIVE, ON_JOURNEY, ADOPTED, RETIRED, AT_ACADEMY }

# Soft cap — UI warns, egg rate slows drastically, but player is never forced
const SOFT_CAP: int = 12
const WARN_THRESHOLD: int = 10  # start showing "getting crowded" at this count

# Dynamic egg spawn interval parameters
const BASE_EGG_INTERVAL: float = 420.0    # 7 minutes base
const PER_PET_FACTOR: float = 45.0        # +45 seconds per active pet
const MIN_EGG_INTERVAL: float = 300.0     # floor: 5 minutes
const MAX_EGG_INTERVAL: float = 1200.0    # ceiling: 20 minutes

var game_manager

func _ready():
	# Deferred so GameManager loads first
	call_deferred("_connect_game_manager")

func _connect_game_manager():
	game_manager = get_tree().root.get_node_or_null("GameManager")

func active_pets() -> Dictionary:
	if game_manager == null:
		game_manager = get_tree().root.get_node_or_null("GameManager")
	if game_manager == null:
		return {}

	var result = {}
	for pet_id in game_manager.pets.keys():
		var pet = game_manager.pets[pet_id]
		if pet.get("status", Status.ACTIVE) == Status.ACTIVE:
			result[pet_id] = pet
	return result

func active_pet_count() -> int:
	return active_pets().size()

func total_pet_count() -> int:
	if game_manager == null:
		game_manager = get_tree().root.get_node_or_null("GameManager")
	if game_manager == null:
		return 0
	return game_manager.pets.size()

func is_at_soft_cap() -> bool:
	return active_pet_count() >= SOFT_CAP

func is_near_cap() -> bool:
	return active_pet_count() >= WARN_THRESHOLD

func next_egg_interval() -> float:
	var n = active_pet_count()
	var interval = BASE_EGG_INTERVAL + n * PER_PET_FACTOR
	return clampf(interval, MIN_EGG_INTERVAL, MAX_EGG_INTERVAL)

func can_hatch_egg() -> bool:
	# Allow hatching even above soft cap — the dynamic interval already slows things down.
	# This keeps the system story-positive: eggs are never "wasted".
	return true

func get_population_label() -> String:
	var n = active_pet_count()
	if n >= SOFT_CAP:
		return "Island Full (%d/%d)" % [n, SOFT_CAP]
	elif n >= WARN_THRESHOLD:
		return "Getting Crowded (%d/%d)" % [n, SOFT_CAP]
	else:
		return "Pets: %d/%d" % [n, SOFT_CAP]

func get_population_color() -> Color:
	var n = active_pet_count()
	if n >= SOFT_CAP:
		return Color(1.0, 0.4, 0.4)  # red
	elif n >= WARN_THRESHOLD:
		return Color(1.0, 0.8, 0.3)  # amber
	else:
		return Color(0.6, 1.0, 0.6)  # green

# --- Lifecycle transitions (stubs for future issues #26, #27, #28) ---

func transition_pet(pet_id: int, new_status: int) -> bool:
	if game_manager == null:
		return false
	if pet_id not in game_manager.pets:
		return false

	var pet = game_manager.pets[pet_id]
	var old_status = pet.get("status", Status.ACTIVE)
	if old_status == new_status:
		return false

	pet["status"] = new_status

	match new_status:
		Status.ADOPTED:
			pet_adopted.emit(pet_id)
		Status.ON_JOURNEY:
			pet_sent_adventure.emit(pet_id)
		Status.AT_ACADEMY:
			pet_graduated.emit(pet_id)

	population_changed.emit(active_pet_count(), total_pet_count())
	return true

static func status_name(status: int) -> String:
	match status:
		Status.ACTIVE: return "Active"
		Status.ON_JOURNEY: return "On Journey"
		Status.ADOPTED: return "Adopted"
		Status.RETIRED: return "Retired"
		Status.AT_ACADEMY: return "At Academy"
		_: return "Unknown"
