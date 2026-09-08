extends Node

@onready var session: OldPineWorldSessionController = $OldPineWorldSession
@onready var status_label: Label = $ProofOverlay/Panel/Margin/Status

class AttackFavoringRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		if exclusive_upper_bound <= 0:
			return -1
		return 0 if calls <= 3 else exclusive_upper_bound - 1


var _proof_state: String = "READY"
var _position_at_start: Vector2 = Vector2.ZERO
var _player_vitality_at_start: int = 0
var _npc_vitality_at_start: int = 0
var _completed_cycle: int = 0
var _completed_event_count: int = 0
var _random := AttackFavoringRandomSource.new()


func _ready() -> void:
	session.configure_combat_random_source(_random)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	_position_at_start = outdoor.player_body.global_position
	_player_vitality_at_start = session.player_runtime().state.vitality.current
	_npc_vitality_at_start = outdoor.npc_runtimes()[0].character_state.vitality.current
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


func _start_controlled_encounter() -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if coordinator.has_active_encounter():
		return
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_position_at_start = outdoor.player_body.global_position
	_player_vitality_at_start = player.state.vitality.current
	_npc_vitality_at_start = npc.character_state.vitality.current
	npc.set_world_location(player.world_location())
	player.relationship.add_opponent(npc.character_id)
	npc.relationship.add_opponent(player.character_id)
	var result: CombatEncounterStartResult = coordinator.start(
		CombatTrigger.new(
			&"cxr4.rendered_proof",
			CombatTriggerCause.Value.SCRIPTED,
			CombatEncounterMode.Value.SCRIPTED,
			player.character_id,
			[
				CombatTriggerCandidate.new(player.character_id, &"side:player"),
				CombatTriggerCandidate.new(npc.character_id, &"side:npc"),
			] as Array[CombatTriggerCandidate],
			player.world_location(),
			&"cxr4.controlled_proof",
		)
	)
	_proof_state = "ACTIVE" if result.succeeded() else "START_FAILED:%d" % result.outcome


func _complete_controlled_encounter() -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	if encounter == null or scheduler == null:
		return
	_completed_cycle = scheduler.logical_cycle
	_completed_event_count = scheduler.events().size()
	var subject_ids: Array[StringName] = []
	for participant: CombatParticipant in encounter.participants():
		subject_ids.append(participant.participant_id)
	var result: CombatEncounterCompletionResult = coordinator.complete(
		CombatEncounterResult.new(
			encounter.encounter_id,
			CombatEncounterMode.Value.SCRIPTED,
			CombatEncounterResultKind.Value.SCRIPTED,
			[],
			[],
			subject_ids,
			&"cxr4.rendered_proof_completed",
		)
	)
	_proof_state = "COMPLETED" if result.succeeded() else "END_FAILED:%d" % result.outcome


func _refresh_status() -> void:
	if session == null or not session.is_initialized():
		status_label.text = "CXR4 HARNESS: SESSION NOT READY"
		return
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	var cycle: int = _completed_cycle if scheduler == null else scheduler.logical_cycle
	var event_count: int = _completed_event_count if scheduler == null else scheduler.events().size()
	var player_changed: bool = player.state.vitality.current != _player_vitality_at_start
	var npc_changed: bool = npc.character_state.vitality.current != _npc_vitality_at_start
	status_label.text = (
		"CXR4 ACTIVE SEMI-AUTO PROOF\n"
		+ "Arrow/WASD: real movement | 1: controlled start | 2: complete\n"
		+ "state=%s encounter=%s gate=%s scheduler=%s legacy_timer_stopped=%s\n"
		+ "cycle=%d events=%d rng_calls=%d player_kee=%d npc_kee=%d mutation=%s\n"
		+ "position=(%.1f, %.1f) start=(%.1f, %.1f) world_position_frozen=%s"
	) % [
		_proof_state,
		"ACTIVE" if coordinator.has_active_encounter() else "NONE",
		"OPEN" if session.world_simulation_gate().is_open() else "FROZEN",
		"RUNNING" if scheduler != null else "INERT",
		str(outdoor.opportunity_timer.is_stopped()),
		cycle,
		event_count,
		_random.calls,
		player.state.vitality.current,
		npc.character_state.vitality.current,
		str(player_changed or npc_changed),
		outdoor.player_body.global_position.x,
		outdoor.player_body.global_position.y,
		_position_at_start.x,
		_position_at_start.y,
		str(
			not coordinator.has_active_encounter()
			or outdoor.player_body.global_position.is_equal_approx(_position_at_start)
		),
	]
