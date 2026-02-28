extends Node

# Autoloaded singleton — handles save/load to user://save_data.json + CSV export

const SAVE_PATH = "user://save_data.json"
const CSV_PATH = "user://pets_export.csv"
const SAVE_VERSION = 3
const AUTO_SAVE_INTERVAL = 60.0

signal game_saved

var _auto_save_timer: float = 0.0

func _process(delta: float):
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_game()

func save_game():
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm == null:
		return

	var achievements = []
	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievements = achievement_mgr.get_unlocked_ids()

	var data = {
		"version": SAVE_VERSION,
		"coins": gm.coins,
		"total_coins_earned": gm.total_coins_earned,
		"next_pet_id": gm._next_pet_id,
		"pets": gm.pets,
		"egg_inventory": gm.egg_inventory,
		"last_played": Time.get_unix_time_from_system(),
		"total_play_time": gm.total_play_time,
		"last_login_date": gm.last_login_date,
		"game_levels": gm.game_levels,
		"achievements": achievements,
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Also export CSV
	_export_csv(gm)

	game_saved.emit()

func _export_csv(gm):
	var file = FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if file == null:
		return

	# Header
	file.store_line("pet_id,name,type,level,xp,health,happiness,hunger,energy,color_variant,has_koala")

	# Data rows
	for pet_id in gm.pets.keys():
		var p = gm.pets[pet_id]
		var line = "%d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%s" % [
			pet_id,
			str(p["name"]).replace(",", ";"),  # escape commas in names
			p["type"],
			p["level"],
			p["xp"],
			p["health"],
			p["happiness"],
			p["hunger"],
			p["energy"],
			p["color_variant"],
			str(p.get("has_koala", false))
		]
		file.store_line(line)

	file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: Could not open save file for reading.")
		return {}

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_warning("SaveManager: Corrupt save file, starting fresh.")
		return {}

	var data = json.data
	if not data is Dictionary:
		push_warning("SaveManager: Save data is not a dictionary, starting fresh.")
		return {}

	return data

func on_scene_transition():
	save_game()
