@abstract
class_name Station
extends Area3D
## A thing that the player buys from. Game reads the offer, takes the points, and then lets the station apply it.


class Offer:
	enum Kind { NONE, WEAPON, AMMO, BOX_ROLL, BOX_TAKE }

	var kind: Kind
	## 0 for NONE and BOX_TAKE.
	var cost: int
	## The prompt text. "" for no prompt.
	var label: String
	## Set for WEAPON, AMMO, and BOX_TAKE.
	var weapon: WeaponDef

	func _init(offer_kind: Kind, offer_cost: int, offer_label: String, offer_weapon: WeaponDef = null) -> void:
		kind = offer_kind
		cost = offer_cost
		label = offer_label
		weapon = offer_weapon


## Only the interact ray finds a station. It does not collide with bodies.
func _init() -> void:
	collision_layer = Layers.INTERACT
	collision_mask = 0
	monitoring = false


## Changes nothing.
@abstract func offer(loadout: Loadout) -> Station.Offer


## Game calls it after the spend of offer.cost succeeds.
@abstract func accept(chosen: Station.Offer, weapon: Weapon) -> void
