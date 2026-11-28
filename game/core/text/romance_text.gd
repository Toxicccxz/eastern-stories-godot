class_name RomanceText
extends RefCounted

## A Romance language as the game shows it (Spanish: docs/production/spanish_style.md; Brazilian
## Portuguese: docs/production/portuguese_style.md): a filled name with the article its sentence
## wants, words agreeing with that name's gender and number or with a number, and with the
## player's gender. The translation writes marks the game resolves once a line is filled
## (ShownText); SpanishText and PortugueseText hold each language's words for them:
##
##   {npc}{:el} / {:o}       the name just before with its definite article, from the noun table:
##                           «Hablas con {npc}{:el}» → «Hablas con el mozo de la posada»; a
##                           preposition and the article contract (a el → al, de el → del; de o →
##                           do, em a → na, a a → à, por o → pelo); a proper name takes none (Liu
##                           Chunfeng); Spanish leaves tú out as a subject («$N{:el}
##                           {N:golpeas|golpea}» → «Golpeas»)
##   {:un} / {:um}           with the indefinite article
##   {:los} {:unos} / {:os} {:uns}  the name in its plural with the plural article; its agreement
##                           takes the plural
##   {npc}{:0}               no article: a common noun in lower case inside a sentence
##   {count} {item}{:pl}     counted by the number before it: 1 espada, 3 espadas
##   {~:herido|herida}       agrees with the nearest marked name before it (else after it):
##                           m | f, or m | f | mp | fp (the player: the player's gender); three
##                           forms are you | m | f, for a verb after a slot the game may fill with
##                           the player
##   %d {#:día|días}          agrees with the nearest number before it: 1 | any other
##   {jugador:o|a} / {jogador:o|a}  the player's own gender (m | f), from the language's
##                           player_gender, which the world session sets
##
## A mark after a slot not filled yet ({npc}{:el}, $n{:el}, %s{:el}) stays for the filled line, and
## so do the words that agree with it. A mark after a name with no row leaves the name as it is.
## $N and $n agree through MessageGrammar's {N:…} forms, which know whether $N is the player.

const _CLOSERS: String = "»“\"')]"  # NO_TRANSLATE: closing quotes and brackets
const _UNFILLED: String = "\\{[a-z_]+\\}|\\$(?:RESPECT|SELF|[NnPplw])|%[sd]"

## The language part of the locale (es, pt).
var language: String
## The article marks: definite, indefinite, their plurals, none, counted.
var definite: String
var indefinite: String
var definite_plural: String
var indefinite_plural: String
var bare: String = "0"
var counted: String = "pl"
## The player's own gender mark ({jugador:…}).
var player_mark: String
## Whether the player as a subject opening a sentence is left out (Spanish tú; Portuguese keeps
## você, whose verb is the third person's).
var drops_you: bool
## "preposition article" → the contracted form, lower case: {"a el": "al"}.
var contractions: Dictionary
var nouns: RomanceNouns
## The player's gender (CharacterState's value), read when a line needs it.
var gender_source: Callable

var _mark: RegEx
var _player: RegEx
var _unfilled_end: RegEx
var _unfilled: RegEx
var _number: RegEx
var _contraction: RegEx
var _tags: RegEx


func _init(p_language: String, marks: PackedStringArray, p_player_mark: String, p_drops_you: bool, p_contractions: Dictionary, p_nouns: RomanceNouns, p_gender_source: Callable) -> void:
	language = p_language
	definite = marks[0]
	indefinite = marks[1]
	definite_plural = marks[2]
	indefinite_plural = marks[3]
	player_mark = p_player_mark
	drops_you = p_drops_you
	contractions = p_contractions
	nouns = p_nouns
	gender_source = p_gender_source
	var alternatives: Array[String] = [definite, indefinite, definite_plural, indefinite_plural, bare, counted]
	alternatives.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	_mark = RegEx.create_from_string("\\{(?:(:)(" + "|".join(alternatives) + ")|([~#]):([^{}]*))\\}")
	_player = RegEx.create_from_string("\\{" + player_mark + ":([^{}|]*)\\|([^{}]*)\\}")
	_unfilled_end = RegEx.create_from_string("(?:" + _UNFILLED + ")$")
	_unfilled = RegEx.create_from_string(_UNFILLED)
	_number = RegEx.create_from_string("\\d+")
	_tags = RegEx.create_from_string("\\[[^\\]]*\\]")
	var prepositions: Array[String] = []
	for pair: String in contractions:
		var preposition: String = pair.get_slice(" ", 0)
		var written: String = "[" + preposition.left(1) + preposition.left(1).to_upper() + "]" + preposition.substr(1)
		if not prepositions.has(written):
			prepositions.append(written)
	prepositions.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	if not prepositions.is_empty():
		_contraction = RegEx.create_from_string("(?:^|(?<=[\\s«\"(\\]]))(" + "|".join(prepositions) + ") $")  # NO_TRANSLATE: a preposition before the article


## The player's gender now.
func player_gender() -> StringName:
	return gender_source.call() if gender_source.is_valid() else &""


## The definite articles this language writes (a row's article must be one of them, or none).
func articles() -> PackedStringArray:
	return nouns.row_articles()


## `text` with every mark it can resolve resolved; unchanged when it has none.
func finish(text: String) -> String:
	if not text.contains("{"):
		return text
	if text.contains("{" + player_mark + ":"):
		var female: bool = player_gender() == CharacterState.GENDER_FEMALE
		text = _player.sub(text, "$2" if female else "$1", true)
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
				# The player left out as a subject: the space after them goes too.
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


## `before` with its last name given the article `mark` asks for:
## {text, gender, resolved, unfilled, dropped}.
func _named(before: String, mark: String) -> Dictionary:
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
	for count: int in range(mini(nouns.longest(), words.size()), 0, -1):
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
		if not nouns.knows(name):
			continue
		var kept: String = " ".join(words.slice(0, start_word))
		if not kept.is_empty():
			kept += " "
		var is_you: bool = name.to_lower() == nouns.you
		result.gender = nouns.you if is_you else nouns.gender_of(name)
		result.resolved = true
		if is_you and drops_you and mark == definite and (_opens_sentence(kept + opening_marks) or (kept + opening_marks).strip_edges().ends_with("(")):
			# The subject left out: the verb says who.
			result.text = kept + opening_marks + tail
			result.dropped = tail.is_empty()
			return result
		var shaped: String = name
		if nouns.is_common(name) or is_you:
			shaped = shaped.left(1).to_lower() + shaped.substr(1)
		var amount: int = _last_number(kept) if mark == counted else (2 if mark == definite_plural or mark == indefinite_plural else 1)
		if amount != 1:
			shaped = nouns.counted(shaped, amount)
			if nouns.row(name).size() > 1 and not String(nouns.row(name)[1]).is_empty():
				result.gender = result.gender.left(1) + "p"
		var article: String = ""
		if mark == definite:
			article = nouns.definite(name)
		elif mark == indefinite:
			article = nouns.indefinite(name)
		elif nouns.is_common(name) and (mark == definite_plural or mark == indefinite_plural):
			article = nouns.plural_article(name, mark == definite_plural)
		var phrase: String = shaped if article.is_empty() else article + " " + shaped
		if not article.is_empty() and _contraction != null and not opening_marks.contains("«") and not opening_marks.contains("\""):
			# A preposition and the article contract (the preposition's capital kept: Al, Do, À).
			var contracted: RegExMatch = _contraction.search(kept)
			if contracted != null:
				var preposition: String = contracted.get_string(1)
				var joined: String = String(contractions.get(preposition.to_lower() + " " + article, ""))
				if not joined.is_empty():
					kept = kept.left(kept.length() - preposition.length() - 1)
					if preposition.left(1) != preposition.left(1).to_lower():
						joined = joined.left(1).to_upper() + joined.substr(1)
					phrase = joined + phrase.substr(article.length())
		if _opens_sentence(kept + opening_marks):
			phrase = phrase.left(1).to_upper() + phrase.substr(1)
		result.text = kept + opening_marks + phrase + tail
		return result
	return result


func _by_gender(agreement: Dictionary, names: Array[Dictionary]) -> String:
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
		# you | m | f: a slot the game fills with the player takes its own verb («{who}{:el}
		# {~:sientes|siente|siente}»).
		return forms[0] if gender == nouns.you else (forms[2] if gender.begins_with("f") else forms[1])
	if gender == nouns.you:
		gender = "f" if player_gender() == CharacterState.GENDER_FEMALE else "m"
	if forms.size() < 4:
		gender = gender.left(1)
	var index: int = maxi(RomanceNouns.GENDERS.find(gender), 0)
	return forms[index] if index < forms.size() else forms[0]


func _by_number(agreement: Dictionary, out: String) -> String:
	var forms: PackedStringArray = agreement.forms
	var before: String = out.left(agreement.at)
	if _unfilled_after_number(before):
		return agreement.written
	var amount: int = _last_number(before)
	if absi(amount) == 1:
		return forms[0]
	return forms[mini(1, forms.size() - 1)]


## The last number written in `text`, or -1.
func _last_number(text: String) -> int:
	var found: Array[RegExMatch] = _number.search_all(text)
	return -1 if found.is_empty() else int(found[found.size() - 1].get_string())


## Whether a slot not filled yet (%d, {count}) comes after the last number in `text`.
func _unfilled_after_number(text: String) -> bool:
	var last_slot: Array[RegExMatch] = _unfilled.search_all(text)
	if last_slot.is_empty():
		return false
	var numbers: Array[RegExMatch] = _number.search_all(text)
	return numbers.is_empty() or numbers[numbers.size() - 1].get_start() < last_slot[last_slot.size() - 1].get_start()


## Whether a word after `prefix` opens a sentence: nothing before it, or a full stop, a ! or ?
## (and the opening ¿ ¡), or a quotation opened after a colon, past BBCode tags and spaces.
func _opens_sentence(prefix: String) -> bool:
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
