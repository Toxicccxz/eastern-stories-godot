extends Node

@onready var session: OldPineWorldSessionController = $OldPineWorldSession
@onready var status_label: Label = $ProofOverlay/Panel/Margin/Status

var _proof_state: String = "READY"
var _transition_outcome: int = -1
var _session_identity: int = 0
var _map_identity: int = 0
var _player_identity: int = 0
var _location_before: WorldLocationState
var _position_at_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	_session_identity = session.get_instance_id()
	_map_identity = session.active_map().get_instance_id()
	_player_identity = session.player_runtime().get_instance_id()
	_location_before = session.player_runtime().world_location()
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_start_controlled_encounter()
		KEY_2:
			_complete_controlled_encounter()
		KEY_3:
			_attempt_transition()


func _start_controlled_encounter() -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if coordinator.has_active_encounter():
		return
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_location_before = player.world_location()
	_position_at_start = outdoor.player_body.global_position
	npc.set_world_location(player.world_location())
	if not player.relationship.has_opponent(npc.character_id):
		player.relationship.add_opponent(npc.character_id)
	var candidates: Array[CombatTriggerCandidate] = [
		CombatTriggerCandidate.new(player.character_id, &"side:player"),
		CombatTriggerCandidate.new(npc.character_id, &"side:npc"),
	]
	var trigger := CombatTrigger.new(
		&"cxr3.rendered_proof",
		CombatTriggerCause.Value.SCRIPTED,
		CombatEncounterMode.Value.SCRIPTED,
		player.character_id,
		candidates,
		player.world_location(),
		&"cxr3.controlled_proof",
	)
	var result: CombatEncounterStartResult = coordinator.start(trigger)
	_proof_state = "ACTIVE" if result.succeeded() else "START_FAILED:%d" % result.outcome


func _complete_controlled_encounter() -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	if encounter == null:
		return
	var participants: Array[CombatParticipant] = encounter.participants()
	var subject_ids: Array[StringName] = []
	for participant: CombatParticipant in participants:
		subject_ids.append(participant.participant_id)
	var terminal := CombatEncounterResult.new(
		encounter.encounter_id,
		CombatEncounterMode.Value.SCRIPTED,
		CombatEncounterResultKind.Value.SCRIPTED,
		[],
		[],
		subject_ids,
		&"cxr3.rendered_proof_completed",
	)
	var result: CombatEncounterCompletionResult = coordinator.complete(terminal)
	_proof_state = "COMPLETED" if result.succeeded() else "END_FAILED:%d" % result.outcome


func _attempt_transition() -> void:
	var result: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.CAVE_VINE_LANDING_SPAWN_POINT_ID,
	)
	_transition_outcome = result.outcome


func _refresh_status() -> void:
	if session == null or not session.is_initialized():
		status_label.text = "CXR3 HARNESS: SESSION NOT READY"
		return
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var gate: WorldSimulationGate = session.world_simulation_gate()
	var player_body: WorldCharacterBody2D = session.active_map().runtime_player_body()
	var same_identity: bool = (
		session.get_instance_id() == _session_identity
		and session.outdoor_map().get_instance_id() == _map_identity
		and session.player_runtime().get_instance_id() == _player_identity
	)
	var same_location: bool = (
		_location_before != null
		and session.player_runtime().world_location().same_location(_location_before)
	)
	status_label.text = (
		"CXR3 RENDERED PROOF\n"
		+ "Arrow/WASD: real movement | 1: start | 3: blocked handoff | 2: complete\n"
		+ "state=%s encounter=%s gate=%s owner=%s\n"
		+ "position=(%.1f, %.1f) start=(%.1f, %.1f) quarantine=%s transition_outcome=%d\n"
		+ "same_session_world=%s same_location=%s"
	) % [
		_proof_state,
		"ACTIVE" if coordinator.has_active_encounter() else "NONE",
		"OPEN" if gate.is_open() else "FROZEN",
		String(gate.freeze_owner_id()),
		player_body.global_position.x,
		player_body.global_position.y,
		_position_at_start.x,
		_position_at_start.y,
		str(player_body.movement_input_quarantined()),
		_transition_outcome,
		str(same_identity),
		str(same_location),
	]
