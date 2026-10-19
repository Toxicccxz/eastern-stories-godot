class_name CharacterAppearances
extends RefCounted
## Which picture a world body wears (presentation only): the player's by gender, an NPC's by its
## definition, read from res://presentation/art/characters/appearances.json.

const PATH: String = "res://presentation/art/characters/appearances.json"
const FRAMES_DIR: String = "res://presentation/art/characters/"

var _player: Dictionary = {}
var _player_default: String = ""
var _npcs: Dictionary = {}


static func load_default() -> CharacterAppearances:
	var result := CharacterAppearances.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		result._player = (data as Dictionary).get("player", {})
		result._player_default = str((data as Dictionary).get("player_default", ""))
		result._npcs = (data as Dictionary).get("npcs", {})
	else:
		push_error("CharacterAppearances: cannot read %s" % PATH)
	return result


## The player's picture: the one for their gender, else the default.
func player_id(gender: StringName) -> String:
	return str(_player.get(String(gender), _player_default))


## An NPC's picture, "" if none: `definition_id` (a named instance's base id) picks the list, the
## character's spawn point picks from it (variant()), so two travellers in one room differ.
func npc_id(definition_id: StringName, character_id: StringName) -> String:
	var looks: Array = _npcs.get(String(NpcDefinition.unnamed_id(definition_id)), [])
	if looks.is_empty():
		return ""
	return str(looks[variant(character_id, looks.size())])


## The instance at spawn point n (NpcGeneration: "<spawn point>.character[.<generation>]", the
## point ending in its number) wears look (n - 1) % count, the same in every generation; an id
## with no number the first.
static func variant(character_id: StringName, count: int) -> int:
	var digits := RegEx.create_from_string("(\\d+)(?:\\.character(?:\\.\\d+)?)?$").search(String(character_id))
	if digits == null or count <= 0:
		return 0
	return posmod(int(digits.get_string(1)) - 1, count)


static func frames(id: String) -> SpriteFrames:
	if id.is_empty():
		return null
	return load(FRAMES_DIR + id + ".tres") as SpriteFrames
