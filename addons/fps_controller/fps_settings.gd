class_name FPSSettings
extends Resource

@export_group("Body")
@export_range(0.1, 1.0, 0.01, "suffix:m") var capsule_radius: float = 0.35
@export_range(0.5, 3.0, 0.01, "suffix:m") var stand_height: float = 1.8
@export_range(0.5, 3.0, 0.01, "suffix:m") var crouch_height: float = 1.1
@export_range(0.1, 3.0, 0.01, "suffix:m") var stand_eye_height: float = 1.65
@export_range(0.1, 3.0, 0.01, "suffix:m") var crouch_eye_height: float = 1.0
@export_range(0.0, 1.0, 0.01, "suffix:m") var step_height: float = 0.35
@export_range(1.0, 89.0, 0.5, "suffix:°") var floor_max_angle_degrees: float = 46.0

@export_group("Ground")
@export_range(0.1, 50.0, 0.1, "suffix:m/s") var walk_speed: float = 7.0
@export_range(0.1, 50.0, 0.1, "suffix:m/s") var sprint_speed: float = 10.5
@export_range(0.1, 50.0, 0.1, "suffix:m/s") var crouch_speed: float = 3.5
@export_range(0.0, 100.0, 0.1) var ground_acceleration: float = 12.0
@export_range(0.0, 100.0, 0.1) var ground_friction: float = 8.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var stop_speed: float = 3.0

@export_group("Jump")
@export_range(0.05, 10.0, 0.01, "suffix:m") var jump_height: float = 1.25
@export_range(0.05, 2.0, 0.01, "suffix:s") var jump_time_to_apex: float = 0.32
@export_range(1.0, 5.0, 0.05) var fall_gravity_multiplier: float = 1.35
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.01, "suffix:s") var coyote_time: float = 0.12
@export_range(0.0, 1.0, 0.01, "suffix:s") var jump_buffer_time: float = 0.12
@export_range(1.0, 200.0, 0.5, "suffix:m/s") var terminal_fall_speed: float = 50.0

@export_group("Air")
@export_range(0.0, 100.0, 0.1) var air_acceleration: float = 10.0
@export_range(0.0, 50.0, 0.1, "suffix:m/s") var air_max_wish_speed: float = 5.0

@export_group("Slide")
@export_range(0.0, 50.0, 0.1, "suffix:m/s") var slide_min_speed: float = 8.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var slide_boost: float = 3.5
@export_range(0.0, 50.0, 0.1, "suffix:m/s") var slide_max_speed: float = 15.0
@export_range(0.0, 50.0, 0.1, "suffix:m/s²") var slide_deceleration: float = 6.5
@export_range(0.0, 50.0, 0.1, "suffix:m/s") var slide_exit_speed: float = 4.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var slide_cooldown: float = 0.6
@export_range(0.0, 100.0, 0.1, "suffix:m/s²") var slide_steer_acceleration: float = 8.0

@export_group("Camera")
## Horizontal field of view on a 16:9 screen. Wider screens see more to the sides.
@export_range(30.0, 150.0, 0.5, "suffix:°") var base_fov: float = 90.0
@export_range(0.0, 40.0, 0.5, "suffix:°") var fov_kick_max: float = 12.0
## Horizontal speed that gives the full FOV kick. The kick starts at walk speed.
@export_range(0.1, 100.0, 0.1, "suffix:m/s") var fov_kick_full_speed: float = 15.0
@export_range(0.1, 50.0, 0.1) var fov_smoothing: float = 6.0
@export_range(0.0, 10.0, 0.1, "suffix:°") var strafe_roll_degrees: float = 2.0
@export_range(0.1, 50.0, 0.1) var roll_smoothing: float = 8.0
@export var head_bob_enabled: bool = true
@export_range(0.0, 0.2, 0.001, "suffix:m") var head_bob_amplitude: float = 0.035
## Full left-right bob cycles per second at walk speed. Scales with speed.
@export_range(0.1, 5.0, 0.05, "suffix:Hz") var head_bob_frequency: float = 1.4
@export_range(0.1, 50.0, 0.1) var eye_height_smoothing: float = 12.0
@export_range(0.1, 50.0, 0.1) var step_smoothing: float = 14.0
@export_range(0.0, 0.1, 0.001, "suffix:m/(m/s)") var landing_dip_per_speed: float = 0.01
@export_range(0.0, 1.0, 0.01, "suffix:m") var landing_dip_max: float = 0.2
@export_range(1.0, 40.0, 0.5, "suffix:rad/s") var landing_dip_frequency: float = 10.0


func gravity() -> float:
	return 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)


func jump_velocity() -> float:
	return 2.0 * jump_height / jump_time_to_apex
