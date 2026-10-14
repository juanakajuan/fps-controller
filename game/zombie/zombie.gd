class_name Zombie
extends CharacterBody3D

enum State { CHASE, ATTACK, DEAD }

signal attacked(damage: float)
signal died(headshot: bool)

const RADIUS: float = 0.35
const HEIGHT: float = 1.8
const GRAVITY: float = 9.8
## The target must also be within this height of the zombie, so a player on the platform above is out of reach.
const ATTACK_HEIGHT: float = 1.2
## The path is asked for again only when the target moves this far, so 24 zombies do not query the map on every tick.
const REPATH_DISTANCE: float = 0.5
const SINK_SPEED: float = 1.2
const SINK_SECONDS: float = 1.0
const FLASH_SECONDS: float = 0.08
const SKIN_COLOR: Color = Color(0.42, 0.52, 0.36)
const CLOTH_COLOR: Color = Color(0.25, 0.22, 0.3)
const EYE_COLOR: Color = Color(1.0, 0.85, 0.3)

var state: State = State.CHASE
var health: float = 0.0
var speed: float = 0.0
## The player.
var target: Node3D

var _agent: NavigationAgent3D = NavigationAgent3D.new()
var _attack_cooldown_left: float = 0.0
var _collision: CollisionShape3D = CollisionShape3D.new()
var _safe_velocity: Vector3 = Vector3.ZERO
var _last_target_position: Vector3 = Vector3.INF
var _dead_time: float = 0.0
var _skin: StandardMaterial3D = StandardMaterial3D.new()
var _flash_left: float = 0.0


## Call before add_child.
func setup(start_health: float, move_speed: float, chase_target: Node3D) -> void:
	health = start_health
	speed = move_speed
	target = chase_target


func _ready() -> void:
	collision_layer = Layers.ZOMBIES
	collision_mask = Layers.WORLD | Layers.PLAYER
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	_collision.shape = capsule
	_collision.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(_collision)
	_agent.radius = RADIUS
	_agent.height = HEIGHT
	_agent.max_speed = speed
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	_agent.avoidance_enabled = true
	_agent.velocity_computed.connect(func(safe_velocity: Vector3) -> void: _safe_velocity = safe_velocity)
	add_child(_agent)
	_build_model()


func take_damage(amount: float, headshot: bool) -> void:
	if state == State.DEAD:
		return
	health = maxf(health - amount, 0.0)
	_flash_left = FLASH_SECONDS
	if health > 0.0:
		return
	state = State.DEAD
	_collision.set_deferred(&"disabled", true)
	_agent.avoidance_enabled = false
	died.emit(headshot)


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	match state:
		State.CHASE:
			if _target_in_range():
				state = State.ATTACK
			else:
				_chase(delta)
		State.ATTACK:
			if not _target_in_range():
				state = State.CHASE
				_chase(delta)
			else:
				_attack(delta)
		State.DEAD:
			_dead_time += delta
			position.y -= SINK_SPEED * delta
			if _dead_time >= SINK_SECONDS:
				queue_free()


func _process(delta: float) -> void:
	_flash_left -= delta
	_skin.emission_enabled = _flash_left > 0.0


func _target_in_range() -> bool:
	var offset: Vector3 = target.global_position - global_position
	return Vector2(offset.x, offset.z).length() <= Rules.ZOMBIE_ATTACK_RANGE and absf(offset.y) <= ATTACK_HEIGHT


func _chase(delta: float) -> void:
	if _last_target_position.distance_to(target.global_position) > REPATH_DISTANCE:
		_last_target_position = target.global_position
		_agent.target_position = _last_target_position
	var next: Vector3 = target.global_position if _agent.is_navigation_finished() else _agent.get_next_path_position()
	var heading: Vector3 = Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	var desired: Vector3 = heading.normalized() * speed if heading.length_squared() > 0.0001 else Vector3.ZERO
	_agent.velocity = desired
	_face(desired)
	_move(_safe_velocity, delta)


func _attack(delta: float) -> void:
	_agent.velocity = Vector3.ZERO
	_face(target.global_position - global_position)
	_move(Vector3.ZERO, delta)
	if _attack_cooldown_left <= 0.0:
		_attack_cooldown_left = Rules.ZOMBIE_ATTACK_COOLDOWN
		attacked.emit(Rules.ZOMBIE_DAMAGE)


func _move(horizontal: Vector3, delta: float) -> void:
	var fall: float = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	velocity = Vector3(horizontal.x, fall, horizontal.z)
	move_and_slide()


func _face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() > 0.0001:
		rotation.y = atan2(-direction.x, -direction.z)


func _build_model() -> void:
	_skin.albedo_color = SKIN_COLOR
	_skin.emission = Color(1.0, 0.25, 0.2)
	_skin.emission_energy_multiplier = 1.5
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = CLOTH_COLOR
	var eyes: StandardMaterial3D = StandardMaterial3D.new()
	eyes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eyes.albedo_color = EYE_COLOR
	var torso: CapsuleMesh = CapsuleMesh.new()
	torso.radius = RADIUS
	torso.height = 1.5
	_add_part(torso, Vector3(0.0, 0.75, 0.0), cloth)
	var head: BoxMesh = BoxMesh.new()
	head.size = Vector3(0.36, 0.36, 0.36)
	_add_part(head, Vector3(0.0, 1.62, 0.0), _skin)
	var eye: BoxMesh = BoxMesh.new()
	eye.size = Vector3(0.07, 0.04, 0.02)
	_add_part(eye, Vector3(-0.08, 1.66, -0.18), eyes)
	_add_part(eye, Vector3(0.08, 1.66, -0.18), eyes)
	var arm: BoxMesh = BoxMesh.new()
	arm.size = Vector3(0.12, 0.12, 0.6)
	_add_part(arm, Vector3(-0.26, 1.3, -0.3), _skin)
	_add_part(arm, Vector3(0.26, 1.3, -0.3), _skin)


func _add_part(mesh: Mesh, at: Vector3, material: Material) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	add_child(part)
