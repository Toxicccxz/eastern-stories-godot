class_name RomanceNouns
extends RefCounted

## The forms of the names the game fills into a sentence, for a Romance language that puts an
## article before a common noun (Spanish, Portuguese): people, beasts, items, places. The article
## agrees with the noun's gender and number (el mozo, la espada; o moço, a espada) and so do
## adjectives, so a translation marks the article after a slot and RomanceText picks it once the
## line is filled, from the language's noun table (res://locale/es_nouns.json, pt_BR_nouns.json):
##
##   "name": [gender, plural, article]
##
## gender is m or f, mp or fp for a word with no singular (las tijeras, as tesouras); plural is the
## counted form after any number but 1 ("" for a name that is never counted); article, when given,
## is the singular definite article the name takes whatever its gender (Spanish el hacha: a
## feminine noun opening with a stressed a; a place that takes one, el Paso del Camello, a
## Capital), or "" for none. A common noun's key is lower case (mozo de la posada): it shows lower
## case inside a sentence; a proper name keeps its capital and takes no article unless its row
## gives one. Each file is the one home of its language's forms.

const GENDERS: PackedStringArray = ["m", "f", "mp", "fp"]

## The table's path.
var path: String
## The player as the narration names them (tú, você): no article.
var you: String
## The definite and indefinite articles by gender: {m, f, mp, fp}.
var definites: Dictionary
var indefinites: Dictionary

var _rows: Dictionary = {}
var _longest: int = 0
var _loaded: bool = false


func _init(p_path: String, p_you: String, p_definites: Dictionary, p_indefinites: Dictionary) -> void:
	path = p_path
	you = p_you
	definites = p_definites
	indefinites = p_indefinites


## The row for `name` (as shown, its first letter in either case), or [] when it has none.
func row(name: String) -> Array:
	_load()
	if name.is_empty():
		return []
	if _rows.has(name):
		return _rows[name]
	var lowered: String = name.left(1).to_lower() + name.substr(1)
	if lowered == you:
		return ["m", "", ""]
	return _rows.get(lowered, [])


func knows(name: String) -> bool:
	return not row(name).is_empty()


## Whether `name` is a common noun: its row is kept under a lower-case key (mozo de la posada),
## so a sentence shows it in lower case with an article; a proper name's key has its capital.
func is_common(name: String) -> bool:
	_load()
	var lowered: String = name.left(1).to_lower() + name.substr(1)
	if lowered == you:
		return false
	return lowered != lowered.left(1).to_upper() + lowered.substr(1) and _rows.has(lowered)


## The most words a known name has: how far back RomanceText looks for one.
func longest() -> int:
	_load()
	return maxi(_longest, 1)


## m, f, mp or fp for `name`; "" when it is not known.
func gender_of(name: String) -> String:
	var found: Array = row(name)
	return "" if found.is_empty() else String(found[0])


## Whether `name` is plural (a word with no singular, or a counted plural).
func is_plural(name: String) -> bool:
	return gender_of(name).ends_with("p")


func is_feminine(name: String) -> bool:
	return gender_of(name).begins_with("f")


## The definite article `name` takes (el, la, los, las; o, a, os, as), or "" (a proper name, the
## player).
func definite(name: String) -> String:
	var found: Array = row(name)
	if found.is_empty():
		return ""
	if found.size() > 2:
		var article: String = String(found[2])
		if not article.is_empty() or not is_common(name):
			return article
	if not is_common(name):
		return ""
	return String(definites.get(String(found[0]), definites.m))


## The indefinite article (un, una, unos, unas; um, uma, uns, umas), or "" (a proper name). A
## feminine noun that takes the masculine article (Spanish el hacha) takes the masculine
## indefinite (un hacha).
func indefinite(name: String) -> String:
	if not is_common(name):
		return ""
	var found: Array = row(name)
	var gender: String = String(found[0])
	if gender == "f" and found.size() > 2 and String(found[2]) == String(definites.m):
		return String(indefinites.m)
	return String(indefinites.get(gender, indefinites.m))


## The plural article for `name` counted or plural ({:los}, {:os}): by its gender.
func plural_article(name: String, is_definite: bool) -> String:
	var table: Dictionary = definites if is_definite else indefinites
	return String(table.fp if is_feminine(name) else table.mp)


## `name` counted by `amount`: its plural for any number but 1 (and -1), the name itself when it
## has no plural form.
func counted(name: String, amount: int) -> String:
	if absi(amount) == 1:
		return name
	var found: Array = row(name)
	if found.size() < 2 or String(found[1]).is_empty():
		return name
	var plural: String = String(found[1])
	if name.left(1) != name.left(1).to_lower():
		plural = plural.left(1).to_upper() + plural.substr(1)
	return plural


## The articles a row may name: the definite ones, or none.
func row_articles() -> PackedStringArray:
	var articles: PackedStringArray = [""]
	for gender: String in GENDERS:
		articles.append(String(definites[gender]))
	return articles


## Loads the rows once; a test may set them with use().
func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("RomanceNouns: %s is not a JSON object" % path)
		return
	use(parsed)


func use(rows: Dictionary) -> void:
	_loaded = true
	_rows = rows
	_longest = 1
	for name: String in rows:
		_longest = maxi(_longest, name.split(" ").size())


## Forgets the rows (a test that used its own): the file is read again when next needed.
func reset() -> void:
	_loaded = false
	_rows = {}
	_longest = 0
