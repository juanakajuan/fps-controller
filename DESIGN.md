# Survival FPS design

## Goal

A round-based survival FPS for Godot 4.7, in GDScript only. The player fights waves of undead. Each round has more zombies, and the zombies have more health and more speed. The player earns points for hits and kills. The game ends when the player dies. The score is the number of rounds the player survived.

The game builds all nodes, geometry, materials, input actions, and UI in code. It uses no external assets.

## Milestones

1. **Core loop.** This document. One map, one starting pistol, rounds with harder waves, zombies that find a path to the player, player health with regeneration, points, death, and restart.
2. **Weapons and buys.** Wall buys, a random weapon box, ammo buys. Points become a currency here.
3. **Upgrades.** Perk machines and a weapon upgrade machine.
4. **Map and secrets.** A larger map, doors that the player buys to open areas, a power switch, and hidden secrets.

Milestone 1 must not add speculative hooks for milestones 2 to 4. It must keep two shapes that the later milestones need: points are a balance that can go down (`spend`), and a weapon is data (`WeaponDef`) and not code.

## Usage

```gdscript
# game/main.tscn has one node with game/game.gd. Game builds everything:
var game: Game = Game.new()
get_tree().root.add_child(game)

# Tests drive the same objects without the Input singleton:
game.player.player_controlled = false
game.player.intent.move = Vector2(0.0, 1.0)
game.player.look(delta_yaw, delta_pitch)
game.weapon.trigger_held = true
game.director.phase  # RoundDirector.Phase.ACTIVE
game.points.balance  # int
game.player.health   # float
```

## Candidates

| | A. Node-centric | B. Pure rules and state, nodes for the world |
|---|---|---|
| Shape | Each node script owns its own rules. `game.gd` connects signals. Round logic lives in a `Node` with timers. | Round progress, wave formulas, and points are `RefCounted` objects and static functions with no scene tree. Nodes (player, zombie, weapon, level) do physics and report events. `Game` ticks the director and turns its spawn requests into zombie nodes. |
| Testability | Round tests need the scene tree and real time. | Round, wave, and points tests run with no physics, at any speed, with literal expected values. Physics tests still drive real bodies. |
| Milestone 2 to 4 cost | Buy logic must reach into many nodes. | Buys call `points.spend()`. Perks change numbers on `Rules` lookups or on the player. |
| Reader load | Rules spread across node scripts. | Rules in one file. Each node has one job. |

Choice: **B**. The rules of a wave shooter are a pure function of the round number. They do not need the scene tree. Keeping them pure gives fast, exact tests, and the later milestones add buys without touching physics code.

## Subtraction first

The game does not need the reusable addon surface. Remove these before adding game code:

- `addons/fps_controller/fps_recording.gd`, `FPSController.start_recording/stop_recording/is_recording/play/stop_playback/is_playing`, the `playback_finished` signal, the `_recording`, `_playback`, `_playback_tick` fields, `_apply_playback_tick()`, `_record_tick()`, and `FPSCameraRig.record_tick()` if it exists only for playback.
- `tests/record_golden.gd`, `tests/golden/`, and the record, playback, and golden tests in `tests/test_runner.gd`.
- `demo/` (the test level and the ghost).
- `manage_mouse_capture`. The game owns mouse capture, because death and pause release the mouse.

Keep `Intent`, `player_controlled`, and `look()`. Tests need them.

Then move and rename. The player is a part of the game now, not an addon:

| Old | New |
|---|---|
| `addons/fps_controller/fps_controller.gd`, `FPSController` | `game/player/player.gd`, `Player` |
| `addons/fps_controller/fps_camera_rig.gd`, `FPSCameraRig` | `game/player/player_camera_rig.gd`, `PlayerCameraRig` |
| `addons/fps_controller/fps_settings.gd`, `FPSSettings` | `game/player/player_settings.gd`, `PlayerSettings` |

`docs/player.md` keeps the movement design (state machine, movement model, stairs, camera rig) with the new names and with the record and play sections removed.

## Files

- `game/main.tscn`. The main scene. One `Node3D` with `game/game.gd`.
- `game/game.gd`. `class_name Game extends Node3D`. Builds the level, the player, the weapon, the HUD. Owns the `RoundDirector` and the `Points`. Each physics tick it ticks the director and spawns a zombie for each spawn request. Routes events: a weapon hit goes to the zombie and to points, a zombie attack goes to the player, a zombie death goes to the director and to points, player death goes to the director. Owns mouse capture, pause (Escape), and restart (Enter after death, by `get_tree().reload_current_scene()`).
- `game/rules.gd`. `class_name Rules`. Static functions and constants only. All tuning for rounds, zombies, points, and player health.
- `game/round_director.gd`. `class_name RoundDirector extends RefCounted`. The round state machine. No nodes.
- `game/points.gd`. `class_name Points extends RefCounted`. The point balance and the total earned.
- `game/player/player.gd`, `player_camera_rig.gd`, `player_settings.gd`. Movement as today, plus health.
- `game/weapon/weapon_def.gd`. `class_name WeaponDef extends Resource`. Data for one weapon.
- `game/weapon/weapon.gd`. `class_name Weapon extends Node3D`. A child of the player camera. Fire, reload, hitscan, and a box view model.
- `game/zombie/zombie.gd`. `class_name Zombie extends CharacterBody3D`. Chase, attack, die.
- `game/level/arena.gd`. `class_name Arena extends Node3D`. Floor, walls, cover blocks, lights, the baked navigation mesh, the player spawn, and the zombie spawn points.
- `game/hud.gd`. `class_name Hud extends CanvasLayer`. Round number, points, ammo, health vignette, crosshair, hit marker, round banner, death screen, pause screen.
- `tests/test_runner.gd`. The movement tests (renamed), plus the game tests below.
- `tests/visual_smoke.gd`. A windowed launch of `game/main.tscn` that captures one frame.
- `tests/run_checks.sh`. All headless checks.

## Data shapes

```gdscript
class_name Rules

enum HitKind { BODY, HEAD, MELEE }

const INTERMISSION_SECONDS: float = 10.0
const FIRST_ROUND_DELAY: float = 3.0
const MAX_ALIVE: int = 24

const POINTS_HIT: int = 10
const POINTS_KILL: int = 60
const POINTS_HEADSHOT_KILL: int = 100
const POINTS_MELEE_KILL: int = 130

const PLAYER_MAX_HEALTH: float = 100.0
const PLAYER_REGEN_DELAY: float = 4.0     # seconds with no damage before regeneration starts
const PLAYER_REGEN_RATE: float = 50.0     # health per second

const ZOMBIE_DAMAGE: float = 40.0
const ZOMBIE_ATTACK_RANGE: float = 1.3
const ZOMBIE_ATTACK_COOLDOWN: float = 1.2
const ZOMBIE_HEAD_HEIGHT: float = 1.5     # a hit above this height on the body is a headshot
const HEADSHOT_MULTIPLIER: float = 2.0

const MELEE_DAMAGE: float = 150.0         # one melee kills a round 1 zombie
const MELEE_SECONDS: float = 0.6          # total time in Weapon.State.MELEE
const MELEE_RANGE: float = 2.0

static func zombie_count(round_number: int) -> int        # total zombies in the round
static func zombie_health(round_number: int) -> float
static func zombie_speed(round_number: int, roll: float) -> float   # roll in [0, 1) picks walker, jogger, or runner
static func spawn_interval(round_number: int) -> float
static func points_for_hit(killed: bool, kind: HitKind) -> int   # 10 for any hit that does not kill. Kills: BODY 60, HEAD 100, MELEE 130.
```

Wave formulas (round `r`, starting at 1):

- `zombie_count(r) = 6 + 3 * (r - 1)`, with an extra `+ (r - 1) * (r - 1) / 4` (integer division) after round 5. Exact values for rounds 1, 2, 5, 10 go in the tests.
- `zombie_health(r) = 150 + 100 * (r - 1)` up to round 9. From round 10, `zombie_health(9) * 1.1 ^ (r - 9)`.
- `zombie_speed(r, roll)`. Walker 1.6 m/s, jogger 3.2 m/s, runner 5.0 m/s. The runner share is `clamp((r - 3) * 0.12, 0, 0.8)`. The jogger share is `clamp((r - 1) * 0.15, 0, 1 - runner share)`. The rest are walkers.
- `spawn_interval(r) = max(0.5, 2.0 - 0.15 * (r - 1))` seconds.

The implementer may change constants for game feel. Each change goes in the rationale at the end of this document, and the tests assert the new literal values.

```gdscript
class_name RoundDirector extends RefCounted

enum Phase { STARTING, ACTIVE, INTERMISSION, GAME_OVER }

signal round_started(round_number: int)
signal round_cleared(round_number: int)
signal game_over(rounds_survived: int)

var phase: Phase = Phase.STARTING
var round_number: int = 0
var to_spawn: int = 0      # zombies in this round not spawned yet
var alive: int = 0
var _timer: float = 0.0    # STARTING and INTERMISSION: time to the next round. ACTIVE: time to the next spawn.

## Advances time. Returns how many zombies to spawn now. Never more than MAX_ALIVE - alive.
func tick(delta: float) -> int
func zombie_died() -> void
func player_died() -> void
func rounds_survived() -> int  # round_number - 1 while ACTIVE, round_number in INTERMISSION
```

| From | Condition | To | Effect |
|---|---|---|---|
| STARTING | timer done | ACTIVE | `round_number = 1`, `to_spawn = zombie_count(1)`, emit `round_started` |
| ACTIVE | `to_spawn == 0` and `alive == 0` | INTERMISSION | emit `round_cleared`, timer = `INTERMISSION_SECONDS` |
| INTERMISSION | timer done | ACTIVE | `round_number += 1`, new `to_spawn`, emit `round_started` |
| any but GAME_OVER | `player_died()` | GAME_OVER | emit `game_over(rounds_survived())` |
| GAME_OVER | anything | GAME_OVER | `tick` returns 0 |

`tick` returns a count, not nodes. `Game` places the zombies. `alive` goes up by the returned count inside `tick`.

```gdscript
class_name Points extends RefCounted

signal changed(balance: int)

var balance: int = 500   # the starting balance
var earned: int = 0      # total earned, for the death screen

func earn(amount: int) -> void          # amount > 0
func spend(amount: int) -> bool         # false and no change if balance < amount
```

```gdscript
class_name WeaponDef extends Resource

@export var display_name: String
@export var damage: float
@export var fire_interval: float      # seconds between shots
@export var automatic: bool           # true: hold the trigger to fire
@export var magazine_size: int
@export var reserve_max: int
@export var reload_seconds: float
@export var range: float
@export var spread_degrees: float

static func starting_pistol() -> WeaponDef   # 8 rounds, 80 reserve, 35 damage, semi-automatic
```

```gdscript
class_name Weapon extends Node3D

enum State { READY, COOLDOWN, RELOADING, MELEE }

signal fired
signal hit(target: Zombie, damage: float, kind: Rules.HitKind)
signal ammo_changed(magazine: int, reserve: int)
signal reload_started
signal reload_finished

var def: WeaponDef
var state: State = State.READY
var magazine: int
var reserve: int
var trigger_held: bool = false      # the game writes this from input. Tests write it directly.
var reload_requested: bool = false  # kept until READY
var melee_requested: bool = false   # one tick

func refill() -> void   # magazine and reserve to full. Game calls it on each round_started.
```

The weapon fires on the physics tick. A semi-automatic weapon fires once per press of the trigger. An empty magazine starts a reload when there is reserve. The ray starts at the camera and excludes the player. A ray that hits a `Zombie` emits `hit`. The headshot test is `hit_position.y - zombie.global_position.y >= Rules.ZOMBIE_HEAD_HEIGHT`.

The melee is a state of the weapon, so the one state machine decides what the player can do with the weapon at a time:

| From | Condition | To | Effect |
|---|---|---|---|
| READY, COOLDOWN | `melee_requested` | MELEE | cast the melee ray, timer = `MELEE_SECONDS` |
| RELOADING | `melee_requested` | MELEE | as above, and `reload_requested = true`. Magazine and reserve do not change. |
| MELEE | `melee_requested` | MELEE | nothing. The request is cleared. |
| MELEE | timer done | READY | on the same tick, READY starts the pending reload or fires a pending press |

The melee ray starts at the camera, has the length `MELEE_RANGE`, and uses the mask `WORLD | ZOMBIES`. A wall stops it, and it hits at most one zombie. A hit emits `hit(target, MELEE_DAMAGE, HitKind.MELEE)`. A melee never fires and uses no ammunition. The view model thrusts forward by a sine over the MELEE time.

Ammo in milestone 1: `refill()` on each new round. Milestone 2 replaces this with ammo buys.

```gdscript
class_name Zombie extends CharacterBody3D

enum State { CHASE, ATTACK, DEAD }

signal attacked(damage: float)
signal died(headshot: bool)

var state: State = State.CHASE
var health: float
var speed: float
var target: Node3D                 # the player
var _agent: NavigationAgent3D
var _attack_cooldown_left: float = 0.0

func setup(health: float, speed: float, target: Node3D) -> void   # before add_child
func take_damage(amount: float, headshot: bool) -> void           # no effect when DEAD
```

A zombie is a capsule body (radius 0.35, height 1.8) with a box head mesh. In CHASE it follows `NavigationAgent3D` to the target with gravity. In range it goes to ATTACK, faces the target, and emits `attacked` when the cooldown ends. It goes back to CHASE when the target leaves range. In DEAD it turns off its collision, plays a short sink, and frees itself. Zombies do not collide with each other (avoidance on the agent keeps them apart).

```gdscript
# Added to Player:
signal health_changed(health: float)
signal died

var health: float = Rules.PLAYER_MAX_HEALTH
var alive: bool = true
var _regen_delay_left: float = 0.0

func take_damage(amount: float) -> void   # no effect when not alive. At 0: alive = false, player_controlled = false, emit died.
```

Collision layers: 1 world, 2 player, 3 zombies. The player collides with 1 and 3. Zombies collide with 1 and 2. The weapon ray uses mask 1 and 3.

```gdscript
class_name Arena extends Node3D

var player_spawn: Transform3D
var zombie_spawns: Array[Vector3]
var navigation: NavigationRegion3D

func build() -> void   # geometry and a synchronous navigation bake, before the first physics tick
```

The arena is a 40 m by 40 m yard with outer walls, cover blocks, one raised platform with stairs and a ramp, and eight zombie spawn points near the walls. `Game` picks the spawn point that is farthest from the player of four random candidates, so zombies do not appear in view at close range.

## Input

Movement actions as today. Add `fire` (left mouse), `reload` (R), `melee` (V, gamepad right stick press), `pause` (Escape), `restart` (Enter). Register missing actions in code, as the player does today.

## Boundaries

- `Rules`, `RoundDirector`, and `Points` trust their inputs. `Game` is the only caller.
- `Game` checks `Weapon.hit` targets with `is_instance_valid` because a zombie can die and free in the same tick as a second ray.
- The navigation bake is synchronous at build time. If the bake gives an empty mesh, `Arena.build()` pushes an error. Zombies need the mesh.

## Verification plan

Headless tests with literal expected values:

- `Rules`: counts, health, spawn interval for rounds 1, 2, 5, 10, 20. Speed shares for a fixed set of rolls.
- `RoundDirector`: STARTING to ACTIVE after `FIRST_ROUND_DELAY`. Spawn counts over time never pass `MAX_ALIVE`. Round clear after all deaths. Intermission length. GAME_OVER stops spawns. `rounds_survived` values.
- `Points`: earn, spend success, spend failure leaves the balance.
- `Weapon` in a real physics world: one shot per press when semi-automatic, the magazine count, auto reload at empty, reload time, no fire during reload, a ray hit on a zombie emits `hit`, a headshot test above head height, a wall blocks the ray.
- Melee in a real physics world: a melee hits a zombie 1.5 m ahead once for 150. MELEE lasts 36 ticks (0.6 s). A second request during MELEE does not hit and does not make MELEE longer. A held trigger does not fire during MELEE and fires once when MELEE ends. A wall blocks the melee of a zombie 1.6 m away. A zombie 3 m away is not hit. A melee during a reload leaves 7 and 80, the reload starts again when MELEE ends, and it loads 1 round after the full 84 ticks.
- Melee through `Game`: one melee kills a round 1 zombie and earns 130 points. A melee on a round 2 zombie (250 health) leaves 100 health and earns 10 points.
- `Zombie` in the real arena: reaches the player around a cover block, attacks at range with cooldown, dies at zero health, frees itself.
- `Player`: damage, regeneration after the delay, death stops control and emits `died`.
- `Game` integration: a full round 1 with forced kills through `Weapon.hit` leads to INTERMISSION and then round 2. Points after a kill and after a headshot kill. Player death leads to GAME_OVER. Restart reloads the scene.
- All the existing movement tests still pass on Jolt and on Godot Physics.
- `godot --headless --path . --quit-after 600` with no errors.
- `tests/visual_smoke.gd` captures a frame. A human (or the lead) inspects the image.

## Accepted deviations

- `Rules.points_for_hit(killed, kind)` is added. The points for a hit are a rule, so the rule lives in `Rules` and the test asserts it without a scene.
- `Rules.WALKER_SPEED`, `JOGGER_SPEED`, and `RUNNER_SPEED` name the three speeds of `zombie_speed`.
- `RoundDirector` has a `TRANSITIONS` table and a private `_rounds_cleared`. `_enter()` asserts each phase change against the table. `rounds_survived()` returns `_rounds_cleared`, because in GAME_OVER the phase no longer tells if the last round was cleared. The values are the same as in the design: 0 before round 1, `round_number - 1` while ACTIVE, `round_number` in INTERMISSION.
- A new round spawns its first zombie on the tick that starts it. Later spawns come one `spawn_interval` apart. A spawn that `MAX_ALIVE` holds back goes out on the first tick after a death, and the next one waits a full interval, so a long hold does not release a burst.
- `game/layers.gd` (`class_name Layers`) names the three collision layer bits: `WORLD` 1, `PLAYER` 2, `ZOMBIES` 4. `Player`, `Zombie`, `Weapon`, and `Arena` read them, so the numbers are in one place.
- The weapon ray does not use an exclusion list. Its mask is `WORLD | ZOMBIES`, and the player is on `PLAYER`, so the ray cannot hit the shooter.
- `Weapon.hit` reports the final damage. A headshot already has `HEADSHOT_MULTIPLIER` in it.
- `Weapon.reload_requested` stays set until the weapon is READY. A request during the cooldown after a shot is not lost. A semi-automatic press during the cooldown also fires when the cooldown ends.
- `Zombie` attacks only when the target is within 1.2 m of height as well as within `ZOMBIE_ATTACK_RANGE`. Without it, a zombie under the 1.5 m platform hits the player on top. The first attack comes on the first tick in ATTACK, then one each `ZOMBIE_ATTACK_COOLDOWN`.
- The navigation mesh uses a cell height of 0.1 m and a maximum climb of 0.2 m, and `Arena` sets the navigation map to the same cell height. With the 0.25 m default, the bake joins the 0.3 m stairs to the walkable mesh, but a zombie body cannot climb a step. Zombies use the ramp. The agent radius is 0.5 m, a whole number of 0.25 m cells, because the bake warns on a radius that is not.
- The navigation map takes in the baked region about three physics ticks after `Arena.build()`. The first zombie spawns 3 s after the start, so the game does not wait for it. Tests wait until the map gives a path.
- `Game` has a `zombies` node that holds the zombies, so the pause and the tests reach them in one place. `Game.set_paused()` and `Game.restart()` are public, and the input handler calls them. `Game` is `PROCESS_MODE_ALWAYS` so that it reads pause and restart while the tree is paused. The arena, the player, and the zombies are `PROCESS_MODE_PAUSABLE`.
- `Hud` has one method for each value it shows: `set_round`, `set_points`, `set_ammo`, `set_health`, `show_hit`, `show_banner`, `show_death`, and `set_paused`. Its labels and screens are public so that the game test reads what the player sees.
- The gamepad also gets actions: right trigger fires, X reloads, and Start pauses and, after death, restarts.
- `run/main_scene` is set in the commit that adds `game/main.tscn`, not in the move commit. The editor import fails while the main scene file is missing.
- The game test loads `game/main.tscn`, not `Game.new()`, because `reload_current_scene()` needs a scene file.
- The melee uses the existing `Weapon.hit` signal, not a parallel `melee_hit`. A melee kill earns more than a body kill, so `Game` must know the kind of hit in either case. `Rules.HitKind` (`BODY`, `HEAD`, `MELEE`) replaces the `headshot: bool` of `hit` and of `points_for_hit`. A melee that is also a headshot cannot be expressed, and `Game._on_weapon_hit` stays one handler with no branch for the melee.
- The melee hit test is a ray, not a shape cast. A ray hits at most one zombie and stops at a wall with no extra code. The zombie capsule is 0.7 m wide, so a ray at the crosshair is enough at 2 m.
- The melee ray is cast on the first tick of MELEE. The rest of `MELEE_SECONDS` is the recovery time.
- A fire press during MELEE is kept and fires on the tick that MELEE ends, the same as a press during the cooldown.
- A melee that interrupts a reload sets `reload_requested`. The reload starts again from the beginning when MELEE ends, and it takes the full `reload_seconds`.
