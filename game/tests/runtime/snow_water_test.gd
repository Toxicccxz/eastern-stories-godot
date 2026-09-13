extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Food := preload("res://tests/runtime/snow_dumpling_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
var assertions: int = 0
var failures: Array[String] = []

class RefusingLiquid extends LiquidCollection:
	func register_state(_id: StringName, _state: LiquidState) -> bool:
		return false


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	vine_tests()
	purchase_tests()
	liquid_tests(tree)
	persistence_tests(tree)
	await physical_tests(tree)
	for scenario: String in ["wine", "full", "partial", "empty"]:
		var profile: String = "s6b-%s-%d-%d" % [scenario, OS.get_process_id(), Time.get_ticks_usec()]
		for mode: String in ["write", "read"]:
			var output: Array = []
			var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_snow_water_cold_process.gd", "--", mode, scenario, profile], output, true)
			check(code == 0 and str(output).contains("S6B cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold " + scenario + "/" + mode + ": " + str(output))
	return {"assertions": assertions, "failures": failures}


static func purchase(session: OldPineWorldSessionController) -> WineskinPurchaseResult:
	return WineskinPurchaseService.buy(Food.context(session), session.liquid_collection(), session.item_id_allocator(), session.player_runtime().maximum_encumbrance, Food.definitions())


static func drink(session: OldPineWorldSessionController, id: StringName, available: bool = true, encounter: bool = false) -> LiquidUseResult:
	return HeldLiquidUseService.drink(session.player_runtime(), Food.context(session), session.liquid_collection(), Food.definitions(), id, available, encounter)


static func fill(session: OldPineWorldSessionController, id: StringName, source: bool = true, encounter: bool = false) -> LiquidUseResult:
	return HeldLiquidUseService.fill(session.player_runtime(), Food.context(session), session.liquid_collection(), Food.definitions(), id, true, source, encounter)


func vine_tests() -> void:
	var policy: VineTraversalPolicy = VineTraversalPolicy.new(&"waterfall", &"passage")
	for bound: int in [-1, 0]:
		var rng: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([999])
		var result: VineTraversalPolicyResult = policy.evaluate(bound, rng, true)
		check(result.selected_portal_id == &"waterfall" and result.effective_dodge == bound and not result.draw_performed and rng.call_count() == 0, "owner Type B nonpositive branch without fabricated draw " + str(bound))
		check(policy.evaluate(bound, rng).legacy_ambiguity and rng.call_count() == 0, "technical baseline unchanged")
	for row: Array in [[1,0,"waterfall"], [5,4,"waterfall"], [6,4,"waterfall"], [6,5,"passage"]]:
		var rng: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([row[1]])
		var result: VineTraversalPolicyResult = policy.evaluate(row[0], rng, true)
		check(result.selected_portal_id == StringName(row[2]) and rng.requested_bounds() == [row[0]] and rng.call_count() == 1, "epath2::random(dodge)<5 positive exact " + str(row))
	for draw: int in [-1,6]:
		var rng: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([draw])
		check(policy.evaluate(6, rng, true).invalid_draw and rng.call_count() == 1, "invalid positive draw neither clamp nor retry")


func funded(inv: InventoryState = null) -> Finance.Fixture:
	var fixture: Finance.Fixture = Finance.Fixture.new(inv)
	Finance.add_money(fixture.context, Food.SILVER, 1, &"silver")
	Finance.add_money(fixture.context, Food.COIN, 100, &"coin")
	return fixture


func purchase_tests() -> void:
	var definition: LiquidDefinition = Food.definitions().liquid_definition(SourceWineskin.DEFINITION_ID)
	check(SourceWineskin.DISPLAY_NAME == "牛皮酒袋" and SourceWineskin.ALIASES == ["wineskin", "skin"] and SourceWineskin.UNIT == "个", "wineskin.c authored identity")
	check(SourceWineskin.content_name(LiquidState.Content.RED_WINE) == "红酒" and SourceWineskin.content_name(LiquidState.Content.CLEAR_WATER) == "清水", "source liquid display names")
	check(definition.maximum_portions == 15 and definition.hydration == 30 and definition.drunk_apply == 6 and definition.value == 20 and definition.own_weight == 700, "wineskin.c + liquid.c literal numeric facts")
	check(Food.definitions().food_definition(SourceWineskin.DEFINITION_ID) == null and Food.definitions().stack_definition(SourceWineskin.DEFINITION_ID) == null and Food.definitions().weapon_definition(SourceWineskin.DEFINITION_ID) == null and Food.definitions().armor_definition(SourceWineskin.DEFINITION_ID) == null, "ordinary item only; no stack/equip/food")
	definition.value = 999
	check(Food.definitions().liquid_definition(SourceWineskin.DEFINITION_ID).value == 20, "defensive projection")
	for coins: int in [0,100]:
		var fixture: Finance.Fixture = Finance.Fixture.new()
		if coins > 0: Finance.add_money(fixture.context, Food.COIN, coins, &"coin")
		var result: WineskinPurchaseResult = WineskinPurchaseService.buy(fixture.context, LiquidCollection.new(), fixture.allocator, 1000, Food.definitions())
		check(result.affordability.outcome == (0 if coins == 0 else 2) and not result.paid and result.allocation == null and fixture.allocator.next_dynamic_sequence == 1, "source finance 0/2 and coin-only anomaly")
	for defs: NativeItemDefinitionProjections in [null, NativeItemDefinitionProjections.new(), NativeItemDefinitionProjections.new([SourceWineskin.item_definition()], [], [], [], [], [LiquidDefinition.new(SourceWineskin.DEFINITION_ID, 15, 30, 6, 701, 20)])]:
		var fixture: Finance.Fixture = funded()
		var result: WineskinPurchaseResult = WineskinPurchaseService.buy(fixture.context, LiquidCollection.new(), fixture.allocator, 1000, defs)
		check(result.outcome == WineskinPurchaseResult.Outcome.INVALID_OFFER and fixture.context.select(Food.COIN).amount == 100 and fixture.allocator.next_dynamic_sequence == 1, "static malformed before payment")
	var fixture: Finance.Fixture = funded()
	var result: WineskinPurchaseResult = WineskinPurchaseService.buy(fixture.context, LiquidCollection.new(), SessionItemIdAllocator.new(&"overflow", 9223372036854775807), 1000, Food.definitions())
	check(result.paid and result.outcome == WineskinPurchaseResult.Outcome.ALLOCATION_FAILED and fixture.context.select(Food.COIN).amount == 80, "allocation overflow after payment: no refund")
	for capacity: int in [816,817]:
		fixture = funded()
		var liquids: LiquidCollection = LiquidCollection.new()
		result = WineskinPurchaseService.buy(fixture.context, liquids, fixture.allocator, capacity, Food.definitions())
		# Source37 silver + coins(100-20) + wine700 =817; before pay would be837.
		check(result.paid and fixture.context.select(Food.COIN).amount == 80 and fixture.allocator.next_dynamic_sequence == 2, "capacity after20 payment + one allocation")
		check(result.delivered == (capacity == 817), "exact817 postpayment capacity")
		if capacity == 816:
			check(result.outcome == WineskinPurchaseResult.Outcome.DELIVERY_FAILED and result.cleanup.succeeded(), "delivery failure destroys only undelivered product")
			check(not fixture.context.inventory.is_registered(result.item_id) and not fixture.context.index.has_snapshot(result.item_id) and liquids.state(result.item_id) == null, "no orphan/state/index")
	var failing: Finance.FailingRemoval = Finance.FailingRemoval.new()
	failing.block_parentless = true
	fixture = funded(failing)
	var liquids: LiquidCollection = LiquidCollection.new()
	result = WineskinPurchaseService.buy(fixture.context, liquids, fixture.allocator, 816, Food.definitions())
	check(result.paid and result.outcome == WineskinPurchaseResult.Outcome.AUTHORITY_FAILURE and not result.cleanup.succeeded(), "cleanup failure explicit, no refund")
	check(fixture.context.inventory.is_registered(result.item_id) and liquids.state(result.item_id) != null and fixture.context.index.has_snapshot(result.item_id), "failed removal does not discard associations")
	fixture = funded()
	result = WineskinPurchaseService.buy(fixture.context, RefusingLiquid.new(), fixture.allocator, 1000, Food.definitions())
	check(result.paid and result.outcome == WineskinPurchaseResult.Outcome.CREATION_FAILED and result.cleanup.succeeded(), "partial registration cleans parentless object")


func liquid_tests(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Recovery.create_session(tree, Recovery.RandomSequence.new())
	check(Food.earn_and_exchange(session), "two Work and exchange without injected money")
	var first: WineskinPurchaseResult = purchase(session)
	check(first.delivered and Food.context(session).select(Food.SILVER).amount == 1 and Food.context(session).select(Food.COIN).amount == 80, "natural mixed denominations price20")
	var second: WineskinPurchaseResult = purchase(session)
	check(second.delivered and second.item_id != first.item_id, "unlimited independent IDs")
	var state: LiquidState = session.liquid_collection().state(first.item_id)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rng: Array[int] = Work.rng_state(session)
	var sequence: int = session.item_id_allocator().next_dynamic_sequence
	check(state.content == LiquidState.Content.RED_WINE and state.remaining == 15, "fresh wine not empty/water")
	check(drink(session, first.item_id).outcome == LiquidUseResult.Outcome.ALCOHOL_DEFERRED and state.remaining == 15 and player.state.recovery.water == 400, "alcohol mutation-free refusal")
	check(fill(session, first.item_id, false).outcome == LiquidUseResult.Outcome.NO_WATER_SOURCE and state.content == LiquidState.Content.RED_WINE, "no source no discard")
	check(fill(session, first.item_id).discarded_wine and state.content == LiquidState.Content.CLEAR_WATER and state.remaining == 15 and player.state.recovery.water == 400, "source fill overrides wine without hydrating Player")
	check(drink(session, first.item_id).outcome == LiquidUseResult.Outcome.TOO_FULL and state.remaining == 15, "400 precheck refuses")
	check(session.advance_player_recovery(12.0).opportunities == 1 and player.state.recovery.water == 399, "S5B natural metabolism reaches399")
	check(drink(session, first.item_id).outcome == LiquidUseResult.Outcome.DRANK and player.state.recovery.water == 429 and state.remaining == 14, "source liquid.c 399+30, no clamp")
	check(session.advance_player_recovery(29*12.0).opportunities == 29 and player.state.recovery.water == 400, "29 opportunities from429 to400")
	check(drink(session, first.item_id).outcome == LiquidUseResult.Outcome.TOO_FULL and state.remaining == 14, "400 remains refused")
	check(session.advance_player_recovery(12.0).opportunities == 1 and player.state.recovery.water == 399, "30th permits next drink")
	check(drink(session, first.item_id).succeeded() and player.state.recovery.water == 429 and state.remaining == 13, "renewable second dose")
	check(fill(session, first.item_id).succeeded() and state.remaining == 15 and player.state.recovery.water == 429, "partial clear refill no Player change")
	# Explicit boundary fixture; not the natural-water399 journey above.
	player.state.recovery.water = 0
	for remaining: int in range(14, -1, -1):
		if player.state.recovery.water >= 400: player.state.recovery.water = 0
		var before: int = player.state.recovery.water
		check(drink(session, first.item_id).succeeded() and state.remaining == remaining and player.state.recovery.water == before+30, "exact decrement +30 " + str(remaining))
	check(session.inventory_state().is_registered(first.item_id) and session.item_instance_index().has_snapshot(first.item_id) and state.remaining == 0 and session.inventory_state().own_weight(first.item_id) == 700, "empty item persists at weight700")
	check(drink(session, first.item_id).outcome == LiquidUseResult.Outcome.EMPTY and state.remaining == 0, "empty no dose")
	check(fill(session, first.item_id).succeeded() and state.remaining == 15, "same empty ID refill")
	player.busy.start_busy(2)
	check(drink(session, first.item_id).outcome == LiquidUseResult.Outcome.BUSY and fill(session, first.item_id).outcome == LiquidUseResult.Outcome.BUSY, "busy no clear/advance")
	check(player.busy.is_busy(), "blocked actions retain existing busy")
	player.busy.advance()
	player.busy.advance()
	check(drink(session, first.item_id, true, true).outcome == LiquidUseResult.Outcome.COMBAT_BLOCKED, "active encounter blocks even without relationship")
	check(fill(session, first.item_id, true, true).outcome == LiquidUseResult.Outcome.COMBAT_BLOCKED and state.remaining == 15 and not player.busy.is_busy(), "encounter Fill also blocks without source busy2")
	check(fill(session, first.item_id).succeeded(), "normal action after encounter boundary clears")
	check(drink(session, first.item_id, false).outcome == LiquidUseResult.Outcome.INTERACTION_BLOCKED, "closed runtime rejected")
	var wrong_owner: MoneyInventoryContext = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(&"other", player.state.equipment, player.armor), session.inventory_state(), session.stack_collection(), session.item_instance_index())
	check(HeldLiquidUseService.drink(player, wrong_owner, session.liquid_collection(), Food.definitions(), first.item_id, true).outcome == LiquidUseResult.Outcome.AUTHORITY_FAILURE and HeldLiquidUseService.fill(player, wrong_owner, session.liquid_collection(), Food.definitions(), first.item_id, true, true).outcome == LiquidUseResult.Outcome.AUTHORITY_FAILURE, "wrong character authority rejected for both actions")
	for parent: ContainmentEndpoint in [ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"ground"), ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, second.item_id), ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, &"npc")]:
		session.inventory_state()._apply_reparent(first.item_id, parent)
		check(drink(session, first.item_id).outcome == LiquidUseResult.Outcome.NOT_DIRECT_HELD and fill(session, first.item_id).outcome == LiquidUseResult.Outcome.NOT_DIRECT_HELD, "direct not root/ground/NPC " + str(parent.kind))
	session.inventory_state()._apply_reparent(first.item_id, Food.context(session).endpoint())
	check(fill(session, first.item_id).succeeded(), "direct ownership restored, same item usable")
	check(Work.rng_state(session) == rng and session.item_id_allocator().next_dynamic_sequence == sequence, "Fill/Drink/time consume no gameplay RNG/item IDs")
	check(player.state.conditions.size() == 0 and session.liquid_collection().state(second.item_id).content == LiquidState.Content.RED_WINE and session.liquid_collection().state(second.item_id).remaining == 15, "no drunk and other wine untouched")
	var independent: OldPineWorldSessionController = Recovery.create_session(tree, Recovery.RandomSequence.new())
	check(independent.liquid_collection().instance_ids().is_empty(), "independent Session collection")
	independent.free()
	session.free()


func persistence_tests(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Recovery.create_session(tree, Recovery.RandomSequence.new())
	Food.earn_and_exchange(session)
	var ids: Array[StringName] = []
	for i: int in range(4): ids.append(purchase(session).item_id)
	for i: int in range(1,4):
		fill(session, ids[i])
		session.liquid_collection().state(ids[i]).remaining = [15,15,14,0][i] # Persistence boundary fixtures.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	check(snapshot != null and snapshot.items.schema_version == 3 and snapshot.metadata.schema_version == 2, "independent item3/root2")
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	check(decoded.succeeded(), "strict liquid codec")
	var restored: NativeItemRestoreCompositionResult = NativeItemPersistenceComposition.restore(decoded.snapshot.items, Food.definitions(), decoded.snapshot.item_id_allocator)
	check(restored.succeeded, "fresh graph restore")
	if restored.succeeded:
		for id: StringName in ids:
			var original: LiquidState = session.liquid_collection().state(id)
			var other: LiquidState = restored.domain_state.liquid_collection.state(id)
			check(other != original and other.content == original.content and other.remaining == original.remaining, "same ID fresh state exact contents")
		check(restored.domain_state.liquid_collection != session.liquid_collection() and restored.domain_state.inventory.registered_item_ids() == session.inventory_state().registered_item_ids(), "fresh aggregate same IDs")
		check(restored.allocator.next_dynamic_sequence == session.item_id_allocator().next_dynamic_sequence, "restore zero allocations")
	var base: Dictionary = JSON.parse_string(encoded.text)
	for mutation: String in ["missing-array", "missing-record", "duplicate", "orphan", "non-liquid", "negative", "overfull", "unknown-content", "unknown-key", "missing-key", "bad-weight", "v2-extra", "v2-forged", "v1-forged"]:
		var data: Dictionary = base.duplicate(true)
		match mutation:
			"missing-array": data.items.erase("liquid_consumables")
			"missing-record": data.items.liquid_consumables.pop_back()
			"duplicate": data.items.liquid_consumables.append(data.items.liquid_consumables[0].duplicate(true))
			"orphan": data.items.liquid_consumables[0].item_instance_id = "absent"
			"non-liquid":
				for item: Dictionary in data.items.records:
					if item.item_definition_id == String(SourceSilver.DEFINITION_ID): data.items.liquid_consumables[0].item_instance_id = item.item_instance_id
			"negative": data.items.liquid_consumables[0].remaining = "-1"
			"overfull": data.items.liquid_consumables[0].remaining = "16"
			"unknown-content": data.items.liquid_consumables[0].content = "ALCOHOL"
			"unknown-key": data.items.liquid_consumables[0].water = "1"
			"missing-key": data.items.liquid_consumables[0].erase("remaining")
			"bad-weight":
				for item: Dictionary in data.items.records:
					if item.item_definition_id == String(SourceWineskin.DEFINITION_ID): item.own_weight = "699"
			"v2-extra": data.items.schema_version = 2
			"v2-forged", "v1-forged":
				data.items.schema_version = 2 if mutation == "v2-forged" else 1
				data.items.erase("liquid_consumables")
				if mutation == "v1-forged": data.items.erase("food_consumables")
		var result: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(data))
		check(not result.succeeded() or not NativeItemStateValidator.validate(result.snapshot.items, Food.definitions()).succeeded, "strict rejects " + mutation)
	session.free()
	# Legal old schemas without liquid content upgrade only their representation.
	session = Recovery.create_session(tree, Recovery.RandomSequence.new())
	base = JSON.parse_string(GameSaveJsonCodec.encode(Work.capture(session)).text)
	for version: int in [1,2]:
		var data: Dictionary = base.duplicate(true)
		data.items.schema_version = version
		data.items.erase("liquid_consumables")
		if version == 1: data.items.erase("food_consumables")
		var result: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(data))
		check(result.succeeded() and result.snapshot.items.schema_version == 3 and result.snapshot.items.liquid_consumable_records.is_empty() and NativeItemStateValidator.validate(result.snapshot.items, Food.definitions()).succeeded, "strict legal legacy item " + str(version))
	session.free()


func physical_tests(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Recovery.create_session(tree, Recovery.RandomSequence.new())
	check(session.get_node_or_null("HeldLiquidUI") != null and not session.waterfall_water_available(), "Session UI, Inn no water source")
	Food.earn_and_exchange(session)
	purchase(session)
	await tree.process_frame
	await tree.process_frame
	var panel: HeldLiquidPanel = session.get_node("HeldLiquidUI") as HeldLiquidPanel
	check(panel._panel.visible and panel._drink.text.contains("酒精暂未开放"), "fresh wine UI truthful")
	var map: OldPineOutdoorController = session.resident_map(OldPineWorldDefinitions.OUTDOOR_MAP_ID) as OldPineOutdoorController
	# Typed/geometry tests only; final acceptance uses real input, not these assignments.
	check(session.handoff_to(OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID, OldPineWorldDefinitions.WATERFALL_LANDING_SPAWN_POINT_ID).succeeded(), "fixture waterfall handoff")
	await tree.physics_frame
	map.player_body.global_position = Vector2(1200,900)
	map.player_runtime().set_world_location(map.location_for_zone(OldPineWorldDefinitions.WATERFALL_BASIN_ZONE_ID))
	check(map.can_fill_at_waterfall() and session.waterfall_water_available(), "valid physical source")
	map.player_body.global_position = Vector2(1200,780)
	check(not map.can_fill_at_waterfall(), "same zone but120 distance >96")
	map.player_body.global_position = Vector2(1200,900)
	map.player_runtime().set_world_location(map.location_for_zone(OldPineWorldDefinitions.RIVER_GORGE_ZONE_ID))
	check(not map.can_fill_at_waterfall(), "wrongzone even ifcoordinatesnear")
	tree.paused = true
	await tree.process_frame
	await tree.process_frame
	check(not session.liquid_interaction_available(), "Pause blocks stale interaction")
	check(not panel._panel.visible, "Pause also hides presentation without advancing Session")
	tree.paused = false
	session.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("S6B: " + label)
