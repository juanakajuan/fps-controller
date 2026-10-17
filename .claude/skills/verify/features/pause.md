# Pause and resume

Esc pauses the game: the world stops, the pause screen shows the controls, and the mouse is free. Esc again resumes and captures the mouse.

## Sub-features

- `pause` stops zombies, timers, and the player. The HUD shows `PAUSED`.
- `resume` continues from the same state and captures the mouse again.
- `click-to-capture` captures the mouse again on a click when it is free and the game is not paused.

## How to get to it (user POV)

- Press Esc. Start on a gamepad.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/pause.txt`.

- **Pause.** `wait_until phase == ACTIVE 10`, `tap Escape`, `wait 0.2`, then `expect paused == true`, `expect hud_pause == true`, `expect mouse_captured == false`, `shot paused`.
- **Stays paused.** `wait 2`, `expect paused == true`.
- **Resume.** `tap Escape`, `wait 0.2`, then `expect paused == false`, `expect hud_pause == false`, `expect mouse_captured == true`.
- **World stops (not in the scenario).** Read `nearest_zombie_m` with `state` before and after a `wait 2` while paused. The value does not change.

## Gotchas

- Esc on the death screen does nothing. Pause works only when the game is not over. Start is bound to both pause and restart, so Start on the death screen starts a new game.
- The pause screen text lists the keyboard and mouse controls. It lists no gamepad controls.
