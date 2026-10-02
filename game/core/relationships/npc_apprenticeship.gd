class_name NpcApprenticeship
extends RefCounted

## The player's side of cmds/std/apprentice.c with an NPC master: the request is
## pending (pending/apprentice) until the master's attempt_apprentice() rule
## (NpcTeaching.ApprenticeRule) recruits through cmds/std/recruit.c and
## feature/apprentice.c recruit_apprentice(). Changing families (betrayal) is not
## offered yet. The pending request is transient, as a query_temp() value.
enum Outcome { RECRUITED, ACKNOWLEDGED, QUALIFICATION_REJECTED, PENDING, CANCELLED, NO_PENDING, OTHER_RELATIONSHIP_DEFERRED, AUTHORITY_FAILURE }

var _pending_master_id: StringName = &""
var _pending_master_name: String = ""
## What the last request or cancel printed, in order, as the player reads it.
var lines: Array[String] = []


func is_pending() -> bool:
	return not _pending_master_id.is_empty()


## feature/apprentice.c is_apprentice_of(): the master's ID and name.
static func is_master_of(student: CharacterState, master: NpcDefinition) -> bool:
	return (
		student != null and master != null and student.family.has_family()
		and student.apprenticeship.master_teacher_id == master.definition_id
		and student.apprenticeship.legacy_master_name == master.display_name
	)


## feature/apprentice.c assign_apprentice(): 封山剑派第十四代弟子 (开山祖师 for the first).
static func family_title(family_name: String, generation: int, title: String) -> String:
	if generation == 1:
		return family_name + "开山祖师"
	return "%s第%s代%s" % [family_name, ChineseNumber.of(generation), title]


func cancel() -> Outcome:
	lines = []
	if not is_pending():
		lines.append(_t("你现在并没有拜任何人为师的意思。"))
		return Outcome.NO_PENDING
	lines.append(_t("你改变主意不想拜%s为师了。") % _pending_master_name)
	_pending_master_id = &""
	_pending_master_name = ""
	return Outcome.CANCELLED


## apprentice <master>: `respect` is how the master addresses the student
## (rankd.c query_respect()); `family` the master's family as defined.
func request(student: CharacterState, master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int, respect: String) -> Outcome:
	lines = []
	var teaching: NpcTeaching = null if master == null else master.teaching()
	if student == null or teaching == null or teaching.apprentice == null or family == null or entry_time_utc < 0:
		return Outcome.AUTHORITY_FAILURE
	var name: String = master.display_name
	if is_master_of(student, master):
		lines.append(_t("你恭恭敬敬地向%s磕头请安，叫道：「师父！」") % name)
		return Outcome.ACKNOWLEDGED
	if student.family.has_family() or student.apprenticeship.has_master():
		lines.append(_t("你已有师门，改投%s门下暂不开放。") % name)
		return Outcome.OTHER_RELATIONSHIP_DEFERRED
	if _pending_master_id == master.definition_id:
		lines.append(_t("你想拜%s为师，但是对方还没有答应。") % name)
		return Outcome.PENDING
	if is_pending():
		lines.append(_t("你改变主意不想拜%s为师了。") % _pending_master_name)
	lines.append(_t("你想要拜%s为师。") % name)
	_pending_master_id = master.definition_id
	_pending_master_name = name
	var rule: NpcTeaching.ApprenticeRule = teaching.apprentice
	if (
		student.attributes.effective_courage() < rule.requires.get(&"cor", 0)
		or student.attributes.effective_composure() < rule.requires.get(&"cps", 0)
	):
		lines.append(_t("%s说道：%s") % [name, NpcTalk.line(rule.refuse_say).replace("$RESPECT", respect)])
		return Outcome.QUALIFICATION_REJECTED
	lines.append(_t("%s说道：%s") % [name, NpcTalk.line(rule.accept_say).replace("$RESPECT", respect)])
	# recruit.c: the student's pending/apprentice is this master.
	lines.append(_t("%s决定收你为弟子。") % name)
	lines.append(_t("你跪了下来向%s恭恭敬敬地磕了四个响头，叫道：「师父！」") % name)
	var generation: int = teaching.family_generation + 1
	student.family = FamilyState.new(family.family_id, generation)
	student.apprenticeship.master_teacher_id = master.definition_id
	student.apprenticeship.legacy_master_name = name
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = rule.class_id
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.family_privileges = 0
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	affiliation.entry_time_utc = entry_time_utc
	student.affiliation = affiliation
	_pending_master_id = &""
	_pending_master_name = ""
	lines.append(_t("恭喜您成为%s的第%s代弟子。") % [family.display_name, ChineseNumber.of(generation)])
	return Outcome.RECRUITED


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
