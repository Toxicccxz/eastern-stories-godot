extends SceneTree

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
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
		var session: OldPineWorldSessionController = Recovery.create_session(self, Recovery.RandomSequence.new())
		check(Work.work(session).succeeded(), "nondefault work resource/money/allocator")
		var portal: PortalDefinition = SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_EXIT_PORTAL_ID)
		check(session.handoff_to(portal.destination_map_id, portal.destination_zone_id, portal.destination_zone_id, portal.destination_spawn_point_id).succeeded(), "serializer resident setup")
		var map: SnowOutdoorController = session.active_map() as SnowOutdoorController
		# Serializer fixture only. Separate H3 physical test/live path proves entry.
		map.player_body.position = Vector2(155,-1000)
		session.player_runtime().set_world_location(map.location_for_zone(&"snow.hockshop"))
		check(map.hockshop.open_door(), "writer door open")
		map.player_body.position = Vector2(330,-1000)
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "save interior")
		session.free()
	else:
		var bytes_before: String = FileAccess.get_file_as_string(profile.canonical_path())
		var loaded: GameSaveResult = repository.load()
		check(loaded.succeeded(), "load file")
		if not loaded.succeeded():
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		paused = true
		check(host.request_continue(), "fresh-process Continue")
		await process_frame
		await process_frame
		var session: OldPineWorldSessionController = host.current_session()
		check(session != null, "published Session")
		if session != null:
			var after: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, loaded.snapshot.metadata.storage_profile, loaded.snapshot.metadata.saved_at_utc)
			check(after.succeeded() and GameSaveJsonCodec.encode(after.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text, "exact complete state")
			check(FileAccess.get_file_as_string(profile.canonical_path()) == bytes_before, "no rewrite on load")
			check(loaded.snapshot.metadata.schema_version == 2 and loaded.snapshot.items.schema_version == 3 and session.world_content_revision() == WorldContentRevision.CURRENT_PUBLIC, "root2/item3/current public source")
			var map: SnowOutdoorController = session.active_map() as SnowOutdoorController
			check(not map.hockshop.door_is_open() and map.player_body.position == Vector2(330,-1000) and session.player_runtime().world_location().zone_id == &"snow.hockshop", "exact position / closed default")
			paused = false
			session.set_process(false)
			check(map.hockshop.can_trade(), "service after Continue")
			await physics_frame
			await physics_frame # release existing Continue held-input quarantine before fresh input
			var walker: Work = Work.new()
			await walker.walk_to(self, session, "move_left", 155, 0)
			check(map.hockshop.open_door(), "inside opening")
			await physics_frame
			await walker.walk_to(self, session, "move_left", 0, 0)
			check(session.player_runtime().world_location().zone_id == &"snow.mstreet3" and walker._failures.is_empty(), "ordinary physical exit")
			host.free()
		paused = false
	print("H3 cold ", "FAIL" if failed else "PASS", " ", args[0])
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		printerr("H3 cold: " + label)
