class_name TeacherService
extends WorldService

## A master who takes apprentices and teaches (daemon/class/swordsman/master.c,
## 柳淳风). No NPC spawn slot, death or AI yet; the teaching facts are still
## SnowSchoolTeacher / LiuhKenDefinition until skills and teachers are data.
var ui: TeacherPanel
var last_learn: LearnResult


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	ui = TeacherPanel.new()
	ui.name = "TeachingUI"
	ui.configure(self)
	add_child(ui)


func verb() -> String:
	return tr("交谈")


func requires_idle() -> bool:
	return true


func interact() -> void:
	ui.interact()


func can_teach() -> bool:
	return in_reach()


func request_apprentice() -> SwordsmanApprenticeship.Outcome:
	if not can_teach():
		return SwordsmanApprenticeship.Outcome.AUTHORITY_FAILURE
	return map.player_runtime().request_school_apprenticeship(int(Time.get_unix_time_from_system()))


func cancel_apprentice() -> SwordsmanApprenticeship.Outcome:
	if not can_teach():
		return SwordsmanApprenticeship.Outcome.AUTHORITY_FAILURE
	return map.player_runtime().school_apprenticeship.cancel()


func request_learn(skill_id: StringName = &"unarmed") -> LearnResult:
	if skill_id not in [&"unarmed", LiuhKenDefinition.SKILL_ID] or not can_teach() or map.world_interaction_random_source() == null:
		last_learn = LearnResult.new(skill_id)
		last_learn.failure_reason = LearnResult.FailureReason.TEACHER_UNAVAILABLE
		return last_learn
	# Fresh facts on every request. No quote or panel state authorizes mutation.
	var definition: SkillDefinition = SnowSchoolTeacher.unarmed_definition() if skill_id == &"unarmed" else LiuhKenDefinition.skill()
	last_learn = LearnService.learn(map.player_runtime().state, SnowSchoolTeacher.teaching_context(skill_id), definition, SnowSchoolTeacher.learn_policy(skill_id), null, map.world_interaction_random_source())
	return last_learn


func enable_liuh() -> bool:
	if not can_teach():
		return false
	return SkillEnableTransition.try_enable(map.player_runtime().state.skills,
		LiuhKenDefinition.skill(), &"unarmed").applied


func disable_liuh() -> bool:
	if not can_teach():
		return false
	# Source enable none: no raw/learned/resource changes. Combat sources are
	# projected afresh for every opportunity; there is no cached next action.
	map.player_runtime().state.skills.unmap_skill(&"unarmed")
	return true
