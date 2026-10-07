class_name NpcTeaching
extends RefCounted

## What an NPC needs to teach (cmds/std/learn.c) and take apprentices
## (cmds/std/apprentice.c): its family from feature/apprentice.c create_family(),
## whether it is an F_MASTER (std/char/master.c prevent_learn()), its own
## recognize_apprentice() as rules and its attempt_apprentice() as one rule.
## What it can teach is every skill it has that the game defines (skills.json).

## create_family(name, generation, title); privs -1 ("ALL privileges"), unless a later
## assign_apprentice(title, privs) set others (於兰天武: 0, he teaches only his own).
var family_name: String = ""
var family_generation: int = 0
var family_title: String = ""
var family_privileges: int = -1
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


## attempt_apprentice(ob) as one of three kinds of rule, and the class its
## recruit_apprentice() gives ("" keeps the student's: daemon/class/fighter's masters
## set none). Emotes print nothing (DECISIONS 4E).
## - requirements (daemon/class/swordsman/master.c): the effective attributes it
##   requires (query_cor(), query_cps()), what it says either way; taken at once.
## - oath (daemon/class/fighter/master.c): it asks for an oath (ask_say; again_say
##   when one is already asked), and the player's swear of `oath` makes it say
##   accept_say and recruit.
## - trial (daemon/class/fighter/champion.c): it says ask_say and tells ask_tell; the
##   accept test is its blows (each a line said before the blow and the line said when
##   the student did not stand it), then `success` and recruit.
class ApprenticeRule:
	extends RefCounted
	var kind: Kind = Kind.REQUIREMENTS
	var requires: Dictionary[StringName, int] = {}
	var refuse_say: String = ""
	var accept_say: String = ""
	var class_id: StringName = &""
	var ask_say: String = ""
	var again_say: String = ""
	var oath: String = ""
	var ask_tell: String = ""
	var blows: Array[TrialBlow] = []
	var success: String = ""


## One blow of a trial: said before it, and said when the student did not stand it.
class TrialBlow:
	extends RefCounted
	var say: String = ""
	var fail: String = ""


enum Kind { REQUIREMENTS, OATH, TRIAL }
const KINDS: Dictionary[String, Kind] = {"requirements": Kind.REQUIREMENTS, "oath": Kind.OATH, "trial": Kind.TRIAL}


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
		teaching.family_privileges = family.integer("privileges", -1)
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
		var kind_text: String = apprentice.text("kind", "requirements")
		if not KINDS.has(kind_text):
			apprentice.fail("kind", "expected one of %s" % ", ".join(KINDS.keys()))
		rule.kind = KINDS.get(kind_text, Kind.REQUIREMENTS)
		rule.class_id = StringName(apprentice.text("class"))
		if rule.kind == Kind.REQUIREMENTS:
			# daemon/class/swordsman/master.c and the like always give their class.
			if rule.class_id.is_empty():
				apprentice.fail("class", "a requirements master gives its class")
			var requires: Dictionary[String, int] = apprentice.integer_map("requires")
			for key: String in requires:
				if not REQUIREMENTS.has(StringName(key)):
					apprentice.fail("requires." + key, "unsupported requirement")
				rule.requires[StringName(key)] = requires[key]
			rule.refuse_say = apprentice.required_text("refuse_say")
			rule.accept_say = apprentice.required_text("accept_say")
		elif rule.kind == Kind.OATH:
			rule.ask_say = apprentice.required_text("ask_say")
			rule.again_say = apprentice.required_text("again_say")
			rule.oath = apprentice.required_text("oath")
			rule.accept_say = apprentice.required_text("accept_say")
		else:
			rule.ask_say = apprentice.required_text("ask_say")
			rule.ask_tell = apprentice.required_text("ask_tell")
			for record: ContentRecordReader in apprentice.children("blows"):
				var blow := TrialBlow.new()
				blow.say = record.required_text("say")
				blow.fail = record.required_text("fail")
				record.finish()
				rule.blows.append(blow)
			if rule.blows.is_empty():
				apprentice.fail("blows", "a trial needs at least one blow")
			rule.success = apprentice.required_text("success")
		apprentice.finish()
		if family == null:
			apprentice.fail("", "an NPC takes apprentices into its family: it needs one")
		teaching.apprentice = rule
	return teaching
