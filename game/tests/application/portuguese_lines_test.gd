extends RefCounted

## Every Brazilian Portuguese template, filled the way the game fills it, shows no grammar mark: each
## slot and token of pt_BR.po's marked lines is filled with a known name (or a number for %d), $N/$n
## resolved for the player (você) and for another, and PortugueseText must leave no {:o}, {~:…},
## {#:…} or {jogador:…} behind, and no preposition left standing before a contracted one («de do»,
## «a ao»: the mark writes the contraction). A mark the finishing cannot reach (after written text, a slot it cannot read past) fails
## here before a player sees it.

const NAME: String = "Bandido"
const ROWS: Dictionary = {
	"bandido": ["m", "bandidos"],
}
const TOKENS: PackedStringArray = ["$RESPECT", "$SELF", "$N", "$n", "$l", "$w"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var translation: Translation = load("res://locale/pt_BR.po") as Translation
	_check(translation != null, "pt_BR.po loads")
	if translation != null:
		var before: String = TranslationServer.get_locale()
		var portuguese := Translation.new()
		portuguese.locale = "pt_BR"
		TranslationServer.add_translation(portuguese)
		TranslationServer.set_locale("pt_BR")
		PortugueseNouns.use(ROWS)
		_test_lines(translation)
		PortugueseNouns.reset()
		TranslationServer.set_locale("zh_CN")
		TranslationServer.remove_translation(portuguese)
		TranslationServer.set_locale(before)
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_lines(translation: Translation) -> void:
	var slot := RegEx.create_from_string("\\{[a-z_]+\\}|%s")
	var mark := RegEx.create_from_string("\\{(?::[^{}]*|[~#]:[^{}]*|[Nn]:[^{}]*|jogador:[^{}]*|jugador:[^{}]*)\\}")
	var doubled := RegEx.create_from_string("(?i)\\b(?:a (?:ao|à|aos|às)|(?:de|em|por) (?:ao|à|aos|às|do|da|dos|das|no|na|nos|nas|pelo|pela|pelos|pelas)|(?:do|da|dos|das|no|na|nos|nas|ao|aos|à|às|pelo|pela|pelos|pelas) (?:o|a|os|as)) bandidos?\\b")
	var left: Array[String] = []
	var stray: Array[String] = []
	var lines: int = 0
	for message: String in translation.get_message_list():
		var text: String = String(translation.get_message(message))
		if mark.search(text) == null:
			continue
		lines += 1
		for player_acts: bool in [true, false]:
			var actor: MessageGrammar.Role = MessageGrammar.you() if player_acts else MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, NAME)
			var target: MessageGrammar.Role = MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, NAME) if player_acts else MessageGrammar.you()
			var filled: String = MessageGrammar.resolve(text, actor, target)
			filled = filled.replace("$N", "você" if player_acts else NAME).replace("$n", NAME if player_acts else "você")
			filled = slot.sub(filled.replace("%d", "3"), NAME, true)
			for token: String in TOKENS:
				filled = filled.replace(token, NAME)
			var shown: String = PortugueseText.finish(filled)
			if mark.search(shown) != null:
				left.append("%s → %s" % [message.left(24), shown.left(60)])
				break
			if doubled.search(shown) != null:
				stray.append("%s → %s" % [message.left(24), shown.left(60)])
				break
	_check(left.is_empty(), "every filled line resolves its marks (%d lines); left as written in %d: %s" % [lines, left.size(), "; ".join(left.slice(0, 8))])
	_check(stray.is_empty(), "no article or preposition written before a marked name (the mark writes it); in %d: %s" % [stray.size(), "; ".join(stray.slice(0, 8))])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("portuguese_lines: " + label)
