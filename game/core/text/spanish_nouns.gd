class_name SpanishNouns
extends RefCounted

## The Spanish forms of the names the game fills into a sentence (docs/production/spanish_style.md):
## RomanceNouns over res://locale/es_nouns.json. "name": [gender, plural, article]; article is
## the singular definite article a name takes whatever its gender (el hacha, el águila: a
## feminine noun opening with a stressed a; el Paso del Camello), or "" for none.

const PATH: String = "res://locale/es_nouns.json"
const GENDERS: PackedStringArray = RomanceNouns.GENDERS
## tú, the player, as the narration names them: no article; as a subject it is left out.
const YOU: String = "tú"

static var _table: RomanceNouns


## The shared table.
static func table() -> RomanceNouns:
	if _table == null:
		_table = RomanceNouns.new(PATH, YOU, {"m": "el", "f": "la", "mp": "los", "fp": "las"}, {"m": "un", "f": "una", "mp": "unos", "fp": "unas"})
	return _table


static func row(name: String) -> Array:
	return table().row(name)


static func knows(name: String) -> bool:
	return table().knows(name)


static func is_common(name: String) -> bool:
	return table().is_common(name)


static func longest() -> int:
	return table().longest()


static func gender_of(name: String) -> String:
	return table().gender_of(name)


static func is_plural(name: String) -> bool:
	return table().is_plural(name)


static func is_feminine(name: String) -> bool:
	return table().is_feminine(name)


static func definite(name: String) -> String:
	return table().definite(name)


static func indefinite(name: String) -> String:
	return table().indefinite(name)


static func counted(name: String, amount: int) -> String:
	return table().counted(name, amount)


static func use(rows: Dictionary) -> void:
	table().use(rows)


static func reset() -> void:
	table().reset()
