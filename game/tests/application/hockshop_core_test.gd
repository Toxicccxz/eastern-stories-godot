extends RefCounted

const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Food := preload("res://tests/runtime/snow_dumpling_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
const SHORT: StringName = &"es2:d/oldpine/obj/short_sword"
const LONG: StringName = &"es2:d/oldpine/obj/long_sword"
const LEATHER: StringName = &"es2:d/oldpine/obj/leather"
const O := HockshopValuationResult.Outcome
var assertions: int = 0
var failures: Array[String] = []

class Fixture extends Finance.Fixture:
	var foods: FoodCollection = FoodCollection.new()
	var liquids: LiquidCollection = LiquidCollection.new()
	func quote(id: StringName = &"sale") -> HockshopValuationResult:
		return HockshopValuation.appraise(context, foods, liquids, id)
	func sell(capacity: int = 150000, id: StringName = &"sale") -> HockshopSellResult:
		return HockshopSellService.sell(context, foods, liquids, allocator, capacity, id)

class TraceInventory extends Finance.FailingRemoval:
	var trace: Array[String] = []
	func register_item(item: ItemInstance, weight: int = 0) -> bool:
		trace.append("create:" + String(item.item_instance_id))
		return super.register_item(item, weight)
	func _remove_registered_leaf(id: StringName) -> bool:
		trace.append("remove:" + String(id))
		return super._remove_registered_leaf(id)

class RefusingIndex extends WorldItemInstanceIndex:
	func register_snapshot(_item: ItemInstance) -> bool:
		return false

class RefusingEquipment extends EquipmentState:
	func unwield(_id: StringName) -> EquipmentTransitionResult:
		return EquipmentTransitionResult.new()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	valuation_tests()
	ownership_tests()
	payout_tests()
	lifecycle_tests()
	failure_tests()
	persistence_tests(tree)
	await tree.process_frame
	return {"assertions": assertions, "failures": failures}


static func add_item(context: MoneyInventoryContext, foods: FoodCollection, liquids: LiquidCollection,
	definition_id: StringName, id: StringName = &"sale") -> void:
	var weights: Dictionary[StringName, int] = {SHORT:3000, LONG:7000, LEATHER:6000,
		SourcePlayerCloth.DEFINITION_ID:3000, SourceDumpling.DEFINITION_ID:80, SourceWineskin.DEFINITION_ID:700}
	var item: ItemInstance = ItemInstance.new(id, definition_id)
	context.inventory.register_item(item, weights.get(definition_id, 1))
	context.index.register_snapshot(item)
	context.inventory._apply_reparent(id, context.endpoint())
	if definition_id == SourceDumpling.DEFINITION_ID:
		foods.register_state(id, FoodState.new(3, 15))
	if definition_id == SourceWineskin.DEFINITION_ID:
		liquids.register_state(id, SourceWineskin.fresh_state())


func fixture(definition_id: StringName = SHORT, inventory: InventoryState = null) -> Fixture:
	var f: Fixture = Fixture.new(inventory)
	add_item(f.context, f.foods, f.liquids, definition_id)
	return f


## Independent exact authority fingerprint (test-only; never a gameplay payload).
func fingerprint(f: Fixture) -> String:
	var rows: Array = [f.allocator.scope, f.allocator.next_dynamic_sequence, f.context.index.snapshot_ids()]
	for id: StringName in f.context.inventory.registered_item_ids():
		var parent: ContainmentEndpoint = f.context.inventory.direct_parent(id)
		var item: ItemInstance = f.context.index.resolve(id)
		rows.append([id, item.item_definition_id if item != null else &"", f.context.inventory.own_weight(id),
			-1 if parent == null else parent.kind, &"" if parent == null else parent.endpoint_id])
	for id: StringName in f.context.stacks.stack_instance_ids():
		rows.append([id, f.context.stacks.stack_state(id).amount])
	for id: StringName in f.foods.instance_ids():
		rows.append([id, f.foods.state(id).remaining_portions, f.foods.state(id).current_value])
	for id: StringName in f.liquids.instance_ids():
		rows.append([id, f.liquids.state(id).content, f.liquids.state(id).remaining])
	for ref: EquippedWeaponRef in [f.context.owner.equipment_state.primary_weapon(), f.context.owner.equipment_state.secondary_weapon()]:
		rows.append(null if ref == null else [ref.instance_id, ref.weapon_id, ref.skill_type])
	for slot: StringName in f.context.owner.armor_state.occupied_slots():
		rows.append([slot, f.context.owner.armor_state.item_instance_id_in_slot(slot)])
	return JSON.stringify(rows)


func valuation_tests() -> void:
	# Literal source facts/expected results, never computed from production helper.
	for row: Array in [[SourcePlayerCloth.DEFINITION_ID,0,0,O.WORTHLESS], [SourceDumpling.DEFINITION_ID,15,12,O.SELLABLE],
		[SourceWineskin.DEFINITION_ID,20,16,O.SELLABLE], [SHORT,300,240,O.SELLABLE], [LONG,700,560,O.SELLABLE], [LEATHER,200,160,O.SELLABLE]]:
		var f: Fixture = fixture(row[0])
		var before: String = fingerprint(f)
		var quote: HockshopValuationResult = f.quote()
		check(quote.outcome == row[3] and quote.source_value == row[1] and quote.actual_payout == row[2], "source quote " + str(row))
		check(quote.item_id == &"sale" and quote.definition_id == row[0], "quote exact identity")
		check(fingerprint(f) == before, "appraisal read-only authority fingerprint")
	for row: Array in [[1,1],[2,1],[3,2],[15,12],[20,16],[125,100],[124,99],[1000,800],[-1,-1],[0,-1],[9223372036854775807,-1]]:
		check(HockshopValuation.sell_payout(row[0]) == row[1], "multiply80 then integer divide100/minimum/overflow " + str(row))
	var cloth: Fixture = fixture(SourcePlayerCloth.DEFINITION_ID)
	cloth.context.owner.armor_state._apply_wear(EquippedArmorRef.new(&"sale", Food.definitions().armor_definition(SourcePlayerCloth.DEFINITION_ID)))
	var before: String = fingerprint(cloth)
	check(cloth.sell().valuation.outcome == O.WORTHLESS and fingerprint(cloth) == before, "worthless worn cloth remains worn/no ID")
	var bitten: Fixture = fixture(SourceDumpling.DEFINITION_ID)
	bitten.foods.state(&"sale").consume_portion() # exact existing accepted-bite state transition
	before = fingerprint(bitten)
	check(bitten.quote().outcome == O.WORTHLESS and bitten.sell().valuation.outcome == O.WORTHLESS and fingerprint(bitten) == before, "bitten2/0 not reconstructed15 or destroyed")
	var changed: Fixture = fixture(SourceDumpling.DEFINITION_ID)
	check(changed.quote().actual_payout == 12, "fresh quote before bite")
	changed.foods.state(&"sale").consume_portion()
	check(changed.sell().valuation.outcome == O.WORTHLESS and changed.allocator.next_dynamic_sequence == 1, "execution rereads changed value, not cached quote")
	for pair: Vector2i in [Vector2i(3,-1),Vector2i(3,0),Vector2i(2,15),Vector2i(0,0),Vector2i(4,15)]:
		var f: Fixture = fixture(SourceDumpling.DEFINITION_ID)
		f.foods.state(&"sale").remaining_portions = pair.x
		f.foods.state(&"sale").current_value = pair.y
		before = fingerprint(f)
		check(f.sell().valuation.outcome == O.INVALID_ITEM_STATE and fingerprint(f) == before, "malformed food fail closed " + str(pair))
	for denomination: CurrencyDenomination.Value in [Finance.COIN, Finance.SILVER, Finance.GOLD]:
		var f: Fixture = Fixture.new()
		Finance.add_money(f.context, denomination, 5, &"sale")
		before = fingerprint(f)
		check(f.quote().outcome == O.MONEY_REJECTED and f.sell().valuation.outcome == O.MONEY_REJECTED and fingerprint(f) == before, "money excluded, no convert " + str(denomination))
	var unknown: Fixture = fixture(&"test:unknown")
	check(unknown.sell().valuation.outcome == O.UNSUPPORTED_ITEM and unknown.allocator.next_dynamic_sequence == 1, "unknown != worthless")
	var missing: Fixture = Fixture.new()
	add_item(missing.context, FoodCollection.new(), LiquidCollection.new(), SourceDumpling.DEFINITION_ID)
	check(missing.quote().outcome == O.INVALID_ITEM_STATE, "missing food association")
	missing = Fixture.new()
	add_item(missing.context, FoodCollection.new(), LiquidCollection.new(), SourceWineskin.DEFINITION_ID)
	check(missing.quote().outcome == O.INVALID_ITEM_STATE, "missing liquid association")
	for remaining: int in [-1,16]:
		var f: Fixture = fixture(SourceWineskin.DEFINITION_ID)
		f.liquids.state(&"sale").remaining = remaining
		check(f.sell().valuation.outcome == O.INVALID_ITEM_STATE and f.allocator.next_dynamic_sequence == 1, "malformed liquid")


func ownership_tests() -> void:
	for parent: ContainmentEndpoint in [ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"ground"),
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, &"npc"), ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, &"bag"),
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, &"corpse")]:
		var f: Fixture = fixture()
		check(f.quote().outcome == O.SELLABLE, "initial quote")
		if parent.kind == ContainmentEndpoint.Kind.ITEM:
			add_item(f.context, f.foods, f.liquids, &"test:holder", parent.endpoint_id)
		f.context.inventory._apply_reparent(&"sale", parent)
		var before: String = fingerprint(f)
		check(f.sell().valuation.outcome == O.NOT_DIRECTLY_HELD and fingerprint(f) == before, "stale quote cannot authorize changed direct owner")
	var f: Fixture = fixture()
	check(f.quote().outcome == O.SELLABLE, "quote before removal")
	ItemLifecycleService.destroy_item(f.context.inventory, f.context.stacks, &"sale", ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, f.context.owner)
	f.context.index.forget_destroyed_snapshots([&"sale"], f.context.inventory)
	check(f.sell().valuation.outcome == O.ITEM_NOT_FOUND and f.allocator.next_dynamic_sequence == 1, "deleted stale ID no allocation")
	f = fixture()
	add_item(f.context, f.foods, f.liquids, SourcePlayerCloth.DEFINITION_ID, &"child")
	f.context.inventory._apply_reparent(&"child", ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, &"sale"))
	check(f.sell().valuation.outcome == O.UNSUPPORTED_ITEM, "supported identity with children not leaf commerce")
	f = fixture()
	f.context.index = WorldItemInstanceIndex.new()
	check(f.sell().outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and f.allocator.next_dynamic_sequence == 1, "missing current index authority")


func payout_tests() -> void:
	# Source240 => silver2 weighs74, coin40 weighs40, sold sword still weighs3000.
	for row: Array in [[114,240,2,40],[50,40,0,40],[90,200,2,0],[20,0,0,0],[74,200,2,0],[40,40,0,40]]:
		var trace: TraceInventory = TraceInventory.new()
		var f: Fixture = fixture(SHORT, trace)
		trace.trace.clear()
		var result: HockshopSellResult = f.sell(3000 + row[0])
		check(result.outcome == HockshopSellResult.Outcome.SOLD and result.payout.delivered_value == row[1], "source capacity matrix " + str(row))
		check(Finance.amount(f.context, Finance.SILVER) == row[2] and Finance.amount(f.context, Finance.COIN) == row[3], "literal delivered amounts")
		check(result.payout.attempts.size() == 2 and result.payout.attempts[0].denomination == Finance.SILVER and result.payout.attempts[1].denomination == Finance.COIN, "silver then coin")
		check(result.payout.attempts[0].creation.amount_after == 2 and result.payout.attempts[0].creation.own_weight_after == 74 and result.payout.attempts[1].creation.amount_after == 40, "full denomination before admission")
		check(f.allocator.next_dynamic_sequence == 3 and not f.context.inventory.is_registered(&"sale"), "both attempt IDs spent, sold last")
		check(trace.trace[-1] == "remove:sale", "sold weight retained until final lifecycle")
		for attempt: HockshopPayoutAttempt in result.payout.attempts:
			if attempt.capacity_rejected:
				check(attempt.cleanup.succeeded() and not f.context.inventory.is_registered(attempt.item_id) and not f.context.index.has_snapshot(attempt.item_id), "failed clone gone/no orphan")
		if row[2] == 0:
			check(trace.trace.find("remove:finance-test.dynamic.1") < trace.trace.find("create:finance-test.dynamic.2"), "immediate silver cleanup BEFORE coin creation")
		check(f.context.index.snapshot_ids() == f.context.inventory.registered_item_ids() and Finance.amount(f.context, Finance.GOLD) == 0, "index exact/no gold")
		check(f.allocator.allocate(f.context.inventory).item_instance_id == &"finance-test.dynamic.3", "failed IDs never reused")
	for amount: int in [100,99,10000]:
		var f: Fixture = Fixture.new()
		var result: HockshopPayoutResult = HockshopPayoutService.pay(f.context, f.allocator, 150000, amount)
		check(result.outcome == HockshopPayoutResult.Outcome.COMPLETE and result.attempts.size() == 1 and f.allocator.next_dynamic_sequence == 2, "skip zero denominations " + str(amount))
		check(result.delivered_value == amount and Finance.amount(f.context, Finance.GOLD) == 0, "even10000 pays100silver notgold")
		check(Finance.amount(f.context, Finance.COIN) == (99 if amount == 99 else 0), "single coin branch literal")
	for capacity: int in [3000+37+5+50,3000+37+5+114]:
		var f: Fixture = fixture()
		Finance.add_money(f.context, Finance.SILVER, 1, &"old-silver")
		Finance.add_money(f.context, Finance.COIN, 5, &"old-coin")
		var result: HockshopSellResult = f.sell(capacity)
		var silver_fit: bool = capacity == 3156
		check(result.outcome == HockshopSellResult.Outcome.SOLD and result.payout.attempts[0].delivered == silver_fit, "existing silver cannot bypass full74 admission")
		check(f.context.inventory.is_registered(&"old-silver") != silver_fit and not f.context.inventory.is_registered(&"old-coin"), "old merge identities destroyed iff delivered")
		check(Finance.amount(f.context, Finance.SILVER) == (3 if silver_fit else 1) and Finance.amount(f.context, Finance.COIN) == 45, "net merged quantity exact")
		check(f.context.stacks.stack_state(result.payout.attempts[1].item_id).amount == 45 and f.context.index.snapshot_ids() == f.context.inventory.registered_item_ids(), "incoming coin survives/index exact")


func lifecycle_tests() -> void:
	for primary_sale: bool in [true,false]:
		var f: Fixture = fixture()
		add_item(f.context, f.foods, f.liquids, SHORT, &"other")
		var equipment: EquipmentState = f.context.owner.equipment_state
		for id: StringName in ([&"sale",&"other"] if primary_sale else [&"other",&"sale"]):
			check(equipment.wield(EquippedWeaponRef.new(id, Food.definitions().weapon_definition(SHORT)), false).succeeded, "real short sword wield")
		var result: HockshopSellResult = f.sell()
		check(result.outcome == HockshopSellResult.Outcome.SOLD and result.removal.weapon_detached and result.payout.delivered_value == 240, "equipped short sale")
		check(equipment == f.context.owner.equipment_state and equipment.has_weapon_instance(&"other") and not equipment.has_weapon_instance(&"sale"), "borrow exact authority/other weapon intact")
		check(equipment.is_primary_hand_empty() == primary_sale and equipment.is_secondary_hand_empty() != primary_sale, "no auto promotion")
	var f: Fixture = fixture(LONG)
	f.context.owner.equipment_state.wield(EquippedWeaponRef.new(&"sale", Food.definitions().weapon_definition(LONG)), false)
	check(f.sell().payout.delivered_value == 560 and f.context.owner.equipment_state.are_both_hands_empty(), "long700 sells560 clears hand")
	f = fixture(LEATHER)
	var armor: ArmorState = f.context.owner.armor_state
	check(armor._apply_wear(EquippedArmorRef.new(&"sale", Food.definitions().armor_definition(LEATHER))).succeeded, "real leather wear")
	check(armor.aggregate_numeric_modifiers().armor == 5 and armor.aggregate_numeric_modifiers().dodge == -2, "source leather modifiers before")
	var sold: HockshopSellResult = f.sell()
	check(sold.payout.delivered_value == 160 and sold.removal.armor_detached and armor.occupied_slots().is_empty() and armor.aggregate_numeric_modifiers().armor == 0 and armor.aggregate_numeric_modifiers().dodge == 0, "exact live armor clears contribution")
	f = fixture(SourceDumpling.DEFINITION_ID)
	sold = f.sell()
	check(sold.outcome == HockshopSellResult.Outcome.SOLD and sold.payout.delivered_value == 12 and f.foods.instance_ids().is_empty() and not f.context.index.has_snapshot(&"sale"), "fresh dumpling coin12/food removed after item")
	for row: Array in [[LiquidState.Content.RED_WINE,15],[LiquidState.Content.RED_WINE,7], [LiquidState.Content.CLEAR_WATER,15],[LiquidState.Content.CLEAR_WATER,14],[LiquidState.Content.CLEAR_WATER,0]]:
		f = fixture(SourceWineskin.DEFINITION_ID)
		f.liquids.state(&"sale").content = row[0]
		f.liquids.state(&"sale").remaining = row[1]
		check(f.quote().source_value == 20 and f.quote().actual_payout == 16, "wineskin source20 all legal contents " + str(row))
		sold = f.sell()
		check(sold.outcome == HockshopSellResult.Outcome.SOLD and sold.payout.delivered_value == 16 and f.liquids.instance_ids().is_empty() and not f.context.inventory.is_registered(&"sale"), "whole wineskin gone/no replacement")
	var independent: Fixture = fixture()
	check(independent.allocator.next_dynamic_sequence == 1 and independent.quote().source_value == 300 and independent.context.stacks.registered_count() == 0, "independent graphs no shared effects")


func failure_tests() -> void:
	var inv: TraceInventory = TraceInventory.new()
	inv.block_parentless = true
	var f: Fixture = fixture(SHORT, inv)
	var result: HockshopSellResult = f.sell(3050)
	check(result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and result.payout.attempts.size() == 1 and result.removal == null, "cleanup failure stops before coin AND sold destruction")
	check(f.allocator.next_dynamic_sequence == 2 and f.context.inventory.is_registered(&"sale") and f.context.inventory.is_registered(&"finance-test.dynamic.1"), "failed cleanup no alternate deletion/rollback")
	inv = TraceInventory.new()
	inv.block_parentless = true
	f = fixture(SHORT, inv)
	result = f.sell(3090)
	check(result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and result.payout.delivered_value == 200 and result.removal == null, "coin cleanup failure preserves earlier successful silver")
	check(f.context.inventory.is_registered(&"sale") and f.allocator.next_dynamic_sequence == 3, "second cleanup failure retains sold item and both allocations")
	inv = TraceInventory.new()
	f = fixture(SHORT, inv)
	inv.block_id = &"sale"
	result = f.sell()
	check(result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and result.stage == HockshopSellResult.Stage.ITEM_REMOVAL and result.payout.delivered_value == 240, "sold lifecycle failure retains payout")
	check(f.context.inventory.is_registered(&"sale") and f.context.index.has_snapshot(&"sale") and not result.index_forgotten, "not falsely reported gone")
	f = fixture()
	f.allocator = SessionItemIdAllocator.new(&"exhausted", 9223372036854775806)
	result = f.sell()
	check(result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and result.payout.delivered_value == 200 and result.removal == null and f.allocator.next_dynamic_sequence == 9223372036854775807, "second allocation overflow retains silver/no wrap")
	inv = TraceInventory.new()
	f = fixture(SHORT, inv)
	Finance.add_money(f.context, Finance.SILVER, 1, &"old")
	inv.block_id = &"old"
	result = f.sell()
	check(result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and result.payout.attempts.size() == 1 and result.payout.attempts[0].delivered and result.payout.delivered_value == 200, "merge authority failure reports moved payout, stops")
	check(f.context.inventory.is_registered(&"old") and f.context.inventory.is_registered(&"sale"), "merge failure not capacity and no item destruction")
	f = fixture()
	# Registration failure after allocation, using existing index virtual seam.
	f.context.index = RefusingIndex.new()
	var payout: HockshopPayoutResult = HockshopPayoutService.pay(f.context, f.allocator, 150000, 240)
	check(payout.outcome == HockshopPayoutResult.Outcome.AUTHORITY_FAILURE and payout.attempts.size() == 1 and f.allocator.next_dynamic_sequence == 2, "registration failure not ordinary capacity")
	var captured: NativeItemSnapshotCaptureResult = NativeItemPersistenceComposition.capture(f.context.inventory, f.context.stacks, f.context.index, [], [], Food.definitions(), f.foods, f.liquids)
	check(not captured.succeeded, "invalid graph fails capture rather than normalizing")
	f = fixture()
	f.context.owner = ItemLifecycleOwnerContext.new(&"player", RefusingEquipment.new(), f.context.owner.armor_state)
	f.context.owner.equipment_state.wield(EquippedWeaponRef.new(&"sale", Food.definitions().weapon_definition(SHORT)), false)
	result = f.sell()
	check(result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE and result.removal.outcome == ItemLifecycleResult.Outcome.EQUIPMENT_DETACH_FAILED and result.payout.delivered_value == 240, "real lifecycle detach failure after payout")
	check(f.context.owner.equipment_state.has_weapon_instance(&"sale") and f.context.inventory.is_registered(&"sale"), "no copied authority/manual detach fallback")


func persistence_tests(tree: SceneTree) -> void:
	# Full production capture/JSON/restore, not a new item save model.
	for row: Array in [[SHORT,114,240],[SHORT,50,40],[SHORT,20,0],[LEATHER,1000,160],[SourceDumpling.DEFINITION_ID,1000,12],[SourceWineskin.DEFINITION_ID,1000,16]]:
		var random: Recovery.RandomSequence = Recovery.RandomSequence.new()
		var session: OldPineWorldSessionController = Recovery.create_session(tree, random)
		var context: MoneyInventoryContext = Food.context(session)
		add_item(context, session.food_collection(), session.liquid_collection(), row[0])
		if row[0] == SHORT:
			context.owner.equipment_state.wield(EquippedWeaponRef.new(&"sale", Food.definitions().weapon_definition(SHORT)), false)
		if row[0] == LEATHER:
			for slot: StringName in context.owner.armor_state.occupied_slots():
				context.owner.armor_state.remove(context.owner.armor_state.item_instance_id_in_slot(slot))
			context.owner.armor_state._apply_wear(EquippedArmorRef.new(&"sale", Food.definitions().armor_definition(LEATHER)))
		var before: String = GameSaveJsonCodec.encode(Work.capture(session)).text
		var rng: Array[int] = Work.rng_state(session)
		var calls: int = random.calls
		var sequence: int = session.item_id_allocator().next_dynamic_sequence
		check(HockshopValuation.appraise(context, session.food_collection(), session.liquid_collection(), &"sale").outcome == O.SELLABLE and GameSaveJsonCodec.encode(Work.capture(session)).text == before, "appraisal exact full Save unchanged")
		var sold: HockshopSellResult = HockshopSellService.sell(context, session.food_collection(), session.liquid_collection(), session.item_id_allocator(), context.checked_contents_weight()+row[1], &"sale")
		check(sold.outcome == HockshopSellResult.Outcome.SOLD and sold.payout.delivered_value == row[2], "settled persistence fixture " + str(row))
		var snapshot: GameSaveSnapshot = Work.capture(session)
		check(snapshot != null and snapshot.metadata.schema_version == 2 and snapshot.items.schema_version == 3 and session.world_content_revision() == WorldContentRevision.CURRENT_PUBLIC, "root2/item3/source revision unchanged")
		if snapshot == null:
			session.free()
			continue
		var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
		var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
		check(decoded.succeeded() and GameSaveJsonCodec.encode(decoded.snapshot).text == encoded.text, "strict root JSON exact roundtrip")
		var restored: NativeItemRestoreCompositionResult = NativeItemPersistenceComposition.restore(decoded.snapshot.items, Food.definitions(), decoded.snapshot.item_id_allocator)
		check(restored.succeeded, "fresh item composition restored")
		if restored.succeeded:
			var domain: NativeItemDomainState = restored.domain_state
			check(domain.inventory != context.inventory and domain.inventory.registered_item_ids() == context.inventory.registered_item_ids() and restored.item_index.snapshot_ids() == context.index.snapshot_ids(), "fresh graph exact IDs/index/no orphan")
			check(not domain.inventory.is_registered(&"sale") and domain.food_collection.state(&"sale") == null and domain.liquid_collection.state(&"sale") == null, "no sold item/food/liquid resurrection")
			check(not domain.equipment_state(context.owner.character_id).has_weapon_instance(&"sale") and not domain.armor_state(context.owner.character_id).is_worn(&"sale"), "restored equipment/armor absence")
			for id: StringName in context.stacks.stack_instance_ids():
				check(domain.combined_stacks.stack_state(id).amount == context.stacks.stack_state(id).amount, "exact payout and unrelated stack quantities")
			check(restored.allocator.next_dynamic_sequence == sequence + sold.payout.attempts.size() and restored.allocator.next_dynamic_sequence == session.item_id_allocator().next_dynamic_sequence, "zero restore allocations/failed IDs consumed")
			check(restored.allocator.allocate(domain.inventory).succeeded, "continue allocation no collision")
		check(Work.rng_state(session) == rng and random.calls == calls, "zero combat/NPC/world/recovery RNG draws")
		var world: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
		check(world.succeeded(), "complete production world candidate accepts settled sale")
		if world.succeeded():
			check(world.candidate.activate_restore_candidate(), "restored candidate activation")
			world.candidate.set_process(false)
			check(Work.rng_state(world.candidate) == rng, "all saved RNG streams restored exactly")
			check(GameSaveJsonCodec.encode(Work.capture(world.candidate)).text == encoded.text, "full world recapture identical/no refund/retry/reward allocation")
			world.candidate.free()
		session.free()


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("H2: " + label)
