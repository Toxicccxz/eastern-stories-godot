extends Node

## Isolated storage; real Shell and production entry/UI. No completion shortcut.
const ShellScene := preload("res://scenes/application/application_shell.tscn")
const Files := preload("res://tests/application/application_shell_phase10c1c_test.gd")
var shell: ApplicationShellController
var files := Files.MemoryFiles.new()

func evidence() -> Dictionary[String, Variant]:
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	var result: Dictionary[String, Variant] = {"paused": get_tree().paused, "files": files.files.size()}
	if session == null:
		return result
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	result["session"] = str(session.get_instance_id())
	result["character"] = str(session.player_runtime().state.get_instance_id())
	result["active"] = coordinator.has_active_encounter()
	result["cycle"] = -1 if coordinator.active_scheduler() == null else coordinator.active_scheduler().logical_cycle
	result["terminal"] = -1 if coordinator.last_completion() == null else coordinator.last_completion().terminal_result.kind
	result["failure"] = -1 if coordinator.resolution() == null else coordinator.resolution().failure
	result["player_life"] = session.player_runtime().life_status
	result["hp"] = session.player_runtime().state.vitality.current
	result["corpse_count"] = session.outdoor_map().corpse_states().size()
	result["items"] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id))
	result["world_open"] = session.world_simulation_gate().is_open()
	result["old_timer"] = session.outdoor_map().cadence_is_running()
	result["save"] = OldPineSaveEligibility.inspect(session).outcome
	return result

func _ready() -> void:
	shell = ShellScene.instantiate()
	assert(shell.configure_before_start(GameSaveStorageProfile.isolated_test("cxr8-live"), files, null, Files.MemoryFiles.new(), Files.FakeWindowCapability.new()))
	add_child(shell)
	print("CXR8 isolated QA: real New Game; key 1 prepares safe Attack target; key 2 prepares player loss; key 3 controlled SPAR. Never invokes Attack/death/completion.")

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode not in [KEY_1, KEY_2, KEY_3]:
		return
	var session: OldPineWorldSessionController = shell.runtime_host().current_session()
	if session == null or session.combat_encounter_coordinator().has_active_encounter():
		return
	var map: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = map.npc_runtimes()[0]
	(map.bandit_bodies[0].get_node("AggressionPresence") as Area2D).monitoring = false
	map.bandit_bodies[0].global_position = map.player_body.global_position + Vector2(0, 60)
	npc.set_world_location(player.world_location())
	session.configure_combat_random_source(GodotCombatRandomSource.new(88, true))
	player.state.attributes.courage = 100000
	player.state.skills.set_raw_level(&"sword", 1000)
	player.state.progression.combat_experience = 1000000
	player.state.vitality = CharacterResourceState.new(10000, 10000, 10000)
	npc.character_state.vitality = CharacterResourceState.new(10000, 10000, 10000)
	if key.keycode == KEY_2:
		player.state.vitality = CharacterResourceState.new(1, 1, 10000)
		player.busy.start_busy(3)
		npc.character_state.attributes.courage = 100000
		npc.character_state.skills.set_raw_level(&"sword", 1000)
		npc.character_state.progression.combat_experience = 1000000
	elif key.keycode == KEY_3:
		player.relationship.add_opponent(npc.character_id)
		npc.relationship.add_opponent(player.character_id)
		var candidates: Array[CombatTriggerCandidate] = [CombatTriggerCandidate.new(player.character_id, &"player"), CombatTriggerCandidate.new(npc.character_id, &"spar")]
		session.combat_encounter_coordinator().start(CombatTrigger.new(&"cxr8.qa.spar", CombatTriggerCause.Value.PLAYER_SPAR, CombatEncounterMode.Value.SPAR, player.character_id, candidates, player.world_location()))
	print("CXR8 declared QA preparation=", key.keycode, " Session=", str(session.get_instance_id()))
