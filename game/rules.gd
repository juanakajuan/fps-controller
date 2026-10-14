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
const PLAYER_REGEN_DELAY: float = 4.0
const PLAYER_REGEN_RATE: float = 50.0

const ZOMBIE_DAMAGE: float = 40.0
const ZOMBIE_ATTACK_RANGE: float = 1.3
const ZOMBIE_ATTACK_COOLDOWN: float = 1.2
const ZOMBIE_HEAD_HEIGHT: float = 1.5
const HEADSHOT_MULTIPLIER: float = 2.0

const MELEE_DAMAGE: float = 150.0
const MELEE_SECONDS: float = 0.6
const MELEE_RANGE: float = 2.0

const WALKER_SPEED: float = 1.6
const JOGGER_SPEED: float = 3.2
const RUNNER_SPEED: float = 5.0


static func zombie_count(round_number: int) -> int:
	var count: int = 6 + 3 * (round_number - 1)
	if round_number > 5:
		count += floori((round_number - 1) * (round_number - 1) / 4.0)
	return count


static func zombie_health(round_number: int) -> float:
	if round_number <= 9:
		return 150.0 + 100.0 * (round_number - 1)
	return zombie_health(9) * pow(1.1, round_number - 9)


## roll is in [0, 1). The low rolls are runners, then joggers, then walkers.
static func zombie_speed(round_number: int, roll: float) -> float:
	var runner_share: float = clampf((round_number - 3) * 0.12, 0.0, 0.8)
	var jogger_share: float = clampf((round_number - 1) * 0.15, 0.0, 1.0 - runner_share)
	if roll < runner_share:
		return RUNNER_SPEED
	if roll < runner_share + jogger_share:
		return JOGGER_SPEED
	return WALKER_SPEED


static func spawn_interval(round_number: int) -> float:
	return maxf(0.5, 2.0 - 0.15 * (round_number - 1))


static func points_for_hit(killed: bool, kind: HitKind) -> int:
	if not killed:
		return POINTS_HIT
	match kind:
		HitKind.HEAD:
			return POINTS_HEADSHOT_KILL
		HitKind.MELEE:
			return POINTS_MELEE_KILL
	return POINTS_KILL
