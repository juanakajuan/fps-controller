class_name FPSController
extends CharacterBody3D

enum MoveState { GROUND, AIR, SLIDE }
enum Stance { STAND, CROUCH }


class Intent:
	## x is right, y is forward. Length is clamped to 1.
	var move: Vector2 = Vector2.ZERO
	## Set to true for one tick on press. The controller clears it.
	var jump_pressed: bool = false
	var jump_held: bool = false
	var sprint_held: bool = false
	var crouch_held: bool = false


signal jumped
signal landed(impact_speed: float)
signal move_state_changed(previous: MoveState, current: MoveState)

const MAX_PITCH: float = PI * 89.0 / 180.0
const STEP_CLEARANCE: float = 0.05
const MIN_STEP: float = 0.01
const STEP_PROBE: float = 0.1

@export var settings: FPSSettings
@export var player_controlled: bool = true
@export var manage_mouse_capture: bool = true
@export_range(0.001, 2.0, 0.001, "suffix:°/px") var mouse_sensitivity: float = 0.1
@export_range(1.0, 1080.0, 1.0, "suffix:°/s") var gamepad_look_speed: float = 240.0
## Response curve exponent for the look stick. 1 is linear. Higher gives finer aim near the center.
@export_range(1.0, 4.0, 0.1) var gamepad_look_exponent: float = 2.0
@export var invert_y: bool = false

var intent: Intent = Intent.new()
var yaw: float = 0.0
var pitch: float = 0.0
var move_state: MoveState = MoveState.AIR
var stance: Stance = Stance.STAND
var camera: Camera3D

var _rig: FPSCameraRig
var _shape: CapsuleShape3D
var _collision: CollisionShape3D
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _slide_cooldown_left: float = 0.0
var _crouch_was_held: bool = false
var _jump_cut_armed: bool = false
var _impact_speed: float = 0.0
var _on_floor: bool = false


func _ready() -> void:
	if settings == null:
		settings = FPSSettings.new()
	if not get_tree().physics_interpolation:
		push_warning("FPSController: physics interpolation is off, so the camera moves at the physics tick rate. Turn on physics/common/physics_interpolation.")
	floor_max_angle = deg_to_rad(settings.floor_max_angle_degrees)
	floor_constant_speed = true
	floor_snap_length = settings.step_height
	_shape = CapsuleShape3D.new()
	_shape.radius = settings.capsule_radius
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	_collision.shape = _shape
	add_child(_collision)
	_apply_stance_shape()
	_rig = FPSCameraRig.new()
	_rig.name = "CameraRig"
	_rig.body = self
	add_child(_rig)
	camera = _rig.camera
	_register_default_actions()
	if player_controlled and manage_mouse_capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_settle()


func _process(delta: float) -> void:
	if not player_controlled:
		return
	var stick: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if stick == Vector2.ZERO:
		return
	var curved: Vector2 = stick.normalized() * pow(stick.length(), gamepad_look_exponent)
	var turn: float = deg_to_rad(gamepad_look_speed) * delta
	look(-curved.x * turn, -curved.y * turn * _pitch_sign())


func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var motion: Vector2 = (event as InputEventMouseMotion).screen_relative
			var turn: float = deg_to_rad(mouse_sensitivity)
			look(-motion.x * turn, -motion.y * turn * _pitch_sign())
	elif manage_mouse_capture:
		_update_mouse_capture(event)


func _physics_process(delta: float) -> void:
	if player_controlled:
		_read_intent()
	_coyote_left = maxf(_coyote_left - delta, 0.0)
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)
	if intent.jump_pressed:
		_jump_buffer_left = settings.jump_buffer_time
		intent.jump_pressed = false
	var crouch_pressed: bool = intent.crouch_held and not _crouch_was_held
	_crouch_was_held = intent.crouch_held
	_transition(crouch_pressed)
	_update_stance()
	match move_state:
		MoveState.GROUND:
			_move_ground(delta)
		MoveState.AIR:
			_move_air(delta)
		MoveState.SLIDE:
			_move_slide(delta)


func look(delta_yaw: float, delta_pitch: float) -> void:
	yaw = wrapf(yaw + delta_yaw, -PI, PI)
	pitch = clampf(pitch + delta_pitch, -MAX_PITCH, MAX_PITCH)


func teleport(target_position: Vector3, target_yaw: float) -> void:
	global_position = target_position
	velocity = Vector3.ZERO
	yaw = wrapf(target_yaw, -PI, PI)
	pitch = 0.0
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	if is_inside_tree():
		reset_physics_interpolation()
		_settle()


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _settle() -> void:
	# A zero-motion move refreshes a stale floor contact, and the snap finds a floor the move missed.
	move_and_slide()
	apply_floor_snap()
	_on_floor = is_on_floor()
	_set_state(MoveState.GROUND if _on_floor else MoveState.AIR)
	_rig.snap()


func _read_intent() -> void:
	intent.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	if Input.is_action_just_pressed(&"jump"):
		intent.jump_pressed = true
	intent.jump_held = Input.is_action_pressed(&"jump")
	intent.sprint_held = Input.is_action_pressed(&"sprint")
	intent.crouch_held = Input.is_action_pressed(&"crouch")


func _transition(crouch_pressed: bool) -> void:
	match move_state:
		MoveState.GROUND:
			if _jump_buffer_left > 0.0:
				_jump()
			elif not _on_floor:
				_coyote_left = settings.coyote_time
				_set_state(MoveState.AIR)
			elif crouch_pressed and _slide_cooldown_left <= 0.0 and horizontal_speed() >= settings.slide_min_speed:
				_boost_slide()
				_set_state(MoveState.SLIDE)
		MoveState.AIR:
			if _on_floor:
				landed.emit(_impact_speed)
				if _jump_buffer_left > 0.0:
					_jump()
				elif intent.crouch_held and horizontal_speed() >= settings.slide_min_speed:
					_set_state(MoveState.SLIDE)
				else:
					_set_state(MoveState.GROUND)
			elif _jump_buffer_left > 0.0 and _coyote_left > 0.0:
				_jump()
		MoveState.SLIDE:
			if _jump_buffer_left > 0.0:
				_jump()
			elif not _on_floor:
				_coyote_left = settings.coyote_time
				_set_state(MoveState.AIR)
			elif not intent.crouch_held or horizontal_speed() < settings.slide_exit_speed:
				_set_state(MoveState.GROUND)


func _set_state(next: MoveState) -> void:
	if next == move_state:
		return
	if move_state == MoveState.SLIDE:
		_slide_cooldown_left = settings.slide_cooldown
	var previous: MoveState = move_state
	move_state = next
	move_state_changed.emit(previous, next)


func _jump() -> void:
	velocity.y = settings.jump_velocity()
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	_jump_cut_armed = intent.jump_held
	_set_state(MoveState.AIR)
	jumped.emit()


func _boost_slide() -> void:
	var horizontal: Vector3 = _horizontal_velocity()
	var speed: float = horizontal.length()
	velocity = horizontal.normalized() * maxf(speed, minf(speed + settings.slide_boost, settings.slide_max_speed))


func _update_stance() -> void:
	if intent.crouch_held or move_state == MoveState.SLIDE:
		_set_stance(Stance.CROUCH)
	elif stance == Stance.CROUCH and _can_stand():
		_set_stance(Stance.STAND)


func _set_stance(next: Stance) -> void:
	if next == stance:
		return
	stance = next
	_apply_stance_shape()


func _apply_stance_shape() -> void:
	var height: float = settings.crouch_height if stance == Stance.CROUCH else settings.stand_height
	_shape.height = height
	_collision.position = Vector3(0.0, height * 0.5, 0.0)


func _can_stand() -> bool:
	var growth: Vector3 = Vector3.UP * (settings.stand_height - settings.crouch_height)
	return not _test_motion(global_transform, growth, PhysicsTestMotionResult3D.new())


func _target_speed() -> float:
	if stance == Stance.CROUCH:
		return settings.crouch_speed
	return settings.sprint_speed if intent.sprint_held else settings.walk_speed


func _wish(speed: float) -> Vector3:
	var move: Vector2 = intent.move.limit_length(1.0)
	return Vector3(move.x, 0.0, -move.y).rotated(Vector3.UP, yaw) * speed


func _horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func _move_ground(delta: float) -> void:
	var horizontal: Vector3 = _friction(_horizontal_velocity(), settings.ground_friction, settings.stop_speed, delta)
	velocity = _accelerate(horizontal, _wish(_target_speed()), settings.ground_acceleration, delta)
	_move_on_floor(delta)


func _move_slide(delta: float) -> void:
	var horizontal: Vector3 = _friction(_horizontal_velocity(), settings.slide_friction, settings.stop_speed, delta)
	var speed_limit: float = maxf(horizontal.length(), settings.slide_max_speed)
	# The horizontal part of the floor normal has length sin(slope), so this adds g * sin(slope) downhill.
	var floor_normal: Vector3 = get_floor_normal()
	horizontal += Vector3(floor_normal.x, 0.0, floor_normal.z) * settings.gravity() * delta
	var speed: float = horizontal.length()
	var wish: Vector3 = _wish(1.0)
	if speed > 0.0 and wish != Vector3.ZERO:
		var heading: Vector3 = horizontal / speed
		var side: Vector3 = wish - heading * wish.dot(heading)
		horizontal = (heading * speed + side * settings.slide_steer_acceleration * delta).normalized() * speed
	velocity = horizontal.limit_length(speed_limit)
	_move_on_floor(delta)


func _move_air(delta: float) -> void:
	var air_speed: float = minf(_target_speed(), settings.air_max_wish_speed)
	var horizontal: Vector3 = _accelerate(_horizontal_velocity(), _wish(air_speed), settings.air_acceleration, delta)
	var vertical: float = velocity.y
	if _jump_cut_armed and not intent.jump_held:
		_jump_cut_armed = false
		if vertical > 0.0:
			vertical *= settings.jump_cut_multiplier
	if vertical <= 0.0:
		_jump_cut_armed = false
	var gravity: float = settings.gravity()
	if vertical <= 0.0:
		gravity *= settings.fall_gravity_multiplier
	# Half the gravity before the move and half after integrates the parabola exactly at any tick rate.
	velocity = Vector3(horizontal.x, vertical - gravity * delta * 0.5, horizontal.z)
	_impact_speed = maxf(-velocity.y, 0.0)
	move_and_slide()
	_on_floor = is_on_floor()
	velocity.y = maxf(velocity.y - gravity * delta * 0.5, -settings.terminal_fall_speed)


func _move_on_floor(delta: float) -> void:
	if _step_up(delta):
		_on_floor = true
		return
	move_and_slide()
	_on_floor = is_on_floor() or _step_down()


## Moves the body onto a step in the way of this tick's motion. Returns false and leaves the body in place if there is no step to climb.
## A slow body moves too little in one tick to see the step, so a probe of at least STEP_PROBE decides, and the real motion is then applied.
func _step_up(delta: float) -> bool:
	var motion: Vector3 = _horizontal_velocity() * delta
	if motion.length_squared() < 0.000001:
		return false
	var start: Transform3D = global_transform
	var hit: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	if not _test_motion(start, motion, hit) or _is_walkable(hit.get_collision_normal()):
		return false
	var base: float = _support_height(start)
	var raised: Transform3D = start
	raised.origin += _free_travel(start, Vector3.UP * (base - start.origin.y + settings.step_height + STEP_CLEARANCE))
	var depth: float = raised.origin.y - start.origin.y
	var probe: Vector3 = motion.normalized() * maxf(motion.length(), STEP_PROBE)
	var probe_hit: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	var probe_landing: Vector3 = _drop_onto_step(raised, probe, depth, probe_hit)
	if probe_hit.get_collision_count() == 0 or probe_landing.y - start.origin.y < MIN_STEP:
		return false
	if probe_hit.get_collision_point().y - base > settings.step_height + MIN_STEP or not _rests_on_walkable(probe_hit, probe_landing):
		return false
	var landing_hit: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	var landing: Vector3 = _drop_onto_step(raised, motion, depth, landing_hit)
	if landing_hit.get_collision_count() == 0 or landing.y < start.origin.y:
		return false
	global_position = landing
	_rig.add_step(landing.y - start.origin.y)
	return true


## The round bottom of the capsule can rest on an edge above the feet, so steps are measured from what the body stands on.
func _support_height(from: Transform3D) -> float:
	var hit: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	if _test_motion(from, Vector3.DOWN * STEP_CLEARANCE, hit):
		return maxf(hit.get_collision_point().y, from.origin.y)
	return from.origin.y


## Moves the capsule forward from raised, then down by at most depth. Returns where it stops. The hit has no collisions if nothing is under it.
func _drop_onto_step(raised: Transform3D, motion: Vector3, depth: float, hit: PhysicsTestMotionResult3D) -> Vector3:
	var ahead: Transform3D = raised
	ahead.origin += _free_travel(raised, motion)
	_test_motion(ahead, Vector3.DOWN * depth, hit)
	return ahead.origin + hit.get_travel()


## A capsule that walks off a step rolls on the step edge, where the contact is too steep to count as floor.
## If an edge or floor with a walkable top is within step height below, move down onto it and stay grounded.
func _step_down() -> bool:
	var hit: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	if not _test_motion(global_transform, Vector3.DOWN * (settings.step_height + STEP_CLEARANCE), hit):
		return false
	if not _rests_on_walkable(hit, global_position + hit.get_travel()):
		return false
	global_position += hit.get_travel()
	_rig.add_step(hit.get_travel().y)
	apply_floor_snap()
	return true


func _free_travel(from: Transform3D, motion: Vector3) -> Vector3:
	var hit: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	return hit.get_travel() if _test_motion(from, motion, hit) else motion


## The capsule can rest on an edge, where the contact normal is tilted.
## A short ray just past the edge, on the side away from the capsule center, reads the real top surface.
func _rests_on_walkable(hit: PhysicsTestMotionResult3D, center: Vector3) -> bool:
	if _is_walkable(hit.get_collision_normal()):
		return true
	var point: Vector3 = hit.get_collision_point()
	var outward: Vector3 = Vector3(point.x - center.x, 0.0, point.z - center.z).normalized()
	var probe: Vector3 = point + outward * 0.02 + Vector3.UP * 0.05
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 0.1, collision_mask, [get_rid()])
	var surface: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var normal: Vector3 = surface.get("normal", Vector3.DOWN)
	return _is_walkable(normal)


func _is_walkable(normal: Vector3) -> bool:
	return normal.angle_to(up_direction) <= floor_max_angle + 0.01


func _test_motion(from: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D) -> bool:
	var parameters: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	parameters.from = from
	parameters.motion = motion
	parameters.margin = safe_margin
	return PhysicsServer3D.body_test_motion(get_rid(), parameters, result)


static func _accelerate(horizontal: Vector3, wish: Vector3, acceleration: float, delta: float) -> Vector3:
	var wish_speed: float = wish.length()
	if wish_speed <= 0.0:
		return horizontal
	var direction: Vector3 = wish / wish_speed
	var missing: float = wish_speed - horizontal.dot(direction)
	if missing <= 0.0:
		return horizontal
	return horizontal + direction * minf(acceleration * wish_speed * delta, missing)


static func _friction(horizontal: Vector3, amount: float, stop_speed: float, delta: float) -> Vector3:
	var speed: float = horizontal.length()
	if speed <= 0.0:
		return horizontal
	var drop: float = maxf(speed, stop_speed) * amount * delta
	return horizontal * (maxf(speed - drop, 0.0) / speed)


func _pitch_sign() -> float:
	return -1.0 if invert_y else 1.0


func _update_mouse_capture(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()


func _register_default_actions() -> void:
	_add_default_action(&"move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_default_action(&"move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_default_action(&"move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_default_action(&"move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_default_action(&"jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add_default_action(&"sprint", [_key(KEY_SHIFT), _button(JOY_BUTTON_LEFT_STICK)])
	_add_default_action(&"crouch", [_key(KEY_CTRL), _key(KEY_C), _button(JOY_BUTTON_B)])
	_add_default_action(&"look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add_default_action(&"look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add_default_action(&"look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_default_action(&"look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])


static func _add_default_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	return event


# Device -1 matches every connected gamepad, like actions made in the editor.
static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	return event
