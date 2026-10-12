# FPS controller for Godot 4.7

This addon is a first-person controller for fast movement. It is written in GDScript only. The body moves on the physics tick. The camera moves on each rendered frame. All tuning values are in one `FPSSettings` resource.

The addon has three scripts:

- `fps_controller.gd` (`FPSController`) is the `CharacterBody3D`. It reads input, runs the move state machine, and climbs stairs.
- `fps_camera_rig.gd` (`FPSCameraRig`) places the camera each rendered frame. It adds FOV kick, strafe roll, head bob, a landing dip, and smooth eye height.
- `fps_settings.gd` (`FPSSettings`) holds all sizes, speeds, and camera values.

## Install the addon

1. Copy the `addons/fps_controller/` folder into your project.
2. Open the project in Godot 4.7.
3. Make sure that **Project Settings > Physics > Common > Physics Interpolation** is on.

You do not need to enable a plugin. Godot registers the class names when it scans the project.

## Add a player

Add the node to a level, then put it at the spawn point with `teleport()`:

```gdscript
var player: FPSController = FPSController.new()
player.settings = preload("res://my_fast_preset.tres")  # Optional. Without it, the player uses the default values.
level.add_child(player)
player.teleport(spawn.global_position, spawn.global_rotation.y)
```

The controller makes its collision capsule, its camera rig, and its camera when it enters the tree. Set `settings` before you add the node.

Attach a weapon or a view model to the camera:

```gdscript
player.camera.add_child(gun)
```

Connect the signals for sound and effects:

```gdscript
player.jumped.connect(play_jump_sound)
player.landed.connect(func(impact_speed: float) -> void: play_land_sound(impact_speed))
player.move_state_changed.connect(func(previous: FPSController.MoveState, current: FPSController.MoveState) -> void: print(previous, current))
```

To move the body without the `Input` singleton (AI, replays, or tests), set `player_controlled` to false and write `intent`:

```gdscript
bot.player_controlled = false
bot.intent.move = Vector2(0.0, 1.0)
bot.intent.jump_pressed = true
bot.intent.jump_held = true
bot.look(delta_yaw, delta_pitch)
```

The demo in `demo/demo.tscn` builds a test level in code. Open the project and press F5 to play it.

## Input actions

The controller adds each action below only if the project does not have it. It does not change an action that is in the project.

| Action | Keyboard and mouse | Gamepad | Function |
|---|---|---|---|
| `move_forward` | W | Left stick up | Move forward |
| `move_back` | S | Left stick down | Move back |
| `move_left` | A | Left stick left | Move left |
| `move_right` | D | Left stick right | Move right |
| `jump` | Space | A (bottom face button) | Jump |
| `sprint` | Shift | Left stick press | Sprint |
| `crouch` | Ctrl, C | B (right face button) | Crouch, and slide at sprint speed |
| `look_left` | Mouse | Right stick left | Turn left |
| `look_right` | Mouse | Right stick right | Turn right |
| `look_up` | Mouse | Right stick up | Look up |
| `look_down` | Mouse | Right stick down | Look down |

The keys use physical key codes, so the positions are the same on all keyboard layouts.

Mouse look uses `InputEventMouseMotion.screen_relative`, so the window size does not change the sensitivity. Mouse look works only while the mouse is captured.

If `manage_mouse_capture` is true, the controller captures the mouse when it enters the tree. Esc releases the mouse. A left click captures the mouse again.

## Movement states

`move_state` has one of three values:

| State | The body is | Enter the state when |
|---|---|---|
| `GROUND` | On walkable floor | The body lands, or a slide stops |
| `AIR` | Off the floor | The body jumps, or walks or slides off a ledge |
| `SLIDE` | On the floor in a slide | You press crouch at `slide_min_speed` or more, or you land with crouch held at that speed |

`stance` is `CROUCH` while crouch is held, during a slide, and while a ceiling stops the body from standing. The capsule gets shorter from the top, so the feet stay on the floor.

The controller uses these timers:

- Coyote time lets you jump for `coyote_time` seconds after the body leaves a ledge.
- The jump buffer keeps a jump press for `jump_buffer_time` seconds. The body jumps when it lands. A jump on the landing tick keeps all horizontal speed.
- After a slide stops, a new slide cannot start for `slide_cooldown` seconds.

If you release jump while the body goes up, the controller multiplies the vertical speed by `jump_cut_multiplier`. Only a release cuts the jump. A jump that starts with jump not held has the full height.

## Settings

Each value has a range in the inspector. Change the **Body** values before the node enters the tree. The controller reads the other values on each tick.

### Body

| Value | Default | Unit | Function |
|---|---|---|---|
| `capsule_radius` | 0.35 | m | Radius of the collision capsule |
| `stand_height` | 1.8 | m | Capsule height when you stand |
| `crouch_height` | 1.1 | m | Capsule height when you crouch |
| `stand_eye_height` | 1.65 | m | Camera height when you stand |
| `crouch_eye_height` | 1.0 | m | Camera height when you crouch |
| `step_height` | 0.35 | m | Highest step that the body climbs. It is also the floor snap length. |
| `floor_max_angle_degrees` | 46 | degrees | Steepest walkable floor |

### Ground

| Value | Default | Unit | Function |
|---|---|---|---|
| `walk_speed` | 7.0 | m/s | Speed when you walk |
| `sprint_speed` | 10.5 | m/s | Speed when you sprint |
| `crouch_speed` | 3.5 | m/s | Speed when you crouch |
| `ground_acceleration` | 12 | 1/s | How fast the body gets to the target speed |
| `ground_friction` | 8 | 1/s | How fast the body slows down |
| `stop_speed` | 3.0 | m/s | Below this speed, friction removes the same amount on each tick, so the body comes to a stop |

### Jump

| Value | Default | Unit | Function |
|---|---|---|---|
| `jump_height` | 1.25 | m | Height of a held jump |
| `jump_time_to_apex` | 0.32 | s | Time from the jump to the highest point |
| `fall_gravity_multiplier` | 1.35 | | Gravity multiplier when the body falls |
| `jump_cut_multiplier` | 0.5 | | Vertical speed multiplier when you release jump early |
| `coyote_time` | 0.12 | s | Time after a ledge when a jump is still possible |
| `jump_buffer_time` | 0.12 | s | Time that the controller keeps a jump press |
| `terminal_fall_speed` | 50 | m/s | Highest fall speed |

Gravity is `2 * jump_height / jump_time_to_apex^2`. The jump speed is `2 * jump_height / jump_time_to_apex`. `FPSSettings.gravity()` and `FPSSettings.jump_velocity()` return these values.

### Air

| Value | Default | Unit | Function |
|---|---|---|---|
| `air_acceleration` | 8 | 1/s | Acceleration in the air |
| `air_max_wish_speed` | 3.0 | m/s | Highest speed that air input adds along its own direction |

The air has no friction. Air input adds speed only along the input direction, up to `air_max_wish_speed`. If you strafe and turn in the air, the body gets faster. This movement is air strafing.

### Slide

| Value | Default | Unit | Function |
|---|---|---|---|
| `slide_min_speed` | 8.0 | m/s | Lowest speed that starts a slide. It is more than the walk speed, so you must sprint. |
| `slide_boost` | 3.5 | m/s | Speed added when a slide starts |
| `slide_max_speed` | 15 | m/s | Highest speed from the boost and from slopes |
| `slide_friction` | 1.0 | 1/s | How fast a slide slows down |
| `slide_exit_speed` | 4.0 | m/s | The slide stops below this speed |
| `slide_cooldown` | 0.6 | s | Time before a new slide can start |
| `slide_steer_acceleration` | 8 | m/s² | How fast input turns a slide. Steering does not add speed. |

Gravity along the floor makes a slide faster down a slope and slower up a slope.

### Camera

| Value | Default | Unit | Function |
|---|---|---|---|
| `base_fov` | 90 | degrees | Horizontal FOV on a 16:9 screen. A wider screen shows more at the sides. |
| `fov_kick_max` | 12 | degrees | FOV added at `fov_kick_full_speed` |
| `fov_kick_full_speed` | 15 | m/s | Speed for the full FOV kick. The kick starts at `walk_speed`. |
| `fov_smoothing` | 6 | 1/s | FOV smoothing rate |
| `strafe_roll_degrees` | 2 | degrees | Camera roll when you strafe at walk speed |
| `roll_smoothing` | 8 | 1/s | Roll smoothing rate |
| `head_bob_enabled` | true | | Turns the head bob on or off |
| `head_bob_amplitude` | 0.035 | m | Vertical bob size. The side bob is half of this value. |
| `head_bob_frequency` | 1.4 | Hz | Bob cycles per second at walk speed. It changes with speed. |
| `eye_height_smoothing` | 12 | 1/s | Eye height smoothing rate for crouch |
| `step_smoothing` | 14 | 1/s | Smoothing rate for the camera after a stair step |
| `landing_dip_per_speed` | 0.01 | m per m/s | Camera dip for each m/s of landing speed |
| `landing_dip_max` | 0.2 | m | Largest landing dip |
| `landing_dip_frequency` | 10 | rad/s | Spring frequency of the landing dip |

The head bob operates only in `GROUND`. All smoothing uses `1.0 - exp(-rate * delta)`. The landing dip uses an exact step of a damped spring. The camera motion is the same at all frame rates.

### Controller properties

These values are on `FPSController`, not on `FPSSettings`, because each player can have different values.

| Property | Default | Function |
|---|---|---|
| `settings` | `FPSSettings.new()` | The tuning resource |
| `player_controlled` | true | If true, the controller reads `Input`. If false, you write `intent`. |
| `manage_mouse_capture` | true | Capture on start, release on Esc, capture again on a left click |
| `mouse_sensitivity` | 0.1 | Degrees of turn for each screen pixel of mouse motion |
| `gamepad_look_speed` | 240 | Degrees per second with the stick fully pushed |
| `gamepad_look_exponent` | 2.0 | Stick response curve. 1 is linear. A higher value gives finer aim near the center. |
| `invert_y` | false | Inverts vertical look |

## Signals and public API

### Signals

| Signal | Emitted when |
|---|---|
| `jumped` | The body jumps |
| `landed(impact_speed: float)` | The body lands. `impact_speed` is the downward speed in m/s just before the contact. It is zero or more. |
| `move_state_changed(previous: MoveState, current: MoveState)` | `move_state` changes |

On a bunny hop, the controller emits `landed` and then `jumped` on the same tick. `move_state` stays `AIR`.

### Properties

| Property | Type | Function |
|---|---|---|
| `intent` | `FPSController.Intent` | The input for the next tick |
| `yaw` | `float` | Horizontal facing in radians. The body itself does not turn. |
| `pitch` | `float` | Vertical look in radians, from -89 to 89 degrees |
| `move_state` | `FPSController.MoveState` | `GROUND`, `AIR`, or `SLIDE` |
| `stance` | `FPSController.Stance` | `STAND` or `CROUCH` |
| `camera` | `Camera3D` | The player camera. It is null until the node enters the tree. |

`FPSController.Intent` has these fields:

| Field | Type | Function |
|---|---|---|
| `move` | `Vector2` | x is right, y is forward. The controller limits the length to 1. |
| `jump_pressed` | `bool` | Set it to true for one press. The controller sets it to false after it reads it. |
| `jump_held` | `bool` | True while jump is held |
| `sprint_held` | `bool` | True while sprint is held |
| `crouch_held` | `bool` | True while crouch is held |

### Methods

| Method | Function |
|---|---|
| `look(delta_yaw: float, delta_pitch: float) -> void` | Turns the view by the two angles in radians. The pitch stops at 89 degrees. |
| `teleport(target_position: Vector3, target_yaw: float) -> void` | Moves the body, sets the speed to zero, sets `yaw`, and sets `pitch` to zero. It resets physics interpolation and puts the camera at its new position with no smoothing. |
| `horizontal_speed() -> float` | Returns the horizontal speed in m/s |

## Physics interpolation

The body moves at the physics tick rate, which is 60 Hz by default. At the end of each tick, the body sends its position to the camera rig. On each rendered frame, the rig interpolates between the last two positions with `Engine.get_physics_interpolation_fraction()`. The camera then moves smoothly on a screen that is faster than 60 Hz.

When the body climbs or drops a step, the rig does not interpolate the height change. The camera stays at its old height and then moves smoothly to the new height at the `step_smoothing` rate. Thus a step up does not move the camera down.

The smooth camera needs physics interpolation. If physics interpolation is off, the camera moves only at the physics tick rate. The controller then pushes one warning when it enters the tree.

Mouse look changes `yaw` and `pitch` in `_unhandled_input`. Gamepad look changes them in `_process`. The rig reads them on the same frame, so look has no tick delay.

Use `teleport()` to move the player a long distance. A direct change to `global_position` makes the camera move across the gap for one tick.

## Run the checks

Run the commands from the project folder. They use the `godot` command for Godot 4.7.

To run all headless checks with one command, use this script. It needs bash.

```sh
bash tests/run_checks.sh
```

The script runs these checks:

1. Import the project:

	```sh
	godot --headless --path . --editor --quit
	```

2. Parse each script with the strict warnings. The editor import does not parse scripts, so this step is necessary.

	```sh
	godot --headless --path . --check-only -s addons/fps_controller/fps_controller.gd
	```

	The script does this for each `.gd` file in `addons/fps_controller/`, `demo/`, and `tests/`.

3. Run the test suite on Jolt Physics, which is the project default:

	```sh
	godot --headless --path . -s tests/test_runner.gd
	```

4. Run the test suite on Godot Physics. A temporary `override.cfg` file changes the physics engine:

	```sh
	printf '[physics]\n\n3d/physics_engine="GodotPhysics3D"\n' > override.cfg
	godot --headless --path . -s tests/test_runner.gd
	rm override.cfg
	```

5. Launch the demo for 180 frames:

	```sh
	godot --headless --path . --quit-after 180
	```

The test suite prints `PASS` or `FAIL` for each check, a `MEASURE` line for each measured value, and a `RESULT` line at the end. It exits with code 1 if a check fails.

Do not add `--fixed-fps` to the suite command. With it, the results are the same, but Jolt Physics can print a job system warning.

The visual smoke test opens a window, so it needs a display. It plays the demo for 3 seconds and saves one frame as a PNG file. It fails if the frame is blank:

```sh
godot --path . -s tests/visual_smoke.gd -- /tmp/fps_visual_smoke.png
```

If you do not give a path, the file is `user://visual_smoke.png`.

## Verified checks

These checks passed with Godot 4.7.2 on Linux on 2026-10-12:

- `bash tests/run_checks.sh` passed. The editor import and the parse of all six scripts gave no errors and no warnings.
- The test suite passed on Jolt Physics with 58 checks and 0 failures.
- The test suite passed on Godot Physics with 58 checks and 0 failures.
- The demo launch for 180 frames gave no errors and no warnings.
- The visual smoke test passed with Vulkan Forward+ at 1600x900. The luminance spread of the frame was 1.0. A frame of one color gives 0.0.

The test suite measured these values with the default settings:

| Measurement | Jolt Physics | Godot Physics |
|---|---|---|
| Time to 90% of walk speed from rest | 0.117 s | 0.117 s |
| Stop time from walk speed | 0.233 s | 0.233 s |
| Held jump height | 1.251 m | 1.251 m |
| Time to the highest point of a held jump | 0.317 s | 0.317 s |
| Jump height with jump released after 0.05 s | 0.584 m | 0.583 m |
| Air speed from a standing jump with forward held | 3.0 m/s | 3.0 m/s |
| Speed after 25 ticks of air strafing from 10.5 m/s | 11.83 m/s | 11.83 m/s |
| Speed on the first slide tick from sprint | 13.77 m/s | 13.77 m/s |
| Slide time on flat floor until the slide stops | 1.25 s | 1.25 s |
| Average speed across a 0.3 m step at walk speed | 7.06 m/s | 7.06 m/s |
| Slide speed after 0.5 s on flat floor | 8.46 m/s | 8.46 m/s |
| Slide speed after 0.5 s down a 20 degree ramp | 11.76 m/s | 11.76 m/s |
| Impact speed after a 2 m drop | 11.26 m/s | 11.26 m/s |
| Vertical FOV when you stand still | 58.72 degrees | 58.72 degrees |
| Vertical FOV at sprint speed | 63.31 degrees | 63.31 degrees |
