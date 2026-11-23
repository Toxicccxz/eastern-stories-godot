extends RefCounted

## Every Korean template, filled the way the game fills it, shows no particle pair: each
## slot and token of ko.po's lines is filled with a name ending in a consonant and then
## with one ending in a vowel (an action line after the NPC's name), and KoreanText must
## leave no 을(를), 이(가), (으)로... behind. A pair after written text, or a slot the
## particles cannot read past, fails here before a player sees it.

const NAMES: PackedStringArray = ["산적", "점소이"]
const TOKENS: PackedStringArray = ["$RESPECT", "$SELF", "$N", "$n", "$P", "$p", "$l", "$w"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var translation: Translation = load("res://locale/ko.po") as Translation
	_check(translation != null, "ko.po loads")
	if translation != null:
		_test_lines(translation)
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_lines(translation: Translation) -> void:
	var slot := RegEx.create_from_string("\\{[a-z_]+\\}|%[sd]")
	var pair := RegEx.create_from_string(KoreanParticles._pattern_source())
	var left: Array[String] = []
	var lines: int = 0
	for message: String in translation.get_message_list():
		var text: String = String(translation.get_message(message))
		if text.is_empty() or not text.contains("("):
			continue
		for name: String in NAMES:
			var filled: String = slot.sub(text, name, true)
			for token: String in TOKENS:
				filled = filled.replace(token, name)
			if pair.search(filled) != null and pair.search(filled).get_start() == 0:
				filled = name + filled  # an action line follows the NPC's name
			var shown: String = KoreanText.without_joiners(KoreanText.finish(filled))
			lines += 1
			if pair.search(shown) != null:
				left.append("%s → %s" % [message.left(24), shown.left(60)])
				break
	_check(lines > 0, "ko.po has lines with particle pairs")
	_check(left.is_empty(), "every filled line picks its particles; left as written in %d: %s" % [left.size(), "; ".join(left.slice(0, 8))])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("korean_lines: " + label)
