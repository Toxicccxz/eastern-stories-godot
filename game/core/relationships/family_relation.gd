class_name FamilyRelation
extends RefCounted

## cmds/std/look.c: what a character of the viewer's own family is to the viewer,
## by generation, master and enter_time, as the word ES2 shows ("" when they are of
## different families, or one has none). An NPC's create_family() records neither a
## master nor an enter_time: its master_id is "" and its enter_time 0.

## The same generation, by [same master, senior]: 师兄 for a 男性, 师姐 for anyone else.
const SAME_GENERATION_MALE: Array[String] = ["师兄", "师弟", "同门师兄", "同门师弟"]
const SAME_GENERATION_OTHER: Array[String] = ["师姐", "师妹", "同门师姐", "同门师妹"]


## The viewer is a player character; the other is described by its family facts.
static func word(viewer: CharacterState, other_id: StringName, other_family: FamilyState, other_master_id: StringName, other_entry_time: int, other_gender: StringName) -> String:
	if viewer == null or other_family == null or not viewer.family.has_family() or viewer.family.family_id != other_family.family_id:
		return ""
	var mine: int = viewer.family.generation
	var theirs: int = other_family.generation
	var my_entry: int = _entry_time(viewer)
	if theirs == mine:
		var words: Array[String] = SAME_GENERATION_MALE if other_gender == CharacterState.GENDER_MALE else SAME_GENERATION_OTHER
		var index: int = (0 if viewer.apprenticeship.master_teacher_id == other_master_id else 2) + (0 if my_entry > other_entry_time else 1)
		return words[index]
	if theirs < mine:
		if viewer.apprenticeship.master_teacher_id == other_id:
			return "师父"
		if mine - theirs > 1:
			return "同门长辈"
		return "师伯" if other_entry_time < my_entry else "师叔"
	if theirs - mine > 1:
		return "同门晚辈"
	# fam["master_id"] == me->query("id"): no NPC is a player's apprentice.
	return "师侄"


## An NPC as look.c sees it: its family from create_family(), no master, no enter_time.
static func of_npc(viewer: CharacterState, npc: NpcDefinition, npc_gender: StringName) -> String:
	var teaching: NpcTeaching = null if npc == null else npc.teaching()
	if teaching == null or not teaching.has_family():
		return ""
	return word(viewer, npc.definition_id, FamilyState.new(teaching.family_id, teaching.family_generation), &"", 0, npc_gender)


## enter_time as saved; a relationship from before entry times were kept counts as 0.
static func _entry_time(viewer: CharacterState) -> int:
	if viewer.affiliation != null and viewer.affiliation.entry_time_status == CharacterAffiliationState.EntryTime.RECORDED:
		return viewer.affiliation.entry_time_utc
	return 0
