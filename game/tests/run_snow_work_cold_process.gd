extends SceneTree

## Two separate OS processes, not an in-process restore presented as cold proof.
const Fixture := preload("res://tests/runtime/snow_work_income_test.gd")
var _failed: bool = false

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
		var session: OldPineWorldSessionController = Fixture.create_session(self)
		var p: WorldPlayerRuntimeState = session.player_runtime()
		var cloth: StringName = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, p.character_id))[0]
		session.inventory_state().update_own_weight(cloth, p.maximum_encumbrance - 20)
		var result: SnowWorkResult = Fixture.work(session)
		check(result.outcome == SnowWorkResult.Outcome.DELIVERY_FAILED_CAPACITY, "capacity-specific delivery failure")
		check(result.cleanup != null and result.cleanup.succeeded, "existing lifecycle cleanup")
		check(OldPineSessionLoadCoordinator.new(repository).save_current(session).succeeded(), "save depleted state")
		session.free()
	elif args[0] == "read":
		var saved: GameSaveResult = repository.load()
		check(saved.succeeded(), "physical file from terminated writer")
		if not saved.succeeded():
			quit(1)
			return
		var host: OldPineGameRuntimeHost = (load("res://scenes/runtime/oldpine_game_runtime_host.tscn") as PackedScene).instantiate()
		host.configure_manual_before_start(profile)
		root.add_child(host)
		check(host.current_session() == null and host.request_continue(), "empty fresh Host accepts Continue")
		await process_frame
		await process_frame
		var session: OldPineWorldSessionController = host.current_session()
		check(session != null, "cold Continue succeeds")
		if session != null:
			var after: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, saved.snapshot.metadata.storage_profile, saved.snapshot.metadata.saved_at_utc)
			check(after.succeeded() and GameSaveJsonCodec.encode(after.snapshot).text == GameSaveJsonCodec.encode(saved.snapshot).text, "whole persisted state exact including RNG, position, depleted resources, allocator")
			check(session.player_runtime().state.essence.current == 70 and session.player_runtime().state.spirit.current == 70, "spent resources remain")
			var carried: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id))
			check(carried.size() == 1 and session.item_instance_index().resolve(carried[0]).item_definition_id == SourcePlayerCloth.DEFINITION_ID, "player retains only original cloth")
			check(session.item_instance_index().snapshot_ids() == session.inventory_state().registered_item_ids() and not session.stack_collection().has_stack(carried[0]), "derived index exact; no player reward stack; full snapshot equality checks all remaining NPC items/ground")
			var before: int = session.item_id_allocator().next_dynamic_sequence
			var next: SessionItemIdAllocationResult = session.item_id_allocator().allocate(session.inventory_state())
			check(before == 2 and next.succeeded and session.item_id_allocator().next_dynamic_sequence == 3, "failed reward sequence consumed, never reused")
		host.free()
	else:
		_failed = true
	print("S2 cold process ", args[0], ": ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)

func check(ok: bool, label: String) -> void:
	if not ok:
		_failed = true
		printerr("S2 cold: ", label)
