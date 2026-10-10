class_name CombatNpcChatResult
extends RefCounted

## What one npc.c chat() in a fight did: the lines it showed (said, or a special's
## message_vision()), whom a special hurt (their last_damage_from is the NPC) and who
## came in to kill whom (ask_for_help()'s kill_ob(), a summoned soldier's invocation()).
## Read-only once made.
var _lines: Array[VisionLine] = []
var _damaged: Array[StringName] = []
var _joins: Array[CombatJoin] = []
var _departure_zone_id: StringName = &""
var _special: SpecialReport


func _init(p_lines: Array[VisionLine] = [], p_damaged: Array[StringName] = []) -> void:
	_lines = p_lines.duplicate()
	_damaged = p_damaged.duplicate()


func with_joins(p_joins: Array[CombatJoin]) -> CombatNpcChatResult:
	_joins = p_joins.duplicate()
	return self


## A special whose file attacked (hasten.c): its lines and attacks, told and judged as
## the player's perform's are.
func with_special(report: SpecialReport) -> CombatNpcChatResult:
	_special = report
	return self


## The special's report when it attacked, else null.
func special() -> SpecialReport:
	return _special


## random_move() in a fight: the NPC walked out to this zone (go.c's remove_all_enemy()).
func with_departure(zone_id: StringName) -> CombatNpcChatResult:
	_departure_zone_id = zone_id
	return self


## The zone the NPC walked out to, or empty when it stayed.
func departure_zone_id() -> StringName:
	return _departure_zone_id


func joins() -> Array[CombatJoin]:
	return _joins.duplicate()


## Those who came in, in order.
func joiners() -> Array[StringName]:
	var ids: Array[StringName] = []
	for join: CombatJoin in _joins:
		ids.append(join.joiner_id)
	return ids


func lines() -> Array[VisionLine]:
	return _lines.duplicate()


func damaged(character_id: StringName) -> bool:
	return _damaged.has(character_id)
