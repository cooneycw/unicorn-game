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
		"pending_game": gm.pending_game,
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

func import_pets_from_csv() -> Dictionary:
	# Fallback import: recover pets from old pets_export.csv when JSON save is missing.
	# Supports both old format (11 columns) and any future format with extra columns.
	# CSV header: pet_id,name,type,level,xp,health,happiness,hunger,energy,color_variant,has_koala
	if not FileAccess.file_exists(CSV_PATH):
		return {}

	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return {}

	var header_line = file.get_line().strip_edges()
	if not header_line.begins_with("pet_id"):
		file.close()
		return {}

	var headers = header_line.split(",")

	var imported_pets = {}
	var max_id = 0
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue

		var cols = line.split(",")
		if cols.size() < 9:
			continue  # need at least: pet_id,name,type,level,xp,health,happiness,hunger,energy

		var pid = int(cols[0])
		var pet_name = str(cols[1]).replace(";", ",")  # reverse the comma escaping
		var pet_type = str(cols[2])

		# Map old type names to new names
		if pet_type == "dogocorn":
			pet_type = "dogicorn"
		elif pet_type == "catocorn":
			pet_type = "caticorn"

		# Validate pet type
		if pet_type not in ["unicorn", "pegasus", "dragon", "alicorn", "dogicorn", "caticorn"]:
			continue

		# CSV columns: pet_id(0),name(1),type(2),level(3),xp(4),
		#   health(5),happiness(6),hunger(7),energy(8),color_variant(9),has_koala(10)
		var pet = {
			"name": pet_name,
			"type": pet_type,
			"level": int(cols[3]) if cols.size() > 3 else 1,
			"xp": int(cols[4]) if cols.size() > 4 else 0,
			"health": int(cols[5]) if cols.size() > 5 else 100,
			"happiness": int(cols[6]) if cols.size() > 6 else 100,
			"hunger": int(cols[7]) if cols.size() > 7 else 50,
			"energy": int(cols[8]) if cols.size() > 8 else 100,
			"location": "hub",
			"color_variant": int(cols[9]) if cols.size() > 9 else 0,
			"has_koala": str(cols[10]).to_lower() == "true" if cols.size() > 10 else false,
		}

		imported_pets[pid] = pet
		if pid > max_id:
			max_id = pid

	file.close()

	if imported_pets.is_empty():
		return {}

	# Return a minimal save-like dictionary so GameManager can load it
	return {
		"pets": imported_pets,
		"next_pet_id": max_id + 1,
		"coins": 50,
		"total_coins_earned": 0,
		"_imported_from_csv": true,
	}

func on_scene_transition():
	save_game()
