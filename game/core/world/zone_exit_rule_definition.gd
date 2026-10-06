class_name ZoneExitRuleDefinition
extends RefCounted

## A room's valid_leave() that refuses one way out while a condition holds
## (d/waterfog/entrance.c: north with a weapon in hand while a 水烟阁武士 is there).
## The player stays where they are and reads `lines`: the room's message() and then
## notify_fail(). `present` is the NPC that must be in the room (present() finds one
## lying unconscious too; a dead one is a corpse).
enum Condition { WEAPON_IN_HAND }

const CONDITIONS: Dictionary[String, Condition] = {"weapon_in_hand": Condition.WEAPON_IN_HAND}

var rule_id: StringName
var room_id: StringName
var from_zone_id: StringName
var to_zone_id: StringName
var condition: Condition
var present_npc_id: StringName
var lines: Array[String] = []
var legacy_source_path: String


## Whether the rule stops a player holding `weapon_in_hand`, with `present` true when
## an NPC of `present_npc_id` is in the room.
func refuses(weapon_in_hand: bool, present: bool) -> bool:
	match condition:
		Condition.WEAPON_IN_HAND:
			return weapon_in_hand and present
	return false


## {id, room, from_zone, to_zone, when: weapon_in_hand, present: npc id, lines: [line],
## legacy_source}.
static func from_record(reader: ContentRecordReader) -> ZoneExitRuleDefinition:
	var rule := ZoneExitRuleDefinition.new()
	rule.rule_id = StringName(reader.required_text("id"))
	rule.room_id = StringName(reader.required_text("room"))
	rule.from_zone_id = StringName(reader.required_text("from_zone"))
	rule.to_zone_id = StringName(reader.required_text("to_zone"))
	var when: String = reader.required_text("when")
	if not CONDITIONS.has(when):
		reader.fail("when", "expected one of %s" % ", ".join(CONDITIONS.keys()))
	rule.condition = CONDITIONS.get(when, Condition.WEAPON_IN_HAND)
	rule.present_npc_id = StringName(reader.required_text("present"))
	rule.lines.assign(reader.text_list("lines"))
	if rule.lines.is_empty():
		reader.fail("lines", "a refusal says why")
	rule.legacy_source_path = reader.required_text("legacy_source")
	reader.finish()
	return rule
