class_name RussianNouns
extends RefCounted

## The Russian forms of the names the game fills into a sentence (docs/production/russian_style.md):
## people, beasts, items, places. Russian changes a name with its role in the sentence (бандит,
## бандита, бандиту…) and agrees a verb with its gender (ударил, ударила). A template does not
## know the name a slot will hold, so the translation marks the case after the slot and
## RussianText picks the form once the line is filled, from res://locale/ru_nouns.json:
##
##   "nominative": [gender, genitive, dative, accusative, instrumental, prepositional, few, many]
##
## gender is м, ж, ср or мн (a word with no singular, ножницы); few and many are the counted
## forms after 2–4 and 5 or more (два бурдюка, пять бурдюков); a form left empty is the
## nominative (a name Russian does not decline: Лань Чжипин). A person's gender is the person's
## (a староста who is a woman is ж); a beast's or a thing's is the word's (собака is ж). The file is the one home of these
## forms: tools/l10n/ru_nouns.py drafts a row for a name that has none and never changes a row.

const PATH: String = "res://locale/ru_nouns.json"
## The case marks, in the order of a row's forms: nominative, genitive, dative, accusative,
## instrumental, prepositional.
const CASES: PackedStringArray = ["им", "род", "дат", "вин", "твор", "пред"]
const GENDERS: PackedStringArray = ["м", "ж", "ср", "мн"]
## вы, the player, as the narration names them; its verbs take the plural.
const YOU: String = "вы"
const _YOU_FORMS: Array[String] = ["мн", "вас", "вам", "вас", "вами", "вас", "", ""]

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
		return _YOU_FORMS
	return _rows.get(lowered, [])


static func knows(name: String) -> bool:
	return not row(name).is_empty()


## The most words a known name has: how far back RussianText looks for one.
static func longest() -> int:
	_load()
	return maxi(_longest, 1)


## м, ж, ср or мн for `name`; "" when it is not known.
static func gender_of(name: String) -> String:
	var found: Array = row(name)
	return "" if found.is_empty() else String(found[0])


## `name` in `case` (one of CASES), its first letter kept as it was; `name` itself when
## it is not known or that form is empty.
static func form(name: String, case: String) -> String:
	var at: int = CASES.find(case)
	if at <= 0:
		return name
	return _shaped(name, at)


## `name` counted by `amount` in the nominative: one бурдюк, два бурдюка, пять бурдюков.
static func counted(name: String, amount: int) -> String:
	match plural_index(amount):
		1:
			return _shaped(name, 6)
		2:
			return _shaped(name, 7)
	return name


## 0 for 1, 21, 101…; 1 for 2–4, 22–24…; 2 for 0, 5–20, 25–30… (Russian's three counted forms).
static func plural_index(amount: int) -> int:
	var n: int = absi(amount)
	if n % 10 == 1 and n % 100 != 11:
		return 0
	if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 12 or n % 100 > 14):
		return 1
	return 2


static func _shaped(name: String, at: int) -> String:
	var found: Array = row(name)
	if found.size() <= at or String(found[at]).is_empty():
		return name
	var shaped: String = String(found[at])
	if name.left(1) != name.left(1).to_lower():
		shaped = shaped.left(1).to_upper() + shaped.substr(1)
	return shaped


## Loads the rows once; a test may set them with use().
static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("RussianNouns: %s is not a JSON object" % PATH)
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
