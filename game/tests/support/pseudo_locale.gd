class_name PseudoLocale
extends RefCounted

## TEST-ONLY pseudo-language built from the committed template (res://locale/eastern_stories.pot):
## each message reads as its source text with the literal parts wrapped in 〖〗, while the
## slots the game fills ({name}, %s, %d, $N...) and BBCode tags stay outside the marks.
## Text on screen with Chinese or English outside the marks never went through a
## translation, or went through one with a message the template lacks: either way no
## translator could translate it.
const CODE: String = "zz"
const OPEN: String = "〖"
const CLOSE: String = "〗"
const POT_PATH: String = "res://locale/eastern_stories.pot"

static var _slot: RegEx
static var _marked: RegEx
static var _foreign: RegEx


static func language() -> LanguageDefinition:
	return LanguageDefinition.new(CODE, "伪语言", "", "", PackedStringArray(), translation())


static func translation(path: String = POT_PATH) -> Translation:
	var result := Translation.new()
	result.locale = CODE
	for message: Dictionary in read_pot(path):
		result.add_message(message["id"], mark(message["id"]), message["context"])
	return result


## Messages as {id, context}; the header entry is left out.
static func read_pot(path: String = POT_PATH) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string(path)
	var fields: Dictionary = {}
	var current: String = ""
	for line: String in text.split("\n") + PackedStringArray([""]):
		if line.begins_with("msgctxt ") or line.begins_with("msgid ") or line.begins_with("msgstr "):
			current = line.get_slice(" ", 0)
			fields[current] = _unquote(line.substr(current.length() + 1))
		elif line.begins_with("\"") and not current.is_empty():
			fields[current] += _unquote(line)
		elif line.strip_edges().is_empty() or line.begins_with("#"):
			if fields.has("msgid") and not String(fields["msgid"]).is_empty():
				messages.append({"id": fields["msgid"], "context": fields.get("msgctxt", "")})
			if line.strip_edges().is_empty():
				fields = {}
				current = ""
	return messages


static func mark(text: String) -> String:
	var result: String = ""
	var at: int = 0
	for found: RegExMatch in _slots().search_all(text):
		result += _wrap(text.substr(at, found.get_start() - at)) + found.get_string()
		at = found.get_end()
	return result + _wrap(text.substr(at))


static func plain(text: String) -> String:
	return text.replace(OPEN, "").replace(CLOSE, "")


## What of `text` would stay untranslated: Chinese or an English word outside the marks,
## once the `allowed` strings (a player's own name) are taken out. Empty when none.
## An ES2 id in parentheses, (Sandals), is the word a MUD player typed: kept as written,
## also when the parentheses are a template's, marked on their own: 〖(〗Leather shield〖)。〗
static func untranslated(text: String, allowed: PackedStringArray = PackedStringArray()) -> String:
	if _marked == null:
		_marked = RegEx.create_from_string(
			OPEN + "[^" + CLOSE + "]*" + CLOSE + "|\\([A-Z][A-Za-z ]*\\)|(?<=\\(" + CLOSE + ")[A-Z][A-Za-z ]*(?=" + OPEN + "\\))"
		)
		_foreign = RegEx.create_from_string("[\\x{3000}-\\x{303f}\\x{3400}-\\x{4dbf}\\x{4e00}-\\x{9fff}\\x{f900}-\\x{faff}\\x{ff00}-\\x{ffef}]|[A-Za-z]{2,}")
	var rest: String = _marked.sub(text, " ", true)
	for token: String in allowed:
		if not token.is_empty():
			rest = rest.replace(token, " ")
	return rest.strip_edges() if _foreign.search(rest) != null else ""


static func _wrap(segment: String) -> String:
	return segment if segment.strip_edges().is_empty() else OPEN + segment + CLOSE


static func _slots() -> RegEx:
	if _slot == null:
		_slot = RegEx.create_from_string(
			"\\{[A-Za-z_][A-Za-z0-9_]*\\}|%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdifxXc%]|\\$[A-Za-z_]+|\\[/?[A-Za-z_][^\\]]*\\]|\\n"
		)
	return _slot


static func _unquote(quoted: String) -> String:
	var inner: String = quoted.strip_edges()
	inner = inner.substr(1, inner.length() - 2)
	return inner.c_unescape()
