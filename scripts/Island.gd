extends Node3D

# Island scene — pet interactions, egg spawning, environment, keyboard controls
var game_manager
var audio_manager
var pets_in_scene: Array = []
var selected_pet_index: int = 0
var pet_ids: Array = []

var _feedback_label: Label
var _stats_label: Label
var _coins_label: Label
var _pet_list_label: Label
var _instructions_label: Label
var _feedback_timer: float = 0.0
var _scroll_container: ScrollContainer

# Action cooldown to prevent exploits (e.g. holding P+R or rapid tapping)
var _action_cooldown: float = 0.0
const ACTION_COOLDOWN_TIME: float = 2.0  # seconds between actions

# Pet renaming mode
var _renaming: bool = false
var _rename_buffer: String = ""
var _rename_label: Label

# Egg spawning
var _egg_spawn_timer: float = 0.0
var _egg_spawn_interval: float = 0.0  # randomized on ready
var _egg_node: MeshInstance3D = null
var _egg_label: Label3D = null
var _egg_available: bool = false

# Sky environment
var _world_env: WorldEnvironment
var _sky_env: Environment
const SKY_COLOR_CLEAR = Color(0.53, 0.81, 0.92)  # light blue
const SKY_COLOR_RAIN = Color(0.5, 0.5, 0.55)      # gray overcast

# Environment
var _sun_light: DirectionalLight3D
var _day_time: float = 0.0  # 0-1 representing full day cycle
var _clouds: Array = []

# Camera (WASD walking)
var _camera: Camera3D
const CAMERA_SPEED: float = 8.0
const CAMERA_BOUNDS: float = 14.0

# Weather — Sun and Moon meshes
var _sun_mesh: MeshInstance3D
var _moon_mesh: MeshInstance3D

# Rain system
var _is_raining: bool = false
var _rain_timer: float = 0.0
var _rain_particles: GPUParticles3D
var _rain_duration: float = 0.0
var _next_rain_time: float = 0.0

func _ready():
	game_manager = get_tree().root.get_node("GameManager")
	audio_manager = get_tree().root.get_node_or_null("AudioManager")

	_create_island_environment()
	_create_trees()
	_create_pond()
	_create_clouds_3d()
	_create_sun_moon()
	_create_rain_system()
	_spawn_all_pets()
	_create_ui()

	game_manager.pet_stat_changed.connect(_on_stat_changed)
	game_manager.coins_changed.connect(_on_coins_changed)

	if pet_ids.size() > 0:
		_highlight_selected()
		_update_stats_display()

	# Randomize first egg spawn (5-10 minutes)
	_egg_spawn_interval = randf_range(300.0, 600.0)

	# First rain event in 2-5 minutes
	_next_rain_time = randf_range(120.0, 300.0)

func _create_island_environment():
	# Ground
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(30, 30)
	ground.mesh = plane_mesh
	ground.position.y = -1

	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.25, 0.55, 0.2)
	ground.material_override = ground_material
	add_child(ground)

	# Sunlight with day/night cycle
	_sun_light = DirectionalLight3D.new()
	_sun_light.rotation.x = -PI / 4
	_sun_light.rotation.y = -PI / 4
	_sun_light.light_energy = 1.0
	_sun_light.light_color = Color(1.0, 0.95, 0.8)
	add_child(_sun_light)

	# Camera (player-controlled)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 8, 15)
	_camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	add_child(_camera)

	# Sky background — light blue by default
	_sky_env = Environment.new()
	_sky_env.background_mode = Environment.BG_COLOR
	_sky_env.background_color = SKY_COLOR_CLEAR
	_sky_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_sky_env.ambient_light_color = Color.WHITE
	_sky_env.ambient_light_energy = 0.5
	_world_env = WorldEnvironment.new()
	_world_env.environment = _sky_env
	add_child(_world_env)

func _create_trees():
	var tree_positions = [
		Vector3(-10, -1, -8), Vector3(-8, -1, 5), Vector3(9, -1, -6),
		Vector3(12, -1, 3), Vector3(-6, -1, -12), Vector3(7, -1, 10),
		Vector3(-12, -1, 0), Vector3(11, -1, -10), Vector3(-4, -1, 11),
		Vector3(5, -1, -11), Vector3(-11, -1, 8), Vector3(13, -1, 7),
	]
	for pos in tree_positions:
		_create_tree(pos)

func _create_tree(pos: Vector3):
	var tree_root = Node3D.new()
	tree_root.position = pos

	# Trunk
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 1.5
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.75

	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.3, 0.15)
	trunk.material_override = trunk_mat
	tree_root.add_child(trunk)

	# Canopy (cone)
	var canopy = MeshInstance3D.new()
	var canopy_mesh = CylinderMesh.new()
	canopy_mesh.top_radius = 0.0
	canopy_mesh.bottom_radius = 1.0
	canopy_mesh.height = 2.0
	canopy.mesh = canopy_mesh
	canopy.position.y = 2.5

	var canopy_mat = StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.15, 0.5 + randf() * 0.15, 0.1)
	canopy.material_override = canopy_mat
	tree_root.add_child(canopy)

	add_child(tree_root)

func _create_pond():
	var pond = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 3.0
	disc.bottom_radius = 3.0
	disc.height = 0.05
	pond.mesh = disc
	pond.position = Vector3(8, -0.95, -2)

	var pond_mat = StandardMaterial3D.new()
	pond_mat.albedo_color = Color(0.2, 0.5, 0.8, 0.7)
	pond_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pond.material_override = pond_mat
	add_child(pond)

func _create_clouds_3d():
	# 3D puffy cloud clusters instead of flat spheres
	for i in range(8):
		var cloud_group = Node3D.new()
		cloud_group.position = Vector3(
			randf_range(-20, 20),
			randf_range(12, 18),
			randf_range(-15, -5)
		)
		cloud_group.name = "Cloud_%d" % i

		# Each cloud is 3-5 overlapping spheres for puffy 3D look
		var num_puffs = randi_range(3, 5)
		for j in range(num_puffs):
			var puff = MeshInstance3D.new()
			var puff_mesh = SphereMesh.new()
			puff_mesh.radius = randf_range(0.8, 1.8)
			puff_mesh.height = randf_range(0.6, 1.2)
			puff.mesh = puff_mesh
			puff.position = Vector3(
				randf_range(-1.5, 1.5),
				randf_range(-0.3, 0.3),
				randf_range(-0.8, 0.8)
			)
			puff.scale = Vector3(1.3, 0.5, 0.9)

			var cloud_mat = StandardMaterial3D.new()
			cloud_mat.albedo_color = Color(1, 1, 1, 0.55)
			cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			puff.material_override = cloud_mat

			cloud_group.add_child(puff)

		add_child(cloud_group)
		_clouds.append(cloud_group)

func _create_sun_moon():
	# Sun — yellow emissive sphere
	_sun_mesh = MeshInstance3D.new()
	var sun_sphere = SphereMesh.new()
	sun_sphere.radius = 1.5
	sun_sphere.height = 3.0
	_sun_mesh.mesh = sun_sphere

	var sun_mat = StandardMaterial3D.new()
	sun_mat.albedo_color = Color(1.0, 0.95, 0.3)
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(1.0, 0.9, 0.4)
	sun_mat.emission_energy_multiplier = 2.0
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sun_mesh.material_override = sun_mat
	add_child(_sun_mesh)

	# Moon — pale white/blue sphere
	_moon_mesh = MeshInstance3D.new()
	var moon_sphere = SphereMesh.new()
	moon_sphere.radius = 0.8
	moon_sphere.height = 1.6
	_moon_mesh.mesh = moon_sphere

	var moon_mat = StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.85, 0.88, 0.95)
	moon_mat.emission_enabled = true
	moon_mat.emission = Color(0.7, 0.75, 0.9)
	moon_mat.emission_energy_multiplier = 1.0
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_moon_mesh.material_override = moon_mat
	add_child(_moon_mesh)

func _create_rain_system():
	_rain_particles = GPUParticles3D.new()
	_rain_particles.amount = 200
	_rain_particles.lifetime = 1.5
	_rain_particles.emitting = false
	_rain_particles.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 25, 40))

	var rain_mat = ParticleProcessMaterial.new()
	rain_mat.direction = Vector3(0, -1, 0)
	rain_mat.spread = 5.0
	rain_mat.initial_velocity_min = 8.0
	rain_mat.initial_velocity_max = 12.0
	rain_mat.gravity = Vector3(0, -9.8, 0)
	rain_mat.scale_min = 0.02
	rain_mat.scale_max = 0.04
	rain_mat.color = Color(0.5, 0.6, 0.9, 0.6)
	rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_mat.emission_box_extents = Vector3(15, 0, 15)
	_rain_particles.process_material = rain_mat
	_rain_particles.position = Vector3(0, 18, 0)

	# Raindrop mesh (tiny stretched sphere)
	var drop_mesh = SphereMesh.new()
	drop_mesh.radius = 0.03
	drop_mesh.height = 0.15
	_rain_particles.draw_pass_1 = drop_mesh

	add_child(_rain_particles)

func _spawn_all_pets():
	var all_pets = game_manager.get_all_pets()

	for pet_id in all_pets.keys():
		var pet_info = all_pets[pet_id]
		var pet = Pet.new()
		pet.pet_id = pet_id
		pet.pet_name = pet_info["name"]
		pet.pet_type = pet_info["type"]
		pet.enable_wandering = true
		pet._wander_bounds = Vector2(8, 8)

		pet.position = Vector3(randf_range(-6, 6), 0.5, randf_range(-6, 6))

		add_child(pet)
		pets_in_scene.append(pet)
		pet_ids.append(pet_id)

func _create_ui():
	var ui = Control.new()
	ui.anchor_right = 1.0
	ui.anchor_bottom = 1.0
	ui.name = "UI"
	add_child(ui)

	# Scroll container so the pet list + stats can be scrolled when overflowing
	_scroll_container = ScrollContainer.new()
	_scroll_container.position = Vector2(10, 10)
	_scroll_container.size = Vector2(500, 600)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(_scroll_container)

	# Main vertical layout
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(vbox)

	# Title row with coins
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "ISLAND"
	title.add_theme_font_size_override("font_size", 22)
	title_row.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	_coins_label = Label.new()
	_coins_label.text = "Coins: %d" % game_manager.coins
	_coins_label.add_theme_font_size_override("font_size", 16)
	_coins_label.add_theme_color_override("font_color", Color.YELLOW)
	title_row.add_child(_coins_label)

	# Instructions — split into two lines so they don't overflow
	_instructions_label = Label.new()
	_instructions_label.text = "WASD/Numpad: walk | UP/DOWN or LEFT/RIGHT: select pet | F: feed | P: play | R: rest\nE: collect egg | I: inspect | X: rename | Ctrl+S: save | ESC: back"
	_instructions_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_instructions_label)

	vbox.add_child(HSeparator.new())

	# Pet list
	_pet_list_label = Label.new()
	_pet_list_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_pet_list_label)

	vbox.add_child(HSeparator.new())

	# Stats for selected pet
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_stats_label)

	vbox.add_child(HSeparator.new())

	# Feedback message
	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 15)
	_feedback_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(_feedback_label)

	# Rename mode label (centered, hidden by default)
	_rename_label = Label.new()
	_rename_label.position = Vector2(200, 300)
	_rename_label.add_theme_font_size_override("font_size", 22)
	_rename_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_rename_label.visible = false
	ui.add_child(_rename_label)

func _highlight_selected():
	if pet_ids.size() == 0:
		return
	var lines = ""
	for i in range(pet_ids.size()):
		var pid = pet_ids[i]
		var info = game_manager.get_pet_info(pid)
		var mood = game_manager.get_mood_emoji(pid)
		var level = game_manager.get_level(pid)
		var prefix = "> " if i == selected_pet_index else "  "
		lines += "%s%s Lv%d (%s) %s\n" % [prefix, info["name"], level, info["type"], mood]
	_pet_list_label.text = lines

func _update_stats_display():
	if pet_ids.size() == 0:
		_stats_label.text = "No pets on island."
		return
	var pid = pet_ids[selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	var mood = game_manager.get_pet_mood(pid)
	var xp_info = game_manager.get_xp_progress(pid)
	var cap = game_manager.get_stat_cap(pid)
	var xp_str = "XP: %d/%d" % [xp_info["current"], xp_info["next"]] if xp_info["next"] > 0 else "XP: MAX"
	var koala_str = " [Koala Rider!]" if info.get("has_koala", false) else ""
	_stats_label.text = "--- %s Lv%d (%s)%s --- Mood: %s\nHealth:    %d/%d\nHappiness: %d/%d\nHunger:    %d/%d\nEnergy:    %d/%d\n%s" % [
		info["name"], info["level"], info["type"], koala_str, mood,
		info["health"], cap, info["happiness"], cap, info["hunger"], cap, info["energy"], cap,
		xp_str
	]

func _show_feedback(msg: String):
	_feedback_label.text = msg
	_feedback_timer = 2.5

func _process(delta: float):
	# Action cooldown
	if _action_cooldown > 0:
		_action_cooldown -= delta

	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0:
			_feedback_label.text = ""

	# Egg spawn timer
	if not _egg_available:
		_egg_spawn_timer += delta
		if _egg_spawn_timer >= _egg_spawn_interval:
			_spawn_egg()

	# Egg glow animation
	if _egg_node and _egg_available:
		_egg_node.position.y = 0.3 + sin(Time.get_ticks_msec() / 500.0) * 0.1

	# Day/night cycle (full cycle every 5 minutes)
	_day_time += delta / 300.0
	if _day_time > 1.0:
		_day_time -= 1.0

	var sun_angle = _day_time * TAU
	_sun_light.rotation.x = -PI / 4 + sin(sun_angle) * 0.3
	var day_factor = (sin(sun_angle) + 1.0) / 2.0  # 0 = night, 1 = day

	# Reduce brightness during rain
	var rain_dimming = 0.6 if _is_raining else 1.0
	_sun_light.light_energy = lerp(0.3, 1.2, day_factor) * rain_dimming

	var rain_blue_shift = 0.15 if _is_raining else 0.0
	_sun_light.light_color = Color(
		lerp(0.4, 1.0, day_factor) - rain_blue_shift,
		lerp(0.3, 0.95, day_factor) - rain_blue_shift,
		lerp(0.6, 0.8, day_factor) + rain_blue_shift
	)

	# Move sun and moon
	if _sun_mesh:
		_sun_mesh.position = Vector3(
			-sin(sun_angle) * 20,
			cos(sun_angle) * 15 + 10,
			-15
		)
		# Hide sun below horizon
		_sun_mesh.visible = _sun_mesh.position.y > 2

	if _moon_mesh:
		_moon_mesh.position = Vector3(
			sin(sun_angle) * 20,  # opposite side
			-cos(sun_angle) * 15 + 10,
			-15
		)
		_moon_mesh.visible = _moon_mesh.position.y > 2

	# Drift clouds
	for cloud in _clouds:
		cloud.position.x += delta * randf_range(0.2, 0.4)
		if cloud.position.x > 25:
			cloud.position.x = -25

	# Rain system
	_rain_timer += delta
	if not _is_raining and _rain_timer >= _next_rain_time:
		_start_rain()
	elif _is_raining:
		_rain_duration -= delta
		if _rain_duration <= 0:
			_stop_rain()

	# WASD + Numpad + Arrow camera movement
	var move_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_KP_8):
		move_dir.z -= 1
	if (Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_CTRL)) or Input.is_key_pressed(KEY_KP_2):
		move_dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_KP_4):
		move_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_KP_6):
		move_dir.x += 1

	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
		_camera.position.x += move_dir.x * CAMERA_SPEED * delta
		_camera.position.z += move_dir.z * CAMERA_SPEED * delta
		_camera.position.x = clampf(_camera.position.x, -CAMERA_BOUNDS, CAMERA_BOUNDS)
		_camera.position.z = clampf(_camera.position.z, -CAMERA_BOUNDS + 5, CAMERA_BOUNDS + 5)
		# Look forward-down from camera position
		var look_target = _camera.position + Vector3(0, -4, -8)
		_camera.look_at(look_target, Vector3.UP)

func _start_rain():
	_is_raining = true
	_rain_particles.emitting = true
	_rain_duration = randf_range(30.0, 60.0)
	# Tween sky to overcast gray
	var tween = create_tween()
	tween.tween_property(_sky_env, "background_color", SKY_COLOR_RAIN, 2.0)

func _stop_rain():
	_is_raining = false
	_rain_particles.emitting = false
	_rain_timer = 0.0
	_next_rain_time = randf_range(120.0, 300.0)
	# Tween sky back to clear blue
	var tween = create_tween()
	tween.tween_property(_sky_env, "background_color", SKY_COLOR_CLEAR, 3.0)

func _spawn_egg():
	_egg_available = true
	_egg_spawn_timer = 0.0

	_egg_node = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.45
	_egg_node.mesh = sphere
	_egg_node.position = Vector3(randf_range(-8, 8), 0.3, randf_range(-8, 8))

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.4, 0.8)
	mat.emission_energy_multiplier = 0.5
	_egg_node.material_override = mat
	add_child(_egg_node)

	_egg_label = Label3D.new()
	_egg_label.text = "?"
	_egg_label.font_size = 64
	_egg_label.position.y = 0.5
	_egg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_egg_label.no_depth_test = true
	_egg_node.add_child(_egg_label)

func _collect_egg():
	if not _egg_available:
		_show_feedback("No egg to collect! Keep playing and one may appear...")
		return

	var success = game_manager.collect_egg()
	if not success:
		_show_feedback("Egg inventory full! (max %d) Wait for one to hatch." % game_manager.MAX_EGGS)
		return

	_egg_available = false
	if _egg_node:
		_egg_node.queue_free()
		_egg_node = null
		_egg_label = null

	# Reset spawn timer for next egg
	_egg_spawn_interval = randf_range(300.0, 600.0)

	_show_feedback("Egg collected! It will hatch in about 5 minutes.")

	# Check achievements
	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_all()

func _on_stat_changed(_pet_id: int, _stat_name: String, _new_value: int):
	_highlight_selected()
	_update_stats_display()

func _on_coins_changed(new_amount: int):
	_coins_label.text = "Coins: %d" % new_amount

func _get_selected_pet_name() -> String:
	if pet_ids.size() == 0:
		return ""
	var pid = pet_ids[selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	return info["name"]

func _get_selected_pet() -> Pet:
	if selected_pet_index < pets_in_scene.size():
		return pets_in_scene[selected_pet_index]
	return null

func _can_act() -> bool:
	return _action_cooldown <= 0

func _action_feed():
	if pet_ids.size() == 0 or not _can_act():
		return
	if game_manager.coins < 5:
		_show_feedback("Not enough coins! (need 5)")
		return
	_action_cooldown = ACTION_COOLDOWN_TIME
	var pid = pet_ids[selected_pet_index]
	game_manager.modify_coins(-5)
	game_manager.modify_stat(pid, "hunger", 20)
	game_manager.add_xp(pid, 5)
	var pet_node = _get_selected_pet()
	if pet_node:
		pet_node.do_feed_reaction()
	_show_feedback("%s loved the treats! (+5 XP)" % _get_selected_pet_name())

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_all()

func _action_play():
	if pet_ids.size() == 0 or not _can_act():
		return
	_action_cooldown = ACTION_COOLDOWN_TIME
	var pid = pet_ids[selected_pet_index]
	var info = game_manager.get_pet_info(pid)
	if info["energy"] < 10:
		_show_feedback("%s is too tired to play!" % info["name"])
		return
	game_manager.modify_stat(pid, "happiness", 15)
	game_manager.modify_stat(pid, "energy", -10)
	game_manager.modify_coins(3)
	game_manager.add_xp(pid, 10)
	var pet_node = _get_selected_pet()
	if pet_node:
		pet_node.do_happy_reaction()
	if audio_manager:
		audio_manager.play_sfx("coin")
	_show_feedback("%s had a great time playing! (+3 coins, +10 XP)" % _get_selected_pet_name())

	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_all()

func _action_rest():
	if pet_ids.size() == 0 or not _can_act():
		return
	_action_cooldown = ACTION_COOLDOWN_TIME
	var pid = pet_ids[selected_pet_index]
	game_manager.modify_stat(pid, "energy", 20)
	_show_feedback("%s is resting... zzz" % _get_selected_pet_name())

func _go_back():
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _inspect_pet():
	if pet_ids.size() == 0:
		return
	game_manager.inspecting_pet_id = pet_ids[selected_pet_index]
	var save_manager = get_tree().root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.on_scene_transition()
	get_tree().change_scene_to_file("res://scenes/PetProfile.tscn")

func _start_rename():
	if pet_ids.size() == 0:
		return
	_renaming = true
	_rename_buffer = ""
	_rename_label.visible = true
	_rename_label.text = "New name: _\n(Type name, ENTER to confirm, ESC to cancel)"

func _finish_rename():
	if _rename_buffer.length() > 0 and pet_ids.size() > 0:
		var pid = pet_ids[selected_pet_index]
		game_manager.pets[pid]["name"] = _rename_buffer
		# Update the Pet node's name too
		if selected_pet_index < pets_in_scene.size():
			pets_in_scene[selected_pet_index].pet_name = _rename_buffer
		_show_feedback("Renamed to '%s'!" % _rename_buffer)
		_highlight_selected()
		_update_stats_display()
	_renaming = false
	_rename_label.visible = false
	_rename_buffer = ""

func _cancel_rename():
	_renaming = false
	_rename_label.visible = false
	_rename_buffer = ""

func _input(event):
	if event is InputEventKey and event.pressed:
		# Ignore key repeat (echo) for action keys — prevents hold-to-spam exploit
		var is_action_key = event.keycode in [KEY_F, KEY_P, KEY_R, KEY_E]
		if is_action_key and event.is_echo():
			return

		# Rename mode input handling
		if _renaming:
			if event.keycode == KEY_ESCAPE:
				_cancel_rename()
				return
			if event.keycode == KEY_ENTER:
				_finish_rename()
				return
			if event.keycode == KEY_BACKSPACE:
				if _rename_buffer.length() > 0:
					_rename_buffer = _rename_buffer.substr(0, _rename_buffer.length() - 1)
				_rename_label.text = "New name: %s_\n(Type name, ENTER to confirm, ESC to cancel)" % _rename_buffer
				return
			# Accept letter keys
			if event.unicode > 0 and _rename_buffer.length() < 20:
				var ch = char(event.unicode)
				if ch.strip_edges() != "" or ch == " ":
					_rename_buffer += ch
					_rename_label.text = "New name: %s_\n(Type name, ENTER to confirm, ESC to cancel)" % _rename_buffer
			return

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

		if event.keycode == KEY_LEFT or event.keycode == KEY_UP:
			selected_pet_index = max(0, selected_pet_index - 1)
			_highlight_selected()
			_update_stats_display()
			if audio_manager:
				audio_manager.play_sfx("menu_navigate")
			return

		if event.keycode == KEY_RIGHT or event.keycode == KEY_DOWN:
			selected_pet_index = min(pet_ids.size() - 1, selected_pet_index + 1)
			_highlight_selected()
			_update_stats_display()
			if audio_manager:
				audio_manager.play_sfx("menu_navigate")
			return

		if event.keycode == KEY_F:
			_action_feed()
			return

		if event.keycode == KEY_P:
			_action_play()
			return

		if event.keycode == KEY_R:
			_action_rest()
			return

		if event.keycode == KEY_E:
			_collect_egg()
			return

		if event.keycode == KEY_X:
			_start_rename()
			return

		if event.keycode == KEY_I:
			_inspect_pet()
			return
