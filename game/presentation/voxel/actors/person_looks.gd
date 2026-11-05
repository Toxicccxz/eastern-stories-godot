class_name PersonLooks
extends RefCounted

## Who looks how on the voxel map (DECISIONS「人物外观」): one card per person, by NPC definition
## id, in game/data/<region>/appearances.json ({"people": {id: card}}; the region is the id's
## first part, the player's cards `player.male` / `player.female` in common). A card's keys are
## the ones VoxelPerson reads (coat, pants, skin, hair, hair_style, headwear, beard, waist,
## apron_color, prop, accent, height, build, extras …). A map's voxel config keeps only what is
## the map's own: its `actors.default` for people without a card, and an entry by id that
## changes a person on that map alone (a rider's mount). Presentation only: no rule reads it.

const PEOPLE_KEY: String = "people"
const PLAYER_PREFIX: String = "player"

static var _regions: Dictionary = {}


## The card of `definition_id` (an unnamed NPC definition id, or `player.male`), {} for none.
## `gender` (CharacterState's): for a role whose gender is drawn (traveller.c), the card
## `<id>.male` / `<id>.female` when the region has one, else `<id>`'s.
static func card(definition_id: String, gender: String = "") -> Dictionary:
	var region: String = definition_id.get_slice(".", 0)
	if region == PLAYER_PREFIX:
		region = "common"
	var people: Dictionary = _region(region)
	var sexed: String = with_sex(definition_id, gender)
	return people.get(sexed, {}) if people.has(sexed) else people.get(definition_id, {})


## `<id>.male` / `<id>.female` for a person's gender (CharacterState's), `id` for any other.
static func with_sex(id: String, gender: String) -> String:
	match StringName(gender):
		CharacterState.GENDER_MALE:
			return id + ".male"
		CharacterState.GENDER_FEMALE:
			return id + ".female"
	return id


## The player's card for `gender` (CharacterState's), the male one when there is no other.
static func player(gender: String) -> Dictionary:
	var female: bool = gender == CharacterState.GENDER_FEMALE
	var found: Dictionary = card("player.female" if female else "player.male")
	return found if not found.is_empty() else card("player.male")


## The look of a person on a map (`actors` from the map's voxel config): their card (`person`,
## else the card of `definition_id` for their `gender`) with the map's own entry for them over
## it; without a card, that entry alone, as before cards; with neither, the map's default.
static func resolve(actors: Dictionary, definition_id: String, person: Dictionary = {}, gender: String = "") -> Dictionary:
	var found: Dictionary = person if not person.is_empty() else card(definition_id, gender)
	var own: Dictionary = actors.get(definition_id, {}) if not definition_id.is_empty() else {}
	if found.is_empty():
		return own if not own.is_empty() else actors.get("default", {})
	var look: Dictionary = found.duplicate()
	look.merge(own, true)
	return look


## Every card loaded so far, by region (the suites check them).
static func region_cards(region: String) -> Dictionary:
	return _region(region)


## Forgets what was read (a suite that writes its own files).
static func reset() -> void:
	_regions.clear()


static func _region(region: String) -> Dictionary:
	if _regions.has(region):
		return _regions[region]
	var people: Dictionary = {}
	var path: String = "res://data/%s/appearances.json" % region
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and (parsed as Dictionary).get(PEOPLE_KEY) is Dictionary:
			people = (parsed as Dictionary)[PEOPLE_KEY]
		else:
			push_error("person looks: %s is not {\"%s\": {...}}" % [path, PEOPLE_KEY])
	_regions[region] = people
	return people
