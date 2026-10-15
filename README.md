# Zombie Survival FPS

Zombie Survival FPS is a round-based survival first-person shooter for Godot 4.7. It is written in GDScript only. The map is a scene (`game/level/arena.tscn`) that you can open and edit in the Godot editor. The rules, the player, the weapons, the zombies, input actions, and the HUD are in code. It uses no external assets.

You stand in a walled yard with a pistol. Undead come in rounds. Each round has more zombies, and the zombies have more health and more speed. You get points for hits and kills, and you spend them on weapons and ammunition. The game ends when you die. Your score is the number of rounds that you survived.

This is milestone 2, weapons and buys. `DESIGN.md` gives the design of the core loop and the plan for the next milestones. `docs/weapons-and-buys.md` gives the design of the weapons, the wall buys, and the box. `docs/player.md` gives the movement design.

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
| Buy (wall buy or box) | E | Right shoulder |
| Change weapon | Q, mouse wheel | Y |
| Pause and resume | Esc | Start |
| Play again after death | Enter | Start |

The keys use physical key codes. Thus the positions are the same on all keyboard layouts.

## Rules

- Round 1 starts 3 seconds after the game starts. The next round starts 10 seconds after you kill the last zombie of a round.
- Round 1 has 6 zombies with 150 health. Each round has more zombies. Up to 24 zombies are alive at one time.
- Zombies walk, jog, or run. In later rounds, more of them run.
- You start with the pistol. The pistol does 35 damage. A hit on the head does 2 times the damage. The magazine holds 8 rounds, and the reserve holds 80 rounds. A new round does not fill the ammunition.
- You can carry two weapons. To change between them, press Q or turn the mouse wheel. A change takes 0.5 seconds. A change stops a reload.
- Three walls sell weapons: the SMG on the north wall for 1000 points, the shotgun on the east wall for 1200 points, and the rifle on the west wall for 1500 points. Look at a wall buy from 2.5 m or less, and press E. The prompt below the crosshair shows the price. The prompt is gray if you cannot pay.
- If you have an empty slot, the new weapon goes there. If not, the new weapon replaces the weapon in your hands.
- At the wall buy of a weapon that you have, E buys ammunition for half the price. It fills the magazine and the reserve.
- The box near the south wall costs 950 points. It rolls for 4 seconds, and then it offers a weapon for 10 seconds. Press E to take the weapon. If you do not take it, the weapon is gone and the points do not come back. The box can give the SMG, the shotgun, the rifle, the LMG, or the marksman rifle, but never a weapon that you had when the roll started.
- No wall sells the pistol. When you have no ammunition and no points, use the knife.
- The knife does 150 damage to one zombie at a distance of 2 m or less. A wall stops the knife. One knife attack takes 0.6 seconds. The knife uses no ammunition, and it stops a reload. The reload starts again after the knife attack.
- You get 10 points for a hit, 60 points for a kill, 100 points for a kill with a head hit, and 130 points for a kill with the knife. A shotgun shot gives the hit points one time for each zombie that it hits. You start with 500 points.
- You have 100 health. A zombie hit removes 40 health. If no zombie hits you for 4 seconds, your health comes back at 50 per second.

`game/rules.gd` holds the values for rounds, points, health, buys, and the box. `game/weapon/arsenal.gd` holds the weapon values:

| Weapon | Where | Price | Damage | Pellets | Fire interval | Automatic | Magazine | Reserve | Reload |
|---|---|---|---|---|---|---|---|---|---|
| Pistol | Start | | 35 | 1 | 0.15 s | No | 8 | 80 | 1.4 s |
| SMG | North wall | 1000 | 30 | 1 | 0.075 s | Yes | 30 | 150 | 2.0 s |
| Shotgun | East wall | 1200 | 25 | 8 | 0.8 s | No | 6 | 42 | 3.0 s |
| Rifle | West wall | 1500 | 80 | 1 | 0.25 s | No | 15 | 90 | 2.2 s |
| LMG | Box | | 55 | 1 | 0.1 s | Yes | 75 | 300 | 4.5 s |
| Marksman | Box | | 250 | 1 | 0.9 s | No | 5 | 40 | 3.0 s |

## Files

| File | Function |
|---|---|
| `game/main.tscn` | The main scene. It has one node with `game/game.gd`. |
| `game/game.gd` | `Game` instances the arena scene and builds the player, the weapon, and the HUD. It ticks the round director, spawns zombies, and sends events between the parts. It finds the station in view, shows its prompt, and takes the points for a buy. It owns mouse capture, pause, and restart. |
| `game/rules.gd` | `Rules` holds all tuning values and the wave formulas. |
| `game/round_director.gd` | `RoundDirector` is the round state machine. It uses no nodes. |
| `game/points.gd` | `Points` holds the point balance and the total earned. |
| `game/layers.gd` | `Layers` names the collision layers. |
| `game/hud.gd` | `Hud` shows the round, the points, the weapon name, the ammunition, the buy prompt, the health vignette, the crosshair, the hit marker, the banner, the death screen, and the pause screen. |
| `game/player/player.gd` | `Player` is the body of the player. It moves, and it has health. |
| `game/player/player_camera_rig.gd` | `PlayerCameraRig` moves the camera on each rendered frame. |
| `game/player/player_settings.gd` | `PlayerSettings` holds the movement values. |
| `game/weapon/weapon_def.gd` | `WeaponDef` holds the data of one weapon, with the boxes of its model. |
| `game/weapon/arsenal.gd` | `Arsenal` makes the six weapons and gives the weapons that the box can roll. |
| `game/weapon/loadout.gd` | `Loadout` holds the weapons that the player has, with the ammunition of each, and the weapon in the hands. |
| `game/weapon/weapon.gd` | `Weapon` fires, reloads, changes weapons, attacks with the knife, and casts the hit rays. It also shows the weapon model. |
| `game/station/station.gd` | `Station` is the base of a thing that the player buys from. It tells what a press buys, and it applies the buy. |
| `game/station/wall_buy.gd` | `WallBuy` sells one weapon and its ammunition on a wall. |
| `game/station/mystery_box.gd` | `MysteryBox` rolls a random weapon and offers it. |
| `game/zombie/zombie.gd` | `Zombie` finds a path to the player, attacks, and dies. |
| `game/level/arena.tscn` | The map: the yard, the lamps, the wall buys, the box, and the spawn markers. Edit it in the Godot editor. |
| `game/level/arena.gd` | `Arena` reads the spawn markers and the stations of the map scene, and bakes its navigation mesh. |
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
godot --path . --script tests/visual_smoke.gd -- /tmp/zombie_survival_fps.png
```

If you do not give a path, the file is `user://visual_smoke.png`.

## Verified checks

These checks passed with Godot 4.7.2 on Linux on 2026-10-14:

- `bash tests/run_checks.sh` passed. The editor import and the parse of all 20 scripts gave no errors and no warnings.
- The test suite passed on Jolt Physics with 204 checks and 0 failures.
- The test suite passed on Godot Physics with 204 checks and 0 failures.
- `godot --headless --path . --quit-after 600` gave no `ERROR` lines and no `WARNING` lines.
- The visual smoke test passed with Vulkan Forward+ at 1600x900. The luminance spread of the frame was 0.93. A frame of one color gives 0.0.
- The `verify` skill played `scenarios/buys.txt` in the real main scene and passed: it cleared round 1, bought the SMG with E, changed weapons with Q, cleared round 2, rolled the box, and took its weapon.

The test suite measured these game values:

| Measurement | Jolt Physics | Godot Physics |
|---|---|---|
| Health 4.3 s after 30 damage | 84.2 | 84.2 |
| Pistol reload time | 1.4 s | 1.4 s |
| Knife attack time | 0.6 s | 0.6 s |
| Weapon change time | 0.5 s | 0.5 s |
| Time for a zombie at 3.2 m/s to reach the player around a 2 m block | 1.85 s | 1.85 s |
| Distance from the box center to the walkable mesh | 1.0 m | 1.0 m |
