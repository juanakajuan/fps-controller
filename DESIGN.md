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
| Camera smoothness | Camera code runs in physics tick or mixes clocks in one file | Rig interpolates the body position each rendered frame | Same problem as A |
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
@export var gamepad_look_exponent: float # stick response curve, 1 is linear
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

One `match move_state` in `_transition()`, then one `match move_state` for the move. Timers are floats that count down: `_coyote_left`, `_jump_buffer_left`, `_slide_cooldown_left`.

"On floor" in the table is the `_on_floor` flag from the last move, not `is_on_floor()`. In AIR, the flag is `is_on_floor()` after `move_and_slide()`. In GROUND and SLIDE, the flag is true when `_step_up()` climbs a step. Otherwise it is `is_on_floor()` after `move_and_slide()`, or the result of `_step_down()`.

| From | Condition | To | Effect |
|---|---|---|---|
| GROUND | buffered jump | AIR | jump velocity, emit `jumped` |
| GROUND | not on floor | AIR | start coyote timer |
| GROUND | crouch pressed, speed >= `slide_min_speed`, cooldown done | SLIDE | add `slide_boost` up to `slide_max_speed` |
| AIR | on floor, buffered jump | AIR | emit `landed`, then jump with no friction tick (bunny hop) |
| AIR | on floor, crouch held, speed >= `slide_min_speed` | SLIDE | emit `landed`, no boost |
| AIR | on floor | GROUND | emit `landed` |
| AIR | buffered jump, coyote time left | AIR | jump |
| SLIDE | buffered jump | AIR | jump, keep horizontal momentum |
| SLIDE | not on floor | AIR | start coyote timer |
| SLIDE | speed < `slide_exit_speed` or crouch released | GROUND | |

Each exit from SLIDE starts the slide cooldown. A state change emits `move_state_changed`. A bunny hop stays in AIR, so it emits no state change.

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

- GROUND: friction with `ground_friction` and `stop_speed` (3.0 m/s), then accelerate to walk, sprint, or crouch speed. A stop from walk speed takes 0.23 s.
- AIR: no friction, accelerate with `air_acceleration` and `air_max_wish_speed`. The dot-product rule allows air strafing.
- SLIDE: a constant deceleration, not friction, so the speed loss does not grow with speed:

```
slide():
	velocity_h = velocity_h.move_toward(ZERO, slide_deceleration * delta)
	limit = max(velocity_h.length(), slide_max_speed)
	velocity_h += floor_normal_h * gravity * delta   # length g * sin(slope), downhill
	velocity_h = velocity_h turned toward the input, same length
	velocity_h = velocity_h.limit_length(limit)
```

With the defaults (`slide_deceleration` 6.5 m/s², gravity 24.4 m/s²), a slide gets faster down a slope steeper than asin(6.5 / 24.4) = 15.4 degrees. On flat floor, a slide from 13.9 m/s drops below `slide_exit_speed` (4.0 m/s) after 1.55 s. The cap applies only to the slope gain, so a slide that starts above `slide_max_speed` keeps its speed and loses only the deceleration. Steering turns the slide and adds no speed.

- Gravity comes from jump height and time to apex: `gravity = 2h / t^2`, `jump_velocity = 2h / t`. Falling uses `gravity * fall_gravity_multiplier`. AIR applies half the gravity of a tick before `move_and_slide()` and half after it, so the rise follows the exact parabola at any tick rate.
- A release of jump while the body rises multiplies vertical velocity by `jump_cut_multiplier`. Only a release cuts the jump. A jump that starts with `jump_held` false has the full height.

## Stairs

GROUND and SLIDE move through `_move_on_floor()`. It tries `_step_up()` first. If no step is climbed, it calls `move_and_slide()`, and then `_step_down()` if the body is not on the floor. All tests use `PhysicsServer3D.body_test_motion` with `PhysicsTestMotionParameters3D`.

`_step_up()`:

1. Test the horizontal motion of this tick. If it hits nothing, or it hits a walkable slope, there is no step.
2. Find the support height. It is the contact point of a 0.05 m test motion down, or the body origin if that is higher. The round bottom of the capsule can rest on an edge above the feet, so the step height is measured from what the body stands on, not from the body origin.
3. Raise the capsule to `step_height + 0.05` above the support height, or less if a ceiling stops it. The 0.05 m clearance keeps the capsule above the top edge of a step of exactly `step_height`.
4. Probe: from the raised position, move forward by the motion, but by at least 0.1 m, then sweep down. A slow body moves too little in one tick to get past the step edge, so the probe decides if a step is there. The step is rejected if nothing is under the probe, if the probe lands less than 0.01 m above the start, if the contact is more than `step_height` plus 0.01 m above the support height, or if the top is not walkable.
5. Do the same move with the real motion. If it lands at or above the start, put the body there, send the height change to the rig with `add_step()`, and skip `move_and_slide()` for this tick.

`_step_down()` tests a motion down by `step_height + 0.05`. If it finds a walkable top, it moves the body onto it, sends the height change to the rig, and calls `apply_floor_snap()`. A capsule that walks off a step rolls on the step edge, where the contact normal is too steep to count as floor. `floor_snap_length = step_height` alone does not keep the body on the floor there.

A walkable top is a contact normal within `floor_max_angle`. If the capsule rests on an edge, the contact normal is tilted. Then a 0.1 m ray down, 0.02 m past the contact point on the side away from the capsule center, reads the real top surface.

## Camera rig

`top_level = true` and `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF`. The rig interpolates the body position itself. It does not use `get_global_transform_interpolated()`.

```
add_step(h):           # the body calls it when _step_up() or _step_down() moves it by h
	pending_step += h

record_tick():         # the body calls it at the end of _physics_process()
	previous_origin = current_origin + (0, pending_step, 0)
	current_origin = body.global_position
	step_offset -= pending_step
	pending_step = 0

_process(delta):
	origin = previous_origin.lerp(current_origin, Engine.get_physics_interpolation_fraction())
	eye_height = smooth toward stance eye height
	step_offset = decay toward 0
	rig transform = yaw basis at origin + (0, eye_height + step_offset, 0)
	camera.transform = basis from pitch and strafe roll, at head bob + landing dip spring
	camera.fov = smooth toward the vertical FOV for base_fov + speed-scaled kick
```

The body calls `record_tick()` directly, so the result does not depend on the order in which child nodes process. A step goes into the previous origin, so the lerp does not spread it over the next tick. Only the `step_offset` decay smooths a step, so a step up never moves the camera down. `snap()` puts both origins at the body position and every smoothed value on its target. `_ready()` and `teleport()` call it.

`Engine.get_physics_interpolation_fraction()` is valid with `physics/common/physics_interpolation` on or off, so the camera is smooth in both cases.

The rig basis is yaw only. Pitch, roll, head bob, and landing dip are on the camera, so the bob and the dip stay vertical when the player looks up or down. `base_fov` is the horizontal FOV at 16:9. `Camera3D.fov` is vertical with `KEEP_HEIGHT`, so the rig converts the value at the 16:9 reference, and a wider screen shows more at the sides (Hor+).

All smoothing uses `1.0 - exp(-rate * delta)` so it does not depend on frame rate. The landing dip uses an exact step of a critically damped spring.

Mouse look applies in `_unhandled_input` from `InputEventMouseMotion.screen_relative`, so window stretch does not change sensitivity and look has no tick delay. Gamepad look applies in the body's `_process`, which runs before the rig's `_process`, with the stick curved by `gamepad_look_exponent`.

## Boundaries

- Input: `Input` and `InputMap` are read only in `_read_intent()`, `_unhandled_input`, and `_process` (gamepad look). Missing default actions register in `_ready`. Existing actions are not changed.
- Settings: `FPSSettings` validates ranges with `@export_range`. If `settings` is null, the controller makes `FPSSettings.new()`.
- Physics interpolation: the camera does not need `physics/common/physics_interpolation`. The controller does not warn when it is off. Other moving bodies in a game still need it for smooth motion. `teleport()` calls `reset_physics_interpolation()`, so a node that a user attaches to the body does not move across the gap.
- Teleport: `teleport()` sets the speed to zero, sets `yaw`, and sets `pitch` to zero. Then it settles the body: a zero-motion `move_and_slide()` and `apply_floor_snap()` find the floor, the state becomes GROUND or AIR with no `landed` signal, and the rig snaps.
- Camera: the camera becomes current only when `player_controlled` is true, so a bot does not take the view from the player.

## Verification plan

Headless tests drive real physics through `intent` with `player_controlled = false`, and each test builds its own `FPSSettings` with explicit values, so the expected values are literals in the test. The suite runs on Jolt Physics and on Godot Physics. One test caps the frame rate at 240 FPS and reads the camera height on each rendered frame while the body climbs twenty 0.3 m steps.

## Accepted deviations

The code differs from the first version of this design in the ways below. Each deviation was accepted by the lead in review.

- Stairs use a forward probe of at least 0.1 m, an edge ray, a step height from the support point, a raise of `step_height + 0.05`, and `_step_down()`. Without the probe minimum, a crouch walk does not climb 0.2 m steps. Without the edge ray, a crouch walk does not climb a 0.35 m step, and a walk down stairs enters AIR. Without the support point, a walk at 30 degrees into the corner of a staircase does not climb it. Without `_step_down()`, a walk down stairs enters AIR. The 0.05 m in the raise is a margin above the top edge of a step of exactly `step_height`. No test fails without it.
- The `_on_floor` flag replaces `is_on_floor()` in the state machine. A climbed step skips `move_and_slide()`, and `_step_down()` finds floor that `move_and_slide()` did not find, so `is_on_floor()` is wrong after both.
- Coyote time also starts on SLIDE to AIR, so a slide off a ledge gives the same late jump as a walk off a ledge.
- Gamepad look is read in `_process`, so stick look has no tick delay.
- The rig basis is yaw only, and pitch, roll, bob, and dip are on the camera, so the bob and the dip stay vertical when the player looks up or down.
- `base_fov` is horizontal at 16:9 (Hor+), so a wider screen shows more at the sides and does not lose the top and bottom of the view.
- Gravity is applied half before and half after the move, so the rise follows the exact parabola at any tick rate.
- Only a release cuts the jump, so a buffered press that was released before the landing, or a bot that does not set `jump_held`, still gets the full jump.
- `teleport()` resets pitch and settles on the floor, so a spawn starts level and in the correct state with no `landed` signal.
- The camera becomes current only when `player_controlled` is true, so a bot does not take the view from the player.
- Slide details: the cap applies only to the slope gain, so speed from air strafing is not cut. Steering adds no speed, so input cannot push a slide faster. A landing slide has no boost, so a chain of slide jumps cannot add the boost on each landing. The cooldown starts when the slide ends, so a long slide cannot chain into a new boost.
- `gamepad_look_exponent` (default 2.0) curves the stick, so small stick motions give fine aim.
- `stop_speed` is 3.0 m/s, so a stop from walk speed takes 0.23 s, inside the 0.25 s limit of the stop test.

The constant slide deceleration and the rig interpolation are not deviations. The lead asked for them in review, and the sections above describe them.
