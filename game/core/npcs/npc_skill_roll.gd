class_name NpcSkillRoll
extends RefCounted

## Skills create() gives only when a draw comes up (d/city/npc/walker.c: if (random(4) == 0)
## set_skill() and map_skill()): random(`bound`) below `below` gives `skills` and `skill_map`.
## Drawn after the NPC's apply rules, before its chat_chance rule; the skills it gets are its
## own (CharacterState, saved).
var bound: int = 0
var below: int = 0
var skills: Dictionary[StringName, int] = {}
var skill_map: Dictionary[StringName, StringName] = {}


## {random, below, skills: {skill: level}, skill_map?: {use: skill}}.
static func from_record(reader: ContentRecordReader) -> NpcSkillRoll:
	var roll := NpcSkillRoll.new()
	roll.bound = reader.required_integer("random")
	roll.below = reader.required_integer("below")
	var levels: Dictionary[String, int] = reader.integer_map("skills")
	for skill_id: String in levels:
		roll.skills[StringName(skill_id)] = levels[skill_id]
	var mapped: Dictionary[String, String] = reader.text_map("skill_map")
	for use_id: String in mapped:
		roll.skill_map[StringName(use_id)] = StringName(mapped[use_id])
		if not roll.skills.has(StringName(mapped[use_id])):
			reader.fail("skill_map." + use_id, "maps a skill the roll gives")
	reader.finish()
	if roll.bound < 1 or roll.below < 1 or roll.below > roll.bound:
		reader.fail("random", "a draw random(random) below `below`, 1 <= below <= random")
	if roll.skills.is_empty():
		reader.fail("skills", "the roll gives at least one skill")
	return roll
