class_name Weapon
extends Node3D

enum State { READY, COOLDOWN, RELOADING, MELEE, SWITCHING }

signal fired
signal hit(target: Zombie, damage: float, kind: Rules.HitKind)
signal ammo_changed(magazine: int, reserve: int)
signal equipped(weapon: WeaponDef)
signal reload_started
signal reload_finished

const VIEW_OFFSET: Vector3 = Vector3(0.16, -0.15, -0.36)
const RECOIL_KICK: float = 0.05
const RECOIL_RECOVERY: float = 18.0
const MELEE_THRUST: float = 0.22
const SWITCH_DROP: float = 0.3
const FLASH_SECONDS: float = 0.05
## A timer of a whole number of ticks ends on its last tick, although the sum of the float deltas can stay a little above it.
const TIMER_TOLERANCE: float = 0.0001
const FLASH_COLOR: Color = Color(1.0, 0.75, 0.35)

## Set it before add_child to start with other weapons.
var loadout: Loadout = Loadout.new(Arsenal.pistol())
var state: State = State.READY
## The game writes this from input. Tests write it directly.
var trigger_held: bool = false
## Kept until the weapon is READY, then cleared, so a press during the cooldown is not lost.
var reload_requested: bool = false
## One tick. The game writes this from input. Tests write it directly.
var melee_requested: bool = false
## One tick. The game writes this from input. Tests write it directly.
var switch_requested: bool = false

var _time_left: float = 0.0
var _trigger_was_held: bool = false
## A semi-automatic press made during the cooldown fires when the cooldown ends.
var _press_pending: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _model: Node3D = Node3D.new()
var _parts: Node3D
## The weapon whose parts the view model shows. During the first half of SWITCHING it is still the old weapon.
var _shown: StringName = &""
var _flash: OmniLight3D = OmniLight3D.new()
var _flash_mesh: MeshInstance3D = MeshInstance3D.new()
var _flash_left: float = 0.0
var _recoil: float = 0.0


func _ready() -> void:
	_build_model()


func current() -> Loadout.Slot:
	return loadout.current()


func equip(weapon: WeaponDef) -> void:
	loadout.give(weapon)
	_start_switch()


## The slot of the weapon fills. A reload of that weapon in progress has nothing left to do.
func fill(id: StringName) -> void:
	var slot: Loadout.Slot = loadout.find(id)
	slot.fill()
	if slot != current():
		return
	if state == State.RELOADING:
		state = State.READY
	ammo_changed.emit(slot.magazine, slot.reserve)


func _physics_process(delta: float) -> void:
	if trigger_held and not _trigger_was_held:
		_press_pending = true
	if not trigger_held:
		_press_pending = false
	_trigger_was_held = trigger_held
	var melee: bool = melee_requested
	melee_requested = false
	var switch: bool = switch_requested
	switch_requested = false
	if state != State.READY:
		_time_left -= delta
		if _time_left <= TIMER_TOLERANCE:
			if state == State.RELOADING:
				_finish_reload()
			else:
				state = State.READY
	var slot: Loadout.Slot = current()
	if melee and state != State.MELEE:
		_melee()
	elif switch and state != State.MELEE and state != State.SWITCHING and loadout.cycle():
		_start_switch()
	elif state == State.READY:
		if slot.magazine == 0 or (reload_requested and slot.magazine < slot.def.magazine_size):
			_start_reload()
		elif _press_pending or (slot.def.automatic and trigger_held):
			_fire()
		reload_requested = false


func _process(delta: float) -> void:
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-RECOIL_RECOVERY * delta))
	var dip: float = 0.0
	if state == State.RELOADING:
		dip = sin(PI * (1.0 - _time_left / current().def.reload_seconds))
	var thrust: float = 0.0
	if state == State.MELEE:
		thrust = sin(PI * (1.0 - _time_left / Rules.MELEE_SECONDS))
	var drop: float = 0.0
	var lowering: bool = false
	if state == State.SWITCHING:
		drop = sin(PI * (1.0 - _time_left / Rules.SWITCH_SECONDS))
		lowering = _time_left > Rules.SWITCH_SECONDS * 0.5
	if not lowering and _shown != current().def.id:
		_show(current().def)
	_model.position = VIEW_OFFSET + Vector3(-0.08 * thrust, -0.12 * dip - SWITCH_DROP * drop, _recoil - MELEE_THRUST * thrust)
	_model.rotation = Vector3(_recoil * 4.0 - dip * 0.7 - drop * 0.6, 0.0, dip * 0.4)
	_flash_left -= delta
	_flash.visible = _flash_left > 0.0
	_flash_mesh.visible = _flash.visible


## The active slot changes before this call, so the HUD shows the new ammunition at once. A reload in progress stops.
func _start_switch() -> void:
	state = State.SWITCHING
	_time_left = Rules.SWITCH_SECONDS
	reload_requested = false
	var slot: Loadout.Slot = current()
	equipped.emit(slot.def)
	ammo_changed.emit(slot.magazine, slot.reserve)


func _start_reload() -> void:
	if current().reserve == 0:
		return
	state = State.RELOADING
	_time_left = current().def.reload_seconds
	reload_started.emit()


func _finish_reload() -> void:
	var slot: Loadout.Slot = current()
	var loaded: int = mini(slot.def.magazine_size - slot.magazine, slot.reserve)
	slot.magazine += loaded
	slot.reserve -= loaded
	state = State.READY
	reload_finished.emit()
	ammo_changed.emit(slot.magazine, slot.reserve)


func _fire() -> void:
	var slot: Loadout.Slot = current()
	slot.magazine -= 1
	state = State.COOLDOWN
	_time_left = slot.def.fire_interval
	_press_pending = false
	_recoil = RECOIL_KICK
	_flash_left = FLASH_SECONDS
	fired.emit()
	ammo_changed.emit(slot.magazine, slot.reserve)
	_cast_pellets(slot.def)


## An interrupted reload starts again from the beginning when the melee ends.
func _melee() -> void:
	if state == State.RELOADING:
		reload_requested = true
	state = State.MELEE
	_time_left = Rules.MELEE_SECONDS
	var view: Transform3D = (get_parent() as Node3D).global_transform
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(view.origin, view.origin - view.basis.z * Rules.MELEE_RANGE, Layers.WORLD | Layers.ZOMBIES)
	var collider: Object = get_world_3d().direct_space_state.intersect_ray(query).get("collider")
	var target: Zombie = collider as Zombie
	if target != null:
		hit.emit(target, Rules.MELEE_DAMAGE, Rules.HitKind.MELEE)


## One ray for each pellet, from the camera, the parent of this node. Its mask has no player layer, so the shooter is never hit.
## The pellets that hit one zombie make one hit, so a shotgun shot earns the hit points once for each zombie.
func _cast_pellets(def: WeaponDef) -> void:
	var view: Transform3D = (get_parent() as Node3D).global_transform
	var forward: Vector3 = -view.basis.z
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var damage: Dictionary[Zombie, float] = {}
	var heads: Dictionary[Zombie, bool] = {}
	for pellet: int in range(def.pellets):
		var spread: float = deg_to_rad(def.spread_degrees) * sqrt(_rng.randf())
		var direction: Vector3 = forward.rotated(view.basis.y, spread).rotated(forward, _rng.randf() * TAU)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(view.origin, view.origin + direction * def.range, Layers.WORLD | Layers.ZOMBIES)
		var result: Dictionary = space.intersect_ray(query)
		var collider: Object = result.get("collider")
		var target: Zombie = collider as Zombie
		if target == null:
			continue
		var point: Vector3 = result["position"]
		var headshot: bool = point.y - target.global_position.y >= Rules.ZOMBIE_HEAD_HEIGHT
		if not damage.has(target):
			damage[target] = 0.0
		damage[target] += def.damage * Rules.HEADSHOT_MULTIPLIER if headshot else def.damage
		if headshot:
			heads[target] = true
	for target: Zombie in damage:
		hit.emit(target, damage[target], Rules.HitKind.HEAD if heads.has(target) else Rules.HitKind.BODY)


func _build_model() -> void:
	_model.position = VIEW_OFFSET
	add_child(_model)
	var flash_sphere: SphereMesh = SphereMesh.new()
	flash_sphere.radius = 0.04
	flash_sphere.height = 0.08
	var flash_material: StandardMaterial3D = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = FLASH_COLOR
	_flash_mesh.mesh = flash_sphere
	_flash_mesh.material_override = flash_material
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mesh.visible = false
	_model.add_child(_flash_mesh)
	_flash.light_color = FLASH_COLOR
	_flash.light_energy = 3.0
	_flash.omni_range = 6.0
	_flash.visible = false
	_model.add_child(_flash)
	_show(current().def)


func _show(def: WeaponDef) -> void:
	if _parts != null:
		_parts.queue_free()
	_parts = def.build_model(1.0)
	_model.add_child(_parts)
	_flash_mesh.position = def.muzzle
	_flash.position = def.muzzle + Vector3(0.0, 0.0, -0.06)
	_shown = def.id
