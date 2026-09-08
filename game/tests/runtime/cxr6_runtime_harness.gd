extends Node

## QA ONLY. Actual Shell/Host/Session/Battle UI; isolated memory files. No production
## trigger/action. Keys establish/complete controlled encounters; tactical proof
## must use the actual Battle buttons, not these fixture controls.
const ShellScene := preload("res://scenes/application/application_shell.tscn")
const Files := preload("res://tests/application/application_shell_phase10c1c_test.gd")
const Mobile := preload("res://tests/application/mobile_touch_test.gd")
const Setup := preload("res://tests/support/cxr6_session_fixture.gd")
var shell: ApplicationShellController
var session: OldPineWorldSessionController
var random := Setup.CountingRandom.new()
var receipt_force: int = 0
var receipt_rng: int = 0
var receipt_resolved: int = 0
var receipt_log: Array[String] = []
var _sequence: int = 0
var _scheduler: CombatEncounterScheduler
var _ui: BattlePresentationController


func _ready() -> void:
	shell = ShellScene.instantiate()
	var configured: bool = shell.configure_before_start(GameSaveStorageProfile.isolated_test("cxr6-live"), Files.MemoryFiles.new(), null, Files.MemoryFiles.new(), Files.FakeWindowCapability.new())
	assert(configured, "CXR6 QA must use isolated in-memory storage")
	(shell.get_node("TouchCanvas/TouchInput") as MobileTouchAdapter).set_capability(Mobile.EnabledTouch.new())
	add_child(shell)
	print("CXR6 QA: actual New Game button first; 1 empty-registry encounter; 2 complete; 4 QA encounter; B pre-route busy=60; T QA current-target change; no tactical callback shortcuts")


func _process(_delta: float) -> void:
	if session == null and shell.runtime_host() != null and shell.runtime_host().current_session() != null:
		session = shell.runtime_host().current_session()
		session.configure_combat_random_source(random)
		_ui = session.get_node("BattlePresentationLayer/BattleSurface")
		_ui.intent_submitting.connect(_before_receipt)
		_ui.intent_received.connect(_after_receipt)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or session == null:
		return
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	match key.keycode:
		KEY_1, KEY_4:
			if coordinator.has_active_encounter():
				return
			if key.keycode == KEY_4:
				Setup.register_probes(session)
			_sequence += 1
			var result: CombatEncounterStartResult = Setup.start(session, StringName("cxr6.live.%d" % _sequence), key.keycode == KEY_4)
			_scheduler = coordinator.active_scheduler()
			print("CXR6 START ", result.outcome, " registry=", coordinator.action_infos().size())
		KEY_2:
			print("CXR6 COMPLETE ", Setup.complete(session))
		KEY_B:
			# Explicit QA preparation before the waiting/replacement/cancel input route.
			session.player_runtime().busy.start_busy(60)
			print("CXR6 QA busy setup=60 (not a production commitment)")
		KEY_T:
			# Test-only authority change, NOT a production player target selector.
			if coordinator.has_active_encounter():
				coordinator.active_encounter().set_current_target(session.player_runtime().character_id, session.outdoor_map().npc_runtimes()[1].character_id)
				print("CXR6 QA current target changed; accepted queue must not retarget")


func resolved_count() -> int:
	var count: int = 0
	if _scheduler != null and _scheduler.player_tactics() != null:
		for event: CombatTacticalEvent in _scheduler.player_tactics().events():
			count += int(event.kind == CombatTacticalEvent.Kind.RESOLVED)
	return count


func _before_receipt() -> void:
	receipt_force = session.player_runtime().state.recovery.inner_force.current
	receipt_rng = random.calls
	receipt_resolved = resolved_count()


func _after_receipt(result: CombatTacticalResult) -> void:
	var queued: CombatQueuedAction = session.combat_encounter_coordinator().active_encounter().queued_player_action()
	var line: String = "code=%d force=%d->%d RNG=%d->%d resolved=%d->%d queue=%s" % [result.code, receipt_force, session.player_runtime().state.recovery.inner_force.current, receipt_rng, random.calls, receipt_resolved, resolved_count(), "EMPTY" if queued == null else queued.request.request_id]
	receipt_log.append(line)
	print("CXR6 UI RECEIPT ", line)
