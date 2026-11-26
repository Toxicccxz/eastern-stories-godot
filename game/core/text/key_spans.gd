class_name KeySpans
extends RefCounted

## 关键信息高亮 (过场演出 A; DECISIONS「关键信息高亮」): where in a line as it is shown the words
## stand that the player acts on after reading it. The words are message IDs (a name, a place,
## 子时): each is put into the shown language and looked for in the shown line, so a line's own
## message ID never carries a mark and a translation needs none. A word the shown line does not
## have is simply not lit.

## A line lights this many places at most: more, and nothing stands out.
const LIMIT: int = 2
## A word found by itself (not hand-marked) is at least this long: one 汉字 is in every line.
const MIN_FOUND: int = 2
## The message context of a word as a line writes it, where that differs from the word's own
## translation (an item's name is Cloth Strip; the line says "the strip"): a translation may give
## the word under this context, and the lit word is then looked for in that form.
const CONTEXT: StringName = &"lit"


## The places in `shown` (the line on screen, Korean word joiners and all) of `keys` (hand-marked,
## in their order) and then of `found` (the next steps' people, places and things: the longest
## first), as [start, end) character ranges in `shown`, in reading order; LIMIT at most, none
## over another.
static func find(shown: String, keys: Array[String], found: Array[String] = []) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	if shown.is_empty() or (keys.is_empty() and found.is_empty()):
		return spans
	# The line without joiners, and where each of its characters stands in `shown`.
	var plain: String = ""
	var at: PackedInt32Array = []
	for index: int in shown.length():
		if shown[index] != KoreanText.WORD_JOINER:
			plain += shown[index]
			at.append(index)
	var words: Array[String] = []
	for key: String in keys:
		words.append(word(key))
	var others: Array[String] = []
	for term: String in found:
		var other: String = word(term)
		if other.length() >= MIN_FOUND and not others.has(other) and not words.has(other):
			others.append(other)
	others.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	words.append_array(others)
	var taken: Array[Vector2i] = []
	for each: String in words:
		if taken.size() >= LIMIT:
			break
		var place: int = _place(plain, each, taken)
		if place >= 0:
			taken.append(Vector2i(place, place + each.length()))
	taken.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	for span: Vector2i in taken:
		spans.append(Vector2i(at[span.x], at[span.y - 1] + 1))
	return spans


## The `keys` whose word does not stand in `shown` (the content check lists them by language).
static func missing(shown: String, keys: Array[String]) -> Array[String]:
	var plain: String = KoreanText.without_joiners(shown)
	var lost: Array[String] = []
	for key: String in keys:
		if _place(plain, word(key), []) < 0:
			lost.append(key)
	return lost


## A marked word in the shown language, as it would stand in a line: its form under CONTEXT
## where the translation gives one, else its own translation.
static func word(key: String) -> String:
	var shown: String = TranslationServer.translate(key, CONTEXT)
	if shown == key:
		shown = TranslationServer.translate(key)
	return KoreanText.without_joiners(shown).strip_edges()


## Where `each` first stands in `plain` clear of `taken`, a whole word where it is written in
## letters (Li is not lit inside Lightning); -1 for nowhere.
static func _place(plain: String, each: String, taken: Array[Vector2i]) -> int:
	if each.is_empty():
		return -1
	var lettered: bool = _letter(each[0]) or _letter(each[-1])
	var from: int = 0
	while from <= plain.length() - each.length():
		var place: int = plain.findn(each, from) if lettered else plain.find(each, from)
		if place < 0:
			return -1
		var end: int = place + each.length()
		var whole: bool = not (_letter(each[0]) and place > 0 and _letter(plain[place - 1])) and not (_letter(each[-1]) and end < plain.length() and _letter(plain[end]))
		if whole and not taken.any(func(span: Vector2i) -> bool: return place < span.y and end > span.x):
			return place
		from = place + 1
	return -1


static func _letter(character: String) -> bool:
	var code: int = character.unicode_at(0)
	return (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A) or (code >= 0xC0 and code <= 0x24F)
