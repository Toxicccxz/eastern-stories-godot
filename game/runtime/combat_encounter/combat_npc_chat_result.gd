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
## 战斗决策层 1B: the special chat() drew but did not run yet (npc_telegraph): announced
## now, run on the NPC's next beat unless interrupted.
var _telegraph: NpcSpecialAction
var _telegraph_label: String = ""
var _ran_special: NpcSpecialAction
## 战斗决策层 4: the name the special ran under, as announced (「封」字诀), for the card's title.
var _special_label: String = ""
## Native (步玄 A; DECISIONS「打着念」): a fight chant's line — the mark it sets on the player ("" none),
## and whether the NPC won the spar with it.
var _chant_mark: String = ""
var _ends_spar: bool = false


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


func with_telegraph(action: NpcSpecialAction, label: String) -> CombatNpcChatResult:
	_telegraph = action
	_telegraph_label = label
	return self


## The special announced this beat (run next beat), or null.
func telegraph() -> NpcSpecialAction:
	return _telegraph


func telegraph_label() -> String:
	return _telegraph_label


## 战斗拍数 C: the special chat() ran on the spot (npc_telegraph off), for its beats' cost.
func with_ran_special(action: NpcSpecialAction) -> CombatNpcChatResult:
	_ran_special = action
	return self


func ran_special() -> NpcSpecialAction:
	return _ran_special


func with_special_label(label: String) -> CombatNpcChatResult:
	_special_label = label
	return self


## The announced name of the special that ran this beat, "" when it had none.
func special_label() -> String:
	return _special_label


## A fight chant's line (NpcHooks.fight_chant): `mark` set on the player, `ends_spar` the NPC wins the spar.
func with_chant(mark: String, ends_spar: bool) -> CombatNpcChatResult:
	_chant_mark = mark
	_ends_spar = ends_spar
	return self


func chant_mark() -> String:
	return _chant_mark


## The NPC won the spar with this line (its fight chant's last): both stop, as combatd.c's friendly stop.
func ends_spar() -> bool:
	return _ends_spar


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
