class_name NpcTalk
extends RefCounted

## What an NPC says: its set("inquiry") answers (cmds/std/ask.c),
## set("chat_chance")/set("chat_msg") (std/char/npc.c chat()) and in a fight
## set("chat_chance_combat")/set("chat_msg_combat"), and how it greets an arriving
## player (d/snow/npc/keeper.c, waiter.c init()/greeting()). Text is kept as
## authored, trailing newlines included; line() trims it for display.

## npc.c random_move(), one chat function that is data; NpcDrinkAction is another.
const RANDOM_MOVE: StringName = &"random_move"
## An emote command() among the chat functions (oldman2.c's sigh): data/emoted.o is
## not in the mudlib, so it shows nothing, but it is one of the entries drawn.
const SILENT_EMOTE: StringName = &"emote"

var _inquiry: Dictionary[String, PackedStringArray] = {}
var _kee_answers: Dictionary[String, Array] = {}
## The marks an answer's functions set on the asker (oldman2.c's set_flag() among the
## lines: ask.c skipped it; as the code means, it runs).
var _answer_marks: Dictionary[String, Array] = {}
## Topics answered by a function that acts (NpcInquiryRule lists).
var _inquiry_rules: Dictionary[String, Array] = {}
## relay_say(): what the NPC answers when the player says a line beside it.
var _relay_say: Dictionary[String, Array] = {}
var _chat_chance: int = 0
## Each entry is a String (said as written), a ColoredLine (said in its colour, the
## text as authored), RANDOM_MOVE, an NpcDrinkAction or an NpcSpecialAction.
var _chat_entries: Array = []
var _combat_chat_chance: int = 0
## As _chat_entries, without RANDOM_MOVE and NpcDrinkAction.
var _combat_chat_entries: Array = []
## What greeting() does (ScriptedAct): one of them drawn by switch(random(n)), or with
## `_greeting_by_rule` the first that is for the player (shinyu.c: a man, anyone else).
var _greeting: Array[ScriptedAct] = []
## switch(random(n)) in greeting(): n, of which only the first lines say something
## (書局 random(4) with three cases); 0 when every draw says one of the lines.
var _greeting_out_of: int = 0
var _greeting_by_rule: bool = false

var chat_chance: int:
	get:
		return _chat_chance
var combat_chat_chance: int:
	get:
		return _combat_chat_chance


## An answer function judged on how hurt the asker is (herbalist.c heal_me()):
## the first case whose eff_kee * 100 / max_kee reaches `at_least` is said; none
## leaves the topic unanswered, as a function returning 0.
class KeeAnswer:
	extends RefCounted
	var at_least: int
	var say: String

	func _init(p_at_least: int = 0, p_say: String = "") -> void:
		at_least = p_at_least
		say = p_say


func _init(
	p_inquiry: Dictionary[String, PackedStringArray] = {},
	p_chat_chance: int = 0,
	p_chat_entries: Array = [],
	p_greeting: Array[ScriptedAct] = [],
	p_kee_answers: Dictionary[String, Array] = {},
	p_combat_chat_chance: int = 0,
	p_combat_chat_entries: Array = [],
) -> void:
	_inquiry = p_inquiry.duplicate()
	_chat_chance = p_chat_chance
	_chat_entries = p_chat_entries.duplicate()
	_greeting = p_greeting.duplicate()
	_kee_answers = p_kee_answers.duplicate()
	_combat_chat_chance = p_combat_chat_chance
	_combat_chat_entries = p_combat_chat_entries.duplicate()


## Topics in authored order.
func inquiry_topics() -> Array[String]:
	var result: Array[String] = []
	result.assign(_inquiry.keys())
	for topic: String in _kee_answers:
		if not result.has(topic):
			result.append(topic)
	for topic: String in _inquiry_rules:
		if not result.has(topic):
			result.append(topic)
	return result


func has_answer(topic: String) -> bool:
	return _inquiry.has(topic) or _kee_answers.has(topic)


## The marks the answer to `topic` sets on the asker.
func answer_marks(topic: String) -> Array[String]:
	var marks: Array[String] = []
	marks.assign(_answer_marks.get(topic, []))
	return marks


## The rules of a topic answered by a function that acts; empty for the others.
func inquiry_rules(topic: String) -> Array[NpcInquiryRule]:
	var rules: Array[NpcInquiryRule] = []
	rules.assign(_inquiry_rules.get(topic, []))
	return rules


## The lines the player can say beside the NPC that it answers (relay_say()), in authored order.
func relay_phrases() -> Array[String]:
	var phrases: Array[String] = []
	phrases.assign(_relay_say.keys())
	return phrases


## What the NPC answers to `phrase`; empty when it lets it pass.
func relay_answer(phrase: String) -> Array[NpcLine]:
	var lines: Array[NpcLine] = []
	lines.assign(_relay_say.get(phrase, []))
	return lines


## Answer marks, inquiry rules and relay_say. Called once by the loader.
func with_actions(answer_marks: Dictionary[String, Array], rules: Dictionary[String, Array], relay_say: Dictionary[String, Array]) -> NpcTalk:
	_answer_marks = answer_marks.duplicate()
	_inquiry_rules = rules.duplicate()
	_relay_say = relay_say.duplicate()
	return self


## The lines said, in turn, for `topic` (empty when the NPC has none). A topic
## answered by how hurt the asker is needs `asker_kee_percent`.
func answer(topic: String, asker_kee_percent: int = 100) -> PackedStringArray:
	if _kee_answers.has(topic):
		for case: KeeAnswer in _kee_answers[topic]:
			if asker_kee_percent >= case.at_least:
				return PackedStringArray([case.say])
		return PackedStringArray()
	return _inquiry.get(topic, PackedStringArray())


## Whether `topic` is answered by how hurt the asker is (herbalist.c heal_me()).
func answers_by_kee(topic: String) -> bool:
	return _kee_answers.has(topic)


func chat_entries() -> Array:
	return _chat_entries.duplicate()


## npc.c chat() does nothing without both a chance and lines.
func has_chat() -> bool:
	return _chat_chance > 0 and not _chat_entries.is_empty()


func combat_chat_entries() -> Array:
	return _combat_chat_entries.duplicate()


## npc.c chat() in a fight: chat_chance_combat and chat_msg_combat.
func has_combat_chat() -> bool:
	return _combat_chat_chance > 0 and not _combat_chat_entries.is_empty()


func has_greeting() -> bool:
	return not _greeting.is_empty()


## What one greeting chooses from (waiter.c switch(random(3))); one for keeper.c; the
## branches in order when it goes by rule.
func greeting_choices() -> Array[ScriptedAct]:
	return _greeting.duplicate()


## How many ways one greeting draws (switch(random(n))): a draw past the lines says nothing.
func greeting_draws() -> int:
	return maxi(_greeting_out_of, _greeting.size())


## The greeting picks its branch by whom it is for (the first that is), drawing nothing.
func greeting_by_rule() -> bool:
	return _greeting_by_rule


## What greeting() does for a player of this gender and class (and these `facts`: marks,
## temps, what they carry): the first branch that is for them, or the one `draw` (MudOS
## random(n)) picks; null when it does nothing. One way to draw draws nothing.
func choose_greeting(gender: StringName, class_id: StringName, draw: Callable, facts: ScriptedAct.Facts = null) -> ScriptedAct:
	if _greeting.is_empty():
		return null
	if _greeting_by_rule:
		return ScriptedAct.first_for(_greeting, gender, class_id, facts)
	var draws: int = greeting_draws()
	var drawn: int = 0 if draws == 1 else int(draw.call(draws))
	if drawn >= _greeting.size() or not _greeting[drawn].applies_to(gender, class_id, facts):
		return null
	return _greeting[drawn]


## greeting `out_of` and `rules`. Called once by the loader.
func with_greeting_out_of(value: int, by_rule: bool = false) -> NpcTalk:
	_greeting_out_of = value
	_greeting_by_rule = by_rule
	return self


func is_valid() -> bool:
	if _chat_chance < 0 or (_chat_chance > 0 and _chat_entries.is_empty()):
		return false
	if _combat_chat_chance < 0 or (_combat_chat_chance > 0 and _combat_chat_entries.is_empty()):
		return false
	for entry: Variant in _chat_entries:
		if not (
			_is_valid_said(entry)
			or (entry is StringName and (entry == RANDOM_MOVE or entry == SILENT_EMOTE))
			or (entry is NpcDrinkAction and (entry as NpcDrinkAction).is_valid())
		):
			return false
	for entry: Variant in _combat_chat_entries:
		if not (
			_is_valid_said(entry) or (entry is NpcWeaponMatch and (entry as NpcWeaponMatch).is_valid())
			or (entry is NpcFightChat.Wield and entry.is_valid()) or (entry is NpcFightChat.CallPartner and entry.is_valid())
			or (entry is NpcFightChat.SayByAge and entry.is_valid()) or (entry is NpcFightChat.Poison and entry.is_valid())
		):
			return false
	for topic: String in _inquiry:
		if topic.is_empty():
			return false
	for topic: String in _kee_answers:
		if topic.is_empty() or _inquiry.has(topic) or _kee_answers[topic].is_empty():
			return false
	for topic: String in _inquiry_rules:
		if topic.is_empty() or _inquiry.has(topic) or _kee_answers.has(topic) or _inquiry_rules[topic].is_empty():
			return false
	for topic: String in _answer_marks:
		if not _inquiry.has(topic):
			return false
	for phrase: String in _relay_say:
		if phrase.strip_edges().is_empty():
			return false
	for greeting: ScriptedAct in _greeting:
		if greeting == null or greeting.steps.is_empty():
			return false
		for step: ScriptedAct.Step in greeting.steps:
			if step.kind == ScriptedAct.Kind.LINE and (step.line == null or line(step.line.text).is_empty()):
				return false
	return true


## A line said (as written or in its colour) or an NpcSpecialAction.
static func _is_valid_said(entry: Variant) -> bool:
	return (
		(entry is String and not line(entry).is_empty())
		or (entry is ColoredLine and not line(entry.text).is_empty() and ColoredLine.COLORS.has(entry.color))
		or (entry is NpcSpecialAction and (entry as NpcSpecialAction).is_valid())
	)


## An authored line as the log shows it: translated, and the MUD's trailing newline gone.
static func line(text: String) -> String:
	return TranslationServer.translate(text).strip_edges()
