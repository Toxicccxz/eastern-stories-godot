class_name NpcTalk
extends RefCounted

## What an NPC says: its set("inquiry") answers (cmds/std/ask.c),
## set("chat_chance")/set("chat_msg") (std/char/npc.c chat()) and in a fight
## set("chat_chance_combat")/set("chat_msg_combat"), and how it greets an arriving
## player (d/snow/npc/keeper.c, waiter.c init()/greeting()). Text is kept as
## authored, trailing newlines included; line() trims it for display.

## npc.c random_move(), one chat function that is data; NpcDrinkAction is another.
const RANDOM_MOVE: StringName = &"random_move"

var _inquiry: Dictionary[String, PackedStringArray] = {}
var _kee_answers: Dictionary[String, Array] = {}
var _chat_chance: int = 0
## Each entry is a String (said as written), a ColoredLine (said in its colour, the
## text as authored), RANDOM_MOVE, an NpcDrinkAction or an NpcSpecialAction.
var _chat_entries: Array = []
var _combat_chat_chance: int = 0
## As _chat_entries, without RANDOM_MOVE and NpcDrinkAction.
var _combat_chat_entries: Array = []
var _greeting: Array[NpcLine] = []
## switch(random(n)) in greeting(): n, of which only the first lines say something
## (書局 random(4) with three cases); 0 when every draw says one of the lines.
var _greeting_out_of: int = 0

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
	p_greeting: Array[NpcLine] = [],
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
	return result


func has_answer(topic: String) -> bool:
	return _inquiry.has(topic) or _kee_answers.has(topic)


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


## The lines one greeting chooses from (waiter.c switch(random(3))); one for keeper.c.
func greeting_choices() -> Array[NpcLine]:
	return _greeting.duplicate()


## How many ways one greeting draws (switch(random(n))): a draw past the lines says nothing.
func greeting_draws() -> int:
	return maxi(_greeting_out_of, _greeting.size())


## greeting `out_of`. Called once by the loader.
func with_greeting_out_of(value: int) -> NpcTalk:
	_greeting_out_of = value
	return self


func is_valid() -> bool:
	if _chat_chance < 0 or (_chat_chance > 0 and _chat_entries.is_empty()):
		return false
	if _combat_chat_chance < 0 or (_combat_chat_chance > 0 and _combat_chat_entries.is_empty()):
		return false
	for entry: Variant in _chat_entries:
		if not (
			_is_valid_said(entry)
			or (entry is StringName and entry == RANDOM_MOVE)
			or (entry is NpcDrinkAction and (entry as NpcDrinkAction).is_valid())
		):
			return false
	for entry: Variant in _combat_chat_entries:
		if not _is_valid_said(entry):
			return false
	for topic: String in _inquiry:
		if topic.is_empty():
			return false
	for topic: String in _kee_answers:
		if topic.is_empty() or _inquiry.has(topic) or _kee_answers[topic].is_empty():
			return false
	for greeting: NpcLine in _greeting:
		if greeting == null or line(greeting.text).is_empty():
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
