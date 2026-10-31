class_name CombatActionSelector
extends RefCounted


## `tag_weights` (DECISIONS「战斗内容」, an NPC's fight style): the draw weighs each move by
## its tag's weight (1 when the tag has none, 平 under &""), one random(sum) instead of
## random(n); empty or all 1: random(n) as combatd.c.
static func select_action(
	input: CombatActionSelectionInput,
	random_source: CombatRandomSource,
	tag_weights: Dictionary[StringName, int] = {},
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
	# A chosen move in the set (the player's pick, an NPC's move drawn a beat early): no draw.
	if not input.chosen_action_id.is_empty():
		for index: int in action_set.size():
			if action_set.action_at(index).action_id == input.chosen_action_id:
				return CombatActionSelectionResult.new(
					CombatActionSelectionResult.Outcome.SELECTED, source_kind, action_set.action_at(index), index,
					false, false, action_set.size(), index,
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

	var weights: Array[int] = _weights(action_set, tag_weights)
	var selected_index: int = -1
	var bound: int = action_set.size()
	if weights.is_empty():
		selected_index = random_source.legacy_random(bound)
	else:
		bound = 0
		for weight: int in weights:
			bound += weight
		var draw: int = random_source.legacy_random(bound)
		var passed: int = 0
		for index: int in weights.size():
			passed += weights[index]
			if draw < passed:
				selected_index = index
				break
		if selected_index < 0 and draw >= 0 and draw < bound:
			selected_index = weights.size() - 1
	if selected_index < 0 or selected_index >= action_set.size():
		return CombatActionSelectionResult.new(
			CombatActionSelectionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE,
			source_kind,
			null,
			selected_index,
			true,
			true,
			bound,
			selected_index,
		)
	return CombatActionSelectionResult.new(
		CombatActionSelectionResult.Outcome.SELECTED,
		source_kind,
		action_set.action_at(selected_index),
		selected_index,
		true,
		true,
		bound,
		selected_index,
	)


## The weight of each move of `action_set` under `tag_weights`; empty when every weight
## is 1 (the plain draw) or the weights leave nothing to draw.
static func _weights(action_set: CombatActionSet, tag_weights: Dictionary[StringName, int]) -> Array[int]:
	var weights: Array[int] = []
	if tag_weights.is_empty():
		return weights
	var plain: bool = true
	var total: int = 0
	for action: CombatActionDefinition in action_set.actions():
		var weight: int = maxi(0, tag_weights.get(action.tag, 1))
		plain = plain and weight == 1
		total += weight
		weights.append(weight)
	if plain or total <= 0:
		weights.clear()
	return weights
