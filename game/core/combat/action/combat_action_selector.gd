class_name CombatActionSelector
extends RefCounted


static func select_action(
	input: CombatActionSelectionInput,
	random_source: CombatRandomSource,
) -> CombatActionSelectionResult:
	if input == null:
		return CombatActionSelectionResult.new()

	var source_kind: int = CombatActionSelectionResult.SourceKind.NONE
	var action_set: CombatActionSet
	if input.mapped_skill_present:
		source_kind = CombatActionSelectionResult.SourceKind.MAPPED_MARTIAL
		action_set = input.mapped_action_set()
		if action_set == null:
			return CombatActionSelectionResult.new(
				CombatActionSelectionResult.Outcome.MAPPED_ACTION_DATA_UNAVAILABLE,
				source_kind,
			)
	elif input.primary_weapon_present:
		source_kind = CombatActionSelectionResult.SourceKind.PRIMARY_WEAPON
		action_set = input.primary_weapon_action_set()
		if action_set == null:
			return CombatActionSelectionResult.new(
				CombatActionSelectionResult.Outcome.PRIMARY_WEAPON_ACTION_DATA_UNAVAILABLE,
				source_kind,
			)
	else:
		source_kind = CombatActionSelectionResult.SourceKind.DEFAULT_ACTIONS
		action_set = input.default_action_set()

	if action_set == null:
		return CombatActionSelectionResult.new(
			CombatActionSelectionResult.Outcome.NO_ACTION_SOURCE,
			source_kind,
		)
	if action_set.is_empty():
		return CombatActionSelectionResult.new(
			CombatActionSelectionResult.Outcome.EMPTY_ACTION_SET,
			source_kind,
		)
	if not action_set.is_valid():
		return CombatActionSelectionResult.new(
			CombatActionSelectionResult.Outcome.INVALID_ACTION_SET,
			source_kind,
		)
	if random_source == null:
		return CombatActionSelectionResult.new(
			CombatActionSelectionResult.Outcome.RANDOM_SOURCE_MISSING,
			source_kind,
			null,
			-1,
			true,
			false,
			action_set.size(),
		)

	var selected_index: int = random_source.next_below(action_set.size())
	if selected_index < 0 or selected_index >= action_set.size():
		return CombatActionSelectionResult.new(
			CombatActionSelectionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE,
			source_kind,
			null,
			selected_index,
			true,
			true,
			action_set.size(),
			selected_index,
		)
	return CombatActionSelectionResult.new(
		CombatActionSelectionResult.Outcome.SELECTED,
		source_kind,
		action_set.action_at(selected_index),
		selected_index,
		true,
		true,
		action_set.size(),
		selected_index,
	)
