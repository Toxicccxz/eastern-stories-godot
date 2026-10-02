class_name NpcTeaching
extends RefCounted

## What an NPC needs to teach (cmds/std/learn.c) and take apprentices
## (cmds/std/apprentice.c): its family from feature/apprentice.c create_family(),
## whether it is an F_MASTER (std/char/master.c prevent_learn()), its own
## recognize_apprentice() as rules and its attempt_apprentice() as one rule.
## What it can teach is every skill it has that the game defines (skills.json).

## create_family(name, generation, title); privs -1 ("ALL privileges").
var family_name: String = ""
var family_generation: int = 0
var family_title: String = ""
## families.json ID of family_name, set when the catalog is built.
var family_id: StringName = &""
var f_master: bool = false
var recognize_rules: Array[RecognizeRule] = []
var apprentice: ApprenticeRule


## One branch of recognize_apprentice(ob): a student of `family`, or one the NPC
## has marked (`giver_mark`, as accept_object() marks the giver). A refusal says
## its lines; `fail` replaces learn.c's polite refusal (its notify_fail wins).
class RecognizeRule:
	extends RefCounted
	var family_id: StringName = &""
	var giver_mark: String = ""
	var lines: Array[NpcLine] = []
	var fail: String = ""
	var accept: bool = false

	func matches(student_family_id: StringName, student_marks: Dictionary[String, int]) -> bool:
		return (
			(family_id.is_empty() or family_id == student_family_id)
			and (giver_mark.is_empty() or student_marks.get(giver_mark, 0) != 0)
		)


## attempt_apprentice(ob) of daemon/class/swordsman/master.c: the effective
## attributes it requires (query_cor(), query_cps()), what it says either way and
## the class recruit_apprentice() gives. Emotes print nothing (DECISIONS 4E).
class ApprenticeRule:
	extends RefCounted
	var requires: Dictionary[StringName, int] = {}
	var refuse_say: String = ""
	var accept_say: String = ""
	var class_id: StringName = &""


const REQUIREMENTS: Array[StringName] = [&"cor", &"cps"]


func has_family() -> bool:
	return not family_name.is_empty()


## learn.c lets anyone ask; only an NPC whose family can admit a student, or one
## with its own recognize_apprentice(), ever teaches.
func can_teach() -> bool:
	return has_family() or not recognize_rules.is_empty()


## The first matching rule, or null: recognize_apprentice() returned 0.
func recognize(student_family_id: StringName, student_marks: Dictionary[String, int]) -> RecognizeRule:
	for rule: RecognizeRule in recognize_rules:
		if rule.matches(student_family_id, student_marks):
			return rule
	return null


## `family`, `f_master`, `recognize_apprentice` and `apprentice` of an NPC
## record; null when it has none of them.
static func from_record(reader: ContentRecordReader) -> NpcTeaching:
	if not (reader.has("family") or reader.has("f_master") or reader.has("recognize_apprentice") or reader.has("apprentice")):
		return null
	var teaching := NpcTeaching.new()
	var family: ContentRecordReader = reader.child("family")
	if family != null:
		teaching.family_name = family.required_text("name")
		teaching.family_generation = family.required_integer("generation")
		teaching.family_title = family.required_text("title")
		family.finish()
		if teaching.family_generation < 1:
			family.fail("generation", "must be positive")
	teaching.f_master = reader.boolean("f_master", false)
	for record: ContentRecordReader in reader.children("recognize_apprentice"):
		var rule := RecognizeRule.new()
		rule.family_id = StringName(record.text("family"))
		rule.giver_mark = record.text("giver_mark")
		rule.lines = NpcLine.optional_lines(record)
		rule.fail = record.text("fail")
		rule.accept = record.boolean("accept", false)
		if not record.has("accept"):
			record.fail("accept", "is required")
		record.finish()
		teaching.recognize_rules.append(rule)
	var apprentice: ContentRecordReader = reader.child("apprentice")
	if apprentice != null:
		var rule := ApprenticeRule.new()
		var requires: Dictionary[String, int] = apprentice.integer_map("requires")
		for key: String in requires:
			if not REQUIREMENTS.has(StringName(key)):
				apprentice.fail("requires." + key, "unsupported requirement")
			rule.requires[StringName(key)] = requires[key]
		rule.refuse_say = apprentice.required_text("refuse_say")
		rule.accept_say = apprentice.required_text("accept_say")
		rule.class_id = StringName(apprentice.required_text("class"))
		apprentice.finish()
		if family == null:
			apprentice.fail("", "an NPC takes apprentices into its family: it needs one")
		teaching.apprentice = rule
	return teaching
