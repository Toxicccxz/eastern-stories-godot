class_name NpcInquiryRule
extends RefCounted

## One branch of an inquiry answered by a function that acts (d/green/npc/shen.c
## give_jade(), sell_drug()): the first rule whose `asker_marks` the asker all has
## decides. It says its lines, sets `mark_asker` on the asker and makes `gives`, an
## item the NPC hands over (give.c); an F_UNIQUE item that already exists somewhere
## (violate_unique()) is not made, and `taken_lines` are said instead, without the mark.
## No rule matching is the function printing nothing (command("?")): ask.c goes on to
## its own lines. The marks hold d/green's set_temp() flags (DECISIONS 青石村 B).
var asker_marks: Array[String] = []
var lines: Array[NpcLine] = []
var mark_asker: String = ""
var gives: StringName = &""
var taken_lines: Array[NpcLine] = []


func matches(marks: Dictionary[String, int]) -> bool:
	for mark: String in asker_marks:
		if marks.get(mark, 0) == 0:
			return false
	return true


static func decide(rules: Array[NpcInquiryRule], marks: Dictionary[String, int]) -> NpcInquiryRule:
	for rule: NpcInquiryRule in rules:
		if rule.matches(marks):
			return rule
	return null


static func from_record(reader: ContentRecordReader) -> NpcInquiryRule:
	var rule := NpcInquiryRule.new()
	rule.asker_marks = reader.text_list("asker_marks")
	rule.lines = NpcLine.optional_lines(reader)
	rule.mark_asker = reader.text("mark_asker")
	rule.gives = StringName(reader.text("gives"))
	var taken: ContentRecordReader = reader.child("taken")
	if taken != null:
		rule.taken_lines = NpcLine.optional_lines(taken)
		taken.finish()
		if rule.gives.is_empty():
			reader.fail("taken", "is said only instead of `gives`")
	reader.finish()
	if rule.lines.is_empty() and rule.gives.is_empty():
		reader.fail("", "says or gives something")
	return rule
