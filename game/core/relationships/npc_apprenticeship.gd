class_name NpcApprenticeship
extends RefCounted

## The player's side of cmds/std/apprentice.c with an NPC master: the request is
## pending (pending/apprentice) and the master's attempt_apprentice() rule
## (NpcTeaching.ApprenticeRule) answers: one of `requirements` recruits at once; one of
## `oath` asks for an oath (swear()), one of `trial` for its test (TeacherService runs
## the blows, NpcApprenticeTrial). The master recruits through cmds/std/recruit.c
## (npc_recruit()): a student whose request waits on it is taken at once; any other is
## offered (pending/recruit on the master), and their next 拜师 takes them (apprentice.c's
## first branch). feature/apprentice.c recruit_apprentice(): a member of another family
## betrays it (score 0, betrayer + 1); the new family, master, title and class (unless
## the master gives none) replace the old ones. Requests, oaths and offers are
## transient, as query_temp() values.
enum Outcome { RECRUITED, ACKNOWLEDGED, QUALIFICATION_REJECTED, PENDING, CANCELLED, NO_PENDING, AUTHORITY_FAILURE, ASKED, OFFERED, NOT_ASKED }

var _pending_master_id: StringName = &""
var _pending_master_name: String = ""
## Masters whose oath the player has been asked for (pending/celestial_swear).
var _oaths: Dictionary[StringName, bool] = {}
## Masters who want to take the player (their pending/recruit).
var _offers: Dictionary[StringName, bool] = {}
## What the last request, oath, recruit or cancel printed, in order, as the player reads it.
var lines: Array[String] = []


func is_pending() -> bool:
	return not _pending_master_id.is_empty()


## The request waits on this master: asking again only hears 对方还没有答应 (apprentice.c).
func is_pending_with(master_id: StringName) -> bool:
	return _pending_master_id == master_id


## The master has asked for the player's oath and it has not been sworn.
func awaits_oath(master_id: StringName) -> bool:
	return _oaths.has(master_id)


## The master wants to take the player: their next 拜师 makes them its apprentice.
func is_offered(master_id: StringName) -> bool:
	return _offers.has(master_id)

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


## recruit.c's betrayal branch: `master` taking `student` now would make them leave
## another family (score 0, betrayer + 1). The panel asks first (owner, DECISIONS 3B).
static func would_betray(student: CharacterState, master: NpcDefinition) -> bool:
	var teaching: NpcTeaching = null if master == null else master.teaching()
	return (
		student != null and teaching != null and teaching.apprentice != null
		and student.family.has_family() and student.family.family_id != teaching.family_id
		and not is_master_of(student, master)
	)


## `master` taking `student`, who has no family yet, would be their first master.
## Changing family later is a betrayal, so the panel asks first (owner, 2026-10-06).
static func would_join_first(student: CharacterState, master: NpcDefinition) -> bool:
	var teaching: NpcTeaching = null if master == null else master.teaching()
	return student != null and teaching != null and teaching.apprentice != null and not student.family.has_family()


## The master's attempt_apprentice() requirements (cor, cps) hold for `student`.
static func qualifies(student: CharacterState, rule: NpcTeaching.ApprenticeRule) -> bool:
	return (
		student.attributes.effective_courage() >= rule.requires.get(&"cor", 0)
		and student.attributes.effective_composure() >= rule.requires.get(&"cps", 0)
	)


## 拜师 with `master` now takes `student` at once: the master has offered, or its
## requirements hold and no request already waits on it (that only hears 对方还没有答应).
func takes_at_once(student: CharacterState, master: NpcDefinition) -> bool:
	var teaching: NpcTeaching = null if master == null else master.teaching()
	if student == null or teaching == null or teaching.apprentice == null or is_master_of(student, master):
		return false
	if is_offered(master.definition_id):
		return true
	return (
		teaching.apprentice.kind == NpcTeaching.Kind.REQUIREMENTS and qualifies(student, teaching.apprentice)
		and not is_pending_with(master.definition_id)
	)


## The master's own recruit (after the oath or the test) takes `student` at once, not
## as an offer: their request waits on it.
func recruit_takes_at_once(student: CharacterState, master: NpcDefinition) -> bool:
	return master != null and not is_master_of(student, master) and is_pending_with(master.definition_id)


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
	if is_offered(master.definition_id):
		# apprentice.c: the master is willing already, so it is done.
		_recruit(student, master, family, entry_time_utc, true)
		return Outcome.RECRUITED
	if _pending_master_id == master.definition_id:
		lines.append(_t("你想拜%s为师，但是对方还没有答应。") % npc)
		return Outcome.PENDING
	if is_pending():
		lines.append(_t("你改变主意不想拜%s为师了。") % _t(_pending_master_name))
	lines.append(_t("你想要拜%s为师。") % npc)
	_pending_master_id = master.definition_id
	_pending_master_name = name
	var rule: NpcTeaching.ApprenticeRule = teaching.apprentice
	if rule.kind == NpcTeaching.Kind.OATH:
		# master.c attempt_apprentice(): asked once; asked again, it will not hear more.
		if awaits_oath(master.definition_id):
			_say(npc, rule.again_say, respect)
		else:
			_say(npc, rule.ask_say, respect)
			_oaths[master.definition_id] = true
		return Outcome.ASKED
	if rule.kind == NpcTeaching.Kind.TRIAL:
		# champion.c attempt_apprentice(): say() to the room (the player reads it too,
		# owner: DECISIONS 水烟阁 B), then tell_object() to the student.
		_say(npc, rule.ask_say, respect)
		lines.append(_t(rule.ask_tell))
		return Outcome.ASKED
	if not qualifies(student, rule):
		_say(npc, rule.refuse_say, respect)
		return Outcome.QUALIFICATION_REJECTED
	_say(npc, rule.accept_say, respect)
	# recruit.c: the student's pending/apprentice is this master.
	_recruit(student, master, family, entry_time_utc, false)
	return Outcome.RECRUITED


## swear <oath> to a master that asked for one (master.c do_swear()): the oath ES2
## accepts, said by the player's fixed button (owner); the master then recruits.
## NOT_ASKED (and nothing printed) when no oath was asked: the command does not exist.
func swear(student: CharacterState, master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int, respect: String) -> Outcome:
	lines = []
	var teaching: NpcTeaching = null if master == null else master.teaching()
	if student == null or teaching == null or teaching.apprentice == null or teaching.apprentice.kind != NpcTeaching.Kind.OATH or family == null or entry_time_utc < 0:
		return Outcome.AUTHORITY_FAILURE
	if not awaits_oath(master.definition_id):
		return Outcome.NOT_ASKED
	_oaths.erase(master.definition_id)
	# TRANSLATORS: master.c do_swear(): message_vision("$N发誓道：" + arg): {oath} is the oath (守门规).
	lines.append(_t("你发誓道：{oath}").format({"oath": _t(teaching.apprentice.oath)}))
	_say(_t(master.display_name), teaching.apprentice.accept_say, respect)
	return _npc_recruit(student, master, family, entry_time_utc)


## command("recruit <student>") by the master (after its trial): recruit.c from its side.
func npc_recruit(student: CharacterState, master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int) -> Outcome:
	lines = []
	var teaching: NpcTeaching = null if master == null else master.teaching()
	if student == null or teaching == null or teaching.apprentice == null or family == null or entry_time_utc < 0:
		return Outcome.AUTHORITY_FAILURE
	return _npc_recruit(student, master, family, entry_time_utc)


func _npc_recruit(student: CharacterState, master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int) -> Outcome:
	var npc: String = _t(master.display_name)
	if is_master_of(student, master):
		lines.append(_t("%s拍拍你的头，说道：「好徒儿！」") % npc)
		return Outcome.ACKNOWLEDGED
	if is_pending_with(master.definition_id):
		_recruit(student, master, family, entry_time_utc, false)
		return Outcome.RECRUITED
	_offers[master.definition_id] = true
	lines.append(_t("%s想要收你为弟子。") % npc)
	# TRANSLATORS: recruit.c tells the student how to accept: ES2 names its apprentice command; here the 拜师 button.
	lines.append(_t("如果你愿意拜%s为师父，就向他拜师。") % npc)
	return Outcome.OFFERED


## recruit_apprentice() with recruit.c's lines (`offered`: apprentice.c's first branch,
## the student's own words). A finished 拜师 ends any other request too.
func _recruit(student: CharacterState, master: NpcDefinition, family: FamilyDefinition, entry_time_utc: int, offered: bool) -> void:
	var teaching: NpcTeaching = master.teaching()
	var name: String = master.display_name
	var npc: String = _t(name)
	# Its family is compared by name, as families.json keeps one ID per name.
	if student.family.has_family() and student.family.family_id != family.family_id:
		lines.append(_t("你决定背叛师门，改投入%s门下！！") % npc)
		lines.append(_t("你跪了下来向%s恭恭敬敬地磕了四个响头，叫道：「师父！」") % npc)
		student.progression.score = 0
		student.apprenticeship.betrayer_count += 1
	else:
		lines.append((_t("你决定拜%s为师。") if offered else _t("%s决定收你为弟子。")) % npc)
		lines.append(_t("你跪了下来向%s恭恭敬敬地磕了四个响头，叫道：「师父！」") % npc)
	var generation: int = teaching.family_generation + 1
	var class_id: StringName = student.affiliation.class_id
	student.family = FamilyState.new(family.family_id, generation)
	student.apprenticeship.master_teacher_id = master.definition_id
	student.apprenticeship.legacy_master_name = name
	var affiliation := CharacterAffiliationState.new()
	# daemon/class/fighter's masters inherit recruit_apprentice() as it is: no class.
	affiliation.class_id = teaching.apprentice.class_id if not teaching.apprentice.class_id.is_empty() else class_id
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.family_privileges = 0
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	affiliation.entry_time_utc = entry_time_utc
	student.affiliation = affiliation
	_pending_master_id = &""
	_pending_master_name = ""
	_offers.erase(master.definition_id)
	lines.append(_t("恭喜您成为{family}的第{generation}代弟子。").format({"family": _t(family.display_name), "generation": ChineseNumber.of(generation)}))


## command("say ...") by the master: 「{npc}说道：{line}」 with $RESPECT filled in.
func _say(npc: String, line: String, respect: String) -> void:
	lines.append(_t("{npc}说道：{line}").format({"npc": npc, "line": NpcTalk.line(line).replace("$RESPECT", _t(respect))}))


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
