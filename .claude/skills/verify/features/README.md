# Zombie Survival FPS verification map

This directory is the maintained source for verifying what a player can do in Zombie Survival FPS. Read this index before you drive the game, then use the matching feature file as the recipe.

## Baseline preconditions

- `.claude/skills/verify/doctor.sh` prints no `PROBLEM:` line.
- Each run starts a new game: round 0, phase `STARTING`, 500 points, 100 health, `8 / 80` ammunition, player at `0,0,6` facing -Z.
- Round 1 starts 3 s after launch with 6 zombies of 150 health.

## Driving conventions

- Drive with `.claude/skills/verify/run.sh <scenario>` from the project root. `../SKILL.md` lists the scenario commands and state fields.
- Use keys, mouse buttons, and mouse motion only. Do not call game methods or set test hooks from a scenario.
- Wait for conditions with `wait_until`, not with long fixed waits. Spawns and spread are random.
- The keyboard and mouse entry points are drivable. The gamepad entry points are not driven yet: the driver sends no joypad events.

## Proof and skip reporting

- Proof is the evidence directory: `transcript.log` with `PASS` lines, and the PNG files. Look at the PNG files.
- Assert the HUD text and the game state behind it.
- Report each entry point that you did not drive (for example, the gamepad) as not verified, with the reason.

## Features

| Feature | File | Scenario |
|---|---|---|
| Pistol: fire, hit, reload | [pistol.md](pistol.md) | `scenarios/pistol.txt` |
| Knife attack | [melee.md](melee.md) | `scenarios/melee.txt` |
| Rounds and intermission | [rounds.md](rounds.md) | `scenarios/rounds.txt` |
| Death and play again | [death-restart.md](death-restart.md) | `scenarios/death-restart.txt` |
| Pause and resume | [pause.md](pause.md) | `scenarios/pause.txt` |
| Movement: walk, sprint, slide, jump | [movement.md](movement.md) | `scenarios/movement.txt` |
