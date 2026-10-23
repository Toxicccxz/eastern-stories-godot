extends RefCounted

var _count: int = 0
var _failures: Array[String] = []

class OrderedResource extends CharacterResourceState:
	var order: Array[String]
	var label: String
	func _init(p_label: String, p_order: Array[String]) -> void:
		super(100, 100, 100)
		label = p_label
		order = p_order
	func apply_damage(amount: int) -> int:
		order.append(label)
		return super.apply_damage(amount)



## random(n) is n - 1: no NPC chat beat fires (test fixtures that must not wander).
class StillAmbience extends WorldInteractionRandomSource:
	func next_below(bound: int) -> int:
		return bound - 1

func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = create_session(tree)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	var index: WorldItemInstanceIndex = session.item_instance_index()
	var inventory: InventoryState = session.inventory_state()
	var allocator: SessionItemIdAllocator = session.item_id_allocator()
	var initial_ids: Array[StringName] = inventory.registered_item_ids()
	var initial_sequence: int = allocator.next_dynamic_sequence
	var original: GameSaveSnapshot = capture(session)
	_check(original != null, "old source save without silver capture")
	await round_trip(tree, session, original, "old no-silver save")
	var rng: Array[int] = rng_state(session)
	for values: Vector2i in [Vector2i(29,100), Vector2i(30,29), Vector2i(-1,100), Vector2i(0,0)]:
		state.essence.current = values.x
		state.spirit.current = values.y
		var rejected: SnowWorkResult = work(session)
		_check(rejected.outcome == SnowWorkResult.Outcome.TOO_TIRED and not rejected.costs_applied, "one tired outcome " + str(values))
		_check(state.essence.current == values.x and state.spirit.current == values.y, "failure resources unchanged")
		_check(allocator.next_dynamic_sequence == initial_sequence and inventory.registered_item_ids() == initial_ids and index.snapshot_ids() == initial_ids, "failure allocates nothing")
		_check(rng_state(session) == rng, "failure RNG exact")
	var order: Array[String] = []
	state.essence = OrderedResource.new("gin", order)
	state.spirit = OrderedResource.new("sen", order)
	var previous_reward: StringName = &""
	for n: int in range(1, 4):
		var result: SnowWorkResult = work(session)
		_check(result.succeeded(), "work success " + str(n))
		_check(state.essence.current == 100 - 30*n and state.spirit.current == 100 - 30*n, "LPC exact -30")
		_check(order == ["sen", "gin"], "LPC ordered mutation")
		order.clear()
		_check(result.reward_id != previous_reward and allocator.next_dynamic_sequence == initial_sequence+n, "new allocation even on merge")
		_check(session.stack_collection().stack_state(result.reward_id).amount == n and inventory.own_weight(result.reward_id) == 37*n, "source amount and weight")
		_check(inventory.registered_item_ids().size() == initial_ids.size()+1 and index.snapshot_ids() == inventory.registered_item_ids(), "one surviving silver and exact derived index")
		if previous_reward != &"":
			_check(not inventory.is_registered(previous_reward) and not index.has_snapshot(previous_reward) and not session.stack_collection().has_stack(previous_reward), "absorbed item lifecycle completed")
		previous_reward = result.reward_id
	_check(work(session).outcome == SnowWorkResult.Outcome.TOO_TIRED and allocator.next_dynamic_sequence == initial_sequence+3, "fourth tired, no ID")
	_check(state.vitality.current == 100 and state.recovery.food == 400 and state.recovery.water == 400 and state.progression.combat_experience == 0 and state.progression.potential == 99, "no kee/food/water/exp/potential changes")
	_check(state.essence.effective == 100 and state.spirit.effective == 100 and player.body_facts.body_weight == 80000 and player.maximum_encumbrance == 150000, "no wounds/body/capacity changes")
	_check(rng_state(session) == rng, "three gameplay RNG streams unchanged")
	await round_trip(tree, session, capture(session), "three silver save")
	# Exact resource threshold: use independent character/graph.
	var edge: WorldSessionController = create_session(tree)
	edge.player_runtime().state.essence.current = 30
	edge.player_runtime().state.spirit.current = 30
	_check(work(edge).succeeded() and edge.player_runtime().state.life_threshold() == CharacterState.LifeThreshold.ACTIVE, "30/30 succeeds to zero without unconsciousness")
	_check(state.essence.current == 10 and state.spirit.current == 10, "independent characters")
	edge.free()
	session.free()
	await tree.process_frame
	await capacity_test(tree)
	await physical_test(tree)
	# Exercise genuine process termination between saving and Host Continue.
	var profile: String = "s2-capacity-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for mode: String in ["write", "read"]:
		var output: Array = []
		var exit_code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_snow_work_cold_process.gd", "--", mode, profile], output, true)
		_check(exit_code == 0 and str(output).contains("S2 cold process " + mode + ": PASS"), "separate process " + mode + ": " + str(output))
	return {"assertions": _count, "failures": _failures}


func capacity_test(tree: SceneTree) -> void:
	var session: WorldSessionController = create_session(tree)
	var inv: InventoryState = session.inventory_state()
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	var cloth: StringName = inv.direct_children(owner)[0]
	# QA-only carry fixture; no production capacity/body changes.
	inv.update_own_weight(cloth, session.player_runtime().maximum_encumbrance - 20)
	var ids: Array[StringName] = inv.registered_item_ids()
	var rng: Array[int] = rng_state(session)
	var before: int = session.item_id_allocator().next_dynamic_sequence
	var result: SnowWorkResult = work(session)
	_check(result.outcome == SnowWorkResult.Outcome.DELIVERY_FAILED_CAPACITY, "specific capacity failure")
	_check(result.costs_applied and result.allocation.succeeded and result.cleanup.succeeded, "real paid work/new/lifecycle")
	_check(session.player_runtime().state.essence.current == 70 and session.player_runtime().state.spirit.current == 70, "no refund")
	_check(inv.registered_item_ids() == ids and session.item_instance_index().snapshot_ids() == ids, "no registered/index orphan")
	_check(not session.stack_collection().has_stack(result.reward_id) and inv.direct_parent(result.reward_id) == null, "no stack/containment/ground reward")
	_check(session.item_id_allocator().next_dynamic_sequence == before+1 and rng_state(session) == rng, "failed delivery consumes ID, no RNG")
	await round_trip(tree, session, capture(session), "capacity failure save")
	var next: SessionItemIdAllocationResult = session.item_id_allocator().allocate(inv)
	_check(next.succeeded and next.item_instance_id != result.reward_id and session.item_id_allocator().next_dynamic_sequence == before+2, "next allocation does not reuse failed reward")
	_check(not session.item_instance_index().forget_destroyed_snapshots([cloth], inv), "index cannot destroy live authority")
	session.free()
	await tree.process_frame


func physical_test(tree: SceneTree) -> void:
	var session: WorldSessionController = create_session(tree)
	# TEST-ONLY: no chat beat fires, so the square's wanderers (the 飞刀 travellers) do not
	# step into the walk down to the square; every map's NPCs share the ambience stream.
	session.configure_npc_ambience_random_source(StillAmbience.new())
	var ids: Array[Object] = [session.player_runtime(), session.inventory_state(), session.stack_collection(), session.item_instance_index(), session.item_id_allocator(), session.world_simulation_gate(), session.combat_encounter_coordinator()]
	var snow: WorldMapController = session.resident_map(SnowWorldDefinitions.OUTDOOR_MAP_ID) as WorldMapController
	var mill_map: WorldMapController = session.resident_map(&"snow.workplace_house") as WorldMapController
	var bank_map: WorldMapController = session.resident_map(&"snow.bank_house") as WorldMapController
	var work: WorkService = mill_map.service(&"snow.workplace.mill") as WorkService
	var residents: int = session.resident_map_count()
	var npcs: int = session.world_npcs().size()
	# Since the remap the mill and the bank are their own maps, joined to the street by doors.
	_check(GameContent.catalog().zone(&"snow.workplace").map_id == &"snow.workplace_house" and GameContent.catalog().zone(&"snow.bank").map_id == &"snow.bank_house" and mill_map != snow, "remap: the mill and the bank are on their own maps, not the town's")
	_check(GameContent.catalog().portal(&"snow.mstreet2.east").destination_map_id == &"snow.workplace_house" and GameContent.catalog().portal(&"snow.workplace.west").destination_map_id == SnowWorldDefinitions.OUTDOOR_MAP_ID, "remap: the mill's door joins mstreet2 and the workplace both ways")
	var street_join: Vector2 = MapPlaces.doorway(snow, &"snow.square", &"snow.mstreet1")
	for entry: Array in [[snow, &"snow.mstreet1", MapPlaces.zone_centre(snow, &"snow.mstreet1")], [snow, &"snow.mstreet2", MapPlaces.zone_centre(snow, &"snow.mstreet2")], [mill_map, &"snow.workplace", MapPlaces.zone_centre(mill_map, &"snow.workplace")], [snow, &"snow.square", street_join + Vector2(0, 24)], [snow, &"snow.mstreet1", street_join - Vector2(0, 24)]]:
		_check(MapPlacementValidator.is_valid_character_position(entry[0], entry[1], entry[2]), "save position and half-open joins " + str(entry[1]) + str(entry[2]))
	var owner: StringName = MapPlaces.seam_owner(snow, &"snow.square", &"snow.mstreet1")
	var other: StringName = &"snow.mstreet1" if owner == &"snow.square" else &"snow.square"
	_check(MapPlacementValidator.is_valid_character_position(snow, owner, street_join) and not MapPlacementValidator.is_valid_character_position(snow, other, street_join), "half-open join: the line itself is %s's" % owner)
	# S7B opens mstreet2 north; the Workplace north wall remains closed.
	var mstreet1: Rect2 = MapPlaces.zone_rect(snow, &"snow.mstreet1")
	var mill: Rect2 = MapPlaces.zone_rect(mill_map, &"snow.workplace")
	for entry: Array in [[snow, &"snow.mstreet1", Vector2(mstreet1.end.x - 10, mstreet1.position.y + 40)], [mill_map, &"snow.workplace", Vector2(mill.get_center().x, mill.position.y + 10)], [mill_map, &"snow.workplace", Vector2(mill.end.x - 10, mill.get_center().y)], [mill_map, &"snow.workplace", mill.position + Vector2(20, 30)], [mill_map, &"snow.workplace", Vector2(mill.end.x + 10, mill.get_center().y)]]:
		_check(not MapPlacementValidator.is_valid_character_position(entry[0], entry[1], entry[2]), "reject new walls/void " + str(entry[1]) + str(entry[2]))
	_check(work.request_work().outcome == SnowWorkResult.Outcome.INTERACTION_BLOCKED, "inactive remote work rejected")
	await tree.physics_frame
	_check(await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, SnowWorldDefinitions.INN_EXIT_PORTAL_ID), "out through the Inn's door")
	_check(session.active_map_id() == SnowWorldDefinitions.OUTDOOR_MAP_ID, "real Inn east Area passage")
	_check(await MapPlaces.drive_through(tree, snow, [&"snow.square", SnowWorldDefinitions.MSTREET1_ZONE_ID]), "up the street")
	_check(session.player_runtime().world_location().zone_id == SnowWorldDefinitions.MSTREET1_ZONE_ID, "physical mstreet1")
	_check(await MapPlaces.take_passage(tree, snow, &"snow.mstreet1.west"), "west through the bank's door")
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map_id() == &"snow.bank_house" and session.player_runtime().world_location().zone_id == SnowWorldDefinitions.BANK_ZONE_ID, "S3C opens authored west Bank access")
	_check(await MapPlaces.take_passage(tree, bank_map, &"snow.bank.east"), "back out of the bank")
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map() == snow and await MapPlaces.drive_through(tree, snow, [SnowWorldDefinitions.MSTREET1_ZONE_ID, SnowWorldDefinitions.MSTREET2_ZONE_ID]), "back out and on up the street")
	_check(session.player_runtime().world_location().zone_id == SnowWorldDefinitions.MSTREET2_ZONE_ID, "physical mstreet2")
	_check(await MapPlaces.take_passage(tree, snow, &"snow.mstreet2.east"), "east through the mill's door")
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive(tree, mill_map, MapPlaces.service_spot(mill_map, &"snow.workplace.mill")), "into the mill, up to the millstone")
	_check(work.in_reach() and session.active_map() == mill_map and session.player_runtime().world_location().zone_id == SnowWorldDefinitions.WORKPLACE_ZONE_ID, "physical workplace and proximity")
	var rng: Array[int] = rng_state(session)
	session.world_simulation_gate().acquire(&"s2.test")
	_check(work.request_work().outcome == SnowWorkResult.Outcome.INTERACTION_BLOCKED, "frozen interaction denied")
	session.world_simulation_gate().release(&"s2.test")
	_check(work.request_work().succeeded(), "physical eligible work")
	await round_trip(tree, session, capture(session), "workplace exact position")
	_check(rng_state(session) == rng and work.silver_amount() == 1, "physical work RNG and real silver")
	for obj: Object in ids: _check(is_instance_valid(obj), "same authorities remain alive")
	_check(snow._player == ids[0] and snow._inventory == ids[1] and snow._stacks == ids[2] and snow._item_index == ids[3] and snow._item_id_allocator == ids[4] and snow._world_simulation_gate == ids[5], "same injected map authorities")
	_check(mill_map._player == ids[0] and mill_map._inventory == ids[1] and mill_map._stacks == ids[2] and mill_map._item_index == ids[3] and mill_map._item_id_allocator == ids[4] and mill_map._world_simulation_gate == ids[5], "same injected map authorities on the mill's own map")
	_check(await MapPlaces.take_passage(tree, mill_map, &"snow.workplace.west"), "back out of the mill")
	await tree.physics_frame
	await tree.physics_frame
	_check(session.active_map() == snow and await MapPlaces.drive_through(tree, snow, [SnowWorldDefinitions.MSTREET2_ZONE_ID, SnowWorldDefinitions.MSTREET1_ZONE_ID, &"snow.square"]), "back out and down the street")
	_check(session.player_runtime().world_location().zone_id == &"snow.square", "real workplace west/south return to Square")
	_check(snow.resident_npcs().size() == GameContent.catalog().spawns_for_map(snow.map_id()).reduce(func(total: int, spawn: NpcSpawnDefinition) -> int: return total + spawn.quantity, 0) and session.world_npcs().size() == npcs and session.resident_map_count() == residents, "no new NPC/resident")
	session.free()
	await tree.process_frame


func round_trip(tree: SceneTree, source: WorldSessionController, snapshot: GameSaveSnapshot, label: String) -> void:
	_check(snapshot != null, label + " capture")
	if snapshot == null: return
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_check(encoded.succeeded(), label + " encode")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(decoded.succeeded(), label + " decode")
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(restored.succeeded(), label + " restore " + restored.path)
	if not restored.succeeded(): return
	var fresh: WorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), label + " activation")
	_check(fresh.player_runtime() != source.player_runtime() and fresh.inventory_state() != source.inventory_state(), label + " fresh authorities")
	var after: GameSaveSnapshot = capture(fresh)
	_check(after != null and GameSaveJsonCodec.encode(after).text == encoded.text, label + " entire snapshot exact, no rebirth/refill/reward/RNG")
	_check(fresh.item_instance_index().snapshot_ids() == fresh.inventory_state().registered_item_ids(), label + " index exactly derived")
	fresh.free()
	await tree.process_frame


static func create_session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("雪工", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	return session


static func work(session: WorldSessionController) -> SnowWorkResult:
	var p: WorldPlayerRuntimeState = session.player_runtime()
	return SnowWorkService.work(p.state, p.character_id, p.maximum_encumbrance, p.armor, session.inventory_state(), session.stack_collection(), session.item_instance_index(), session.item_id_allocator())


static func capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-11T00:00:00Z")
	if result.snapshot == null: print("S2 capture rejected: ", result.path, " ", result.detail)
	return result.snapshot


static func rng_state(session: WorldSessionController) -> Array[int]:
	return [session.combat_random_source().capture_random_state().state, session.npc_random_source().capture_random_state().state, session.world_interaction_random_source().capture_random_state().state]


func walk(tree: SceneTree, session: WorldSessionController, action: String, frames: int) -> void:
	var direction: Vector2 = {"move_left":Vector2.LEFT,"move_right":Vector2.RIGHT,"move_up":Vector2.UP,"move_down":Vector2.DOWN}[action]
	for i: int in range(frames):
		MapRoute.press_toward(session.active_map().runtime_player_body(),direction)
		await tree.physics_frame
	MapPlaces.release()
	await tree.physics_frame
	await tree.physics_frame


func walk_to(tree: SceneTree, session: WorldSessionController, action: String, target: float, axis: int) -> void:
	var sign_value: float = -1.0 if action in ["move_left", "move_up"] else 1.0
	var arrived: bool = false
	for i: int in range(700):
		if (session.active_map().runtime_player_body().position[axis] - target) * sign_value >= 0:
			arrived = true
			break
		var direction := Vector2.ZERO
		direction[axis] = sign_value
		MapRoute.press_toward(session.active_map().runtime_player_body(),direction)
		await tree.physics_frame
	MapPlaces.release()
	await tree.physics_frame
	await tree.physics_frame
	_check(arrived, "physical target reachable " + action + str(target))


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("S2: " + label)
