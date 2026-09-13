class_name PlayerRecoveryCadence
extends RefCounted

## S5B: owner-approved Native timing, NOT a proven ES2 wall-clock period.
## Source std/char.c: if (tick--) return; else tick = 5 + random(10).
## Runtime caller owns eligibility. This object owns no character, timer or Save.
const BASE_PULSE_SECONDS: float = 2.0

var _random: RecoveryCadenceRandomSource
var _accumulator: float = 0.0
var _source_tick: int = -1
var _valid: bool = false

var accumulated_seconds: float:
	get: return _accumulator
var source_tick: int:
	get: return _source_tick


func _init(random: RecoveryCadenceRandomSource) -> void:
	_random = random
	if _random != null:
		_source_tick = _random.draw_reset_tick()
		_valid = _source_tick >= 5 and _source_tick <= 14


func is_valid() -> bool:
	return _valid


func advance(delta: float, character: CharacterState, busy: ActionBusyState) -> PlayerRecoveryCadenceResult:
	var result: PlayerRecoveryCadenceResult = PlayerRecoveryCadenceResult.new()
	if not _valid or character == null or busy == null or not is_finite(delta) or delta < 0.0:
		result.outcome = PlayerRecoveryCadenceResult.Outcome.INVALID_INPUT
		return result
	var accumulated: float = _accumulator + delta
	# Checked arithmetic: an input whose float cannot represent subtracting one
	# pulse is not executable cadence time. Reject it, never clamp/discard a tail.
	if not is_finite(accumulated) or (accumulated >= BASE_PULSE_SECONDS and accumulated - BASE_PULSE_SECONDS == accumulated):
		result.outcome = PlayerRecoveryCadenceResult.Outcome.INVALID_INPUT
		return result
	_accumulator = accumulated
	while _accumulator >= BASE_PULSE_SECONDS:
		_accumulator -= BASE_PULSE_SECONDS
		result.pulses += 1
		# Borrow busy at pulse entry; never advance or clear it here.
		if busy.is_busy():
			result.busy_pulses += 1
			continue
		if _source_tick > 0:
			_source_tick -= 1
			continue
		_source_tick = _random.draw_reset_tick()
		if _source_tick < 5 or _source_tick > 14:
			# Reached draw/pulse stays consumed; no retry, clamp or rollback.
			_valid = false
			result.outcome = PlayerRecoveryCadenceResult.Outcome.INVALID_RANDOM
			return result
		var skills: RecoverySkillLevels = RecoverySkillLevels.new(
			character.skills.raw_level(&"magic"), character.skills.raw_level(&"force"),
			character.skills.raw_level(&"spells"),
		)
		result.last_update_count = CharacterRecovery.apply_tick(character, skills, true, false)
		result.opportunities += 1
	return result
