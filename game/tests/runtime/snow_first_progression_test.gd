extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
const Draws := preload("res://tests/support/scripted_world_interaction_random_source.gd")
const Master := preload("res://tests/support/snow_master.gd")
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
	Master.recruit(state, 1789420000)
	return state


func apprenticeship_tests() -> void:
	var state := fresh()
	var request := NpcApprenticeship.new()
	check(Master.recruit(state, 1789420000, request) == NpcApprenticeship.Outcome.RECRUITED, "fresh 30/30 recruitment")
	check(request.lines == ["你想要拜柳淳风为师。", "柳淳风说道：很好，壮士多加努力，他日必定有成。", "柳淳风决定收你为弟子。", "你跪了下来向柳淳风恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为封山剑派的第十四代弟子。"], "apprentice.c, master.c and recruit.c lines: " + str(request.lines))
	check(state.family.family_id == &"family.fonxan" and state.family.generation == 14, "exact family and generation")
	check(state.apprenticeship.master_teacher_id == Master.MASTER_ID and state.apprenticeship.legacy_master_name == "柳淳风", "both master facts")
	check(state.affiliation.class_id == &"swordsman" and state.affiliation.family_title == "弟子" and state.affiliation.has_family_rank and state.affiliation.family_privileges == 0, "distinct class/rank/privilege")
	check(state.affiliation.entry_time_status == CharacterAffiliationState.EntryTime.RECORDED and state.affiliation.entry_time_utc == 1789420000, "entry timestamp")
	check(state.apprenticeship.betrayer_count == 0 and not state.skills.has_raw_level(&"unarmed") and state.progression.combat_experience == 0, "no betrayal/skill/experience reward")
	check(Master.recruit(state, 1789429999, request) == NpcApprenticeship.Outcome.ACKNOWLEDGED and state.affiliation.entry_time_utc == 1789420000 and state.apprenticeship.betrayer_count == 0, "idempotent old time")
	check(request.lines == ["你恭恭敬敬地向柳淳风磕头请安，叫道：「师父！」"], "apprentice.c greets the master")
	for attribute: String in ["courage", "composure"]:
		state = fresh()
		state.attributes.set(attribute, 19)
		request = NpcApprenticeship.new()
		check(Master.recruit(state, 1, request) == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.is_pending(), attribute + " 19 pending")
		check(request.lines[-1] == "柳淳风说道：学剑之人必须胆大心细，依我看壮士的资质似乎不宜？", "attempt_apprentice() refusal")
		state.attributes.set(attribute, 20)
		check(Master.recruit(state, 2, request) == NpcApprenticeship.Outcome.PENDING and not state.family.has_family(), "retry before cancel remains pending")
		check(request.lines == ["你想拜柳淳风为师，但是对方还没有答应。"], "apprentice.c: still pending")
		check(request.cancel() == NpcApprenticeship.Outcome.CANCELLED and not request.is_pending(), "explicit cancel")
		check(Master.recruit(state, 3, request) == NpcApprenticeship.Outcome.RECRUITED, attribute + " exactly20 accepted")
	state = fresh()
	state.attributes.courage = 19
	state.attributes.bellicosity = 50
	state.attributes.composure = 19
	state.attributes.force_factor = 2
	check(Master.recruit(state, 4) == NpcApprenticeship.Outcome.RECRUITED, "effective source attributes, not base")
	state = fresh()
	state.family = FamilyState.new(&"other", 1)
	state.progression.score = 7
	request = NpcApprenticeship.new()
	check(Master.recruit(state, 5, request) == NpcApprenticeship.Outcome.RECRUITED and state.family.family_id == &"family.fonxan" and state.apprenticeship.betrayer_count == 1 and state.progression.score == 0, "a member of another family betrays it (recruit.c)")
	check(request.lines[2] == "你决定背叛师门，改投入柳淳风门下！！", "recruit.c betrayal line: " + str(request.lines))
	check(Master.definition().skill_levels().size() == 11 and NpcTeacher.teachable_skills(Master.definition(), GameContent.catalog()) == [&"unarmed", &"parry", &"dodge", &"sword", &"force", &"literate", &"fonxanforce", &"fonxansword", &"liuh-ken", &"chaos-steps"], "all source knowledge retained; teaches what skills.json defines (not spider-array)")


func learn_tests() -> void:
	for raw: int in [0, 1, 2, 3]:
		for experience: int in [0, 2]:
			for roll: int in [0, 1, 29]:
				var state := disciple()
				state.skills.set_raw_level(&"unarmed", raw)
				state.progression.combat_experience = experience
				var rng := Draws.new([roll])
				var result := learn(state, Master.context(&"unarmed", rng), rng)
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
		var result := learn(state, Master.context(&"unarmed", rng), rng)
		check(rng.call_count() == (1 if row[2] else 0), "strict gin " + str(row))
		check(state.essence.current == (1 if row[2] else 0), "actual drain boundary")
		check(result.success, "fatigue executed vs pre-gate rejection")
	for raw: int in [0,1]:
		for sen: int in ([5,6] if raw == 0 else [3,4]):
			var state := disciple()
			state.skills.set_raw_level(&"unarmed", raw)
			var rng := Draws.new([0])
			var context := Master.context(&"unarmed", rng)
			context.current_spirit = sen
			var result := learn(state,context,rng)
			var fatigued: bool = sen == (5 if raw == 0 else 3)
			check(rng.call_count() == (0 if fatigued else 1) and context.current_spirit == sen, "NPC sen threshold/read-only")
			check(not fatigued or result.completion == LearnResult.Completion.NO_PROGRESS_TEACHER_FATIGUE, "teacher fatigue outcome")
	var state := disciple()
	state.progression.potential_spent = 99
	var rng := Draws.new([0])
	var result := learn(state,Master.context(&"unarmed", rng),rng)
	check(result.created_explicit_zero_skill_entry and state.skills.has_raw_level(&"unarmed") and result.failure_reason == LearnResult.FailureReason.POTENTIAL_EXHAUSTED and rng.call_count() == 0 and state.essence.current == 100, "raw0 before potential failure")
	state = disciple()
	rng = Draws.new([30])
	result = learn(state,Master.context(&"unarmed", rng),rng)
	check(result.completion == LearnResult.Completion.LEGACY_ERROR and result.failure_reason == LearnResult.FailureReason.INVALID_DETERMINISTIC_ROLL and state.progression.potential_spent == 1 and state.essence.current == 100 and state.skills.has_raw_level(&"unarmed") and rng.call_count() == 1, "invalid draw retains spent/zero before gin")
	state = fresh()
	rng = Draws.new([2])
	var context := Master.context(&"unarmed", rng)
	result = learn(state,context,rng)
	# learn.c draws reject_msg[random(3)] for its notify_fail before asking recognize_apprentice().
	check(rng.requested_bounds() == [3] and not state.skills.has_raw_level(&"unarmed") and result.failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, "no relationship rejects before mutation, after the refusal draw")
	check(LearnLines.lines(result, "柳淳风", GameContent.catalog().skill(&"unarmed"), state, context, "壮士") == ["柳淳风笑著说道：您见笑了，我这点雕虫小技怎够资格「指点」您什麽？"], "the drawn refusal")
	check(rng.call_count() == 1, "presentation does not draw")


static func learn(state: CharacterState, context: TeachingContext, rng: WorldInteractionRandomSource) -> LearnResult:
	return LearnService.learn(state,context,Master.skill(&"unarmed"),Master.policy(&"unarmed"),null,rng)


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
		check(GameSaveJsonCodec.decode(text, true).outcome == GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, "historical development contract explicitly refused " + kind)
	var session := Recovery.create_session(tree,Recovery.RandomSequence.new())
	var player := session.player_runtime()
	var state := player.state
	state.attributes.courage = 19
	player.request_apprenticeship(Master.definition(), Master.family(), 100)
	var snapshot := Work.capture(session)
	check(player.apprenticeship_request.is_pending() and not GameSaveJsonCodec.encode(snapshot).text.contains("pending"), "pending omitted")
	player.apprenticeship_request.cancel()
	state.attributes.courage = 30
	var before_ids: Array[Object] = [player,state,player.body_facts,session.item_id_allocator()]
	check(player.request_apprenticeship(Master.definition(), Master.family(), 1789420000) == NpcApprenticeship.Outcome.RECRUITED and player.facts.title == "封山剑派第十四代弟子", "controlled identity seam")
	check(before_ids == [player,player.state,player.body_facts,session.item_id_allocator()], "identity/body/allocator remain")
	state.progression.potential_spent = 99
	learn(state,Master.context(&"unarmed"),Draws.new([0]))
	snapshot = Work.capture(session)
	await exact_roundtrip(tree,session,snapshot,"raw0 failure")
	state.progression.potential_spent = 0
	learn(state,Master.context(&"unarmed"),session.world_interaction_random_source())
	state.skills.set_learned_progress(&"unarmed",1)
	snapshot = Work.capture(session)
	await exact_roundtrip(tree,session,snapshot,"partial skill")
	var encoded := GameSaveJsonCodec.encode(snapshot)
	var raw: Dictionary = JSON.parse_string(encoded.text)
	check(raw.metadata.schema_version == 2 and raw.items.schema_version == 3 and raw.world_content_revision == WorldContentRevision.serialized(WorldContentRevision.CURRENT_PUBLIC), "root/item/content stable")
	raw.player.character.affiliation.schema_version = 2
	check(not GameSaveJsonCodec.decode(JSON.stringify(raw)).succeeded(), "unknown affiliation version rejected")
	raw.player.character.affiliation.schema_version = 1
	raw.player.character.affiliation.entry_time_status = "UNKNOWN"
	check(not GameSaveJsonCodec.decode(JSON.stringify(raw)).succeeded(), "unknown time cannot carry invented number")
	session.free()
	await tree.process_frame


func exact_roundtrip(tree: SceneTree, session: WorldSessionController, snapshot: GameSaveSnapshot, label: String) -> void:
	var probe := Work.new()
	await probe.round_trip(tree,session,snapshot,label)
	check(probe._failures.is_empty(),label + " all-state restore: " + str(probe._failures))


func physical_tests(tree: SceneTree) -> void:
	var session := Recovery.create_session(tree,Recovery.RandomSequence.new())
	var initial_npc_count: int = Work.capture(session).npc_spawn_states.size()
	var map := session.resident_map(&"snow.outdoor") as WorldMapController
	var school := map.service(&"snow.outdoor.schoolhall.master") as TeacherService
	check(school != null and not school.can_teach() and not school.request_learn(&"unarmed").success, "inactive resident cannot teach")
	check(GameContent.catalog().zones_for_map(&"snow.outdoor").size() == 31, "three school zones, the revival temple, 4B's nine rooms and 4C's five")
	for i: int in range(3):
		var id: StringName = [SnowWorldDefinitions.SCHOOL1_ZONE_ID, SnowWorldDefinitions.SCHOOL2_ZONE_ID, SnowWorldDefinitions.SCHOOLHALL_ZONE_ID][i]
		check(GameContent.catalog().zone(id).room_ids() == [StringName("es2:d/snow/" + String(id).get_slice(".", 1))],"school source identity " + String(id))
	var walk := Work.new()
	await tree.physics_frame
	check(await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, SnowWorldDefinitions.INN_EXIT_PORTAL_ID), "out through the Inn's door")
	check(await MapPlaces.drive_through(tree, map, [&"snow.square", &"snow.mstreet1", &"snow.school1"]), "up the street and in at the school entrance")
	check(session.player_runtime().world_location().zone_id == &"snow.school1", "physical school1")
	var gate: CollisionShape2D = MapPlaces.door_wall(map, &"snow.school.gate")
	check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"snow.school.gate", &"snow.school1")), "up to the red gate")
	await MapPlaces.push(tree, &"move_right", 30)
	check(map.player_body.position.x < gate.global_position.x - 16.0 and not map.door(&"snow.school.gate").is_open(), "closed real collision")
	check(map.open_door(&"snow.school.gate"),"open west")
	await tree.physics_frame
	var hall: Rect2 = MapPlaces.zone_rect(map, &"snow.schoolhall")
	check(gate.disabled and TerrainProbe.blocks_at(map, hall.position + Vector2(8, 8)),"only door collision disabled")
	check(not MapPlacementValidator.is_valid_character_position(map,&"snow.school2",gate.global_position),"open doorway save rejected")
	check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"snow.school.gate", &"snow.school2")), "through into the yard")
	check(map.close_door(&"snow.school.gate"),"close east")
	await tree.physics_frame
	check(not gate.disabled,"close collision restored")
	await MapPlaces.push(tree, &"move_left", 30)
	check(map.player_body.position.x > gate.global_position.x + 16.0,"inside closed blocks")
	check(map.open_door(&"snow.school.gate"),"open east")
	check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"snow.school.gate", &"snow.school1")), "back through the gate")
	check(map.close_door(&"snow.school.gate"),"close west")
	check(map.open_door(&"snow.school.gate"),"reopen west")
	check(await MapPlaces.drive(tree, map, MapPlaces.spot(map, &"snow.schoolhall", MapPlaces.doorway(map, &"snow.school2", &"snow.schoolhall") + Vector2(48, 0))), "across the yard into the hall")
	check(not school.can_teach(),"hall but outside proximity")
	check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"snow.outdoor.schoolhall.master", &"snow.schoolhall")), "up to 柳淳风")
	check(school.can_teach(),"actual hall contact")
	var player := session.player_runtime()
	var valid_location := player.world_location()
	var before_state: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	player.set_world_location(WorldLocationState.new(valid_location.region_id, valid_location.map_id, &"snow.school2", &"snow.school2"))
	check(not school.can_teach() and not school.request_learn(&"unarmed").success and school.request_apprentice() == NpcApprenticeship.Outcome.AUTHORITY_FAILURE, "wrong zone rejects despite physical teacher proximity")
	player.set_world_location(valid_location)
	player.busy.start_busy(1)
	check(not school.can_teach() and not school.request_learn(&"unarmed").success, "busy native contact gate")
	player.busy.advance()
	player.relationship.add_opponent(&"test.opponent")
	check(not school.can_teach() and not school.request_learn(&"unarmed").success, "fighting contact gate")
	player.relationship.remove_opponent(&"test.opponent")
	tree.paused = true
	check(not school.can_teach() and not school.request_learn(&"unarmed").success, "pause rechecks request authority")
	tree.paused = false
	check(GameSaveJsonCodec.encode(Work.capture(session)).text == before_state, "rejected contact requests preserve captured authority and RNG")
	school.ui.interact()
	check(school.ui.panel.visible,"narrow real panel")
	var position := map.player_body.position
	await walk.walk(tree,session,"move_left",12)
	check(map.player_body.position.distance_to(position) < 0.1,"panel movement quarantine")
	school.ui.request_apprentice()
	check(school.ui.is_confirming() and not NpcApprenticeship.is_master_of(session.player_runtime().state, Master.definition()), "the first master asks first")
	school.ui.confirm_button.pressed.emit()
	school.ui.learn_buttons[&"unarmed"].pressed.emit()
	check(NpcApprenticeship.is_master_of(session.player_runtime().state, Master.definition()) and school.last_learn != null,"UI routing through services")
	check(school.ui.feedback.text.contains("你向柳淳风请教有关「基本拳脚」的疑问。"), "learn.c lines in the panel: " + school.ui.feedback.text)
	school.ui.close_panel()
	var snapshot := Work.capture(session)
	check(snapshot != null and snapshot.npc_spawn_states.size() == initial_npc_count,"the master is one of the authored NPC slots")
	check(not GameSaveJsonCodec.encode(snapshot).text.contains('"door') and not GameSaveJsonCodec.encode(snapshot).text.contains('"school_door'),"transient gate fields omitted")
	await exact_roundtrip(tree,session,snapshot,"school position")
	check(walk._failures.is_empty(),"all physical targets reached: " + str(walk._failures))
	session.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("P2: " + label)
