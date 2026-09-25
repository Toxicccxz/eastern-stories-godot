extends RefCounted

const First := preload("res://tests/runtime/snow_first_progression_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const LearnDraws := preload("res://tests/support/scripted_world_interaction_random_source.gd")
const Draws := preload("res://tests/support/scripted_combat_random_source.gd")
var assertions: int = 0
var failures: Array[String] = []

class HighDraws extends CombatRandomSource:
	var bounds: Array[int] = []
	func next_below(bound: int) -> int:
		bounds.append(bound)
		return bound - 1


func run_all(tree: SceneTree) -> Dictionary:
	definition_and_learn()
	mapping_and_equipment()
	action_execution()
	reverse_execution()
	await persistence_and_panel(tree)
	await terminal_feedback(tree)
	print("SMP2 focused: %d assertions; %d failures" % [assertions, failures.size()])
	return {"assertions": assertions, "failures": failures}


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("SMP2: " + label)


static func learn(state: CharacterState, rng: WorldInteractionRandomSource, context: TeachingContext = null) -> LearnResult:
	return LearnService.learn(state, context if context != null else SnowSchoolTeacher.teaching_context(&"liuh-ken"), LiuhKenDefinition.skill(), SnowSchoolTeacher.learn_policy(&"liuh-ken"), null, rng)


func definition_and_learn() -> void:
	var definition := LiuhKenDefinition.skill()
	check(definition.skill_id == &"liuh-ken" and definition.skill_type == SkillDefinition.Type.MARTIAL and definition.kind == SkillDefinition.Kind.SPECIALIZED, "exact specialized martial identity")
	check(definition.can_enable_for(&"unarmed"), "unarmed enabled use")
	for use_id: StringName in [&"sword", &"parry", &"dodge", &"force", &"magic", &"spells"]:
		check(not definition.can_enable_for(use_id), "invalid use " + String(use_id))
	check(SnowSchoolTeacher.teaching_context(&"liuh-ken").teacher_raw_level == 60 and SnowSchoolTeacher.teaching_context(&"unarmed").teacher_raw_level == 40, "two exact teacher levels")
	check(SnowSchoolTeacher.teaching_context(&"sword") == null and SnowSchoolTeacher.learn_policy(&"sword") == null, "other teacher knowledge not a new working surface")
	var thresholds: Array[int] = [0,0,0,2,6,12,21,34,51,72,100]
	for raw: int in range(thresholds.size()):
		for offset: int in [-1,0,1]:
			var experience: int = thresholds[raw] + offset
			if experience < 0:
				continue
			var state := First.disciple()
			state.skills.set_raw_level(&"liuh-ken", raw)
			state.progression.combat_experience = experience
			var rng := LearnDraws.new([0])
			var result := learn(state, rng)
			var allowed: bool = offset >= 0
			check(result.required_combat_experience == thresholds[raw], "threshold " + str(raw))
			check(rng.call_count() == (1 if allowed else 0) and state.progression.potential_spent == (1 if allowed else 0), "boundary draw/spent " + str([raw,experience]))
			check(result.calculated_essence_cost == (22 if raw == 0 else 11) and state.essence.current == (78 if raw == 0 else 89), "source cost even EXP refusal")
			check(not allowed or rng.requested_bounds() == [30], "Learn uses exact WorldInteraction bound")
	for row: Array in [[0,22,false],[0,23,true],[1,11,false],[1,12,true]]:
		var state := First.disciple()
		state.skills.set_raw_level(&"liuh-ken", row[0])
		state.essence.current = row[1]
		var rng := LearnDraws.new([0])
		learn(state,rng)
		check(rng.call_count() == (1 if row[2] else 0) and state.essence.current == (1 if row[2] else 0), "strict gin " + str(row))
	for raw: int in [0,1]:
		for delta: int in [0,1]:
			var state := First.disciple()
			state.skills.set_raw_level(&"liuh-ken", raw)
			var context := SnowSchoolTeacher.teaching_context(&"liuh-ken")
			context.current_spirit = (5 if raw == 0 else 3) + delta
			var initial: int = context.current_spirit
			var rng := LearnDraws.new([0])
			learn(state,rng,context)
			check(rng.call_count() == delta and context.current_spirit == initial, "strict NPC sen, no debit")
	for gate: String in ["potential", "no_teach", "bad_random"]:
		var state := First.disciple()
		var context := SnowSchoolTeacher.teaching_context(&"liuh-ken")
		if gate == "potential": state.progression.potential_spent = 99
		if gate == "no_teach": context.teaching_temporarily_disabled = true
		var rng := LearnDraws.new([30])
		var result := learn(state,rng,context)
		check(result.created_explicit_zero_skill_entry and state.skills.has_raw_level(&"liuh-ken") and state.skills.raw_level(&"liuh-ken") == 0, "explicit zero survives " + gate)
		check(state.essence.current == 100 and rng.call_count() == (1 if gate == "bad_random" else 0), "ordered late failure " + gate)
		check(gate != "bad_random" or state.progression.potential_spent == 1, "spent before bad draw")
	for gate: String in ["ceiling", "betrayal", "no_relation"]:
		var state := First.disciple() if gate != "no_relation" else First.fresh()
		if gate == "ceiling": state.skills.set_raw_level(&"liuh-ken",60)
		if gate == "betrayal":
			state.apprenticeship.betrayer_count = 3
		var rng := LearnDraws.new([0])
		var result := learn(state,rng)
		check(not result.success and rng.call_count() == 0 and state.essence.current == 100, "teacher rejects " + gate)


static func ready_state() -> CharacterState:
	var state := First.disciple()
	state.skills.set_raw_level(&"unarmed",4)
	state.skills.set_raw_level(&"liuh-ken",5)
	state.skills.set_learned_progress(&"liuh-ken",7)
	state.progression.combat_experience = 6
	SkillEnableTransition.try_enable(state.skills,LiuhKenDefinition.skill(),&"unarmed")
	return state


static func binding(id: StringName, state: CharacterState = null, user: bool = true) -> CombatSliceCharacterBinding:
	return CombatSliceCharacterBinding.new(id, ready_state() if state == null else state,
		CombatRelationshipState.new(id),ActionBusyState.new(),ArmorState.new(),CombatSliceContentProfile.new(),&"test",true,CombatSliceLifeStatus.Value.ACTIVE,user)


static func sword(id: StringName = &"smp2.sword") -> EquippedWeaponRef:
	return EquippedWeaponRef.new(id,WeaponDefinition.new(CombatSliceContentProfile.LONG_SWORD_ID,&"sword",true))


func mapping_and_equipment() -> void:
	for base: int in [0,1]:
		for special: int in [0,1]:
			var state := First.disciple()
			state.skills.set_raw_level(&"unarmed",base)
			state.skills.set_raw_level(&"liuh-ken",special)
			var result := SkillEnableTransition.try_enable(state.skills,LiuhKenDefinition.skill(),&"unarmed")
			check(result.applied == (base != 0 and special != 0) and result.internal_resource_reset == SkillMappingChangeResult.InternalResourceReset.NONE, "Enable raw gate / no reset")
	var state := ready_state()
	check(state.skills.effective_level(&"unarmed") == 7 and state.skills.effective_level(&"unarmed",3) == 10, "authoritative effective formula")
	state.skills.unmap_skill(&"unarmed")
	check(state.skills.effective_level(&"unarmed") == 2 and state.skills.learned_progress(&"liuh-ken") == 7 and state.skills.raw_level(&"liuh-ken") == 5, "disable retains skill/progress")
	for mode: String in ["empty", "primary", "secondary", "both"]:
		state = ready_state()
		state.equipment._restore_weapons(sword() if mode in ["primary","both"] else null,sword(&"smp2.second") if mode in ["secondary","both"] else null)
		var rng := LearnDraws.new([0])
		var result := learn(state,rng)
		check((result.failure_reason == LearnResult.FailureReason.SKILL_LEARN_REJECTED) == (mode != "empty"), "both refs Learn gate " + mode)
		check(SkillEnableTransition.try_enable(state.skills,LiuhKenDefinition.skill(),&"unarmed").applied, "Enable has no weapon predicate " + mode)
		var actor := binding(&"actor",state)
		var selected := CombatSliceProjectionBuilder.build_action_selection_input(actor)
		check(selected.mapped_skill_present == (mode in ["empty","secondary"]), "primary-only combat source " + mode)
		check(state.skills.mapped_skill(&"unarmed") == &"liuh-ken", "weapon retains mapping")
		if mode == "primary":
			state.equipment.unwield(&"smp2.sword")
			check(CombatSliceProjectionBuilder.build_action_selection_input(actor).mapped_action_set().size() == 4, "unwield restores mapped source")


static func execute(actor: CombatSliceCharacterBinding, target: CombatSliceCharacterBinding, rng: CombatRandomSource, regular: bool = false, live: CombatReverseAttackProjection = null) -> CombatSingleAttackExecutionResult:
	if not regular: target.busy.start_busy(1)
	var fight := CombatFightDecisionService.decide(CombatSliceProjectionBuilder.build_fight_facts(actor,target),actor.relationship,target.relationship,Draws.new([0]))
	var projection := CombatSliceProjectionBuilder.build_live_projection(actor,target) if live == null else live
	return CombatSingleAttackExecutionService.execute(fight,projection.action_selection_input(),projection.attack_input_template(),actor.state,target.state,
		CombatRawComposureAuthority.new(actor.character_id,actor.state.attributes),projection.attacker_facts(),projection.defender_facts(),projection.defender_busy_projection(),projection.defender_busy_state(),actor.relationship,target.relationship,rng,null,projection.modifier_projection())


func action_execution() -> void:
	var expected: Array[String] = ["$N使一招「古松挂月」，对准$n的$l「呼」地一拳","$N扬起拳头，一招「傲雪冬梅」便往$n的$l招呼过去","$N左手虚晃，右拳「孤崖听涛」往$n的$l击出","$N步履一沉，左拳拉开，右拳使出「荒山虎吟」击向$n$l"]
	var actions := LiuhKenDefinition.actions()
	check(actions.is_valid() and actions.size() == 4,"four valid actions")
	for index: int in range(4):
		var action := actions.action_at(index)
		check(action.legacy_action_text == expected[index] and action.damage_percent == 0 and action.force_percent == 0 and action.damage_type == &"瘀伤" and action.post_action_policy_id.is_empty(),"exact action " + str(index))
		var actor := binding(&"actor")
		var target := binding(&"target")
		var rng := Draws.new([index,0,0])
		var result := execute(actor,target,rng)
		check(result.outcome == CombatSingleAttackExecutionResult.Outcome.COMPLETED_WITHOUT_RIPOSTE,"forward completes " + str(index))
		check(result.selected_action_id == action.action_id and result.ordinary_attack_result.base_result.action_id == action.action_id,"selected action actually resolved " + str(index))
		check(rng.requested_bounds() == [4,16,107],"one action draw, then limb and source dodge math " + str(rng.requested_bounds()))
		check(result.ordinary_attack_result.base_result.calculation.attack_power == 106,"no action dodge/parry bonuses")
		var before: int = rng.call_count()
		var text: String = BattleFeedbackReader._attack(result.ordinary_attack_result,"学徒","对手")
		check(text.contains(expected[index].replace("$N","学徒").replace("$n","对手").replace("$l","头部")) and text.contains("dodges") and not text.contains("$"),"full committed feedback")
		check(rng.call_count() == before,"presentation zero draws")
	var actor := binding(&"actor")
	var target := binding(&"target")
	var rng := Draws.new([4])
	var result := execute(actor,target,rng)
	check(result.outcome == CombatSingleAttackExecutionResult.Outcome.ACTION_SELECTION_FAILED and rng.call_count() == 1,"invalid action draw never rerolls")
	for field: String in ["exp","spirit","mapping","weapon","modifier","busy"]:
		actor = binding(&"actor"); target = binding(&"target")
		target.busy.start_busy(1)
		var live := CombatSliceProjectionBuilder.build_live_projection(actor,target)
		match field:
			"exp": actor.state.progression.combat_experience += 1
			"spirit": actor.state.spirit.current -= 1
			"mapping": actor.state.skills.unmap_skill(&"unarmed")
			"weapon": actor.state.equipment.wield(sword(),false)
			"modifier": actor.state.attributes.strength_modifier += 1
			"busy": target.busy.advance()
		rng = Draws.new([0])
		result = execute(actor,target,rng,true,live)
		check(result.outcome == CombatSingleAttackExecutionResult.Outcome.CALLER_AUTHORITY_MISMATCH and rng.call_count() == 0,"stale live authority before selection " + field)
	# Tampered source payload/order must fail before selection, not be accepted
	# merely because an ID matches or because all actions are numerically equal.
	actor = binding(&"actor"); target = binding(&"target")
	target.busy.start_busy(1)
	var approved_live := CombatSliceProjectionBuilder.build_live_projection(actor,target)
	var original_input := approved_live.attack_input_template()
	var tampered: Array[CombatActionDefinition] = actions.actions()
	tampered[2] = CombatActionDefinition.new(actions.action_at(2).action_id,99,0,&"瘀伤")
	var changed_source := CombatActionSelectionInput.new(true,CombatActionSet.new(tampered),false,null,actor.content.unarmed_action_set())
	var bad_live := CombatReverseAttackProjection.new(approved_live.attacker_authority(),approved_live.defender_authority(),changed_source,original_input,approved_live.attacker_facts(),approved_live.defender_facts(),approved_live.defender_busy_projection(),approved_live.defender_busy_state(),actor.relationship,target.relationship,approved_live.modifier_projection())
	rng = Draws.new([2])
	result = execute(actor,target,rng,false,bad_live)
	check(result.outcome == CombatSingleAttackExecutionResult.Outcome.CALLER_AUTHORITY_MISMATCH and rng.call_count() == 0,"altered approved source refused before RNG")
	check(not original_input.accepts_action(tampered[2]),"selected payload membership validates every field")
	var copy := original_input.approved_actions()
	copy._actions.clear()
	check(original_input.approved_actions().size() == 4,"approved set defensive snapshot")
	for armed: bool in [false,true]:
		actor = binding(&"actor"); target = binding(&"target")
		actor.state.skills.unmap_skill(&"unarmed")
		if armed: actor.state.equipment.wield(sword(),false)
		rng = Draws.new([0,0,0])
		result = execute(actor,target,rng)
		check(result.outcome == CombatSingleAttackExecutionResult.Outcome.COMPLETED_WITHOUT_RIPOSTE and rng.requested_bounds()[0] == 1,"existing singleton draw preserved")
		check(result.selected_action_id == (CombatSliceContentProfile.SLASH_ACTION_ID if armed else CombatSliceContentProfile.UNARMED_ACTION_ID),"existing weapon/default selection retained")
	actor = binding(&"actor"); target = binding(&"target")
	actor.state.skills.set_raw_level(&"unknown-style",5)
	actor.state.skills.map_skill(&"unarmed",&"unknown-style")
	rng = Draws.new([0])
	result = execute(actor,target,rng)
	check(result.outcome == CombatSingleAttackExecutionResult.Outcome.ACTION_SELECTION_FAILED and rng.call_count() == 0,"unknown mapped source remains unavailable")
	var input := CombatSliceProjectionBuilder.build_attack_input(actor,target,actor.content.unarmed_action())
	check(input.attacker.mapped_attack_skill_id == &"unknown-style" and input.attacker.martial_hit_policy_status == CombatHitPolicyStatus.Value.AUTHORED_POLICY_UNAVAILABLE,"unknown hit policy closed")
	# Real resolver/completion with deterministic high draws, not a fabricated award.
	actor = binding(&"actor"); target = binding(&"target",ready_state(),false)
	target.state.progression.combat_experience = 600
	var high := HighDraws.new()
	result = execute(actor,target,high,true)
	check(result.ordinary_attack_result.base_result.outcome == CombatAttackResult.Outcome.HIT,"known liuh hit policy reaches real hit")
	check(actor.state.skills.learned_progress(&"unarmed") > 0 and actor.state.skills.learned_progress(&"liuh-ken") == 7 and actor.state.skills.raw_level(&"liuh-ken") == 5,"combat improves basic only")
	check(actor.state.progression.combat_experience == 7,"existing source hit EXP award")


func reverse_execution() -> void:
	for branch: int in [0,1]:
		var actor := binding(&"actor")
		var target := binding(&"target")
		target.relationship.set_guarding(true)
		# Forward regular dodge, guard clear, then source quick/riposte choice.
		var rng := Draws.new([1,0,0,0 if branch == 0 else 5])
		var forward := execute(actor,target,rng,true)
		check(forward.has_riposte_request,"real reverse request")
		if not forward.has_riposte_request: continue
		var projection := CombatSliceProjectionBuilder.build_reverse_projection(target,actor,forward.riposte_request)
		var reverse_rng := Draws.new([3,0,0])
		var chain := CombatAttackChainCompletionService.complete(forward,projection,reverse_rng)
		check(chain.outcome == CombatAttackChainResult.Outcome.REVERSE_COMPLETE,"reverse completes " + str(branch))
		check(chain.reverse_selected_action_id == LiuhKenDefinition.ACTION_IDS[3] and forward.selected_action_id == LiuhKenDefinition.ACTION_IDS[1],"reverse independently selects")
		check(reverse_rng.requested_bounds() == [4,16,109],"reverse one own action draw")
		check(chain.reverse_attack_type == (CombatAttackType.Value.QUICK if branch == 0 else CombatAttackType.Value.RIPOSTE),"source reverse branch")
		# A mapping change after the forward must be reprojected, never reuse forward.
		target.state.skills.unmap_skill(&"unarmed")
		var stale_rng := Draws.new([0])
		var stale := CombatAttackChainCompletionService.complete(forward,projection,stale_rng)
		check(stale.outcome == CombatAttackChainResult.Outcome.REVERSE_CONTEXT_INVALID and stale_rng.call_count() == 0,"stale reverse mapping rejects before draw")
		projection = CombatSliceProjectionBuilder.build_reverse_projection(target,actor,forward.riposte_request)
		check(not projection.action_selection_input().mapped_skill_present,"fresh reverse reads changed mapping")


func persistence_and_panel(tree: SceneTree) -> void:
	var session := Work.create_session(tree)
	session.set_process(false)
	var player := session.player_runtime()
	player.request_school_apprenticeship(1789420000)
	player.state.skills.set_raw_level(&"unarmed",4)
	player.state.skills.set_raw_level(&"liuh-ken",5)
	player.state.skills.set_learned_progress(&"liuh-ken",7)
	player.state.progression.combat_experience = 6
	player.state.progression.potential_spent = 9
	for i: int in range(5):
		session.combat_random_source().next_below(4)
		session.world_interaction_random_source().next_below(30)
		session.npc_random_source().next_below(100)
	for enabled: bool in [true,false]:
		if enabled: SkillEnableTransition.try_enable(player.state.skills,LiuhKenDefinition.skill(),&"unarmed")
		else: player.state.skills.unmap_skill(&"unarmed")
		var snapshot := Work.capture(session)
		var raw: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(snapshot).text)
		check(raw.metadata.schema_version == 2 and raw.items.schema_version == 3 and raw.world_content_revision == "SOURCE_ENTRY_V1","save schema unchanged")
		var probe := Work.new()
		await probe.round_trip(tree,session,snapshot,"liuh enabled=" + str(enabled))
		check(probe._failures.is_empty(),"full state and all RNG exact; restore draws zero " + str(probe._failures))
	var map := session.resident_map(&"snow.outdoor") as SnowOutdoorController
	var school := map.school
	var before := Work.rng_state(session)
	check(not school.enable_liuh() and not school.disable_liuh() and not school.request_learn(&"liuh-ken").success,"out-of-range contact rejects")
	check(Work.rng_state(session) == before,"rejected contact draws zero")
	var walker := Work.new()
	await walker.walk(tree,session,"move_right",125)
	# Automated UI boundary fixture only; not claimed as natural/live journey.
	map.player_body.position = Vector2(1015,-400)
	player.set_world_location(WorldLocationState.new(player.world_location().region_id,&"snow.outdoor",SnowWorldDefinitions.SCHOOLHALL_ZONE_ID,&"snow.schoolhall"))
	check(school.can_teach(),"contact fixture valid")
	school.ui.interact()
	check(school.ui.panel.visible,"existing Liu panel")
	school.ui.enable_liuh_button.pressed.emit()
	check(player.state.skills.mapped_skill(&"unarmed") == &"liuh-ken" and school.ui.status.text.contains("有效拳脚 7"),"real button wiring / authoritative UI")
	school.ui.disable_liuh_button.pressed.emit()
	check(player.state.skills.mapped_skill(&"unarmed").is_empty() and school.ui.status.text.contains("有效拳脚 2"),"immediate disable UI")
	var before_resources: Array[int] = [player.state.recovery.inner_force.current,player.state.recovery.mana.current,player.state.recovery.atman.current]
	check(school.enable_liuh() and school.disable_liuh(),"contact transitions succeed")
	check(before_resources == [player.state.recovery.inner_force.current,player.state.recovery.mana.current,player.state.recovery.atman.current],"unarmed transitions never reset resources")
	player.state.skills.set_raw_level(&"liuh-ken",0)
	player.state.skills.set_learned_progress(&"liuh-ken",0)
	var learn_rng_before: int = session.world_interaction_random_source().capture_random_state().state
	var combat_rng_before: int = session.combat_random_source().capture_random_state().state
	school.ui.learn_liuh_button.pressed.emit()
	check(school.last_learn.skill_id == &"liuh-ken" and school.last_learn.calculated_essence_cost == 22 and school.last_learn.success,"Liu button uses generic liuh Learn with carried inventory/armor")
	check(session.world_interaction_random_source().capture_random_state().state != learn_rng_before and session.combat_random_source().capture_random_state().state == combat_rng_before,"Learn uses WorldInteraction, never Combat RNG")
	check(school.ui.feedback.text.contains("柳家拳") or school.last_learn.completion == LearnResult.Completion.PROGRESSED,"liuh label follows committed Learn")
	for gate: String in ["busy","fight","pause"]:
		if gate == "busy": player.busy.start_busy(1)
		if gate == "fight": player.relationship.add_opponent(&"opponent")
		if gate == "pause": tree.paused = true
		check(not school.enable_liuh() and not school.disable_liuh(),"mapping availability " + gate)
		player.busy.advance(); player.relationship.remove_opponent(&"opponent"); tree.paused = false
	for size: Vector2 in [Vector2(1152,648),Vector2(960,540),Vector2(800,480),Vector2(480,320)]:
		var rect := Rect2(Vector2.ZERO,size)
		var metrics := SafeAreaMetrics.normalize(rect,rect,rect,Transform2D.IDENTITY,true)
		school.ui._reflow(metrics)
		await tree.process_frame
		await tree.process_frame
		check(metrics.content_rect().encloses(school.ui.panel.get_rect()),"panel confined " + str(size))
		for button: Button in [school.ui.learn_button,school.ui.learn_liuh_button,school.ui.enable_liuh_button,school.ui.disable_liuh_button]:
			check(button.custom_minimum_size.y >= 64 and button.custom_minimum_size.x >= 64,"touch targets " + str(size))
		check(school.ui._layout.scroll.follow_focus,"scroll follows input focus")
	school.ui.close_panel()
	session.free()
	await tree.process_frame


func terminal_feedback(tree: SceneTree) -> void:
	var setup: Script = load("res://tests/support/cxr6_session_fixture.gd")
	var session: OldPineWorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	tree.root.add_child(session)
	session.set_process(false)
	var player := session.player_runtime()
	for weapon: EquippedWeaponRef in [player.state.equipment.primary_weapon(),player.state.equipment.secondary_weapon()]:
		if weapon != null: player.state.equipment.unwield(weapon.instance_id)
	player.state.skills.set_raw_level(&"unarmed",4)
	player.state.skills.set_raw_level(&"liuh-ken",5)
	SkillEnableTransition.try_enable(player.state.skills,LiuhKenDefinition.skill(),&"unarmed")
	var rng: CombatRandomSource = setup.CountingRandom.new()
	session.configure_combat_random_source(rng)
	check(setup.start(session,&"smp2.receipt").succeeded(),"controlled receipt encounter")
	var coordinator := session.combat_encounter_coordinator()
	coordinator.advance_scheduler(1.0)
	var projection := BattleProjectionBuilder.build(session)
	check(setup.complete(session) and coordinator.active_scheduler() == null,"scheduler released after completion")
	check(coordinator.completed_feedback() != null,"completed event receipt retained")
	var before: int = rng.calls
	var reader := BattleFeedbackReader.new()
	var entries := reader.read_new(coordinator,projection)
	var saw_liuh: bool = false
	for entry: BattleFeedbackProjection in entries:
		if entry.text.contains("古松挂月"):
			saw_liuh = true
			check(not entry.text.contains("$"),"terminal authored tokens resolved")
	check(saw_liuh and reader.read_new(coordinator,projection).is_empty(),"late terminal reader gets liuh once")
	check(rng.calls == before,"terminal feedback no random consumption")
	session.free()
	await tree.process_frame
