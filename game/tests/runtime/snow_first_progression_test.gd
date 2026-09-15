extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
const Draws := preload("res://tests/support/scripted_world_interaction_random_source.gd")
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	apprenticeship_tests()
	learn_tests()
	combat_tests()
	await persistence_tests(tree)
	await physical_tests(tree)
	var profile: String = "p2-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for mode: String in ["write", "read"]:
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_snow_progression_cold_process.gd", "--", mode, profile], output, true)
		check(code == 0 and str(output).contains("P2 cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold " + mode + ": " + str(output))
	return {"assertions": assertions, "failures": failures}


static func fresh() -> CharacterState:
	return NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "初学").state


static func disciple() -> CharacterState:
	var state := fresh()
	SwordsmanApprenticeship.new().request(state, 1789420000)
	return state


func apprenticeship_tests() -> void:
	var state := fresh()
	var request := SwordsmanApprenticeship.new()
	check(request.request(state, 1789420000) == SwordsmanApprenticeship.Outcome.RECRUITED, "fresh 30/30 recruitment")
	check(state.family.family_id == &"family.fonxan" and state.family.generation == 14, "exact family and generation")
	check(state.apprenticeship.master_teacher_id == &"teacher.liu_chunfeng" and state.apprenticeship.legacy_master_name == "柳淳风", "both master facts")
	check(state.affiliation.class_id == &"swordsman" and state.affiliation.family_title == "弟子" and state.affiliation.has_family_rank and state.affiliation.family_privileges == 0, "distinct class/rank/privilege")
	check(state.affiliation.entry_time_status == CharacterAffiliationState.EntryTime.RECORDED and state.affiliation.entry_time_utc == 1789420000, "entry timestamp")
	check(state.apprenticeship.betrayer_count == 0 and not state.skills.has_raw_level(&"unarmed") and state.progression.combat_experience == 0, "no betrayal/skill/experience reward")
	check(request.request(state, 1789429999) == SwordsmanApprenticeship.Outcome.ACKNOWLEDGED and state.affiliation.entry_time_utc == 1789420000 and state.apprenticeship.betrayer_count == 0, "idempotent old time")
	for attribute: String in ["courage", "composure"]:
		state = fresh()
		state.attributes.set(attribute, 19)
		request = SwordsmanApprenticeship.new()
		check(request.request(state, 1) == SwordsmanApprenticeship.Outcome.QUALIFICATION_REJECTED and request.is_pending(), attribute + " 19 pending")
		state.attributes.set(attribute, 20)
		check(request.request(state, 2) == SwordsmanApprenticeship.Outcome.PENDING and not state.family.has_family(), "retry before cancel remains pending")
		check(request.cancel() == SwordsmanApprenticeship.Outcome.CANCELLED and not request.is_pending(), "explicit cancel")
		check(request.request(state, 3) == SwordsmanApprenticeship.Outcome.RECRUITED, attribute + " exactly20 accepted")
	state = fresh()
	state.attributes.courage = 19
	state.attributes.bellicosity = 50
	state.attributes.composure = 19
	state.attributes.force_factor = 2
	check(SwordsmanApprenticeship.new().request(state, 4) == SwordsmanApprenticeship.Outcome.RECRUITED, "effective source attributes, not base")
	state = fresh()
	state.family = FamilyState.new(&"other", 1)
	check(SwordsmanApprenticeship.new().request(state, 5) == SwordsmanApprenticeship.Outcome.OTHER_RELATIONSHIP_DEFERRED and state.family.family_id == &"other", "no family switching")
	check(SnowSchoolTeacher.definition().offer_count() == 11 and SnowSchoolTeacher.definition().has_offer(&"liuh-ken"), "all source knowledge retained")


func learn_tests() -> void:
	for raw: int in [0, 1, 2, 3]:
		for experience: int in [0, 2]:
			for roll: int in [0, 1, 29]:
				var state := disciple()
				state.skills.set_raw_level(&"unarmed", raw)
				state.progression.combat_experience = experience
				var rng := Draws.new([roll])
				var result := learn(state, SnowSchoolTeacher.unarmed_context(), rng)
				var allowed: bool = raw < 3 or experience >= 2
				check(result.calculated_essence_cost == (22 if raw == 0 else 11), "exact cost " + str([raw,experience,roll]))
				check(rng.call_count() == (1 if allowed else 0) and state.progression.potential_spent == (1 if allowed else 0), "gate/draw/spent " + str([raw,experience,roll]))
				check(state.progression.potential == 99 and state.essence.current == (78 if raw == 0 else 89), "potential total / gin")
				if allowed:
					check(rng.requested_bounds() == [30] and result.deterministic_improvement_roll == roll, "one exact bound draw")
					check(state.skills.raw_level(&"unarmed") == raw + (1 if maxi(1, roll) > (raw+1)*(raw+1) else 0), "strict square / at most one level")
				else:
					check(result.completion == LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE, "exp blocks but gin spent")
	for row: Array in [[0,22,false],[0,23,true],[1,11,false],[1,12,true]]:
		var state := disciple()
		state.skills.set_raw_level(&"unarmed", row[0])
		state.essence.current = row[1]
		var rng := Draws.new([0])
		var result := learn(state, SnowSchoolTeacher.unarmed_context(), rng)
		check(rng.call_count() == (1 if row[2] else 0), "strict gin " + str(row))
		check(state.essence.current == (1 if row[2] else 0), "actual drain boundary")
		check(result.success, "fatigue executed vs pre-gate rejection")
	for raw: int in [0,1]:
		for sen: int in ([5,6] if raw == 0 else [3,4]):
			var state := disciple()
			state.skills.set_raw_level(&"unarmed", raw)
			var context := SnowSchoolTeacher.unarmed_context()
			context.current_spirit = sen
			var rng := Draws.new([0])
			var result := learn(state,context,rng)
			var fatigued: bool = sen == (5 if raw == 0 else 3)
			check(rng.call_count() == (0 if fatigued else 1) and context.current_spirit == sen, "NPC sen threshold/read-only")
			check(not fatigued or result.completion == LearnResult.Completion.NO_PROGRESS_TEACHER_FATIGUE, "teacher fatigue outcome")
	var state := disciple()
	state.progression.potential_spent = 99
	var rng := Draws.new([0])
	var result := learn(state,SnowSchoolTeacher.unarmed_context(),rng)
	check(result.created_explicit_zero_skill_entry and state.skills.has_raw_level(&"unarmed") and result.failure_reason == LearnResult.FailureReason.POTENTIAL_EXHAUSTED and rng.call_count() == 0 and state.essence.current == 100, "raw0 before potential failure")
	state = disciple()
	rng = Draws.new([30])
	result = learn(state,SnowSchoolTeacher.unarmed_context(),rng)
	check(result.completion == LearnResult.Completion.LEGACY_ERROR and result.failure_reason == LearnResult.FailureReason.INVALID_DETERMINISTIC_ROLL and state.progression.potential_spent == 1 and state.essence.current == 100 and state.skills.has_raw_level(&"unarmed") and rng.call_count() == 1, "invalid draw retains spent/zero before gin")
	state = fresh()
	rng = Draws.new([29])
	result = learn(state,SnowSchoolTeacher.unarmed_context(),rng)
	check(rng.call_count() == 0 and not state.skills.has_raw_level(&"unarmed") and result.failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, "no relationship rejects before draw/mutation")
	SnowSchoolInteraction.learn_message(result)
	check(rng.call_count() == 0, "presentation does not draw")


static func learn(state: CharacterState, context: TeachingContext, rng: WorldInteractionRandomSource) -> LearnResult:
	return LearnService.learn(state,context,SnowSchoolTeacher.unarmed_definition(),SnowSchoolTeacher.unarmed_policy(),null,rng)


func combat_tests() -> void:
	var state := fresh()
	var attacker := CombatSliceCharacterBinding.new(&"p2.player",state,CombatRelationshipState.new(&"p2.player"),ActionBusyState.new(),ArmorState.new(),CombatSliceContentProfile.new(),&"test")
	var defender := CombatSliceCharacterBinding.new(&"p2.target",fresh(),CombatRelationshipState.new(&"p2.target"),ActionBusyState.new(),ArmorState.new(),CombatSliceContentProfile.new(),&"test")
	for experience: int in [0,1,2]:
		for raw: int in [0,1,2]:
			state.skills.set_raw_level(&"unarmed",raw)
			state.progression.combat_experience = experience
			var input := CombatSliceProjectionBuilder.build_attack_input(attacker,defender,attacker.content.unarmed_action())
			check(input != null, "existing projection usable")
			if input == null: continue
			var a := input.attacker
			var ap: int = maxi(1,CombatMath.skill_power(CombatSkillPowerInput.new(a.living,a.effective_attack_skill_level,a.attack_usage_bonus,a.combat_experience,a.maximum_spirit,a.current_spirit)))
			check(ap == (2 if experience == 2 and raw == 2 else 1), "source AP " + str([experience,raw]))
			check(a.attack_usage_bonus == 0 and a.mapped_attack_skill_id.is_empty() and a.projected_attack_skill_type == &"unarmed", "no manual bonus or advanced mapping")


func persistence_tests(tree: SceneTree) -> void:
	for kind: String in ["snow","hockshop","oldpine","legacy_relation"]:
		var text := FileAccess.get_file_as_string("res://tests/fixtures/snow_progression/pre_p2_" + kind + ".json")
		var decoded := GameSaveJsonCodec.decode(text)
		check(decoded.succeeded(), "frozen P1 decode " + kind)
		if not decoded.succeeded(): continue
		check(not (JSON.parse_string(text) as Dictionary).player.character.has("affiliation"), "actual old shape")
		check(decoded.snapshot.player.character.affiliation.entry_time_status == (CharacterAffiliationState.EntryTime.UNKNOWN if kind == "legacy_relation" else CharacterAffiliationState.EntryTime.ABSENT), "old timestamp never now")
		check(decoded.snapshot.player.character.affiliation.class_id.is_empty(), "no invented old class")
		var source := Recovery.create_session(tree,Recovery.RandomSequence.new())
		await exact_roundtrip(tree,source,decoded.snapshot,"old P1 " + kind)
		source.free()
		await tree.process_frame
	var session := Recovery.create_session(tree,Recovery.RandomSequence.new())
	var player := session.player_runtime()
	var state := player.state
	state.attributes.courage = 19
	player.request_school_apprenticeship(100)
	var snapshot := Work.capture(session)
	check(player.school_apprenticeship.is_pending() and not GameSaveJsonCodec.encode(snapshot).text.contains("pending"), "pending omitted")
	player.school_apprenticeship.cancel()
	state.attributes.courage = 30
	var before_ids: Array[Object] = [player,state,player.body_facts,session.item_id_allocator()]
	check(player.request_school_apprenticeship(1789420000) == SwordsmanApprenticeship.Outcome.RECRUITED and player.facts.title == "封山剑派第十四代弟子", "controlled identity seam")
	check(before_ids == [player,player.state,player.body_facts,session.item_id_allocator()], "identity/body/allocator remain")
	state.progression.potential_spent = 99
	learn(state,SnowSchoolTeacher.unarmed_context(),Draws.new([0]))
	snapshot = Work.capture(session)
	await exact_roundtrip(tree,session,snapshot,"raw0 failure")
	state.progression.potential_spent = 0
	learn(state,SnowSchoolTeacher.unarmed_context(),session.world_interaction_random_source())
	state.skills.set_learned_progress(&"unarmed",1)
	snapshot = Work.capture(session)
	await exact_roundtrip(tree,session,snapshot,"partial skill")
	var encoded := GameSaveJsonCodec.encode(snapshot)
	var raw: Dictionary = JSON.parse_string(encoded.text)
	check(raw.metadata.schema_version == 2 and raw.items.schema_version == 3 and raw.world_content_revision == "SOURCE_ENTRY_V1", "root/item/content stable")
	raw.player.character.affiliation.schema_version = 2
	check(not GameSaveJsonCodec.decode(JSON.stringify(raw)).succeeded(), "unknown affiliation version rejected")
	raw.player.character.affiliation.schema_version = 1
	raw.player.character.affiliation.entry_time_status = "UNKNOWN"
	check(not GameSaveJsonCodec.decode(JSON.stringify(raw)).succeeded(), "unknown time cannot carry invented number")
	session.free()
	await tree.process_frame


func exact_roundtrip(tree: SceneTree, session: OldPineWorldSessionController, snapshot: GameSaveSnapshot, label: String) -> void:
	var probe := Work.new()
	await probe.round_trip(tree,session,snapshot,label)
	check(probe._failures.is_empty(),label + " all-state restore: " + str(probe._failures))


func physical_tests(tree: SceneTree) -> void:
	var session := Recovery.create_session(tree,Recovery.RandomSequence.new())
	var initial_npc_count: int = Work.capture(session).npc_spawn_states.size()
	var map := session.resident_map(&"snow.outdoor") as SnowOutdoorController
	check(not map.school.can_teach() and not map.school.request_learn().success, "inactive resident cannot teach")
	check(SnowWorldDefinitions.outdoor_map().zone_ids().size() == 16, "exactly three added zones")
	for i: int in range(3):
		var id: StringName = SnowWorldDefinitions.SCHOOL_ZONE_IDS[i]
		check(SnowWorldDefinitions.zone_by_id(id).legacy_room_ids() == ["/d/snow/" + String(id).get_slice(".",1)],"school source identity " + String(id))
	check(SnowWorldDefinitions.zone_by_id(&"snow.school") == null and SnowWorldDefinitions.zone_by_id(&"snow.inneryard") == null, "no academy or inner yard")
	var walk := Work.new()
	await tree.physics_frame
	await walk.walk(tree,session,"move_right",125)
	await walk.walk_to(tree,session,"move_right",0,0)
	await walk.walk_to(tree,session,"move_up",-400,1)
	await walk.walk_to(tree,session,"move_right",330,0)
	check(session.player_runtime().world_location().zone_id == &"snow.school1", "physical school1")
	await walk.walk(tree,session,"move_right",30)
	check(map.player_body.position.x < 372 and not map.school.door_is_open(), "closed real collision")
	check(map.school.open_door(),"open west")
	await tree.physics_frame
	check((map.get_node("Walls/SchoolDoor") as CollisionShape2D).disabled and not (map.get_node("Walls/SchoolEast") as CollisionShape2D).disabled,"only door collision disabled")
	check(not OldPineMapPlacementValidator.is_valid_character_position(map,&"snow.school2",Vector2(400,-400)),"open doorway save rejected")
	await walk.walk_to(tree,session,"move_right",450,0)
	check(map.school.close_door(),"close east")
	await tree.physics_frame
	check(not (map.get_node("Walls/SchoolDoor") as CollisionShape2D).disabled,"close collision restored")
	await walk.walk(tree,session,"move_left",30)
	check(map.player_body.position.x > 428,"inside closed blocks")
	check(map.school.open_door(),"open east")
	await walk.walk_to(tree,session,"move_left",340,0)
	check(map.school.close_door(),"close west")
	check(map.school.open_door(),"reopen west")
	await walk.walk_to(tree,session,"move_right",930,0)
	check(not map.school.can_teach(),"hall but outside proximity")
	await walk.walk_to(tree,session,"move_right",1015,0)
	check(map.school.can_teach(),"actual hall contact")
	var player := session.player_runtime()
	var valid_location := player.world_location()
	var before_state: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	player.set_world_location(WorldLocationState.new(valid_location.region_id, valid_location.map_id, &"snow.school2", &"snow.school2"))
	check(not map.school.can_teach() and not map.school.request_learn().success and map.school.request_apprentice() == SwordsmanApprenticeship.Outcome.AUTHORITY_FAILURE, "wrong zone rejects despite physical teacher proximity")
	player.set_world_location(valid_location)
	player.busy.start_busy(1)
	check(not map.school.can_teach() and not map.school.request_learn().success, "busy native contact gate")
	player.busy.advance()
	player.relationship.add_opponent(&"test.opponent")
	check(not map.school.can_teach() and not map.school.request_learn().success, "fighting contact gate")
	player.relationship.remove_opponent(&"test.opponent")
	tree.paused = true
	check(not map.school.can_teach() and not map.school.request_learn().success, "pause rechecks request authority")
	tree.paused = false
	check(GameSaveJsonCodec.encode(Work.capture(session)).text == before_state, "rejected contact requests preserve captured authority and RNG")
	map.school.ui.interact()
	check(map.school.ui.panel.visible,"narrow real panel")
	var position := map.player_body.position
	await walk.walk(tree,session,"move_left",12)
	check(map.player_body.position.distance_to(position) < 0.1,"panel movement quarantine")
	map.school.ui.request_apprentice()
	map.school.ui.request_learn()
	check(SwordsmanApprenticeship.is_master_of(session.player_runtime().state) and map.school.last_learn != null,"UI routing through services")
	map.school.ui.close_panel()
	var snapshot := Work.capture(session)
	check(snapshot != null and snapshot.npc_spawn_states.size() == initial_npc_count,"no teacher NPC slot")
	check(not GameSaveJsonCodec.encode(snapshot).text.contains('"door') and not GameSaveJsonCodec.encode(snapshot).text.contains('"school_door'),"transient gate fields omitted")
	await exact_roundtrip(tree,session,snapshot,"school position")
	check(walk._failures.is_empty(),"all physical targets reached: " + str(walk._failures))
	session.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("P2: " + label)
