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
	_check(player.facts.is_legacy_technical(), "current New Game retains technical identity")
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
	_check(player.state.recovery.food == 0 and player.state.recovery.water == 0, "technical New Game not refilled")
	_check(session.active_map_id() == OldPineWorldDefinitions.OUTDOOR_MAP_ID, "Old Pine start unchanged")
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
		_check(encoded.succeeded(), "v1 encoding succeeds")
		var root: Dictionary = JSON.parse_string(encoded.text)
		var saved_player: Dictionary = root["player"]
		var saved_character: Dictionary = saved_player["character"]
		_check(int(root["metadata"]["schema_version"]) == 1, "no schema2")
		for missing: String in ["age", "display_name", "title", "race_id"]:
			_check(not saved_player.has(missing) and not saved_character.has(missing), "v1 does not serialize " + missing)
		# Deliberately not exp600; also test BOTH wielded and unwielded save graphs.
		for wielded: bool in [true, false]:
			player.state.progression.combat_experience = 731 if wielded else 0
			player.state.recovery.food = -7
			player.state.recovery.water = 923
			player.state.attributes.strength = 27
			player._maximum_encumbrance = 135000
			player.state.vitality.maximum = 357
			if not wielded:
				player.state.equipment.unwield(player.state.equipment.primary_weapon().instance_id)
			var saved: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"development", "2001-01-01T00:00:00Z")
			_check(saved.succeeded(), "arbitrary old save captures: " + saved.path + saved.detail)
			if not saved.succeeded():
				continue
			var roundtrip: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(saved.snapshot).text)
			_check(roundtrip.succeeded(), "arbitrary old save JSON roundtrip")
			var restored: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(roundtrip.snapshot)
			_check(restored.outcome == OldPineWorldRestoreResult.Outcome.SUCCESS, "old save prepares: " + restored.path + restored.detail)
			if restored.preparation == null:
				continue
			var old: WorldPlayerRuntimeState = restored.preparation.player
			_check(old.facts.display_name == "Player" and old.facts.age == 20 and old.facts.title.is_empty(), "schema1 implies legacy identity, not exp/sword/date heuristics")
			_check(old.state.progression.combat_experience == player.state.progression.combat_experience, "saved experience exact")
			_check(old.state.recovery.food == -7 and old.state.recovery.water == 923, "restore does not fill or clamp food/water")
			_check(old.state.attributes.strength == 27 and old.state.vitality.maximum == 357, "metadata does not rerun body/resource derivation")
			_check(old.state.equipment.are_both_hands_empty() == not wielded, "equipment preserved exactly")
			_check(old.armor.occupied_slots().is_empty(), "restore never grants cloth")
			_check(restored.preparation.item_index.snapshot_count() == 12, "same inventory count")
			_check(restored.preparation.item_allocator.next_dynamic_sequence == saved.snapshot.item_id_allocator.next_dynamic_sequence, "allocator not advanced by restore")
			_check(restored.preparation.item_allocator.scope == saved.snapshot.item_id_allocator.scope, "allocator scope preserved")
			for id: StringName in session.inventory_state().registered_item_ids():
				_check(restored.preparation.item_index.resolve(id) != null, "semantic item ID retained: " + String(id))
			_check(old.state != player.state and old.state.equipment != player.state.equipment, "fresh restore authorities")
	# QA-only injection of facts: prove v1 refuses silent metadata loss. No new schema.
	player._facts = PlayerIdentityFacts.new("初雪", "普通百姓", 14)
	var source_context: DeathContext = session.outdoor_map()._death_context_for(binding, null, destination)
	_check(source_context.victim_age == 14 and source_context.victim_display_name == "初雪", "same outdoor production delegation reads source facts")
	var blocked: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"development", "2026-09-10T12:00:00Z")
	_check(blocked.outcome == OldPineWorldCaptureResult.Outcome.UNREPRESENTED_CHARACTER_STATE and blocked.path == "player.facts", "v1 fails closed for source identity")
	player._facts = PlayerIdentityFacts.legacy_technical()
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _check(value: bool, label: String) -> void:
	_count += 1
	if not value:
		_failures.append("NGE1 legacy: " + label)
