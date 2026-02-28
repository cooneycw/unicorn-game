extends Node

# Singleton managing egg spawn timing on the island
# Actual egg visuals are created by Island.gd; this tracks spawn cooldowns

signal egg_spawned  # Island.gd listens to place a visual egg

var _island_play_time: float = 0.0
var _next_spawn_time: float = 0.0
var _egg_available_on_island: bool = false

func _ready():
	_roll_next_spawn_time()

func _roll_next_spawn_time():
	# 5-10 minutes of active island play
	_next_spawn_time = _island_play_time + randf_range(300.0, 600.0)

func tick_island_time(delta: float):
	_island_play_time += delta
	if not _egg_available_on_island and _island_play_time >= _next_spawn_time:
		_egg_available_on_island = true
		egg_spawned.emit()

func egg_collected():
	_egg_available_on_island = false
	_roll_next_spawn_time()

func is_egg_available() -> bool:
	return _egg_available_on_island
