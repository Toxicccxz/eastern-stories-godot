class_name NpcRecognitionPolicy
extends "res://core/learning/teacher_recognition_policy.gd"

## learn.c for a student who is neither the teacher's apprentice nor of its
## family with full privileges: notify_fail(reject_msg[random(3)]) is drawn
## first, then the NPC's recognize_apprentice() runs, here as NpcTeaching rules.
## An NPC without rules has no such function: call_other() returns 0.
const REJECT_LINES: Array[String] = [
	"%s说道：您太客气了，这怎麽敢当？",
	"%s像是受宠若惊一样，说道：请教？这怎麽敢当？",
	"%s笑著说道：您见笑了，我这点雕虫小技怎够资格「指点」您什麽？",
]

var _teaching: NpcTeaching
var _random: WorldInteractionRandomSource
## What the last evaluation drew and matched, for the lines (LearnLines).
var reject_index: int = -1
var matched_rule: NpcTeaching.RecognizeRule


func _init(p_teaching: NpcTeaching = null, p_random: WorldInteractionRandomSource = null) -> void:
	_teaching = p_teaching
	_random = p_random


func evaluate(student: CharacterStateType, _context: TeachingContextType) -> PolicyResultType:
	matched_rule = null
	reject_index = -1
	if _random == null or student == null:
		return PolicyResultType.new(PolicyResultType.Status.DEPENDENCY_UNAVAILABLE)
	reject_index = _random.legacy_random(REJECT_LINES.size())
	if _teaching == null or _teaching.recognize_rules.is_empty():
		return PolicyResultType.new(PolicyResultType.Status.NO_ADDITIONAL_POLICY)
	matched_rule = _teaching.recognize(student.family.family_id, student.marks)
	if matched_rule != null and matched_rule.accept:
		return PolicyResultType.new(PolicyResultType.Status.ALLOWED)
	return PolicyResultType.new(PolicyResultType.Status.REJECTED)
