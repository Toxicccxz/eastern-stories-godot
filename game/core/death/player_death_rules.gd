class_name PlayerDeathRules
extends RefCounted

## feature/damage.c die() and reincarnate() for a user, plus the death penalty
## from adm/daemons/combatd.c killer_reward(). Corpse creation and relationship
## cleanup are done by the combat lifecycle before this runs. `pacing`'s death knobs lighten
## the penalty (DECISIONS「减轻死亡」); without one it is ES2's.


## die(): conditions are always cleared; the penalty applies only when someone
## dealt the last damage (killer_reward is called for last_damage_from).
## Resources end at 1/1 and the player is a ghost (ghost = 1).
static func die(state: CharacterState, has_killer: bool, pacing: PacingDefinition = null) -> PlayerDeathResult:
	var result: PlayerDeathResult = PlayerDeathResult.new()
	if state == null:
		return result
	result.conditions_cleared = state.conditions.size()
	state.conditions.clear()
	if has_killer:
		_apply_killer_reward_penalty(state, result, pacing)
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = 1
		resource.current = 1
	state.ghost = true
	return result


## reincarnate(): no ghost any more; effective resources return to maximum, current
## stays as is.
static func reincarnate(state: CharacterState) -> void:
	if state == null:
		return
	state.ghost = false
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum


## killer_reward() for userp(victim).
@warning_ignore("integer_division")
static func _apply_killer_reward_penalty(state: CharacterState, result: PlayerDeathResult, pacing: PacingDefinition) -> void:
	result.penalized = true
	result.bellicosity_lost = state.attributes.bellicosity
	state.attributes.bellicosity = 0
	state.vendetta.clear()
	CrimeRecord.halve_thief(state)
	var exp_percent: int = PacingDefinition.ES2_DEATH_EXP_PERCENT if pacing == null else pacing.death_exp_percent
	result.combat_experience_lost = state.progression.combat_experience / 10 if exp_percent == PacingDefinition.ES2_DEATH_EXP_PERCENT else state.progression.combat_experience * exp_percent / 100
	state.progression.combat_experience -= result.combat_experience_lost
	var progression: CharacterProgressionState = state.progression
	if progression.potential > progression.potential_spent and (pacing == null or not pacing.death_keeps_potential):
		var before: int = progression.potential
		progression.potential += (progression.potential_spent - progression.potential) / 2
		result.potential_lost = before - progression.potential
	if pacing != null and pacing.death_keeps_skills:
		return
	result.enabled_skills_cleared = state.skills.enabled_use_ids().size() if state.skills.has_skills_mapping() else 0
	result.skill_changes = state.skills.apply_death_penalty()
