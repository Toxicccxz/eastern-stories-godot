class_name StudyMaterial
extends RefCounted

## An item's set("skill", ([...])): what cmds/std/study.c teaches from it.
var skill_id: StringName
var exp_required: int
var sen_cost: int
var difficulty: int
var max_skill: int


## items.json `study`: {skill, exp_required, sen_cost, difficulty, max_skill}.
static func from_record(reader: ContentRecordReader) -> StudyMaterial:
	var material := StudyMaterial.new()
	material.skill_id = StringName(reader.required_text("skill"))
	material.exp_required = reader.integer("exp_required")
	# An LPC mapping key the book does not set reads as 0.
	material.sen_cost = reader.integer("sen_cost")
	material.difficulty = reader.integer("difficulty")
	material.max_skill = reader.integer("max_skill")
	reader.finish()
	return material
