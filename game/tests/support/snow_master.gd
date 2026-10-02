extends RefCounted

## 柳淳风 (daemon/class/swordsman/master.c, common.npc.swordsman.master) for tests
## that recruit and learn without walking to his body: his definition, family and
## a body state as he stands at full health (int 24, sen 170), through the same
## NpcTeacher/NpcApprenticeship code his TeacherService uses.
const MASTER_ID: StringName = &"common.npc.swordsman.master"
const FAMILY_ID: StringName = &"family.fonxan"
const SPIRIT: int = 170


static func definition() -> NpcDefinition:
	return GameContent.catalog().npc(MASTER_ID)


static func family() -> FamilyDefinition:
	return GameContent.catalog().family(FAMILY_ID)


## apprentice 柳淳风 with a fresh request (pending state starts empty).
static func recruit(state: CharacterState, entry_time_utc: int, request: NpcApprenticeship = null) -> NpcApprenticeship.Outcome:
	return (NpcApprenticeship.new() if request == null else request).request(state, definition(), family(), entry_time_utc, "壮士")


static func body() -> NpcRuntimeState:
	var state := CharacterState.new()
	state.attributes.intelligence = definition().base_attribute_overrides().intelligence()
	state.spirit = CharacterResourceState.new(SPIRIT, SPIRIT, SPIRIT)
	for skill: NpcSkillLevelDefinition in definition().skill_levels():
		state.skills.set_raw_level(skill.skill_id, skill.raw_level)
	return NpcRuntimeState.new(&"test.master", definition(), &"snow.outdoor.schoolhall.master", &"snow.schoolhall.master.1", state, CombatRelationshipState.new(&"test.master"), ActionBusyState.new(), ArmorState.new())


static func context(skill_id: StringName, random: WorldInteractionRandomSource = null) -> TeachingContext:
	return NpcTeacher.context(body(), skill_id, true, false, random)


static func skill(skill_id: StringName) -> SkillDefinition:
	return GameContent.catalog().skill(skill_id)


static func policy(skill_id: StringName) -> SkillLearnPolicy:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	return registry.policy_for(skill_id)
