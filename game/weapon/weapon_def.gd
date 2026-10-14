class_name WeaponDef
extends Resource

## The identity for "the player has this weapon". Code compares weapons by id, never by object.
@export var id: StringName = &""
@export var display_name: String = ""
## For each pellet.
@export_range(0.0, 1000.0, 0.5) var damage: float = 0.0
@export_range(1, 20, 1) var pellets: int = 1
@export_range(0.01, 5.0, 0.01, "suffix:s") var fire_interval: float = 0.1
## True: hold the trigger to fire.
@export var automatic: bool = false
@export_range(1, 200, 1) var magazine_size: int = 1
@export_range(0, 1000, 1) var reserve_max: int = 0
@export_range(0.0, 10.0, 0.05, "suffix:s") var reload_seconds: float = 1.0
@export_range(1.0, 500.0, 1.0, "suffix:m") var range: float = 100.0
@export_range(0.0, 20.0, 0.1, "suffix:°") var spread_degrees: float = 0.0
## Boxes of the view model, in view model space. The barrel points to -Z.
var parts: Array[WeaponDef.Part] = []
## Where the muzzle flash shows, in view model space.
var muzzle: Vector3 = Vector3.ZERO


class Part:
	var size: Vector3
	var at: Vector3
	var color: Color

	func _init(part_size: Vector3, part_at: Vector3, part_color: Color) -> void:
		size = part_size
		at = part_at
		color = part_color


## A tint with an alpha above 0 draws all parts in that one flat color, as chalk on a wall buy.
func build_model(scale: float, tint: Color = Color.TRANSPARENT) -> Node3D:
	var model: Node3D = Node3D.new()
	for part: WeaponDef.Part in parts:
		var box: BoxMesh = BoxMesh.new()
		box.size = part.size * scale
		var material: StandardMaterial3D = StandardMaterial3D.new()
		if tint.a > 0.0:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = tint
		else:
			material.albedo_color = part.color
			material.roughness = 0.5
			material.metallic = 0.6
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = part.at * scale
		model.add_child(mesh)
	return model
