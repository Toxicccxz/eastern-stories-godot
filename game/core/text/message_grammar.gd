class_name MessageGrammar
extends RefCounted

## English grammar in the ES2 message templates ($N acts on $n). Chinese needs none: 你 and a
## name take the same verb, and 他 serves for he, him and his. An English translation marks
## what changes with who $N or $n is (docs/production/english_style.md):
##
##   {N:flick|flicks}   the first form when $N is the player (you), the second otherwise;
##                      {n:…|…} the same for $n. Verbs: {N:are|is}, {N:have|has}.
##   {N:he} {N:him} {N:his} {N:himself}
##                      $N's pronoun: you/you/your/yourself for the player, else by gender
##                      (she/her/her/herself, it/its for a beast or a thing); {n:…} for $n.
##   $N's  $n's         "your" when that one is the player; a name keeps its 's.
##   {N:ударили|ударил|ударила|ударило}
##                      three or four forms (Russian, docs/production/russian_style.md): the
##                      player (вы) or a plural name, then by the gender of $N's name — the
##                      Russian name's own (RussianNouns: собака is ж), else the character's —
##                      м | ж | ср; three forms: ср takes м.
##   {N:golpeas|golpea}  Spanish (docs/production/spanish_style.md): tú, then anyone else; three
##                      forms tú | m | f ({n:te|lo|la}); four tú m | tú f | m | f. A form may
##                      hold an article mark ({n:te golpea|golpea a $n{:el}}).
##                      Brazilian Portuguese the same (docs/production/portuguese_style.md):
##                      você, then anyone else ({n:te|o|a}, {n:te golpeia|golpeia $n{:o}}).
##
## resolve() runs on the translated template before a site fills $N/$n/$P/$p as it always
## has, so a Chinese line comes out exactly as before. capitalize() runs on the filled line
## and only outside Chinese: "you leap" and "the bandit" open a sentence capitalised.

const ACTOR: String = "N"
const TARGET: String = "n"

const _PRONOUNS: Dictionary[String, PackedStringArray] = {
	# key: [you, he, she, it]
	"he": ["you", "he", "she", "it"],
	"him": ["you", "him", "her", "it"],
	"his": ["your", "his", "her", "its"],
	"himself": ["yourself", "himself", "herself", "itself"],
}

static var _token: RegEx


## Who $N or $n is for the grammar: the player (as they read it) or someone of a gender;
## `name` is the name as shown, when the site knows it (fill() sets it).
class Role:
	extends RefCounted
	var is_you: bool
	var gender: StringName
	var name: String

	func _init(p_is_you: bool = false, p_gender: StringName = &"", p_name: String = "") -> void:
		is_you = p_is_you
		gender = p_gender
		name = p_name


static func you() -> Role:
	return Role.new(true)


static func other(gender: StringName = &"") -> Role:
	return Role.new(false, gender)


## The grammar forms of `text` for `actor` ($N) and `target` ($n); a role left null leaves
## its forms as written (a line with no $n).
static func resolve(text: String, actor: Role, target: Role = null) -> String:
	if not text.contains("{") and not text.contains("'s"):
		return text
	if _token == null:
		# A form may hold an article mark of its own (Spanish: {n:te golpea|golpea a $n{:el}}), and
		# the player's form may be empty (Portuguese: no $l{:o}{n:| de $n{:o}}).
		_token = RegEx.create_from_string("\\{([Nn]):((?:[^{}|]|\\{:[^{}|]*\\})*)(?:\\|((?:[^{}]|\\{:[^{}|]*\\})*))?\\}")
	var out: String = ""
	var at: int = 0
	for found: RegExMatch in _token.search_all(text):
		var role: Role = actor if found.get_string(1) == ACTOR else target
		out += text.substr(at, found.get_start() - at)
		at = found.get_end()
		if role == null:
			out += found.get_string()
			continue
		out += _form(role, found.get_string(2), found.get_string(3) if found.get_group_count() >= 3 and found.get_start(3) >= 0 else "", found.get_string())
	out += text.substr(at)
	for pair: Array in [[ACTOR, actor], [TARGET, target]]:
		var role: Role = pair[1]
		if role != null and role.is_you:
			out = out.replace("$%s's" % pair[0], "your")
	return out


## A translated message_vision() line filled the plain way: the grammar forms, then $N with
## `actor_text` and $n with `target_text` (a null role's token is left as written), capitalised.
static func fill(text: String, actor: Role, actor_text: String, target: Role = null, target_text: String = "") -> String:
	if actor != null and actor.name.is_empty():
		actor.name = actor_text
	if target != null and target.name.is_empty():
		target.name = target_text
	var out: String = resolve(text, actor, target)
	if actor != null:
		out = out.replace("$N", actor_text)
	if target != null:
		out = out.replace("$n", target_text)
	return capitalize(out)


## Whether what shows is the Chinese text (a Chinese locale, or no translation loaded for it).
static func shows_chinese() -> bool:
	var locale: String = TranslationServer.get_locale()
	return locale.begins_with("zh") or TranslationServer.get_translation_object(locale) == null


## Upper-cases a Latin letter that opens the line or a sentence (after . ! ? and a space,
## past an opening quote or bracket), and in Korean picks the particles after the filled
## names (KoreanParticles), in Russian puts the filled names in their cases (RussianText).
## Only under a loaded translation: the source language (Chinese)
## has none, whatever the system locale is before Settings applies one.
static func capitalize(text: String) -> String:
	if text.is_empty() or shows_chinese():
		return text
	text = ShownText.of(text)
	var chars: PackedStringArray = []
	var opens: bool = true
	for index: int in range(text.length()):
		var c: String = text[index]
		if opens:
			if c.to_upper() != c:
				c = c.to_upper()
				opens = false
			elif not (c in [" ", "\"", "“", "‘", "'", "(", "[", "—", "\n", "¿", "¡"]):
				opens = false
		elif c in [".", "!", "?"] and not (index > 0 and text[index - 1] == ".") and (index + 1 >= text.length() or text[index + 1] in [" ", "\n", "”", "\""]):
			opens = true
		elif c == "\n":
			opens = true
		chars.append(c)
	return "".join(chars)


static func _form(role: Role, first: String, second: String, written: String) -> String:
	if second.is_empty() and not written.contains("|"):
		var forms: PackedStringArray = _PRONOUNS.get(first, PackedStringArray())
		if forms.is_empty():
			push_error("MessageGrammar: unknown pronoun %s" % written)
			return written
		return forms[_pronoun_index(role)]
	if second.contains("|"):
		var forms: PackedStringArray = [first]
		forms.append_array(second.split("|"))
		var romance: RomanceText = ShownText.romance(TranslationServer.get_locale().get_slice("_", 0))
		var index: int = _romance_index(role, forms.size(), romance) if romance != null else (0 if role.is_you else _russian_gender_index(role))
		return forms[index] if index < forms.size() else forms[1]
	return first if role.is_you else second


## Spanish and Portuguese forms (docs/production/spanish_style.md, portuguese_style.md): three
## are you | m | f (an object pronoun: {n:te|lo|la}); four are you m | you f | m | f, the player's
## by the language's player gender. A name's gender is its word's when the noun table knows it,
## else the character's.
static func _romance_index(role: Role, count: int, romance: RomanceText) -> int:
	if role.is_you:
		return (1 if romance.player_gender() == CharacterState.GENDER_FEMALE else 0) if count >= 4 else 0
	var female: bool = false
	var gender: String = romance.nouns.gender_of(role.name)
	if gender.is_empty():
		female = role.gender == CharacterState.GENDER_FEMALE or role.gender == &"雌性"  # NO_TRANSLATE: a gender value
	else:
		female = gender.begins_with("f")
	if count >= 4:
		return 3 if female else 2
	return 2 if female else 1


## 0 мн, 1 м, 2 ж, 3 ср: the gender of the Russian name when it is known, else the character's.
static func _russian_gender_index(role: Role) -> int:
	match RussianNouns.gender_of(role.name):
		"мн":
			return 0
		"ж":
			return 2
		"ср":
			return 3
		"м":
			return 1
	if role.gender == CharacterState.GENDER_FEMALE or role.gender == &"雌性":  # NO_TRANSLATE: a gender value
		return 2
	return 1


static func _pronoun_index(role: Role) -> int:
	if role.is_you:
		return 0
	if role.gender == CharacterState.GENDER_FEMALE:
		return 2
	if role.gender == CharacterState.GENDER_MALE or role.gender == &"中性神":  # NO_TRANSLATE: a gender value
		return 1
	return 3
