class_name TeacherService
extends NpcService

## cmds/std/learn.c and apprentice.c with an NPC that teaches: whoever its family
## or recognize_apprentice() admits learns the skills it has that skills.json
## defines (NpcTeacher); a master with an attempt_apprentice() rule takes
## apprentices (NpcApprenticeship). Its lines go to the log; the panel shows the
## student's skills and the last lines.
var ui: TeacherPanel
var last_learn: LearnResult
var last_lines: Array[String] = []


func bind_npc(p_map: WorldMapController, p_npc: NpcRuntimeState) -> void:
	super.bind_npc(p_map, p_npc)
	ui = TeacherPanel.new()
	ui.name = "TeachingUI"
	ui.configure(self)
	add_child(ui)


func verb() -> String:
	return tr("请教")


func requires_idle() -> bool:
	return true


func interact() -> void:
	ui.interact()


func can_teach() -> bool:
	return in_reach()


func teaching() -> NpcTeaching:
	return npc.definition().teaching()


func teachable_skills() -> Array[StringName]:
	return NpcTeacher.teachable_skills(npc.definition(), GameContent.catalog())


func takes_apprentices() -> bool:
	return teaching() != null and teaching().apprentice != null


## apprentice <npc>; living(ob) first ("你必须先把…弄醒。").
func request_apprentice() -> NpcApprenticeship.Outcome:
	last_lines = []
	if not can_teach() or not takes_apprentices():
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		_say([tr("你必须先把%s弄醒。") % tr(display_name())])
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var outcome: NpcApprenticeship.Outcome = player.request_apprenticeship(
		npc.definition(), GameContent.catalog().family(teaching().family_id), int(Time.get_unix_time_from_system()),
	)
	_say(player.apprenticeship_request.lines)
	return outcome


func cancel_apprentice() -> NpcApprenticeship.Outcome:
	last_lines = []
	if not can_teach():
		return NpcApprenticeship.Outcome.AUTHORITY_FAILURE
	var request: NpcApprenticeship = map.player_runtime().apprenticeship_request
	var outcome: NpcApprenticeship.Outcome = request.cancel()
	_say(request.lines)
	return outcome


## learn <skill> from <npc>, with fresh facts on every request.
func request_learn(skill_id: StringName) -> LearnResult:
	last_lines = []
	var catalog: ContentCatalog = GameContent.catalog()
	var random: WorldInteractionRandomSource = map.world_interaction_random_source()
	if not teachable_skills().has(skill_id) or not can_teach() or random == null:
		last_learn = LearnResult.new(skill_id)
		last_learn.failure_reason = LearnResult.FailureReason.TEACHER_UNAVAILABLE
		return last_learn
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, player.relationship.is_fighting(), random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = catalog.skill(skill_id)
	last_learn = LearnService.learn(player.state, context, skill, registry.policy_for(skill_id), map.encounter_skill_effect_registry(), random)
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	_say(LearnLines.lines(last_learn, display_name(), skill.display_name, player.state, context, respect))
	return last_learn


## enable <use> <skill> for a specialized skill this teacher teaches.
func enable(skill_id: StringName) -> bool:
	var skill: SkillDefinition = GameContent.catalog().skill(skill_id)
	if not can_teach() or skill == null or skill.valid_enabled_uses().is_empty():
		return false
	return SkillEnableTransition.try_enable(map.player_runtime().state.skills, skill, skill.valid_enabled_uses()[0]).applied


func disable(skill_id: StringName) -> bool:
	var skill: SkillDefinition = GameContent.catalog().skill(skill_id)
	if not can_teach() or skill == null or skill.valid_enabled_uses().is_empty():
		return false
	var use_id: StringName = skill.valid_enabled_uses()[0]
	if map.player_runtime().state.skills.mapped_skill(use_id) != skill_id:
		return false
	# Source enable none: no raw/learned/resource changes. Combat sources are
	# projected afresh for every opportunity; there is no cached next action.
	map.player_runtime().state.skills.unmap_skill(use_id)
	return true


func _say(lines: Array[String]) -> void:
	last_lines.assign(lines)
	if map.session != null and not lines.is_empty():
		map.session.shared_ui().append_log_lines(lines)
