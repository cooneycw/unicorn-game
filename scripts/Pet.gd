extends Node3D

# Pet visual representation in 3D — reads all stats from GameManager
class_name Pet

var pet_id: int
var pet_name: String
var pet_type: String  # "unicorn", "pegasus", "dragon", "alicorn"

var _game_manager
var _base_y: float = 0.0
var _bob_time: float = 0.0
var _label3d: Label3D
var _body_mesh: MeshInstance3D
var _iridescent_time: float = 0.0

func _ready():
	_game_manager = get_tree().root.get_node("GameManager")
	_base_y = position.y

	_build_body()
	_build_legs()
	_build_horn()
	_build_type_features()
	_build_label()

	_game_manager.pet_leveled_up.connect(_on_pet_leveled_up)

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
	if pet_type == "dragon":
		return
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
		"alicorn":
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
				add_child(wing)

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
	var level = _game_manager.get_level(pet_id)
	_label3d.text = "%s Lv%d %s" % [pet_name, level, emoji]

func _process(delta: float):
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

	# Iridescent color cycle for alicorn with variant 2
	if pet_type == "alicorn" and _body_mesh and _body_mesh.material_override:
		var info = _game_manager.get_pet_info(pet_id)
		if info and info["color_variant"] == 2:
			_iridescent_time += delta
			var r = (sin(_iridescent_time * 1.0) + 1.0) / 2.0
			var g = (sin(_iridescent_time * 1.3 + 2.0) + 1.0) / 2.0
			var b = (sin(_iridescent_time * 1.7 + 4.0) + 1.0) / 2.0
			_body_mesh.material_override.albedo_color = Color(r, g, b)

	_update_label()

func _on_pet_leveled_up(leveled_pet_id: int, _new_level: int):
	if leveled_pet_id != pet_id:
		return
	do_level_up_reaction()

func do_happy_reaction():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.15)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

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
			return Color.RED
		"alicorn":
			return Color(0.6, 0.2, 0.8)
		_:
			return Color.WHITE
