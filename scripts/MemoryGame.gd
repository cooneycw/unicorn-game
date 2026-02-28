extends Node2D

# Memory Match — 5 auto-advancing levels
# L1: 2x3 (3 pairs)  L2: 2x4 (4 pairs)  L3: 3x4 (6 pairs)
# L4: 4x4 (8 pairs)  L5: 4x6 (12 pairs)
# Advance: Complete the board

var game_manager
var audio_manager

# Grid
var grid_cols: int = 3
var grid_rows: int = 2
var cards: Array = []
var cursor_x: int = 0
var cursor_y: int = 0

# Card state
var flipped_cards: Array = []
var matched_pairs: int = 0
var total_pairs: int = 0
var coins_earned: int = 0
var can_flip: bool = true

var _level: int = 1

# Visual constants
const CARD_SIZE: float = 80.0
const CARD_GAP: float = 10.0

# Card colors
var card_colors = [
	Color.WHITE,
	Color.LIGHT_GRAY,
	Color.RED,
	Color(0.7, 0.3, 1.0),
	Color.YELLOW,
	Color(0.5, 0.8, 1.0),
	Color(0.3, 0.8, 0.3),
	Color(1.0, 0.5, 0.3),
	Color(1.0, 0.6, 0.8),
	Color(0.6, 0.4, 0.8),
	Color(0.3, 0.6, 0.9),
	Color(0.9, 0.9, 0.3),
]

var _status_label: Label
var _info_label: Label
var _level_label: Label

const LEVEL_NAMES: Array = [
	"",
	"Tiny (2x3)",
	"Small (2x4)",
	"Medium (3x4)",
	"Large (4x4)",
	"Expert (4x6)",
]

# Per-level config: [cols, rows]
const LEVEL_CONFIG: Array = [
	[], # unused index 0
	[3, 2],
	[4, 2],
	[4, 3],
	[4, 4],
	[6, 4],
]

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")

	_level = game_manager.get_game_level("memory")

	_create_ui()
	_start_game()

func _create_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.1, 0.25)
	bg.size = Vector2(1152, 648)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "MEMORY MATCH"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)

	# Level display
	_level_label = Label.new()
	_level_label.position = Vector2(200, 14)
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(_level_label)

	# Status
	_status_label = Label.new()
	_status_label.position = Vector2(10, 45)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(_status_label)

	# Info
	_info_label = Label.new()
	_info_label.position = Vector2(10, 70)
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_info_label.text = "Arrow keys: move | SPACE: flip | ESC: back"
	add_child(_info_label)

func _start_game():
	var config = LEVEL_CONFIG[_level]
	grid_cols = config[0]
	grid_rows = config[1]

	total_pairs = (grid_cols * grid_rows) / 2
	matched_pairs = 0
	coins_earned = 0
	flipped_cards.clear()
	can_flip = true

	_level_label.text = "Level %d: %s" % [_level, LEVEL_NAMES[_level]]

	_generate_cards()
	_draw_board()
	_update_status()

func _generate_cards():
	var values: Array = []
	for i in range(total_pairs):
		values.append(i % card_colors.size())
		values.append(i % card_colors.size())

	values.shuffle()

	cards.clear()
	var idx = 0
	for row in range(grid_rows):
		var row_data: Array = []
		for col in range(grid_cols):
			row_data.append({
				"value": values[idx],
				"flipped": false,
				"matched": false
			})
			idx += 1
		cards.append(row_data)

	cursor_x = 0
	cursor_y = 0

func _draw_board():
	for child in get_children():
		if child.is_in_group("card_visual"):
			child.queue_free()

	var grid_total_w = grid_cols * (CARD_SIZE + CARD_GAP)
	var grid_total_h = grid_rows * (CARD_SIZE + CARD_GAP)
	var grid_offset_x = (1152 - grid_total_w) / 2.0
	var grid_offset_y = max(100, (648 - grid_total_h) / 2.0)

	for row in range(grid_rows):
		for col in range(grid_cols):
			var card = cards[row][col]
			var rect = ColorRect.new()
			rect.size = Vector2(CARD_SIZE, CARD_SIZE)
			rect.position = Vector2(
				grid_offset_x + col * (CARD_SIZE + CARD_GAP),
				grid_offset_y + row * (CARD_SIZE + CARD_GAP)
			)
			rect.add_to_group("card_visual")

			if card["matched"]:
				rect.color = card_colors[card["value"]].darkened(0.3)
			elif card["flipped"]:
				rect.color = card_colors[card["value"]]
			else:
				rect.color = Color(0.3, 0.25, 0.4)

			# Cursor highlight
			if row == cursor_y and col == cursor_x and not card["matched"]:
				var border = ColorRect.new()
				border.size = Vector2(CARD_SIZE + 4, CARD_SIZE + 4)
				border.position = rect.position - Vector2(2, 2)
				border.color = Color.GOLD
				border.add_to_group("card_visual")
				add_child(border)
				rect.z_index = 1

			add_child(rect)

			if card["flipped"] or card["matched"]:
				var symbol = Label.new()
				var pet_names = ["U", "P", "D", "A", "G", "S", "E", "O", "K", "L", "B", "Y"]
				symbol.text = pet_names[card["value"] % pet_names.size()]
				symbol.position = rect.position + Vector2(CARD_SIZE / 2 - 8, CARD_SIZE / 2 - 12)
				symbol.add_theme_font_size_override("font_size", 24)
				symbol.add_theme_color_override("font_color", Color.BLACK if card_colors[card["value"]].v > 0.5 else Color.WHITE)
				symbol.z_index = 2
				symbol.add_to_group("card_visual")
				add_child(symbol)

func _update_status():
	_status_label.text = "Pairs: %d/%d | Coins earned: %d" % [matched_pairs, total_pairs, coins_earned]

func _flip_card():
	if not can_flip:
		return
	var card = cards[cursor_y][cursor_x]
	if card["flipped"] or card["matched"]:
		return

	card["flipped"] = true
	flipped_cards.append(Vector2i(cursor_x, cursor_y))

	if audio_manager:
		audio_manager.play_sfx("menu_select")

	if flipped_cards.size() == 2:
		can_flip = false
		var c1 = cards[flipped_cards[0].y][flipped_cards[0].x]
		var c2 = cards[flipped_cards[1].y][flipped_cards[1].x]

		if c1["value"] == c2["value"]:
			c1["matched"] = true
			c2["matched"] = true
			matched_pairs += 1
			coins_earned += 2
			game_manager.modify_coins(2)
			if audio_manager:
				audio_manager.play_sfx("match")
			_info_label.text = "Match! +2 coins"
			flipped_cards.clear()
			can_flip = true

			if matched_pairs >= total_pairs:
				_game_won()
		else:
			if audio_manager:
				audio_manager.play_sfx("mismatch")
			_info_label.text = "No match..."
			_draw_board()
			get_tree().create_timer(0.8).timeout.connect(_unflip_cards)
			return

	_draw_board()
	_update_status()

func _unflip_cards():
	for pos in flipped_cards:
		cards[pos.y][pos.x]["flipped"] = false
	flipped_cards.clear()
	can_flip = true
	_draw_board()

func _game_won():
	var bonus = 5 + _level * 3
	game_manager.modify_coins(bonus)
	coins_earned += bonus

	for pet_id in game_manager.get_all_pets().keys():
		game_manager.modify_stat(pet_id, "happiness", 5)
		game_manager.add_xp(pet_id, 5 + _level * 2)

	if audio_manager:
		audio_manager.play_sfx("win")

	# Auto-advance on board completion
	var leveled_up = false
	var new_level = game_manager.advance_game_level("memory")
	if new_level > _level:
		leveled_up = true
		_level = new_level

	var msg = "You matched them all! +%d bonus coins!" % bonus
	if leveled_up:
		msg += " LEVEL UP! Now Level %d: %s" % [_level, LEVEL_NAMES[_level]]
	msg += " ESC to exit."
	_info_label.text = msg
	_update_status()
	can_flip = false

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			var save_manager = get_tree().root.get_node_or_null("SaveManager")
			if save_manager:
				save_manager.on_scene_transition()
			get_tree().change_scene_to_file("res://scenes/Main.tscn")
			return

		# After winning, no replay from within — just ESC back
		if matched_pairs >= total_pairs:
			return

		if event.keycode == KEY_UP:
			cursor_y = max(0, cursor_y - 1)
			_draw_board()
		elif event.keycode == KEY_DOWN:
			cursor_y = min(grid_rows - 1, cursor_y + 1)
			_draw_board()
		elif event.keycode == KEY_LEFT:
			cursor_x = max(0, cursor_x - 1)
			_draw_board()
		elif event.keycode == KEY_RIGHT:
			cursor_x = min(grid_cols - 1, cursor_x + 1)
			_draw_board()
		elif event.keycode == KEY_SPACE:
			_flip_card()
