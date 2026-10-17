# Buys

Points are a currency. The player buys weapons and ammunition at three wall buys and a random weapon from the box, carries two weapons, and changes between them.

## Sub-features

- `buy-prompt` shows the prompt below the crosshair when the player looks at a station from 2.5 m or less, for example `E  Buy SMG  1000`. It is gray when the player cannot pay. A wall between the player and the station hides it.
- `buy-weapon` buys the weapon with E. It goes to the empty slot, or it replaces the weapon in the hands. The HUD shows the weapon name above the ammunition.
- `buy-ammo` buys ammunition for half the price at the wall of a weapon that the player has. With full ammunition the prompt is `SMG ammo full` and E does nothing.
- `weapon-change` changes weapons with Q or the mouse wheel. `weapon` is `SWITCHING` for 0.5 s.
- `box-roll` rolls the box for 950 points. It is `ROLLING` for 4 s with no prompt, then `OFFERING` with `E  Take <weapon>` for 10 s. E takes the weapon. A timeout keeps the points.

## How to get to it (user POV)

| Station | Position | Price |
|---|---|---|
| SMG wall buy | north wall, x -8 | 1000 |
| Shotgun wall buy | east wall, z -8 | 1200 |
| Rifle wall buy | west wall, z 8 | 1500 |
| Box | south wall, x 10 | 950 |

The player starts at `0,0,6` with 500 points. Round 1 earns about 700 points with head hits.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/buys.txt`. It takes about 2 to 3 minutes.

- **Earn.** `fight 120 head` clears round 1. `expect points >= 1000`.
- **Walk.** `walk_to` waypoints go around the cover blocks at `-8,6` and `0,-4`, and the ramp of the platform. `face 0 0` faces the north wall.
- **Buy.** `expect hud_prompt == E  Buy SMG  1000`, `shot smg-prompt`, `tap E`, `expect slots == Pistol,*SMG`, `expect hud_ammo == 30 / 150`.
- **Change.** `tap Q`, `expect weapon == SWITCHING`, `expect hud_weapon == Pistol`, and after 0.6 s `expect weapon == READY`.
- **Box.** Earn in round 2, walk to `10,17.8`, `face 180 0`, `expect hud_prompt == E  Mystery box  950`, `tap E`, `wait_until box == OFFERING 5`, `wait 0.1`, `shot box-offer`, `tap E`.

## Gotchas

- The prompt can be one tick old. Game reads the offer before the box advances in the same tick, so add `wait 0.1` after a `wait_until box == ...`.
- `walk_to` goes in a straight line. A waypoint behind an obstacle makes it time out against the obstacle.
- Round 2 can start during the walk. Zombies then attack the player at the station.
