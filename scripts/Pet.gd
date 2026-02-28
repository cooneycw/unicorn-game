extends Node3D

# Pet visual representation in 3D
class_name Pet

var pet_id: int
var pet_name: String
var pet_type: String  # "unicorn", "pegasus", "dragon"
var health: int = 100
var happiness: int = 100

func _ready():
	# Create a simple 3D pet model
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_instance.mesh = sphere_mesh

	# Add a material
	var material = StandardMaterial3D.new()
	material.albedo_color = _get_pet_color()
	mesh_instance.material_override = material

	add_child(mesh_instance)

	# Add a simple horn (cone)
	var horn = MeshInstance3D.new()
	var cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.1
	cone_mesh.height = 0.5
	horn.mesh = cone_mesh
	horn.position.y = 0.7

	var horn_material = StandardMaterial3D.new()
	horn_material.albedo_color = Color.YELLOW
	horn.material_override = horn_material

	add_child(horn)

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

func take_damage(amount: int):
	health = max(0, health - amount)

func heal(amount: int):
	health = min(100, health + amount)

func increase_happiness(amount: int):
	happiness = min(100, happiness + amount)
