extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const COIN = CurrencyDenomination.Value.COIN
const SILVER = CurrencyDenomination.Value.SILVER
var assertions: int = 0
var failures: Array[String] = []

class RefusingFood extends FoodCollection:
	func register_state(_id: StringName, _state: FoodState) -> bool:
		return false

class RefusingIndex extends WorldItemInstanceIndex:
	func register_snapshot(item: ItemInstance) -> bool:
		if item.item_definition_id == SourceDumpling.DEFINITION_ID:
			return false
		return super.register_snapshot(item)


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	definition_tests()
	purchase_failures()
	await consumption_and_save(tree)
	await physical_availability(tree)
	var profile: String = "s4b-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for mode: String in ["write", "read", "finish", "absent"]:
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_snow_dumpling_cold_process.gd", "--", mode, profile], output, true)
		check(code == 0 and str(output).contains("S4B cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold " + mode + ": " + str(output))
	return {"assertions": assertions, "failures": failures}


static func definitions() -> NativeItemDefinitionProjections:
	return OldPineNativeItemDefinitionProjections.create(WorldContentRevision.Value.SOURCE_ENTRY_V1)


static func context(session: OldPineWorldSessionController) -> MoneyInventoryContext:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), session.inventory_state(), session.stack_collection(), session.item_instance_index())


static func purchase(session: OldPineWorldSessionController) -> DumplingPurchaseResult:
	return DumplingPurchaseService.buy(context(session), session.food_collection(), session.item_id_allocator(), session.player_runtime().maximum_encumbrance, definitions())


static func eat(session: OldPineWorldSessionController, id: StringName) -> FoodUseResult:
	return HeldFoodUseService.eat(session.player_runtime(), context(session), session.food_collection(), definitions(), id, true)


static func earn_and_exchange(session: OldPineWorldSessionController) -> bool:
	return Work.work(session).outcome == SnowWorkResult.Outcome.SUCCESS and Work.work(session).outcome == SnowWorkResult.Outcome.SUCCESS and BankConversionService.convert(context(session), session.item_id_allocator(), session.player_runtime().maximum_encumbrance, SILVER, COIN, 1).succeeded()


func definition_tests() -> void:
	var food: FoodDefinition = definitions().food_definition(SourceDumpling.DEFINITION_ID)
	check(SourceDumpling.DISPLAY_NAME == "包子" and SourceDumpling.ALIAS == "dumpling" and SourceDumpling.UNIT == "个", "dumpling.c name alias unit")
	check(food.initial_value == 15 and food.own_weight == 80 and food.initial_portions == 3 and food.food_supply == 60, "dumpling.c literal facts")
	check(definitions().stack_definition(SourceDumpling.DEFINITION_ID) == null and definitions().weapon_definition(SourceDumpling.DEFINITION_ID) == null and definitions().armor_definition(SourceDumpling.DEFINITION_ID) == null, "ordinary noncombined food")
	food.initial_value = 999
	check(definitions().food_definition(SourceDumpling.DEFINITION_ID).initial_value == 15, "content projection independent")
	for id: StringName in [&"es2:obj/example/wineskin", &"es2:obj/example/dagger", &"es2:obj/example/chickenleg", &"es2:obj/example/cake"]:
		check(not definitions().has_item_definition(id), "deferred source goods " + String(id))


func funded(inv: InventoryState = null, coin: int = 100) -> Finance.Fixture:
	var f: Finance.Fixture = Finance.Fixture.new(inv)
	Finance.add_money(f.context, SILVER, 1, &"silver")
	Finance.add_money(f.context, COIN, coin, &"coin")
	return f


func purchase_failures() -> void:
	for coin: int in [0, 100]:
		var f: Finance.Fixture = Finance.Fixture.new()
		if coin > 0: Finance.add_money(f.context, COIN, coin, &"coin")
		var result: DumplingPurchaseResult = DumplingPurchaseService.buy(f.context, FoodCollection.new(), f.allocator, 1000, definitions())
		check(result.affordability.outcome == (0 if coin == 0 else 2), "finance.c 0 versus 2, coin alone not sufficient denomination")
		check(not result.paid and result.allocation == null and f.allocator.next_dynamic_sequence == 1, "affordability no allocation")
	for defs: NativeItemDefinitionProjections in [null, NativeItemDefinitionProjections.new(), NativeItemDefinitionProjections.new([SourceDumpling.item_definition()], [], [], [], [FoodDefinition.new(SourceDumpling.DEFINITION_ID, 3, 60, 999, 80)])]:
		var f: Finance.Fixture = funded()
		var result: DumplingPurchaseResult = DumplingPurchaseService.buy(f.context, FoodCollection.new(), f.allocator, 1000, defs)
		check(result.outcome == DumplingPurchaseResult.Outcome.INVALID_OFFER and f.context.select(COIN).amount == 100 and f.allocator.next_dynamic_sequence == 1, "static malformed offer rejected before payment")
	var f: Finance.Fixture = funded()
	f.allocator = SessionItemIdAllocator.new(&"overflow", 9223372036854775807)
	var result: DumplingPurchaseResult = DumplingPurchaseService.buy(f.context, FoodCollection.new(), f.allocator, 1000, definitions())
	check(result.paid and not result.delivered and result.outcome == DumplingPurchaseResult.Outcome.ALLOCATION_FAILED and f.context.select(COIN).amount == 85, "overflow after payment, no refund")
	var failing: Finance.FailingRemoval = Finance.FailingRemoval.new()
	failing.block_id = &"coin"
	f = funded(failing, 15)
	result = DumplingPurchaseService.buy(f.context, FoodCollection.new(), f.allocator, 1000, definitions())
	check(result.outcome == DumplingPurchaseResult.Outcome.PAYMENT_FAILED and result.payment.mutations.size() == 1 and result.allocation == null and f.allocator.next_dynamic_sequence == 1, "coin depletion lifecycle failure stops before goods")
	for capacity: int in [201, 202]:
		f = funded()
		var foods: FoodCollection = FoodCollection.new()
		result = DumplingPurchaseService.buy(f.context, foods, f.allocator, capacity, definitions())
		# Source coins 100->85, silver weighs37: 122+80=202; prepayment137+80=217.
		check(f.context.select(COIN).amount == 85 and f.allocator.next_dynamic_sequence == 2, "capacity checked AFTER payment/allocation")
		check(result.delivered == (capacity == 202), "exact postpayment full weight admission " + str(capacity))
		if capacity == 201:
			check(result.paid and result.outcome == DumplingPurchaseResult.Outcome.DELIVERY_FAILED and result.cleanup.succeeded(), "capacity paid/no product with authoritative cleanup")
			check(not f.context.inventory.is_registered(result.item_id) and not f.context.index.has_snapshot(result.item_id) and foods.state(result.item_id) == null, "no parentless orphan")
	failing = Finance.FailingRemoval.new()
	failing.block_parentless = true
	f = funded(failing)
	var foods: FoodCollection = FoodCollection.new()
	result = DumplingPurchaseService.buy(f.context, foods, f.allocator, 201, definitions())
	check(result.outcome == DumplingPurchaseResult.Outcome.AUTHORITY_FAILURE and result.paid and not result.cleanup.succeeded(), "cleanup failure explicit; not fake success")
	check(f.context.inventory.is_registered(result.item_id) and f.context.index.has_snapshot(result.item_id) and foods.state(result.item_id) != null, "failed removal retains food/index until authoritative removal")
	f = funded()
	result = DumplingPurchaseService.buy(f.context, RefusingFood.new(), f.allocator, 1000, definitions())
	check(result.paid and result.outcome == DumplingPurchaseResult.Outcome.CREATION_FAILED and result.cleanup.succeeded() and not f.context.inventory.is_registered(result.item_id) and not f.context.index.has_snapshot(result.item_id), "partially registered parentless product cleanup")
	f = funded()
	var replacement: RefusingIndex = RefusingIndex.new()
	for id: StringName in f.context.inventory.registered_item_ids(): replacement.register_snapshot(f.context.index.resolve(id))
	f.context.index = replacement
	result = DumplingPurchaseService.buy(f.context, FoodCollection.new(), f.allocator, 1000, definitions())
	check(result.paid and result.cleanup.succeeded() and not f.context.inventory.is_registered(result.item_id), "index registration failure cleans only created parentless item")


func consumption_and_save(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	check(earn_and_exchange(session), "real work rewards + source Bank composition")
	var rng: Array[int] = Work.rng_state(session)
	var sequence: int = session.item_id_allocator().next_dynamic_sequence
	var first: DumplingPurchaseResult = purchase(session)
	check(first.paid and first.delivered and first.price == 15, "one product bought")
	check(context(session).select(SILVER).amount == 1 and context(session).select(COIN).amount == 85, "natural source denomination payment")
	check(session.item_id_allocator().next_dynamic_sequence == sequence + 1 and session.inventory_state().own_weight(first.item_id) == 80, "fresh ID and weight80")
	check(eat(session, first.item_id).outcome == FoodUseResult.Outcome.TOO_FULL and session.player_runtime().state.recovery.food == 400, "fresh food400 refuses")
	check(session.food_collection().state(first.item_id).remaining_portions == 3 and session.food_collection().state(first.item_id).current_value == 15, "refusal preserves untouched product")
	var second: DumplingPurchaseResult = purchase(session)
	check(second.delivered and second.item_id != first.item_id and session.food_collection().instance_ids().size() == 2, "unlimited fresh independent products; no merge")
	for row: Array in [[399,459], [340,400]]:
		var id: StringName = first.item_id if row[0] == 399 else second.item_id
		session.player_runtime().state.recovery.food = row[0]
		var result: FoodUseResult = eat(session, id)
		check(result.outcome == FoodUseResult.Outcome.ATE and result.food_after == row[1], "food.c precheck and unclamped +60 " + str(row))
		check(session.food_collection().state(id).remaining_portions == 2 and session.food_collection().state(id).current_value == 0, "value0 + exact decrement")
	var snap: GameSaveSnapshot = Work.capture(session)
	check(snap != null and snap.items.schema_version == 2 and snap.items.food_consumable_records.size() == 2, "partial foods captured via native item schema2")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snap).text)
	check(decoded.succeeded(), "strict codec roundtrip")
	var restore: NativeItemRestoreCompositionResult = NativeItemPersistenceComposition.restore(decoded.snapshot.items, definitions(), decoded.snapshot.item_id_allocator)
	check(restore.succeeded, "fresh graph B restored")
	if restore.succeeded:
		check(restore.domain_state.inventory != session.inventory_state(), "fresh graph objects")
		check(restore.domain_state.food_collection != session.food_collection() and restore.domain_state.food_collection.state(first.item_id) != session.food_collection().state(first.item_id), "fresh food authorities, exact IDs")
		check(restore.domain_state.food_collection.state(first.item_id).remaining_portions == 2 and restore.domain_state.food_collection.state(second.item_id).current_value == 0, "partial values preserved")
	strict_save_tests(snap)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.recovery.food = 0
	player.relationship.add_opponent(&"fixture-opponent")
	check(eat(session, first.item_id).outcome == FoodUseResult.Outcome.COMBAT_BLOCKED and player.state.recovery.food == 0, "active relationship blocks food, no invented busy")
	player.relationship.remove_opponent(&"fixture-opponent")
	player.busy.start_busy(1)
	check(eat(session, first.item_id).outcome == FoodUseResult.Outcome.BUSY and player.state.recovery.food == 0, "existing ordinary busy blocks")
	player.busy.advance()
	for parent: ContainmentEndpoint in [ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"snow.inn"), ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, second.item_id), ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, &"npc")]:
		session.inventory_state()._apply_reparent(first.item_id, parent)
		check(eat(session, first.item_id).outcome == FoodUseResult.Outcome.NOT_DIRECT_HELD and player.state.recovery.food == 0, "no root-owned/ground/NPC food")
	session.inventory_state()._apply_reparent(first.item_id, context(session).endpoint())
	check(HeldFoodUseService.eat(player, context(session), session.food_collection(), definitions(), first.item_id, false).outcome == FoodUseResult.Outcome.INTERACTION_BLOCKED, "caller runtime gate respected")
	var third: DumplingPurchaseResult = purchase(session)
	for portions: int in [2,1,0]:
		var result: FoodUseResult = eat(session, third.item_id)
		check(result.outcome == FoodUseResult.Outcome.ATE and player.state.recovery.food == (3 - portions) * 60, "three uses from food0:60/120/180")
		if portions > 0:
			check(session.food_collection().state(third.item_id).remaining_portions == portions, "remaining " + str(portions))
	check(not session.inventory_state().is_registered(third.item_id) and not session.item_instance_index().has_snapshot(third.item_id) and session.food_collection().state(third.item_id) == null, "final bite lifecycle removes all association")
	check(Work.rng_state(session) == rng, "all three gameplay RNG streams unchanged")
	check(session.food_collection().state(first.item_id).remaining_portions == 2, "other product unaffected")
	# Failure seam is test-only; source resource/value/decrement remain reached.
	var failing_inventory: Finance.FailingRemoval = Finance.FailingRemoval.new()
	var failed_context: MoneyInventoryContext = MoneyInventoryContext.new(context(session).owner, failing_inventory, CombinedStackCollection.new(), WorldItemInstanceIndex.new())
	Finance.add_money(failed_context, SILVER, 1, &"failure-silver")
	Finance.add_money(failed_context, COIN, 100, &"failure-coin")
	var failed_foods: FoodCollection = FoodCollection.new()
	var doomed: DumplingPurchaseResult = DumplingPurchaseService.buy(failed_context, failed_foods, SessionItemIdAllocator.new(&"doomed", 1), 1000, definitions())
	player.state.recovery.food = 0
	for bite: int in range(2):
		check(HeldFoodUseService.eat(player, failed_context, failed_foods, definitions(), doomed.item_id, true).outcome == FoodUseResult.Outcome.ATE, "pre-terminal bite " + str(bite))
	failing_inventory.block_id = doomed.item_id
	var final_failure: FoodUseResult = HeldFoodUseService.eat(player, failed_context, failed_foods, definitions(), doomed.item_id, true)
	check(final_failure.accepted_bite and final_failure.outcome == FoodUseResult.Outcome.AUTHORITY_FAILURE and player.state.recovery.food == 180, "terminal removal failure leaves food +60 spent")
	check(failed_foods.state(doomed.item_id).remaining_portions == 0 and failed_foods.state(doomed.item_id).current_value == 0 and failed_context.index.has_snapshot(doomed.item_id), "no rollback or prematurely forgotten food")
	var invalid: NativeItemStateSnapshot = NativeItemStateSnapshot.new(2, [NativeItemRecord.new(doomed.item_id, SourceDumpling.DEFINITION_ID, 80, failed_context.endpoint())], [], [], [], [NativeFoodConsumableRecord.new(doomed.item_id, 0, 0)])
	check(NativeItemStateValidator.validate(invalid, definitions()).outcome == NativeItemStateValidationResult.Outcome.INVALID_FOOD_RECORD, "reached live zero-portions state cannot Save")
	var independent: OldPineWorldSessionController = Work.create_session(tree)
	check(independent.food_collection().instance_ids().is_empty(), "independent Session collections")
	independent.free()
	session.free()
	await tree.process_frame


func strict_save_tests(snapshot: GameSaveSnapshot) -> void:
	var base: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(snapshot).text)
	for portions: int in [-1,0,1,2,3,4]:
		for value: int in [-1,0,15,16]:
			var modified: Dictionary = base.duplicate(true)
			modified.items.food_consumables[0].remaining_portions = str(portions)
			modified.items.food_consumables[0].current_value = str(value)
			var decoded: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(modified))
			var accepted: bool = decoded.succeeded() and NativeItemStateValidator.validate(decoded.snapshot.items, definitions()).succeeded
			check(accepted == ((portions == 3 and value == 15) or (portions in [1,2] and value == 0)), "literal live dumpling pairs " + str([portions,value]))
	for mutation: String in ["duplicate", "dangling", "nonfood", "missing", "unknown-key", "missing-key", "v1-extra", "v1-food", "unknown-version"]:
		var modified: Dictionary = base.duplicate(true)
		match mutation:
			"duplicate": modified.items.food_consumables.append(modified.items.food_consumables[0].duplicate(true))
			"dangling": modified.items.food_consumables[0].item_instance_id = "absent"
			"nonfood":
				for item: Dictionary in modified.items.records:
					if item.item_definition_id == "es2:obj/money/silver": modified.items.food_consumables[0].item_instance_id = item.item_instance_id
			"missing": modified.items.food_consumables.clear()
			"unknown-key": modified.items.extra = 1
			"missing-key": modified.items.erase("food_consumables")
			"v1-extra": modified.items.schema_version = 1
			"v1-food":
				modified.items.schema_version = 1
				modified.items.erase("food_consumables")
			"unknown-version": modified.items.schema_version = 99
		var decoded: GameSaveResult = GameSaveJsonCodec.decode(JSON.stringify(modified))
		check(not decoded.succeeded() or not NativeItemStateValidator.validate(decoded.snapshot.items, definitions()).succeeded, "strict schema/definition rejects " + mutation)


func physical_availability(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	var inn: SnowInnController = session.active_map() as SnowInnController
	check(not inn.can_purchase_here(), "birth does not overlap waiter")
	var walk: RefCounted = Work.new()
	await walk.walk_to(tree, session, "move_left", -225, 0)
	await walk.walk_to(tree, session, "move_up", -90, 1)
	check(inn.can_purchase_here() and walk._failures.is_empty(), "CharacterBody physically reaches static contact")
	check(inn.request_dumpling().affordability.outcome == MoneyAffordabilityResult.Outcome.INSUFFICIENT_TOTAL, "real controller no free food")
	check(session.get_node_or_null("HeldFoodUI") != null, "one Session-owned map-independent food view")
	session.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("S4B: " + label)
