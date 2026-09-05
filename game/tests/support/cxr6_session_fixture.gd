extends RefCounted

const Probe := preload("res://tests/support/cxr5_probe_policy.gd")

class CountingRandom extends CombatRandomSource:
	var calls: int = 0
	func capture_random_state() -> RandomStreamSnapshot:
		# Shell diagnostic read only. Deliberately unsupported by gameplay restore.
		return RandomStreamSnapshot.new(&"qa-counting-zero-not-restorable", 0, calls)
	func next_below(bound: int) -> int:
		calls += 1
		return 0 if bound > 0 else -1


static func register_probes(session: OldPineWorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	coordinator.register_tactical_policy(Probe.new())
	coordinator.register_tactical_policy(Probe.new(&"qa.second"))
	Probe.prepare(session.player_runtime().state)
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	ui.action_catalog.action_ids = [&"qa.probe", &"qa.second"]
	ui.action_catalog.labels = ["QA Probe", "QA Alternate"]


static func start(session: OldPineWorldSessionController, id: StringName, third: bool = false) -> CombatEncounterStartResult:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var candidates: Array[CombatTriggerCandidate] = [CombatTriggerCandidate.new(player.character_id, &"player")]
	for index: int in (2 if third else 1):
		var npc: NpcRuntimeState = session.outdoor_map().npc_runtimes()[index]
		# Declared QA setup before route; physical position is not moved.
		npc.set_world_location(player.world_location())
		player.relationship.add_opponent(npc.character_id)
		npc.relationship.add_opponent(player.character_id)
		candidates.append(CombatTriggerCandidate.new(npc.character_id, &"hostile"))
	return session.combat_encounter_coordinator().start(CombatTrigger.new(
		id, CombatTriggerCause.Value.SCRIPTED, CombatEncounterMode.Value.SCRIPTED,
		player.character_id, candidates, player.world_location(), &"cxr6.qa.setup",
	))


static func complete(session: OldPineWorldSessionController) -> bool:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if not coordinator.has_active_encounter():
		return false
	return coordinator.complete(CombatEncounterResult.new(
		coordinator.active_encounter().encounter_id, CombatEncounterMode.Value.SCRIPTED,
		CombatEncounterResultKind.Value.SCRIPTED, [], [], [], &"cxr6.qa.end",
	)).succeeded()
