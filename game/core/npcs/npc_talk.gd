class_name NpcTalk
extends RefCounted

## What an NPC says outside a fight: its set("inquiry") answers (cmds/std/ask.c),
## set("chat_chance")/set("chat_msg") (std/char/npc.c chat()) and the line it greets
## an arriving player with (d/snow/npc/keeper.c init()/greeting()). Text is kept as
## authored, trailing newlines included; line() trims it for display.

## npc.c random_move(), the one chat function that is data.
const RANDOM_MOVE: StringName = &"random_move"

var _inquiry: Dictionary[String, PackedStringArray] = {}
var _chat_chance: int = 0
## Each entry is a String (said as written) or RANDOM_MOVE.
var _chat_entries: Array = []
var _greeting_say: String = ""

var chat_chance: int:
	get:
		return _chat_chance
## say() text after `<name>说道：`, with $RESPECT for the greeted player.
var greeting_say: String:
	get:
		return _greeting_say


func _init(
	p_inquiry: Dictionary[String, PackedStringArray] = {},
	p_chat_chance: int = 0,
	p_chat_entries: Array = [],
	p_greeting_say: String = "",
) -> void:
	_inquiry = p_inquiry.duplicate()
	_chat_chance = p_chat_chance
	_chat_entries = p_chat_entries.duplicate()
	_greeting_say = p_greeting_say


## Topics in authored order.
func inquiry_topics() -> Array[String]:
	var result: Array[String] = []
	result.assign(_inquiry.keys())
	return result


func has_answer(topic: String) -> bool:
	return _inquiry.has(topic)


## The lines said, in turn, for `topic` (empty when the NPC has none).
func answer(topic: String) -> PackedStringArray:
	return _inquiry.get(topic, PackedStringArray())


func chat_entries() -> Array:
	return _chat_entries.duplicate()


## npc.c chat() does nothing without both a chance and lines.
func has_chat() -> bool:
	return _chat_chance > 0 and not _chat_entries.is_empty()


func is_valid() -> bool:
	if _chat_chance < 0 or (_chat_chance > 0 and _chat_entries.is_empty()):
		return false
	for entry: Variant in _chat_entries:
		if not ((entry is String and not line(entry).is_empty()) or (entry is StringName and entry == RANDOM_MOVE)):
			return false
	for topic: String in _inquiry:
		if topic.is_empty():
			return false
	return true


## An authored line as the log shows it: the MUD's trailing newline goes.
static func line(text: String) -> String:
	return text.strip_edges()
