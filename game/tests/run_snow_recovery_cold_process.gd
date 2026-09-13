extends SceneTree

const RecoveryTest := preload("res://tests/runtime/player_recovery_cadence_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Food := preload("res://tests/runtime/snow_dumpling_test.gd")
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
		var random: RecoveryTest.RandomSequence = RecoveryTest.RandomSequence.new()
		var session: OldPineWorldSessionController = RecoveryTest.create_session(self, random)
		check(Food.earn_and_exchange(session), "Work + Bank")
		var product: DumplingPurchaseResult = Food.purchase(session)
		check(product.delivered and session.advance_player_recovery(12.0).opportunities == 1, "purchase + natural food399")
		check(Food.eat(session, product.item_id).outcome == FoodUseResult.Outcome.ATE, "natural Eat459")
		session.advance_player_recovery(3.0)
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "actual file Save")
		check(session.player_recovery_cadence().accumulated_seconds == 1.0 and session.player_recovery_cadence().source_tick == 4 and random.calls == 2, "Save leaves live phase intact/no RNG")
		session.free()
	else:
		var before_bytes: String = FileAccess.get_file_as_string(profile.canonical_path())
		var loaded: GameSaveResult = repository.load()
		check(loaded.succeeded(), "existing save valid")
		if not loaded.succeeded():
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		paused = true # Host ALWAYS, Session PAUSABLE: inspect exact pre-first-pulse continuation.
		check(host.request_continue(), "cold manual Continue")
		await process_frame
		await process_frame
		var session: OldPineWorldSessionController = host.current_session()
		check(session != null, "fresh published Session")
		if session != null:
			var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, loaded.snapshot.metadata.storage_profile, loaded.snapshot.metadata.saved_at_utc)
			check(captured.succeeded() and GameSaveJsonCodec.encode(captured.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text, "ALL persisted gameplay facts equal (Player/items/food/money/allocator/position/RNG)")
			var cadence: PlayerRecoveryCadence = session.player_recovery_cadence()
			check(cadence != null and cadence.accumulated_seconds == 0.0 and cadence.source_tick >= 5 and cadence.source_tick <= 14, "fresh transient cadence0/new5..14")
			check(loaded.snapshot.metadata.schema_version == 2 and loaded.snapshot.items.schema_version == 2 and loaded.snapshot.world_content_revision == WorldContentRevision.Value.SOURCE_ENTRY_V1, "schema2/item2/SOURCE_ENTRY_V1 unchanged")
			check(FileAccess.get_file_as_string(profile.canonical_path()) == before_bytes, "Continue never rewrites/migrates file")
			check(not before_bytes.contains("cadence") and not before_bytes.contains("countdown") and not before_bytes.contains("accumulator"), "no cadence persisted")
			if args[0] == "read": check(session.player_runtime().state.recovery.food == 459 and session.player_runtime().state.recovery.water == 399 and session.player_runtime().state.essence.current == 50, "natural recovered/consumed facts persist")
		host.free()
		paused = false
	print("S5B cold ", "FAIL" if failed else "PASS", " ", args[0])
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("S5B cold: " + label)
