extends SceneTree

const Water := preload("res://tests/runtime/snow_water_test.gd")
const Food := preload("res://tests/runtime/snow_dumpling_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
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
		var session: OldPineWorldSessionController = Recovery.create_session(self, Recovery.RandomSequence.new())
		check(Food.earn_and_exchange(session), "real Work + Bank")
		var product: WineskinPurchaseResult = Water.purchase(session)
		check(product.delivered, "paid wineskin")
		if args[1] != "wine": check(Water.fill(session, product.item_id).succeeded(), "typed Fill")
		if args[1] == "partial":
			check(session.advance_player_recovery(12.0).opportunities == 1, "natural water399")
			check(Water.drink(session, product.item_id).succeeded(), "natural drink429")
		elif args[1] == "empty":
			for i: int in range(15):
				session.player_runtime().state.recovery.water = 0 # Explicit empty-state fixture.
				check(Water.drink(session, product.item_id).succeeded(), "consume to empty")
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "actual file Save")
		session.free()
	else:
		var original_bytes: String = FileAccess.get_file_as_string(profile.canonical_path())
		var loaded: GameSaveResult = repository.load()
		check(loaded.succeeded(), "existing file load")
		if not loaded.succeeded():
			printerr(loaded.path, " ", loaded.detail)
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		paused = true
		check(host.request_continue(), "fresh process Continue")
		await process_frame
		await process_frame
		var session: OldPineWorldSessionController = host.current_session()
		check(session != null, "fresh published Session")
		if session != null:
			var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, loaded.snapshot.metadata.storage_profile, loaded.snapshot.metadata.saved_at_utc)
			check(captured.succeeded() and GameSaveJsonCodec.encode(captured.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text, "ALL facts exact: Player/items/liquid/food/money/IDs/allocator/equipment/location/RNG")
			check(FileAccess.get_file_as_string(profile.canonical_path()) == original_bytes, "Continue does not rewrite saved bytes")
			check(loaded.snapshot.items.schema_version == 3 and loaded.snapshot.metadata.schema_version == 2, "root2/item3")
			if args[1] == "pre-v2":
				check(JSON.parse_string(original_bytes).items.schema_version == 2 and session.liquid_collection().instance_ids().is_empty(), "exact archived pre-S6B item2 grants no liquids")
				check(session.player_runtime().state.recovery.food == 459 and session.player_runtime().state.recovery.water == 399, "pre-S6B natural food/water exact")
			else:
				var records: Array[NativeLiquidConsumableRecord] = loaded.snapshot.items.liquid_consumable_records
				check(records.size() == 1, "one stable item")
				if records.size() == 1:
					var state: LiquidState = session.liquid_collection().state(records[0].item_instance_id)
					check(state != null and state.content == (LiquidState.Content.RED_WINE if args[1] == "wine" else LiquidState.Content.CLEAR_WATER), "content not converted by restore")
					check(state.remaining == (14 if args[1] == "partial" else (0 if args[1] == "empty" else 15)), "exact portions no refill")
			host.free()
		paused = false
	print("S6B cold ", "FAIL" if failed else "PASS", " ", args[0], " ", args[1])
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("S6B cold: " + label)
