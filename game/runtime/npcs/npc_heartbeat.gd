class_name NpcHeartbeat
extends RefCounted

## What std/char.c heart_beat() does for the NPCs of the active map while no fight
## runs: heal_up() on the `5 + random(10)` tick (one transient cadence per NPC, as
## for the player, DECISIONS S5B) and feature/damage.c revive() once an unconscious
## NPC's call_out comes due. Fighting or busy NPCs heal as the player does (S5B C-D;
## busy wears down on the beat, continue_action()); conditions update on the tick
## before heal_up() (their lines are told to the NPC: nobody hears them); an unconscious
## NPC heals too (char.c keeps calling heal_up()). What a condition shows the room
## (drunk.c's 脸上已经略显酒意了) is kept per NPC for the map to show whoever is there.
## Timed applies (powerup) count down on world time, as call_out() does.
## Cadences are not saved; the revive countdown and timed applies are.
var _random: RecoveryCadenceRandomSource
var _cadences: Dictionary[StringName, PlayerRecoveryCadence] = {}
var _conditions: ConditionSystem = ConditionSystem.new()
var _revive_remainder_ms: Dictionary[StringName, float] = {}
var _timed_remainder_ms: Dictionary[StringName, float] = {}
## The last advance's room lines of each NPC's conditions ({name} templates).
var room_lines: Dictionary[StringName, Array] = {}
## The last advance's heal_up() calls of each NPC that made any (zombie.c's heal_up()
## does more: WorldMapSpells).
var heal_ups: Dictionary[StringName, int] = {}


func _init(random: RecoveryCadenceRandomSource) -> void:
	_random = random


## Advances one step of world time and returns the NPCs that came to.
func advance(delta: float, npcs: Array[NpcRuntimeState]) -> Array[NpcRuntimeState]:
	var woke: Array[NpcRuntimeState] = []
	room_lines.clear()
	heal_ups.clear()
	if _random == null or not is_finite(delta) or delta < 0.0:
		return woke
	for npc: NpcRuntimeState in npcs:
		if npc == null or not npc.exists_in_map:
			continue
		if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			continue
		_wear_timed_applies(npc, delta)
		if not npc.relationship.is_fighting():
			var cadence: PlayerRecoveryCadence = _cadence(npc)
			if cadence.is_valid():
				var beat: PlayerRecoveryCadenceResult = cadence.advance(
					delta, npc.character_state, npc.busy, npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE,
				)
				if not beat.room_lines.is_empty():
					room_lines[npc.character_id] = beat.room_lines
				if beat.heal_ups > 0:
					heal_ups[npc.character_id] = beat.heal_ups
		if npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and _count_down(npc, delta):
			npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
			woke.append(npc)
	return woke


## What catch_up() came to for one NPC.
class CatchUp:
	extends RefCounted
	## Seconds still to catch up: the NPC fell below zero with these left (the map lets it
	## fall, then catches up the rest); 0 when done.
	var left: float = 0.0
	var woke: bool = false
	var heal_ups: int = 0


## 别的地图时间补算 (DECISIONS): `seconds` of the NPC's heart beat on a map the player was
## away from, at once, as advance() would have run them: in steps that end at its next
## heal_up() tick or its revive, so a tick never meets the revive out of order. Stops once
## a tick would change nothing (CharacterRecovery.is_settled(): char.c turns that heart beat
## off), or when the NPC falls below zero (CatchUp.left). Room lines go unheard.
func catch_up(npc: NpcRuntimeState, seconds: float) -> CatchUp:
	var result: CatchUp = CatchUp.new()
	var left: float = seconds if is_finite(seconds) else 0.0
	while left > 0.0:
		if npc == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			return result
		var skills: RecoverySkillLevels = _skills(npc.character_state)
		if _plain(npc):
			# Only heal_up() is left to come: its ticks counted at once and run, until one
			# changes nothing (nothing will after it).
			if CharacterRecovery.is_settled(npc.character_state, skills):
				return result
			var cadence: PlayerRecoveryCadence = _cadence(npc)
			var ticks: int = cadence.ticks_in(left)
			var water_use: int = GameContent.catalog().pacing().npc_thirst
			for _tick: int in maxi(ticks, 0):
				result.heal_ups += 1
				if CharacterRecovery.apply_tick(npc.character_state, skills, false, false, 1, water_use) == 0:
					break
			return result
		var step: float = minf(left, _seconds_to_next_tick(npc))
		if npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			step = minf(step, maxf(npc.revive_in_ms, 1) / 1000.0)
		step = maxf(step, 0.001)
		if not advance(step, [npc]).is_empty():
			result.woke = true
		result.heal_ups += heal_ups.get(npc.character_id, 0)
		left -= step
		if npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.character_state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
			result.left = maxf(left, 0.0)
			return result
	return result


## Only heal_up() is left for a beat to do: the NPC awake, not fighting or busy, nothing
## timed or ailing.
func _plain(npc: NpcRuntimeState) -> bool:
	var character: CharacterState = npc.character_state
	return (
		npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not npc.busy.is_busy()
		and not npc.relationship.is_fighting()
		and character.timed_applies.is_empty() and character.conditions.size() == 0
	)


static func _skills(character: CharacterState) -> RecoverySkillLevels:
	return RecoverySkillLevels.new(
		character.skills.raw_level(&"magic"), character.skills.raw_level(&"force"),
		character.skills.raw_level(&"spells"),
	)


func _cadence(npc: NpcRuntimeState) -> PlayerRecoveryCadence:
	var cadence: PlayerRecoveryCadence = _cadences.get(npc.character_id)
	if cadence == null:
		var pacing: PacingDefinition = GameContent.catalog().pacing()
		cadence = PlayerRecoveryCadence.new(_random, false, _conditions, 1, pacing.npc_thirst, pacing.heart_beat_seconds)
		_cadences[npc.character_id] = cadence
	return cadence


## Seconds of world time to the NPC's next heal_up() tick: the beats its cadence still
## counts down (one beat while busy, which spends beats without counting them).
func _seconds_to_next_tick(npc: NpcRuntimeState) -> float:
	var cadence: PlayerRecoveryCadence = _cadences.get(npc.character_id)
	if cadence == null or not cadence.is_valid():
		var pulse: float = GameContent.catalog().pacing().heart_beat_seconds
		return pulse
	var beats: int = 1 if npc.busy.is_busy() else cadence.source_tick + 1
	return beats * cadence.pulse_seconds - cadence.accumulated_seconds


## The NPC woke otherwise (revive() called on it): its count-down starts afresh next time.
func forget_revive(character_id: StringName) -> void:
	_revive_remainder_ms.erase(character_id)


## An NPC the room replaced (room.c reset()) beats no more.
func forget(character_id: StringName) -> void:
	_cadences.erase(character_id)
	_revive_remainder_ms.erase(character_id)
	_timed_remainder_ms.erase(character_id)


func _wear_timed_applies(npc: NpcRuntimeState, delta: float) -> void:
	var timed: CharacterTimedApplies = npc.character_state.timed_applies
	if timed.is_empty():
		_timed_remainder_ms.erase(npc.character_id)
		return
	var elapsed: float = _timed_remainder_ms.get(npc.character_id, 0.0) + delta * 1000.0
	var whole: int = int(elapsed)
	_timed_remainder_ms[npc.character_id] = elapsed - whole
	timed.advance(whole)


func _count_down(npc: NpcRuntimeState, delta: float) -> bool:
	var elapsed: float = _revive_remainder_ms.get(npc.character_id, 0.0) + delta * 1000.0
	var whole: int = int(elapsed)
	_revive_remainder_ms[npc.character_id] = elapsed - whole
	npc.set_revive_in_ms(npc.revive_in_ms - whole)
	if npc.revive_in_ms > 0:
		return false
	_revive_remainder_ms.erase(npc.character_id)
	return true
