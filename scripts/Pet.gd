extends Node3D

# Pet visual representation in 3D — reads all stats from GameManager
class_name Pet

var pet_id: int
var pet_name: String
var pet_type: String  # "unicorn", "pegasus", "dragon"

var _game_manager
var _base_y: float = 0.0
var _bob_time: float = 0.0
var _label3d: Label3D
var _body_mesh: MeshInstance3D

func _ready():
	_game_manager = get_tree().root.get_node("GameManager")
	_base_y = position.y

	_build_body()
	_build_legs()
	_build_horn()
	_build_type_features()
	_build_label()

	# Randomize bob phase so pets don't all bob in sync
	_bob_time = randf() * TAU

func _build_body():
	_body_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	_body_mesh.mesh = sphere_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = _get_pet_color()
	_body_mesh.material_override = material

	add_child(_body_mesh)

func _build_legs():
	var leg_positions = [
		Vector3(-0.25, -0.5, -0.15),
		Vector3(0.25, -0.5, -0.15),
		Vector3(-0.25, -0.5, 0.15),
		Vector3(0.25, -0.5, 0.15),
	]
	for pos in leg_positions:
		var leg = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = 0.35
		leg.mesh = cyl
		leg.position = pos

		var mat = StandardMaterial3D.new()
		mat.albedo_color = _get_pet_color().darkened(0.1)
		leg.material_override = mat

		add_child(leg)

func _build_horn():
	# All pet types get a horn on the head (repositioned to head height)
	if pet_type == "dragon":
		return  # dragons don't have horns
	var horn = MeshInstance3D.new()
	var cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.1
	cone_mesh.height = 0.5
	horn.mesh = cone_mesh
	horn.position.y = 0.75

	var horn_material = StandardMaterial3D.new()
	horn_material.albedo_color = Color.YELLOW
	horn.material_override = horn_material

	add_child(horn)

func _build_type_features():
	match pet_type:
		"pegasus":
			# Wing boxes on each side
			for side in [-1.0, 1.0]:
				var wing = MeshInstance3D.new()
				var box = BoxMesh.new()
				box.size = Vector3(0.6, 0.05, 0.3)
				wing.mesh = box
				wing.position = Vector3(side * 0.65, 0.15, 0.0)
				wing.rotation.z = side * -0.3

				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.85, 0.85, 0.95)
				wing.material_override = mat

				wing.name = "Wing_" + ("L" if side < 0 else "R")
				add_child(wing)
		"dragon":
			# Tail cylinder behind
			var tail = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.12
			cyl.height = 0.6
			tail.mesh = cyl
			tail.position = Vector3(0, 0.0, 0.5)
			tail.rotation.x = PI / 3

			var mat = StandardMaterial3D.new()
			mat.albedo_color = _get_pet_color().darkened(0.2)
			tail.material_override = mat

			add_child(tail)

func _build_label():
	_label3d = Label3D.new()
	_label3d.position.y = 1.1
	_label3d.font_size = 48
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.no_depth_test = true
	_update_label()
	add_child(_label3d)

func _update_label():
	if _label3d == null or _game_manager == null:
		return
	var emoji = _game_manager.get_mood_emoji(pet_id)
	_label3d.text = pet_name + " " + emoji

func _process(delta: float):
	# Bobbing animation
	_bob_time += delta
	var mood = "content"
	if _game_manager:
		mood = _game_manager.get_pet_mood(pet_id)

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

	_update_label()

func do_happy_reaction():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.15)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

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
