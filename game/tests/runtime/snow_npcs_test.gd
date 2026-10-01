extends RefCounted

## Snow's NPCs (4A), imported from d/snow by tools/migration/content_importer.py:
## every Snow spawn stands in its zone with its authored facts and loadout, and
## the temple (set("no_fight")) refuses an attack.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	_test_population(session)
	_test_authored_facts(session)
	await _test_temple_forbids_fighting(tree, session)
	session.free()
	await tree.process_frame
	await _test_dog_fight_ends(tree)
	return {"assertions": _count, "failures": _failures}


func _test_population(session: OldPineWorldSessionController) -> void:
	var placed: int = 0
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		if GameContent.catalog().map(spawn.map_id).region_id != &"snow":
			continue
		var map: WorldMapController = session.world_map_of(spawn.map_id)
		for point_id: StringName in spawn.spawn_point_ids():
			var npc: NpcRuntimeState = map.find_resident_npc(StringName("%s.character" % point_id))
			_check(npc != null and npc.definition_id == spawn.npc_definition_id and npc.world_location().zone_id == spawn.zone_id, "%s stands in %s" % [point_id, spawn.zone_id])
			if npc != null:
				var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
				_check(body != null and MapPlacementValidator.is_valid_character_position(map, spawn.zone_id, body.global_position), "%s body is inside its zone, clear of walls" % point_id)
				placed += 1
	_check(placed == 15, "fifteen Snow NPCs: travellers 2, dogs 2, keeper, drunk, scavenger, guard, trainees 6, trainer")


func _test_authored_facts(session: OldPineWorldSessionController) -> void:
	var outdoor: WorldMapController = session.world_map_of(&"snow.outdoor")
	var guard: NpcRuntimeState = outdoor.find_resident_npc(&"snow.school1.guard.1.character")
	_check(guard.definition().short_name() == "门房 刘安禄" and guard.definition().attitude == NpcDefinition.Attitude.HEROISM, "guard.c title and heroism")
	_check(guard.character_state.equipment.primary_weapon_skill_type() == &"blade" and guard.armor.occupied_slots() == [&"cloth"], "guard wields the blade and wears cloth")
	_check(guard.character_state.skills.raw_level(&"blade") == 40 and guard.character_state.skills.raw_level(&"parry") == 40 and guard.character_state.attributes.strength == 29, "guard skills and attributes")
	var trainer: NpcRuntimeState = outdoor.find_resident_npc(&"snow.school2.fist_trainer.1.character")
	_check(trainer.character_state.skills.mapped_skill(&"unarmed") == &"liuh-ken", "李火狮 fights with 柳家拳 (map_skill)")
	var trainee: NpcRuntimeState = outdoor.find_resident_npc(&"snow.school2.trainee.1.character")
	_check(trainee.armor.aggregate_numeric_modifiers().armor == 2 and trainee.character_state.progression.combat_experience == 100, "trainee wears linen (armor 2)")
	var dog: NpcRuntimeState = outdoor.find_resident_npc(&"snow.eroad2.dog.1.character")
	_check(dog.definition().race_id == &"beast" and dog.loadout_items().is_empty() and dog.definition().authored_combat_facts().verbs() == [&"bite", &"claw"], "野狗 is a beast that bites and claws")
	var drunk: NpcRuntimeState = outdoor.find_resident_npc(&"snow.mstreet2.drunk.1.character")
	var wine: LiquidState = null
	for item: ItemInstance in drunk.loadout_items():
		if item.item_definition_id == &"es2:obj/example/wineskin":
			wine = session.liquid_collection().state(item.item_instance_id)
	_check(wine != null and wine.content == LiquidState.Content.RED_WINE and wine.remaining == 15, "the drunk's wineskin starts full of red wine")
	var inn: WorldMapController = session.world_map_of(&"snow.inn")
	for point: int in [1, 2]:
		var traveller: NpcRuntimeState = inn.find_resident_npc(StringName("snow.inn.main_floor.inn.traveller.%d.character" % point))
		_check(
			traveller.character_state.gender in [&"男性", &"女性"]
			and traveller.age >= 15 and traveller.age < 65
			and traveller.character_state.progression.combat_experience >= 600
			and traveller.character_state.progression.combat_experience < 1000,
			"traveller %d drew gender, 15+random(50) and 600+random(400)" % point,
		)


func _test_temple_forbids_fighting(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	# Inn east door to the square, then the temple's west door (d/snow/temple.c).
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	# Selected from the square next door, the keeper is still inside a no_fight room.
	var outdoor: WorldMapController = session.active_map() as WorldMapController
	_check(session.player_runtime().world_location().zone_id == &"snow.square" and outdoor.select_npc(&"snow.temple.keeper.1.character"), "the keeper can be selected from the square")
	var square_log: int = session.shared_ui().log_lines().size()
	outdoor.attack_selected()
	_check(not session.combat_encounter_coordinator().has_active_encounter() and session.shared_ui().log_lines().slice(square_log) == ["这里不准战斗。"], "no fight with someone standing in the temple either")
	var walker: RefCounted = Work.new()
	await walker.walk_to(tree, session, "move_down", 205, 1)
	await walker.walk_to(tree, session, "move_right", 420, 0)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(walker._failures.is_empty() and player.world_location().zone_id == &"snow.temple", "walked from the Inn through the square into the temple")
	var map: WorldMapController = session.active_map() as WorldMapController
	_check(map.select_npc(&"snow.temple.keeper.1.character"), "the keeper can be selected")
	var before: int = session.shared_ui().log_lines().size()
	var result: CombatSliceInitiationResult = map.attack_selected()
	_check(result.outcome != CombatSliceInitiationResult.Outcome.COMPLETED and not session.combat_encounter_coordinator().has_active_encounter(), "no fight starts in the temple")
	var lines: Array[String] = session.shared_ui().log_lines()
	_check(lines.size() == before + 1 and lines[-1] == "这里不准战斗。", "kill.c: 这里不准战斗。")


## d/snow/npc/dog.c bites and claws (beast.c query_action draws one verb per
## attack, forward or riposte). A claw must not stall the encounter.
func _test_dog_fight_ends(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	var walker: RefCounted = Work.new()
	await walker.walk_to(tree, session, "move_right", 0, 0)
	await walker.walk_to(tree, session, "move_down", 550, 1)
	await walker.walk_to(tree, session, "move_right", 600, 0)
	_check(walker._failures.is_empty() and session.player_runtime().world_location().zone_id == &"snow.eroad2", "walked to the dogs on the east road")
	session.set_process(false)
	var map: WorldMapController = session.active_map() as WorldMapController
	map.select_npc(&"snow.eroad2.dog.1.character")
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the fight with the dog starts")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var claws: int = 0
	var stalled: bool = false
	for _second: int in range(120):
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1.0)
		for event: CombatSchedulerEvent in advanced.events():
			var resolution: CombatSliceOpportunityResult = event.resolution
			if resolution == null:
				continue
			if resolution.forward_result != null and resolution.forward_result.selected_action_id == &"es2:adm/daemons/race/beast/claw":
				claws += 1
			if resolution.chain_result != null and resolution.chain_result.reverse_selected_action_id == &"es2:adm/daemons/race/beast/claw":
				claws += 1
			stalled = stalled or resolution.outcome == CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE
		if not coordinator.has_active_encounter():
			break
	_check(not stalled and not coordinator.has_active_encounter(), "the dog fight runs to its end, no incomplete attack chain")
	_check(claws > 0, "the dog clawed at least once")
	# The seeded fight ends as the owner's playtest did: the dog kills the new character on
	# Snow's own map, so the way back (wgargoyle.c) must not need a scene change.
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD and session.player_life_flow().phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE, "the dog killed the new character on the east road")
	for _second: int in range(60):
		session.skip_death_message()
		session._process(1.0)
		await tree.process_frame
		if not session.player_life_flow().is_active():
			break
	var body: WorldCharacterBody2D = session.active_map().runtime_player_body()
	_check(
		player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and session.active_map_id() == &"snow.outdoor"
		and player.world_location().zone_id == &"snow.temple" and body.visible
		and body.global_position == (session.active_map() as WorldMapController).resolve_spawn_marker(&"snow.temple.revive").global_position,
		"继续 brings the player back at the temple on the same map",
	)
	session.free()
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("4A Snow NPCs: " + label)
