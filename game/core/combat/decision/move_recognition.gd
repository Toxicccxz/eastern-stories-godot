class_name MoveRecognition
extends RefCounted

## 识招 (战斗决策层 4, DECISIONS「战斗内容」; 点子库 §4「识招与见识录」): the player reads an enemy
## move's tag (「起手：重」) once they have watched it used `recognise_after` times in fights
## they were in; until then the card says 「起手：？」. The moves of the player's own schools
## (a skill they have a level in), their race's and those of any weapon skill they have
## learned are known. `CharacterState.known_moves` counts the uses (saved).

## Counts one use of `action_id` watched by the player. Returns the count now.
static func note(state: CharacterState, action_id: StringName) -> int:
	if state == null or action_id.is_empty():
		return 0
	var key: String = String(action_id)
	state.known_moves[key] = state.known_moves.get(key, 0) + 1
	return state.known_moves[key]


static func times_seen(state: CharacterState, action_id: StringName) -> int:
	return 0 if state == null else state.known_moves.get(String(action_id), 0)


## Whether the player reads `action`'s tag: the knob off (0), their own, or watched enough.
static func recognised(state: CharacterState, action: CombatActionDefinition, rules: CombatDecisionRules, catalog: ContentCatalog) -> bool:
	if action == null or rules == null or rules.recognise_after <= 0:
		return true
	if is_own(state, action, catalog):
		return true
	return times_seen(state, action.action_id) >= rules.recognise_after


## Whether the move is one of the player's own: a school they have a level in, their race's
## moves, or the verbs of a weapon skill they have learned.
static func is_own(state: CharacterState, action: CombatActionDefinition, catalog: ContentCatalog) -> bool:
	if state == null or action == null or catalog == null:
		return false
	for skill_id: StringName in state.skills.raw_skill_ids():
		if state.skills.raw_level(skill_id) <= 0:
			continue
		var skill: SkillDefinition = catalog.skill(skill_id)
		if skill == null:
			continue
		if _set_has(skill.action_set(), action.action_id):
			return true
		if skill.kind == SkillDefinition.Kind.BASIC and _set_has(catalog.combat_actions().weapon_action_set(skill_id), action.action_id):
			return true
	return _set_has(catalog.combat_actions().race_action_set(NpcCharacterStateFactory.HUMAN_RACE_ID), action.action_id)


## The tag the counter ring says beats `tag`, &"" for 平.
static func weakness(tag: StringName) -> StringName:
	for other: StringName in CombatMoveTags.ALL:
		if CombatMoveTags.beats(other, tag):
			return other
	return CombatMoveTags.NONE


static func _set_has(set: CombatActionSet, action_id: StringName) -> bool:
	if set == null:
		return false
	for action: CombatActionDefinition in set.actions():
		if action.action_id == action_id:
			return true
	return false
