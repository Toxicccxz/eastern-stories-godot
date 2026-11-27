class_name SpanishNouns
extends RefCounted

## The Spanish forms of the names the game fills into a sentence (docs/production/spanish_style.md):
## people, beasts, items, places. Spanish puts an article before a common noun that agrees with
## its gender and number (el mozo, la espada, los guantes), and adjectives agree with it
## (herido, herida). A template does not know the name a slot will hold, so the translation
## marks the article after the slot and SpanishText picks it once the line is filled, from
## res://locale/es_nouns.json:
##
##   "name": [gender, plural, article]
##
## gender is m or f, mp or fp for a word with no singular (las tijeras); plural is the counted
## form after any number but 1 ("" for a name that is never counted); article, when given, is
## the singular definite article the name takes whatever its gender (el hacha, el águila: a
## feminine noun opening with a stressed a), or "" for none. A common noun's key is lower case
## (mozo de la posada): it shows lower case inside a sentence; a proper name keeps its capital
## and takes no article unless its row gives one (el Paso del Camello). The file is the one
## home of these forms.

const PATH: String = "res://locale/es_nouns.json"
const GENDERS: PackedStringArray = ["m", "f", "mp", "fp"]
## tú, the player, as the narration names them: no article; as a subject it is left out.
const YOU: String = "tú"

static var _rows: Dictionary = {}
static var _longest: int = 0
static var _loaded: bool = false


## The row for `name` (as shown, its first letter in either case), or [] when it has none.
static func row(name: String) -> Array:
	_load()
	if name.is_empty():
		return []
	if _rows.has(name):
		return _rows[name]
	var lowered: String = name.left(1).to_lower() + name.substr(1)
	if lowered == YOU:
		return ["m", "", ""]
	return _rows.get(lowered, [])


static func knows(name: String) -> bool:
	return not row(name).is_empty()


## Whether `name` is a common noun: its row is kept under a lower-case key (mozo de la posada),
## so a sentence shows it in lower case with an article; a proper name's key has its capital.
static func is_common(name: String) -> bool:
	_load()
	var lowered: String = name.left(1).to_lower() + name.substr(1)
	if lowered == YOU:
		return false
	return lowered != lowered.left(1).to_upper() + lowered.substr(1) and _rows.has(lowered)


## The most words a known name has: how far back SpanishText looks for one.
static func longest() -> int:
	_load()
	return maxi(_longest, 1)


## m, f, mp or fp for `name`; "" when it is not known.
static func gender_of(name: String) -> String:
	var found: Array = row(name)
	return "" if found.is_empty() else String(found[0])


## Whether `name` is plural (a word with no singular, or a counted plural).
static func is_plural(name: String) -> bool:
	return gender_of(name).ends_with("p")


static func is_feminine(name: String) -> bool:
	return gender_of(name).begins_with("f")


## The definite article `name` takes: el, la, los, las, or "" (a proper name, tú).
static func definite(name: String) -> String:
	var found: Array = row(name)
	if found.is_empty():
		return ""
	if found.size() > 2:
		var article: String = String(found[2])
		if not article.is_empty() or not is_common(name):
			return article
	if not is_common(name):
		return ""
	match String(found[0]):
		"f":
			return "la"
		"mp":
			return "los"
		"fp":
			return "las"
	return "el"


## The indefinite article: un, una, unos, unas, or "" (a proper name). A feminine noun that takes
## el (el hacha) takes un (un hacha).
static func indefinite(name: String) -> String:
	if not is_common(name):
		return ""
	var found: Array = row(name)
	match String(found[0]):
		"f":
			return "un" if found.size() > 2 and String(found[2]) == "el" else "una"
		"mp":
			return "unos"
		"fp":
			return "unas"
	return "un"


## `name` counted by `amount`: its plural for any number but 1 (and -1), the name itself when it
## has no plural form.
static func counted(name: String, amount: int) -> String:
	if absi(amount) == 1:
		return name
	var found: Array = row(name)
	if found.size() < 2 or String(found[1]).is_empty():
		return name
	var plural: String = String(found[1])
	if name.left(1) != name.left(1).to_lower():
		plural = plural.left(1).to_upper() + plural.substr(1)
	return plural


## Loads the rows once; a test may set them with use().
static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("SpanishNouns: %s is not a JSON object" % PATH)
		return
	use(parsed)


static func use(rows: Dictionary) -> void:
	_loaded = true
	_rows = rows
	_longest = 1
	for name: String in rows:
		_longest = maxi(_longest, name.split(" ").size())


## Forgets the rows (a test that used its own): the file is read again when next needed.
static func reset() -> void:
	_loaded = false
	_rows = {}
	_longest = 0
