# Knife attack

V makes a knife attack. It does 150 damage to one zombie at 2 m or less, and a wall stops it. It uses no ammunition. A knife kill gives 130 points.

## Sub-features

- `melee-hit` kills a round-1 zombie (150 health) in one attack: +130 points.
- `melee-range` does not hit a zombie farther than 2 m.
- `melee-reload-interrupt` stops a reload. The reload starts again after the 0.6 s attack.

## How to get to it (user POV)

- Press V. Right stick press on a gamepad.
- The pistol thrusts forward for 0.6 s.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/melee.txt`.

- **Wait for contact.** `wait_until nearest_zombie_m <= 1.8 60`. The player stands still and the zombies come.
- **Attack.** `aim_nearest body`, `tap V`, `wait 0.05`, `expect weapon == MELEE`, `shot knife`.
- **Result.** After `wait 0.3`: `expect earned >= 130` and `expect hud_ammo == 8 / 80` (no ammunition used).
- **Reload interrupt (not in the scenario).** Fire one round, `tap R`, `wait 0.3`, `tap V`, then `expect weapon == MELEE` and `expect hud_ammo == 7 / 80`. After `wait 0.7`, `expect weapon == RELOADING`.

## Gotchas

- `nearest_zombie_m` is from the player's feet to the zombie's feet. The knife ray starts at the camera.
- The zombie also attacks at 1.3 m. Health drops to 60 before the knife often. That is correct.
- A `look` and a `tap V` in the same tick use the old view. `aim_nearest` waits for the camera, so use it before `tap V`.
