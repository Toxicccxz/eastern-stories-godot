extends SceneTree

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
	var mode: String = args[0]
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test(args[1])
	var repository: SourceEntrySaveRepository = SourceEntrySaveRepository.new(profile)
	if mode == "write":
		var session: OldPineWorldSessionController = Work.create_session(self)
		check(Food.earn_and_exchange(session), "work + bank source money")
		check(Food.purchase(session).delivered and Food.purchase(session).delivered, "two products no stock limit")
		var ids: Array[StringName] = session.food_collection().instance_ids()
		check(ids.size() == 2, "two identities")
		session.player_runtime().state.recovery.food = 0 # Explicit consumption-only QA fixture.
		check(Food.eat(session, ids[0]).outcome == FoodUseResult.Outcome.ATE, "first bite")
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "real file Save")
		session.free()
	else:
		var original_text: String = FileAccess.get_file_as_string(profile.canonical_path())
		var original: Dictionary = JSON.parse_string(original_text)
		var loaded: GameSaveResult = repository.load()
		check(loaded.succeeded(), "file load")
		if not loaded.succeeded():
			printerr(loaded.path, " ", loaded.detail)
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		check(host.request_continue(), "fresh Host Continue")
		await process_frame
		await process_frame
		var session: OldPineWorldSessionController = host.current_session()
		check(session != null, "fresh Session")
		if session != null:
			var captured: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, loaded.snapshot.metadata.storage_profile, loaded.snapshot.metadata.saved_at_utc)
			check(captured.succeeded() and GameSaveJsonCodec.encode(captured.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text, "ENTIRE decoded persisted snapshot equality")
			var ids: Array[StringName] = session.food_collection().instance_ids()
			if mode in ["pre-read", "pre-v2"]:
				check(ids.is_empty(), "no food granted to pre-S4B save")
				check(Food.context(session).select(Food.SILVER).amount == 1 and Food.context(session).select(Food.COIN).amount == 100, "old source currency exact")
				check(original.items.schema_version == (1 if mode == "pre-read" else 2), "original embedded version")
				if mode == "pre-read":
					# Only expected representation changes; every other raw field identical.
					original.items.schema_version = 2.0 # JSON parser represents numbers as float.
					original.items.food_consumables = []
					var current: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(captured.snapshot).text)
					check(recursive_equal(original, current), "old-v1 semantic exactness: all fields except explicit item-version extension")
					if not failed:
						check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "resave item-v2")
			elif mode == "absent":
				check(ids.is_empty() and session.player_runtime().state.recovery.food == 360, "six bites total; no resurrection")
			else:
				check(ids.size() == 2 and session.player_runtime().state.recovery.food == 60, "partial food and multiple identities exact")
				check(session.food_collection().state(ids[0]).remaining_portions == 2 and session.food_collection().state(ids[0]).current_value == 0, "partial2/value0")
				check(session.food_collection().state(ids[1]).remaining_portions == 3 and session.food_collection().state(ids[1]).current_value == 15, "fresh3/value15")
				check(session.inventory_state().own_weight(ids[0]) == 80 and session.inventory_state().direct_parent(ids[0]).same_identity(Food.context(session).endpoint()), "exact parent/weight")
				if mode == "finish":
					for id: StringName in ids:
						while session.food_collection().state(id) != null:
							var result: FoodUseResult = Food.eat(session, id)
							check(result.outcome == FoodUseResult.Outcome.ATE, "consume remaining after Continue")
							if result.outcome != FoodUseResult.Outcome.ATE: break
					check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "Save after destruction")
			host.free()
	print("S4B cold ", "FAIL" if failed else "PASS", " ", mode)
	quit(1 if failed else 0)

func recursive_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not recursive_equal(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not recursive_equal(a[i], b[i]): return false
		return true
	return a == b

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("S4B cold: " + label)
