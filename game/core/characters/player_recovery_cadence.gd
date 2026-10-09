class_name PlayerRecoveryCadence
extends RefCounted

## S5B: owner-approved Native timing, NOT a proven ES2 wall-clock period.
## Source std/char.c: if (tick--) return; else tick = 5 + random(10).
## Runtime caller owns eligibility. This object owns no character, timer or Save.
## NPCs run the same cadence (NpcHeartbeat) with is_player_character false. Outside a
## fight it is the heart beat that wears busy down (a fight's scheduler does inside one).
## On the tick, update_condition() runs before heal_up(), which a condition's
## CND_NO_HEAL_UP skips (char.c).
const BASE_PULSE_SECONDS: float = 2.0

var _random: RecoveryCadenceRandomSource
var _conditions: ConditionSystem
var _is_player_character: bool = true
## Times what heal_up() restores (pacing.json player_recovery_gain for the player; 1 is ES2).
var _recovery_gain: int = 1
## Water used up per heal_up() (pacing.json npc_thirst for NPCs; 1 is ES2).
var _water_use: int = 1
var _accumulator: float = 0.0
var _source_tick: int = -1
var _valid: bool = false

var accumulated_seconds: float:
	get: return _accumulator
var source_tick: int:
	get: return _source_tick


func _init(random: RecoveryCadenceRandomSource, is_player_character: bool = true, conditions: ConditionSystem = null, recovery_gain: int = 1, water_use: int = 1) -> void:
	_random = random
	_conditions = conditions if conditions != null else ConditionSystem.new()
	_is_player_character = is_player_character
	_recovery_gain = maxi(recovery_gain, 1)
	_water_use = maxi(water_use, 1)
	if _random != null:
		_source_tick = _random.draw_reset_tick()
		_valid = _source_tick >= 5 and _source_tick <= 14


func is_valid() -> bool:
	return _valid


## `conscious` is living(me) for the conditions that ask it (an NPC's heart beat runs
## on while it lies unconscious; the player's conditions wait, owner).
func advance(delta: float, character: CharacterState, busy: ActionBusyState, conscious: bool = true) -> PlayerRecoveryCadenceResult:
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
		# char.c heart_beat(): a busy character spends the beat in continue_action().
		if busy.is_busy():
			busy.advance()
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
		var conditions: ConditionUpdateResult = _conditions.update_once(character, conscious)
		result.conditions_updated += conditions.updated
		result.lines.append_array(conditions.lines)
		result.room_lines.append_array(conditions.room_lines)
		if conditions.knocked_out:
			# A daemon's unconcious() (drunk.c): the fall happens at the caller's life
			# check, so this beat's heal_up() must not lift sen back above zero first.
			result.opportunities += 1
			break
		var skills: RecoverySkillLevels = RecoverySkillLevels.new(
			character.skills.raw_level(&"magic"), character.skills.raw_level(&"force"),
			character.skills.raw_level(&"spells"),
		)
		result.last_update_count = CharacterRecovery.apply_tick(character, skills, _is_player_character, conditions.no_heal_up, _recovery_gain, _water_use)
		result.opportunities += 1
		if not conditions.no_heal_up:
			result.heal_ups += 1
		# A condition that left the character below zero ends the advance here: the
		# caller lets it fall (char.c heart_beat checks at the start of the next beat).
		if character.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
			break
	return result
