class_name CombatSpecialAttackSource
extends SpecialAttackSource

## do_attack() for a special file run in a fight: a direct attack between two of its
## participants (CombatSliceOpportunityExecutor.execute_direct_attack()) with the
## fight's random source and skill_improved() effects.
var _bindings: Array[CombatSliceCharacterBinding] = []
var _random: CombatRandomSource
var _effects: SkillImprovementEffectRegistry


func _init(bindings: Array[CombatSliceCharacterBinding], random_source: CombatRandomSource, effects: SkillImprovementEffectRegistry) -> void:
	_bindings = bindings
	_random = random_source
	_effects = effects


## Null when either side cannot take part (not in the fight, not conscious).
func attack(attacker_id: StringName, victim_id: StringName) -> SpecialAttack:
	var actor: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(_bindings, attacker_id)
	var victim: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(_bindings, victim_id)
	var result: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_direct_attack(actor, victim, _bindings, _random, _effects)
	if result.forward_result == null:
		return null
	var made := SpecialAttack.new(attacker_id, victim_id, result.forward_result, result.chain_result)
	made.told = result.post_action_lines()
	made.reverse_told = result.reverse_post_action_lines()
	return made


## The special files' view of a fight: `actor` as `me`, everyone else as `others`
## and its enemies (in its order, those there and conscious, or unconscious and
## marked to kill: a killer keeps them) as `enemies`.
static func context_for(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effects: SkillImprovementEffectRegistry,
) -> SpecialContext:
	var others: Array[SpecialSide] = []
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != actor:
			others.append(CombatNpcChat.side_of(binding, null))
	var enemies: Array[SpecialSide] = []
	for opponent_id: StringName in actor.relationship.opponent_ids():
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, opponent_id)
		if binding == null or not binding.exists_in_encounter or binding.location_id != actor.location_id:
			continue
		if binding.life_status == CombatSliceLifeStatus.Value.ACTIVE or (
			binding.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS and actor.relationship.has_lethal_target(opponent_id)
		):
			for side: SpecialSide in others:
				if side.character_id == opponent_id:
					enemies.append(side)
	var context := SpecialContext.new(
		CombatNpcChat.side_of(actor, null), enemies, random_source.legacy_random, GameContent.catalog(), effects, others,
	)
	context.attack_source = CombatSpecialAttackSource.new(bindings, random_source, effects)
	return context
