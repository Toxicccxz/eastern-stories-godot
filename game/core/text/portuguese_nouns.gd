class_name PortugueseNouns
extends RefCounted

## The Brazilian Portuguese forms of the names the game fills into a sentence
## (docs/production/portuguese_style.md): RomanceNouns over res://locale/pt_BR_nouns.json.
## "name": [gender, plural, article]; article is the singular definite article a proper name takes
## in a sentence (a Capital, o Passo do Camelo), or "" for none.

const PATH: String = "res://locale/pt_BR_nouns.json"
const GENDERS: PackedStringArray = RomanceNouns.GENDERS
## você, the player, as the narration names them: no article, the third person's verb.
const YOU: String = "você"

static var _table: RomanceNouns


## The shared table.
static func table() -> RomanceNouns:
	if _table == null:
		_table = RomanceNouns.new(PATH, YOU, {"m": "o", "f": "a", "mp": "os", "fp": "as"}, {"m": "um", "f": "uma", "mp": "uns", "fp": "umas"})
	return _table


static func gender_of(name: String) -> String:
	return table().gender_of(name)


static func use(rows: Dictionary) -> void:
	table().use(rows)


static func reset() -> void:
	table().reset()
