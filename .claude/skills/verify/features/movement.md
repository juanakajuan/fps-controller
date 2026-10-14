# Movement

The player walks at 7 m/s, sprints at 10.5 m/s, crouches at 3.5 m/s, slides from a sprint, and jumps. `docs/player.md` gives the full design.

## Sub-features

- `walk` with W, A, S, D.
- `sprint` with Shift held.
- `slide` with Ctrl or C at sprint speed (8 m/s or more). Under that speed, Ctrl or C crouches.
- `jump` with Space. The state goes `AIR`, then `GROUND` on landing.
- `look` with mouse motion: 0.1 degree for each pixel.
- `stairs` on the platform at -10, -10 (stairs on its +Z side, a ramp on its +X side).

## How to get to it (user POV)

- Keyboard and mouse as above. Left stick, left stick press, B, and A on a gamepad.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/movement.txt`.

- **Turn.** `look 1800 0`, `wait 0.1`, `expect yaw_deg == -180`. The player now faces +Z, a clear lane.
- **Walk.** `press W`, `wait 0.5`, `expect speed >= 6.5`.
- **Sprint.** `press Shift`, `wait 0.6`, `expect speed >= 10`.
- **Slide.** `press C`, `wait 0.05`, `expect move_state == SLIDE`, `shot slide` (the camera is low).
- **Jump.** Release all keys, `wait 1`, `tap Space`, `wait 0.1`, `expect move_state == AIR`, `wait 1`, `expect move_state == GROUND`.

## Gotchas

- Facing -Z from spawn, the cover block at z = -4 stops a sprint after about 1 s, and `speed` drops to 0.
- `press` holds a key until `release`. The driver releases held keys at the end of the run.
- Zombies can reach the player during long movement runs after round 1 starts at 3 s.
