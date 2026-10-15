---
name: verify
description: Drive Zombie Survival FPS (Godot 4.7 desktop game) like a player and prove a change works. It plays the real main scene in a private headless KWin display, sends real key, mouse-button, and mouse-motion events from a scenario file, and keeps a transcript, game state, and screenshots. Use it after a change to gameplay, the HUD, the weapon, zombies, rounds, pause, death, or movement, when the headless tests are not enough proof.
---

# Verify Zombie Survival FPS

The surface is one desktop game window. There is no server, no network, and no saved data. Each run starts a new game from `game/main.tscn`.

The harness has three parts:

- `run.sh` starts a private headless KWin (`kwin_wayland --virtual`, socket `zsfps-verify-<pid>`), starts Godot in it, plays one scenario, and stops both. KWin and Godot use a private D-Bus session (`dbus-daemon`, no auto-started services) and a private KDE config dir in `$XDG_RUNTIME_DIR/zsfps-verify-<pid>.d/`. Do not remove this isolation: on the desktop bus, the nested KWin takes `org.kde.kglobalaccel` and, when it exits, makes the desktop KWin Meta shortcuts stop until the next login.
- `driver.gd` is a `SceneTree` script. It loads the main scene and plays the scenario lines. It sends input with `Input.parse_input_event`, so the input goes through the same `InputMap` actions and `_unhandled_input` path as a real player. It reads state from the live nodes only to log and to assert.
- `scenarios/*.txt` are the scenario files. Each feature in `features/` names its scenario.

The game window never opens on the user's desktop, and the game never captures the user's mouse. Two runs can operate at the same time: each run has its own KWin socket and its own evidence directory.

## Doctor

Run this first, and again when something looks wrong. It is read-only.

```bash
.claude/skills/verify/doctor.sh
```

Each line starts with `OK:` or `PROBLEM:`. Exit code 1 means at least one problem. It checks Godot 4.7, `kwin_wayland`, `XDG_RUNTIME_DIR`, the project import (`.godot/`), no `override.cfg` (it changes the physics engine), and no stranded verify instances.

If the project is not imported, run `godot --headless --path . --editor --quit` once.

## Launch and drive

Run from the project root:

```bash
.claude/skills/verify/run.sh .claude/skills/verify/scenarios/pistol.txt
```

The optional second argument sets the evidence directory. The default is `.verify/<date>-<time>-<scenario>/`.

- Ready signal: `VERIFY READY` in the output. The main scene is in the tree at that time.
- End: `VERIFY DONE failures=<n>`, then `RESULT: PASS` or `RESULT: FAIL (exit <code>)` and the evidence path.
- Exit code: 0 for PASS, 1 for a failed step, 2 for a launch problem.
- Teardown is automatic. A `trap` stops Godot and KWin by PID on exit, on Ctrl+C, and on `kill`.

There is no long-lived instance. To prove a new behavior, write a scenario file (in the scratchpad, or in `scenarios/` if it is worth keeping) and run it.

### Scenario language

One command on each line. `#` starts a comment line. The run stops at the first failed step.

| Command | Effect |
|---|---|
| `wait <seconds>` | Lets game time pass. |
| `press <key>` / `release <key>` | Holds or releases a key. Names come from `OS.find_keycode_from_string`: `W`, `A`, `S`, `D`, `Space`, `Shift`, `Ctrl`, `C`, `R`, `V`, `E`, `Q`, `Escape`, `Enter`. Held keys are released at the end. |
| `tap <key>` | Press, two physics ticks, release. |
| `click` / `mouse_down` / `mouse_up` | Left mouse button (the `fire` action). |
| `look <dx> <dy>` | Mouse motion in pixels. 10 px is 1 degree. A positive `dx` turns right (yaw goes down). `look 1800 0` turns 180 degrees. |
| `aim_nearest [body\|head]` | Sends the mouse motion that points the view at the nearest live zombie, then waits for the camera rig to apply it. Fails if no zombie is alive. |
| `fight <seconds> [head\|body]` | Aims at the nearest zombie and holds the fire button for 0.2 s, every 0.3 s, until the time ends or the round is cleared. A semi-automatic weapon fires once for each hold, and an automatic weapon fires a burst. It uses only real mouse events. |
| `walk_to <x> <z> <timeout-s>` | Holds W and steers with mouse motion until the player is within 0.3 m of the point on the floor. Fails at the timeout. It does not go around obstacles, so give waypoints. |
| `face <yaw-deg> [pitch-deg]` | Turns the view with one mouse motion. Yaw 0 faces -Z, 90 faces -X, 180 faces +Z. |
| `shot <name>` | Saves `<name>.png` (1600x900) to the evidence directory. |
| `state` | Logs one `STATE {json}` line with all fields below. |
| `expect <field> <op> <value>` | Asserts a field. Ops: `==`, `!=`, `>`, `<`, `>=`, `<=`, and `contains` for text. The value is the rest of the line with its inner spaces, so `expect hud_ammo == 8 / 80` and `expect hud_prompt == E  Buy SMG  1000` work. |
| `wait_until <field> <op> <value> <timeout-s>` | Waits for a field, checked each physics tick. Fails at the timeout. |

State fields: `phase` (`STARTING`, `ACTIVE`, `INTERMISSION`, `GAME_OVER`), `round`, `to_spawn`, `zombies_alive`, `nearest_zombie_m` (999 when no zombie is alive), `points`, `earned`, `magazine` and `reserve` (of the weapon in the hands), `weapon` (`READY`, `COOLDOWN`, `RELOADING`, `MELEE`, `SWITCHING`), `weapon_name`, `slots` (for example `Pistol,*SMG`, with `*` on the weapon in the hands), `box` (`IDLE`, `ROLLING`, `OFFERING`), `health`, `player_alive`, `move_state` (`GROUND`, `AIR`, `SLIDE`), `stance` (`STAND`, `CROUCH`), `speed` (horizontal m/s), `position`, `yaw_deg`, `paused`, `mouse_captured`, `fps`, `ticks_ms`, and the HUD text the player sees: `hud_round`, `hud_points`, `hud_ammo`, `hud_weapon`, `hud_prompt` (empty when hidden), `hud_banner` (empty when faded), `hud_death`, `hud_death_text`, `hud_pause`.

To add a field or a command, edit `driver.gd`. The project treats untyped and unsafe GDScript as errors, so keep all declarations typed. Check the parse with:

```bash
godot --headless --path . --check-only -s res://.claude/skills/verify/driver.gd
```

## Evidence

Each run writes these files to its evidence directory:

- `transcript.log`: each step, each `STATE` line, each `PASS` or `FAIL`, each `SHOT` path.
- `godot.log`: all Godot output, with engine errors and `SCRIPT ERROR` lines.
- `kwin.log`: the private compositor log, for launch problems.
- `dbus.log`: the private D-Bus log, for launch problems.
- `<name>.png`: one file for each `shot`.

`.verify/` is in `.gitignore`. Godot does not import it, because its name starts with a dot.

Proof standards:

- Drive the real player path: keys, mouse buttons, and mouse motion. Do not set `Weapon.trigger_held`, call `take_damage`, or use other test hooks from a scenario. The headless suite in `tests/` already does that.
- Capture the action and the result: a `state` or `expect` before the action, a `shot` during it, and `expect` lines after it.
- Assert what the player sees (`hud_*` fields and screenshots) and the game state behind it (`points`, `magazine`, `phase`). A HUD that shows a value the game does not have is a bug.
- Look at the screenshots. Use the Read tool on the PNG. An `expect` does not prove that the frame shows the right thing.
- Zombie spawns and pistol spread are random. Make a scenario robust with `wait_until` (for example, wait until a zombie is within 8 m before a shot), not with long fixed waits. Run a new scenario 3 times before you trust it.

## Cleanup

`run.sh` cleans up after itself. If a run was killed with `kill -9`, or the shell died, stop the stranded instances with:

```bash
.claude/skills/verify/cleanup.sh
```

It stops only processes named `godot` that run `verify/driver.gd`, and processes named `kwin_wayland` with a `zsfps-verify-` socket. It never stops the user's own Godot editor or desktop KWin. It removes stale sockets. It keeps `.verify/`. To delete old evidence, remove `.verify/<run>` by hand.

Never use `pkill -f` with a pattern from this skill: the pattern also matches the shell that runs the command, and that shell is then killed.

## Gotchas

- `run.sh` starts Godot with `--disable-vsync --max-fps 60`. With vsync, Vulkan FIFO present under the virtual KWin sometimes blocks for ever, and the run freezes at a `shot`.
- Godot sometimes did not exit after `quit()` in a run that used restart (scene reload). `run.sh` stops Godot 15 s after `VERIFY DONE` and prints a `NOTE:` line. The result then comes from the transcript.
- The camera rig applies a look on the next rendered frame. A shot or knife in the same tick as a large look uses the old view. `aim_nearest` and `fight` wait for this. After a raw `look`, add `wait 0.1` before `click` or `tap V`.
- Round 1 starts 3 s after launch, and zombies spawn about 28 m away. A zombie needs 15 to 25 s to reach the player.
- The player spawns at `0,0,6` and faces -Z. A cover block is 10 m ahead at z = -4. For movement tests, turn to +Z first (`look 1800 0`): that lane is clear for 14 m.
- The headless test suite (`bash tests/run_checks.sh`) and this skill are different proofs. Run both for a gameplay change.

## Feature map

`features/README.md` lists each user-facing feature, its scenario, and its proof. A proof for a feature covers every entry point that its file lists.
