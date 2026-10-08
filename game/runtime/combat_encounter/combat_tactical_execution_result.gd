class_name CombatTacticalExecutionResult
extends RefCounted

## DISENGAGED is a semantic terminal intent; only encounter resolution may apply it.
enum Outcome { UNSUPPORTED, APPLIED, FAILED, DISENGAGED }

var _outcome: int
var _effect_id: StringName
var _lines: Array[ColoredLine] = []
var _special: SpecialReport
var _joiners: Array[StringName] = []
var _allies: Array[StringName] = []
var _joins: Array[CombatJoin] = []
var _departure: StringName
var outcome: int:
	get: return _outcome
var effect_id: StringName:
	get: return _effect_id
## What a perform file showed and did (its lines and attacks), or null.
var special: SpecialReport:
	get: return _special
## Those the action had kill_ob() the player (roar.c), in order: the fight takes in
## the ones not yet in it and goes on to the death.
var joiners: Array[StringName]:
	get: return _joiners.duplicate()
## Those who came in or turned against the player's side, each with whom it kills (an
## NPC's chat: ask_for_help(), its soldier's invocation()).
var joins: Array[CombatJoin]:
	get: return _joins.duplicate()
## Those the action called in on the player's side (saveme.c's soldier): each kills
## the player's living enemies, who kill it back, and the fight goes on to the death.
var allies: Array[StringName]:
	get: return _allies.duplicate()
## The room the action took the player to (dun.c at oneself), or empty: DISENGAGED,
## and the world moves the player there once the fight has let them go.
var departure: StringName:
	get: return _departure


## `lines`: what the action printed (exert.c's), in the shown language.
func _init(
	p_outcome: int = Outcome.UNSUPPORTED, p_effect_id: StringName = &"", p_lines: Array[ColoredLine] = [],
	p_special: SpecialReport = null, p_joiners: Array[StringName] = [],
) -> void:
	_outcome = p_outcome
	_effect_id = p_effect_id
	_lines = p_lines.duplicate()
	_special = p_special
	_joiners = p_joiners.duplicate()


func with_allies(p_allies: Array[StringName]) -> CombatTacticalExecutionResult:
	_allies = p_allies.duplicate()
	return self


func with_joins(p_joins: Array[CombatJoin]) -> CombatTacticalExecutionResult:
	_joins = p_joins.duplicate()
	return self


func with_departure(room_id: StringName) -> CombatTacticalExecutionResult:
	_departure = room_id
	return self


func lines() -> Array[ColoredLine]:
	return _lines.duplicate()


func duplicate_snapshot() -> CombatTacticalExecutionResult:
	return CombatTacticalExecutionResult.new(_outcome, _effect_id, _lines, _special, _joiners).with_allies(_allies).with_joins(_joins).with_departure(_departure)
