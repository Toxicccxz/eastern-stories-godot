extends RefCounted

const COIN = CurrencyDenomination.Value.COIN
const SILVER = CurrencyDenomination.Value.SILVER
const GOLD = CurrencyDenomination.Value.GOLD
var assertions: int = 0
var failures: Array[String] = []

class FailingRemoval extends InventoryState:
	var block_id: StringName = &""
	var block_parentless: bool = false
	func _remove_registered_leaf(id: StringName) -> bool:
		if id == block_id or (block_parentless and direct_parent(id) == null):
			return false
		return super._remove_registered_leaf(id)

class Fixture extends RefCounted:
	var context: MoneyInventoryContext
	var allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(&"finance-test", 1)
	func _init(inv: InventoryState = null) -> void:
		context = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(&"player", EquipmentState.new(), ArmorState.new()),
			InventoryState.new() if inv == null else inv, CombinedStackCollection.new(), WorldItemInstanceIndex.new())


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	check(_definitions(), "definition test section completed")
	check(_lookup(), "lookup test section completed")
	check(_affordability(), "affordability test section completed")
	check(_payment(), "payment test section completed")
	check(_bank(), "Bank test section completed")
	check(_errors(), "error test section completed")
	# Production Session/Host/Repository, with independent terminated writer/reader processes.
	for scenario: String in ["denominations", "payment", "existing", "new", "overcap", "failed"]:
		var profile: String = "s3b-%s-%d-%d" % [scenario, OS.get_process_id(), Time.get_ticks_usec()]
		for mode: String in ["write", "read"]:
			var output: Array = []
			var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--script", "res://tests/run_snow_finance_cold_process.gd", "--", mode, scenario, profile], output, true)
			check(code == 0 and str(output).contains("S3B cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold " + scenario + "/" + mode + ": " + str(output))
	await tree.process_frame
	return {"assertions": assertions, "failures": failures}


func _definitions() -> bool:
	for row: Array in [[COIN, "coin", 1, 1, "文"], [SILVER, "silver", 100, 37, "两"], [GOLD, "gold", 10000, 37, "两"]]:
		var content: GDScript = SourceCurrencyDefinitions.source(row[0])
		check(content.BASE_VALUE == row[2] and content.BASE_WEIGHT == row[3] and content.BASE_UNIT == row[4], "source denomination facts " + row[1])
		check(content.DEFINITION_ID == StringName("es2:obj/money/" + row[1]) and content.MONEY_ID == StringName(row[1]), "canonical identity")
		check(content.stack_definition().stack_compatibility_id == StringName("/obj/money/" + row[1]), "source merge identity")
	check(SourceCurrencyDefinitions.source(SILVER) == SourceSilver, "shared silver class")
	var definitions: NativeItemDefinitionProjections = OldPineNativeItemDefinitionProjections.create(WorldContentRevision.Value.SOURCE_ENTRY_V1)
	check(definitions.is_valid and definitions.has_item_definition(SourceCoin.DEFINITION_ID) and definitions.has_item_definition(SourceGold.DEFINITION_ID), "source restore projections")
	check(not definitions.has_item_definition(&"es2:obj/money/thousand-cash"), "paper deferred")
	return true


func _lookup() -> bool:
	var f: Fixture = Fixture.new()
	add_money(f.context, COIN, 100, &"z")
	add_money(f.context, COIN, 7, &"a")
	check(f.context.select(COIN).item_id == &"a" and f.context.select(COIN).amount == 7, "lexical first, not insertion/sum")
	check(f.context.stacks.registered_count() == 2, "lookup does not merge")
	var bag: ItemInstance = ItemInstance.new(&"bag", &"test-bag")
	f.context.inventory.register_item(bag, 0)
	f.context.index.register_snapshot(bag)
	f.context.inventory._apply_reparent(&"bag", f.context.endpoint())
	add_money(f.context, SILVER, 100, &"in-bag", ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, &"bag"))
	add_money(f.context, GOLD, 100, &"ground", ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"map"))
	add_money(f.context, GOLD, 100, &"npc", ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, &"npc"))
	check(f.context.select(SILVER).outcome == CurrencyStackSelection.Outcome.ABSENT and f.context.select(GOLD).outcome == CurrencyStackSelection.Outcome.ABSENT, "no recursive, ground or NPC money")
	check(MoneyPaymentService.pay(f.context, 8).outcome == MoneyPaymentResult.Outcome.INSUFFICIENT_TOTAL, "does not sum duplicate or outside money")
	var independent: Fixture = Fixture.new()
	check(independent.context.select(COIN).outcome == CurrencyStackSelection.Outcome.ABSENT, "independent authorities")
	return true


func _affordability() -> bool:
	# Literal expected values derived from finance.c, NOT the production algorithm.
	for v: Array in [[0,0,0,1,0], [0,0,100,99,2], [0,0,100,100,2], [0,0,100,101,0],
		[0,1,0,99,2], [0,1,0,100,1], [0,1,0,101,0], [1,0,0,9999,2], [1,0,0,10000,1],
		[1,0,0,10001,0], [0,1,100,199,1], [0,1,100,200,1], [0,1,100,201,0], [0,1,100,50,1],
		[0,0,10000,10000,1], [0,100,0,10000,1], [1,1,0,9900,1], [2,1,0,19900,1], [1,0,10000,19900,2]]:
		var f: Fixture = amounts(v[0], v[1], v[2])
		var ids: Array[StringName] = f.context.inventory.registered_item_ids()
		check(int(MoneyPaymentService.can_afford(f.context, v[3]).outcome) == v[4], "LPC affordability " + str(v))
		check(ids == f.context.inventory.registered_item_ids(), "query no liveness mutation")
	var zero: Fixture = amounts(0, 0, 100)
	add_money(zero.context, SILVER, 0, &"silver")
	check(MoneyPaymentService.can_afford(zero.context, 100).outcome == MoneyAffordabilityResult.Outcome.AFFORDABLE, "raw-zero silver PRESENT")
	zero = amounts(1, 1, 0)
	add_money(zero.context, COIN, 0, &"coin")
	check(MoneyPaymentService.can_afford(zero.context, 9900).outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED, "raw-zero coin enables S+C test")
	for invalid: int in [0, -1]:
		check(MoneyPaymentService.can_afford(zero.context, invalid).outcome == MoneyAffordabilityResult.Outcome.INVALID_PRICE, "positive-price API boundary")
	return true


func _payment() -> bool:
	for v: Array in [[0,1,100,199,0,0,1,0], [2,3,50,10225,1,1,25,0], [2,1,0,19900,1,0,0,9800],
		[1,1,0,9900,1,0,0,9800], [1,0,0,50,1,0,0,50], [0,0,100,50,0,0,50,0],
		[1,0,10000,19900,0,0,100,0], [0,1,100,200,0,0,0,0]]:
		var f: Fixture = amounts(v[0], v[1], v[2])
		var result: MoneyPaymentResult = MoneyPaymentService.pay(f.context, v[3])
		check(result.succeeded() == (v[7] == 0) and result.remaining_price == v[7], "ordered payment terminal " + str(v))
		check(amount(f.context, GOLD) == v[4] and amount(f.context, SILVER) == v[5] and amount(f.context, COIN) == v[6], "literal final denominations")
		var expected_order: Array[StringName] = []
		for id: StringName in [&"gold", &"silver", &"coin"]:
			for mutation: MoneyMutationResult in result.mutations:
				if mutation.item_id == id: expected_order.append(id)
		var actual_order: Array[StringName] = []
		for mutation: MoneyMutationResult in result.mutations:
			actual_order.append(mutation.item_id)
			if mutation.requested_amount == 0:
				check(mutation.removal.succeeded and mutation.index_forgotten and not f.context.inventory.is_registered(mutation.item_id), "immediate exhausted removal")
		check(actual_order == expected_order, "gold silver coin ordering")
		check(f.allocator.next_dynamic_sequence == 1 and f.context.index.snapshot_ids() == f.context.inventory.registered_item_ids(), "no mint/allocation, index exact")
	var f: Fixture = amounts(0, 0, 99)
	check(MoneyPaymentService.pay(f.context, 100).outcome == MoneyPaymentResult.Outcome.INSUFFICIENT_TOTAL and amount(f.context, COIN) == 99, "total precheck no debit")
	f = amounts(1, 1, 0)
	check(MoneyPaymentService.can_afford(f.context, 9900).outcome == MoneyAffordabilityResult.Outcome.AFFORDABLE and MoneyPaymentService.pay(f.context, 9900).outcome == MoneyPaymentResult.Outcome.CANNOT_COMPLETE, "false-positive affordability retained")
	var inv: FailingRemoval = FailingRemoval.new()
	f = Fixture.new(inv)
	add_money(f.context, GOLD, 2, &"gold")
	add_money(f.context, SILVER, 1, &"silver")
	inv.block_id = &"silver"
	var failure: MoneyPaymentResult = MoneyPaymentService.pay(f.context, 19900)
	check(failure.outcome == MoneyPaymentResult.Outcome.AUTHORITY_FAILURE and failure.stage == MoneyPaymentResult.Stage.SILVER, "lifecycle failure exact stage")
	check(amount(f.context, GOLD) == 1 and amount(f.context, SILVER) == 1 and failure.remaining_price == 9800, "earlier gold retained, blocked lifecycle no fallback")
	check(failure.mutations[1].amount_change.accepted and not failure.mutations[1].removal.succeeded and f.context.index.has_snapshot(&"silver"), "intent/removal failure evidence")
	f = amounts(1, 0, 1)
	failure = MoneyPaymentService.pay(f.context, 50)
	check(failure.outcome == MoneyPaymentResult.Outcome.CANNOT_COMPLETE and failure.stage == MoneyPaymentResult.Stage.COIN and amount(f.context, COIN) == 1 and failure.mutations.is_empty(), "insufficient coin branch does not debit coin")
	check(MoneyPaymentService.pay(f.context, -1).outcome == MoneyPaymentResult.Outcome.INVALID_PRICE, "negative pay rejected")
	check(MoneyPaymentService.pay(null, 1).outcome == MoneyPaymentResult.Outcome.AUTHORITY_FAILURE, "missing authority explicit")
	return true


func _bank() -> bool:
	for v: Array in [[SILVER,COIN,2,1,1,100], [GOLD,SILVER,2,1,1,100], [GOLD,COIN,2,1,1,10000],
		[COIN,SILVER,100,100,0,1], [COIN,SILVER,199,199,99,1], [SILVER,GOLD,101,101,1,1]]:
		var f: Fixture = Fixture.new()
		add_money(f.context, v[0], v[2], &"source")
		var result: BankConversionResult = BankConversionService.convert(f.context, f.allocator, 1000000, v[0], v[1], v[3])
		check(result.succeeded() and amount(f.context, v[0]) == v[4] and amount(f.context, v[1]) == v[5], "literal Bank ratios/remainder " + str(v))
		check(result.creation.amount_after == 1 and result.creation.own_weight_after == SourceCurrencyDefinitions.source(v[1]).BASE_WEIGHT, "authored amount1 creation")
		check(f.allocator.next_dynamic_sequence == 2, "one new target ID")
		check(f.context.index.snapshot_ids() == f.context.inventory.registered_item_ids(), "Bank index exact")
	for type: CurrencyDenomination.Value in [COIN, SILVER, GOLD]:
		var f: Fixture = Fixture.new()
		add_money(f.context, type, 7, &"same")
		var result: BankConversionResult = BankConversionService.convert(f.context, f.allocator, 0, type, type, 3)
		check(result.succeeded() and result.target_id == result.source_id and amount(f.context, type) == 7, "same type identity/final")
		check(result.target_change.amount_change.amount_before == 7 and result.target_change.amount_change.amount_after == 10 and result.source_change.amount_change.amount_before == 10 and result.source_change.amount_change.amount_after == 7, "temporary growth, then subtraction")
		check(result.transfer == null and result.allocation == null and f.allocator.next_dynamic_sequence == 1, "no same-type allocation or capacity veto")
	var f: Fixture = amounts(0,2,0)
	ballast(f.context, 925) # current999
	var result: BankConversionResult = BankConversionService.convert(f.context, f.allocator, 1000, SILVER, COIN, 1)
	check(result.succeeded() and f.context.inventory.contents_weight(f.context.endpoint()) == 1062, "new one-unit exact cap then overcap1062")
	f = amounts(0,2,1)
	ballast(f.context, 925) # current1000
	result = BankConversionService.convert(f.context, f.allocator, 1000, SILVER, COIN, 1)
	check(result.succeeded() and result.transfer == null and f.context.inventory.contents_weight(f.context.endpoint()) == 1063, "existing overcap1063 no transfer")
	f = amounts(0,0,200)
	ballast(f.context, 800)
	result = BankConversionService.convert(f.context, f.allocator, 1000, COIN, SILVER, 100)
	check(result.outcome == BankConversionResult.Outcome.DELIVERY_FAILED and amount(f.context, COIN) == 100 and amount(f.context, SILVER) == 0, "capacity rejection still debits")
	check(result.target_change.amount_change.requested_amount == 1 and result.cleanup.removal.succeeded and result.cleanup.index_forgotten, "target amount then authoritative cleanup")
	check(f.context.inventory.contents_weight(f.context.endpoint()) == 900 and f.allocator.next_dynamic_sequence == 2 and not f.context.inventory.is_registered(result.target_id), "no orphan/refund/ID reuse")
	f = amounts(0,1,200)
	ballast(f.context, 763)
	result = BankConversionService.convert(f.context, f.allocator, 1000, COIN, SILVER, 100)
	check(result.succeeded() and f.context.inventory.contents_weight(f.context.endpoint()) == 937 and amount(f.context, SILVER) == 2, "existing counterpart succeeds937")
	f = amounts(0,0,100)
	ballast(f.context, 900)
	result = BankConversionService.convert(f.context, f.allocator, 1000, COIN, SILVER, 100)
	check(result.outcome == BankConversionResult.Outcome.DELIVERY_FAILED and f.context.stacks.registered_count() == 0 and f.context.inventory.contents_weight(f.context.endpoint()) == 900, "both exhausted source and failed target removed")


	return true


func _errors() -> bool:
	var f: Fixture = amounts(0,0,150)
	check(BankConversionService.convert(f.context, f.allocator, 9999, COIN, SILVER, 199).outcome == BankConversionResult.Outcome.INSUFFICIENT_SOURCE, "original request checked before rounding")
	check(BankConversionService.convert(f.context, f.allocator, 9999, COIN, SILVER, 99).outcome == BankConversionResult.Outcome.ROUNDED_TO_ZERO, "rounds to zero")
	check(BankConversionService.convert(f.context, f.allocator, 9999, COIN, SILVER, 0).outcome == BankConversionResult.Outcome.INVALID_QUANTITY, "zero request")
	check(BankConversionService.convert(f.context, f.allocator, 9999, GOLD, SILVER, 0).outcome == BankConversionResult.Outcome.SOURCE_MISSING, "missing before invalid quantity")
	check(BankConversionService.convert(f.context, f.allocator, 9999, GOLD, CurrencyDenomination.Value.UNSUPPORTED, 0).outcome == BankConversionResult.Outcome.UNSUPPORTED_TARGET, "unsupported target first")
	check(BankConversionService.convert(f.context, f.allocator, 9999, CurrencyDenomination.Value.UNSUPPORTED, COIN, 1).outcome == BankConversionResult.Outcome.UNSUPPORTED_SOURCE, "unsupported source")
	check(f.allocator.next_dynamic_sequence == 1 and amount(f.context, COIN) == 150, "validation no mutation")
	var overflow_allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(&"test", CurrencyArithmetic.MAXIMUM)
	check(BankConversionService.convert(f.context, overflow_allocator, 9999, COIN, SILVER, 100).outcome == BankConversionResult.Outcome.ALLOCATION_FAILED, "allocator overflow")
	f = amounts(0,0,1)
	f.context.stacks._apply_amount(&"coin", CurrencyArithmetic.MAXIMUM)
	check(BankConversionService.convert(f.context, f.allocator, 9999, COIN, COIN, 1).outcome == BankConversionResult.Outcome.ARITHMETIC_FAILURE and amount(f.context, COIN) == CurrencyArithmetic.MAXIMUM, "same-target addition overflow no wrap")
	f = amounts(1,0,0)
	f.context.stacks._apply_amount(&"gold", CurrencyArithmetic.MAXIMUM)
	check(MoneyPaymentService.can_afford(f.context, 1).outcome == MoneyAffordabilityResult.Outcome.ARITHMETIC_FAILURE and MoneyPaymentService.pay(f.context, 1).outcome == MoneyPaymentResult.Outcome.ARITHMETIC_FAILURE, "value overflow")
	var result: BankConversionResult = BankConversionService.convert(f.context, f.allocator, 9999, GOLD, COIN, CurrencyArithmetic.MAXIMUM)
	check(result.outcome == BankConversionResult.Outcome.ARITHMETIC_FAILURE and result.stage == BankConversionResult.Stage.TARGET_AMOUNT and result.transfer.succeeded and amount(f.context, COIN) == 1, "late multiplication failure preserves new/move amount1")
	check(amount(f.context, GOLD) == CurrencyArithmetic.MAXIMUM and f.allocator.next_dynamic_sequence == 2, "late overflow no source debit/ID rollback")
	var inv: FailingRemoval = FailingRemoval.new()
	f = Fixture.new(inv)
	add_money(f.context, COIN, 200, &"coin")
	inv.block_parentless = true
	result = BankConversionService.convert(f.context, f.allocator, 200, COIN, SILVER, 100)
	check(result.outcome == BankConversionResult.Outcome.AUTHORITY_FAILURE and result.stage == BankConversionResult.Stage.CLEANUP, "failed-target lifecycle failure")
	check(amount(f.context, COIN) == 100 and f.context.inventory.is_registered(result.target_id) and f.context.index.has_snapshot(result.target_id), "no cleanup fallback and no source refund")
	check(CurrencyArithmetic.add(CurrencyArithmetic.MAXIMUM, 1) == -1 and CurrencyArithmetic.multiply(CurrencyArithmetic.MAXIMUM, 2) == -1, "checked arithmetic primitives")
	inv = FailingRemoval.new()
	f = Fixture.new(inv)
	add_money(f.context, SILVER, 1, &"silver")
	inv.block_id = &"silver"
	result = BankConversionService.convert(f.context, f.allocator, 1000, SILVER, COIN, 1)
	check(result.outcome == BankConversionResult.Outcome.AUTHORITY_FAILURE and result.stage == BankConversionResult.Stage.SOURCE_AMOUNT and amount(f.context, COIN) == 100 and amount(f.context, SILVER) == 1, "source lifecycle failure retains completed target credit")
	f = amounts(0, 0, 100)
	add_money(f.context, SILVER, 0, &"silver")
	result = BankConversionService.convert(f.context, f.allocator, 0, COIN, SILVER, 100)
	check(result.succeeded() and result.allocation == null and amount(f.context, SILVER) == 1, "zero target is existing and bypasses admission")
	f = amounts(0, 1, 1)
	f.context.stacks._apply_amount(&"coin", CurrencyArithmetic.MAXIMUM)
	check(MoneyPaymentService.can_afford(f.context, 1).outcome == MoneyAffordabilityResult.Outcome.ARITHMETIC_FAILURE and MoneyPaymentService.pay(f.context, 1).outcome == MoneyPaymentResult.Outcome.ARITHMETIC_FAILURE, "total addition overflow")
	f = amounts(0, 1, 0)
	f.context.stacks._apply_amount(&"silver", CurrencyArithmetic.MAXIMUM / 37)
	result = BankConversionService.convert(f.context, f.allocator, 0, SILVER, SILVER, 1)
	check(result.outcome == BankConversionResult.Outcome.ARITHMETIC_FAILURE and result.target_change.amount_change == null, "temporary own-weight overflow fails before mutation")
	return true


static func amounts(gold: int, silver: int, coin: int) -> Fixture:
	var f: Fixture = Fixture.new()
	if gold > 0: add_money(f.context, GOLD, gold, &"gold")
	if silver > 0: add_money(f.context, SILVER, silver, &"silver")
	if coin > 0: add_money(f.context, COIN, coin, &"coin")
	return f


static func add_money(context: MoneyInventoryContext, denomination: CurrencyDenomination.Value, quantity: int, id: StringName, parent: ContainmentEndpoint = null) -> void:
	var content: GDScript = SourceCurrencyDefinitions.source(denomination)
	var item: ItemInstance = ItemInstance.new(id, content.DEFINITION_ID)
	assert(context.inventory.register_item(item, 0))
	assert(context.index.register_snapshot(item))
	assert(CombinedStackService.register_stack(context.stacks, context.inventory, item, content.stack_definition(), quantity).accepted)
	assert(context.inventory._apply_reparent(id, context.endpoint() if parent == null else parent))


static func ballast(context: MoneyInventoryContext, weight: int) -> void:
	var item: ItemInstance = ItemInstance.new(&"ballast", &"test-ballast")
	assert(context.inventory.register_item(item, weight))
	assert(context.index.register_snapshot(item))
	assert(context.inventory._apply_reparent(item.item_instance_id, context.endpoint()))


static func amount(context: MoneyInventoryContext, denomination: CurrencyDenomination.Value) -> int:
	return context.select(denomination).amount


static func session_context(session: OldPineWorldSessionController) -> MoneyInventoryContext:
	var p: WorldPlayerRuntimeState = session.player_runtime()
	return MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(p.character_id, p.state.equipment, p.armor),
		session.inventory_state(), session.stack_collection(), session.item_instance_index())


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("S3B: " + label)
