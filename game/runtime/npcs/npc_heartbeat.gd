class_name NpcHeartbeat
extends RefCounted

## What std/char.c heart_beat() does for the NPCs of the active map while no fight
## runs: heal_up() on the `5 + random(10)` tick (one transient cadence per NPC, as
## for the player, DECISIONS S5B) and feature/damage.c revive() once an unconscious
## NPC's call_out comes due. Fighting or busy NPCs heal as the player does (S5B C-D;
## busy wears down on the beat, continue_action()); conditions update on the tick
## before heal_up() (their lines are told to the NPC: nobody hears them); an unconscious
## NPC heals too (char.c keeps calling heal_up()). Timed applies (powerup) count
## down on world time, as call_out() does.
## Cadences are not saved; the revive countdown and timed applies are.
var _random: RecoveryCadenceRandomSource
var _cadences: Dictionary[StringName, PlayerRecoveryCadence] = {}
var _conditions: ConditionSystem = ConditionSystem.new()
var _revive_remainder_ms: Dictionary[StringName, float] = {}
var _timed_remainder_ms: Dictionary[StringName, float] = {}


func _init(random: RecoveryCadenceRandomSource) -> void:
	_random = random


## Advances one step of world time and returns the NPCs that came to.
func advance(delta: float, npcs: Array[NpcRuntimeState]) -> Array[NpcRuntimeState]:
	var woke: Array[NpcRuntimeState] = []
	if _random == null or not is_finite(delta) or delta < 0.0:
		return woke
	for npc: NpcRuntimeState in npcs:
		if npc == null or not npc.exists_in_map:
			continue
		if npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			continue
		_wear_timed_applies(npc, delta)
		if not npc.relationship.is_fighting():
			var cadence: PlayerRecoveryCadence = _cadences.get(npc.character_id)
			if cadence == null:
				cadence = PlayerRecoveryCadence.new(_random, false, _conditions)
				_cadences[npc.character_id] = cadence
			if cadence.is_valid():
				cadence.advance(delta, npc.character_state, npc.busy)
		if npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and _count_down(npc, delta):
			npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
			woke.append(npc)
	return woke


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
