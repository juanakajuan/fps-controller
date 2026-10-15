# Pistol

The player starts with a semi-automatic pistol. Each press fires one round. A hit gives points and shows a hit marker. R reloads.

## Sub-features

- `pistol-fire` fires one round for each press of the fire button, with a muzzle flash and recoil.
- `pistol-hit` gives 10 points for a hit, 60 for a kill, 100 for a kill with a head hit. The hit marker is white for a hit and red for a kill.
- `pistol-reload` reloads with R. It takes about 1.5 s. It also starts automatically when the magazine is empty.
- `pistol-no-refill`: a new round does not fill the pistol, and no wall sells it. The knife is the fallback (see [melee.md](melee.md)).

## How to get to it (user POV)

- Left mouse button fires. Right trigger on a gamepad.
- R reloads. X on a gamepad.
- The HUD shows ammunition at the bottom right as `<magazine> / <reserve>`, and the points at the top left.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/pistol.txt`.

- **Baseline.** `wait_until phase == ACTIVE 10`, then `expect hud_ammo == 8 / 80` and `expect points == 500`.
- **Get in range.** `wait_until nearest_zombie_m <= 8 40`. At 28 m, the spread misses often.
- **Fire.** `aim_nearest body`, `shot before-fire`, `click`, `wait 0.03`, `shot muzzle-flash`. The PNG shows the flash at the muzzle and the hit marker on the crosshair.
- **Result.** `expect magazine == 7`, `expect hud_ammo == 7 / 80`, `expect earned >= 10`, `expect hud_points != 500`.
- **Reload.** `tap R`, `wait 0.3`, `expect weapon == RELOADING`, `shot reloading` (the pistol dips). After `wait 2.0`: `expect weapon == READY` and `expect hud_ammo == 8 / 79`.

## Gotchas

- `aim_nearest body` aims at the chest (1 m above the feet). `aim_nearest head` aims above `Rules.ZOMBIE_HEAD_HEIGHT` for a head hit.
- The hit marker shows for 0.15 s only. Take the `shot` within 0.1 s of the `click`.
- A miss is not a bug. If `earned` stays 0, look at `muzzle-flash.png` to see where the round went before you change the game.
