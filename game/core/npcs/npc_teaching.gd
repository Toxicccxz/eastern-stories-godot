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


## attempt_apprentice(ob) as one of four kinds of rule, and the class its
## recruit_apprentice() gives ("" keeps the student's: daemon/class/fighter's masters
## set none). Emotes print nothing (DECISIONS 4E).
## - requirements (daemon/class/swordsman/master.c): its checks in order, each the
##   minimums it requires and what it says when one is short (RequirementCheck), and what
##   it says to one it takes, at once. daemon/class/juechen/master.c first takes anyone
##   whose title is not 普通百姓 (a family's member) for a traitor (`commoners_only`: its
##   chat line, then kill_ob()). daemon/class/taoist/taolord.c answers `answer_after`
##   seconds later (call_out("do_recruit", 2)): its checks, its say and its recruit come
##   then, and one asking while that answer is due hears `busy_say` (find_call_out()).
##   daemon/class/dancer/master.c adds a message_vision() after its say for a young beauty
##   (`accept_vision`). daemon/class/scholar/master.c takes only one with a mark (marks/桃林);
##   its refusal marks the student (marks/书生: the way east is open), and whom it takes loses
##   both marks (`unmarks`).
## - oath (daemon/class/fighter/master.c): it asks for an oath (ask_say; again_say
##   when one is already asked), and the player's swear of `oath` makes it say
##   accept_say and recruit.
## - trial (daemon/class/fighter/champion.c): it says ask_say and tells ask_tell; the
##   accept test is its blows (each a line said before the blow and the line said when
##   the student did not stand it), then `success` and recruit. d/latemoon/room/npc/elon.c
##   checks first (its checks, each with its say), then takes a family's member for a
##   traitor (`commoners_only`); its test is taken only by those its checks pass, and whom it
##   takes is titled `title` (its set("title") after the recruit).
## - refuses (d/latemoon/room/npc/annihi.c): it only says refuse_say.
class ApprenticeRule:
	extends RefCounted
	var kind: Kind = Kind.REQUIREMENTS
	## Every check's minimums together.
	var requires: Dictionary[StringName, int] = {}
	var checks: Array[RequirementCheck] = []
	## The chat line ({title}{nickname}{name} of the student) before the kill; "" takes anyone.
	var commoners_only: String = ""
	var accept_say: String = ""
	## message_vision($N the master, $n the student) after accept_say, or null.
	var accept_vision: AcceptVision
	## The title the master sets on whom it takes, "" for assign_apprentice()'s.
	var title: String = ""
	var refuse_say: String = ""
	## Seconds before a requirements master answers (its call_out()); 0 answers at once.
	var answer_after: float = 0.0
	var busy_say: String = ""
	var class_id: StringName = &""
	var ask_say: String = ""
	var again_say: String = ""
	var oath: String = ""
	var ask_tell: String = ""
	var blows: Array[TrialBlow] = []
	var success: String = ""
	## The marks whom it takes loses (ob->set("marks/书生", 0)).
	var unmarks: Array[String] = []


## One check of attempt_apprentice(): the minimums it requires, cor and cps as
## query_cor() and query_cps() have them, spi as set (query("spi")) and combat_exp, the
## gender it takes ("" any; query("gender") != "男性" in taolord.c), the class it takes
## ("" any; query("class") != "bonze" in daemon/class/bonze/master.c), the saved mark it
## needs ("" none; query("marks/桃林") in daemon/class/scholar/master.c), what it says when
## one is short and the marks its refusal gives (set("marks/书生", 1)).
class RequirementCheck:
	extends RefCounted
	var requires: Dictionary[StringName, int] = {}
	var gender: String = ""
	var class_id: StringName = &""
	var mark: String = ""
	var refuse_say: String = ""
	var refuse_marks: Array[String] = []


## One blow of a trial: said before it, and said when the student did not stand it ("":
## only emotes, elon.c's sigh and shake).
class TrialBlow:
	extends RefCounted
	var say: String = ""
	var fail: String = ""


## master.c do_recruit(): `line` when the student's query("per") is above `per_above` and
## their age below `age_below`.
class AcceptVision:
	extends RefCounted
	var line: String = ""
	var per_above: int = 0
	var age_below: int = 0

	func applies(personality: int, age: int) -> bool:
		return personality > per_above and age < age_below


enum Kind { REQUIREMENTS, OATH, TRIAL, REFUSES }
const KINDS: Dictionary[String, Kind] = {"requirements": Kind.REQUIREMENTS, "oath": Kind.OATH, "trial": Kind.TRIAL, "refuses": Kind.REFUSES}


const REQUIREMENTS: Array[StringName] = [&"cor", &"cps", &"spi", &"combat_exp"]
## The genders a check may require (query("gender")).
const GENDERS: Array[StringName] = [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]


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
		# 0 is a founder's (d/latemoon/room/npc/elon.c, 晚月庄开山祖师).
		if teaching.family_generation < 0:
			family.fail("generation", "must not be negative")
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
		rule.title = apprentice.text("title")
		if rule.kind == Kind.REQUIREMENTS:
			# daemon/class/swordsman/master.c and the like always give their class.
			if rule.class_id.is_empty():
				apprentice.fail("class", "a requirements master gives its class")
			if apprentice.has("requires") and not apprentice.is_object("requires"):
				_read_checks(apprentice, rule)
			else:
				# {<key>: minimum} and one refuse_say: a single check.
				var check := RequirementCheck.new()
				var requires: Dictionary[String, int] = apprentice.integer_map("requires")
				for key: String in requires:
					if not REQUIREMENTS.has(StringName(key)):
						apprentice.fail("requires." + key, "unsupported requirement")
					check.requires[StringName(key)] = requires[key]
				check.refuse_say = apprentice.required_text("refuse_say")
				rule.checks.append(check)
			rule.accept_say = apprentice.required_text("accept_say")
			var vision: ContentRecordReader = apprentice.child("accept_vision")
			if vision != null:
				rule.accept_vision = AcceptVision.new()
				rule.accept_vision.line = vision.required_text("line")
				rule.accept_vision.per_above = vision.required_integer("per_above")
				rule.accept_vision.age_below = vision.required_integer("age_below")
				vision.finish()
			rule.commoners_only = apprentice.text("commoners_only")
			rule.unmarks = apprentice.text_list("unmarks")
			rule.answer_after = float(apprentice.integer("answer_after", 0))
			if rule.answer_after < 0.0:
				apprentice.fail("answer_after", "must not be negative")
			rule.busy_say = apprentice.text("busy_say")
			if rule.answer_after > 0.0 and rule.busy_say.is_empty():
				apprentice.fail("busy_say", "a master who answers later says something to one asking meanwhile")
			if rule.answer_after > 0.0 and not rule.commoners_only.is_empty():
				apprentice.fail("answer_after", "a master who takes only commoners answers at once")
		elif rule.kind == Kind.OATH:
			rule.ask_say = apprentice.required_text("ask_say")
			rule.again_say = apprentice.required_text("again_say")
			rule.oath = apprentice.required_text("oath")
			rule.accept_say = apprentice.required_text("accept_say")
		elif rule.kind == Kind.TRIAL:
			if apprentice.has("requires"):
				_read_checks(apprentice, rule)
			rule.commoners_only = apprentice.text("commoners_only")
			rule.ask_say = apprentice.required_text("ask_say")
			rule.ask_tell = apprentice.required_text("ask_tell")
			for record: ContentRecordReader in apprentice.children("blows"):
				var blow := TrialBlow.new()
				blow.say = record.required_text("say")
				blow.fail = record.text("fail")
				record.finish()
				rule.blows.append(blow)
			if rule.blows.is_empty():
				apprentice.fail("blows", "a trial needs at least one blow")
			rule.success = apprentice.required_text("success")
		else:
			rule.refuse_say = apprentice.required_text("refuse_say")
		for check: RequirementCheck in rule.checks:
			rule.requires.merge(check.requires, true)
		apprentice.finish()
		if family == null:
			apprentice.fail("", "an NPC takes apprentices into its family: it needs one")
		teaching.apprentice = rule
	return teaching


## `requires` as [{<key>: minimum, ..., "gender"?, "class"?, "mark"?, "refuse_say",
## "refuse_marks"?}]: checked in turn, each with its say.
static func _read_checks(apprentice: ContentRecordReader, rule: ApprenticeRule) -> void:
	for record: ContentRecordReader in apprentice.children("requires"):
		var check := RequirementCheck.new()
		for key: String in record.keys():
			if key == "refuse_say":
				continue
			if key == "gender":
				check.gender = record.required_text("gender")
				if not GENDERS.has(StringName(check.gender)):
					record.fail("gender", "expected one of %s" % [GENDERS])
				continue
			if key == "class":
				check.class_id = StringName(record.required_text("class"))
				continue
			if key == "mark":
				check.mark = record.required_text("mark")
				continue
			if key == "refuse_marks":
				check.refuse_marks = record.text_list("refuse_marks")
				continue
			if not REQUIREMENTS.has(StringName(key)):
				record.fail(key, "unsupported requirement")
			check.requires[StringName(key)] = record.required_integer(key)
		check.refuse_say = record.required_text("refuse_say")
		record.finish()
		rule.checks.append(check)
