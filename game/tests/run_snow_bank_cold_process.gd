extends SceneTree

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Bank := preload("res://tests/runtime/snow_bank_access_test.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test(args[1])
	var repository: SourceEntrySaveRepository = SourceEntrySaveRepository.new(profile)
	if args[0] == "write":
		var session: OldPineWorldSessionController = Work.create_session(self)
		var walk: RefCounted = Work.new()
		Work.work(session)
		Work.work(session)
		await physics_frame
		await walk.walk(self, session, "move_right", 125)
		await walk.walk_to(self, session, "move_right", 0, 0)
		await walk.walk_to(self, session, "move_up", -400, 1)
		await walk.walk_to(self, session, "move_left", -340, 0)
		check(walk._failures.is_empty(), "bank physically reached")
		var bank: SnowOutdoorController = session.active_map() as SnowOutdoorController
		check(bank.request_bank_conversion(CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN, "1").succeeded(), "exchange before Save")
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "production bank Save")
		session.free()
	elif args[0] == "read":
		var loaded: GameSaveResult = repository.load()
		check(loaded.succeeded(), "read file")
		if not loaded.succeeded():
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		check(host.request_continue(), "fresh Host Continue")
		await process_frame
		await process_frame
		var session: OldPineWorldSessionController = host.current_session()
		check(session != null, "restored")
		if session != null:
			var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, loaded.snapshot.metadata.storage_profile, loaded.snapshot.metadata.saved_at_utc)
			check(captured.succeeded() and GameSaveJsonCodec.encode(captured.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text, "ENTIRE persisted snapshot exact")
			var bank: SnowOutdoorController = session.active_map() as SnowOutdoorController
			check(bank.can_exchange_here(), "bank exact location/proximity restored")
			var money: MoneyInventoryContext = bank.bank_money_context()
			check(money.select(CurrencyDenomination.Value.SILVER).amount == 1 and money.select(CurrencyDenomination.Value.COIN).amount == 100, "denominations restored")
			var ids: Array[StringName] = session.inventory_state().registered_item_ids()
			var before: int = session.item_id_allocator().next_dynamic_sequence
			var next: SessionItemIdAllocationResult = session.item_id_allocator().allocate(session.inventory_state())
			check(next.succeeded and not ids.has(next.item_instance_id) and session.item_id_allocator().next_dynamic_sequence == before+1, "next ID no collision")
		host.free()
	else:
		failed = true
	print("S3C cold ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("S3C cold: " + label)
