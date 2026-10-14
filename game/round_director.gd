class_name RoundDirector
extends RefCounted

enum Phase { STARTING, ACTIVE, INTERMISSION, GAME_OVER }

signal round_started(round_number: int)
signal round_cleared(round_number: int)
signal game_over(rounds_survived: int)

const TRANSITIONS: Dictionary[Phase, Array] = {
	Phase.STARTING: [Phase.ACTIVE, Phase.GAME_OVER],
	Phase.ACTIVE: [Phase.INTERMISSION, Phase.GAME_OVER],
	Phase.INTERMISSION: [Phase.ACTIVE, Phase.GAME_OVER],
	Phase.GAME_OVER: [],
}

var phase: Phase = Phase.STARTING
var round_number: int = 0
var to_spawn: int = 0
var alive: int = 0
## STARTING and INTERMISSION: time to the next round. ACTIVE: time to the next spawn.
var _timer: float = Rules.FIRST_ROUND_DELAY
var _rounds_cleared: int = 0


## Advances time. Returns how many zombies to spawn now. Never more than MAX_ALIVE - alive.
func tick(delta: float) -> int:
	match phase:
		Phase.STARTING, Phase.INTERMISSION:
			_timer -= delta
			if _timer > 0.0:
				return 0
			_start_round()
			return _spawn_due()
		Phase.ACTIVE:
			_timer -= delta
			return _spawn_due()
	return 0


func zombie_died() -> void:
	if phase != Phase.ACTIVE:
		return
	alive -= 1
	if to_spawn == 0 and alive == 0:
		_rounds_cleared = round_number
		_timer = Rules.INTERMISSION_SECONDS
		_enter(Phase.INTERMISSION)
		round_cleared.emit(round_number)


func player_died() -> void:
	if phase == Phase.GAME_OVER:
		return
	_enter(Phase.GAME_OVER)
	game_over.emit(_rounds_cleared)


func rounds_survived() -> int:
	return _rounds_cleared


func _start_round() -> void:
	round_number += 1
	to_spawn = Rules.zombie_count(round_number)
	_timer = 0.0
	_enter(Phase.ACTIVE)
	round_started.emit(round_number)


func _spawn_due() -> int:
	var count: int = 0
	while _timer <= 0.0 and to_spawn > 0 and alive < Rules.MAX_ALIVE:
		count += 1
		to_spawn -= 1
		alive += 1
		_timer += Rules.spawn_interval(round_number)
	# A spawn held back by MAX_ALIVE goes out on the first tick after a death, not in a burst of saved-up spawns.
	_timer = maxf(_timer, 0.0)
	return count


func _enter(next: Phase) -> void:
	assert(next in TRANSITIONS[phase], "RoundDirector cannot go from %s to %s" % [Phase.find_key(phase), Phase.find_key(next)])
	phase = next
