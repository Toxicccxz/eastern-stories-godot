class_name CombatAttackChainCompletionService
extends RefCounted

const UNARMED_SKILL_ID: StringName = &"unarmed"
const FORCE_SKILL_ID: StringName = &"force"

## Completes one closed forward result and, only when requested, one direct
## QUICK/RIPOSTE do_attack-equivalent reverse body. It never calls fight().
static func complete(
	forward_result: CombatSingleAttackExecutionResult,
	reverse_projection: CombatReverseAttackProjection,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry = null,
) -> CombatAttackChainResult:
	var result: CombatAttackChainResult = CombatAttackChainResult.new()
	if forward_result != null:
		result._forward_result = forward_result.duplicate_snapshot()
	result._reached_stage = CombatAttackChainResult.ReachedStage.FORWARD_INSPECTED

	if _is_forward_complete_without_reverse(forward_result):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.FORWARD_COMPLETE_NO_REVERSE,
			CombatAttackChainResult.FailureStage.NONE,
			CombatAttackChainResult.ReachedStage.COMPLETED,
			forward_result.partial_mutation_preserved,
		)
	if not _is_reverse_terminal(forward_result):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.FORWARD_INCOMPLETE,
			CombatAttackChainResult.FailureStage.FORWARD_RESULT,
			CombatAttackChainResult.ReachedStage.FORWARD_INSPECTED,
			forward_result != null and forward_result.partial_mutation_preserved,
		)

	result._reverse_required = true
	result._reached_stage = CombatAttackChainResult.ReachedStage.FORWARD_COMPLETE
	var request: CombatRiposteRequest = forward_result.riposte_request
	if request != null:
		result._reverse_request = request.duplicate_snapshot()
		result._reverse_attacker_id = request.attacker_id
		result._reverse_victim_id = request.victim_id
		result._reverse_attack_type = request.attack_type
	if not _is_coherent_request(forward_result, request):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_REQUEST_INCOHERENT,
			CombatAttackChainResult.FailureStage.REVERSE_REQUEST,
			CombatAttackChainResult.ReachedStage.FORWARD_COMPLETE,
			forward_result.partial_mutation_preserved,
		)

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_REQUEST_VALIDATED
	if not _is_coherent_live_projection(request, reverse_projection):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_CONTEXT_INVALID,
			CombatAttackChainResult.FailureStage.REVERSE_CONTEXT,
			CombatAttackChainResult.ReachedStage.REVERSE_REQUEST_VALIDATED,
			forward_result.partial_mutation_preserved,
		)

	var attacker_authority: CombatCharacterAuthority = (
		reverse_projection.attacker_authority()
	)
	var defender_authority: CombatCharacterAuthority = (
		reverse_projection.defender_authority()
	)
	var attacker: CharacterState = attacker_authority.state()
	var defender: CharacterState = defender_authority.state()
	var attack_template: CombatAttackInput = reverse_projection.attack_input_template()
	var projected_attacker: CombatAttackerSnapshot = attack_template.attacker
	var current_weapon: EquippedWeaponRef = attacker.equipment.primary_weapon()
	result._reverse_weapon_present = current_weapon != null
	if current_weapon != null:
		result._reverse_weapon_instance_id = current_weapon.instance_id
		result._reverse_weapon_profile_id = current_weapon.weapon_id

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_CONTEXT_VALIDATED
	result._reverse_execution_reached = true
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTION
	var selection: CombatActionSelectionResult = CombatActionSelector.select_action(
		reverse_projection.action_selection_input(),
		random_source,
	)
	result._reverse_action_selection_result = selection.duplicate_snapshot()
	if not selection.succeeded:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_ACTION_SELECTION_FAILED,
			CombatAttackChainResult.FailureStage.REVERSE_ACTION_SELECTION,
			CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTION,
			_prior_mutation(result),
		)

	var selected_action: CombatActionDefinition = selection.selected_action
	result._reverse_selected_action_id = selected_action.action_id
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTED
	if not _matches_attack_projection(selected_action, attack_template):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_ACTION_PROJECTION_MISMATCH,
			CombatAttackChainResult.FailureStage.REVERSE_ACTION_PROJECTION,
			CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTED,
			_prior_mutation(result),
		)

	var attack_input: CombatAttackInput = CombatAttackInput.new(
		projected_attacker,
		attack_template.defender,
		selected_action,
	)
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ORDINARY
	var ordinary: CombatOrdinaryAttackResult = CombatAttackCompletionService.resolve(
		attack_input,
		attacker,
		defender,
		reverse_projection.attacker_facts(),
		reverse_projection.defender_facts(),
		reverse_projection.defender_busy_projection(),
		reverse_projection.defender_busy_state(),
		random_source,
		effect_registry,
	)
	result._reverse_ordinary_result = CombatAttackChainResult._copy_ordinary(ordinary)
	if ordinary.outcome != CombatOrdinaryAttackResult.Outcome.COMPLETED:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_ORDINARY_FAILED,
			CombatAttackChainResult.FailureStage.REVERSE_ORDINARY,
			CombatAttackChainResult.ReachedStage.REVERSE_ORDINARY,
			_prior_mutation(result),
		)

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ORDINARY_COMPLETED
	result._has_reverse_legacy_damage = true
	result._reverse_legacy_damage = _legacy_damage_for(ordinary.base_result)
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_LEGACY_DAMAGE

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_RELATIONSHIP
	var relationship: CombatPostRelationshipResult = CombatPostRelationshipService.apply(
		ordinary,
		request.attacker_id,
		request.victim_id,
		reverse_projection.attacker_relationship(),
		reverse_projection.defender_relationship(),
		random_source,
	)
	result._reverse_relationship_result = CombatAttackChainResult._copy_relationship(
		relationship
	)
	if relationship.failure_stage != CombatPostRelationshipResult.FailureStage.NONE:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_RELATIONSHIP_FAILED,
			CombatAttackChainResult.FailureStage.REVERSE_RELATIONSHIP,
			CombatAttackChainResult.ReachedStage.REVERSE_RELATIONSHIP,
			_prior_mutation(result),
		)

	result._reverse_post_action_reached = true
	result._reverse_post_action_policy_id = selected_action.post_action_policy_id
	result._reverse_post_action_policy_present = (
		not result._reverse_post_action_policy_id.is_empty()
	)
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_POST_ACTION
	if result._reverse_post_action_policy_present:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_POST_ACTION_UNAVAILABLE,
			CombatAttackChainResult.FailureStage.REVERSE_POST_ACTION,
			CombatAttackChainResult.ReachedStage.REVERSE_POST_ACTION,
			_prior_mutation(result),
		)

	## QUICK/RIPOSTE are both non-REGULAR, so the source's final guarding
	## predicate is false without reading or mutating reverse-victim guarding.
	return _finish(
		result,
		CombatAttackChainResult.Outcome.REVERSE_COMPLETE,
		CombatAttackChainResult.FailureStage.NONE,
		CombatAttackChainResult.ReachedStage.COMPLETED,
		_prior_mutation(result),
	)


static func _is_forward_complete_without_reverse(
	forward: CombatSingleAttackExecutionResult,
) -> bool:
	return (
		forward != null
		and forward.outcome
		== CombatSingleAttackExecutionResult.Outcome.COMPLETED_WITHOUT_RIPOSTE
		and forward.failure_stage == CombatSingleAttackExecutionResult.FailureStage.NONE
		and forward.reached_stage == CombatSingleAttackExecutionResult.ReachedStage.COMPLETED
		and not forward.has_riposte_request
	)


static func _is_reverse_terminal(
	forward: CombatSingleAttackExecutionResult,
) -> bool:
	return (
		forward != null
		and forward.outcome
		== CombatSingleAttackExecutionResult.Outcome.REVERSE_ATTACK_REQUIRED
		and forward.failure_stage == CombatSingleAttackExecutionResult.FailureStage.NONE
		and forward.reached_stage == CombatSingleAttackExecutionResult.ReachedStage.COMPLETED
	)


static func _is_coherent_request(
	forward: CombatSingleAttackExecutionResult,
	request: CombatRiposteRequest,
) -> bool:
	if (
		request == null
		or not forward.has_riposte_request
		or not request.is_valid()
		or forward.attack_type != CombatAttackType.Value.REGULAR
		or not forward.has_legacy_damage
		or forward.legacy_damage >= 1
		or not forward.riposte_eligible
		or not forward.riposte_guard_clear_attempted
		or not forward.victim_guarding_before_clear
		or forward.victim_guarding_after_clear
		or not forward.riposte_random_reached
		or not forward.riposte_random_attempted
		or not forward.post_action_reached
		or forward.post_action_policy_present
	):
		return false
	var ordinary: CombatOrdinaryAttackResult = forward.ordinary_attack_result
	var relationship: CombatPostRelationshipResult = forward.post_relationship_result
	if (
		ordinary == null
		or ordinary.outcome != CombatOrdinaryAttackResult.Outcome.COMPLETED
		or relationship == null
		or relationship.failure_stage != CombatPostRelationshipResult.FailureStage.NONE
		or relationship.winner_selection_reached
		or relationship.winner_random_attempted
	):
		return false
	return (
		request.attacker_id == forward.victim_id
		and request.victim_id == forward.attacker_id
		and request.triggering_forward_action_id == forward.selected_action_id
		and request.triggering_legacy_damage == forward.legacy_damage
		and request.random_bound == forward.riposte_random_bound
		and request.random_draw == forward.riposte_random_draw
		and (
			request.attack_type == CombatAttackType.Value.QUICK
			or request.attack_type == CombatAttackType.Value.RIPOSTE
		)
	)


static func _is_coherent_live_projection(
	request: CombatRiposteRequest,
	projection: CombatReverseAttackProjection,
) -> bool:
	if projection == null:
		return false
	var attacker_authority: CombatCharacterAuthority = projection.attacker_authority()
	var defender_authority: CombatCharacterAuthority = projection.defender_authority()
	if (
		attacker_authority == null
		or defender_authority == null
		or not attacker_authority.is_valid()
		or not defender_authority.is_valid()
		or attacker_authority == defender_authority
		or attacker_authority.character_id != request.attacker_id
		or defender_authority.character_id != request.victim_id
		or attacker_authority.character_id == defender_authority.character_id
		or attacker_authority.state() == defender_authority.state()
	):
		return false
	var attacker: CharacterState = attacker_authority.state()
	var defender: CharacterState = defender_authority.state()
	var input: CombatAttackInput = projection.attack_input_template()
	var attacker_facts: CombatProgressionFacts = projection.attacker_facts()
	var defender_facts: CombatProgressionFacts = projection.defender_facts()
	var busy_projection: CombatBusyInterruptProjection = (
		projection.defender_busy_projection()
	)
	var attacker_relationship: CombatRelationshipState = (
		projection.attacker_relationship()
	)
	var defender_relationship: CombatRelationshipState = (
		projection.defender_relationship()
	)
	var selection_input: CombatActionSelectionInput = projection.action_selection_input()
	var modifiers: CombatReverseModifierProjection = projection.modifier_projection()
	if (
		input == null
		or attacker_facts == null
		or defender_facts == null
		or not attacker_facts.is_valid()
		or not defender_facts.is_valid()
		or busy_projection == null
		or not busy_projection.is_valid()
		or attacker_relationship == null
		or defender_relationship == null
		or attacker_relationship == defender_relationship
		or not attacker_relationship.is_valid()
		or not defender_relationship.is_valid()
		or selection_input == null
		or modifiers == null
		or not modifiers.is_valid()
	):
		return false
	var attacker_snapshot: CombatAttackerSnapshot = input.attacker
	var defender_snapshot: CombatDefenderSnapshot = input.defender
	if attacker_snapshot == null or defender_snapshot == null:
		return false
	if (
		attacker_snapshot.character_id != request.attacker_id
		or defender_snapshot.character_id != request.victim_id
		or attacker_facts.character_id != request.attacker_id
		or defender_facts.character_id != request.victim_id
		or attacker_relationship.owner_character_id != request.attacker_id
		or defender_relationship.owner_character_id != request.victim_id
		or modifiers.attacker_character_id != request.attacker_id
		or modifiers.defender_character_id != request.victim_id
		or attacker_snapshot.combat_experience
		!= attacker.progression.combat_experience
		or defender_snapshot.combat_experience
		!= defender.progression.combat_experience
		or attacker_snapshot.current_spirit != attacker.spirit.current
		or attacker_snapshot.maximum_spirit != attacker.spirit.maximum
		or defender_snapshot.current_spirit != defender.spirit.current
		or defender_snapshot.maximum_spirit != defender.spirit.maximum
		or defender_snapshot.current_inner_force
		!= defender.recovery.inner_force.current
	):
		return false
	if (
		attacker_facts.base_intelligence != attacker.attributes.intelligence
		or attacker_facts.base_spirituality != attacker.attributes.spirituality
		or defender_facts.base_intelligence != defender.attributes.intelligence
		or defender_facts.base_spirituality != defender.attributes.spirituality
	):
		return false
	var strength: CombatStrengthProjection = attacker_snapshot.strength_projection
	if (
		strength.base_strength != attacker.attributes.strength
		or strength.force_factor != attacker.attributes.force_factor
		or strength.strength_modifier != attacker.attributes.strength_modifier
	):
		return false
	var current_weapon: EquippedWeaponRef = attacker.equipment.primary_weapon()
	var has_current_weapon: bool = current_weapon != null
	if attacker_snapshot.has_weapon != has_current_weapon:
		return false
	var expected_attack_skill: StringName = UNARMED_SKILL_ID
	if has_current_weapon:
		var weapon_profile: WeaponCombatProfile = attacker_snapshot.weapon_profile
		if (
			weapon_profile == null
			or weapon_profile.weapon_id != current_weapon.weapon_id
			or weapon_profile.skill_type != current_weapon.skill_type
		):
			return false
		expected_attack_skill = current_weapon.skill_type
	if (
		attacker_snapshot.projected_attack_skill_type != expected_attack_skill
		or attacker_facts.attack_skill_definition_id != expected_attack_skill
		or attacker_snapshot.mapped_attack_skill_id
		!= attacker.skills.mapped_skill(expected_attack_skill)
		or attacker_snapshot.mapped_force_skill_id
		!= attacker.skills.mapped_skill(FORCE_SKILL_ID)
		or selection_input.mapped_skill_present
		!= (not attacker_snapshot.mapped_attack_skill_id.is_empty())
		or selection_input.primary_weapon_present != has_current_weapon
		or defender_snapshot.has_primary_weapon
		!= (not defender.equipment.is_primary_hand_empty())
	):
		return false
	if (
		attacker_snapshot.effective_attack_skill_level
		!= attacker.skills.effective_level(
			expected_attack_skill,
			modifiers.attacker_attack_skill_modifier,
		)
		or attacker_snapshot.effective_force_skill_level
		!= attacker.skills.effective_level(
			attacker_snapshot.projected_force_skill_type,
			modifiers.attacker_force_skill_modifier,
		)
		or defender_snapshot.effective_dodge_skill_level
		!= defender.skills.effective_level(
			&"dodge",
			modifiers.defender_dodge_skill_modifier,
		)
		or defender_snapshot.effective_parry_skill_level
		!= defender.skills.effective_level(
			&"parry",
			modifiers.defender_parry_skill_modifier,
		)
		or defender_snapshot.effective_unarmed_skill_level
		!= defender.skills.effective_level(
			UNARMED_SKILL_ID,
			modifiers.defender_unarmed_skill_modifier,
		)
		or defender_snapshot.effective_force_skill_level
		!= defender.skills.effective_level(
			defender_snapshot.projected_force_skill_type,
			modifiers.defender_force_skill_modifier,
		)
		or attacker_snapshot.attack_usage_bonus
		!= modifiers.attacker_attack_usage_bonus
		or defender_snapshot.defense_usage_bonus
		!= modifiers.defender_defense_usage_bonus
		or attacker_snapshot.projected_apply_damage
		!= modifiers.attacker_apply_damage
		or defender_snapshot.armor != modifiers.defender_armor
		or defender_snapshot.armor_vs_force != modifiers.defender_armor_vs_force
	):
		return false
	return _busy_projection_matches(
		defender_snapshot,
		busy_projection,
		projection.defender_busy_state(),
	)


static func _busy_projection_matches(
	defender: CombatDefenderSnapshot,
	projection: CombatBusyInterruptProjection,
	state: ActionBusyState,
) -> bool:
	var projected_busy: bool = (
		projection.busy_kind != CombatBusyInterruptProjection.BusyKind.NOT_BUSY
	)
	if defender.busy != projected_busy:
		return false
	if (
		projection.busy_kind == CombatBusyInterruptProjection.BusyKind.INTEGER
		and projection.interrupt_kind
		== CombatBusyInterruptProjection.InterruptKind.INTEGER
	):
		return state != null and state.is_busy()
	if (
		projection.busy_kind == CombatBusyInterruptProjection.BusyKind.NOT_BUSY
		and projection.interrupt_kind
		== CombatBusyInterruptProjection.InterruptKind.INTEGER
	):
		return state == null or not state.is_busy()
	return state == null


static func _matches_attack_projection(
	selected: CombatActionDefinition,
	template: CombatAttackInput,
) -> bool:
	if selected == null or template == null or not template.is_valid():
		return false
	var projected: CombatActionDefinition = template.selected_action
	return (
		selected.action_id == projected.action_id
		and selected.damage_percent == projected.damage_percent
		and selected.force_percent == projected.force_percent
		and selected.damage_type == projected.damage_type
		and selected.presentation_key == projected.presentation_key
		and selected.legacy_action_text == projected.legacy_action_text
		and selected.displayed_weapon_or_body_token
		== projected.displayed_weapon_or_body_token
		and selected.post_action_policy_id == projected.post_action_policy_id
	)


static func _legacy_damage_for(base_result: CombatAttackResult) -> int:
	if base_result.outcome == CombatAttackResult.Outcome.DODGE:
		return -1
	if base_result.outcome == CombatAttackResult.Outcome.PARRY:
		return -2
	return base_result.calculation.requested_damage


static func _prior_mutation(result: CombatAttackChainResult) -> bool:
	var mutated: bool = (
		result._forward_result != null
		and result._forward_result.partial_mutation_preserved
	)
	if result._reverse_ordinary_result != null:
		mutated = mutated or _ordinary_mutated(result._reverse_ordinary_result)
	if result._reverse_relationship_result != null:
		mutated = (
			mutated
			or result._reverse_relationship_result.attacker_removal_succeeded
			or result._reverse_relationship_result.defender_removal_succeeded
		)
	return mutated


static func _ordinary_mutated(result: CombatOrdinaryAttackResult) -> bool:
	if result.partial_mutation_preserved:
		return true
	if result.has_base_result:
		var base: CombatAttackResult = result.base_result
		var mutation: CombatResourceMutationResult = base.resource_mutation
		if mutation.damage_transition_completed or mutation.wound_transition_completed:
			return true
		if base.has_standard_force_result:
			if (
				base.standard_force_result.reached_stage
				>= StandardForceHitResult.ReachedStage.FORCE_DEDUCTED
			):
				return true
	var progression: CombatProgressionResult = result.progression_result
	return (
		progression.attacker_combat_experience_incremented()
		or progression.defender_combat_experience_incremented()
		or progression.attacker_potential_incremented()
		or progression.defender_potential_incremented()
		or progression.attacker_skill_improvement_attempted
		or progression.defender_skill_improvement_attempted
	)


static func _finish(
	result: CombatAttackChainResult,
	outcome: int,
	failure_stage: int,
	reached_stage: int,
	partial_mutation_preserved: bool,
) -> CombatAttackChainResult:
	result._outcome = outcome
	result._failure_stage = failure_stage
	result._reached_stage = reached_stage
	result._partial_mutation_preserved = partial_mutation_preserved
	result._rebuild_combined_random_evidence()
	return result
