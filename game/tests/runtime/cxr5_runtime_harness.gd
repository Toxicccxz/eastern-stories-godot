extends Node

## Bounded QA adapter: real Session, real key input, production coordinator and
## automatic Session _process. No action is executed by these input callbacks.
const Probe := preload("res://tests/support/cxr5_probe_policy.gd")

class ZeroRandom extends CombatRandomSource:
	var calls: int = 0
	func next_below(bound: int) -> int:
		calls += 1
		return 0 if bound > 0 else -1

@onready var session: OldPineWorldSessionController = $OldPineWorldSession
@onready var label: Label = $ProofOverlay/Panel/Margin/Status
var _random := ZeroRandom.new()
var _input_sequence: int = 0
var _receipt: String = "No request"
var _state: String = "READY"
var _start_position: Vector2
var _runtime: CombatTacticalRuntime
var _scheduler: CombatEncounterScheduler
var _npc: NpcRuntimeState


func _ready() -> void:
	session.configure_combat_random_source(_random)
	session.combat_encounter_coordinator().register_tactical_policy(Probe.new())
	_npc = session.outdoor_map().npc_runtimes()[0]
	_start_position = session.outdoor_map().player_body.global_position
	Probe.prepare(session.player_runtime().state)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _start()
		KEY_2: _complete()
		KEY_3: _submit()
		KEY_4:
			_submit()
			_submit()
		KEY_5:
			var id: StringName = _submit()
			var cancelled: CombatTacticalResult = session.combat_encounter_coordinator().cancel_player_action(id)
			_receipt += " CANCEL=%d" % cancelled.code
			print("CXR5 INPUT ", _receipt)


func _start() -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if coordinator.has_active_encounter():
		return
	var player: WorldPlayerRuntimeState = session.player_runtime()
	## QA establishment facts before the claimed tactical input path.
	_npc.set_world_location(player.world_location())
	player.relationship.add_opponent(_npc.character_id)
	_npc.relationship.add_opponent(player.character_id)
	_start_position = session.outdoor_map().player_body.global_position
	var started: CombatEncounterStartResult = coordinator.start(CombatTrigger.new(
		&"cxr5.live", CombatTriggerCause.Value.SCRIPTED, CombatEncounterMode.Value.SCRIPTED,
		player.character_id,
		[CombatTriggerCandidate.new(player.character_id, &"player"), CombatTriggerCandidate.new(_npc.character_id, &"npc")] as Array[CombatTriggerCandidate],
		player.world_location(), &"cxr5.qa",
	))
	_state = "ACTIVE" if started.succeeded() else "FAILED:%d" % started.outcome
	_scheduler = coordinator.active_scheduler()
	_runtime = null if _scheduler == null else _scheduler.player_tactics()


func _submit() -> StringName:
	_input_sequence += 1
	var id := StringName("qa.input.%d" % _input_sequence)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var before: int = player.state.recovery.inner_force.current
	var random_before: int = _random.calls
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var accepted: CombatTacticalResult = coordinator.submit_player_action(CombatTacticalRequest.new(
		id, &"encounter:cxr5.live", player.character_id, &"qa.probe",
		CombatTacticalRequest.Category.MARTIAL_SPECIAL, _npc.character_id,
	))
	_receipt = "input=%s result=%d force=%d->%d rng=%d->%d queue=%s" % [
		id, accepted.code, before, player.state.recovery.inner_force.current,
		random_before, _random.calls,
		"NONE" if _runtime == null else str(_runtime.queue_status()),
	]
	print("CXR5 INPUT ", _receipt)
	return id


func _complete() -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if not coordinator.has_active_encounter():
		return
	var result: CombatEncounterCompletionResult = coordinator.complete(CombatEncounterResult.new(
		&"encounter:cxr5.live", CombatEncounterMode.Value.SCRIPTED,
		CombatEncounterResultKind.Value.SCRIPTED, [], [], [], &"qa.done",
	))
	_state = "COMPLETED" if result.succeeded() else "END_FAILED"


func _process(_delta: float) -> void:
	if _npc == null:
		return
	var resolved: int = 0
	var replaced: int = 0
	var cancelled: int = 0
	if _runtime != null:
		for event: CombatTacticalEvent in _runtime.events():
			resolved += int(event.kind == CombatTacticalEvent.Kind.RESOLVED)
			replaced += int(event.kind == CombatTacticalEvent.Kind.REPLACED)
			cancelled += int(event.kind == CombatTacticalEvent.Kind.CANCELLED)
	label.text = (
		"CXR5 QA ONLY | 1 start | 3 submit | 4 replace pair | 5 submit/cancel | 2 complete\n"
		+ "%s | %s\ncycles=%d ordinary=%d resolved=%d replaced=%d cancelled=%d RNG=%d\n"
		+ "exact player force=%d NPC atman=%d gate_frozen=%s legacy_stopped=%s\n"
		+ "position=%s start=%s scheduler=%s"
	) % [
		_state, _receipt,
		0 if _scheduler == null else _scheduler.logical_cycle,
		0 if _scheduler == null else _scheduler.events().size(), resolved, replaced, cancelled, _random.calls,
		session.player_runtime().state.recovery.inner_force.current, _npc.character_state.recovery.atman.current,
		session.world_simulation_gate().is_frozen(), session.outdoor_map().opportunity_timer.is_stopped(),
		session.outdoor_map().player_body.global_position, _start_position,
		"RUNNING" if session.combat_encounter_coordinator().has_active_encounter() else "INERT",
	]
