# Hold the Yard

Hold the Yard is a round-based survival first-person shooter for Godot 4.7. It is written in GDScript only. The game builds all nodes, geometry, materials, input actions, and the HUD in code. It uses no external assets.

You stand in a walled yard with a pistol. Undead come in rounds. Each round has more zombies, and the zombies have more health and more speed. You get points for hits and kills. The game ends when you die. Your score is the number of rounds that you survived.

This is milestone 1, the core loop. `DESIGN.md` gives the design and the plan for the next milestones. `docs/player.md` gives the movement design.

## Run the game

1. Install Godot 4.7.
2. Open the project folder in Godot, and then press F5.

To start the game from a terminal, use this command in the project folder:

```sh
godot --path .
```

## Controls

| Action | Keyboard and mouse | Gamepad |
|---|---|---|
| Move | W, A, S, D | Left stick |
| Look | Mouse | Right stick |
| Jump | Space | A |
| Sprint | Shift | Left stick press |
| Crouch. At sprint speed, slide. | Ctrl, C | B |
| Fire | Left mouse button | Right trigger |
| Reload | R | X |
| Knife attack | V | Right stick press |
| Pause and resume | Esc | Start |
| Play again after death | Enter | Start |

The keys use physical key codes. Thus the positions are the same on all keyboard layouts.

## Rules

- Round 1 starts 3 seconds after the game starts. The next round starts 10 seconds after you kill the last zombie of a round.
- Round 1 has 6 zombies with 150 health. Each round has more zombies. Up to 24 zombies are alive at one time.
- Zombies walk, jog, or run. In later rounds, more of them run.
- The pistol does 35 damage. A hit on the head does 70 damage. The magazine holds 8 rounds, and the reserve holds 80 rounds. Each new round fills the magazine and the reserve.
- The knife does 150 damage to one zombie at a distance of 2 m or less. A wall stops the knife. One knife attack takes 0.6 seconds. The knife uses no ammunition, and it stops a reload. The reload starts again after the knife attack.
- You get 10 points for a hit, 60 points for a kill, 100 points for a kill with a head hit, and 130 points for a kill with the knife. You start with 500 points. In milestone 1, you cannot spend points.
- You have 100 health. A zombie hit removes 40 health. If no zombie hits you for 4 seconds, your health comes back at 50 per second.

`game/rules.gd` holds all these values.

## Files

| File | Function |
|---|---|
| `game/main.tscn` | The main scene. It has one node with `game/game.gd`. |
| `game/game.gd` | `Game` builds the arena, the player, the weapon, and the HUD. It ticks the round director, spawns zombies, and sends events between the parts. It owns mouse capture, pause, and restart. |
| `game/rules.gd` | `Rules` holds all tuning values and the wave formulas. |
| `game/round_director.gd` | `RoundDirector` is the round state machine. It uses no nodes. |
| `game/points.gd` | `Points` holds the point balance and the total earned. |
| `game/layers.gd` | `Layers` names the collision layers. |
| `game/hud.gd` | `Hud` shows the round, the points, the ammunition, the health vignette, the crosshair, the hit marker, the banner, the death screen, and the pause screen. |
| `game/player/player.gd` | `Player` is the body of the player. It moves, and it has health. |
| `game/player/player_camera_rig.gd` | `PlayerCameraRig` moves the camera on each rendered frame. |
| `game/player/player_settings.gd` | `PlayerSettings` holds the movement values. |
| `game/weapon/weapon_def.gd` | `WeaponDef` holds the data of one weapon. |
| `game/weapon/weapon.gd` | `Weapon` fires, reloads, attacks with the knife, and casts the hit rays. It also shows the weapon model. |
| `game/zombie/zombie.gd` | `Zombie` finds a path to the player, attacks, and dies. |
| `game/level/arena.gd` | `Arena` builds the yard and bakes its navigation mesh. |
| `tests/test_runner.gd` | The headless test suite. |
| `tests/run_checks.sh` | Runs all headless checks. |
| `tests/visual_smoke.gd` | Opens a window, plays the game for 3 seconds, and saves one frame. |

## Run the checks

Run the commands from the project folder. They use the `godot` command for Godot 4.7.

To run all headless checks, use this script. It needs bash.

```sh
bash tests/run_checks.sh
```

The script does these steps:

1. It imports the project with the editor.
2. It parses each `.gd` file in `game/` and `tests/` with the strict warnings. The project treats untyped declarations, inferred declarations, and unsafe access as errors.
3. It runs the test suite on Jolt Physics, which is the project default.
4. It runs the test suite on Godot Physics. A temporary `override.cfg` file changes the physics engine.
5. It starts the game for 600 frames.

If a step shows an `ERROR` or `WARNING` line, or if a test fails, the script stops and shows `FAIL`.

The test suite prints `PASS` or `FAIL` for each check, a `MEASURE` line for each measured value, and a `RESULT` line at the end. It exits with code 1 if a check fails. The game test plays two rounds in real time, so each suite run takes more than 30 seconds.

The visual smoke test opens a window, so it needs a display. It plays the game for 3 seconds and saves one frame as a PNG file. It fails if the frame is blank:

```sh
godot --path . --script tests/visual_smoke.gd -- /tmp/hold_the_yard.png
```

If you do not give a path, the file is `user://visual_smoke.png`.

## Verified checks

These checks passed with Godot 4.7.2 on Linux on 2026-10-13:

- `bash tests/run_checks.sh` passed. The editor import and the parse of all 16 scripts gave no errors and no warnings.
- The test suite passed on Jolt Physics with 153 checks and 0 failures.
- The test suite passed on Godot Physics with 153 checks and 0 failures.
- `godot --headless --path . --quit-after 600` gave no `ERROR` lines and no `WARNING` lines.
- The visual smoke test passed with Vulkan Forward+ at 1600x900. The luminance spread of the frame was 0.93. A frame of one color gives 0.0.

The test suite measured these game values:

| Measurement | Jolt Physics | Godot Physics |
|---|---|---|
| Health 4.3 s after 30 damage | 84.2 | 84.2 |
| Pistol reload time | 1.4 s | 1.4 s |
| Knife attack time | 0.6 s | 0.6 s |
| Time for a zombie at 3.2 m/s to reach the player around a 2 m block | 1.85 s | 1.85 s |
