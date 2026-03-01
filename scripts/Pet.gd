extends Node3D

# Pet visual representation in 3D — reads all stats from GameManager
class_name Pet

var pet_id: int
var pet_name: String
var pet_type: String  # "unicorn", "pegasus", "dragon", "alicorn", "dogicorn", "caticorn"

var _game_manager
var _audio_manager
var _base_y: float = 0.0
var _bob_time: float = 0.0
var _label3d: Label3D
var _body_mesh: MeshInstance3D
var _head_mesh: MeshInstance3D
var _wing_l: MeshInstance3D
var _wing_r: MeshInstance3D
var _iridescent_time: float = 0.0

# Dog/Cat features
var _tail_node: Node3D
var _ear_l: MeshInstance3D
var _ear_r: MeshInstance3D

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

	# Koala rider — only on unicorn, pegasus, dragon
	if _game_manager:
		var info = _game_manager.get_pet_info(pet_id)
		if info and info.get("has_koala", false) and pet_type in ["unicorn", "pegasus", "dragon"]:
			_build_koala()

	_game_manager.pet_leveled_up.connect(_on_pet_leveled_up)

	# Randomize bob phase so pets don't all bob in sync
	_bob_time = randf() * TAU

func _build_body():
	_body_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()

	match pet_type:
		"dogicorn":
			sphere_mesh.radius = 0.5
			sphere_mesh.height = 0.9
			_body_mesh.scale = Vector3(1.1, 0.85, 1.3)  # stocky
		"caticorn":
			sphere_mesh.radius = 0.4
			sphere_mesh.height = 0.75
			_body_mesh.scale = Vector3(0.9, 0.95, 1.4)  # sleek and long
		_:
			sphere_mesh.radius = 0.45
			sphere_mesh.height = 0.8
			_body_mesh.scale = Vector3(1.0, 0.9, 1.2)  # original

	_body_mesh.mesh = sphere_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = _get_pet_color()
	_body_mesh.material_override = material

	add_child(_body_mesh)

func _build_head():
	_head_mesh = MeshInstance3D.new()
	var head = SphereMesh.new()

	match pet_type:
		"dogicorn":
			head.radius = 0.28
			head.height = 0.55
			_head_mesh.position = Vector3(0, 0.3, -0.4)
		"caticorn":
			head.radius = 0.22
			head.height = 0.44
			_head_mesh.position = Vector3(0, 0.38, -0.38)
		"dragon":
			head.radius = 0.25
			head.height = 0.5
			_head_mesh.position = Vector3(0, 0.35, -0.35)
			_head_mesh.scale = Vector3(1.2, 0.9, 1.1)  # wider dragon head
		_:
			head.radius = 0.25
			head.height = 0.5
			_head_mesh.position = Vector3(0, 0.35, -0.35)

	_head_mesh.mesh = head

	var mat = StandardMaterial3D.new()
	if pet_type == "dragon":
		mat.albedo_color = Color(1.0, 0.84, 0.0)  # gold head
	else:
		mat.albedo_color = _get_pet_color()
	_head_mesh.material_override = mat
	add_child(_head_mesh)

	# Eyes
	var eye_z = -0.55
	var eye_y = 0.38
	match pet_type:
		"dogicorn":
			eye_z = -0.58
			eye_y = 0.35
		"caticorn":
			eye_z = -0.52
			eye_y = 0.4

	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.05
		eye_mesh.height = 0.1
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.1, eye_y, eye_z)

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

	# Adjust leg positions for different body shapes
	match pet_type:
		"dogicorn":
			leg_positions = [
				Vector3(-0.25, -0.42, -0.25),
				Vector3(0.25, -0.42, -0.25),
				Vector3(-0.25, -0.42, 0.25),
				Vector3(0.25, -0.42, 0.25),
			]
		"caticorn":
			leg_positions = [
				Vector3(-0.18, -0.45, -0.25),
				Vector3(0.18, -0.45, -0.25),
				Vector3(-0.18, -0.45, 0.3),
				Vector3(0.18, -0.45, 0.3),
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
		return  # dragons get dragon horns in _build_type_features()
	if pet_type == "pegasus":
		return  # pegasus has no horn (winged horse)

	var horn = MeshInstance3D.new()
	var cone_mesh = CylinderMesh.new()

	match pet_type:
		"dogicorn":
			cone_mesh.top_radius = 0.0
			cone_mesh.bottom_radius = 0.07
			cone_mesh.height = 0.35
			horn.position = Vector3(0, 0.55, -0.4)
		"caticorn":
			cone_mesh.top_radius = 0.0
			cone_mesh.bottom_radius = 0.06
			cone_mesh.height = 0.3
			horn.position = Vector3(0, 0.58, -0.38)
		_:
			cone_mesh.top_radius = 0.0
			cone_mesh.bottom_radius = 0.08
			cone_mesh.height = 0.4
			horn.position = Vector3(0, 0.6, -0.35)

	horn.mesh = cone_mesh

	var horn_material = StandardMaterial3D.new()
	horn_material.albedo_color = Color.YELLOW
	horn.material_override = horn_material

	add_child(horn)

const RAINBOW_COLORS: Array = [
	Color(1.0, 0.0, 0.0),      # red
	Color(1.0, 0.5, 0.0),      # orange
	Color(1.0, 1.0, 0.0),      # yellow
	Color(0.0, 0.8, 0.0),      # green
	Color(0.0, 0.4, 1.0),      # blue
	Color(0.56, 0.0, 1.0),     # violet
]

func _build_type_features():
	match pet_type:
		"unicorn":
			_build_mane(RAINBOW_COLORS)
			_build_equine_tail(RAINBOW_COLORS)
		"pegasus":
			_build_pegasus_wings()
			var blue = Color(0.3, 0.5, 1.0)
			_build_mane([blue])
			_build_equine_tail([blue])
		"dragon":
			_build_dragon_features()
		"alicorn":
			_build_alicorn_features()
			_build_mane([Color(0.8, 0.6, 0.95)])
			_build_equine_tail([Color(0.8, 0.6, 0.95)])
		"dogicorn":
			_build_dog_features()
		"caticorn":
			_build_cat_features()

func _build_mane(colors: Array):
	# Flowing mane along neck — series of small spheres
	var segment_count = 6
	for i in range(segment_count):
		var mane_part = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.07 - i * 0.005
		sphere.height = 0.12 - i * 0.008
		mane_part.mesh = sphere

		# Position along the top of neck/back
		var t = float(i) / float(segment_count - 1)
		mane_part.position = Vector3(0, 0.45 - t * 0.15, -0.25 + t * 0.35)

		var mat = StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mane_part.material_override = mat
		add_child(mane_part)

func _build_equine_tail(colors: Array):
	# Flowing tail at the back — cylinder segments
	_tail_node = Node3D.new()
	_tail_node.position = Vector3(0, -0.05, 0.45)
	_tail_node.name = "EquineTail"

	var segment_count = 5
	for i in range(segment_count):
		var seg = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.03 - i * 0.003
		cyl.bottom_radius = 0.04 - i * 0.004
		cyl.height = 0.15
		seg.mesh = cyl

		var t = float(i) / float(segment_count - 1)
		seg.position = Vector3(0, -i * 0.08, i * 0.06)
		seg.rotation.x = PI / 4 + t * 0.3

		var mat = StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		seg.material_override = mat
		_tail_node.add_child(seg)

	# Tail tip tuft
	var tip = MeshInstance3D.new()
	var tip_mesh = SphereMesh.new()
	tip_mesh.radius = 0.05
	tip_mesh.height = 0.08
	tip.mesh = tip_mesh
	tip.position = Vector3(0, -segment_count * 0.08, segment_count * 0.06)

	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = colors[(segment_count) % colors.size()]
	tip.material_override = tip_mat
	_tail_node.add_child(tip)

	add_child(_tail_node)

func _build_pegasus_wings():
	for side in [-1.0, 1.0]:
		var wing = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.5, 0.04, 0.3)
		wing.mesh = box
		wing.position = Vector3(side * 0.55, 0.2, 0.0)
		wing.rotation.z = side * -0.3

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.6, 0.75)  # pink wings
		wing.material_override = mat

		if side < 0:
			wing.name = "Wing_L"
			_wing_l = wing
		else:
			wing.name = "Wing_R"
			_wing_r = wing
		add_child(wing)

func _build_dragon_features():
	# Dragon wings (larger, bat-like, darker)
	for side in [-1.0, 1.0]:
		var wing = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.65, 0.04, 0.45)
		wing.mesh = box
		wing.position = Vector3(side * 0.6, 0.15, 0.0)
		wing.rotation.z = side * -0.4

		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_pet_color().darkened(0.3)
		wing.material_override = mat

		if side < 0:
			wing.name = "Wing_L"
			_wing_l = wing
		else:
			wing.name = "Wing_R"
			_wing_r = wing
		add_child(wing)

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

	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = _get_pet_color().darkened(0.2)
	tail.material_override = tail_mat
	add_child(tail)

	# Tail spike (diamond shape at end)
	var tail_spike = MeshInstance3D.new()
	var spike_mesh = CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.08
	spike_mesh.height = 0.12
	tail_spike.mesh = spike_mesh
	tail_spike.position = Vector3(0, 0.3, 0.7)
	var spike_mat = StandardMaterial3D.new()
	spike_mat.albedo_color = _get_pet_color().darkened(0.35)
	tail_spike.material_override = spike_mat
	add_child(tail_spike)

	# Spines along back
	for i in range(4):
		var spine = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.06
		cone.height = 0.2
		spine.mesh = cone
		spine.position = Vector3(0, 0.38, -0.15 + i * 0.18)

		var smat = StandardMaterial3D.new()
		smat.albedo_color = _get_pet_color().darkened(0.15)
		spine.material_override = smat
		add_child(spine)

	# Dragon horns (two small curved horns on head)
	for side in [-1.0, 1.0]:
		var dhorn = MeshInstance3D.new()
		var dcone = CylinderMesh.new()
		dcone.top_radius = 0.0
		dcone.bottom_radius = 0.04
		dcone.height = 0.18
		dhorn.mesh = dcone
		dhorn.position = Vector3(side * 0.12, 0.55, -0.35)
		dhorn.rotation.z = side * 0.3

		var dhmat = StandardMaterial3D.new()
		dhmat.albedo_color = Color(0.3, 0.3, 0.3)
		dhorn.material_override = dhmat
		add_child(dhorn)

	# Snout / muzzle
	var snout = MeshInstance3D.new()
	var snout_mesh = SphereMesh.new()
	snout_mesh.radius = 0.08
	snout_mesh.height = 0.1
	snout.mesh = snout_mesh
	snout.position = Vector3(0, 0.32, -0.58)

	var snout_mat = StandardMaterial3D.new()
	snout_mat.albedo_color = _get_pet_color().darkened(0.1)
	snout.material_override = snout_mat
	add_child(snout)

func _build_alicorn_features():
	# Wings + horn (horn already built above)
	for side in [-1.0, 1.0]:
		var wing = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.7, 0.05, 0.35)
		wing.mesh = box
		wing.position = Vector3(side * 0.65, 0.2, 0.0)
		wing.rotation.z = side * -0.3

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.6, 0.95)
		wing.material_override = mat

		wing.name = "Wing_" + ("L" if side < 0 else "R")
		if side < 0:
			_wing_l = wing
		else:
			_wing_r = wing
		add_child(wing)

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

func _build_dog_features():
	# Floppy ears
	for side in [-1.0, 1.0]:
		var ear = MeshInstance3D.new()
		var ear_mesh = SphereMesh.new()
		ear_mesh.radius = 0.1
		ear_mesh.height = 0.15
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.2, 0.25, -0.4)
		ear.rotation.z = side * 0.5  # drooping outward
		ear.scale = Vector3(0.6, 1.0, 0.8)

		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_pet_color().darkened(0.15)
		ear.material_override = mat

		if side < 0:
			_ear_l = ear
		else:
			_ear_r = ear
		add_child(ear)

	# Short wagging tail
	_tail_node = Node3D.new()
	_tail_node.position = Vector3(0, 0.05, 0.45)
	_tail_node.name = "DogTail"

	var tail_mesh_inst = MeshInstance3D.new()
	var tail_cyl = CylinderMesh.new()
	tail_cyl.top_radius = 0.03
	tail_cyl.bottom_radius = 0.06
	tail_cyl.height = 0.25
	tail_mesh_inst.mesh = tail_cyl
	tail_mesh_inst.rotation.x = -PI / 4  # angled upward

	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = _get_pet_color().darkened(0.1)
	tail_mesh_inst.material_override = tail_mat
	_tail_node.add_child(tail_mesh_inst)
	add_child(_tail_node)

	# Snout
	var snout = MeshInstance3D.new()
	var snout_mesh = SphereMesh.new()
	snout_mesh.radius = 0.1
	snout_mesh.height = 0.12
	snout.mesh = snout_mesh
	snout.position = Vector3(0, 0.28, -0.58)

	var snout_mat = StandardMaterial3D.new()
	snout_mat.albedo_color = _get_pet_color().lightened(0.1)
	snout.material_override = snout_mat
	add_child(snout)

	# Nose tip
	var nose = MeshInstance3D.new()
	var nose_mesh = SphereMesh.new()
	nose_mesh.radius = 0.04
	nose_mesh.height = 0.06
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 0.3, -0.65)

	var nose_mat = StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.15, 0.1, 0.1)
	nose.material_override = nose_mat
	add_child(nose)

func _build_cat_features():
	# Pointed ears
	for side in [-1.0, 1.0]:
		var ear = MeshInstance3D.new()
		var ear_mesh = CylinderMesh.new()
		ear_mesh.top_radius = 0.0
		ear_mesh.bottom_radius = 0.07
		ear_mesh.height = 0.15
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.13, 0.55, -0.38)
		ear.rotation.z = side * -0.2

		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_pet_color().darkened(0.1)
		ear.material_override = mat

		if side < 0:
			_ear_l = ear
		else:
			_ear_r = ear
		add_child(ear)

	# Long curving tail
	_tail_node = Node3D.new()
	_tail_node.position = Vector3(0, 0.0, 0.5)
	_tail_node.name = "CatTail"

	var tail_base = MeshInstance3D.new()
	var tail_cyl = CylinderMesh.new()
	tail_cyl.top_radius = 0.025
	tail_cyl.bottom_radius = 0.05
	tail_cyl.height = 0.5
	tail_base.mesh = tail_cyl
	tail_base.rotation.x = PI / 3
	tail_base.position.y = 0.15

	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = _get_pet_color().darkened(0.15)
	tail_base.material_override = tail_mat
	_tail_node.add_child(tail_base)

	# Tail tip
	var tip = MeshInstance3D.new()
	var tip_mesh = SphereMesh.new()
	tip_mesh.radius = 0.035
	tip_mesh.height = 0.06
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.4, 0.15)

	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = _get_pet_color().darkened(0.2)
	tip.material_override = tip_mat
	_tail_node.add_child(tip)
	add_child(_tail_node)

	# Whiskers (4 thin horizontal cylinders)
	for side in [-1.0, 1.0]:
		for offset in [-0.03, 0.03]:
			var whisker = MeshInstance3D.new()
			var w_mesh = CylinderMesh.new()
			w_mesh.top_radius = 0.003
			w_mesh.bottom_radius = 0.003
			w_mesh.height = 0.15
			whisker.mesh = w_mesh
			whisker.position = Vector3(side * 0.15, 0.33 + offset, -0.52)
			whisker.rotation.z = PI / 2
			whisker.rotation.y = side * 0.3

			var w_mat = StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.9, 0.9, 0.9)
			whisker.material_override = w_mat
			add_child(whisker)

func _build_koala():
	var koala_root = Node3D.new()
	koala_root.position = Vector3(0, 0.55, 0.05)
	koala_root.name = "Koala"

	# Body — larger and warm brown
	var body = MeshInstance3D.new()
	var body_mesh = SphereMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.3
	body.mesh = body_mesh
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.5, 0.4, 0.3)  # warm brown
	body.material_override = bmat
	koala_root.add_child(body)

	# Head — lighter tan
	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.24
	head.mesh = head_mesh
	head.position = Vector3(0, 0.25, -0.06)
	var hmat = StandardMaterial3D.new()
	hmat.albedo_color = Color(0.65, 0.55, 0.4)  # lighter tan
	head.material_override = hmat
	koala_root.add_child(head)

	# Round fluffy ears — distinctive dark with pink inner
	for side in [-1.0, 1.0]:
		# Outer ear (dark brown)
		var ear = MeshInstance3D.new()
		var ear_mesh = SphereMesh.new()
		ear_mesh.radius = 0.09
		ear_mesh.height = 0.1
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.12, 0.35, -0.06)
		var emat = StandardMaterial3D.new()
		emat.albedo_color = Color(0.35, 0.25, 0.18)
		ear.material_override = emat
		koala_root.add_child(ear)
		# Inner ear (pink)
		var inner_ear = MeshInstance3D.new()
		var ie_mesh = SphereMesh.new()
		ie_mesh.radius = 0.05
		ie_mesh.height = 0.06
		inner_ear.mesh = ie_mesh
		inner_ear.position = Vector3(side * 0.12, 0.35, -0.1)
		var ie_mat = StandardMaterial3D.new()
		ie_mat.albedo_color = Color(0.9, 0.6, 0.6)  # pink
		inner_ear.material_override = ie_mat
		koala_root.add_child(inner_ear)

	# Eyes — shiny black
	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.04
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.06, 0.28, -0.18)
		var eyemat = StandardMaterial3D.new()
		eyemat.albedo_color = Color(0.05, 0.05, 0.05)
		eyemat.metallic = 0.3
		eye.material_override = eyemat
		koala_root.add_child(eye)

	# Big round nose — signature koala feature
	var nose = MeshInstance3D.new()
	var nose_mesh = SphereMesh.new()
	nose_mesh.radius = 0.045
	nose_mesh.height = 0.04
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 0.22, -0.2)
	var nmat = StandardMaterial3D.new()
	nmat.albedo_color = Color(0.1, 0.08, 0.08)
	nose.material_override = nmat
	koala_root.add_child(nose)

	add_child(koala_root)

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
	var level = _game_manager.get_level(pet_id)
	_label3d.text = "%s Lv%d %s" % [pet_name, level, emoji]

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

	# Wing flapping — pegasus, dragon, alicorn all have wings
	if _wing_l and _wing_r:
		match pet_type:
			"pegasus":
				var flap = sin(_bob_time * 4.0) * 0.15
				_wing_l.rotation.z = 0.3 + flap
				_wing_r.rotation.z = -0.3 - flap
			"dragon":
				var flap = sin(_bob_time * 2.5) * 0.2  # slower, more powerful
				_wing_l.rotation.z = 0.4 + flap
				_wing_r.rotation.z = -0.4 - flap
			"alicorn":
				var flap = sin(_bob_time * 3.5) * 0.15
				_wing_l.rotation.z = 0.3 + flap
				_wing_r.rotation.z = -0.3 - flap

	# Dragon tail sway
	if pet_type == "dragon":
		var tail_node = get_node_or_null("Tail")
		if tail_node:
			tail_node.rotation.y = sin(_bob_time * 1.5) * 0.3

	# Dog tail wag (fast side-to-side)
	if pet_type == "dogicorn" and _tail_node:
		_tail_node.rotation.y = sin(_bob_time * 8.0) * 0.4

	# Cat tail swish (slow, elegant)
	if pet_type == "caticorn" and _tail_node:
		_tail_node.rotation.y = sin(_bob_time * 1.2) * 0.5
		_tail_node.rotation.x = sin(_bob_time * 0.8) * 0.1

	# Equine tail sway (unicorn, pegasus, alicorn)
	if pet_type in ["unicorn", "pegasus", "alicorn"] and _tail_node:
		_tail_node.rotation.y = sin(_bob_time * 1.5) * 0.3

	# Iridescent color cycle for alicorn with variant 2
	if pet_type == "alicorn" and _body_mesh and _body_mesh.material_override:
		var info = _game_manager.get_pet_info(pet_id)
		if info and info["color_variant"] == 2:
			_iridescent_time += delta
			var r = (sin(_iridescent_time * 1.0) + 1.0) / 2.0
			var g = (sin(_iridescent_time * 1.3 + 2.0) + 1.0) / 2.0
			var b = (sin(_iridescent_time * 1.7 + 4.0) + 1.0) / 2.0
			_body_mesh.material_override.albedo_color = Color(r, g, b)

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

func _on_pet_leveled_up(leveled_pet_id: int, _new_level: int):
	if leveled_pet_id != pet_id:
		return
	do_level_up_reaction()

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

func do_level_up_reaction():
	# Bigger bounce + flash
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.2)
	tween.tween_property(self, "scale", Vector3(0.9, 0.9, 0.9), 0.1)
	tween.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.1)

	# Show "LEVEL UP!" text briefly
	var level_label = Label3D.new()
	level_label.text = "LEVEL UP!"
	level_label.font_size = 64
	level_label.position.y = 1.8
	level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_label.no_depth_test = true
	level_label.modulate = Color.GOLD
	add_child(level_label)

	var label_tween = create_tween()
	label_tween.tween_property(level_label, "position:y", 2.5, 1.5)
	label_tween.parallel().tween_property(level_label, "modulate:a", 0.0, 1.5)
	label_tween.tween_callback(level_label.queue_free)

func _get_pet_color() -> Color:
	if _game_manager:
		return _game_manager.get_pet_color(pet_id)
	match pet_type:
		"unicorn":
			return Color.WHITE
		"pegasus":
			return Color.LIGHT_GRAY
		"dragon":
			return Color(0.0, 0.6, 0.0)
		"alicorn":
			return Color(0.6, 0.2, 0.8)
		"dogicorn":
			return Color(0.72, 0.53, 0.34)
		"caticorn":
			return Color(0.95, 0.6, 0.2)
		_:
			return Color.WHITE
