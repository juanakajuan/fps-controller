class_name PlayerCameraRig
extends Node3D

const BOB_FADE_RATE: float = 10.0
const REFERENCE_ASPECT: float = 16.0 / 9.0

var body: Player
var camera: Camera3D = Camera3D.new()

var _previous_origin: Vector3 = Vector3.ZERO
var _current_origin: Vector3 = Vector3.ZERO
var _pending_step: float = 0.0
var _eye_height: float = 0.0
var _step_offset: float = 0.0
var _roll: float = 0.0
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0
var _dip: float = 0.0
var _dip_velocity: float = 0.0


func _init() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.name = "Camera"
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)


func _ready() -> void:
	body.landed.connect(_on_landed)
	if body.player_controlled:
		camera.make_current()
	snap()


## Puts every smoothed value on its target and places the camera now.
func snap() -> void:
	_previous_origin = body.global_position
	_current_origin = body.global_position
	_pending_step = 0.0
	_eye_height = _target_eye_height()
	_step_offset = 0.0
	_roll = 0.0
	_bob_weight = 0.0
	_dip = 0.0
	_dip_velocity = 0.0
	camera.fov = _target_fov()
	_place(body.global_position, Vector3.ZERO)


## Keeps the camera at its old height after the body moves up or down by height. The offset then decays to zero.
func add_step(height: float) -> void:
	_pending_step += height


## Called by the body at the end of each physics tick.
## The step also goes into the previous origin, so the lerp does not spread it over the tick. Only the offset decay smooths it.
func record_tick() -> void:
	_previous_origin = _current_origin + Vector3(0.0, _pending_step, 0.0)
	_current_origin = body.global_position
	_step_offset -= _pending_step
	_pending_step = 0.0


func _process(delta: float) -> void:
	var tuning: PlayerSettings = body.settings
	var speed: float = body.horizontal_speed()
	_eye_height = lerpf(_eye_height, _target_eye_height(), _blend(tuning.eye_height_smoothing, delta))
	_step_offset = lerpf(_step_offset, 0.0, _blend(tuning.step_smoothing, delta))
	camera.fov = lerpf(camera.fov, _target_fov(), _blend(tuning.fov_smoothing, delta))
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, body.yaw)
	var lateral: float = clampf(body.velocity.dot(right) / tuning.walk_speed, -1.0, 1.0)
	_roll = lerpf(_roll, -deg_to_rad(tuning.strafe_roll_degrees) * lateral, _blend(tuning.roll_smoothing, delta))
	var bobbing: bool = tuning.head_bob_enabled and body.move_state == Player.MoveState.GROUND
	var bob_target: float = clampf(speed / tuning.walk_speed, 0.0, 1.0) if bobbing else 0.0
	_bob_weight = lerpf(_bob_weight, bob_target, _blend(BOB_FADE_RATE, delta))
	_bob_phase = fmod(_bob_phase + TAU * tuning.head_bob_frequency * speed / tuning.walk_speed * delta, TAU)
	var bob: Vector3 = Vector3(sin(_bob_phase) * 0.5, sin(_bob_phase * 2.0), 0.0) * tuning.head_bob_amplitude * _bob_weight
	_step_dip(tuning.landing_dip_frequency, delta)
	var origin: Vector3 = _previous_origin.lerp(_current_origin, Engine.get_physics_interpolation_fraction())
	_place(origin, bob + Vector3(0.0, _dip, 0.0))


func _place(origin: Vector3, offset: Vector3) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, body.yaw), origin + Vector3(0.0, _eye_height + _step_offset, 0.0))
	camera.transform = Transform3D(Basis.from_euler(Vector3(body.pitch, 0.0, _roll)), offset)


func _on_landed(impact_speed: float) -> void:
	var tuning: PlayerSettings = body.settings
	var depth: float = minf(impact_speed * tuning.landing_dip_per_speed, tuning.landing_dip_max)
	# A critically damped spring that starts at rest with velocity v peaks at v / (frequency * e).
	_dip_velocity -= depth * tuning.landing_dip_frequency * exp(1.0)


## Exact step of a critically damped spring toward zero, so the dip is the same at any frame rate.
func _step_dip(frequency: float, delta: float) -> void:
	var decay: float = exp(-frequency * delta)
	var carry: float = (_dip_velocity + frequency * _dip) * delta
	_dip = (_dip + carry) * decay
	_dip_velocity = (_dip_velocity - frequency * carry) * decay


func _target_eye_height() -> float:
	var tuning: PlayerSettings = body.settings
	return tuning.crouch_eye_height if body.stance == Player.Stance.CROUCH else tuning.stand_eye_height


## Camera3D keeps the vertical FOV fixed, so the horizontal FOV from settings is converted at the 16:9 reference.
func _target_fov() -> float:
	var tuning: PlayerSettings = body.settings
	var kick_range: float = maxf(tuning.fov_kick_full_speed - tuning.walk_speed, 0.01)
	var kick: float = clampf((body.horizontal_speed() - tuning.walk_speed) / kick_range, 0.0, 1.0)
	var horizontal: float = deg_to_rad(tuning.base_fov + tuning.fov_kick_max * kick)
	return rad_to_deg(2.0 * atan(tan(horizontal * 0.5) / REFERENCE_ASPECT))


static func _blend(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
