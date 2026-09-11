class_name NewPlayerRuntimeComposition
extends RefCounted

## Binds an already-created birth result; does not rerun birth or create items.
## Location is supplied by the entry composition, never by the physical map.
static func create(
	character_id: StringName, birth: NewPlayerInitialization,
	location: WorldLocationState,
) -> WorldPlayerRuntimeState:
	if character_id.is_empty() or birth == null or birth.state == null or birth.armor == null:
		return null
	if birth.facts == null or not birth.facts.is_valid() or location == null or not location.is_valid():
		return null
	if birth.body_facts == null:
		return null
	return WorldPlayerRuntimeState.new(
		character_id, birth.state, CombatRelationshipState.new(character_id),
		ActionBusyState.new(), birth.armor, location,
		CharacterRuntimeLifeStatus.Value.ACTIVE, true, true,
		birth.body_facts, birth.facts,
	)
