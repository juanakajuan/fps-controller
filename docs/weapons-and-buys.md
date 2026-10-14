# Milestone 2 design: weapons and buys

## Goal

Points become a currency. The player spends them at three wall buys and at one random weapon box. The player carries up to two weapons and changes between them. Ammunition no longer comes back at the start of each round. The player buys it at the wall where the weapon hangs.

Milestone 2 does not add perks, the weapon upgrade machine, doors, power, power-ups, or a box that moves. Those belong to milestones 3 and 4, or to no milestone.

## Rules for the player

- You start with the pistol in slot 1 and an empty slot 2.
- To buy a weapon, look at its wall buy from 2.5 m or less, and press **E**. The HUD shows the prompt and the price. If you cannot pay, the prompt is gray and the press does nothing.
- If you have an empty slot, the new weapon goes there. If not, the new weapon replaces the weapon in your hands.
- At the wall buy of a weapon that you have, the press buys ammunition for half the price. It fills the magazine and the reserve of that weapon. If both are full, the prompt says so and the press does nothing.
- The box costs 950 points. It rolls for 4 seconds and then offers one weapon for 10 seconds. Press **E** to take the weapon. If you do not take it in 10 seconds, the weapon is gone and you do not get the points back. The box never offers a weapon that you had when the roll started.
- To change weapons, press **Q** or turn the mouse wheel. A change takes 0.5 seconds. A new weapon also takes 0.5 seconds to come up.
- No wall sells the pistol. When the pistol is empty and you cannot pay, the knife is the fallback. A knife kill earns 130 points.

## Weapons

`Arsenal` holds this table. The price belongs to the wall buy, not to the weapon. `Pellets` is a new `WeaponDef` field. The other columns are current `WeaponDef` fields.

| Weapon | Where | Price | Damage | Pellets | Interval | Automatic | Magazine | Reserve | Reload | Range | Spread |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Pistol | Start | | 35 | 1 | 0.15 s | No | 8 | 80 | 1.4 s | 100 m | 1.0° |
| SMG | North wall | 1000 | 30 | 1 | 0.075 s | Yes | 30 | 150 | 2.0 s | 60 m | 3.0° |
| Shotgun | East wall | 1200 | 25 | 8 | 0.8 s | No | 6 | 42 | 3.0 s | 20 m | 6.0° |
| Rifle | West wall | 1500 | 80 | 1 | 0.25 s | No | 15 | 90 | 2.2 s | 150 m | 0.5° |
| LMG | Box | | 55 | 1 | 0.1 s | Yes | 75 | 300 | 4.5 s | 120 m | 2.5° |
| Marksman | Box | | 250 | 1 | 0.9 s | No | 5 | 40 | 3.0 s | 300 m | 0.0° |

The box pool is the SMG, the shotgun, the rifle, the LMG, and the marksman. The pistol is not in the pool. The player has at most two weapons, so the pool has at least three weapons at each roll. The roll needs no check for an empty pool.

The shotgun reloads its full magazine at one time. A reload of one shell at a time needs a second reload state, and milestone 2 does not need it.

The implementer may change these values for game feel. Each change goes in the accepted deviations at the end of this document, and the tests assert the new literal values.

## Usage

```gdscript
# The player state for weapons is plain data. Tests use it with no scene tree:
var loadout: Loadout = Loadout.new(Arsenal.pistol())
loadout.give(Arsenal.smg())             # goes to the empty slot 2 and becomes active
loadout.current().magazine              # 30
loadout.find(&"pistol").reserve         # 80

# A station tells what a press buys. It does not change anything:
var wall: WallBuy = WallBuy.new(Arsenal.smg(), 1000)
var offer: Station.Offer = wall.offer(loadout)
offer.kind   # Station.Offer.Kind.AMMO
offer.cost   # 500
offer.label  # "Buy SMG ammo"

# Game takes the points and then lets the station act:
if points.spend(offer.cost):
	station.accept(offer, weapon)

# Tests drive the weapon and the game without the Input singleton:
game.weapon.switch_requested = true
game.interact()                         # the same call as a press of E
game.weapon.current().magazine
game.arena.box.advance(4.0)             # the box timers, without real time
```

## Candidates

The main choice is where the state of the two weapons lives.

| | A. One `Weapon` node for each weapon | B. One `Weapon` node and a `Loadout` of data |
|---|---|---|
| Shape | Each weapon that the player has is a `Weapon` node under the camera. The holstered node is hidden and does not process. A change shows the other node. | One `Weapon` node is the hands. It runs the one state machine. A `Loadout` holds up to two `Loadout.Slot` objects, each with a `WeaponDef`, a magazine, and a reserve. A change makes the other slot active and builds its view model. |
| Requests | `trigger_held`, `reload_requested`, and `melee_requested` must go to the active node. `Game` must connect and disconnect `hit` and `ammo_changed` at each change. | No change. `Game` connects the signals one time. |
| Buys | A buy creates or frees a node. An ammo buy must find the right node. | A buy calls `Loadout.give()`. An ammo buy calls `Slot.fill()`. Both are plain data, so the tests need no physics. |
| Melee and change | Each node has its own melee state, so a melee during a change needs rules across two nodes. | MELEE and SWITCHING are states of the same machine. |

Choice: **B**. Milestone 1 made a weapon data, not code, and B keeps that shape. One state machine decides what the hands can do at one time. The buy rules work on plain data and get exact tests with no scene tree.

Two smaller choices:

- **Targeting.** A station is in use when a ray from the camera hits it, not when the player is in an area near it. The melee already uses a camera ray. A look ray lets two stations stand near each other, and a wall between the player and a station blocks it.
- **The buy effect.** Each station applies its own offer in `accept()`. A single `match` in `Game` over all kinds needs a cast from `Station` to `MysteryBox` to roll the box. With `accept()`, `Game` only takes the points.

## Files

New files:

- `game/weapon/arsenal.gd`. `class_name Arsenal`. Static functions only. One function for each weapon in the table, and `box_pool()`.
- `game/weapon/loadout.gd`. `class_name Loadout extends RefCounted`. The slots and the active slot. Holds the inner class `Slot`.
- `game/station/station.gd`. `class_name Station extends Area3D`. The base of a thing that the player buys from. Holds the inner class `Offer`.
- `game/station/wall_buy.gd`. `class_name WallBuy extends Station`. One weapon at one price on a wall.
- `game/station/mystery_box.gd`. `class_name MysteryBox extends Station`. The random weapon box.

Changed files:

- `game/weapon/weapon_def.gd`. Adds `id`, `pellets`, `parts`, and `muzzle`. Removes `starting_pistol()`. `Arsenal.pistol()` replaces it.
- `game/weapon/weapon.gd`. Reads the active slot of a `Loadout`. Adds SWITCHING and pellets. Builds the view model from `WeaponDef.parts`. Removes `def`, `magazine`, `reserve`, and `refill()`.
- `game/game.gd`. Casts the interact ray, shows the prompt, and handles the `interact` and `switch_weapon` actions. Removes the `refill()` call on `round_started`.
- `game/level/arena.gd`. Builds the three wall buys and the box before the navigation bake.
- `game/layers.gd`. Adds `INTERACT`.
- `game/rules.gd`. Adds the constants for buys, the box, and the weapon change.
- `game/hud.gd`. Adds the weapon name and the prompt. Adds the new keys to the pause screen.
- `tests/test_runner.gd`. Uses `weapon.current()` in place of `weapon.magazine`, `weapon.reserve`, and `weapon.def`. Replaces the `refill()` test and the refill check of round 2. Adds the tests in the verification plan.

## Data shapes

```gdscript
# Added to Rules:
const LOADOUT_SIZE: int = 2
const INTERACT_RANGE: float = 2.5
const SWITCH_SECONDS: float = 0.5
const BOX_PRICE: int = 950
const BOX_ROLL_SECONDS: float = 4.0
const BOX_OFFER_SECONDS: float = 10.0

static func ammo_price(weapon_price: int) -> int   # weapon_price / 2, integer division
```

```gdscript
# Added to Layers:
const INTERACT: int = 8
```

```gdscript
class_name WeaponDef extends Resource

@export var id: StringName              # the identity for "the player has this weapon"
@export var display_name: String
@export var damage: float               # for each pellet
@export var pellets: int = 1
@export var fire_interval: float
@export var automatic: bool
@export var magazine_size: int
@export var reserve_max: int
@export var reload_seconds: float
@export var range: float
@export var spread_degrees: float
var parts: Array[WeaponDef.Part] = []   # boxes of the view model, in view model space
var muzzle: Vector3                     # where the flash shows

class Part:
	var size: Vector3
	var at: Vector3
	var color: Color
```

The view model is a list of boxes, as the pistol model is today. The wall buys draw the same parts at three times the size in one chalk color. Thus each weapon has one model, and a new weapon needs only a new `Arsenal` function.

```gdscript
class_name Arsenal

static func pistol() -> WeaponDef
static func smg() -> WeaponDef
static func shotgun() -> WeaponDef
static func rifle() -> WeaponDef
static func lmg() -> WeaponDef
static func marksman() -> WeaponDef
static func box_pool() -> Array[WeaponDef]   # smg, shotgun, rifle, lmg, marksman
```

Each call returns a new `WeaponDef`. Code compares weapons by `id`, never by object.

```gdscript
class_name Loadout extends RefCounted

class Slot:
	var def: WeaponDef
	var magazine: int
	var reserve: int
	func _init(weapon: WeaponDef) -> void   # magazine and reserve full
	func fill() -> void
	func is_full() -> bool

var slots: Array[Loadout.Slot] = []    # 1 or 2 slots, never empty
var active: int = 0

func _init(first: WeaponDef) -> void
func current() -> Loadout.Slot
func find(id: StringName) -> Loadout.Slot   # null if the player does not have it
func give(weapon: WeaponDef) -> void
func cycle() -> bool                         # false and no change with one slot
```

`give()` has three cases. If the player has the weapon, its slot is filled and becomes active. If a slot is empty, a new slot is added and becomes active. If not, the new slot replaces the active slot. The second case is the only one that adds a slot, so `slots.size()` is never more than `Rules.LOADOUT_SIZE`.

```gdscript
class_name Station extends Area3D

class Offer:
	enum Kind { NONE, WEAPON, AMMO, BOX_ROLL, BOX_TAKE }
	var kind: Kind
	var cost: int        # 0 for NONE and BOX_TAKE
	var label: String    # the prompt text, "" for no prompt
	var weapon: WeaponDef  # set for WEAPON, AMMO, and BOX_TAKE

func offer(loadout: Loadout) -> Station.Offer   # changes nothing
func accept(offer: Station.Offer, weapon: Weapon) -> void   # Game calls it after a successful spend
```

A station is on `Layers.INTERACT` only. It does not collide with bodies.

```gdscript
class_name WallBuy extends Station

var weapon_def: WeaponDef
var price: int

func _init(weapon: WeaponDef, weapon_price: int) -> void
```

| The player | Offer |
|---|---|
| does not have the weapon | WEAPON, `price`, "Buy SMG" |
| has the weapon, and its ammunition is not full | AMMO, `Rules.ammo_price(price)`, "Buy SMG ammo" |
| has the weapon, and its ammunition is full | NONE, 0, "SMG ammo full" |

`accept()` calls `weapon.equip(weapon_def)` for WEAPON and `weapon.fill(weapon_def.id)` for AMMO.

```gdscript
class_name MysteryBox extends Station

enum Phase { IDLE, ROLLING, OFFERING }

var phase: Phase = Phase.IDLE
var result: WeaponDef         # set in ROLLING and OFFERING
var rng: RandomNumberGenerator = RandomNumberGenerator.new()   # tests seed it
var _time_left: float = 0.0

func advance(delta: float) -> void   # _physics_process calls it. Tests call it directly.
```

| From | Condition | To | Effect |
|---|---|---|---|
| IDLE | `accept(BOX_ROLL)` | ROLLING | `result` = a random pick from `Arsenal.box_pool()` without the ids in the loadout. Timer = `BOX_ROLL_SECONDS`. |
| ROLLING | timer done | OFFERING | timer = `BOX_OFFER_SECONDS` |
| OFFERING | `accept(BOX_TAKE)` | IDLE | `weapon.equip(result)`, `result = null` |
| OFFERING | timer done | IDLE | `result = null` |

| Phase | Offer |
|---|---|
| IDLE | BOX_ROLL, `Rules.BOX_PRICE`, "Mystery box" |
| ROLLING | NONE, 0, "" |
| OFFERING | BOX_TAKE, 0, "Take LMG" |

The box is a crate on `Layers.WORLD`, so the navigation bake cuts it out and zombies walk around it. The station area is a child of the crate and is 0.1 m larger than the crate on each side, so the interact ray hits the area before the crate body. In ROLLING, a model above the crate shows a different weapon of the pool every 0.1 s. In OFFERING, it shows `result`.

A weapon that the player buys from a wall during a roll can be the result. Then BOX_TAKE fills that weapon, because `give()` fills a weapon that the player has. No branch is necessary.

```gdscript
class_name Weapon extends Node3D

enum State { READY, COOLDOWN, RELOADING, MELEE, SWITCHING }

signal fired
signal hit(target: Zombie, damage: float, kind: Rules.HitKind)
signal ammo_changed(magazine: int, reserve: int)
signal equipped(weapon: WeaponDef)
signal reload_started
signal reload_finished

var loadout: Loadout                  # Game sets it before add_child. The default is the pistol only.
var state: State = State.READY
var trigger_held: bool = false
var reload_requested: bool = false
var melee_requested: bool = false
var switch_requested: bool = false    # one tick

func current() -> Loadout.Slot
func equip(weapon: WeaponDef) -> void   # loadout.give(), then SWITCHING
func fill(id: StringName) -> void       # the slot fills. If it is current and RELOADING, the state goes to READY.
```

| From | Condition | To | Effect |
|---|---|---|---|
| READY, COOLDOWN, RELOADING | `switch_requested` and `loadout.cycle()` | SWITCHING | timer = `SWITCH_SECONDS`, `reload_requested = false`, emit `equipped` and `ammo_changed` |
| any | `equip()` | SWITCHING | the same as above |
| SWITCHING | timer done | READY | on the same tick, READY fires a pending press |
| SWITCHING | `melee_requested` | MELEE | the same as a melee from READY |
| MELEE, SWITCHING | `switch_requested` | no change | the request is cleared |

A change stops a reload, and the magazine and the reserve do not change. The active slot changes on the first tick of SWITCHING, so the HUD shows the new ammunition at once. The view model goes down for the first half of SWITCHING with the old parts, and comes up for the second half with the new parts.

A shot casts one ray for each pellet. The weapon adds the damage of all pellets that hit the same zombie and emits one `hit` for each zombie. A head pellet does `damage * HEADSHOT_MULTIPLIER`. The kind is HEAD if one or more pellets hit the head, and BODY if not. Thus a shotgun shot earns `POINTS_HIT` one time for each zombie it hits, not one time for each pellet. `Rules.points_for_hit` does not change.

```gdscript
# Added to Game:
var _station: Station = null   # the station in view on the last physics tick, or null

func interact() -> bool        # true if the press bought something
```

Each physics tick, `Game` casts a ray from the camera with the length `INTERACT_RANGE` and the mask `WORLD | INTERACT`, with `collide_with_areas` on. A wall stops it. `Game` sends the offer to `hud.set_prompt()`. `interact()` gets the offer again, calls `points.spend(offer.cost)`, and calls `station.accept()` if the spend succeeds. An offer of kind NONE does nothing.

```gdscript
# Added to Hud:
var weapon_label: Label
var prompt_label: Label

func set_weapon(weapon_name: String) -> void
func set_prompt(text: String, affordable: bool) -> void   # "" hides it. Not affordable: gray.
```

The weapon name is above the ammunition. The prompt is below the crosshair, in the form "E  Buy SMG  1000".

## Arena

The outer walls have their inner faces at 20 m from the center. The stations stay away from the zombie spawn points:

| Station | Position | Faces |
|---|---|---|
| SMG wall buy, 1000 | (-8, 1.5, -19.95) | +Z |
| Shotgun wall buy, 1200 | (19.95, 1.5, -8) | -X |
| Rifle wall buy, 1500 | (-19.95, 1.5, 8) | +X |
| Box, 950 | (10, 0, 19.5) | -Z |

`Arena` exposes `stations: Array[Station]` and `box: MysteryBox` for the game and the tests.

## Input

Add `interact` (E, gamepad right shoulder) and `switch_weapon` (Q, mouse wheel up, mouse wheel down, gamepad Y). `Game` registers them, as it registers `fire` today.

## Boundaries

- `Loadout`, `WallBuy.offer()`, and `MysteryBox.offer()` trust their inputs. `Game` and the stations are the only callers.
- `interact()` gets the offer again on the press. The prompt on the screen can be one tick old.
- `Game` checks `_station` with `is_instance_valid`, as it checks a zombie.

## Verification plan

Headless tests with literal expected values:

- `Rules`: `ammo_price` of 1000, 1200, and 1500 gives 500, 600, and 750.
- `Loadout`: the start has 1 slot with the pistol at 8 and 80. `give(smg)` adds slot 2 and makes it active. `give(rifle)` with 2 slots replaces the SMG, and the pistol keeps its ammunition. `give(pistol)` after 3 shots fills it and makes it active. `cycle()` with 1 slot returns false. `fill()` and `is_full()`.
- `WallBuy.offer` for the three rows of its table, with the literal kind, cost, and label.
- `MysteryBox`: with a seeded `rng`, a roll from a loadout of the pistol and the SMG never gives the SMG in 200 rolls. ROLLING lasts 4.0 s and OFFERING lasts 10.0 s through `advance()`. The offer in each phase. A take gives the weapon. A timeout gives nothing. Through `Game`, a roll removes 950 points, and a timeout does not give them back.
- `Weapon` in a real physics world: a change takes 30 ticks (0.5 s) and keeps the ammunition of both slots. A change during a reload stops it with no change to the ammunition. A switch request with one slot does nothing. A press held through SWITCHING fires one time when it ends. A shotgun shot with 0° spread at a zombie 3 m ahead emits one `hit` for 200 damage of kind BODY.
- `Game` with the real arena: the player looks at the SMG wall from 1.5 m, and the prompt is "E  Buy SMG  1000". With 500 points, `interact()` returns false and the balance stays 500. With 1000 points, `interact()` returns true, the balance is 0, and slot 2 is the SMG. A wall between the player and the station hides the prompt. Round 2 does not refill the ammunition.
- All milestone 1 tests still pass, with `weapon.current()` in place of the removed fields, on Jolt and on Godot Physics.
- `godot --headless --path . --quit-after 600` with no errors.
- `tests/visual_smoke.gd` captures a frame.
- The `verify` skill plays the real main scene: earn points, buy the SMG with E, change weapons with Q, and take a screenshot of the prompt and of the box offer.

## Accepted deviations

None yet.
