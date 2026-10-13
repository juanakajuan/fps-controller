class_name FPSRecording
extends Resource

enum ButtonBit { JUMP_PRESSED = 1, JUMP_HELD = 2, SPRINT_HELD = 4, CROUCH_HELD = 8 }

@export var tick_rate: int = 0
@export var start_position: Vector3 = Vector3.ZERO
@export var start_velocity: Vector3 = Vector3.ZERO
@export var start_yaw: float = 0.0
@export var start_pitch: float = 0.0
@export var moves: PackedVector2Array = PackedVector2Array()
@export var buttons: PackedByteArray = PackedByteArray()
## Absolute angles, not look deltas. Look changes on each rendered frame, so deltas summed per tick would drift.
@export var yaws: PackedFloat64Array = PackedFloat64Array()
@export var pitches: PackedFloat64Array = PackedFloat64Array()


func tick_count() -> int:
	return moves.size()


## Returns an empty string if the recording can play at this tick rate, or else the reason that it cannot.
func validation_error(current_tick_rate: int) -> String:
	if tick_rate <= 0:
		return "tick_rate is %d. It must be more than 0." % tick_rate
	if tick_rate != current_tick_rate:
		return "tick_rate is %d, but the physics tick rate is %d." % [tick_rate, current_tick_rate]
	var count: int = moves.size()
	if buttons.size() != count or yaws.size() != count or pitches.size() != count:
		return "The per-tick arrays have different lengths: moves %d, buttons %d, yaws %d, pitches %d." % [count, buttons.size(), yaws.size(), pitches.size()]
	return ""
