class_name NpcGeneration
extends RefCounted

## Who stands at a spawn point after std/room.c reset() made a new NPC there
## (make_inventory() for one that was destructed, i.e. died). The first is
## `<point>.character`, the n-th `<point>.character.<n>`, so its loadout item IDs
## never meet those of an earlier one's corpse or loot. A save holds only the
## current one; earlier ones live on as corpse victims.


static func character_id(spawn_point_id: StringName, generation: int) -> StringName:
	if generation <= 1:
		return StringName("%s.character" % spawn_point_id)
	return StringName("%s.character.%d" % [spawn_point_id, generation])


## The generation `character_id` is at `spawn_point_id`, or 0 when it is none of them.
static func of(character_id: StringName, spawn_point_id: StringName) -> int:
	var base: String = "%s.character" % spawn_point_id
	var text: String = String(character_id)
	if text == base:
		return 1
	if not text.begins_with(base + "."):
		return 0
	var suffix: String = text.substr(base.length() + 1)
	if not suffix.is_valid_int() or suffix.begins_with("0") or suffix.begins_with("+") or suffix.begins_with("-"):
		return 0
	return suffix.to_int() if suffix.to_int() >= 2 else 0


static func next(character_id: StringName, spawn_point_id: StringName) -> StringName:
	return NpcGeneration.character_id(spawn_point_id, of(character_id, spawn_point_id) + 1)
