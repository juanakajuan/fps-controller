class_name WallBuy
extends Station
## One weapon at one price on a wall. Its origin is on the wall face, and its +Z axis points out of the wall.

const PANEL_SIZE: Vector3 = Vector3(2.6, 1.0, 0.04)
const PANEL_COLOR: Color = Color(0.07, 0.08, 0.08)
const CHALK_COLOR: Color = Color(0.88, 0.87, 0.8)
const DRAWING_SCALE: float = 3.0
## The interact area stands out from the wall, so the ray finds it before the wall.
const AREA_DEPTH: float = 0.3

var weapon_def: WeaponDef
var price: int


func _init(weapon: WeaponDef, weapon_price: int) -> void:
	super()
	weapon_def = weapon
	price = weapon_price


func _ready() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(PANEL_SIZE.x, PANEL_SIZE.y, AREA_DEPTH)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.0, AREA_DEPTH * 0.5)
	add_child(collision)
	var panel_mesh: BoxMesh = BoxMesh.new()
	panel_mesh.size = PANEL_SIZE
	var panel_material: StandardMaterial3D = StandardMaterial3D.new()
	panel_material.albedo_color = PANEL_COLOR
	panel_material.roughness = 1.0
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.mesh = panel_mesh
	panel.material_override = panel_material
	panel.position = Vector3(0.0, 0.0, -PANEL_SIZE.z * 0.5)
	add_child(panel)
	add_child(_drawing())
	var caption: Label3D = Label3D.new()
	caption.text = "%s  %d" % [weapon_def.display_name, price]
	caption.modulate = CHALK_COLOR
	caption.outline_size = 0
	caption.pixel_size = 0.004
	caption.font_size = 48
	caption.position = Vector3(0.0, -PANEL_SIZE.y * 0.5 + 0.12, 0.01)
	add_child(caption)


func offer(loadout: Loadout) -> Station.Offer:
	var owned: Loadout.Slot = loadout.find(weapon_def.id)
	if owned == null:
		return Station.Offer.new(Station.Offer.Kind.WEAPON, price, "Buy %s" % weapon_def.display_name, weapon_def)
	if not owned.is_full():
		return Station.Offer.new(Station.Offer.Kind.AMMO, Rules.ammo_price(price), "Buy %s ammo" % weapon_def.display_name, weapon_def)
	return Station.Offer.new(Station.Offer.Kind.NONE, 0, "%s ammo full" % weapon_def.display_name)


func accept(chosen: Station.Offer, weapon: Weapon) -> void:
	match chosen.kind:
		Station.Offer.Kind.WEAPON:
			weapon.equip(weapon_def)
		Station.Offer.Kind.AMMO:
			weapon.fill(weapon_def.id)


## The weapon parts in profile, the barrel to the left, centered on the panel.
func _drawing() -> Node3D:
	var bounds: AABB = AABB()
	for index: int in range(weapon_def.parts.size()):
		var part: WeaponDef.Part = weapon_def.parts[index]
		var box: AABB = AABB(part.at - part.size * 0.5, part.size)
		bounds = box if index == 0 else bounds.merge(box)
	var drawing: Node3D = weapon_def.build_model(DRAWING_SCALE, CHALK_COLOR)
	drawing.basis = Basis(Vector3.UP, PI * 0.5)
	drawing.position = Vector3(0.0, 0.06, bounds.size.x * DRAWING_SCALE * 0.5 + 0.01) - drawing.basis * (bounds.get_center() * DRAWING_SCALE)
	return drawing
