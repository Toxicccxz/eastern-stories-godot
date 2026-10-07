class_name ZoneExitRuleDefinition
extends RefCounted

## A room's valid_leave() that refuses one way out while a condition holds:
## d/waterfog/entrance.c (north with a weapon in hand while a 水烟阁武士 is there),
## d/green/entrance.c (east into the 迷阵 below 100000 combat_exp) and
## d/green/outdoor.c (enter only for 绝尘子's apprentices: family/master_id).
## The player stays where they are and reads `lines`: the room's message() and then
## notify_fail(). `present` is the NPC that must be in the room (present() finds one
## lying unconscious too; a dead one is a corpse). The way out may be a walk into the
## next zone or a passage (portal) from `from_zone` to `to_zone`.
enum Condition { WEAPON_IN_HAND, COMBAT_EXP_BELOW, NOT_APPRENTICE_OF }

const CONDITIONS: Dictionary[String, Condition] = {
	"weapon_in_hand": Condition.WEAPON_IN_HAND,
	"combat_exp_below": Condition.COMBAT_EXP_BELOW,
	"not_apprentice_of": Condition.NOT_APPRENTICE_OF,
}

var rule_id: StringName
var room_id: StringName
var from_zone_id: StringName
var to_zone_id: StringName
var condition: Condition
var present_npc_id: StringName
## combat_exp_below: the combat_exp the player needs.
var value: int = 0
## not_apprentice_of: the master (an NPC definition ID) whose apprentices may pass.
var npc_id: StringName
var lines: Array[String] = []
var legacy_source_path: String


## What a rule looks at when the player tries to leave.
class Leaver:
	extends RefCounted
	var weapon_in_hand: bool
	var combat_exp: int
	var master_id: StringName

	func _init(p_weapon_in_hand: bool = false, p_combat_exp: int = 0, p_master_id: StringName = &"") -> void:
		weapon_in_hand = p_weapon_in_hand
		combat_exp = p_combat_exp
		master_id = p_master_id

	static func of(state: CharacterState) -> Leaver:
		return Leaver.new(not state.equipment.is_primary_hand_empty(), state.progression.combat_experience, state.apprenticeship.master_teacher_id)


## Whether the rule stops `leaver`, with `present` true when an NPC of
## `present_npc_id` is in the room.
func refuses(leaver: Leaver, present: bool) -> bool:
	match condition:
		Condition.WEAPON_IN_HAND:
			return leaver.weapon_in_hand and present
		Condition.COMBAT_EXP_BELOW:
			return leaver.combat_exp < value
		Condition.NOT_APPRENTICE_OF:
			return leaver.master_id != npc_id
	return false


## {id, room, from_zone, to_zone, when, lines: [line], legacy_source} and per `when`:
## weapon_in_hand {present: npc id}, combat_exp_below {value}, not_apprentice_of {npc}.
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
	match rule.condition:
		Condition.WEAPON_IN_HAND:
			rule.present_npc_id = StringName(reader.required_text("present"))
		Condition.COMBAT_EXP_BELOW:
			rule.value = reader.required_integer("value")
			if rule.value <= 0:
				reader.fail("value", "must be positive")
		Condition.NOT_APPRENTICE_OF:
			rule.npc_id = StringName(reader.required_text("npc"))
	rule.lines.assign(reader.text_list("lines"))
	if rule.lines.is_empty():
		reader.fail("lines", "a refusal says why")
	rule.legacy_source_path = reader.required_text("legacy_source")
	reader.finish()
	return rule
