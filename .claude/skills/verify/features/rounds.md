# Rounds and intermission

Undead come in rounds. Kill every zombie of a round to clear it. The next round starts 10 s later, with more zombies. It does not fill the ammunition: ammunition comes from the wall buys (see [buys.md](buys.md)).

## Sub-features

- `round-start` starts round 1 3 s after launch. The banner shows `Round 1`. The round number shows at the bottom left in red.
- `round-clear` shows the banner `Round cleared` when the last zombie of the round dies. The phase becomes `INTERMISSION`.
- `round-next` starts round 2 10 s later, with a `Round 2` banner. The ammunition stays as it was.

## How to get to it (user POV)

- Start the game and wait. Kill all zombies with the pistol or the knife.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/rounds.txt`. It takes about 60 s.

- **Start.** `wait_until phase == ACTIVE 10`, `expect hud_round == 1`.
- **Clear.** `fight 120 head` aims and fires at the nearest zombie until the round is cleared. Reloads happen automatically at an empty magazine.
- **Cleared.** `wait_until phase == INTERMISSION 5`, `expect hud_banner == Round cleared`, `shot round-cleared`.
- **Next round.** `wait_until round == 2 15`, `expect hud_round == 2`, `expect reserve < 80` (no refill).

## Gotchas

- `fight` can lose: if the zombies kill the player first, `phase` becomes `GAME_OVER` and the next `wait_until` fails. Look at `health` in the last `STATE` line.
- The banner fades after 3 s. `hud_banner` is empty when the banner is not visible.
