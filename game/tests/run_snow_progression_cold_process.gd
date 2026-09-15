extends SceneTree
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Recovery := preload("res://tests/runtime/player_recovery_cadence_test.gd")
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var profile := GameSaveStorageProfile.isolated_test(args[1])
	var repository := SourceEntrySaveRepository.new(profile)
	if args[0] == "write":
		var session := Recovery.create_session(self,Recovery.RandomSequence.new())
		var gate := SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_EXIT_PORTAL_ID)
		check(session.handoff_to(gate.destination_map_id,gate.destination_zone_id,gate.destination_zone_id,gate.destination_spawn_point_id).succeeded(),"fixture outdoor")
		var map := session.active_map() as SnowOutdoorController
		# Serializer fixture only; physical/live routes have separate real-input proof.
		map.player_body.position = Vector2(340,-400)
		session.player_runtime().set_world_location(map.location_for_zone(&"snow.school1"))
		check(map.school.open_door(),"writer opens transient door")
		map.player_body.position = Vector2(1000,-400)
		session.player_runtime().set_world_location(map.location_for_zone(&"snow.schoolhall"))
		check(map.school.request_apprentice() == SwordsmanApprenticeship.Outcome.RECRUITED,"writer recruits")
		check(map.school.request_learn().success,"writer world RNG Learn")
		session.player_runtime().state.skills.set_learned_progress(&"unarmed",1)
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(),"write school")
		session.free()
	else:
		var original := FileAccess.get_file_as_string(profile.canonical_path())
		var loaded := repository.load()
		check(loaded.succeeded(),"cold read")
		if not loaded.succeeded():
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		paused = true
		check(host.request_continue(),"real cold Host Continue")
		await process_frame
		await process_frame
		var session := host.current_session()
		check(session != null,"published session")
		if session != null:
			var after := OldPineWorldSaveCapture.new().capture(session,loaded.snapshot.metadata.storage_profile,loaded.snapshot.metadata.saved_at_utc)
			check(after.succeeded() and GameSaveJsonCodec.encode(after.snapshot).text == GameSaveJsonCodec.encode(loaded.snapshot).text,"whole snapshot exact")
			var map := session.active_map() as SnowOutdoorController
			check(not map.school.door_is_open() and not (map.get_node("Walls/SchoolDoor") as CollisionShape2D).disabled,"cold-closed gate")
			check(not session.player_runtime().school_apprenticeship.is_pending() and not map.school.ui.panel.visible,"pending/UI not restored")
			check(map.player_body.position == Vector2(1000,-400),"exact school position")
			check(session.player_runtime().facts.title == "封山剑派第十四代弟子" and session.player_runtime().state.affiliation.class_id == &"swordsman","title/class")
			var reference_rng := GodotWorldInteractionRandomSource.new()
			check(reference_rng.restore_random_state(loaded.snapshot.world_interaction_rng),"RNG restore reference")
			check(reference_rng.next_below(30) == session.world_interaction_random_source().next_below(30),"same next world draw")
			check(FileAccess.get_file_as_string(profile.canonical_path()) == original,"load does not rewrite file")
		host.free()
		paused = false
	print("P2 cold ","FAIL" if failed else "PASS"," ",args[0])
	quit(1 if failed else 0)

func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		printerr("P2 cold: " + label)
