class_name CombatSparSummary
extends RefCounted
## What a finished 切磋 came to, for the card after it (native, owner 2026-11-22: a summary
## after a spar): who won (fight.c's spar ends on the first blow that draws 气: whoever landed
## it), against whom, how many rounds, and what the player gained in it — 实战经验, 潜能 and the
## skills that rose or moved on — read as the player's state before and after. It decides
## nothing: the fight's rules already did.

enum Outcome { WON, LOST, EVEN }

## A skill the spar moved: its level before and after, or progress only.
class SkillGain:
	var skill_id: StringName
	var level_before: int
	var level_after: int

	func _init(p_skill_id: StringName, p_before: int, p_after: int) -> void:
		skill_id = p_skill_id
		level_before = p_before
		level_after = p_after

	func levelled() -> bool:
		return level_after > level_before


var encounter_id: StringName
var outcome: int = Outcome.EVEN
## The other side's ids (the NPCs sparred with).
var opponent_ids: Array[StringName] = []
var rounds: int = 0
var combat_experience_gained: int = 0
var potential_gained: int = 0
var skills: Array[SkillGain] = []


## The player's numbers a spar may move, as they stand (taken as it starts).
static func snapshot(state: CharacterState) -> Dictionary:
	var levels: Dictionary[StringName, int] = {}
	var progress: Dictionary[StringName, int] = {}
	if state != null:
		for skill_id: StringName in state.skills.raw_skill_ids():
			levels[skill_id] = state.skills.raw_level(skill_id)
			progress[skill_id] = state.skills.learned_progress(skill_id)
	return {
		"exp": 0 if state == null else state.progression.combat_experience,
		"potential": 0 if state == null else state.progression.potential,
		"levels": levels,
		"progress": progress,
	}


## The summary of `encounter_id`: `winner_id` the spar's winner (empty: nobody landed the
## blow), `player_id` the player, `before` snapshot() as it began, `state` the player now.
static func build(p_encounter_id: StringName, player_id: StringName, winner_id: StringName, opponents: Array[StringName], p_rounds: int, before: Dictionary, state: CharacterState) -> CombatSparSummary:
	var summary := CombatSparSummary.new()
	summary.encounter_id = p_encounter_id
	summary.opponent_ids = opponents.duplicate()
	summary.rounds = p_rounds
	if winner_id.is_empty():
		summary.outcome = Outcome.EVEN
	elif winner_id == player_id:
		summary.outcome = Outcome.WON
	else:
		summary.outcome = Outcome.LOST
	if state == null or before.is_empty():
		return summary
	summary.combat_experience_gained = maxi(state.progression.combat_experience - int(before.get("exp", 0)), 0)
	summary.potential_gained = maxi(state.progression.potential - int(before.get("potential", 0)), 0)
	var levels: Dictionary = before.get("levels", {})
	var progress: Dictionary = before.get("progress", {})
	var ids: Array[StringName] = state.skills.raw_skill_ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for skill_id: StringName in ids:
		var level: int = state.skills.raw_level(skill_id)
		var was: int = int(levels.get(skill_id, 0))
		var moved: bool = state.skills.learned_progress(skill_id) > int(progress.get(skill_id, 0))
		if level > was or (level == was and moved):
			summary.skills.append(SkillGain.new(skill_id, was, level))
	# The skills that rose first.
	summary.skills.sort_custom(func(a: SkillGain, b: SkillGain) -> bool: return a.levelled() and not b.levelled())
	return summary


func gained_anything() -> bool:
	return combat_experience_gained > 0 or potential_gained > 0 or not skills.is_empty()
