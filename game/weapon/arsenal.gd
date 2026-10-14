class_name Arsenal

const METAL: Color = Color(0.16, 0.17, 0.19)
const WOOD: Color = Color(0.32, 0.22, 0.14)
const POLYMER: Color = Color(0.09, 0.09, 0.1)
const OLIVE: Color = Color(0.25, 0.28, 0.18)


static func pistol() -> WeaponDef:
	var weapon: WeaponDef = _weapon(&"pistol", "Pistol", 35.0, 1, 0.15, false, 8, 80, 1.4, 100.0, 1.0)
	weapon.parts = [
		WeaponDef.Part.new(Vector3(0.035, 0.045, 0.17), Vector3(0.0, 0.0, -0.03), METAL),
		WeaponDef.Part.new(Vector3(0.032, 0.09, 0.045), Vector3(0.0, -0.06, 0.03), WOOD),
		WeaponDef.Part.new(Vector3(0.008, 0.014, 0.008), Vector3(0.0, 0.029, -0.1), METAL),
	]
	weapon.muzzle = Vector3(0.0, 0.0, -0.14)
	return weapon


static func smg() -> WeaponDef:
	var weapon: WeaponDef = _weapon(&"smg", "SMG", 30.0, 1, 0.075, true, 30, 150, 2.0, 60.0, 3.0)
	weapon.parts = [
		WeaponDef.Part.new(Vector3(0.045, 0.06, 0.28), Vector3(0.0, 0.0, -0.06), METAL),
		WeaponDef.Part.new(Vector3(0.02, 0.02, 0.1), Vector3(0.0, 0.01, -0.25), METAL),
		WeaponDef.Part.new(Vector3(0.032, 0.09, 0.04), Vector3(0.0, -0.07, 0.03), POLYMER),
		WeaponDef.Part.new(Vector3(0.025, 0.13, 0.035), Vector3(0.0, -0.09, -0.1), METAL),
		WeaponDef.Part.new(Vector3(0.03, 0.04, 0.14), Vector3(0.0, -0.01, 0.15), POLYMER),
	]
	weapon.muzzle = Vector3(0.0, 0.01, -0.31)
	return weapon


static func shotgun() -> WeaponDef:
	var weapon: WeaponDef = _weapon(&"shotgun", "Shotgun", 25.0, 8, 0.8, false, 6, 42, 3.0, 20.0, 6.0)
	weapon.parts = [
		WeaponDef.Part.new(Vector3(0.03, 0.03, 0.5), Vector3(0.0, 0.02, -0.25), METAL),
		WeaponDef.Part.new(Vector3(0.04, 0.035, 0.14), Vector3(0.0, -0.02, -0.3), WOOD),
		WeaponDef.Part.new(Vector3(0.045, 0.065, 0.16), Vector3(0.0, 0.0, 0.0), METAL),
		WeaponDef.Part.new(Vector3(0.04, 0.07, 0.22), Vector3(0.0, -0.04, 0.18), WOOD),
	]
	weapon.muzzle = Vector3(0.0, 0.02, -0.5)
	return weapon


static func rifle() -> WeaponDef:
	var weapon: WeaponDef = _weapon(&"rifle", "Rifle", 80.0, 1, 0.25, false, 15, 90, 2.2, 150.0, 0.5)
	weapon.parts = [
		WeaponDef.Part.new(Vector3(0.04, 0.06, 0.3), Vector3(0.0, 0.0, -0.05), METAL),
		WeaponDef.Part.new(Vector3(0.02, 0.02, 0.24), Vector3(0.0, 0.01, -0.32), METAL),
		WeaponDef.Part.new(Vector3(0.042, 0.045, 0.16), Vector3(0.0, 0.0, -0.26), OLIVE),
		WeaponDef.Part.new(Vector3(0.025, 0.12, 0.04), Vector3(0.0, -0.08, -0.08), METAL),
		WeaponDef.Part.new(Vector3(0.03, 0.08, 0.035), Vector3(0.0, -0.06, 0.05), POLYMER),
		WeaponDef.Part.new(Vector3(0.035, 0.07, 0.18), Vector3(0.0, -0.01, 0.19), OLIVE),
		WeaponDef.Part.new(Vector3(0.01, 0.03, 0.01), Vector3(0.0, 0.045, -0.38), METAL),
	]
	weapon.muzzle = Vector3(0.0, 0.01, -0.44)
	return weapon


static func lmg() -> WeaponDef:
	var weapon: WeaponDef = _weapon(&"lmg", "LMG", 55.0, 1, 0.1, true, 75, 300, 4.5, 120.0, 2.5)
	weapon.parts = [
		WeaponDef.Part.new(Vector3(0.06, 0.08, 0.34), Vector3(0.0, 0.0, -0.04), METAL),
		WeaponDef.Part.new(Vector3(0.025, 0.025, 0.3), Vector3(0.0, 0.01, -0.36), METAL),
		WeaponDef.Part.new(Vector3(0.07, 0.1, 0.09), Vector3(0.0, -0.09, -0.05), OLIVE),
		WeaponDef.Part.new(Vector3(0.032, 0.09, 0.04), Vector3(0.0, -0.07, 0.08), POLYMER),
		WeaponDef.Part.new(Vector3(0.04, 0.08, 0.2), Vector3(0.0, -0.01, 0.23), POLYMER),
		WeaponDef.Part.new(Vector3(0.015, 0.03, 0.12), Vector3(0.0, 0.055, -0.06), METAL),
	]
	weapon.muzzle = Vector3(0.0, 0.01, -0.51)
	return weapon


static func marksman() -> WeaponDef:
	var weapon: WeaponDef = _weapon(&"marksman", "Marksman", 250.0, 1, 0.9, false, 5, 40, 3.0, 300.0, 0.0)
	weapon.parts = [
		WeaponDef.Part.new(Vector3(0.04, 0.055, 0.3), Vector3(0.0, 0.0, -0.02), METAL),
		WeaponDef.Part.new(Vector3(0.022, 0.022, 0.36), Vector3(0.0, 0.01, -0.35), METAL),
		WeaponDef.Part.new(Vector3(0.04, 0.04, 0.2), Vector3(0.0, 0.07, -0.04), POLYMER),
		WeaponDef.Part.new(Vector3(0.025, 0.07, 0.04), Vector3(0.0, -0.06, -0.06), METAL),
		WeaponDef.Part.new(Vector3(0.03, 0.08, 0.035), Vector3(0.0, -0.06, 0.06), WOOD),
		WeaponDef.Part.new(Vector3(0.04, 0.08, 0.22), Vector3(0.0, -0.02, 0.23), WOOD),
	]
	weapon.muzzle = Vector3(0.0, 0.01, -0.53)
	return weapon


## The pistol is not in the pool. The player has at most two weapons, so at least three are left at each roll.
static func box_pool() -> Array[WeaponDef]:
	return [smg(), shotgun(), rifle(), lmg(), marksman()]


static func _weapon(id: StringName, display_name: String, damage: float, pellets: int, fire_interval: float, automatic: bool, magazine_size: int, reserve_max: int, reload_seconds: float, weapon_range: float, spread_degrees: float) -> WeaponDef:
	var weapon: WeaponDef = WeaponDef.new()
	weapon.id = id
	weapon.display_name = display_name
	weapon.damage = damage
	weapon.pellets = pellets
	weapon.fire_interval = fire_interval
	weapon.automatic = automatic
	weapon.magazine_size = magazine_size
	weapon.reserve_max = reserve_max
	weapon.reload_seconds = reload_seconds
	weapon.range = weapon_range
	weapon.spread_degrees = spread_degrees
	return weapon
