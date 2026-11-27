extends RefCounted

## Every Russian template, filled the way the game fills it, shows no grammar mark: each slot and
## token of ru.po's marked lines is filled with a known name (or a number for %d), $N/$n resolved
## for the player and for another, and RussianText must leave no {:вин}, {~:…} or {#:…} behind.
## A mark the finishing cannot reach (after written text, a slot it cannot read past) fails here
## before a player sees it.

const NAME: String = "бандит"
const ROWS: Dictionary = {
	"бандит": ["м", "бандита", "бандиту", "бандита", "бандитом", "бандите", "бандита", "бандитов"],
}
const TOKENS: PackedStringArray = ["$RESPECT", "$SELF", "$N", "$n", "$l", "$w"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var translation: Translation = load("res://locale/ru.po") as Translation
	_check(translation != null, "ru.po loads")
	if translation != null:
		RussianNouns.use(ROWS)
		_test_lines(translation)
		RussianNouns.reset()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_lines(translation: Translation) -> void:
	var slot := RegEx.create_from_string("\\{[a-z_]+\\}|%s")
	var mark := RegEx.create_from_string("\\{(?::[^{}]*|[~#]:[^{}]*|[Nn]:[^{}]*)\\}")
	var left: Array[String] = []
	for message: String in translation.get_message_list():
		var text: String = String(translation.get_message(message))
		if mark.search(text) == null:
			continue
		for player_acts: bool in [true, false]:
			var actor: MessageGrammar.Role = MessageGrammar.you() if player_acts else MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, NAME)
			var target: MessageGrammar.Role = MessageGrammar.Role.new(false, CharacterState.GENDER_MALE, NAME) if player_acts else MessageGrammar.you()
			var filled: String = MessageGrammar.resolve(text, actor, target)
			filled = filled.replace("$N", "вы" if player_acts else NAME).replace("$n", NAME if player_acts else "вы")
			filled = slot.sub(filled.replace("%d", "3"), NAME, true)
			for token: String in TOKENS:
				filled = filled.replace(token, NAME)
			var shown: String = RussianText.finish(filled)
			if mark.search(shown) != null:
				left.append("%s → %s" % [message.left(24), shown.left(60)])
				break
	_check(left.is_empty(), "every filled line resolves its marks; left as written in %d: %s" % [left.size(), "; ".join(left.slice(0, 8))])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("russian_lines: " + label)
