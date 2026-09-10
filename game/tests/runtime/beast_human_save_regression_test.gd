extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
const BeastFixture := preload("res://tests/support/beast_persistence_fixture.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	session.deterministic_npc_seed = true
	session.npc_seed = 37
	session.deterministic_combat_seed = true
	session.combat_seed = 38
	session.deterministic_world_interaction_seed = true
	session.world_interaction_seed = 39
	tree.root.add_child(session)
	await tree.process_frame
	var capture: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-09-10T12:00:00Z")
	_eq(capture.outcome, OldPineWorldCaptureResult.Outcome.SUCCESS, "real normal human Save capture passes shared prepare validation")
	if capture.outcome != OldPineWorldCaptureResult.Outcome.SUCCESS:
		session.free()
		return {"assertions": _assertions, "failures": _failures.duplicate()}
	var snapshot: GameSaveSnapshot = capture.snapshot
	var prepared: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(snapshot)
	_eq(prepared.outcome, OldPineWorldRestoreResult.Outcome.SUCCESS, "real production human ledger restores")
	_eq(snapshot.npc_spawn_states.size(), 5, "five production NPCs unchanged")
	_eq(snapshot.items.item_records.size(), 12, "twelve bootstrap items unchanged")
	for saved: Values.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		_eq(saved.npc_definition_id != &"oldpine.npc.serpent", true, "no production serpent")
		var body: NpcBodyFacts = NpcBodyFacts.derive(OldPineNpcDefinitions.npc_by_id(saved.npc_definition_id), saved.character.attributes.strength)
		_eq(body.matches_saved(saved.body_weight, saved.maximum_encumbrance), true, "human snapshot facts remain unchanged")
		for capacity_error: bool in [false, true]:
			var records: Array[Values.NpcSpawnStateSnapshot] = snapshot.npc_spawn_states
			for record: Values.NpcSpawnStateSnapshot in records:
				if record.character_id == saved.character_id:
					if capacity_error:
						record.maximum_encumbrance += 1
					else:
						record.body_weight += 1
			var malformed: GameSaveSnapshot = GameSaveSnapshot.new(snapshot.metadata, snapshot.session_kind, snapshot.item_id_allocator, snapshot.player, records, snapshot.corpses, snapshot.items, snapshot.combat_rng, snapshot.npc_initialization_rng, snapshot.world_interaction_rng)
			var result: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(malformed)
			_eq(result.outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "production restore rejects wrong human body/capacity")
			_eq(result.path.ends_with(".derived_character_facts"), true, "same failure boundary/path")
	# A representable DTO is not authorization to invent a production spawn slot.
	var beast: BeastFixture = BeastFixture.new()
	var extra_records: Array[Values.NpcSpawnStateSnapshot] = snapshot.npc_spawn_states
	extra_records.append(beast.capture().npc_spawn_states[0])
	var unsupported_slot: GameSaveSnapshot = GameSaveSnapshot.new(snapshot.metadata, snapshot.session_kind, snapshot.item_id_allocator, snapshot.player, extra_records, snapshot.corpses, snapshot.items, snapshot.combat_rng, snapshot.npc_initialization_rng, snapshot.world_interaction_rng)
	_eq(OldPineWorldRestoreComposition.prepare(unsupported_slot).outcome, OldPineWorldRestoreResult.Outcome.INCONSISTENT_SPAWN_STATE, "production ledger still rejects unapproved serpent slot")
	session.free()
	await tree.process_frame
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
