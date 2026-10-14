class_name WeaponDef
extends Resource

@export var display_name: String = ""
@export_range(0.0, 1000.0, 0.5) var damage: float = 0.0
@export_range(0.01, 5.0, 0.01, "suffix:s") var fire_interval: float = 0.1
## True: hold the trigger to fire.
@export var automatic: bool = false
@export_range(1, 200, 1) var magazine_size: int = 1
@export_range(0, 1000, 1) var reserve_max: int = 0
@export_range(0.0, 10.0, 0.05, "suffix:s") var reload_seconds: float = 1.0
@export_range(1.0, 500.0, 1.0, "suffix:m") var range: float = 100.0
@export_range(0.0, 20.0, 0.1, "suffix:°") var spread_degrees: float = 0.0


static func starting_pistol() -> WeaponDef:
	var pistol: WeaponDef = WeaponDef.new()
	pistol.display_name = "Pistol"
	pistol.damage = 35.0
	pistol.fire_interval = 0.15
	pistol.automatic = false
	pistol.magazine_size = 8
	pistol.reserve_max = 80
	pistol.reload_seconds = 1.4
	pistol.range = 100.0
	pistol.spread_degrees = 1.0
	return pistol
