extends RefCounted

## Owner-authorized functional story. Checkpoints are TEST-ONLY, never live grind evidence.
const ShellTests := preload("res://tests/application/application_shell_test.gd")
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const First := preload("res://tests/runtime/snow_first_progression_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Draws := preload("res://tests/support/scripted_combat_random_source.gd")
const LearnDraws := preload("res://tests/support/scripted_world_interaction_random_source.gd")
const SHELL := preload("res://scenes/application/application_shell.tscn")
const ACTION_IDS: Array[StringName] = [
	&"es2:daemon/skill/liuh-ken/gu-song-gua-yue", &"es2:daemon/skill/liuh-ken/ao-xue-dong-mei",
	&"es2:daemon/skill/liuh-ken/gu-ya-ting-tao", &"es2:daemon/skill/liuh-ken/huang-shan-hu-yin",
]
const TEXTS: Array[String] = [
	"$N使一招「古松挂月」，对准$n的$l「呼」地一拳",
	"$N扬起拳头，一招「傲雪冬梅」便往$n的$l招呼过去",
	"$N左手虚晃，右拳「孤崖听涛」往$n的$l击出",
	"$N步履一沉，左拳拉开，右拳使出「荒山虎吟」击向$n$l",
]
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	await _story(tree)
	print("SMP2 automated acceptance: %d assertions; %d failures" % [assertions, failures.size()])
	return {"assertions": assertions, "failures": failures}


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("SMP2 acceptance: " + label)


func _frames(tree: SceneTree) -> void:
	for i: int in 3: await tree.process_frame


func _story(tree: SceneTree) -> void:
	var files := ShellTests.MemoryFiles.new()
	var profile := GameSaveStorageProfile.isolated_test("smp2-functional")
	var shell: ApplicationShellController = SHELL.instantiate()
	shell.configure_before_start(profile, files, null, ShellTests.MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	check(shell.runtime_host().current_session() == null and files.files.is_empty(), "isolated menu, no prepared Save/Session")
	check(PublicNewGameTestFixture.request(shell), "public New Game fixture submits source setup")
	await _frames(tree)
	var session := shell.runtime_host().current_session()
	check(session != null, "public Session created")
	if session == null:
		shell.free()
		return
	session.set_process(false) # Test timing only; production recovery is unchanged.
	var player := session.player_runtime()
	var state := player.state
	check(session.world_content_revision() == WorldContentRevision.CURRENT_PUBLIC and session.active_map_id() == &"snow.inn", "source revision and Snow Inn")
	check(player.facts.age == 14, "age14")
	var a := state.attributes
	check([a.strength,a.courage,a.intelligence,a.spirituality,a.composure,a.personality,a.constitution,a.karma] == [30,30,30,30,30,30,30,30], "all base attributes30")
	check(state.progression.combat_experience == 0 and state.progression.potential == 99 and state.progression.potential_spent == 0, "birth EXP0/potential99/spent0")
	for resource: CharacterResourceState in [state.essence,state.vitality,state.spirit]:
		check([resource.current,resource.effective,resource.maximum] == [100,100,100], "full primary resource")
	var items := session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER,player.character_id))
	check(items.size() == 1, "only source cloth at birth")
	if items.size() == 1:
		check(session.item_instance_index().resolve(items[0]).item_definition_id == &"es2:obj/cloth" and player.armor.is_worn(items[0]), "source cloth worn")
	check(state.equipment.are_both_hands_empty() and state.skills.raw_skill_ids().is_empty() and state.skills.learned_skill_ids().is_empty() and state.skills.enabled_use_ids().is_empty(), "empty hands/skills/mappings")
	check(state.family.family_id.is_empty() and state.apprenticeship.master_teacher_id.is_empty() and state.affiliation.class_id.is_empty(), "no birth relationship")
	check(files.files.is_empty(), "birth never autosaves")

	# Declared contact placement fixture; no claim of keyboard/door traversal.
	check(session.handoff_to(&"snow.outdoor",&"snow.square",&"snow.square",SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID).succeeded(), "test contact map handoff")
	var map := session.active_map() as SnowOutdoorController
	map.player_body.position = Vector2(1015,-400)
	check(player.set_world_location(WorldLocationState.new(SnowWorldDefinitions.REGION_ID,&"snow.outdoor",SnowWorldDefinitions.SCHOOLHALL_ZONE_ID,&"snow.schoolhall")), "test Liu contact placement")
	var school := map.school
	check(school.request_apprentice() == SwordsmanApprenticeship.Outcome.RECRUITED, "production Liu apprenticeship")
	check(state.family.family_id == &"family.fonxan" and state.family.generation == 14 and state.apprenticeship.master_teacher_id == &"teacher.liu_chunfeng" and state.affiliation.class_id == &"swordsman", "committed relationship")
	var basic_rng := LearnDraws.new([29])
	var basic := First.learn(state,SnowSchoolTeacher.unarmed_context(),basic_rng)
	check(basic.success and state.skills.raw_level(&"unarmed") == 1 and basic_rng.requested_bounds() == [30], "real basic Learn, no raw assignment")
	check(state.essence.current == 78 and state.progression.potential_spent == 1, "basic Learn gin/potential debit")

	# Natural capability: Player defends against a stronger non-user actor.
	# Only RNG is scripted. The resolver/completion writes the EXP increment.
	var actor := Martial.binding(player.character_id,state)
	var enemy := Martial.binding(&"acceptance.opponent",null,false)
	var exp_rng := Draws.new([0,0,0,51])
	var exp_result := Martial.execute(enemy,actor,exp_rng,true)
	check(exp_result.outcome == CombatSingleAttackExecutionResult.Outcome.COMPLETED_WITHOUT_RIPOSTE, "production EXP opportunity completes")
	check(exp_result.ordinary_attack_result.base_result.outcome == CombatAttackResult.Outcome.DODGE and state.progression.combat_experience == 1, "natural resolver EXP0 to1")
	var progression := exp_result.ordinary_attack_result.progression_result
	check(progression.defender_combat_experience_before == 0 and progression.defender_combat_experience_after == 1 and progression.defender_roll_succeeded, "committed natural EXP receipt")
	check(exp_rng.requested_bounds() == [4,16,107,108], "natural progression uses committed 51/bound108")
	if state.progression.combat_experience != 1:
		shell.free()
		await _frames(tree)
		return

	# Owner-authorized TEST-ONLY prerequisite construction, not naturally earned.
	state.progression.combat_experience = 6
	state.skills.set_raw_level(&"unarmed",4)
	var liuh_rng := LearnDraws.new([29,29,29,29,29])
	for expected: int in range(1,5):
		var learned := Martial.learn(state,liuh_rng)
		check(learned.success and state.skills.raw_level(&"liuh-ken") == expected and state.skills.learned_progress(&"liuh-ken") == 0, "Learn builds liuh raw" + str(expected))
	state.progression.combat_experience = 5 # Exact negative boundary fixture.
	var spent_before: int = state.progression.potential_spent
	var blocked := Martial.learn(state,liuh_rng)
	check(blocked.completion == LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE and blocked.required_combat_experience == 6 and state.skills.raw_level(&"liuh-ken") == 4, "EXP5 cannot learn liuh4 to5")
	check(liuh_rng.call_count() == 4 and state.progression.potential_spent == spent_before, "EXP refusal draws/spends no potential")
	state.progression.combat_experience = 6
	var advanced := Martial.learn(state,liuh_rng)
	check(advanced.success and state.skills.raw_level(&"liuh-ken") == 5 and liuh_rng.call_count() == 5, "EXP6 real Learn reaches liuh5, never assigned")
	check(state.essence.current == 1 and state.progression.potential_spent == 6 and state.progression.potential == 99, "entire Learn sequence exact cost")
	check(school.enable_liuh() and state.skills.mapped_skill(&"unarmed") == &"liuh-ken" and state.skills.effective_level(&"unarmed") == 7, "production Enable effective unarmed7")
	var internal_before: Array[int] = [state.recovery.inner_force.current,state.recovery.mana.current,state.recovery.atman.current]
	check(school.disable_liuh() and state.skills.mapped_skill(&"unarmed").is_empty(), "production contact Disable")
	check(state.skills.raw_level(&"liuh-ken") == 5 and state.skills.learned_progress(&"liuh-ken") == 0 and state.skills.raw_level(&"unarmed") == 4, "Disable retains raw/learned")
	check(internal_before == [state.recovery.inner_force.current,state.recovery.mana.current,state.recovery.atman.current], "Disable no internal resource reset")
	check(school.enable_liuh(), "re-enable through contact")
	for index: int in range(4): _mapped_attack(state,index)
	_equipment(state)
	# Existing exhaustive reverse tests additionally exercise QUICK and RIPOSTE.
	var reverse := Martial.new()
	reverse.reverse_execution()
	assertions += reverse.assertions
	failures.append_array(reverse.failures)

	# Retain genuine liuh learned0; get nonzero basic progress from mapped combat.
	for i: int in range(10): CharacterRecovery.apply_tick(state,RecoverySkillLevels.new(),true)
	var hard_target := Martial.binding(&"acceptance.hard",null,false)
	hard_target.state.progression.combat_experience = 600
	var hit := Martial.execute(Martial.binding(player.character_id,state),hard_target,Martial.HighDraws.new(),true)
	check(hit.ordinary_attack_result.base_result.outcome == CombatAttackResult.Outcome.HIT and hit.ordinary_attack_result.progression_result.attacker_skill_improvement_attempted, "mapped hit reaches progression completion")
	check(state.skills.learned_progress(&"unarmed") == 1 and state.skills.learned_progress(&"liuh-ken") == 0 and state.skills.raw_level(&"liuh-ken") == 5 and state.progression.combat_experience == 7, "mapped hit improves basic only; natural EXP6 to7")
	check(shell.request_pause(), "public Pause before Save")
	var before := Work.capture(session)
	check(before != null, "complete durable projection before public Save")
	if before == null:
		shell.free()
		await _frames(tree)
		return
	var encoded := GameSaveJsonCodec.encode(before)
	check(encoded.succeeded(), "durable state encodes")
	var old_session_id: int = session.get_instance_id()
	var old_character_id: int = state.get_instance_id()
	var session_ref: WeakRef = weakref(session)
	var character_ref: WeakRef = weakref(state)
	check(shell.request_save_from_pause(), "public Save request")
	await _frames(tree)
	check(shell.last_result().succeeded(), "public Save succeeds")
	var saved := GameSaveRepository.new(profile,files).load()
	check(saved.succeeded() and saved.snapshot.metadata.schema_version == 2 and saved.snapshot.items.schema_version == 3, "unchanged root2/item3 Save schemas")
	check(saved.succeeded() and _durable_json(GameSaveJsonCodec.encode(saved.snapshot).text) == _durable_json(encoded.text), "public Save contains entire projected state")
	shell.free()
	session = null
	player = null
	state = null
	actor = null
	await _frames(tree)
	check(session_ref.get_ref() == null and character_ref.get_ref() == null, "old Session and Character graph freed")
	shell = SHELL.instantiate()
	shell.configure_before_start(profile,files,null,ShellTests.MemoryFiles.new())
	tree.root.add_child(shell)
	await _frames(tree)
	check(shell.runtime_host().current_session() == null, "fresh Shell begins without Session")
	check(shell.request_continue_from_menu(), "real public Continue request")
	await _frames(tree)
	session = shell.runtime_host().current_session()
	check(session != null, "Continue installs Session")
	if session == null:
		shell.free()
		return
	session.set_process(false)
	state = session.player_runtime().state
	check(session.get_instance_id() != old_session_id and state.get_instance_id() != old_character_id, "new Session/Character identities")
	var after := Work.capture(session)
	check(after != null and GameSaveJsonCodec.encode(after).text == encoded.text, "exact full durable equality including skills, relation, equipment, position, items, allocator, NPCs and all three RNG streams")
	check(Work.rng_state(session) == [before.combat_rng.state,before.npc_initialization_rng.state,before.world_interaction_rng.state], "Continue consumes zero durable RNG")
	check(state.skills.raw_level(&"unarmed") == 4 and state.skills.raw_level(&"liuh-ken") == 5 and state.skills.mapped_skill(&"unarmed") == &"liuh-ken" and state.skills.effective_level(&"unarmed") == 7, "restored Liuh finish")
	_mapped_attack(state,2)
	_upper_exp_boundary(state)
	shell.free()
	await _frames(tree)


func _mapped_attack(state: CharacterState, index: int) -> void:
	var rng := Draws.new([index,0,0])
	var result := Martial.execute(Martial.binding(&"acceptance.player",state),Martial.binding(&"acceptance.target"),rng)
	check(result.outcome == CombatSingleAttackExecutionResult.Outcome.COMPLETED_WITHOUT_RIPOSTE and result.ordinary_attack_result.outcome == CombatOrdinaryAttackResult.Outcome.COMPLETED, "mapped normal completion " + str(index))
	check(result.selected_action_id == ACTION_IDS[index] and result.ordinary_attack_result.base_result.action_id == ACTION_IDS[index], "authored action committed into resolver " + str(index))
	check(rng.requested_bounds() == [4,16,101 + state.progression.combat_experience], "one bound4 action draw; limb/math only thereafter")
	check(result.ordinary_attack_result.base_result.calculation.attack_power == 100 + state.progression.combat_experience, "authored dodge/parry metadata has no AP effect")
	var count_before: int = rng.call_count()
	var feedback := BattleFeedbackReader._attack(result.ordinary_attack_result,"学徒","对手")
	check(feedback.contains(TEXTS[index].replace("$N","学徒").replace("$n","对手").replace("$l","头部")) and not feedback.contains("$"), "full authored feedback " + str(index))
	check(rng.call_count() == count_before, "presentation cannot reroll")


func _equipment(state: CharacterState) -> void:
	var weapon := Martial.sword()
	state.equipment.wield(weapon,false)
	var rng := Draws.new([0,0,0])
	var result := Martial.execute(Martial.binding(&"armed",state),Martial.binding(&"target"),rng)
	check(state.skills.mapped_skill(&"unarmed") == &"liuh-ken" and result.selected_action_id == CombatSliceContentProfile.SLASH_ACTION_ID and rng.requested_bounds()[0] == 1, "primary weapon overrides retained mapping")
	state.equipment.unwield(weapon.instance_id)
	_mapped_attack(state,0)
	state.equipment._restore_weapons(null,Martial.sword(&"acceptance.secondary"))
	var learn_rng := LearnDraws.new([29])
	var learned := Martial.learn(state,learn_rng)
	check(learned.failure_reason == LearnResult.FailureReason.SKILL_LEARN_REJECTED and learn_rng.call_count() == 0, "secondary-only weapon rejects Liuh Learn before draw")
	state.equipment.unwield(&"acceptance.secondary")


func _upper_exp_boundary(state: CharacterState) -> void:
	# Separate post-loop boundary probe; no raw Liuh assignment, no saved-state edits.
	for i: int in range(10): CharacterRecovery.apply_tick(state,RecoverySkillLevels.new(),true)
	state.progression.combat_experience = 11
	var rng := LearnDraws.new([29,29])
	var result := Martial.learn(state,rng)
	check(result.completion == LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE and result.required_combat_experience == 12 and rng.call_count() == 0 and state.skills.raw_level(&"liuh-ken") == 5, "EXP11 blocks raw5")
	state.progression.combat_experience = 12
	result = Martial.learn(state,rng)
	check(result.success and state.skills.learned_progress(&"liuh-ken") == 29 and state.skills.raw_level(&"liuh-ken") == 5, "EXP12 allows actual learned progress")
	result = Martial.learn(state,rng)
	check(result.success and state.skills.raw_level(&"liuh-ken") == 6 and rng.requested_bounds() == [30,30], "two Learn calls cross strict square threshold to raw6")


func _durable_json(text: String) -> Dictionary:
	var value: Dictionary = JSON.parse_string(text)
	# Save time/build metadata is not durable gameplay state; every other field stays.
	value.erase("metadata")
	return value
