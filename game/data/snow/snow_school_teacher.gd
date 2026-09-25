class_name SnowSchoolTeacher
extends RefCounted

## daemon/class/swordsman/master.c. Teaching-only projection, NOT a full NPC.
const SOURCE_PATH: String = "daemon/class/swordsman/master.c"
const ALIASES: Array[String] = ["master swordsman", "swordsman", "master"]
const GENDER: StringName = &"男性"
const AGE: int = 44
const INTELLIGENCE: int = 24
## human.c/chard.c: age44 -> max_sen170; NPC teaching does not debit sen.
const SPIRIT: int = 170
const TEACHER_GENERATION: int = 13
const SKILLS: Dictionary[StringName, int] = {
	&"unarmed": 40, &"parry": 120, &"dodge": 80, &"sword": 150,
	&"force": 40, &"literate": 60, &"fonxanforce": 60, &"fonxansword": 150,
	&"liuh-ken": 60, &"chaos-steps": 100, &"spider-array": 85,
}


static func definition() -> TeacherDefinition:
	var offers: Array[TeachingOffer] = []
	for skill: StringName in SKILLS:
		offers.append(TeachingOffer.new(skill))
	return TeacherDefinition.new(SwordsmanApprenticeship.TEACHER_ID, offers, SOURCE_PATH, ALIASES[0], SwordsmanApprenticeship.MASTER_NAME)


static func unarmed_context() -> TeachingContext:
	return teaching_context(&"unarmed")


static func teaching_context(skill_id: StringName) -> TeachingContext:
	if skill_id not in [&"unarmed", LiuhKenDefinition.SKILL_ID]:
		return null
	var context := TeachingContext.new(
		SwordsmanApprenticeship.TEACHER_ID, TeachingOffer.new(skill_id),
		SKILLS[skill_id], INTELLIGENCE, SPIRIT,
		SwordsmanApprenticeship.FAMILY_ID, TEACHER_GENERATION, -1,
		SwordsmanApprenticeship.MASTER_NAME,
	)
	context.prevention_policy = FMasterTeacherPreventionPolicy.new()
	return context


static func unarmed_definition() -> SkillDefinition:
	return SkillDefinition.new(&"unarmed", SkillDefinition.Kind.BASIC, SkillDefinition.Type.MARTIAL, false, [], "daemon/skill/unarmed.c")


static func unarmed_policy() -> SkillLearnPolicy:
	return learn_policy(&"unarmed")


static func learn_policy(skill_id: StringName) -> SkillLearnPolicy:
	if skill_id not in [&"unarmed", LiuhKenDefinition.SKILL_ID]:
		return null
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	return registry.policy_for(skill_id)
