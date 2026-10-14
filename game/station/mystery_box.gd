class_name MysteryBox
extends Station
## The random weapon box. Arena puts it on a crate body on Layers.WORLD, so the navigation bake cuts the crate out.

enum Phase { IDLE, ROLLING, OFFERING }

const CRATE_SIZE: Vector3 = Vector3(1.8, 0.9, 0.9)
## The area is 0.1 m larger than the crate on each side, so the interact ray finds it before the crate body.
## It also reaches up over the floating weapon, so the player can look at the weapon to take it.
const AREA_SIZE: Vector3 = Vector3(2.0, 1.8, 1.1)
const CYCLE_SECONDS: float = 0.1
const MODEL_SCALE: float = 1.5
## The floating weapon is one flat glowing color, so it reads in the dark yard.
const MODEL_TINT: Color = Color(0.75, 0.85, 1.0)
const MODEL_HEIGHT: float = 0.45
const SPIN_SPEED: float = 1.2
const GLOW_COLOR: Color = Color(0.45, 0.65, 1.0)

var phase: Phase = Phase.IDLE
## Set in ROLLING and OFFERING.
var result: WeaponDef = null
## Tests seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _time_left: float = 0.0
var _cycle_left: float = 0.0
var _cycle_index: int = 0
var _pool: Array[WeaponDef] = Arsenal.box_pool()
var _display: Node3D
var _models: Dictionary[StringName, Node3D] = {}


## The origin is the crate center.
func _ready() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = AREA_SIZE
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, AREA_SIZE.y * 0.5 - CRATE_SIZE.y * 0.5 - 0.1, 0.0)
	add_child(collision)
	_display = Node3D.new()
	_display.position = Vector3(0.0, CRATE_SIZE.y * 0.5 + MODEL_HEIGHT, 0.0)
	add_child(_display)
	for weapon: WeaponDef in _pool:
		var model: Node3D = weapon.build_model(MODEL_SCALE, MODEL_TINT)
		model.basis = Basis(Vector3.UP, PI * 0.5)
		model.visible = false
		_display.add_child(model)
		_models[weapon.id] = model
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = GLOW_COLOR
	glow.light_energy = 1.5
	glow.omni_range = 3.0
	glow.position = Vector3(0.0, CRATE_SIZE.y * 0.5 + 0.3, 0.0)
	add_child(glow)


func _physics_process(delta: float) -> void:
	advance(delta)


func _process(delta: float) -> void:
	_display.rotate_y(SPIN_SPEED * delta)


func offer(_loadout: Loadout) -> Station.Offer:
	match phase:
		Phase.IDLE:
			return Station.Offer.new(Station.Offer.Kind.BOX_ROLL, Rules.BOX_PRICE, "Mystery box")
		Phase.OFFERING:
			return Station.Offer.new(Station.Offer.Kind.BOX_TAKE, 0, "Take %s" % result.display_name, result)
	return Station.Offer.new(Station.Offer.Kind.NONE, 0, "")


func accept(chosen: Station.Offer, weapon: Weapon) -> void:
	match chosen.kind:
		Station.Offer.Kind.BOX_ROLL:
			_roll(weapon.loadout)
		Station.Offer.Kind.BOX_TAKE:
			weapon.equip(result)
			_enter_idle()


## _physics_process calls it. Tests call it directly.
func advance(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_time_left -= delta
	if phase == Phase.ROLLING:
		_cycle_left -= delta
		if _cycle_left <= 0.0:
			_cycle_left = CYCLE_SECONDS
			_cycle_index = (_cycle_index + 1) % _pool.size()
			_show(_pool[_cycle_index].id)
	if _time_left > 0.0:
		return
	if phase == Phase.ROLLING:
		phase = Phase.OFFERING
		_time_left = Rules.BOX_OFFER_SECONDS
		_show(result.id)
	else:
		_enter_idle()


## A weapon that the player has when the roll starts cannot be the result.
func _roll(loadout: Loadout) -> void:
	var choices: Array[WeaponDef] = []
	for weapon: WeaponDef in _pool:
		if loadout.find(weapon.id) == null:
			choices.append(weapon)
	result = choices[rng.randi_range(0, choices.size() - 1)]
	phase = Phase.ROLLING
	_time_left = Rules.BOX_ROLL_SECONDS
	_cycle_left = CYCLE_SECONDS
	_show(_pool[_cycle_index].id)


func _enter_idle() -> void:
	phase = Phase.IDLE
	result = null
	_show(&"")


func _show(id: StringName) -> void:
	for shown: StringName in _models:
		_models[shown].visible = shown == id
