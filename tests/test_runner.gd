extends SceneTree

const TICK: float = 1.0 / 60.0

var checks: int = 0
var failures: int = 0
var jumps: int = 0
var landings: Array[float] = []
var transitions: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)


func measure(label: String, value: float, unit: String) -> void:
	print("MEASURE: %s = %.3f %s" % [label, value, unit])


func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func run() -> void:
	print("Physics engine setting: %s" % str(ProjectSettings.get_setting("physics/3d/physics_engine")))
	await test_ground_speed()
	await test_jump_height()
	await test_air_control()
	await test_coyote_time()
	await test_jump_buffer()
	await test_sprint_and_slide()
	await test_slide_jump_and_landing_slide()
	await test_stairs()
	await test_staircases()
	await test_ceiling()
	await test_slope_slide()
	await test_landed_signal()
	await test_camera_rig()
	await test_camera_on_stairs()
	await test_player_input()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func tuning() -> FPSSettings:
	var values: FPSSettings = FPSSettings.new()
	values.capsule_radius = 0.35
	values.stand_height = 1.8
	values.crouch_height = 1.1
	values.stand_eye_height = 1.65
	values.crouch_eye_height = 1.0
	values.step_height = 0.35
	values.floor_max_angle_degrees = 46.0
	values.walk_speed = 7.0
	values.sprint_speed = 10.5
	values.crouch_speed = 3.5
	values.ground_acceleration = 12.0
	values.ground_friction = 8.0
	values.stop_speed = 3.0
	values.jump_height = 1.25
	values.jump_time_to_apex = 0.32
	values.fall_gravity_multiplier = 1.35
	values.jump_cut_multiplier = 0.5
	values.coyote_time = 0.12
	values.jump_buffer_time = 0.12
	values.terminal_fall_speed = 50.0
	values.air_acceleration = 8.0
	values.air_max_wish_speed = 3.0
	values.slide_min_speed = 8.0
	values.slide_boost = 3.5
	values.slide_max_speed = 15.0
	values.slide_friction = 1.0
	values.slide_exit_speed = 4.0
	values.slide_cooldown = 0.6
	values.slide_steer_acceleration = 8.0
	values.base_fov = 90.0
	values.fov_kick_max = 12.0
	values.fov_kick_full_speed = 15.0
	values.fov_smoothing = 6.0
	values.strafe_roll_degrees = 2.0
	values.roll_smoothing = 8.0
	values.head_bob_enabled = true
	values.head_bob_amplitude = 0.035
	values.head_bob_frequency = 1.4
	values.eye_height_smoothing = 12.0
	values.step_smoothing = 14.0
	values.landing_dip_per_speed = 0.01
	values.landing_dip_max = 0.2
	values.landing_dip_frequency = 10.0
	return values


func make_level() -> Node3D:
	var level: Node3D = Node3D.new()
	root.add_child(level)
	add_box(level, Vector3(400.0, 1.0, 400.0), Vector3(0.0, -0.5, 0.0))
	return level


func add_box(level: Node3D, size: Vector3, center: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = box
	var body: StaticBody3D = StaticBody3D.new()
	body.add_child(shape)
	body.transform = Transform3D(basis, center)
	level.add_child(body)


func spawn(level: Node3D, values: FPSSettings, at: Vector3, facing: float) -> FPSController:
	var player: FPSController = FPSController.new()
	player.settings = values
	player.player_controlled = false
	level.add_child(player)
	player.teleport(at, facing)
	player.jumped.connect(func() -> void: jumps += 1)
	player.landed.connect(func(impact_speed: float) -> void: landings.append(impact_speed))
	player.move_state_changed.connect(func(previous: FPSController.MoveState, current: FPSController.MoveState) -> void:
		transitions.append("%s>%s" % [FPSController.MoveState.find_key(previous), FPSController.MoveState.find_key(current)]))
	return player


func clear_events() -> void:
	jumps = 0
	landings.clear()
	transitions.clear()


func finish(level: Node3D) -> void:
	level.queue_free()
	await physics_frame
	clear_events()


func press_jump(player: FPSController) -> void:
	player.intent.jump_pressed = true
	player.intent.jump_held = true


func wait_for_state(player: FPSController, state: FPSController.MoveState, limit: int) -> int:
	for tick: int in range(1, limit + 1):
		await physics_frame
		if player.move_state == state:
			return tick
	return -1


func test_ground_speed() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	check(player.move_state == FPSController.MoveState.GROUND and player.horizontal_speed() == 0.0, "Spawned body rests on the floor in GROUND with no speed")
	player.intent.move = Vector2(0.0, 1.0)
	var ticks_to_ninety: int = -1
	for tick: int in range(1, 31):
		await physics_frame
		if ticks_to_ninety < 0 and player.horizontal_speed() >= 6.3:
			ticks_to_ninety = tick
	measure("time to 90% walk speed", ticks_to_ninety * TICK, "s")
	check(ticks_to_ninety > 0 and ticks_to_ninety * TICK <= 0.15, "Holding forward from rest reaches 6.3 m/s (90% of 7.0) within 0.15 s")
	var start_z: float = player.global_position.z
	await frames(60)
	var covered: float = start_z - player.global_position.z
	measure("settled walk speed", player.horizontal_speed(), "m/s")
	check(absf(player.horizontal_speed() - 7.0) <= 0.14, "Holding forward settles within 2% of 7.0 m/s")
	check(absf(covered - 7.0) <= 0.14, "With yaw 0 the body covers 7.0 m toward -Z in one second of walking")
	player.intent.move = Vector2.ZERO
	var ticks_to_stop: int = -1
	for tick: int in range(1, 61):
		await physics_frame
		if player.horizontal_speed() < 0.01:
			ticks_to_stop = tick
			break
	measure("stop time from walk speed", ticks_to_stop * TICK, "s")
	check(ticks_to_stop > 0 and ticks_to_stop * TICK <= 0.25, "Releasing input stops the body from 7.0 m/s within 0.25 s")
	player.look(PI * 0.5, 0.0)
	player.intent.move = Vector2(0.0, 1.0)
	await frames(30)
	check(player.velocity.x < -6.5 and absf(player.velocity.z) < 0.1, "After look() turns 90 degrees left, forward input moves the body toward -X")
	await finish(level)


func test_jump_height() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	var start_y: float = player.global_position.y
	press_jump(player)
	var apex: float = 0.0
	var apex_tick: int = 0
	for tick: int in range(1, 61):
		await physics_frame
		var height: float = player.global_position.y - start_y
		if height > apex:
			apex = height
			apex_tick = tick
	measure("held jump apex", apex, "m")
	measure("held jump time to apex", apex_tick * TICK, "s")
	check(jumps == 1, "Jump press emits jumped once")
	check(absf(apex - 1.25) <= 0.0625, "Held jump peaks at 1.25 m within 5%")
	check(absf(apex_tick * TICK - 0.32) <= 0.034, "Held jump reaches its apex about 0.32 s after the press")
	check(player.move_state == FPSController.MoveState.GROUND, "Body is back in GROUND one second after the jump")
	player.intent.jump_held = false
	await frames(5)
	press_jump(player)
	await frames(3)
	player.intent.jump_held = false
	var tap_apex: float = 0.0
	for tick: int in range(1, 61):
		await physics_frame
		tap_apex = maxf(tap_apex, player.global_position.y - start_y)
	measure("tap jump apex (released after 0.05 s)", tap_apex, "m")
	check(tap_apex > 0.25 and tap_apex < 0.6, "Jump released after 0.05 s peaks between 0.25 m and 0.6 m, clearly below the 1.25 m held jump")
	player.intent.jump_pressed = true
	var bot_apex: float = 0.0
	for tick: int in range(1, 61):
		await physics_frame
		bot_apex = maxf(bot_apex, player.global_position.y - start_y)
	check(absf(bot_apex - 1.25) <= 0.0625, "A jump press with jump_held never set gives the full 1.25 m jump, because only a release cuts the jump")
	await finish(level)


func test_air_control() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	press_jump(player)
	var air_speed: float = 0.0
	for tick: int in range(90):
		await physics_frame
		if player.move_state != FPSController.MoveState.AIR:
			break
		air_speed = player.horizontal_speed()
	measure("air speed from a standing jump with forward held", air_speed, "m/s")
	check(air_speed >= 2.5, "Holding forward during a standing jump gives at least 2.5 m/s before landing")
	player.intent.sprint_held = true
	await frames(60)
	press_jump(player)
	await frames(1)
	player.intent.move = Vector2(1.0, 0.0)
	for tick: int in range(25):
		player.look(-0.02, 0.0)
		await physics_frame
	measure("air strafe speed after 25 ticks from 10.5 m/s", player.horizontal_speed(), "m/s")
	check(player.move_state == FPSController.MoveState.AIR and player.horizontal_speed() >= 11.0, "Strafing while turning in the air raises speed from 10.5 m/s to at least 11.0 m/s")
	await finish(level)


func test_coyote_time() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(10.0, 4.0, 10.0), Vector3(0.0, 2.0, 0.0))
	var player: FPSController = spawn(level, tuning(), Vector3(0.0, 4.0, 0.0), 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	var left_at: int = await wait_for_state(player, FPSController.MoveState.AIR, 120)
	check(left_at > 0 and jumps == 0, "Walking off a 4 m ledge enters AIR without a jump")
	await frames(3)
	press_jump(player)
	await frames(1)
	check(jumps == 1 and player.velocity.y > 0.0, "Jump pressed 0.05 s after leaving the ledge jumps (coyote time)")
	player.teleport(Vector3(0.0, 4.0, 0.0), 0.0)
	clear_events()
	await frames(5)
	left_at = await wait_for_state(player, FPSController.MoveState.AIR, 120)
	await frames(15)
	press_jump(player)
	await frames(2)
	check(jumps == 0 and player.velocity.y < 0.0, "Jump pressed 0.25 s after leaving the ledge does not jump")
	await wait_for_state(player, FPSController.MoveState.GROUND, 120)
	await frames(5)
	check(jumps == 0 and landings.size() == 1, "The late press expires before landing, so the landing does not jump")
	await finish(level)


func test_jump_buffer() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3(0.0, 2.5, 0.0), 0.0)
	check(player.move_state == FPSController.MoveState.AIR, "Teleport to 2.5 m above the floor starts in AIR")
	press_jump(player)
	await frames(1)
	player.intent.jump_held = false
	await wait_for_state(player, FPSController.MoveState.GROUND, 120)
	await frames(3)
	check(jumps == 0 and player.move_state == FPSController.MoveState.GROUND, "Jump pressed 0.39 s before landing is not kept until the landing")
	player.teleport(Vector3(0.0, 2.5, 0.0), 0.0)
	clear_events()
	var pressed: bool = false
	for tick: int in range(120):
		await physics_frame
		if not pressed and player.global_position.y < 0.45:
			press_jump(player)
			pressed = true
		if landings.size() > 0:
			break
	check(pressed and landings.size() == 1, "Body falls and lands once after the late press")
	await frames(2)
	check(jumps == 1 and player.velocity.y > 0.0, "Jump pressed just before landing jumps on the landing tick (jump buffer)")
	var rise: float = 0.0
	for tick: int in range(30):
		await physics_frame
		rise = maxf(rise, player.global_position.y)
	check(rise > 1.0, "The buffered jump rises above 1.0 m")
	await finish(level)


func test_sprint_and_slide() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(60)
	measure("sprint speed", player.horizontal_speed(), "m/s")
	check(absf(player.horizontal_speed() - 10.5) <= 0.21, "Sprint settles within 2% of 10.5 m/s")
	clear_events()
	player.intent.crouch_held = true
	await frames(1)
	check(player.move_state == FPSController.MoveState.SLIDE and player.stance == FPSController.Stance.CROUCH, "Crouch press at sprint speed starts a crouched SLIDE")
	var peak: float = player.horizontal_speed()
	measure("slide speed on the first tick", peak, "m/s")
	check(peak >= 13.5 and peak <= 14.0, "Slide boost lifts 10.5 m/s to between 13.5 and 14.0 m/s")
	var slide_ticks: int = await wait_for_state(player, FPSController.MoveState.GROUND, 240)
	measure("flat slide duration", slide_ticks * TICK, "s")
	check(slide_ticks > 30, "Slide lasts more than 0.5 s on flat ground")
	check(player.horizontal_speed() < 4.0, "Slide ends when speed drops below 4.0 m/s")
	check(transitions == ["GROUND>SLIDE", "SLIDE>GROUND"], "move_state_changed reports GROUND>SLIDE then SLIDE>GROUND")
	check(player.stance == FPSController.Stance.CROUCH, "Body stays crouched after the slide while crouch is held")
	player.intent.crouch_held = false
	player.intent.sprint_held = true
	await frames(60)
	clear_events()
	player.intent.crouch_held = true
	await frames(1)
	player.intent.crouch_held = false
	await frames(1)
	player.intent.crouch_held = true
	await frames(1)
	check(transitions == ["GROUND>SLIDE", "SLIDE>GROUND"], "A second crouch press inside the 0.6 s cooldown does not start a slide")
	await finish(level)


func test_slide_jump_and_landing_slide() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(60)
	player.intent.crouch_held = true
	await frames(5)
	clear_events()
	press_jump(player)
	await frames(1)
	var takeoff: float = player.horizontal_speed()
	await frames(15)
	measure("speed 0.25 s after a slide jump", player.horizontal_speed(), "m/s")
	check(transitions == ["SLIDE>AIR"] and player.horizontal_speed() > 12.5, "Jumping out of a slide carries more than 12.5 m/s into the air")
	check(absf(player.horizontal_speed() - takeoff) < 0.05, "Holding forward in the air after a slide jump loses no horizontal speed")
	await wait_for_state(player, FPSController.MoveState.SLIDE, 90)
	check(transitions == ["SLIDE>AIR", "AIR>SLIDE"] and landings.size() == 1, "Landing with crouch held at slide speed goes straight into SLIDE and emits landed")
	await finish(level)


func test_stairs() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(4.0, 0.3, 10.0), Vector3(0.0, 0.15, -8.0))
	add_box(level, Vector3(4.0, 0.35, 10.0), Vector3(10.0, 0.175, -8.0))
	add_box(level, Vector3(4.0, 0.6, 10.0), Vector3(20.0, 0.3, -8.0))
	var values: FPSSettings = tuning()
	var player: FPSController = spawn(level, values, Vector3(0.0, 0.0, 2.0), 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	var entered: int = -1
	var exited: int = -1
	var slowest: float = INF
	for tick: int in range(1, 121):
		await physics_frame
		var z: float = player.global_position.z
		if entered < 0 and z <= -2.0:
			entered = tick
		if entered > 0 and exited < 0:
			slowest = minf(slowest, player.horizontal_speed())
		if exited < 0 and z <= -4.0:
			exited = tick
	var crossing_speed: float = 2.0 / ((exited - entered) * TICK) if exited > entered else 0.0
	measure("average speed across a 0.3 m step", crossing_speed, "m/s")
	measure("slowest speed across a 0.3 m step", slowest, "m/s")
	check(absf(player.global_position.y - 0.3) < 0.02, "Walking into a 0.3 m step ends on top of it")
	check(crossing_speed >= 5.6, "Crossing the 0.3 m step averages at least 5.6 m/s (80% of 7.0)")
	check(transitions.is_empty(), "Climbing the 0.3 m step never leaves GROUND")
	player.teleport(Vector3(0.0, 0.3, -8.0), PI)
	clear_events()
	await frames(60)
	check(absf(player.global_position.y) < 0.02 and transitions.is_empty(), "Walking down off the 0.3 m step stays in GROUND and ends on the floor")
	player.teleport(Vector3(10.0, 0.0, 2.0), 0.0)
	player.intent.crouch_held = true
	clear_events()
	await frames(120)
	check(absf(player.global_position.y - 0.35) < 0.02 and transitions.is_empty(), "Crouch walking into a 0.35 m step climbs it")
	player.intent.crouch_held = false
	player.teleport(Vector3(20.0, 0.0, 2.0), 0.0)
	await frames(120)
	check(player.global_position.y < 0.05 and player.global_position.z > -2.7, "A 0.6 m step blocks the body")
	await finish(level)


func add_staircase(level: Node3D, x: float, riser: float, tread: float, count: int) -> void:
	for step: int in range(count):
		var height: float = riser * (step + 1)
		add_box(level, Vector3(3.0, height, tread), Vector3(x, height * 0.5, -3.0 - tread * (step + 0.5)))
	var top: float = riser * count
	add_box(level, Vector3(3.0, top, 6.0), Vector3(x, top * 0.5, -6.0 - tread * count))


func test_staircases() -> void:
	var level: Node3D = make_level()
	add_staircase(level, 0.0, 0.2, 0.3, 8)
	add_staircase(level, 5.0, 0.35, 0.35, 5)
	var player: FPSController = spawn(level, tuning(), Vector3(0.0, 0.0, 0.0), 0.0)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.crouch_held = true
	await frames(180)
	check(absf(player.global_position.y - 1.6) < 0.02 and transitions.is_empty(), "Crouch walking climbs eight 0.2 m steps with 0.3 m treads to 1.6 m without leaving GROUND")
	player.intent.crouch_held = false
	player.teleport(Vector3(5.0, 1.75, -6.0), PI)
	clear_events()
	await frames(90)
	check(absf(player.global_position.y) < 0.02 and transitions.is_empty(), "Walking down five 0.35 m steps with 0.35 m treads stays in GROUND to the floor")
	player.teleport(Vector3(1.5, 0.0, 0.0), deg_to_rad(-30.0))
	var highest: float = 0.0
	for tick: int in range(90):
		await physics_frame
		highest = maxf(highest, player.global_position.y)
	check(absf(highest - 1.75) < 0.02, "Walking at 30 degrees into the corner of the 0.35 m staircase climbs it from the side to 1.75 m")
	await finish(level)


func test_ceiling() -> void:
	var level: Node3D = make_level()
	add_box(level, Vector3(4.0, 0.3, 6.0), Vector3(0.0, 1.45, -6.0))
	var player: FPSController = spawn(level, tuning(), Vector3.ZERO, 0.0)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.crouch_held = true
	await frames(75)
	check(player.global_position.z < -3.4 and player.stance == FPSController.Stance.CROUCH, "Crouched body walks under the 1.3 m ceiling")
	player.intent.crouch_held = false
	await frames(10)
	check(player.stance == FPSController.Stance.CROUCH and absf(player.global_position.y) < 0.02, "Releasing crouch under the ceiling keeps the body crouched on the floor")
	for tick: int in range(150):
		await physics_frame
		if player.global_position.z < -9.5:
			break
	await frames(2)
	check(player.global_position.z < -9.5 and player.stance == FPSController.Stance.STAND, "Body stands up after it clears the ceiling")
	await finish(level)


func slide_speed_after(level: Node3D, at: Vector3, facing: float) -> float:
	var player: FPSController = spawn(level, tuning(), at, facing)
	await frames(5)
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(30)
	player.intent.crouch_held = true
	await frames(30)
	return player.horizontal_speed() if player.move_state == FPSController.MoveState.SLIDE else 0.0


func test_slope_slide() -> void:
	var flat: Node3D = make_level()
	var flat_speed: float = await slide_speed_after(flat, Vector3.ZERO, 0.0)
	await finish(flat)
	var hill: Node3D = make_level()
	var slope: float = deg_to_rad(20.0)
	add_box(hill, Vector3(6.0, 1.0, 40.0), Vector3(0.0, 0.0, 0.0), Basis(Vector3.RIGHT, slope))
	var top_z: float = -15.0
	var top_y: float = -top_z * tan(slope) + 0.5 / cos(slope)
	var ramp_speed: float = await slide_speed_after(hill, Vector3(0.0, top_y + 0.05, top_z), PI)
	measure("flat slide speed after 0.5 s", flat_speed, "m/s")
	measure("20 degree downhill slide speed after 0.5 s", ramp_speed, "m/s")
	check(flat_speed > 4.0 and ramp_speed > flat_speed + 1.5, "Sliding 0.5 s down a 20 degree ramp keeps at least 1.5 m/s more speed than on flat ground")
	await finish(hill)


func test_landed_signal() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3(0.0, 2.0, 0.0), 0.0)
	await frames(60)
	measure("impact speed after a 2 m drop", landings[0] if landings.size() > 0 else 0.0, "m/s")
	check(landings.size() == 1 and landings[0] > 10.5 and landings[0] < 12.5, "A 2 m drop emits landed once with an impact speed near 11.5 m/s")
	press_jump(player)
	await frames(60)
	check(landings.size() == 2 and landings[1] > 8.0, "A jump from the floor emits landed once more with a positive impact speed")
	await finish(level)


func test_camera_rig() -> void:
	var level: Node3D = make_level()
	var player: FPSController = spawn(level, tuning(), Vector3(3.0, 0.0, 4.0), 0.0)
	check(player.camera.global_position.distance_to(Vector3(3.0, 1.65, 4.0)) < 0.01, "Spawn teleport places the camera at eye height with no smoothing")
	await frames(30)
	player.teleport(Vector3(-20.0, 0.0, 10.0), 0.0)
	check(player.camera.global_position.distance_to(Vector3(-20.0, 1.65, 10.0)) < 0.01, "A second teleport moves the camera at once")
	await frames(60)
	var idle_fov: float = player.camera.fov
	measure("idle vertical FOV", idle_fov, "deg")
	check(absf(idle_fov - 58.72) < 0.1, "Standing still settles at 90 degrees horizontal FOV, 58.72 degrees vertical at 16:9")
	player.intent.move = Vector2(0.0, 1.0)
	player.intent.sprint_held = true
	await frames(90)
	var sprint_fov: float = player.camera.fov
	measure("sprint vertical FOV", sprint_fov, "deg")
	check(sprint_fov > 62.5, "Sprinting at 10.5 m/s widens the vertical FOV above 62.5 degrees")
	var offset: Vector3 = player.camera.global_position - player.global_position
	check(Vector2(offset.x, offset.z).length() < 0.25 and offset.y > 1.55 and offset.y < 1.75, "Camera follows the moving body at about 1.65 m eye height")
	player.intent.move = Vector2.ZERO
	player.intent.crouch_held = true
	await frames(60)
	offset = player.camera.global_position - player.global_position
	check(absf(offset.y - 1.0) < 0.05, "Crouching lowers the camera to 1.0 m eye height")
	await finish(level)


func test_camera_on_stairs() -> void:
	var level: Node3D = make_level()
	add_staircase(level, 0.0, 0.3, 0.6, 20)
	var values: FPSSettings = tuning()
	# The head bob moves the camera down on purpose, so it is off to isolate the step.
	values.head_bob_enabled = false
	var player: FPSController = spawn(level, values, Vector3.ZERO, 0.0)
	await frames(5)
	var previous_max_fps: int = Engine.max_fps
	Engine.max_fps = 240
	player.intent.move = Vector2(0.0, 1.0)
	var start_tick: int = Engine.get_physics_frames()
	var last_y: float = player.camera.global_position.y
	var worst_drop: float = 0.0
	var samples: int = 0
	while player.global_position.z > -16.5 and Engine.get_physics_frames() - start_tick < 240:
		await process_frame
		var y: float = player.camera.global_position.y
		worst_drop = maxf(worst_drop, last_y - y)
		last_y = y
		samples += 1
	var ticks: int = Engine.get_physics_frames() - start_tick
	Engine.max_fps = previous_max_fps
	measure("rendered frames while climbing twenty 0.3 m steps", samples, "frames")
	measure("physics ticks while climbing twenty 0.3 m steps", ticks, "ticks")
	measure("worst camera drop in one frame while climbing", worst_drop, "m")
	check(absf(player.global_position.y - 6.0) < 0.02, "Walking up twenty 0.3 m steps with 0.6 m treads reaches the 6.0 m top")
	check(samples > ticks, "At a 240 FPS cap more frames render than physics ticks run, so frames fall between ticks")
	check(worst_drop <= 0.01, "While the body climbs, no rendered frame moves the camera down by more than 0.01 m")
	await finish(level)


func test_player_input() -> void:
	var level: Node3D = make_level()
	var player: FPSController = FPSController.new()
	player.settings = tuning()
	player.manage_mouse_capture = false
	level.add_child(player)
	player.teleport(Vector3.ZERO, 0.0)
	check(InputMap.action_get_events(&"crouch").size() == 3 and InputMap.action_get_events(&"look_right").size() == 1, "The controller registers the default actions: crouch has three events and look_right has one")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await frames(60)
	check(absf(player.horizontal_speed() - 10.5) <= 0.21 and player.velocity.z < -10.0, "Held move_forward and sprint actions drive a player-controlled body at 10.5 m/s toward -Z")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	Input.action_press(&"look_right")
	await frames(30)
	Input.action_release(&"look_right")
	var turned: float = rad_to_deg(-player.yaw)
	measure("gamepad turn in 0.5 s at full stick", turned, "deg")
	check(turned > 100.0 and turned < 140.0, "Full right stick turns the view right by about 120 degrees in 0.5 s (240 degrees per second)")
	await finish(level)
