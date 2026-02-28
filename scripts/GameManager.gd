extends Node

# Singleton to manage game state
var pets = {}
var current_location = "hub"

func _ready():
	# Initialize game
	pass

func add_pet(pet_name: String, pet_type: String):
	var pet_id = randi() % 10000
	pets[pet_id] = {
		"name": pet_name,
		"type": pet_type,
		"health": 100,
		"happiness": 100,
		"location": "hub"
	}
	return pet_id

func heal_pet(pet_id: int, heal_amount: int = 50):
	if pet_id in pets:
		pets[pet_id]["health"] = min(100, pets[pet_id]["health"] + heal_amount)
		return true
	return false

func update_pet_location(pet_id: int, location: String):
	if pet_id in pets:
		pets[pet_id]["location"] = location

func get_pet_info(pet_id: int):
	if pet_id in pets:
		return pets[pet_id]
	return null

func get_all_pets():
	return pets
