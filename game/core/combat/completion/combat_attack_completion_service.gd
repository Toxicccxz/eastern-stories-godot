class_name CombatAttackCompletionService
extends RefCounted


static func resolve(
	input: CombatAttackInput,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	defender_busy_projection: CombatBusyInterruptProjection,
	defender_busy_state: ActionBusyState,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry = null,
) -> CombatOrdinaryAttackResult:
	var validation_stage: int = _validate(
		input,
		attacker,
		defender,
		attacker_facts,
		defender_facts,
		defender_busy_projection,
		defender_busy_state,
		random_source,
	)
	if validation_stage != CombatOrdinaryAttackResult.FailureStage.NONE:
		return CombatOrdinaryAttackResult.new(
			CombatOrdinaryAttackResult.Outcome.INVALID_COMPOSITION_INPUT,
			validation_stage,
		)

	var registry: SkillImprovementEffectRegistry = effect_registry
	if registry == null:
		registry = SkillImprovementEffectRegistry.new()
		registry.register_legacy_defaults()
	var base_result: CombatAttackResult = CombatAttackResolver.resolve(
		input,
		defender.essence,
		defender.vitality,
		defender.spirit,
		random_source,
		attacker.recovery.inner_force,
		attacker.essence,
		attacker.vitality,
		attacker.spirit,
	)
	if not base_result.succeeded():
		return CombatOrdinaryAttackResult.new(
			CombatOrdinaryAttackResult.Outcome.BASE_ATTACK_INCOMPLETE,
			CombatOrdinaryAttackResult.FailureStage.BASE_ATTACK,
			base_result,
			CombatProgressionResult.new(),
			CombatStatusReportBoundaryResult.new(),
			CombatBusyInterruptResult.new(),
			_base_mutated(base_result),
		)

	var progression: CombatProgressionResult = CombatProgressionService.apply(
		base_result,
		attacker,
		defender,
		attacker_facts,
		defender_facts,
		random_source,
		registry,
	)
	if progression.outcome != CombatProgressionResult.Outcome.COMPLETED:
		return CombatOrdinaryAttackResult.new(
			CombatOrdinaryAttackResult.Outcome.PROGRESSION_FAILED,
			CombatOrdinaryAttackResult.FailureStage.PROGRESSION,
			base_result,
			progression,
			CombatStatusReportBoundaryResult.new(),
			CombatBusyInterruptResult.new(),
			_base_mutated(base_result) or _progression_mutated(progression),
		)

	var status_report_result: CombatStatusReportBoundaryResult = (
		_validate_status_report(base_result, defender)
	)
	if (
		status_report_result.outcome
		== CombatStatusReportBoundaryResult.Outcome.ZERO_MAXIMUM_DIVISOR
	):
		return CombatOrdinaryAttackResult.new(
			CombatOrdinaryAttackResult.Outcome.STATUS_REPORT_BOUNDARY_FAILED,
			CombatOrdinaryAttackResult.FailureStage.REPORT_STATUS,
			base_result,
			progression,
			status_report_result,
			CombatBusyInterruptResult.new(),
			_base_mutated(base_result) or _progression_mutated(progression),
		)

	var busy_result: CombatBusyInterruptResult = _apply_busy(
		base_result,
		defender_busy_projection,
		defender_busy_state,
	)
	if (
		busy_result.outcome
		== CombatBusyInterruptResult.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE
	):
		return CombatOrdinaryAttackResult.new(
			CombatOrdinaryAttackResult.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE,
			CombatOrdinaryAttackResult.FailureStage.BUSY_INTERRUPT,
			base_result,
			progression,
			status_report_result,
			busy_result,
			true,
		)
	return CombatOrdinaryAttackResult.new(
		CombatOrdinaryAttackResult.Outcome.COMPLETED,
		CombatOrdinaryAttackResult.FailureStage.NONE,
		base_result,
		progression,
		status_report_result,
		busy_result,
		false,
	)


static func _validate(
	input: CombatAttackInput,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	defender_busy_projection: CombatBusyInterruptProjection,
	defender_busy_state: ActionBusyState,
	random_source: CombatRandomSource,
) -> int:
	if (
		input == null
		or not input.is_valid()
		or attacker == null
		or defender == null
		or attacker_facts == null
		or defender_facts == null
		or not attacker_facts.is_valid()
		or not defender_facts.is_valid()
		or random_source == null
		or defender_busy_projection == null
		or not defender_busy_projection.is_valid()
	):
		return CombatOrdinaryAttackResult.FailureStage.INVALID_INPUT
	var attacker_snapshot: CombatAttackerSnapshot = input.attacker
	var defender_snapshot: CombatDefenderSnapshot = input.defender
	if attacker_snapshot.character_id != attacker_facts.character_id:
		return CombatOrdinaryAttackResult.FailureStage.ATTACKER_ID_PROJECTION
	if defender_snapshot.character_id != defender_facts.character_id:
		return CombatOrdinaryAttackResult.FailureStage.DEFENDER_ID_PROJECTION
	if attacker_snapshot.combat_experience != attacker.progression.combat_experience:
		return CombatOrdinaryAttackResult.FailureStage.ATTACKER_PROGRESSION_PROJECTION
	if defender_snapshot.combat_experience != defender.progression.combat_experience:
		return CombatOrdinaryAttackResult.FailureStage.DEFENDER_PROGRESSION_PROJECTION
	if (
		attacker_facts.base_intelligence != attacker.attributes.intelligence
		or attacker_facts.base_spirituality != attacker.attributes.spirituality
	):
		return CombatOrdinaryAttackResult.FailureStage.ATTACKER_ATTRIBUTE_PROJECTION
	if (
		defender_facts.base_intelligence != defender.attributes.intelligence
		or defender_facts.base_spirituality != defender.attributes.spirituality
	):
		return CombatOrdinaryAttackResult.FailureStage.DEFENDER_ATTRIBUTE_PROJECTION
	var projected_busy: bool = (
		defender_busy_projection.busy_kind
		!= CombatBusyInterruptProjection.BusyKind.NOT_BUSY
	)
	if defender_snapshot.busy != projected_busy:
		return CombatOrdinaryAttackResult.FailureStage.BUSY_PROJECTION
	if (
		defender_busy_projection.busy_kind
		== CombatBusyInterruptProjection.BusyKind.INTEGER
		and defender_busy_projection.interrupt_kind
		== CombatBusyInterruptProjection.InterruptKind.INTEGER
	):
		if defender_busy_state == null or not defender_busy_state.is_busy():
			return CombatOrdinaryAttackResult.FailureStage.BUSY_PROJECTION
	elif (
		defender_busy_projection.busy_kind
		== CombatBusyInterruptProjection.BusyKind.NOT_BUSY
		and defender_busy_projection.interrupt_kind
		== CombatBusyInterruptProjection.InterruptKind.INTEGER
	):
		if defender_busy_state != null and defender_busy_state.is_busy():
			return CombatOrdinaryAttackResult.FailureStage.BUSY_PROJECTION
	elif defender_busy_state != null:
		return CombatOrdinaryAttackResult.FailureStage.BUSY_PROJECTION
	return CombatOrdinaryAttackResult.FailureStage.NONE


static func _apply_busy(
	base_result: CombatAttackResult,
	busy_projection: CombatBusyInterruptProjection,
	busy_state: ActionBusyState,
) -> CombatBusyInterruptResult:
	if (
		base_result.outcome != CombatAttackResult.Outcome.HIT
		or base_result.calculation.requested_damage <= 0
	):
		return CombatBusyInterruptResult.new()
	if busy_projection.busy_kind == CombatBusyInterruptProjection.BusyKind.NOT_BUSY:
		return CombatBusyInterruptResult.new(
			CombatBusyInterruptResult.Outcome.DEFENDER_NOT_BUSY,
			false,
			busy_projection.busy_kind,
			busy_projection.interrupt_kind,
		)
	if (
		busy_projection.interrupt_kind
		== CombatBusyInterruptProjection.InterruptKind.FUNCTION
	):
		return CombatBusyInterruptResult.new(
			CombatBusyInterruptResult.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE,
			true,
			busy_projection.busy_kind,
			busy_projection.interrupt_kind,
		)
	if busy_projection.busy_kind == CombatBusyInterruptProjection.BusyKind.FUNCTION:
		return CombatBusyInterruptResult.new(
			CombatBusyInterruptResult.Outcome.FUNCTION_BUSY_INTEGER_INTERRUPT_NO_OP,
			true,
			busy_projection.busy_kind,
			busy_projection.interrupt_kind,
		)
	if busy_projection.busy_kind == CombatBusyInterruptProjection.BusyKind.INTEGER:
		var before: int = busy_state.busy_value
		var threshold: int = busy_state.interrupt_threshold
		var cleared: bool = busy_state.try_interrupt()
		return CombatBusyInterruptResult.new(
			(
				CombatBusyInterruptResult.Outcome.INTEGER_BUSY_CLEARED
				if cleared
				else CombatBusyInterruptResult.Outcome.INTEGER_BUSY_REMAINED
			),
			true,
			busy_projection.busy_kind,
			busy_projection.interrupt_kind,
			true,
			before,
			busy_state.busy_value,
			threshold,
		)
	return CombatBusyInterruptResult.new()


static func _validate_status_report(
	base_result: CombatAttackResult,
	defender: CharacterState,
) -> CombatStatusReportBoundaryResult:
	if (
		base_result.outcome != CombatAttackResult.Outcome.HIT
		or base_result.calculation.requested_damage <= 0
	):
		return CombatStatusReportBoundaryResult.new()
	var wounded: bool = base_result.resource_mutation.wound_transition_completed
	var value_source: int = (
		CombatStatusReportBoundaryResult.ValueSource.EFFECTIVE_VITALITY
		if wounded
		else CombatStatusReportBoundaryResult.ValueSource.CURRENT_VITALITY
	)
	var numerator: int = (
		defender.vitality.effective if wounded else defender.vitality.current
	)
	var maximum: int = defender.vitality.maximum
	if maximum == 0:
		return CombatStatusReportBoundaryResult.new(
			CombatStatusReportBoundaryResult.Outcome.ZERO_MAXIMUM_DIVISOR,
			value_source,
			numerator,
			maximum,
		)
	@warning_ignore("integer_division")
	var ratio: int = numerator * 100 / maximum
	return CombatStatusReportBoundaryResult.new(
		CombatStatusReportBoundaryResult.Outcome.VALIDATED,
		value_source,
		numerator,
		maximum,
		ratio,
	)


static func _base_mutated(result: CombatAttackResult) -> bool:
	var mutation: CombatResourceMutationResult = result.resource_mutation
	if mutation.damage_transition_completed or mutation.wound_transition_completed:
		return true
	if result.has_standard_force_result:
		var force_result: StandardForceHitResult = result.standard_force_result
		return (
			force_result.reached_stage >= StandardForceHitResult.ReachedStage.FORCE_DEDUCTED
		)
	return false


static func _progression_mutated(result: CombatProgressionResult) -> bool:
	return (
		result.attacker_combat_experience_incremented()
		or result.defender_combat_experience_incremented()
		or result.attacker_potential_incremented()
		or result.defender_potential_incremented()
		or result.attacker_skill_improvement_attempted
		or result.defender_skill_improvement_attempted
	)
