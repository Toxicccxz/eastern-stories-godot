extends RefCounted

## MessageGrammar: an English line's verb forms and pronouns for who $N and $n are, "your"
## for the player's 's, capitals at a sentence's start outside Chinese, and a Chinese line
## left exactly as it was.

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_forms()
	_test_pronouns()
	_test_possessive()
	_test_capitalize()
	_test_chinese_untouched()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_forms() -> void:
	var line: String = "$N {N:flick|flicks} $w at $n, and $n {n:leap|leaps} aside."
	_same(MessageGrammar.resolve(line, MessageGrammar.you(), MessageGrammar.other(CharacterState.GENDER_MALE)),
		"$N flick $w at $n, and $n leaps aside.", "the player acts")
	_same(MessageGrammar.resolve(line, MessageGrammar.other(CharacterState.GENDER_MALE), MessageGrammar.you()),
		"$N flicks $w at $n, and $n leap aside.", "the player is acted on")
	_same(MessageGrammar.resolve(line, MessageGrammar.other(), MessageGrammar.other()),
		"$N flicks $w at $n, and $n leaps aside.", "two others")
	_same(MessageGrammar.resolve("$N {N:are|is} out of breath.", MessageGrammar.you()), "$N are out of breath.", "be")
	_same(MessageGrammar.resolve("$n {n:stagger|staggers}.", MessageGrammar.you()), "$n {n:stagger|staggers}.",
		"a role not given keeps its forms")


func _test_pronouns() -> void:
	var male := MessageGrammar.other(CharacterState.GENDER_MALE)
	var female := MessageGrammar.other(CharacterState.GENDER_FEMALE)
	_same(MessageGrammar.resolve("{N:he} lifts {N:his} sword at {n:him}; {n:he} braces {n:himself}.", male, female),
		"he lifts his sword at her; she braces herself.", "he and she")
	_same(MessageGrammar.resolve("{N:he} lifts {N:his} sword at {n:him}.", MessageGrammar.you(), MessageGrammar.other(&"雄性")),
		"you lifts your sword at it.", "you, and a beast is it (the verb is the writer's to mark)")


func _test_possessive() -> void:
	_same(MessageGrammar.resolve("$N's whole attack misses $n's guard.", MessageGrammar.you(), MessageGrammar.other()),
		"your whole attack misses $n's guard.", "the player's 's is your")
	_same(MessageGrammar.resolve("$N's blade finds $n's chest.", MessageGrammar.other(), MessageGrammar.you()),
		"$N's blade finds your chest.", "and as the one hit")


func _test_capitalize() -> void:
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_same(MessageGrammar.capitalize("you leap."), "you leap.", "no translation loaded (the source language under any system locale): no capitals")
	var english := Translation.new()
	english.locale = "en"
	TranslationServer.add_translation(english)
	_same(MessageGrammar.capitalize("you leap straight up. the bandit's attack misses!"),
		"You leap straight up. The bandit's attack misses!", "line and sentence starts")
	_same(MessageGrammar.capitalize("“you again?” he says."), "“You again?” he says.", "past an opening quote")
	_same(MessageGrammar.capitalize("( you look a little tired )"), "( You look a little tired )", "a status line")
	_same(MessageGrammar.capitalize("You hit 3 times... and then liu anlu"), "You hit 3 times... and then liu anlu",
		"an ellipsis opens nothing; a name is the writer's to capitalise")
	_same(MessageGrammar.fill("$N {N:hit|hits} $n.", MessageGrammar.you(), "you", MessageGrammar.other(), "the bandit"),
		"You hit the bandit.", "fill() puts it together")
	_same(MessageGrammar.fill("$N {N:hit|hits} $n.", MessageGrammar.other(), "the bandit", MessageGrammar.you(), "you"),
		"The bandit hits you.", "and the other way round")
	TranslationServer.remove_translation(english)
	TranslationServer.set_locale("zh_CN")
	_same(MessageGrammar.capitalize("you leap. a b"), "you leap. a b", "Chinese locale: no capitals")
	TranslationServer.set_locale(before)


func _test_chinese_untouched() -> void:
	for line: String in ["$N手中$w一抖，使出「饿鬼拦路」往$n的$l刺出一剑", "$n身形陡然拔高，使$N的攻势尽数落空。", "{npc}说道：{line}"]:
		_same(MessageGrammar.resolve(line, MessageGrammar.you(), MessageGrammar.other()), line, "unchanged: " + line)
	_same(MessageGrammar.fill("$N对$n说道：好。", MessageGrammar.you(), "你", MessageGrammar.other(), "刘安禄"), "你对刘安禄说道：好。",
		"fill() is the plain replacement in Chinese")


func _same(got: String, want: String, label: String) -> void:
	_check(got == want, "%s: got %s, want %s" % [label, got, want])


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("message_grammar: " + label)
