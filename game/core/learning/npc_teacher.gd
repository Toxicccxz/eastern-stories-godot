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


## What `definition` offers `student` (the 请教 list): every skill it teaches, or, to one outside its
## family it recognises by a rule for some skills only (DECISIONS「只教这几门」), those.
static func taught_to(definition: NpcDefinition, catalog: ContentCatalog, student: CharacterState) -> Array[StringName]:
	var skills: Array[StringName] = teachable_skills(definition, catalog)
	var teaching: NpcTeaching = null if definition == null else definition.teaching()
	if teaching == null or student == null or (not teaching.family_id.is_empty() and student.family.family_id == teaching.family_id):
		return skills
	var rule: NpcTeaching.RecognizeRule = teaching.recognize(student.family.family_id, student.marks)
	if rule == null or rule.skills.is_empty() or not rule.accept:
		return skills
	return skills.filter(func(skill_id: StringName) -> bool: return rule.skills.has(skill_id))


## learn.c's facts about the teacher for one request: present and a character
## (`here`), living(), query("int"), query("sen"), its raw skill level and family
## (with its privs: only -1 teaches every member).
## An NPC never pays sen (only userp(ob) does).
static func context(npc: NpcRuntimeState, skill_id: StringName, here: bool, student_fighting: bool, random: WorldInteractionRandomSource, worn_armor_types: Array[StringName] = []) -> TeachingContext:
	var teaching: NpcTeaching = npc.definition().teaching()
	var state: CharacterState = npc.character_state
	var result := TeachingContext.new(
		npc.definition().definition_id, TeachingOffer.new(skill_id),
		state.skills.raw_level(skill_id), state.attributes.intelligence, state.spirit.current,
		&"" if teaching == null else teaching.family_id,
		0 if teaching == null else teaching.family_generation,
		teaching.family_privileges if teaching != null and teaching.has_family() else 0,
		npc.definition().display_name,
		here and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD,
		true,
		npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE,
	)
	result.student_is_fighting = student_fighting
	result.worn_armor_types = worn_armor_types
	result.recognition_policy = NpcRecognitionPolicy.new(teaching, random)
	if teaching != null and teaching.f_master:
		result.prevention_policy = FMasterTeacherPreventionPolicy.new()
	return result
