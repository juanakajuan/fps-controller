# FPS controller design

## Goal

A drop-in first-person controller for Godot 4.7 with fast, smooth movement. A user copies `addons/fps_controller/` into a project, adds an `FPSController` node to a level, and plays. All tuning is in one `FPSSettings` resource.

Usage the design must support:

```gdscript
# Player: add the node, done. Default input actions register if missing.
var player: FPSController = FPSController.new()
player.settings = preload("res://my_fast_preset.tres")  # optional
level.add_child(player)
player.teleport(spawn.global_position, spawn.global_rotation.y)

# Weapon or viewmodel: attach to the camera.
player.camera.add_child(gun)

# Sound and effects: typed signals.
player.jumped.connect(play_jump_sound)
player.landed.connect(func(impact_speed: float) -> void: ...)
player.move_state_changed.connect(func(previous: FPSController.MoveState, current: FPSController.MoveState) -> void: ...)

# AI, replays, or tests: drive the same body without the Input singleton.
bot.player_controlled = false
bot.intent.move = Vector2(0.0, 1.0)
bot.intent.jump_pressed = true
bot.look(delta_yaw, delta_pitch)
```

## Candidates

| | A. One script | B. Body + camera rig + settings | C. Node state machine |
|---|---|---|---|
| Shape | One `CharacterBody3D` script owns input, movement, camera effects | Body script owns input parse, state machine, movement. Separate camera rig node runs at render rate. One settings resource. | One child node per state, a manager node switches between them |
| Camera smoothness | Camera code runs in physics tick or mixes clocks in one file | Rig reads the interpolated body transform each rendered frame | Same problem as A |
| Testability | Tests drive real physics | Tests drive real physics through `intent`, no Input singleton | Tests must know the node tree |
| Reader load | One long file | Three files, each with one clock and one job | Many small files, logic spread across nodes |

Choice: **B**. The body runs on the physics clock and the camera runs on the render clock. That split is real, so it gets its own node. C adds indirection for three states and removes no branches. A forces the reader to track which code runs on which clock.

## Files

- `addons/fps_controller/fps_settings.gd`. `class_name FPSSettings extends Resource`. All tuning, grouped with `@export_group`. The only source of truth for sizes and speeds.
- `addons/fps_controller/fps_controller.gd`. `class_name FPSController extends CharacterBody3D`. Builds its own children from settings. Parses input into `Intent`. Runs the move state machine. Steps up stairs.
- `addons/fps_controller/fps_camera_rig.gd`. `class_name FPSCameraRig extends Node3D`. Top-level node. Places the camera every rendered frame from the interpolated body position plus look angles plus feel effects.
- `demo/demo.tscn` and `demo/demo_level.gd`. A test level built in code: flat floor, stairs, a ramp, gaps, ledges, a low ceiling, boxes.
- `tests/test_runner.gd`. Headless physics integration tests.
- `tests/visual_smoke.gd`. Windowed launch that captures one viewport frame.

## Data shapes

```gdscript
class_name FPSController extends CharacterBody3D

enum MoveState { GROUND, AIR, SLIDE }
enum Stance { STAND, CROUCH }

class Intent:
	var move: Vector2 = Vector2.ZERO   # x right, y forward, length <= 1
	var jump_pressed: bool = false     # true for one tick on press
	var jump_held: bool = false
	var sprint_held: bool = false
	var crouch_held: bool = false

signal jumped
signal landed(impact_speed: float)
signal move_state_changed(previous: MoveState, current: MoveState)

@export var settings: FPSSettings
@export var player_controlled: bool = true
@export var manage_mouse_capture: bool = true
@export var mouse_sensitivity: float     # degrees per screen pixel
@export var gamepad_look_speed: float    # degrees per second at full stick
@export var invert_y: bool = false

var intent: Intent
var yaw: float      # radians, the only source of horizontal facing
var pitch: float    # radians, clamped
var move_state: MoveState
var stance: Stance
var camera: Camera3D

func look(delta_yaw: float, delta_pitch: float) -> void
func teleport(target_position: Vector3, target_yaw: float) -> void
func horizontal_speed() -> float
```

The body never rotates. Facing is `yaw` only. The capsule is round, so body rotation adds nothing and would put mouse look behind physics interpolation.

## State machine

One `match move_state` in `_physics_process`. Timers are floats that count down: `coyote_left`, `jump_buffer_left`, `slide_cooldown_left`.

| From | Condition | To | Effect |
|---|---|---|---|
| GROUND | buffered jump | AIR | jump velocity, emit `jumped` |
| GROUND | not on floor | AIR | start coyote timer |
| GROUND | crouch pressed, speed >= `slide_min_speed`, cooldown done | SLIDE | add `slide_boost` up to `slide_max_speed` |
| AIR | on floor, buffered jump | AIR | jump again with no friction tick (bunny hop) |
| AIR | on floor, crouch held, speed >= `slide_min_speed` | SLIDE | land into slide, emit `landed` |
| AIR | on floor | GROUND | emit `landed` |
| AIR | buffered jump, coyote time left | AIR | jump |
| SLIDE | buffered jump | AIR | jump, keep horizontal momentum |
| SLIDE | speed < `slide_exit_speed` or crouch released | GROUND | |
| SLIDE | not on floor | AIR | |

Stance is CROUCH while crouch is held, while in SLIDE, or while a ceiling blocks standing. Stance sets the capsule height. The capsule shrinks from the top, so the feet stay on the floor.

## Movement model

Quake-style acceleration and friction, in m/s:

```
accelerate(wish_dir, wish_speed, accel):
	add = wish_speed - velocity_h.dot(wish_dir)
	if add > 0: velocity_h += wish_dir * min(accel * wish_speed * delta, add)

friction(amount):
	speed = velocity_h.length()
	drop = max(speed, stop_speed) * amount * delta
	velocity_h *= max(speed - drop, 0) / speed
```

- GROUND: friction, then accelerate to walk, sprint, or crouch speed.
- AIR: no friction, accelerate with `air_acceleration` and `air_max_wish_speed`. The dot-product rule allows air strafing.
- SLIDE: `slide_friction`, gravity along the floor slope speeds the slide downhill, steering with `slide_steer_acceleration`.
- Gravity comes from jump height and time to apex: `gravity = 2h / t^2`, `jump_velocity = 2h / t`. Falling uses `gravity * fall_gravity_multiplier`. Release jump while rising to multiply vertical velocity by `jump_cut_multiplier`.

## Stairs

Before `move_and_slide` in GROUND and SLIDE: if the horizontal motion for this tick hits something, test the motion again from `step_height` higher, then sweep down to the floor. If the landing floor angle is <= `floor_max_angle`, move the body to the landing point and send the height change to the camera rig as an offset that decays to zero. Use `PhysicsServer3D.body_test_motion` with `PhysicsTestMotionParameters3D`. Going down stairs uses `floor_snap_length = step_height`.

## Camera rig

`top_level = true` and `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF`. In `_process`:

```
origin = body.get_global_transform_interpolated().origin
eye_height = smooth toward stance eye height
step_offset = decay toward 0
basis = yaw, pitch, roll from strafe tilt
camera.fov = smooth toward base_fov + speed-scaled kick
camera.position = head bob + landing dip spring
```

All smoothing uses `1.0 - exp(-rate * delta)` so it does not depend on frame rate.

Mouse look applies in `_unhandled_input` from `InputEventMouseMotion.screen_relative`, so window stretch does not change sensitivity and look has no tick delay.

## Boundaries

- Input: `Input` and `InputMap` are read only in `_read_intent()` and `_unhandled_input`. Missing default actions register in `_ready`. Existing actions are not changed.
- Settings: `FPSSettings` validates ranges with `@export_range`. If `settings` is null, the controller makes `FPSSettings.new()`.
- Physics interpolation: if `physics/common/physics_interpolation` is off, `_ready` pushes one warning, because the camera then moves at the physics rate.

## Verification plan

Headless tests drive real physics through `intent` with `player_controlled = false`, and each test builds its own `FPSSettings` with explicit values, so the expected values are literals in the test. The suite runs on Jolt Physics and on Godot Physics.
