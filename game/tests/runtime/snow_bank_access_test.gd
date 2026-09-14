extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const COIN = CurrencyDenomination.Value.COIN
const SILVER = CurrencyDenomination.Value.SILVER
const GOLD = CurrencyDenomination.Value.GOLD
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	check(input_test(), "input section complete")
	check(await integration_test(tree), "integration section complete")
	check(await capacity_test(tree, false), "failed delivery section complete")
	check(await capacity_test(tree, true), "existing overcap section complete")
	check(await physical_test(tree), "physical section complete")
	var profile: String = "s3c-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for mode: String in ["write", "read"]:
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_snow_bank_cold_process.gd", "--", mode, profile], output, true)
		check(code == 0 and str(output).contains("S3C cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold " + mode + ": " + str(output))
	return {"assertions": assertions, "failures": failures}


func input_test() -> bool:
	for text: String in ["", "0", "-1", "+1", "1.5", "1e3", " 1", "1 ", "NaN", "9223372036854775808", "9999999999999999999999999"]:
		check(SnowBankExchangePanel.positive_amount(text) == -1, "strict quantity rejects " + text)
	for row: Array in [["1",1], ["0002",2], ["9223372036854775807",9223372036854775807]]:
		check(SnowBankExchangePanel.positive_amount(row[0]) == row[1], "exact integer " + row[0])
	check(SnowWorldDefinitions.route_neighbours(&"snow.mstreet1", &"snow.bank") and SnowWorldDefinitions.route_neighbours(&"snow.bank", &"snow.mstreet1"), "source two-way bank east")
	check(not SnowWorldDefinitions.route_neighbours(&"snow.bank", &"snow.square"), "no bank-square shortcut")
	check(SnowWorldDefinitions.zone_by_id(&"snow.bank").map_id == &"snow.outdoor", "same map")
	return true


## Typed/position setup ONLY for controller integration tests, never live route evidence.
static func at_bank(session: OldPineWorldSessionController) -> SnowOutdoorController:
	session.handoff_to(SnowWorldDefinitions.OUTDOOR_MAP_ID, &"snow.square", &"snow.square", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID)
	var bank: SnowOutdoorController = session.resident_map(SnowWorldDefinitions.OUTDOOR_MAP_ID) as SnowOutdoorController
	bank.player_body.player_controlled = true
	bank.player_body.position = Vector2(-340, -400)
	session.player_runtime().set_world_location(WorldLocationState.new(&"snow", &"snow.outdoor", &"snow.bank", &"snow.bank"))
	return bank


func integration_test(tree: SceneTree) -> bool:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	var bank: SnowOutdoorController = session.resident_map(&"snow.outdoor") as SnowOutdoorController
	check(bank.request_bank_conversion(SILVER, COIN, "1").outcome == SnowBankInteractionResult.Outcome.BLOCKED, "inactive map blocked")
	Work.work(session)
	Work.work(session)
	at_bank(session)
	if not bank.can_exchange_here():
		check(false, "bank fixture unavailable: init=%s paused=%s controlled=%s gate=%s life=%s fighting=%s loc=%s pos=%s marker=%s valid=%s" % [bank._initialized, tree.paused, bank.player_body.player_controlled, session.world_simulation_gate().is_open(), session.player_runtime().life_status, session.player_runtime().relationship.is_fighting(), session.player_runtime().world_location().zone_id, bank.player_body.global_position, bank.bank_marker.global_position, OldPineMapPlacementValidator.is_valid_character_position(bank, &"snow.bank", bank.player_body.global_position)])
		session.free()
		return false
	var context: MoneyInventoryContext = bank.bank_money_context()
	check(context.inventory == session.inventory_state() and context.stacks == session.stack_collection() and context.index == session.item_instance_index(), "borrow live item authorities")
	check(context.owner.equipment_state == session.player_runtime().state.equipment and context.owner.armor_state == session.player_runtime().armor, "exact equipment armor injection")
	var before: int = session.item_id_allocator().next_dynamic_sequence
	var rng: Array[int] = Work.rng_state(session)
	for text: String in ["", "0", "-1", "1.1", "9223372036854775808"]:
		check(bank.request_bank_conversion(SILVER, COIN, text).outcome == SnowBankInteractionResult.Outcome.INVALID_INPUT, "controller invalid input " + text)
	check(session.item_id_allocator().next_dynamic_sequence == before and context.select(SILVER).amount == 2, "invalid input no mutation")
	session.world_simulation_gate().acquire(&"test.bank")
	check(not bank.can_exchange_here(), "world gate blocked")
	session.world_simulation_gate().release(&"test.bank")
	tree.paused = true
	check(not bank.can_exchange_here(), "pause blocked")
	tree.paused = false
	session.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	check(not bank.can_exchange_here(), "unconscious blocked")
	session.player_runtime().set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	bank.player_body.position = Vector2(-170,-400)
	check(not bank.can_exchange_here(), "far blocked")
	bank.player_body.position = Vector2(-425,-400)
	check(not bank.can_exchange_here(), "inside counter collision blocked")
	bank.player_body.position = Vector2(-340,-400)
	var result: SnowBankInteractionResult = bank.request_bank_conversion(SILVER, COIN, "1")
	check(result.succeeded() and result.conversion.source_quantity == 1 and result.conversion.target_quantity == 100, "two Works -> exact source ratio")
	check(context.select(SILVER).amount == 1 and context.select(COIN).amount == 100, "silver1 coin100")
	check(MoneyPaymentService.can_afford(context, 15).outcome == MoneyAffordabilityResult.Outcome.AFFORDABLE, "silver-present price15")
	check(session.player_runtime().state.essence.current == 40 and session.player_runtime().state.spirit.current == 40, "only two Work costs")
	check(session.player_runtime().maximum_encumbrance == 150000 and session.player_runtime().body_facts.body_weight == 80000, "body authority unchanged")
	check(session.item_id_allocator().next_dynamic_sequence == before+1 and Work.rng_state(session) == rng, "one target ID no RNG")
	var coin_id: StringName = context.select(COIN).item_id
	result = bank.request_bank_conversion(COIN, COIN, "100")
	check(result.succeeded() and result.conversion.allocation == null and context.select(COIN).item_id == coin_id and context.select(COIN).amount == 100, "same type legal, stable identity and net amount")
	check(bank.request_bank_conversion(GOLD, COIN, "1").conversion.outcome == BankConversionResult.Outcome.SOURCE_MISSING, "missing")
	check(bank.request_bank_conversion(COIN, SILVER, "101").conversion.outcome == BankConversionResult.Outcome.INSUFFICIENT_SOURCE, "requested holding before round")
	check(bank.request_bank_conversion(COIN, SILVER, "99").conversion.outcome == BankConversionResult.Outcome.ROUNDED_TO_ZERO, "round-zero")
	# Duplicate direct stacks: presentation must use the same first selected stack.
	Finance.add_money(context, COIN, 7, &"000-selected-coin")
	check(bank.bank_amount_text(context, COIN) == "7", "not sum of duplicate stacks")
	bank.request_bank_conversion(COIN, SILVER, "8")
	check(bank.last_bank_result.conversion.outcome == BankConversionResult.Outcome.INSUFFICIENT_SOURCE, "same selected7 authority")
	session.free()
	await tree.process_frame
	session = Work.create_session(tree)
	Work.work(session)
	bank = at_bank(session)
	check(bank.request_bank_conversion(SILVER, COIN, "1").succeeded(), "one Work exchange")
	context = bank.bank_money_context()
	check(context.select(SILVER).outcome == CurrencyStackSelection.Outcome.ABSENT and context.select(COIN).amount == 100, "last silver removed")
	check(MoneyPaymentService.can_afford(context, 15).outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED, "legacy coin-only15 result2 not fixed")
	session.free()
	await tree.process_frame
	return true


func capacity_test(tree: SceneTree, existing: bool) -> bool:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	Work.work(session)
	var bank: SnowOutdoorController = at_bank(session)
	if not bank.can_exchange_here():
		check(false, "capacity fixture unavailable")
		session.free()
		return false
	var context: MoneyInventoryContext = bank.bank_money_context()
	if existing: Finance.add_money(context, COIN, 1, &"existing-coin")
	var cloth: StringName = &""
	for id: StringName in context.inventory.direct_children(context.endpoint()):
		if context.index.resolve(id).item_definition_id == SourcePlayerCloth.DEFINITION_ID: cloth = id
	context.inventory.update_own_weight(cloth, 150000 - 37 - (1 if existing else 0))
	var before: int = session.item_id_allocator().next_dynamic_sequence
	var rng: Array[int] = Work.rng_state(session)
	var result: BankConversionResult = bank.request_bank_conversion(SILVER, COIN, "1").conversion
	if existing:
		check(result.succeeded() and result.allocation == null and context.select(COIN).amount == 101, "existing credit before debit skips capacity admission")
		check(context.inventory.contents_weight(context.endpoint()) == 150063, "existing overcap exact 150000+100-37")
		check(session.item_id_allocator().next_dynamic_sequence == before, "existing no ID")
	else:
		check(result.outcome == BankConversionResult.Outcome.DELIVERY_FAILED and result.cleanup.succeeded(), "capacity failure lifecycle")
		check(context.select(COIN).outcome == CurrencyStackSelection.Outcome.ABSENT and not context.inventory.is_registered(result.target_id), "no target/ground/orphan")
		check(session.item_id_allocator().next_dynamic_sequence == before+1, "failed delivery ID spent")
		check(bank.bank_panel.feedback.text.contains("原币已扣除") and bank.bank_panel.feedback.text.contains("无退款"), "honest failure message")
	check(context.select(SILVER).outcome == CurrencyStackSelection.Outcome.ABSENT, "source debit and depletion retained")
	check(context.index.snapshot_ids() == context.inventory.registered_item_ids(), "derived index exact")
	check(Work.rng_state(session) == rng, "zero RNG")
	session.free()
	await tree.process_frame
	return true


func physical_test(tree: SceneTree) -> bool:
	var session: OldPineWorldSessionController = Work.create_session(tree)
	var walk: RefCounted = Work.new()
	await tree.physics_frame
	await walk.walk(tree, session, "move_right", 125)
	await walk.walk_to(tree, session, "move_right", 0, 0)
	await walk.walk_to(tree, session, "move_up", -400, 1)
	await walk.walk(tree, session, "move_right", 60)
	check(session.active_map().runtime_player_body().position.x < 75, "school east collision retained")
	await walk.walk_to(tree, session, "move_left", -340, 0)
	var bank: SnowOutdoorController = session.active_map() as SnowOutdoorController
	check(bank != null and bank.can_exchange_here(), "physical west entry/proximity")
	if bank == null:
		session.free()
		return false
	check(bank.bank_panel.is_visible_in_tree(), "exchange UI visible")
	bank.bank_panel.quantity.grab_focus()
	var position: Vector2 = bank.player_body.position
	await walk.walk(tree, session, "move_left", 10)
	check(bank.player_body.position == position, "quantity cursor input cannot move")
	bank.bank_panel.quantity.release_focus()
	bank.bank_panel.source.get_popup().popup()
	await walk.walk(tree, session, "move_up", 10)
	check(bank.player_body.position == position, "currency popup cursor cannot move")
	bank.bank_panel.source.get_popup().hide()
	await walk.walk_to(tree, session, "move_right", 0, 0)
	check(session.player_runtime().world_location().zone_id == &"snow.mstreet1" and not bank.can_exchange_here(), "east exit clears availability")
	check(bank.resident_npcs().is_empty() and session.resident_map_count() == 4, "no NPC/map added")
	for entry: Array in [[&"snow.bank",Vector2(-490,-400)], [&"snow.bank",Vector2(-300,-545)], [&"snow.bank",Vector2(-300,-255)], [&"snow.bank",Vector2(-425,-400)], [&"snow.mstreet1",Vector2(-100,-500)]]:
		check(not OldPineMapPlacementValidator.is_valid_character_position(bank, entry[0], entry[1]), "restore rejects walls " + str(entry))
	check(OldPineMapPlacementValidator.is_valid_character_position(bank, &"snow.mstreet1",Vector2(-100,-400)), "half-open east join")
	check(walk._failures.is_empty(), "all physical targets reached")
	session.free()
	await tree.process_frame
	return true


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("S3C: " + label)
