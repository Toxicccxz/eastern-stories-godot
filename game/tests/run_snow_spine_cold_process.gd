extends SceneTree

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or args[1] not in ["mstreet3", "crossroad"]:
		quit(2)
		return
	var zone: StringName = StringName("snow." + args[1])
	var position: Vector2 = Vector2(0,-1000) if args[1] == "mstreet3" else Vector2(100,-1650)
	var profile: GameSaveStorageProfile = GameSaveStorageProfile.isolated_test(args[2])
	var repository: SourceEntrySaveRepository = SourceEntrySaveRepository.new(profile)
	if args[0] == "write":
		var session: OldPineWorldSessionController = Recovery.create_session(self, Recovery.RandomSequence.new())
		check(Work.work(session).succeeded(), "nondefault resources/real silver/stable allocator fixture")
		var portal: PortalDefinition = SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_EXIT_PORTAL_ID)
		check(session.handoff_to(portal.destination_map_id, portal.destination_zone_id, portal.destination_zone_id, portal.destination_spawn_point_id).succeeded(), "source map binding")
		# Serializer fixture only. Physical reachability is separately proven by input tests/live.
		session.active_map().runtime_player_body().position = position
		session.player_runtime().set_world_location(session.active_map().location_for_zone(zone))
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "file Save")
		session.free()
	else:
		var bytes_before: String = FileAccess.get_file_as_string(profile.canonical_path())
		var loaded: GameSaveResult = repository.load()
		check(loaded.succeeded(), "existing file load")
		if not loaded.succeeded():
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
		check(session != null, "fresh Session published")
		if session != null:
			var after: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, loaded.snapshot.metadata.storage_profile, loaded.snapshot.metadata.saved_at_utc)
			check(after.succeeded() and GameSaveJsonCodec.encode(after.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text, "ALL saved facts exact including location/items/allocator/RNG")
			check(FileAccess.get_file_as_string(profile.canonical_path()) == bytes_before, "no save rewrite")
			check(loaded.snapshot.metadata.schema_version == 2 and loaded.snapshot.items.schema_version == 3, "root2/item3")
			check(session.player_runtime().world_location().zone_id == zone and session.active_map().runtime_player_body().position == position, "exact new zone and position")
			paused = false
			session.set_process(false)
			var walker: Work = Work.new()
			await walker.walk(self, session, "move_down", 20)
			check(session.active_map().runtime_player_body().position.y > position.y + 20 and session.active_map_id() == &"snow.outdoor", "normal physics walking after cold Continue")
			host.free()
		paused = false
	print("S7B cold ", "FAIL" if failed else "PASS", " ", args[0], " ", args[1])
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("S7B cold: " + label)
