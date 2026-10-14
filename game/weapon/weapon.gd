class_name Weapon
extends Node3D

enum State { READY, COOLDOWN, RELOADING, MELEE }

signal fired
signal hit(target: Zombie, damage: float, kind: Rules.HitKind)
signal ammo_changed(magazine: int, reserve: int)
signal reload_started
signal reload_finished

const VIEW_OFFSET: Vector3 = Vector3(0.16, -0.15, -0.36)
const RECOIL_KICK: float = 0.05
const RECOIL_RECOVERY: float = 18.0
const MELEE_THRUST: float = 0.22
const FLASH_SECONDS: float = 0.05
const METAL_COLOR: Color = Color(0.16, 0.17, 0.19)
const GRIP_COLOR: Color = Color(0.32, 0.22, 0.14)
const FLASH_COLOR: Color = Color(1.0, 0.75, 0.35)

var def: WeaponDef
var state: State = State.READY
var magazine: int = 0
var reserve: int = 0
## The game writes this from input. Tests write it directly.
var trigger_held: bool = false
## Kept until the weapon is READY, then cleared, so a press during the cooldown is not lost.
var reload_requested: bool = false
## One tick. The game writes this from input. Tests write it directly.
var melee_requested: bool = false

var _time_left: float = 0.0
var _trigger_was_held: bool = false
## A semi-automatic press made during the cooldown fires when the cooldown ends.
var _press_pending: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _model: Node3D = Node3D.new()
var _flash: OmniLight3D = OmniLight3D.new()
var _flash_mesh: MeshInstance3D = MeshInstance3D.new()
var _flash_left: float = 0.0
var _recoil: float = 0.0


func _ready() -> void:
	if def == null:
		def = WeaponDef.starting_pistol()
	_build_model()
	refill()


func refill() -> void:
	magazine = def.magazine_size
	reserve = def.reserve_max
	if state == State.RELOADING:
		state = State.READY
	ammo_changed.emit(magazine, reserve)


func _physics_process(delta: float) -> void:
	if trigger_held and not _trigger_was_held:
		_press_pending = true
	if not trigger_held:
		_press_pending = false
	_trigger_was_held = trigger_held
	var melee: bool = melee_requested
	melee_requested = false
	match state:
		State.COOLDOWN:
			_time_left -= delta
			if _time_left <= 0.0:
				state = State.READY
		State.RELOADING:
			_time_left -= delta
			if _time_left <= 0.0:
				_finish_reload()
		State.MELEE:
			_time_left -= delta
			if _time_left <= 0.0:
				state = State.READY
	if melee and state != State.MELEE:
		_melee()
	elif state == State.READY:
		if magazine == 0 or (reload_requested and magazine < def.magazine_size):
			_start_reload()
		elif _press_pending or (def.automatic and trigger_held):
			_fire()
		reload_requested = false


func _process(delta: float) -> void:
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-RECOIL_RECOVERY * delta))
	var dip: float = 0.0
	if state == State.RELOADING:
		dip = sin(PI * (1.0 - _time_left / def.reload_seconds))
	var thrust: float = 0.0
	if state == State.MELEE:
		thrust = sin(PI * (1.0 - _time_left / Rules.MELEE_SECONDS))
	_model.position = VIEW_OFFSET + Vector3(-0.08 * thrust, -0.12 * dip, _recoil - MELEE_THRUST * thrust)
	_model.rotation = Vector3(_recoil * 4.0 - dip * 0.7, 0.0, dip * 0.4)
	_flash_left -= delta
	_flash.visible = _flash_left > 0.0
	_flash_mesh.visible = _flash.visible


func _start_reload() -> void:
	if reserve == 0:
		return
	state = State.RELOADING
	_time_left = def.reload_seconds
	reload_started.emit()


func _finish_reload() -> void:
	var loaded: int = mini(def.magazine_size - magazine, reserve)
	magazine += loaded
	reserve -= loaded
	state = State.READY
	reload_finished.emit()
	ammo_changed.emit(magazine, reserve)


func _fire() -> void:
	magazine -= 1
	state = State.COOLDOWN
	_time_left = def.fire_interval
	_press_pending = false
	_recoil = RECOIL_KICK
	_flash_left = FLASH_SECONDS
	fired.emit()
	ammo_changed.emit(magazine, reserve)
	_cast_ray()


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


## The ray starts at the camera, the parent of this node. Its mask has no player layer, so the shooter is never hit.
func _cast_ray() -> void:
	var view: Transform3D = (get_parent() as Node3D).global_transform
	var spread: float = deg_to_rad(def.spread_degrees) * sqrt(_rng.randf())
	var forward: Vector3 = -view.basis.z
	var direction: Vector3 = forward.rotated(view.basis.y, spread).rotated(forward, _rng.randf() * TAU)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(view.origin, view.origin + direction * def.range, Layers.WORLD | Layers.ZOMBIES)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = result.get("collider")
	var target: Zombie = collider as Zombie
	if target == null:
		return
	var point: Vector3 = result["position"]
	var headshot: bool = point.y - target.global_position.y >= Rules.ZOMBIE_HEAD_HEIGHT
	if headshot:
		hit.emit(target, def.damage * Rules.HEADSHOT_MULTIPLIER, Rules.HitKind.HEAD)
	else:
		hit.emit(target, def.damage, Rules.HitKind.BODY)


func _build_model() -> void:
	_model.position = VIEW_OFFSET
	add_child(_model)
	_add_part(Vector3(0.035, 0.045, 0.17), Vector3(0.0, 0.0, -0.03), METAL_COLOR)
	_add_part(Vector3(0.032, 0.09, 0.045), Vector3(0.0, -0.06, 0.03), GRIP_COLOR)
	_add_part(Vector3(0.008, 0.014, 0.008), Vector3(0.0, 0.029, -0.1), METAL_COLOR)
	var flash_sphere: SphereMesh = SphereMesh.new()
	flash_sphere.radius = 0.04
	flash_sphere.height = 0.08
	var flash_material: StandardMaterial3D = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = FLASH_COLOR
	_flash_mesh.mesh = flash_sphere
	_flash_mesh.material_override = flash_material
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mesh.position = Vector3(0.0, 0.0, -0.14)
	_flash_mesh.visible = false
	_model.add_child(_flash_mesh)
	_flash.light_color = FLASH_COLOR
	_flash.light_energy = 3.0
	_flash.omni_range = 6.0
	_flash.position = Vector3(0.0, 0.0, -0.2)
	_flash.visible = false
	_model.add_child(_flash)


func _add_part(size: Vector3, at: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.6
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = box
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = at
	_model.add_child(part)
