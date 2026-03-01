extends Node2D

# Logic Grid — 6 auto-advancing levels
# L1-3: 3x3 Latin square (5/4/3 givens)
# L4-6: 4x4 Latin square (10/8/6 givens)
# Advance: Complete puzzle without using any hints

var game_manager
var audio_manager

# Grid state
var _grid_size: int = 3
var _solution: Array = []
var _puzzle: Array = []
var _player_grid: Array = []
var _locked: Array = []

var cursor_x: int = 0
var cursor_y: int = 0
var _game_active: bool = false
var _puzzles_completed: int = 0
var _coins_earned: int = 0
var _hints_used: int = 0
var _total_hints_session: int = 0
var _level: int = 1

# UI
var _status_label: Label
var _level_label: Label
var _info_label: Label
var _feedback_label: Label
var _feedback_timer: float = 0.0

var _screen_width: float = 1152.0
var _screen_height: float = 648.0

# Visual constants
var CELL_SIZE: float = 100.0
const CELL_GAP: float = 6.0

const LEVEL_NAMES: Array = [
	"",
	"3x3 Easy (5 given)",
	"3x3 Medium (4 given)",
	"3x3 Hard (3 given)",
	"4x4 Easy (10 given)",
	"4x4 Medium (8 given)",
	"4x4 Hard (6 given)",
]

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")
	game_manager.pending_game = "res://scenes/SudokuGame.tscn"

	_level = game_manager.get_game_level("logic_grid")

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x > 0:
		_screen_width = viewport_size.x
		_screen_height = viewport_size.y

	_build_ui()
	_generate_puzzle()
	_draw_grid()

func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.2)
	bg.size = Vector2(_screen_width, _screen_height)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "LOGIC GRID"
	title.position = Vector2(15, 10)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	add_child(title)

	# Level display
	_level_label = Label.new()
	_level_label.position = Vector2(250, 14)
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(_level_label)

	# Status
	_status_label = Label.new()
	_status_label.position = Vector2(15, 45)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(_status_label)

	# Info
	_info_label = Label.new()
	_info_label.position = Vector2(15, _screen_height - 35)
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(_info_label)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(15, 75)
	_feedback_label.add_theme_font_size_override("font_size", 16)
	add_child(_feedback_label)

	_update_labels()

func _update_labels():
	_level_label.text = "Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	_status_label.text = "Puzzles: %d | Coins: +%d | Hints: %d" % [_puzzles_completed, _coins_earned, _hints_used]
	if _game_active:
		if _grid_size == 3:
			_info_label.text = "Arrows: move | 1-3: place | Backspace: clear | H: hint | ESC: back"
		else:
			_info_label.text = "Arrows: move | 1-4: place | Backspace: clear | H: hint | ESC: back"
	else:
		_info_label.text = "SPACE: next puzzle | ESC: exit"

func _get_level_config() -> Dictionary:
	match _level:
		1: return {"size": 3, "givens": 5}
		2: return {"size": 3, "givens": 4}
		3: return {"size": 3, "givens": 3}
		4: return {"size": 4, "givens": 10}
		5: return {"size": 4, "givens": 8}
		6: return {"size": 4, "givens": 6}
		_: return {"size": 3, "givens": 5}

func _generate_puzzle():
	_game_active = true
	_hints_used = 0

	var config = _get_level_config()
	_grid_size = config["size"]
	var num_given = config["givens"]

	# Adjust cell size for 4x4
	if _grid_size == 4:
		CELL_SIZE = 80.0
	else:
		CELL_SIZE = 100.0

	# Generate Latin square
	if _grid_size == 3:
		_generate_3x3_solution()
	else:
		_generate_4x4_solution()

	# Build puzzle by removing cells
	_puzzle = []
	_player_grid = []
	_locked = []

	var all_positions: Array = []
	for r in range(_grid_size):
		_puzzle.append([])
		_player_grid.append([])
		_locked.append([])
		for c in range(_grid_size):
			_puzzle[r].append(0)
			_player_grid[r].append(0)
			_locked[r].append(false)
			all_positions.append(Vector2i(r, c))

	all_positions.shuffle()

	for i in range(num_given):
		var pos = all_positions[i]
		_puzzle[pos.x][pos.y] = _solution[pos.x][pos.y]
		_player_grid[pos.x][pos.y] = _solution[pos.x][pos.y]
		_locked[pos.x][pos.y] = true

	cursor_x = 0
	cursor_y = 0
	_update_labels()

func _generate_3x3_solution():
	var row1 = [1, 2, 3]
	row1.shuffle()

	var valid_row2s = _get_valid_rows_3(row1, [])
	var row2 = valid_row2s[randi() % valid_row2s.size()]

	var valid_row3s = _get_valid_rows_3(row1, row2)
	var row3 = valid_row3s[0]

	_solution = [row1.duplicate(), row2.duplicate(), row3.duplicate()]

func _get_valid_rows_3(row1: Array, row2: Array) -> Array:
	var perms = [[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]
	var valid: Array = []
	for perm in perms:
		var ok = true
		for c in range(3):
			if perm[c] == row1[c]:
				ok = false
				break
			if row2.size() > 0 and perm[c] == row2[c]:
				ok = false
				break
		if ok:
			valid.append(perm)
	return valid

func _generate_4x4_solution():
	# Generate a valid 4x4 Latin square using backtracking-friendly approach
	var rows: Array = []

	# Row 1: random permutation
	var row1 = [1, 2, 3, 4]
	row1.shuffle()
	rows.append(row1)

	# Row 2-4: find valid rows by filtering permutations
	var all_perms_4 = _get_all_permutations_4()

	for _row_idx in range(3):
		var valid: Array = []
		for perm in all_perms_4:
			var ok = true
			for c in range(4):
				for prev_row in rows:
					if perm[c] == prev_row[c]:
						ok = false
						break
				if not ok:
					break
			if ok:
				valid.append(perm)
		if valid.size() > 0:
			rows.append(valid[randi() % valid.size()].duplicate())
		else:
			# Fallback: restart generation
			_generate_4x4_solution()
			return

	_solution = rows

func _get_all_permutations_4() -> Array:
	var result: Array = []
	var vals = [1, 2, 3, 4]
	for a in vals:
		for b in vals:
			if b == a:
				continue
			for c in vals:
				if c == a or c == b:
					continue
				for d in vals:
					if d == a or d == b or d == c:
						continue
					result.append([a, b, c, d])
	return result

func _check_win() -> bool:
	for r in range(_grid_size):
		for c in range(_grid_size):
			if _player_grid[r][c] != _solution[r][c]:
				return false
	return true

func _validate_placement(row: int, col: int, value: int) -> bool:
	for c in range(_grid_size):
		if c != col and _player_grid[row][c] == value:
			return false
	for r in range(_grid_size):
		if r != row and _player_grid[r][col] == value:
			return false
	return true

func _give_hint():
	for r in range(_grid_size):
		for c in range(_grid_size):
			if not _locked[r][c] and _player_grid[r][c] != _solution[r][c]:
				_player_grid[r][c] = _solution[r][c]
				_locked[r][c] = true
				_hints_used += 1
				_total_hints_session += 1
				_show_feedback("Hint! Cell (%d,%d) = %d" % [r + 1, c + 1, _solution[r][c]])
				if audio_manager:
					audio_manager.play_sfx("menu_select")
				_draw_grid()
				_update_labels()
				if _check_win():
					_puzzle_complete()
				return
	_show_feedback("No empty cells to hint!")

func _puzzle_complete():
	_game_active = false
	_puzzles_completed += 1
	var reward = 15 - (_hints_used * 3)
	if _grid_size == 4:
		reward = 25 - (_hints_used * 3)
	reward = max(5, reward)
	_coins_earned += reward
	game_manager.modify_coins(reward)

	for pet_id in game_manager.get_all_pets().keys():
		game_manager.modify_stat(pet_id, "happiness", 3)
		game_manager.add_xp(pet_id, 8)

	if audio_manager:
		audio_manager.play_sfx("win")

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_logic_grid_complete(_puzzles_completed, _hints_used)
		achievement_mgr.check_all()

	# Auto-advance if no hints used
	var leveled_up = false
	if _hints_used == 0:
		var new_level = game_manager.advance_game_level("logic_grid")
		if new_level > _level:
			leveled_up = true
			_level = new_level

	# Award egg for completing the puzzle
	var egg_got = game_manager.collect_egg()
	var egg_msg = " +1 Egg!" if egg_got else " Egg inventory full!"

	# Clear pending game — player completed it
	game_manager.pending_game = ""

	var msg = "SOLVED! +%d coins!%s" % [reward, egg_msg]
	if leveled_up:
		msg += " LEVEL UP! Now Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	elif _hints_used > 0:
		msg += " (Complete without hints to advance)"
	msg += " SPACE for next puzzle, ESC to exit."
	_show_feedback(msg)
	_update_labels()

func _show_feedback(msg: String):
	_feedback_label.text = msg
	_feedback_timer = 5.0

func _draw_grid():
	# Remove old grid visuals
	for child in get_children():
		if child.is_in_group("grid_visual"):
			child.queue_free()

	var grid_total_w = _grid_size * (CELL_SIZE + CELL_GAP)
	var grid_offset_x = (_screen_width - grid_total_w) / 2.0
	var grid_offset_y = 130.0

	for row in range(_grid_size):
		for col in range(_grid_size):
			var cell_x = grid_offset_x + col * (CELL_SIZE + CELL_GAP)
			var cell_y = grid_offset_y + row * (CELL_SIZE + CELL_GAP)

			# Cursor highlight
			if row == cursor_y and col == cursor_x and _game_active:
				var border = ColorRect.new()
				border.size = Vector2(CELL_SIZE + 6, CELL_SIZE + 6)
				border.position = Vector2(cell_x - 3, cell_y - 3)
				border.color = Color.GOLD
				border.add_to_group("grid_visual")
				add_child(border)

			# Cell background
			var cell = ColorRect.new()
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.position = Vector2(cell_x, cell_y)
			cell.add_to_group("grid_visual")

			var value = _player_grid[row][col]
			var is_conflict = value > 0 and not _validate_placement(row, col, value) and not _locked[row][col]

			if _locked[row][col]:
				cell.color = Color(0.25, 0.25, 0.4)
			elif is_conflict:
				cell.color = Color(0.5, 0.15, 0.15)
			elif value > 0:
				cell.color = Color(0.2, 0.35, 0.2)
			else:
				cell.color = Color(0.18, 0.18, 0.28)

			add_child(cell)

			# Number display
			if value > 0:
				var num_label = Label.new()
				num_label.text = str(value)
				num_label.position = Vector2(cell_x + CELL_SIZE / 2 - 12, cell_y + CELL_SIZE / 2 - 18)
				num_label.add_theme_font_size_override("font_size", 36)
				num_label.add_to_group("grid_visual")

				if _locked[row][col]:
					num_label.add_theme_color_override("font_color", Color.WHITE)
				elif is_conflict:
					num_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
				else:
					num_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))

				num_label.z_index = 1
				add_child(num_label)

	# Row labels
	for i in range(_grid_size):
		var row_label = Label.new()
		row_label.text = "Row %d" % (i + 1)
		row_label.position = Vector2(grid_offset_x - 65, grid_offset_y + i * (CELL_SIZE + CELL_GAP) + CELL_SIZE / 2 - 10)
		row_label.add_theme_font_size_override("font_size", 12)
		row_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		row_label.add_to_group("grid_visual")
		add_child(row_label)

func _process(delta: float):
	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0:
			_feedback_label.text = ""

func _go_back():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			_go_back()
			return

		# Manual save
		if event.keycode == KEY_S and event.ctrl_pressed:
			var save_manager = get_tree().root.get_node_or_null("SaveManager")
			if save_manager:
				save_manager.save_game()
			_show_feedback("Game saved!")
			return

		if not _game_active:
			if event.keycode == KEY_SPACE:
				_generate_puzzle()
				_draw_grid()
				_update_labels()
			return

		# Navigation
		if event.keycode == KEY_UP:
			cursor_y = max(0, cursor_y - 1)
			_draw_grid()
		elif event.keycode == KEY_DOWN:
			cursor_y = min(_grid_size - 1, cursor_y + 1)
			_draw_grid()
		elif event.keycode == KEY_LEFT:
			cursor_x = max(0, cursor_x - 1)
			_draw_grid()
		elif event.keycode == KEY_RIGHT:
			cursor_x = min(_grid_size - 1, cursor_x + 1)
			_draw_grid()

		# Number entry (1-3 for 3x3, 1-4 for 4x4)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_1 + _grid_size - 1:
			if _locked[cursor_y][cursor_x]:
				_show_feedback("That cell is locked!")
				return
			var num = event.keycode - KEY_1 + 1
			_player_grid[cursor_y][cursor_x] = num

			if not _validate_placement(cursor_y, cursor_x, num):
				_show_feedback("Conflict! %d already in this row or column." % num)
				if audio_manager:
					audio_manager.play_sfx("wrong")
			else:
				if audio_manager:
					audio_manager.play_sfx("menu_select")

			_draw_grid()

			if _check_win():
				_puzzle_complete()

		# Clear cell
		elif event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE:
			if not _locked[cursor_y][cursor_x]:
				_player_grid[cursor_y][cursor_x] = 0
				_draw_grid()

		# Hint
		elif event.keycode == KEY_H:
			_give_hint()
