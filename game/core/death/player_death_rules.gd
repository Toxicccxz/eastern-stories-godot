class_name PlayerDeathRules
extends RefCounted

## feature/damage.c die() and reincarnate() for a user, plus the death penalty
## from adm/daemons/combatd.c killer_reward(). Corpse creation and relationship
## cleanup are done by the combat lifecycle before this runs.


## die(): conditions are always cleared; the penalty applies only when someone
## dealt the last damage (killer_reward is called for last_damage_from).
## Resources end at 1/1 while the player is a ghost.
static func die(state: CharacterState, has_killer: bool) -> PlayerDeathResult:
	var result: PlayerDeathResult = PlayerDeathResult.new()
	if state == null:
		return result
	result.conditions_cleared = state.conditions.size()
	state.conditions.clear()
	if has_killer:
		_apply_killer_reward_penalty(state, result)
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = 1
		resource.current = 1
	return result


## reincarnate(): effective resources return to maximum; current stays as is.
static func reincarnate(state: CharacterState) -> void:
	if state == null:
		return
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum


## killer_reward() for userp(victim). thief is not modelled.
@warning_ignore("integer_division")
static func _apply_killer_reward_penalty(state: CharacterState, result: PlayerDeathResult) -> void:
	result.penalized = true
	result.bellicosity_lost = state.attributes.bellicosity
	state.attributes.bellicosity = 0
	state.vendetta.clear()
	result.combat_experience_lost = state.progression.combat_experience / 10
	state.progression.combat_experience -= result.combat_experience_lost
	var progression: CharacterProgressionState = state.progression
	if progression.potential > progression.potential_spent:
		var before: int = progression.potential
		progression.potential += (progression.potential_spent - progression.potential) / 2
		result.potential_lost = before - progression.potential
	result.enabled_skills_cleared = state.skills.enabled_use_ids().size() if state.skills.has_skills_mapping() else 0
	result.skill_changes = state.skills.apply_death_penalty()
