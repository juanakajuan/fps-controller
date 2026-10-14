# Death and play again

A zombie hit removes 40 health. At 0 health the game ends and shows the death screen with the rounds survived and the points earned. Enter starts a new game.

## Sub-features

- `damage-vignette` shows a red vignette that gets stronger as health goes down. Health comes back at 50/s after 4 s without a hit.
- `death-screen` shows `YOU DIED`, `You survived <n> rounds.`, `You earned <n> points.`, and frees the mouse.
- `restart` reloads the scene with Enter: round 0, 500 points, 100 health.

## How to get to it (user POV)

- Stand still near zombies until they kill you.
- On the death screen, press Enter (or keypad Enter). Start on a gamepad.

## Driving it with run.sh

Run `.claude/skills/verify/run.sh .claude/skills/verify/scenarios/death-restart.txt`. It takes about 25 s.

- **Die.** `wait_until player_alive == false 180`. The player does nothing.
- **Death screen.** `expect phase == GAME_OVER`, `expect hud_death == true`, `expect hud_death_text contains You survived 0 rounds.`, `expect mouse_captured == false`, `shot death`.
- **Restart.** `tap Enter`, `wait 1`, then `expect phase == STARTING`, `expect hud_death == false`, `expect points == 500`, `expect health == 100`.
- **Vignette (not in the scenario).** `wait_until health <= 60 60`, `shot hurt`. The PNG shows a red border.

## Gotchas

- Godot sometimes did not exit after a run with a restart. `run.sh` stops it 15 s after `VERIFY DONE` and prints a `NOTE:` line. That is not a failure of the feature.
- Round 1 is not survived if the player dies in it, so the text is `0 rounds`.
