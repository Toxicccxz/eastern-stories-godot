class_name RussianText
extends RefCounted

## Russian as the game shows it (docs/production/russian_style.md): a filled name in the case
## its sentence wants, a word agreeing with that name's gender, a word agreeing with a number.
## The translation writes marks the game resolves once a line is filled (ShownText):
##
##   {npc}{:вин}               the name just before in that case (им род дат вин твор пред), from
##                             RussianNouns: «Вы бьёте {npc}{:вин}» → «Вы бьёте бандита»; вы → вас
##   {~:ушли|ушёл|ушла|ушло}   agrees with the nearest name marked before it (else after it):
##                             мн (вы, a plural noun) | м | ж | ср — MessageGrammar's {N:…} order;
##                             three forms: ср takes м
##   %d {#:день|дня|дней}       agrees with the nearest number before it: 1 | 2–4 | 5+
##   {count} {item}{:счёт}     a filled noun counted by the number before it (два бурдюка)
##
## A mark after a slot not filled yet ({npc}{:вин}, $n{:вин}, %s{:вин}) stays for the filled line, and so
## do the words that agree with it. A mark after a name with no row leaves the name as it is.
## $N and $n agree through MessageGrammar's {N:…} forms, which know whether $N is the player.

const LANGUAGE: String = "ru"
const COUNTED: String = "счёт"
## The agreement forms in order: the plural (вы) first, then м ж ср.
const AGREEMENT_ORDER: PackedStringArray = ["мн", "м", "ж", "ср"]
const _CLOSERS: String = "»“\"')]"  # NO_TRANSLATE: closing quotes and brackets
const _UNFILLED: String = "\\{[a-z_]+\\}|\\$(?:RESPECT|SELF|[NnPplw])|%[sd]"

static var _mark: RegEx
static var _unfilled_end: RegEx
static var _number: RegEx


## `text` with every mark it can resolve resolved; unchanged when it has none.
static func finish(text: String) -> String:
	if not text.contains("{"):
		return text
	if _mark == null:
		_mark = RegEx.create_from_string("\\{(?:(:)(им|род|дат|вин|твор|пред|счёт)|([~#]):([^{}]*))\\}")
		_unfilled_end = RegEx.create_from_string("(?:" + _UNFILLED + ")$")
		_number = RegEx.create_from_string("\\d+")
	var marks: Array[RegExMatch] = _mark.search_all(text)
	if marks.is_empty():
		return text
	# Case marks first, left to right: each one's name, gender and where it ends in the output.
	var out: String = ""
	var at: int = 0
	var names: Array[Dictionary] = []  # {end: int (in out), gender: String, resolved: bool}
	var agreements: Array[Dictionary] = []  # {kind, forms, at (in out)}
	for found: RegExMatch in marks:
		var before: String = out + text.substr(at, found.get_start() - at)
		at = found.get_end()
		if found.get_string(1) == ":":
			var case: String = found.get_string(2)
			var named: Dictionary = _named(before, case)
			out = named.text
			names.append({"end": out.length(), "gender": named.gender, "resolved": named.resolved, "unfilled": named.unfilled})
			if not named.resolved and named.unfilled:
				out += found.get_string()
		else:
			out = before
			agreements.append({"kind": found.get_string(3), "forms": found.get_string(4).split("|"), "at": out.length(), "written": found.get_string()})
	out += text.substr(at)
	if agreements.is_empty():
		return out
	# Agreements, right to left so the positions before them hold.
	agreements.reverse()
	for agreement: Dictionary in agreements:
		var chosen: String = ""
		if agreement.kind == "~":
			chosen = _by_gender(agreement, names)
		else:
			chosen = _by_number(agreement, out)
		var place: int = agreement.at
		out = out.left(place) + chosen + out.substr(place)
	return out


## `before` with its last name put in `case`: {text, gender, resolved, unfilled}.
static func _named(before: String, case: String) -> Dictionary:
	var result: Dictionary = {"text": before, "gender": "", "resolved": false, "unfilled": false}
	var end: int = before.length()
	# Past closing quotes and BBCode closing tags: «[color=red]бандит[/color]»{:вин}.
	while end > 0:
		var c: String = before[end - 1]
		if c == "]":
			var opening: int = before.rfind("[", end - 1)
			if opening < 0:
				break
			end = opening
			continue
		if _CLOSERS.contains(c):
			end -= 1
			continue
		break
	var head: String = before.left(end)
	if _unfilled_end.search(head) != null:
		result.unfilled = true
		return result
	var tail: String = before.substr(end)
	var words: PackedStringArray = head.split(" ")
	for count: int in range(mini(RussianNouns.longest(), words.size()), 0, -1):
		var start_word: int = words.size() - count
		var name: String = " ".join(words.slice(start_word))
		var opening_marks: String = ""
		# A name opened by a quote or a tag in its first word: «Лю Чуньфэн.
		while not name.is_empty() and not _is_letter(name[0]):
			if name[0] == "[":
				var closing: int = name.find("]")
				if closing < 0:
					break
				opening_marks += name.left(closing + 1)
				name = name.substr(closing + 1)
				continue
			opening_marks += name[0]
			name = name.substr(1)
		if not RussianNouns.knows(name):
			continue
		var kept: String = " ".join(words.slice(0, start_word))
		if not kept.is_empty():
			kept += " "
		var shaped: String = RussianNouns.counted(name, _last_number(kept)) if case == COUNTED else RussianNouns.form(name, case)
		# A common noun is shown with a capital on its own (a label, a button) and in lower case
		# inside a sentence: «Трактирный слуга» → «Вы зовёте трактирного слугу».
		if _opens_sentence(kept + opening_marks):
			shaped = shaped.left(1).to_upper() + shaped.substr(1)
		elif RussianNouns.is_common(name):
			shaped = shaped.left(1).to_lower() + shaped.substr(1)
		result.text = kept + opening_marks + shaped + tail
		result.gender = RussianNouns.gender_of(name)
		result.resolved = true
		return result
	return result


static func _by_gender(agreement: Dictionary, names: Array[Dictionary]) -> String:
	var named: Dictionary = {}
	for candidate: Dictionary in names:
		if candidate.end <= agreement.at:
			named = candidate
	if named.is_empty():
		for candidate: Dictionary in names:
			if candidate.end > agreement.at:
				named = candidate
				break
	if not named.is_empty() and named.unfilled:
		return agreement.written
	var forms: PackedStringArray = agreement.forms
	var masculine: int = mini(1, forms.size() - 1)
	if named.is_empty() or not named.resolved:
		return forms[masculine]
	var index: int = maxi(AGREEMENT_ORDER.find(String(named.gender)), 0)
	return forms[index] if index < forms.size() else forms[masculine]


static func _by_number(agreement: Dictionary, out: String) -> String:
	var forms: PackedStringArray = agreement.forms
	var before: String = out.left(agreement.at)
	if _unfilled_after_number(before):
		return agreement.written
	var amount: int = _last_number(before)
	if amount < 0:
		return forms[forms.size() - 1]
	var index: int = RussianNouns.plural_index(amount)
	return forms[index] if index < forms.size() else forms[forms.size() - 1]


## The last number written in `text`, or -1.
static func _last_number(text: String) -> int:
	var found: Array[RegExMatch] = _number.search_all(text)
	return -1 if found.is_empty() else int(found[found.size() - 1].get_string())


## Whether a slot not filled yet (%d, {count}) comes after the last number in `text`.
static func _unfilled_after_number(text: String) -> bool:
	var slots: RegEx = RegEx.create_from_string(_UNFILLED)
	var last_slot: Array[RegExMatch] = slots.search_all(text)
	if last_slot.is_empty():
		return false
	var numbers: Array[RegExMatch] = _number.search_all(text)
	return numbers.is_empty() or numbers[numbers.size() - 1].get_start() < last_slot[last_slot.size() - 1].get_start()


## Whether a word after `prefix` opens a sentence: nothing before it, or a full stop, a ! or ?, or
## a quotation opened after a colon (говорит: «…), past BBCode tags and spaces.
static func _opens_sentence(prefix: String) -> bool:
	var plain: String = RegEx.create_from_string("\\[[^\\]]*\\]").sub(prefix, "", true).strip_edges()
	var quoted: bool = plain.ends_with("«") or plain.ends_with("\"")
	if quoted:
		plain = plain.left(plain.length() - 1).strip_edges()
	if plain.is_empty():
		return true
	var last: String = plain[plain.length() - 1]
	return ".!?\n".contains(last) or (quoted and last == ":")


static func _is_letter(c: String) -> bool:
	return c.to_lower() != c.to_upper() or (c >= "0" and c <= "9")
