extends "res://tests/runtime/cxr6_runtime_harness.gd"

const Multi := preload("res://tests/support/cxr7_session_fixture.gd")
var target_receipts: Array[String] = []
var _before_cycle: int
var _before_target: StringName
var _before_queue: StringName


func _ready() -> void:
	shell = ShellScene.instantiate()
	var configured: bool = shell.configure_before_start(GameSaveStorageProfile.isolated_test("cxr7-live"), Files.MemoryFiles.new(), null, Files.MemoryFiles.new(), Files.FakeWindowCapability.new())
	assert(configured, "CXR7 QA requires isolated memory storage")
	(shell.get_node("TouchCanvas/TouchInput") as MobileTouchAdapter).set_capability(Mobile.EnabledTouch.new())
	add_child(shell)
	print("CXR7 QA: actual New Game first; 1 SCRIPTED; 3 SPAR; 4 LETHAL; 5 SCRIPTED QA probe + busy30; 2 typed cleanup. Target/action proof ONLY via real Battle UI.")


func _process(delta: float) -> void:
	super(delta)
	if _ui != null and not _ui.target_received.is_connected(_after_target):
		_ui.target_submitting.connect(_before_target_receipt)
		_ui.target_received.connect(_after_target)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or session == null:
		return
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if key.keycode == KEY_2:
		print("CXR7 typed QA cleanup (not outcome-generation proof): ", Multi.finish(session))
		return
	if key.keycode not in [KEY_1, KEY_3, KEY_4, KEY_5] or coordinator.has_active_encounter():
		return
	# Controlled pre-route facts only. No target selector shortcut in this harness.
	for npc: NpcRuntimeState in session.outdoor_map().npc_runtimes():
		session.player_runtime().relationship.remove_lethal_relation(npc.character_id)
		npc.relationship.remove_lethal_relation(session.player_runtime().character_id)
	var mode: int = CombatEncounterMode.Value.SCRIPTED
	var cause: int = CombatTriggerCause.Value.SCRIPTED
	if key.keycode == KEY_3:
		mode = CombatEncounterMode.Value.SPAR
		cause = CombatTriggerCause.Value.PLAYER_SPAR
	elif key.keycode == KEY_4:
		mode = CombatEncounterMode.Value.LETHAL
		cause = CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK
		session.player_runtime().relationship.mark_lethal_target(session.outdoor_map().npc_runtimes()[0].character_id)
	elif key.keycode == KEY_5:
		Multi.register_probes(session)
		session.player_runtime().busy.start_busy(30)
	_sequence += 1
	var result: CombatEncounterStartResult = coordinator.start(Multi.trigger(session, mode, cause, StringName("cxr7.live.%d" % _sequence)))
	_scheduler = coordinator.active_scheduler()
	print("CXR7 controlled START: ", result.outcome, " mode=", mode, " registry=", coordinator.action_infos().size())


func _before_target_receipt() -> void:
	_before_receipt()
	_before_cycle = _scheduler.logical_cycle
	var encounter: CombatEncounter = session.combat_encounter_coordinator().active_encounter()
	_before_target = encounter.current_target_for(session.player_runtime().character_id)
	var queued: CombatQueuedAction = encounter.queued_player_action()
	_before_queue = &"" if queued == null else queued.resolved_target_id


func _after_target(result: CombatTargetResult) -> void:
	var encounter: CombatEncounter = session.combat_encounter_coordinator().active_encounter()
	var queued: CombatQueuedAction = encounter.queued_player_action()
	var line: String = "code=%d target=%s->%s queue=%s->%s force=%d->%d RNG=%d->%d cycle=%d->%d" % [result.code, _before_target, encounter.current_target_for(session.player_runtime().character_id), _before_queue, &"" if queued == null else queued.resolved_target_id, receipt_force, session.player_runtime().state.recovery.inner_force.current, receipt_rng, random.calls, _before_cycle, _scheduler.logical_cycle]
	target_receipts.append(line)
	print("CXR7 TARGET RECEIPT ", line)
