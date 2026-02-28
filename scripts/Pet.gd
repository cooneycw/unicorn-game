extends Node3D

# Pet visual representation in 3D — reads all stats from GameManager
class_name Pet

var pet_id: int
var pet_name: String
var pet_type: String  # "unicorn", "pegasus", "dragon"

var _game_manager
var _audio_manager
var _base_y: float = 0.0
var _bob_time: float = 0.0
var _label3d: Label3D
var _body_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _wing_l: MeshInstance3D
var _wing_r: MeshInstance3D

# Particles
var _happy_particles: GPUParticles3D
var _sad_particles: GPUParticles3D

# Wandering
var enable_wandering: bool = false
var _wander_target: Vector3
var _wander_pause: float = 0.0
var _wander_bounds: Vector2 = Vector2(10, 10)  # half-extents
var _move_speed: float = 0.5

func _ready():
	_game_manager = get_tree().root.get_node("GameManager")
	_audio_manager = get_tree().root.get_node_or_null("AudioManager")
	_base_y = position.y
	_wander_target = position

	_build_body()
	_build_head()
	_build_legs()
	_build_horn()
	_build_type_features()
	_build_label()
	_build_particles()

	# Randomize bob phase so pets don't all bob in sync
	_bob_time = randf() * TAU

func _build_body():
	_body_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.45
	sphere_mesh.height = 0.8
	_body_mesh.mesh = sphere_mesh
	_body_mesh.scale = Vector3(1.0, 0.9, 1.2)  # slightly elongated

	var material = StandardMaterial3D.new()
	material.albedo_color = _get_pet_color()
	_body_mesh.material_override = material

	add_child(_body_mesh)

func _build_head():
	_head_mesh = MeshInstance3D.new()
	var head = SphereMesh.new()
	head.radius = 0.25
	head.height = 0.5
	_head_mesh.mesh = head
	_head_mesh.position = Vector3(0, 0.35, -0.35)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = _get_pet_color()
	_head_mesh.material_override = mat
	add_child(_head_mesh)

	# Eyes
	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.05
		eye_mesh.height = 0.1
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.1, 0.38, -0.55)

		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color.BLACK
		eye.material_override = eye_mat
		add_child(eye)

func _build_legs():
	var leg_positions = [
		Vector3(-0.2, -0.45, -0.2),
		Vector3(0.2, -0.45, -0.2),
		Vector3(-0.2, -0.45, 0.2),
		Vector3(0.2, -0.45, 0.2),
	]
	for pos in leg_positions:
		var leg = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = 0.3
		leg.mesh = cyl
		leg.position = pos

		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_pet_color().darkened(0.1)
		leg.material_override = mat

		add_child(leg)

func _build_horn():
	if pet_type == "dragon":
		return
	var horn = MeshInstance3D.new()
	var cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.08
	cone_mesh.height = 0.4
	horn.mesh = cone_mesh
	horn.position = Vector3(0, 0.6, -0.35)

	var horn_material = StandardMaterial3D.new()
	horn_material.albedo_color = Color.YELLOW
	horn.material_override = horn_material

	add_child(horn)

func _build_type_features():
	match pet_type:
		"pegasus":
			for side in [-1.0, 1.0]:
				var wing = MeshInstance3D.new()
				var box = BoxMesh.new()
				box.size = Vector3(0.5, 0.04, 0.3)
				wing.mesh = box
				wing.position = Vector3(side * 0.55, 0.2, 0.0)
				wing.rotation.z = side * -0.3

				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.85, 0.85, 0.95)
				wing.material_override = mat

				if side < 0:
					wing.name = "Wing_L"
					_wing_l = wing
				else:
					wing.name = "Wing_R"
					_wing_r = wing
				add_child(wing)
		"dragon":
			# Tail
			var tail = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.1
			cyl.height = 0.5
			tail.mesh = cyl
			tail.position = Vector3(0, 0.0, 0.45)
			tail.rotation.x = PI / 3
			tail.name = "Tail"

			var mat = StandardMaterial3D.new()
			mat.albedo_color = _get_pet_color().darkened(0.2)
			tail.material_override = mat
			add_child(tail)

			# Small wing cones
			for side in [-1.0, 1.0]:
				var dwing = MeshInstance3D.new()
				var dcone = CylinderMesh.new()
				dcone.top_radius = 0.0
				dcone.bottom_radius = 0.15
				dcone.height = 0.35
				dwing.mesh = dcone
				dwing.position = Vector3(side * 0.45, 0.25, 0.1)
				dwing.rotation.z = side * -0.5

				var dmat = StandardMaterial3D.new()
				dmat.albedo_color = _get_pet_color().darkened(0.15)
				dwing.material_override = dmat
				add_child(dwing)

func _build_label():
	_label3d = Label3D.new()
	_label3d.position.y = 1.0
	_label3d.font_size = 48
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.no_depth_test = true
	_update_label()
	add_child(_label3d)

func _build_particles():
	# Happy sparkles (yellow/white upward)
	_happy_particles = GPUParticles3D.new()
	_happy_particles.amount = 8
	_happy_particles.lifetime = 1.0
	_happy_particles.emitting = false
	_happy_particles.position.y = 0.6

	var happy_mat = ParticleProcessMaterial.new()
	happy_mat.direction = Vector3(0, 1, 0)
	happy_mat.spread = 30.0
	happy_mat.initial_velocity_min = 0.5
	happy_mat.initial_velocity_max = 1.0
	happy_mat.gravity = Vector3(0, -0.5, 0)
	happy_mat.scale_min = 0.05
	happy_mat.scale_max = 0.1
	happy_mat.color = Color(1.0, 0.95, 0.3)
	_happy_particles.process_material = happy_mat

	var happy_mesh = SphereMesh.new()
	happy_mesh.radius = 0.04
	happy_mesh.height = 0.08
	_happy_particles.draw_pass_1 = happy_mesh

	add_child(_happy_particles)

	# Sad clouds (gray, drifting slowly)
	_sad_particles = GPUParticles3D.new()
	_sad_particles.amount = 4
	_sad_particles.lifetime = 2.0
	_sad_particles.emitting = false
	_sad_particles.position.y = 0.8

	var sad_mat = ParticleProcessMaterial.new()
	sad_mat.direction = Vector3(0, 0.3, 0)
	sad_mat.spread = 45.0
	sad_mat.initial_velocity_min = 0.1
	sad_mat.initial_velocity_max = 0.3
	sad_mat.gravity = Vector3(0, 0, 0)
	sad_mat.scale_min = 0.08
	sad_mat.scale_max = 0.15
	sad_mat.color = Color(0.6, 0.6, 0.65, 0.7)
	_sad_particles.process_material = sad_mat

	var sad_mesh = SphereMesh.new()
	sad_mesh.radius = 0.06
	sad_mesh.height = 0.08
	_sad_particles.draw_pass_1 = sad_mesh

	add_child(_sad_particles)

func _update_label():
	if _label3d == null or _game_manager == null:
		return
	var emoji = _game_manager.get_mood_emoji(pet_id)
	_label3d.text = pet_name + " " + emoji

func _process(delta: float):
	_bob_time += delta
	var mood = "content"
	if _game_manager:
		mood = _game_manager.get_pet_mood(pet_id)

	# Bobbing animation
	var speed: float
	var amplitude: float
	match mood:
		"happy":
			speed = 3.0
			amplitude = 0.15
		"content":
			speed = 2.0
			amplitude = 0.1
		"sad":
			speed = 1.0
			amplitude = 0.05
		"hungry":
			speed = 1.5
			amplitude = 0.07
		"resting":
			speed = 0.5
			amplitude = 0.03
		_:
			speed = 2.0
			amplitude = 0.1

	position.y = _base_y + sin(_bob_time * speed) * amplitude

	# Pegasus wing flapping
	if pet_type == "pegasus" and _wing_l and _wing_r:
		var flap = sin(_bob_time * 4.0) * 0.15
		_wing_l.rotation.z = 0.3 + flap
		_wing_r.rotation.z = -0.3 - flap

	# Dragon tail sway
	if pet_type == "dragon":
		var tail_node = get_node_or_null("Tail")
		if tail_node:
			tail_node.rotation.y = sin(_bob_time * 1.5) * 0.3

	# Particle effects based on mood
	_happy_particles.emitting = mood == "happy"
	_sad_particles.emitting = mood == "sad" or mood == "hungry"

	# Wandering behavior
	if enable_wandering and mood != "resting":
		_process_wander(delta)

	_update_label()

func _process_wander(delta: float):
	if _wander_pause > 0:
		_wander_pause -= delta
		return

	var dist = Vector2(position.x, position.z).distance_to(Vector2(_wander_target.x, _wander_target.z))
	if dist < 0.3:
		# Arrived — pause and pick new target
		_wander_pause = randf_range(2.0, 5.0)
		_wander_target = Vector3(
			randf_range(-_wander_bounds.x, _wander_bounds.x),
			_base_y,
			randf_range(-_wander_bounds.y, _wander_bounds.y)
		)
		return

	# Move toward target
	var dir = Vector3(_wander_target.x - position.x, 0, _wander_target.z - position.z).normalized()
	position.x += dir.x * _move_speed * delta
	position.z += dir.z * _move_speed * delta

	# Face movement direction
	if dir.length() > 0.01:
		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 3.0)

func do_happy_reaction():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.15)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
	if _audio_manager:
		_audio_manager.play_sfx("play")

func do_feed_reaction():
	# Head bob down animation
	if _head_mesh:
		var tween = create_tween()
		tween.tween_property(_head_mesh, "position:y", 0.15, 0.1)
		tween.tween_property(_head_mesh, "position:y", 0.35, 0.1)
		tween.tween_property(_head_mesh, "position:y", 0.15, 0.1)
		tween.tween_property(_head_mesh, "position:y", 0.35, 0.1)
	if _audio_manager:
		_audio_manager.play_sfx("feed")

func do_heal_reaction():
	# Brief green tint
	if _body_mesh and _body_mesh.material_override:
		var orig_color = _get_pet_color()
		var tween = create_tween()
		_body_mesh.material_override.albedo_color = Color.GREEN
		tween.tween_property(_body_mesh.material_override, "albedo_color", orig_color, 0.5)
	if _audio_manager:
		_audio_manager.play_sfx("heal")

func _get_pet_color() -> Color:
	match pet_type:
		"unicorn":
			return Color.WHITE
		"pegasus":
			return Color.LIGHT_GRAY
		"dragon":
			return Color.RED
		_:
			return Color.WHITE
