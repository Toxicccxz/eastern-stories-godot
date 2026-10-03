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

# TRANSLATORS: the title of a family's founder: {family} is the family (封山剑派).
const FOUNDER_TITLE: String = "{family}开山祖师"
# TRANSLATORS: a family member's title, e.g. 封山剑派第十四代弟子: {generation} in words, {title} the rank (弟子).
const MEMBER_TITLE: String = "{family}第{generation}代{title}"

## feature/apprentice.c is_apprentice_of(): the master's ID and name.
static func is_master_of(student: CharacterState, master: NpcDefinition) -> bool:
	return (
		student != null and master != null and student.family.has_family()
		and student.apprenticeship.master_teacher_id == master.definition_id
		and student.apprenticeship.legacy_master_name == master.display_name
	)


## feature/apprentice.c assign_apprentice(): 封山剑派第十四代弟子 (开山祖师 for the first),
## as ES2 writes it: this is the title a character keeps (and a save holds).
static func family_title(family_name: String, generation: int, title: String) -> String:
	if generation == 1:
		return FOUNDER_TITLE.format({"family": family_name})
	return MEMBER_TITLE.format({"family": family_name, "generation": ChineseNumber.source_text(generation), "title": title})


## The same title put together in the shown language.
static func shown_family_title(family_name: String, generation: int, title: String) -> String:
	if generation == 1:
		return _t(FOUNDER_TITLE).format({"family": _t(family_name)})
	return _t(MEMBER_TITLE).format({"family": _t(family_name), "generation": ChineseNumber.of(generation), "title": _t(title)})


func cancel() -> Outcome:
	lines = []
	if not is_pending():
		lines.append(_t("你现在并没有拜任何人为师的意思。"))
		return Outcome.NO_PENDING
	lines.append(_t("你改变主意不想拜%s为师了。") % _t(_pending_master_name))
	_pending_master_id = &""
	_pending_master_name = ""
	return Outcome.CANCELLED


## apprentice <master>: `respect` is how the master addresses the student
## (rankd.c query_respect()); `family` the master's family as defined. The lines are
## in the shown language; the names kept on the student stay as authored.
func request(student: CharacterState, master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int, respect: String) -> Outcome:
	lines = []
	var teaching: NpcTeaching = null if master == null else master.teaching()
	if student == null or teaching == null or teaching.apprentice == null or family == null or entry_time_utc < 0:
		return Outcome.AUTHORITY_FAILURE
	var name: String = master.display_name
	var npc: String = _t(name)
	if is_master_of(student, master):
		lines.append(_t("你恭恭敬敬地向%s磕头请安，叫道：「师父！」") % npc)
		return Outcome.ACKNOWLEDGED
	if student.family.has_family() or student.apprenticeship.has_master():
		lines.append(_t("你已有师门，改投%s门下暂不开放。") % npc)
		return Outcome.OTHER_RELATIONSHIP_DEFERRED
	if _pending_master_id == master.definition_id:
		lines.append(_t("你想拜%s为师，但是对方还没有答应。") % npc)
		return Outcome.PENDING
	if is_pending():
		lines.append(_t("你改变主意不想拜%s为师了。") % _t(_pending_master_name))
	lines.append(_t("你想要拜%s为师。") % npc)
	_pending_master_id = master.definition_id
	_pending_master_name = name
	var rule: NpcTeaching.ApprenticeRule = teaching.apprentice
	if (
		student.attributes.effective_courage() < rule.requires.get(&"cor", 0)
		or student.attributes.effective_composure() < rule.requires.get(&"cps", 0)
	):
		lines.append(_t("{npc}说道：{line}").format({"npc": npc, "line": NpcTalk.line(rule.refuse_say).replace("$RESPECT", _t(respect))}))
		return Outcome.QUALIFICATION_REJECTED
	lines.append(_t("{npc}说道：{line}").format({"npc": npc, "line": NpcTalk.line(rule.accept_say).replace("$RESPECT", _t(respect))}))
	# recruit.c: the student's pending/apprentice is this master.
	lines.append(_t("%s决定收你为弟子。") % npc)
	lines.append(_t("你跪了下来向%s恭恭敬敬地磕了四个响头，叫道：「师父！」") % npc)
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
	lines.append(_t("恭喜您成为{family}的第{generation}代弟子。").format({"family": _t(family.display_name), "generation": ChineseNumber.of(generation)}))
	return Outcome.RECRUITED


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
