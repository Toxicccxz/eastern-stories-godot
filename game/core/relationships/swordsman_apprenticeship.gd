class_name SwordsmanApprenticeship
extends RefCounted

## Narrow player-initiated NPC chain from cmds/std/apprentice.c -> recruit.c ->
## feature/apprentice.c and daemon/class/swordsman/master.c. No reverse handshake.
const TEACHER_ID: StringName = &"teacher.liu_chunfeng"
const MASTER_NAME: String = "柳淳风"
const FAMILY_ID: StringName = &"family.fonxan"
const FAMILY_NAME: String = "封山剑派"
const GENERATION: int = 14
const DISPLAY_TITLE: String = "封山剑派第十四代弟子"
enum Outcome { RECRUITED, ACKNOWLEDGED, QUALIFICATION_REJECTED, PENDING, CANCELLED, NO_PENDING, OTHER_RELATIONSHIP_DEFERRED, AUTHORITY_FAILURE }

var _pending: bool = false


func is_pending() -> bool:
	return _pending


static func is_master_of(student: CharacterState) -> bool:
	return student.family.has_family() and student.apprenticeship.master_teacher_id == TEACHER_ID and student.apprenticeship.legacy_master_name == MASTER_NAME


func cancel() -> Outcome:
	if not _pending:
		return Outcome.NO_PENDING
	_pending = false
	return Outcome.CANCELLED


func request(student: CharacterState, entry_time_utc: int) -> Outcome:
	if student == null or entry_time_utc < 0:
		return Outcome.AUTHORITY_FAILURE
	if is_master_of(student):
		return Outcome.ACKNOWLEDGED
	if student.family.has_family() or student.apprenticeship.has_master():
		return Outcome.OTHER_RELATIONSHIP_DEFERRED
	if _pending:
		return Outcome.PENDING
	_pending = true
	if student.attributes.effective_courage() < 20 or student.attributes.effective_composure() < 20:
		return Outcome.QUALIFICATION_REJECTED
	student.family = FamilyState.new(FAMILY_ID, GENERATION)
	student.apprenticeship.master_teacher_id = TEACHER_ID
	student.apprenticeship.legacy_master_name = MASTER_NAME
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"swordsman"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.family_privileges = 0
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	affiliation.entry_time_utc = entry_time_utc
	student.affiliation = affiliation
	_pending = false
	return Outcome.RECRUITED
