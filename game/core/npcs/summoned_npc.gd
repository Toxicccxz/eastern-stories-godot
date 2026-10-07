class_name SummonedNpc
extends RefCounted

## An NPC a spell called into the world (saveme.c: new("/obj/npc/heaven_soldier")->move()).
## No room placed it: its spawn is made as it comes, and it leaves once the fight it was
## called into is over, so a save never holds it alive; only its corpse may stay. Its
## spawn point is summoned.<number>.<definition>, the number drawn from the session's
## saved item allocator, so it never meets an earlier one's corpse or loot, and such a
## corpse's victim still names the definition it was.
const PREFIX: String = "summoned."
## The spawn's legacy room: none placed it.
const LEGACY_SOURCE: String = "summoned"


static func point_id(number: int, definition_id: StringName) -> StringName:
	return StringName("%s%d.%s" % [PREFIX, number, definition_id])


## The spawn one NPC of `definition_id` came by, at `point_id` in `zone_id` of `map_id`.
static func spawn(p_point_id: StringName, definition_id: StringName, map_id: StringName, zone_id: StringName) -> NpcSpawnDefinition:
	return NpcSpawnDefinition.new(
		p_point_id, definition_id, map_id, zone_id, [p_point_id], 1, LEGACY_SOURCE, 1,
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
	)


static func is_summoned(character_id: StringName) -> bool:
	return not definition_id_of(character_id).is_empty()


## The NPC definition a summoned NPC's character ID names; "" for any other character.
static func definition_id_of(character_id: StringName) -> StringName:
	var text: String = String(character_id)
	if not text.begins_with(PREFIX) or not text.ends_with(".character"):
		return &""
	var rest: String = text.trim_prefix(PREFIX).trim_suffix(".character")
	var dot: int = rest.find(".")
	if dot <= 0 or not rest.substr(0, dot).is_valid_int() or rest.substr(0, dot).begins_with("-"):
		return &""
	return StringName(rest.substr(dot + 1))
