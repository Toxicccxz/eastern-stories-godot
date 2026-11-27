class_name SpanishText
extends RefCounted

## Spanish as the game shows it (docs/production/spanish_style.md): a filled name with the
## article its sentence wants, words agreeing with that name's gender and number or with a
## number, and with the player's gender. The translation writes marks the game resolves once a
## line is filled (ShownText):
##
##   {npc}{:el}              the name just before with its definite article, from SpanishNouns:
##                           «Hablas con {npc}{:el}» → «Hablas con el mozo de la posada»; a + el
##                           and de + el contract (al, del); a proper name takes none (Liu
##                           Chunfeng); tú as a subject is left out («$N{:el} {N:golpeas|golpea}»
##                           → «Golpeas»)
##   {npc}{:un}              with the indefinite article (un mozo, una espada, un hacha)
##   {item}{:los} {item}{:unos}  the name in its plural with the plural article (las espadas
##                           viejas, unos mozos); its agreement takes the plural
##   {npc}{:0}               no article: a common noun in lower case inside a sentence
##   {count} {item}{:pl}     counted by the number before it: 1 espada, 3 espadas
##   {~:herido|herida}       agrees with the nearest marked name before it (else after it):
##                           m | f, or m | f | mp | fp (tú: the player's gender); three forms
##                           are tú | m | f, for a verb after a slot the game may fill with tú
##   %d {#:día|días}          agrees with the nearest number before it: 1 | any other
##   {jugador:o|a}           the player's own gender (m | f), from player_gender, which the world
##                           session sets: «Estás cansad{jugador:o|a}»
##
## A mark after a slot not filled yet ({npc}{:el}, $n{:el}, %s{:el}) stays for the filled line, and
## so do the words that agree with it. A mark after a name with no row leaves the name as it is.
## $N and $n agree through MessageGrammar's {N:…} forms, which know whether $N is the player.

const LANGUAGE: String = "es"
const DEFINITE: String = "el"
const INDEFINITE: String = "un"
const BARE: String = "0"
const COUNTED: String = "pl"
const DEFINITE_PLURAL: String = "los"
const INDEFINITE_PLURAL: String = "unos"
const MARKS: PackedStringArray = [DEFINITE, INDEFINITE, DEFINITE_PLURAL, INDEFINITE_PLURAL, BARE, COUNTED]
## The agreement forms in order: m f, then the plurals mp fp.
const AGREEMENT_ORDER: PackedStringArray = ["m", "f", "mp", "fp"]
const PLAYER_MARK: String = "jugador"
## The gender a slot filled with tú agrees as: the tú form of three, else the player's gender.
const YOU_FORM: String = "tú"
const _CLOSERS: String = "»“\"')]"  # NO_TRANSLATE: closing quotes and brackets
const _UNFILLED: String = "\\{[a-z_]+\\}|\\$(?:RESPECT|SELF|[NnPplw])|%[sd]"

## The player's gender (CharacterState's value): set by the world session once it has its player.
static var player_gender: StringName = &""
static var _mark: RegEx
static var _player_mark: RegEx
static var _unfilled_end: RegEx
static var _number: RegEx
static var _contraction: RegEx
static var _tags: RegEx


## `text` with every mark it can resolve resolved; unchanged when it has none.
static func finish(text: String) -> String:
	if not text.contains("{"):
		return text
	if text.contains("{" + PLAYER_MARK + ":"):
		text = _for_player(text)
	if _mark == null:
		_mark = RegEx.create_from_string("\\{(?:(:)(el|unos|un|los|0|pl)|([~#]):([^{}]*))\\}")
		_unfilled_end = RegEx.create_from_string("(?:" + _UNFILLED + ")$")
		_number = RegEx.create_from_string("\\d+")
		_contraction = RegEx.create_from_string("(?:^|(?<=[\\s«\"(\\]]))([Aa]|[Dd]e) $")  # NO_TRANSLATE: a + el, de + el
		_tags = RegEx.create_from_string("\\[[^\\]]*\\]")
	var marks: Array[RegExMatch] = _mark.search_all(text)
	if marks.is_empty():
		return text
	var out: String = ""
	var at: int = 0
	var names: Array[Dictionary] = []  # {end: int (in out), gender: String, resolved: bool, unfilled: bool}
	var agreements: Array[Dictionary] = []  # {kind, forms, at (in out), written}
	for found: RegExMatch in marks:
		var before: String = out + text.substr(at, found.get_start() - at)
		at = found.get_end()
		if found.get_string(1) == ":":
			var named: Dictionary = _named(before, found.get_string(2))
			out = named.text
			if named.dropped:
				# tú left out as a subject: the space after it goes too.
				if text.substr(at, 1) == " ":
					at += 1
			names.append({"end": out.length(), "gender": named.gender, "resolved": named.resolved, "unfilled": named.unfilled})
			if not named.resolved and named.unfilled:
				out += found.get_string()
		else:
			out = before
			agreements.append({"kind": found.get_string(3), "forms": found.get_string(4).split("|"), "at": out.length(), "written": found.get_string()})
	out += text.substr(at)
	agreements.reverse()
	for agreement: Dictionary in agreements:
		var chosen: String = _by_gender(agreement, names) if agreement.kind == "~" else _by_number(agreement, out)
		var place: int = agreement.at
		out = out.left(place) + chosen + out.substr(place)
	return out


## `text` with each {jugador:m|f} replaced by the form for the player's gender.
static func _for_player(text: String) -> String:
	if _player_mark == null:
		_player_mark = RegEx.create_from_string("\\{" + PLAYER_MARK + ":([^{}|]*)\\|([^{}]*)\\}")
	var female: bool = player_gender == CharacterState.GENDER_FEMALE
	return _player_mark.sub(text, "$2" if female else "$1", true)


## `before` with its last name given the article `mark` asks for:
## {text, gender, resolved, unfilled, dropped}.
static func _named(before: String, mark: String) -> Dictionary:
	var result: Dictionary = {"text": before, "gender": "", "resolved": false, "unfilled": false, "dropped": false}
	var end: int = before.length()
	# Past closing quotes and BBCode closing tags: «[color=red]bandido[/color]»{:el}.
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
	for count: int in range(mini(SpanishNouns.longest(), words.size()), 0, -1):
		var start_word: int = words.size() - count
		var name: String = " ".join(words.slice(start_word))
		var opening_marks: String = ""
		# A name opened by a quote or a tag in its first word: «Liu Chunfeng.
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
		if not SpanishNouns.knows(name):
			continue
		var kept: String = " ".join(words.slice(0, start_word))
		if not kept.is_empty():
			kept += " "
		result.gender = YOU_FORM if name.to_lower() == SpanishNouns.YOU else SpanishNouns.gender_of(name)
		result.resolved = true
		if name.to_lower() == SpanishNouns.YOU and mark == DEFINITE and _opens_sentence(kept + opening_marks):
			# Spanish leaves the subject tú out: the verb says who.
			result.text = kept + opening_marks + tail
			result.dropped = tail.is_empty()
			return result
		var shaped: String = name
		if SpanishNouns.is_common(name) or (name.to_lower() == SpanishNouns.YOU):
			shaped = shaped.left(1).to_lower() + shaped.substr(1)
		var amount: int = _last_number(kept) if mark == COUNTED else (2 if mark == DEFINITE_PLURAL or mark == INDEFINITE_PLURAL else 1)
		if amount != 1:
			shaped = SpanishNouns.counted(shaped, amount)
			if SpanishNouns.row(name).size() > 1 and not String(SpanishNouns.row(name)[1]).is_empty():
				result.gender = result.gender.left(1) + "p"
		var article: String = ""
		if mark == DEFINITE:
			article = SpanishNouns.definite(name)
		elif mark == INDEFINITE:
			article = SpanishNouns.indefinite(name)
		elif SpanishNouns.is_common(name) and (mark == DEFINITE_PLURAL or mark == INDEFINITE_PLURAL):
			var feminine: bool = SpanishNouns.is_feminine(name)
			if mark == DEFINITE_PLURAL:
				article = "las" if feminine else "los"
			else:
				article = "unas" if feminine else "unos"
		var phrase: String = shaped if article.is_empty() else article + " " + shaped
		if article == "el" and not opening_marks.contains("«") and not opening_marks.contains("\""):
			# a + el → al, de + el → del (the preposition's capital kept: Al, Del).
			var contracted: RegExMatch = _contraction.search(kept)
			if contracted != null:
				var preposition: String = contracted.get_string(1)
				kept = kept.left(kept.length() - preposition.length() - 1)
				phrase = preposition + "l" + phrase.substr(2) if preposition.length() == 1 else preposition.left(1) + "el" + phrase.substr(2)
		if _opens_sentence(kept + opening_marks):
			phrase = phrase.left(1).to_upper() + phrase.substr(1)
		result.text = kept + opening_marks + phrase + tail
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
	if named.is_empty() or not named.resolved:
		return forms[0]
	var gender: String = String(named.gender)
	if forms.size() == 3:
		# tú | m | f: a slot the game fills with the player's tú takes its verb («{who}{:el}
		# {~:sientes|siente|siente}»).
		return forms[0] if gender == YOU_FORM else (forms[2] if gender.begins_with("f") else forms[1])
	if gender == YOU_FORM:
		gender = "f" if player_gender == CharacterState.GENDER_FEMALE else "m"
	if forms.size() < 4:
		gender = gender.left(1)
	var index: int = maxi(AGREEMENT_ORDER.find(gender), 0)
	return forms[index] if index < forms.size() else forms[0]


static func _by_number(agreement: Dictionary, out: String) -> String:
	var forms: PackedStringArray = agreement.forms
	var before: String = out.left(agreement.at)
	if _unfilled_after_number(before):
		return agreement.written
	var amount: int = _last_number(before)
	if absi(amount) == 1:
		return forms[0]
	return forms[mini(1, forms.size() - 1)]


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


## Whether a word after `prefix` opens a sentence: nothing before it, or a full stop, a ! or ?
## (and the opening ¿ ¡), or a quotation opened after a colon, past BBCode tags and spaces.
static func _opens_sentence(prefix: String) -> bool:
	var plain: String = _tags.sub(prefix, "", true).strip_edges()
	while plain.ends_with("¿") or plain.ends_with("¡"):
		plain = plain.left(plain.length() - 1).strip_edges()
	var quoted: bool = plain.ends_with("«") or plain.ends_with("\"") or plain.ends_with("—")
	if quoted:
		plain = plain.left(plain.length() - 1).strip_edges()
	if plain.is_empty():
		return true
	var last: String = plain[plain.length() - 1]
	return ".!?\n".contains(last) or (quoted and last == ":")


static func _is_letter(c: String) -> bool:
	return c.to_lower() != c.to_upper() or (c >= "0" and c <= "9")
