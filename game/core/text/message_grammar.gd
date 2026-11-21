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


## Who $N or $n is for the grammar: the player (as they read it) or someone of a gender.
class Role:
	extends RefCounted
	var is_you: bool
	var gender: StringName

	func _init(p_is_you: bool = false, p_gender: StringName = &"") -> void:
		is_you = p_is_you
		gender = p_gender


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
		_token = RegEx.create_from_string("\\{([Nn]):([^{}|]+)(?:\\|([^{}]*))?\\}")
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
	var out: String = resolve(text, actor, target)
	if actor != null:
		out = out.replace("$N", actor_text)
	if target != null:
		out = out.replace("$n", target_text)
	return capitalize(out)


## Upper-cases a Latin letter that opens the line or a sentence (after . ! ? and a space,
## past an opening quote or bracket). Only under a loaded translation: the source language
## (Chinese) has none, whatever the system locale is before Settings applies one.
static func capitalize(text: String) -> String:
	var locale: String = TranslationServer.get_locale()
	if text.is_empty() or locale.begins_with("zh") or TranslationServer.get_translation_object(locale) == null:
		return text
	var chars: PackedStringArray = []
	var opens: bool = true
	for index: int in range(text.length()):
		var c: String = text[index]
		if opens:
			if c >= "a" and c <= "z":
				c = c.to_upper()
				opens = false
			elif not (c in [" ", "\"", "“", "‘", "'", "(", "[", "—", "\n"]):
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
	return first if role.is_you else second


static func _pronoun_index(role: Role) -> int:
	if role.is_you:
		return 0
	if role.gender == CharacterState.GENDER_FEMALE:
		return 2
	if role.gender == CharacterState.GENDER_MALE or role.gender == &"中性神":  # NO_TRANSLATE: a gender value
		return 1
	return 3
