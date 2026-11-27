extends RefCounted

## Every Spanish template, filled the way the game fills it, shows no grammar mark and no tú where
## Spanish cannot have it: each slot and token of es_419.po's marked lines is filled with a known
## name (or a number for %d), $N/$n resolved for the player (tú) and for another, and SpanishText
## must leave no {:el}, {~:…}, {#:…} or {jugador:…} behind, and no «a tú» or «de tú» (the player as
## an object is written in the {n:…} forms). A mark the finishing cannot reach (after written text,
## a slot it cannot read past) fails here before a player sees it.

const NAME: String = "Bandido"
const ROWS: Dictionary = {
	"bandido": ["m", "bandidos"],
}
const TOKENS: PackedStringArray = ["$RESPECT", "$SELF", "$N", "$n", "$l", "$w"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var translation: Translation = load("res://locale/es_419.po") as Translation
	_check(translation != null, "es_419.po loads")
	if translation != null:
		var before: String = TranslationServer.get_locale()
		var spanish := Translation.new()
		spanish.locale = "es"
		TranslationServer.add_translation(spanish)
		TranslationServer.set_locale("es_419")
		SpanishNouns.use(ROWS)
		_test_lines(translation)
		SpanishNouns.reset()
		TranslationServer.set_locale("zh_CN")
		TranslationServer.remove_translation(spanish)
		TranslationServer.set_locale(before)
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_lines(translation: Translation) -> void:
	var slot := RegEx.create_from_string("\\{[a-z_]+\\}|%s")
	var mark := RegEx.create_from_string("\\{(?::[^{}]*|[~#]:[^{}]*|[Nn]:[^{}]*|jugador:[^{}]*)\\}")
	var you_after := RegEx.create_from_string("(?i)\\b(?:a|de|con|para|contra|por|sin) tú\\b")
	var left: Array[String] = []
	var stray: Array[String] = []
	for message: String in translation.get_message_list():
		var text: String = String(translation.get_message(message))
		if mark.search(text) == null:
			continue
		for player_acts: bool in [true, false]:
			var actor: MessageGrammar.Role = MessageGrammar.you() if player_acts else MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, NAME)
			var target: MessageGrammar.Role = MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, NAME) if player_acts else MessageGrammar.you()
			var filled: String = MessageGrammar.resolve(text, actor, target)
			filled = filled.replace("$N", "tú" if player_acts else NAME).replace("$n", NAME if player_acts else "tú")
			filled = slot.sub(filled.replace("%d", "3"), NAME, true)
			for token: String in TOKENS:
				filled = filled.replace(token, NAME)
			var shown: String = SpanishText.finish(filled)
			if mark.search(shown) != null:
				left.append("%s → %s" % [message.left(24), shown.left(60)])
				break
			if you_after.search(shown) != null:
				stray.append("%s → %s" % [message.left(24), shown.left(60)])
				break
	_check(left.is_empty(), "every filled line resolves its marks; left as written in %d: %s" % [left.size(), "; ".join(left.slice(0, 8))])
	_check(stray.is_empty(), "the player as an object is written in {n:…} forms (no «a tú»); in %d: %s" % [stray.size(), "; ".join(stray.slice(0, 8))])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("spanish_lines: " + label)
