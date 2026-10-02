class_name NpcTeacher
extends RefCounted

## An NPC as cmds/std/learn.c sees it: what it can teach and the TeachingContext
## of one request, from its definition (NpcTeaching) and its current state.
## Teachers are data: any NPC whose family or recognize_apprentice() admits a
## student teaches the skills it has that skills.json defines.


## The skills `definition` teaches, in its authored order.
static func teachable_skills(definition: NpcDefinition, catalog: ContentCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	if definition == null or catalog == null or definition.teaching() == null or not definition.teaching().can_teach():
		return result
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		if skill.raw_level > 0 and catalog.skill(skill.skill_id) != null:
			result.append(skill.skill_id)
	return result


## learn.c's facts about the teacher for one request: present and a character
## (`here`), living(), query("int"), query("sen"), its raw skill level and family.
## An NPC never pays sen (only userp(ob) does).
static func context(npc: NpcRuntimeState, skill_id: StringName, here: bool, student_fighting: bool, random: WorldInteractionRandomSource) -> TeachingContext:
	var teaching: NpcTeaching = npc.definition().teaching()
	var state: CharacterState = npc.character_state
	var result := TeachingContext.new(
		npc.definition().definition_id, TeachingOffer.new(skill_id),
		state.skills.raw_level(skill_id), state.attributes.intelligence, state.spirit.current,
		&"" if teaching == null else teaching.family_id,
		0 if teaching == null else teaching.family_generation,
		-1 if teaching != null and teaching.has_family() else 0,
		npc.definition().display_name,
		here and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD,
		true,
		npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE,
	)
	result.student_is_fighting = student_fighting
	result.recognition_policy = NpcRecognitionPolicy.new(teaching, random)
	if teaching != null and teaching.f_master:
		result.prevention_policy = FMasterTeacherPreventionPolicy.new()
	return result
