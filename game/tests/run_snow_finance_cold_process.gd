extends SceneTree

const Test := preload("res://tests/runtime/snow_finance_test.gd")
const SourceFixture := preload("res://tests/runtime/snow_work_income_test.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(2)
		return
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test(args[2])
	var repository: SourceEntrySaveRepository = SourceEntrySaveRepository.new(profile)
	if args[0] == "write":
		var session: OldPineWorldSessionController = SourceFixture.create_session(self)
		var context: MoneyInventoryContext = Test.session_context(session)
		var rng: Array[int] = SourceFixture.rng_state(session)
		var initial_ids: Array[StringName] = context.inventory.registered_item_ids()
		# Public birth unchanged: cloth only, no Player money; dormant NPC items untouched.
		check(context.inventory.direct_children(context.endpoint()).size() == 1 and context.select(Test.SILVER).item_id.is_empty(), "no new birth money")
		var silver_id: StringName = &""
		for row: Array in [[Test.GOLD, 2], [Test.SILVER, 3], [Test.COIN, 50]]:
			var allocated: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
			check(allocated.succeeded, "fixture allocation")
			Test.add_money(context, row[0], row[1], allocated.item_instance_id)
			if row[0] == Test.SILVER: silver_id = allocated.item_instance_id
		match args[1]:
			"payment":
				var paid: MoneyPaymentResult = MoneyPaymentService.pay(context, 20350)
				check(paid.succeeded() and context.inventory.registered_item_ids() == initial_ids, "settled all money depleted")
			"existing":
				var converted: BankConversionResult = BankConversionService.convert(context, session.item_id_allocator(), 150000, Test.GOLD, Test.SILVER, 1)
				check(converted.succeeded() and converted.allocation == null and Test.amount(context, Test.SILVER) == 103, "existing target103")
			"new", "overcap", "failed":
				check(context.set_amount(silver_id, 0).succeeded(), "remove silver fixture through lifecycle")
				if args[1] in ["overcap", "failed"]:
					# QA-only load fixture. Uses persisted body authority, no production cap change.
					var cloth: StringName = context.inventory.direct_children(context.endpoint())[0]
					for id: StringName in context.inventory.direct_children(context.endpoint()):
						if context.index.resolve(id).item_definition_id == SourcePlayerCloth.DEFINITION_ID: cloth = id
					context.inventory.update_own_weight(cloth, 150000 - 74 - 50 - (37 if args[1] == "overcap" else 0))
				var converted: BankConversionResult = BankConversionService.convert(context, session.item_id_allocator(), 150000, Test.GOLD, Test.SILVER, 1)
				if args[1] == "failed":
					check(converted.outcome == BankConversionResult.Outcome.DELIVERY_FAILED and converted.cleanup.succeeded() and not context.inventory.is_registered(converted.target_id), "failed target absent")
				else:
					check(converted.succeeded() and Test.amount(context, Test.SILVER) == 100, "new target100")
					if args[1] == "overcap":
						check(context.inventory.contents_weight(context.endpoint()) == 153626, "one-unit equality admission then overcap survives Save")
				check(Test.amount(context, Test.GOLD) == 1 and session.item_id_allocator().next_dynamic_sequence == 5, "source debit/sequence")
			"denominations":
				check(Test.amount(context, Test.GOLD) == 2 and Test.amount(context, Test.COIN) == 50, "all canonical denominations")
		check(SourceFixture.rng_state(session) == rng, "zero gameplay RNG consumption")
		check(context.index.snapshot_ids() == context.inventory.registered_item_ids(), "exact index")
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "production Save")
		session.free()
	elif args[0] == "read":
		var loaded: GameSaveResult = repository.load()
		check(loaded.succeeded(), "read writer file")
		if not loaded.succeeded():
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		check(host.current_session() == null and host.request_continue(), "fresh Host Continue")
		await process_frame
		await process_frame
		var session: OldPineWorldSessionController = host.current_session()
		check(session != null, "restored Session")
		if session != null:
			var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, loaded.snapshot.metadata.storage_profile, loaded.snapshot.metadata.saved_at_utc)
			check(captured.succeeded() and GameSaveJsonCodec.encode(captured.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text,
				"entire snapshot exact: IDs, parents, amounts, weights, Player, location, RNG, allocator")
			var before: int = session.item_id_allocator().next_dynamic_sequence
			var next: SessionItemIdAllocationResult = session.item_id_allocator().allocate(session.inventory_state())
			check(next.succeeded and session.item_id_allocator().next_dynamic_sequence == before + 1, "continued allocator")
			check(session.item_instance_index().snapshot_ids() == session.inventory_state().registered_item_ids(), "restored index")
		host.free()
	else:
		failed = true
	print("S3B cold ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("S3B cold: ", label)
