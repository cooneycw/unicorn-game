extends Node3D

# Island scene — pet interactions, egg spawning, environment, keyboard controls
var game_manager
var audio_manager
var pop_manager
var pets_in_scene: Array = []
var selected_pet_index: int = 0
var pet_ids: Array = []

var _feedback_label: Label
var _stats_label: Label
var _coins_label: Label
var _pop_label: Label
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

# Guild Board (Adventure Journeys)
var _guild_board_open: bool = false
var _guild_panel: PanelContainer
var _guild_label: Label
var _guild_quest_index: int = 0
var _available_quests: Array = []
var _guild_state: String = "quest_select"  # "quest_select" or "pet_select"
var _selected_quest: Dictionary = {}
var _eligible_pets: Array = []
var _guild_pet_index: int = 0

# Postcard notification
var _postcard_label: Label
var _postcard_timer: float = 0.0

# Egg spawning
var _egg_spawn_timer: float = 0.0
var _egg_spawn_interval: float = 0.0  # randomized on ready
var _egg_node: MeshInstance3D = null
var _egg_label: Label3D = null
var _egg_available: bool = false

# Walking koalas (independent, not riding pets)
var _walking_koalas: Array = []
var _koala_targets: Array = []
var _koala_pauses: Array = []

# Sky environment
var _world_env: WorldEnvironment
var _sky_env: Environment
const SKY_COLOR_CLEAR = Color(0.53, 0.81, 0.92)  # light blue
const SKY_COLOR_RAIN = Color(0.5, 0.5, 0.55)      # gray overcast

# Environment
var _sun_light: DirectionalLight3D
var _day_time: float = 0.0  # 0-1 representing full day cycle
var _clouds: Array = []

# Camera follows player character
var _camera: Camera3D
const CAMERA_BOUNDS: float = 14.0

# Player character (girl)
var _girl: Node3D
const GIRL_SPEED: float = 5.0
const GIRL_Y: float = -0.45  # ground level (ground plane at y=-1, girl feet on ground)
const BUMP_RADIUS: float = 1.2
const BUMP_FORCE: float = 3.0

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
	pop_manager = get_tree().root.get_node_or_null("PetPopulationManager")

	_create_island_environment()
	_create_trees()
	_create_pond()
	_create_clouds_3d()
	_create_sun_moon()
	_create_rain_system()
	_create_guild_board()
	_spawn_all_pets()
	_create_ui()

	game_manager.pet_stat_changed.connect(_on_stat_changed)
	game_manager.coins_changed.connect(_on_coins_changed)
	game_manager.postcard_received.connect(_on_postcard_received)

	if pet_ids.size() > 0:
		_highlight_selected()
		_update_stats_display()

	# Dynamic egg spawn interval based on population
	if pop_manager:
		_egg_spawn_interval = pop_manager.next_egg_interval()
	else:
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

	# Player character — girl on the ground
	_girl = Node3D.new()
	_girl.position = Vector3(0, GIRL_Y, 0)
	_girl.name = "Girl"
	_build_girl_model(_girl)
	add_child(_girl)

	# Camera follows girl from behind and above
	_camera = Camera3D.new()
	_update_camera_follow()
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

func _create_guild_board():
	# Physical signpost on the Island — a wooden board near the edge
	var board_root = Node3D.new()
	board_root.position = Vector3(-8, -1, 8)
	board_root.name = "GuildBoard"

	# Post (vertical cylinder)
	var post = MeshInstance3D.new()
	var post_mesh = CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.1
	post_mesh.height = 2.0
	post.mesh = post_mesh
	post.position.y = 1.0
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.45, 0.3, 0.15)
	post.material_override = post_mat
	board_root.add_child(post)

	# Board face (flat box)
	var board = MeshInstance3D.new()
	var board_mesh = BoxMesh.new()
	board_mesh.size = Vector3(1.2, 0.8, 0.06)
	board.mesh = board_mesh
	board.position = Vector3(0, 1.8, 0)
	var board_mat = StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.65, 0.5, 0.3)
	board.material_override = board_mat
	board_root.add_child(board)

	# Label
	var label = Label3D.new()
	label.text = "Guild Board [J]"
	label.font_size = 40
	label.position = Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.9, 0.5)
	board_root.add_child(label)

	add_child(board_root)

func _build_girl_model(root: Node3D):
	# Dress / body (cone shape — cute simple dress)
	var dress = MeshInstance3D.new()
	var dress_mesh = CylinderMesh.new()
	dress_mesh.top_radius = 0.15
	dress_mesh.bottom_radius = 0.35
	dress_mesh.height = 0.6
	dress.mesh = dress_mesh
	dress.position.y = 0.3
	var dress_mat = StandardMaterial3D.new()
	dress_mat.albedo_color = Color(0.9, 0.4, 0.6)  # pink dress
	dress.material_override = dress_mat
	root.add_child(dress)

	# Head
	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.position.y = 0.78
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(1.0, 0.87, 0.75)  # skin tone
	head.material_override = head_mat
	root.add_child(head)

	# Hair (back — longer)
	var hair_back = MeshInstance3D.new()
	var hair_mesh = SphereMesh.new()
	hair_mesh.radius = 0.2
	hair_mesh.height = 0.4
	hair_back.mesh = hair_mesh
	hair_back.position = Vector3(0, 0.75, 0.08)
	hair_back.scale = Vector3(1.0, 1.2, 0.8)
	var hair_mat = StandardMaterial3D.new()
	hair_mat.albedo_color = Color(0.35, 0.2, 0.1)  # brown hair
	hair_back.material_override = hair_mat
	root.add_child(hair_back)

	# Hair pigtails
	for side in [-1.0, 1.0]:
		var pigtail = MeshInstance3D.new()
		var pt_mesh = SphereMesh.new()
		pt_mesh.radius = 0.08
		pt_mesh.height = 0.25
		pigtail.mesh = pt_mesh
		pigtail.position = Vector3(side * 0.18, 0.65, 0.05)
		var pt_mat = StandardMaterial3D.new()
		pt_mat.albedo_color = Color(0.35, 0.2, 0.1)
		pigtail.material_override = pt_mat
		root.add_child(pigtail)

	# Eyes
	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.04
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.07, 0.8, -0.16)
		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color(0.2, 0.4, 0.7)  # blue eyes
		eye.material_override = eye_mat
		root.add_child(eye)

	# Legs
	for side in [-1.0, 1.0]:
		var leg = MeshInstance3D.new()
		var leg_mesh = CylinderMesh.new()
		leg_mesh.top_radius = 0.05
		leg_mesh.bottom_radius = 0.05
		leg_mesh.height = 0.3
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.1, -0.1, 0)
		var leg_mat = StandardMaterial3D.new()
		leg_mat.albedo_color = Color(1.0, 0.87, 0.75)
		leg.material_override = leg_mat
		root.add_child(leg)

	# Shoes
	for side in [-1.0, 1.0]:
		var shoe = MeshInstance3D.new()
		var shoe_mesh = SphereMesh.new()
		shoe_mesh.radius = 0.06
		shoe_mesh.height = 0.06
		shoe.mesh = shoe_mesh
		shoe.position = Vector3(side * 0.1, -0.25, -0.02)
		var shoe_mat = StandardMaterial3D.new()
		shoe_mat.albedo_color = Color(0.8, 0.2, 0.3)  # red shoes
		shoe.material_override = shoe_mat
		root.add_child(shoe)

func _update_camera_follow():
	if not _girl or not _camera:
		return
	# Third-person camera: behind and above the girl
	_camera.position = _girl.position + Vector3(0, 5, 6)
	_camera.look_at(_girl.position + Vector3(0, 0.5, 0), Vector3.UP)

func _spawn_all_pets():
	var all_pets = game_manager.get_active_pets()

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

		# Spawn a standalone walking koala if this pet has a koala but isn't a rider-compatible type
		if pet_info.get("has_koala", false) and pet_info["type"] not in ["unicorn", "pegasus", "dragon"]:
			_spawn_walking_koala()

func _spawn_walking_koala():
	var koala = Node3D.new()
	koala.position = Vector3(randf_range(-6, 6), 0.3, randf_range(-6, 6))
	koala.name = "WalkingKoala"

	# Body
	var body = MeshInstance3D.new()
	var body_mesh = SphereMesh.new()
	body_mesh.radius = 0.2
	body_mesh.height = 0.35
	body.mesh = body_mesh
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.5, 0.4, 0.3)
	body.material_override = bmat
	koala.add_child(body)

	# Head
	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.28
	head.mesh = head_mesh
	head.position = Vector3(0, 0.28, -0.08)
	var hmat = StandardMaterial3D.new()
	hmat.albedo_color = Color(0.65, 0.55, 0.4)
	head.material_override = hmat
	koala.add_child(head)

	# Ears
	for side in [-1.0, 1.0]:
		var ear = MeshInstance3D.new()
		var ear_mesh = SphereMesh.new()
		ear_mesh.radius = 0.1
		ear_mesh.height = 0.12
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.14, 0.4, -0.08)
		var emat = StandardMaterial3D.new()
		emat.albedo_color = Color(0.35, 0.25, 0.18)
		ear.material_override = emat
		koala.add_child(ear)

	# Eyes
	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.04
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.07, 0.3, -0.22)
		var eyemat = StandardMaterial3D.new()
		eyemat.albedo_color = Color(0.05, 0.05, 0.05)
		eye.material_override = eyemat
		koala.add_child(eye)

	# Nose
	var nose = MeshInstance3D.new()
	var nose_mesh = SphereMesh.new()
	nose_mesh.radius = 0.05
	nose_mesh.height = 0.04
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 0.24, -0.24)
	var nmat = StandardMaterial3D.new()
	nmat.albedo_color = Color(0.1, 0.08, 0.08)
	nose.material_override = nmat
	koala.add_child(nose)

	# Legs (4 short stubby legs)
	for pos in [Vector3(-0.1, -0.18, -0.08), Vector3(0.1, -0.18, -0.08), Vector3(-0.1, -0.18, 0.08), Vector3(0.1, -0.18, 0.08)]:
		var leg = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 0.15
		leg.mesh = cyl
		leg.position = pos
		var lmat = StandardMaterial3D.new()
		lmat.albedo_color = Color(0.45, 0.35, 0.25)
		leg.material_override = lmat
		koala.add_child(leg)

	# Label
	var label = Label3D.new()
	label.text = "Koala"
	label.font_size = 36
	label.position.y = 0.7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	koala.add_child(label)

	add_child(koala)
	_walking_koalas.append(koala)
	_koala_targets.append(koala.position)
	_koala_pauses.append(randf_range(1.0, 3.0))

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

	# Population indicator
	_pop_label = Label.new()
	_pop_label.add_theme_font_size_override("font_size", 14)
	if pop_manager:
		_pop_label.text = pop_manager.get_population_label()
		_pop_label.add_theme_color_override("font_color", pop_manager.get_population_color())
	else:
		_pop_label.text = "Pets: %d" % game_manager.pets.size()
		_pop_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	vbox.add_child(_pop_label)

	# Instructions — split into two lines so they don't overflow
	_instructions_label = Label.new()
	_instructions_label.text = "WASD/Numpad: walk | UP/DOWN or LEFT/RIGHT: select pet | F: feed | P: play | R: rest\nE: collect egg | I: inspect | X: rename | J: Guild Board | Ctrl+S: save | ESC: back"
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

	# Guild Board overlay panel (hidden by default)
	_guild_panel = PanelContainer.new()
	_guild_panel.position = Vector2(150, 80)
	_guild_panel.size = Vector2(520, 500)
	_guild_panel.visible = false
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.18, 0.92)
	panel_style.border_color = Color(0.8, 0.65, 0.3)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	_guild_panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(_guild_panel)

	_guild_label = Label.new()
	_guild_label.add_theme_font_size_override("font_size", 14)
	_guild_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_guild_panel.add_child(_guild_label)

	# Postcard notification (bottom-center, hidden by default)
	_postcard_label = Label.new()
	_postcard_label.position = Vector2(150, 550)
	_postcard_label.add_theme_font_size_override("font_size", 16)
	_postcard_label.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	_postcard_label.visible = false
	ui.add_child(_postcard_label)

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
	var has_rider = info.get("has_koala", false) and info["type"] in ["unicorn", "pegasus", "dragon"]
	var koala_str = " [Koala Rider!]" if has_rider else ""
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

	# Postcard display timer
	if _postcard_timer > 0:
		_postcard_timer -= delta
		if _postcard_timer <= 0:
			_postcard_label.visible = false

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

	# Walking koala wandering
	for i in range(_walking_koalas.size()):
		var koala = _walking_koalas[i]
		if _koala_pauses[i] > 0:
			_koala_pauses[i] -= delta
			# Gentle bob while paused
			koala.position.y = 0.3 + sin(Time.get_ticks_msec() / 800.0 + i) * 0.03
			continue
		var target = _koala_targets[i]
		var dist = Vector2(koala.position.x, koala.position.z).distance_to(Vector2(target.x, target.z))
		if dist < 0.3:
			_koala_pauses[i] = randf_range(2.0, 6.0)
			_koala_targets[i] = Vector3(randf_range(-7, 7), 0.3, randf_range(-7, 7))
		else:
			var dir = Vector3(target.x - koala.position.x, 0, target.z - koala.position.z).normalized()
			koala.position.x += dir.x * 0.4 * delta
			koala.position.z += dir.z * 0.4 * delta
			koala.position.y = 0.3 + sin(Time.get_ticks_msec() / 400.0 + i) * 0.04
			if dir.length() > 0.01:
				koala.rotation.y = lerp_angle(koala.rotation.y, atan2(dir.x, dir.z), delta * 3.0)

	# WASD + Numpad — move girl character
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
		_girl.position.x += move_dir.x * GIRL_SPEED * delta
		_girl.position.z += move_dir.z * GIRL_SPEED * delta
		_girl.position.x = clampf(_girl.position.x, -CAMERA_BOUNDS, CAMERA_BOUNDS)
		_girl.position.z = clampf(_girl.position.z, -CAMERA_BOUNDS + 5, CAMERA_BOUNDS + 5)
		_girl.position.y = GIRL_Y
		# Face movement direction
		var target_angle = atan2(move_dir.x, move_dir.z)
		_girl.rotation.y = lerp_angle(_girl.rotation.y, target_angle, delta * 8.0)

	# Camera follows girl
	_update_camera_follow()

	# Bump animals out of the way
	for pet in pets_in_scene:
		var dist = Vector2(_girl.position.x, _girl.position.z).distance_to(Vector2(pet.position.x, pet.position.z))
		if dist < BUMP_RADIUS and dist > 0.01:
			var push_dir = Vector3(pet.position.x - _girl.position.x, 0, pet.position.z - _girl.position.z).normalized()
			pet.position.x += push_dir.x * BUMP_FORCE * delta
			pet.position.z += push_dir.z * BUMP_FORCE * delta

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

	# Reset spawn timer — dynamic interval based on population
	if pop_manager:
		_egg_spawn_interval = pop_manager.next_egg_interval()
	else:
		_egg_spawn_interval = randf_range(300.0, 600.0)

	_show_feedback("Egg collected! It will hatch in about 5 minutes.")

	# Check achievements
	var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
	if achievement_mgr:
		achievement_mgr.check_all()

func _on_stat_changed(_pet_id: int, _stat_name: String, _new_value: int):
	_highlight_selected()
	_update_stats_display()
	_update_pop_display()

func _update_pop_display():
	if pop_manager and _pop_label:
		_pop_label.text = pop_manager.get_population_label()
		_pop_label.add_theme_color_override("font_color", pop_manager.get_population_color())

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

		# Guild Board input handling
		if _guild_board_open:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_J:
				_close_guild_board()
				return
			if _guild_state == "quest_select":
				if event.keycode == KEY_UP:
					_guild_quest_index = max(0, _guild_quest_index - 1)
					_refresh_guild_display()
					return
				if event.keycode == KEY_DOWN:
					_guild_quest_index = min(_available_quests.size() - 1, _guild_quest_index + 1)
					_refresh_guild_display()
					return
				if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
					if _available_quests.size() > 0:
						_selected_quest = _available_quests[_guild_quest_index]
						_eligible_pets = game_manager.get_eligible_pets_for_quest(_selected_quest)
						if _eligible_pets.size() == 0:
							_show_feedback("No pets meet the level requirement for this quest!")
							return
						_guild_state = "pet_select"
						_guild_pet_index = 0
						_refresh_guild_display()
					return
			elif _guild_state == "pet_select":
				if event.keycode == KEY_BACKSPACE:
					_guild_state = "quest_select"
					_refresh_guild_display()
					return
				if event.keycode == KEY_UP:
					_guild_pet_index = max(0, _guild_pet_index - 1)
					_refresh_guild_display()
					return
				if event.keycode == KEY_DOWN:
					_guild_pet_index = min(_eligible_pets.size() - 1, _guild_pet_index + 1)
					_refresh_guild_display()
					return
				if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
					if _eligible_pets.size() > 0:
						var chosen_pet_id = _eligible_pets[_guild_pet_index]
						var success = game_manager.send_pet_on_journey(chosen_pet_id, _selected_quest)
						if success:
							var pet_name = game_manager.pets[chosen_pet_id]["name"]
							_show_feedback("%s set off on '%s'! Check back later." % [pet_name, _selected_quest["name"]])
							# Check achievement
							var achievement_mgr = get_tree().root.get_node_or_null("AchievementManager")
							if achievement_mgr:
								achievement_mgr.check_journey_sent()
							if audio_manager:
								audio_manager.play_sfx("coin")
							# Remove pet from Island scene
							_remove_pet_from_scene(chosen_pet_id)
							_close_guild_board()
						else:
							_show_feedback("Could not send pet on journey.")
					return
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

		if event.keycode == KEY_J:
			_open_guild_board()
			return

func _open_guild_board():
	_available_quests = game_manager.get_available_quests()
	_guild_quest_index = 0
	_guild_state = "quest_select"
	_guild_board_open = true
	_guild_panel.visible = true
	_refresh_guild_display()

func _close_guild_board():
	_guild_board_open = false
	_guild_panel.visible = false

func _refresh_guild_display():
	var text = "=== GUILD BOARD ===\n\n"

	# Show active journeys at top
	if game_manager.active_journeys.size() > 0:
		text += "-- Pets On Journeys --\n"
		for journey in game_manager.active_journeys:
			var pet = game_manager.pets.get(journey["pet_id"], null)
			if pet:
				var remaining = game_manager.get_journey_time_remaining(journey["pet_id"])
				var mins = ceili(remaining / 60.0)
				text += "  %s -> %s (%dm left)\n" % [pet["name"], journey["quest_name"], mins]
		text += "\n"

	if _guild_state == "quest_select":
		text += "-- Available Quests --\n"
		text += "UP/DOWN: browse | SPACE: select | ESC: close\n\n"
		if _available_quests.size() == 0:
			text += "  No quests available right now.\n"
		else:
			for i in range(_available_quests.size()):
				var quest = _available_quests[i]
				var prefix = "> " if i == _guild_quest_index else "  "
				text += "%s%s (Lv%d+, %dm, %d coins)\n" % [prefix, quest["name"], quest["min_level"], quest["duration"], quest["coin_reward"]]
				if i == _guild_quest_index:
					text += "    %s\n" % quest["desc"]

	elif _guild_state == "pet_select":
		text += "-- Select a Pet for: %s --\n" % _selected_quest["name"]
		text += "UP/DOWN: browse | SPACE: confirm | BACKSPACE: back\n\n"
		for i in range(_eligible_pets.size()):
			var pid = _eligible_pets[i]
			var pet = game_manager.pets[pid]
			var prefix = "> " if i == _guild_pet_index else "  "
			text += "%s%s Lv%d (%s)\n" % [prefix, pet["name"], pet["level"], pet["type"]]

	_guild_label.text = text

func _remove_pet_from_scene(pet_id: int):
	for i in range(pet_ids.size()):
		if pet_ids[i] == pet_id:
			var pet_node = pets_in_scene[i]
			pet_node.queue_free()
			pets_in_scene.remove_at(i)
			pet_ids.remove_at(i)
			# Fix selection index
			if selected_pet_index >= pet_ids.size():
				selected_pet_index = max(0, pet_ids.size() - 1)
			_highlight_selected()
			_update_stats_display()
			_update_pop_display()
			break

func _on_postcard_received(pet_name: String, message: String):
	_postcard_label.text = "Postcard from %s: %s" % [pet_name, message]
	_postcard_label.visible = true
	_postcard_timer = 6.0
	if audio_manager:
		audio_manager.play_sfx("menu_select")
