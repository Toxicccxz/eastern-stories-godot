class_name CultivationService
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const CharacterInternalResourceStateType := preload(
	"res://core/characters/character_internal_resource_state.gd"
)
const SkillIdsType := preload("res://core/skills/skill_ids.gd")
const CultivationResultType := preload("res://core/cultivation/cultivation_result.gd")

const MINIMUM_SOURCE_COST: int = 10
const REQUIRED_HEALTH_PERCENT: int = 70
const GAIN_DIVISOR: int = 300
const MAXIMUM_SKILL_MULTIPLIER: int = 10


## Pure domain translation of cmds/std/exercise.c. Runtime combat state and
## temporary skill modifiers are explicit inputs rather than service dependencies.
static func exercise(
	character: CharacterStateType,
	vitality_cost: int,
	is_fighting: bool,
	force_temporary_modifier: int = 0,
) -> CultivationResultType:
	var action: int = CultivationResultType.Action.EXERCISE
	if is_fighting:
		return _failure(action, CultivationResultType.FailureReason.IN_COMBAT, vitality_cost)
	if character.skills.mapped_skill(SkillIdsType.FORCE) == &"":
		return _failure(
			action,
			CultivationResultType.FailureReason.FORCE_STYLE_NOT_ENABLED,
			vitality_cost,
		)
	if vitality_cost < MINIMUM_SOURCE_COST:
		return _failure(
			action,
			CultivationResultType.FailureReason.COST_BELOW_MINIMUM,
			vitality_cost,
		)
	if character.vitality.current < vitality_cost:
		return _failure(
			action,
			CultivationResultType.FailureReason.INSUFFICIENT_VITALITY,
			vitality_cost,
		)
	if character.spirit.maximum == 0:
		return _failure(
			action,
			CultivationResultType.FailureReason.LEGACY_ZERO_MAXIMUM_SPIRIT_DIVISOR,
			vitality_cost,
		)
	if _is_below_required_health(character.spirit.current, character.spirit.maximum):
		return _failure(
			action,
			CultivationResultType.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD,
			vitality_cost,
		)
	if character.essence.maximum == 0:
		return _failure(
			action,
			CultivationResultType.FailureReason.LEGACY_ZERO_MAXIMUM_ESSENCE_DIVISOR,
			vitality_cost,
		)
	if _is_below_required_health(character.essence.current, character.essence.maximum):
		return _failure(
			action,
			CultivationResultType.FailureReason.ESSENCE_BELOW_HEALTH_THRESHOLD,
			vitality_cost,
		)

	character.vitality.apply_damage(vitality_cost)
	var raw_force: int = character.skills.raw_level(SkillIdsType.FORCE)
	var gain: int = _legacy_int_divide(
		vitality_cost * (raw_force + character.attributes.constitution),
		GAIN_DIVISOR,
	)
	var effective_force: int = character.skills.effective_level(
		SkillIdsType.FORCE,
		force_temporary_modifier,
	)
	var skill_cap: int = (
		raw_force
		+ _legacy_int_divide(effective_force, 5)
	) * MAXIMUM_SKILL_MULTIPLIER
	return _apply_gain(
		action,
		vitality_cost,
		character.recovery.inner_force,
		gain,
		skill_cap,
	)


## Pure domain translation of cmds/std/meditate.c.
static func meditate(
	character: CharacterStateType,
	spirit_cost: int,
	is_fighting: bool,
	spells_temporary_modifier: int = 0,
) -> CultivationResultType:
	var action: int = CultivationResultType.Action.MEDITATE
	if is_fighting:
		return _failure(action, CultivationResultType.FailureReason.IN_COMBAT, spirit_cost)
	if spirit_cost < MINIMUM_SOURCE_COST:
		return _failure(
			action,
			CultivationResultType.FailureReason.COST_BELOW_MINIMUM,
			spirit_cost,
		)
	if character.spirit.current < spirit_cost:
		return _failure(
			action,
			CultivationResultType.FailureReason.INSUFFICIENT_SPIRIT,
			spirit_cost,
		)
	if character.vitality.maximum == 0:
		return _failure(
			action,
			CultivationResultType.FailureReason.LEGACY_ZERO_MAXIMUM_VITALITY_DIVISOR,
			spirit_cost,
		)
	if _is_below_required_health(character.vitality.current, character.vitality.maximum):
		return _failure(
			action,
			CultivationResultType.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD,
			spirit_cost,
		)
	if character.essence.maximum == 0:
		return _failure(
			action,
			CultivationResultType.FailureReason.LEGACY_ZERO_MAXIMUM_ESSENCE_DIVISOR,
			spirit_cost,
		)
	if _is_below_required_health(character.essence.current, character.essence.maximum):
		return _failure(
			action,
			CultivationResultType.FailureReason.ESSENCE_BELOW_HEALTH_THRESHOLD,
			spirit_cost,
		)

	character.spirit.apply_damage(spirit_cost)
	var effective_spells: int = character.skills.effective_level(
		SkillIdsType.SPELLS,
		spells_temporary_modifier,
	)
	var gain: int = _legacy_int_divide(
		spirit_cost * (effective_spells + character.attributes.spirituality),
		GAIN_DIVISOR,
	)
	var skill_cap: int = (
		character.skills.raw_level(SkillIdsType.SPELLS) * MAXIMUM_SKILL_MULTIPLIER
	)
	return _apply_gain(action, spirit_cost, character.recovery.mana, gain, skill_cap)


## Pure domain translation of cmds/std/respirate.c.
static func respirate(
	character: CharacterStateType,
	essence_cost: int,
	is_fighting: bool,
	magic_temporary_modifier: int = 0,
) -> CultivationResultType:
	var action: int = CultivationResultType.Action.RESPIRATE
	if is_fighting:
		return _failure(action, CultivationResultType.FailureReason.IN_COMBAT, essence_cost)
	if essence_cost < MINIMUM_SOURCE_COST:
		return _failure(
			action,
			CultivationResultType.FailureReason.COST_BELOW_MINIMUM,
			essence_cost,
		)
	if character.essence.current < essence_cost:
		return _failure(
			action,
			CultivationResultType.FailureReason.INSUFFICIENT_ESSENCE,
			essence_cost,
		)
	if character.vitality.maximum == 0:
		return _failure(
			action,
			CultivationResultType.FailureReason.LEGACY_ZERO_MAXIMUM_VITALITY_DIVISOR,
			essence_cost,
		)
	if _is_below_required_health(character.vitality.current, character.vitality.maximum):
		return _failure(
			action,
			CultivationResultType.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD,
			essence_cost,
		)
	if character.spirit.maximum == 0:
		return _failure(
			action,
			CultivationResultType.FailureReason.LEGACY_ZERO_MAXIMUM_SPIRIT_DIVISOR,
			essence_cost,
		)
	if _is_below_required_health(character.spirit.current, character.spirit.maximum):
		return _failure(
			action,
			CultivationResultType.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD,
			essence_cost,
		)

	character.essence.apply_damage(essence_cost)
	var effective_magic: int = character.skills.effective_level(
		SkillIdsType.MAGIC,
		magic_temporary_modifier,
	)
	var gain: int = _legacy_int_divide(
		essence_cost * (effective_magic + character.attributes.spirituality),
		GAIN_DIVISOR,
	)
	var skill_cap: int = (
		character.skills.raw_level(SkillIdsType.MAGIC) * MAXIMUM_SKILL_MULTIPLIER
	)
	return _apply_gain(action, essence_cost, character.recovery.atman, gain, skill_cap)


static func _apply_gain(
	action: int,
	requested_cost: int,
	internal_resource: CharacterInternalResourceStateType,
	calculated_gain: int,
	skill_cap: int,
) -> CultivationResultType:
	var internal_before: int = internal_resource.current
	var maximum_before: int = internal_resource.maximum
	if calculated_gain < 1:
		return CultivationResultType.new(
			action,
			true,
			CultivationResultType.FailureReason.NONE,
			CultivationResultType.Completion.NO_GAIN,
			requested_cost,
			requested_cost,
			calculated_gain,
			internal_before,
			internal_resource.current,
			maximum_before,
			internal_resource.maximum,
		)

	internal_resource.current += calculated_gain
	var completion: int = CultivationResultType.Completion.GAINED
	if internal_resource.current > internal_resource.maximum * 2:
		if internal_resource.maximum >= skill_cap:
			completion = CultivationResultType.Completion.SKILL_CAP_REACHED
		else:
			internal_resource.maximum += 1
			completion = CultivationResultType.Completion.MAXIMUM_INCREASED
		internal_resource.current = internal_resource.maximum

	return CultivationResultType.new(
		action,
		true,
		CultivationResultType.FailureReason.NONE,
		completion,
		requested_cost,
		requested_cost,
		calculated_gain,
		internal_before,
		internal_resource.current,
		maximum_before,
		internal_resource.maximum,
	)


static func _failure(action: int, reason: int, requested_cost: int) -> CultivationResultType:
	return CultivationResultType.new(
		action,
		false,
		reason,
		CultivationResultType.Completion.NONE,
		requested_cost,
	)


static func _is_below_required_health(current: int, maximum: int) -> bool:
	return _legacy_int_divide(current * 100, maximum) < REQUIRED_HEALTH_PERCENT


static func _legacy_int_divide(dividend: int, divisor: int) -> int:
	@warning_ignore("integer_division")
	return dividend / divisor
