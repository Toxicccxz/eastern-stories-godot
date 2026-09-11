extends RefCounted

const SessionScene := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: OldPineWorldSessionController = SessionScene.instantiate()
	session.deterministic_npc_seed = true
	session.npc_seed = 2031
	session.deterministic_combat_seed = true
	session.combat_seed = 2032
	session.deterministic_world_interaction_seed = true
	session.world_interaction_seed = 2033
	tree.root.add_child(session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(player.facts.is_legacy_technical(), "explicit internal fixture retains technical identity")
	_check(player.state.progression.combat_experience == 600, "technical experience stays 600")
	_check(player.state.equipment.primary_weapon_skill_type() == &"sword", "technical starter sword remains")
	_check(player.state.equipment.primary_weapon().weapon_id == CombatSliceContentProfile.LONG_SWORD_ID, "exact old long-sword definition")
	var attributes: CharacterBaseAttributes = player.state.attributes
	for value: int in [attributes.strength, attributes.courage, attributes.intelligence, attributes.spirituality, attributes.composure, attributes.personality, attributes.constitution, attributes.karma]:
		_check(value == 20, "technical base attributes remain 20")
	_check(player.state.essence.current == 220 and player.state.essence.effective == 220 and player.state.essence.maximum == 220, "technical gin unchanged")
	_check(player.state.vitality.current == 220 and player.state.vitality.effective == 220 and player.state.vitality.maximum == 220, "technical kee unchanged")
	_check(player.state.spirit.current == 100 and player.state.spirit.effective == 100 and player.state.spirit.maximum == 100, "technical sen unchanged")
	for skill: StringName in [&"sword", &"dodge", &"parry", &"unarmed"]:
		_check(player.state.skills.raw_level(skill) == 10, "technical skill unchanged")
	_check(player.state.recovery.food == 0 and player.state.recovery.water == 0, "technical fixture not refilled")
	_check(session.active_map_id() == OldPineWorldDefinitions.OUTDOOR_MAP_ID, "internal technical Old Pine start unchanged")
	_check(session.inventory_state().registered_item_ids().size() == 12, "12 original bootstrap items; no source cloth")
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"fixture"),
	)
	var context: DeathContext = player.death_context(destination, true)
	_check(context.victim_display_name == "Player" and context.victim_age == 20, "technical death name/age unchanged")
	_check(context.killer_was_present, "death killer fact preserved")
	# Exercise the production outdoor delegation, not just its extracted helper.
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_player(player, CombatSliceContentProfile.new())
	var outdoor_context: DeathContext = session.outdoor_map()._death_context_for(binding, null, destination)
	_check(outdoor_context.victim_age == 20 and outdoor_context.victim_display_name == "Player", "real outdoor death delegation retains technical facts")
	var capture: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"development", "2026-09-10T12:00:00Z")
	_check(capture.succeeded(), "production capture succeeds: " + capture.path + capture.detail)
	if capture.succeeded():
		var encoded: GameSaveResult = GameSaveJsonCodec.encode(capture.snapshot)
		var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
		_check(decoded.succeeded() and decoded.snapshot.metadata.schema_version == 2, "technical schema2 roundtrip")
		var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
		_check(restored.succeeded(), "technical current save cold candidate")
		if restored.succeeded():
			var cold: WorldPlayerRuntimeState = restored.candidate.player_runtime()
			_check(cold.facts.is_legacy_technical() and cold.state.progression.combat_experience == 600, "explicit technical identity and exp retained")
			_check(restored.candidate.resident_map_count() == 2 and cold.state.equipment.primary_weapon_skill_type() == &"sword", "technical two maps and sword retained")
			restored.candidate.free()
	# QA-only identity injection must not silently change the legacy world profile.
	player._facts = PlayerIdentityFacts.new("初雪", "普通百姓", 14)
	var source_context: DeathContext = session.outdoor_map()._death_context_for(binding, null, destination)
	_check(source_context.victim_age == 14 and source_context.victim_display_name == "初雪", "same outdoor production delegation reads source facts")
	var blocked: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"development", "2026-09-10T12:00:00Z")
	_check(blocked.outcome == OldPineWorldCaptureResult.Outcome.INVALID_CAPTURED_SNAPSHOT and blocked.path == "player.identity", "legacy profile fails closed for source identity")
	player._facts = PlayerIdentityFacts.legacy_technical()
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _check(value: bool, label: String) -> void:
	_count += 1
	if not value:
		_failures.append("NGE1 legacy: " + label)
