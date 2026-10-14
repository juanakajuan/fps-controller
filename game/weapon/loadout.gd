class_name Loadout
extends RefCounted

## 1 or 2 slots, never empty.
var slots: Array[Loadout.Slot] = []
var active: int = 0


class Slot:
	var def: WeaponDef
	var magazine: int = 0
	var reserve: int = 0

	func _init(weapon: WeaponDef) -> void:
		def = weapon
		fill()

	func fill() -> void:
		magazine = def.magazine_size
		reserve = def.reserve_max

	func is_full() -> bool:
		return magazine == def.magazine_size and reserve == def.reserve_max


func _init(first: WeaponDef) -> void:
	slots.append(Loadout.Slot.new(first))


func current() -> Loadout.Slot:
	return slots[active]


## Null if the player does not have the weapon.
func find(id: StringName) -> Loadout.Slot:
	for slot: Loadout.Slot in slots:
		if slot.def.id == id:
			return slot
	return null


## Only the empty-slot case adds a slot, so there are never more than LOADOUT_SIZE slots.
func give(weapon: WeaponDef) -> void:
	var owned: Loadout.Slot = find(weapon.id)
	if owned != null:
		owned.fill()
		active = slots.find(owned)
	elif slots.size() < Rules.LOADOUT_SIZE:
		slots.append(Loadout.Slot.new(weapon))
		active = slots.size() - 1
	else:
		slots[active] = Loadout.Slot.new(weapon)


## False and no change with one slot.
func cycle() -> bool:
	if slots.size() < 2:
		return false
	active = (active + 1) % slots.size()
	return true
