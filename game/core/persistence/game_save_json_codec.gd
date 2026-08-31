class_name GameSaveJsonCodec
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const Endpoint := preload("res://core/inventory/containment_endpoint.gd")

var _error: GameSaveResult


static func encode(snapshot: GameSaveSnapshot) -> GameSaveResult:
	var validation: GameSaveResult = GameSaveSnapshotValidator.validate(snapshot)
	if not validation.succeeded(): return validation
	var codec := GameSaveJsonCodec.new()
	var root: Dictionary[String, Variant] = codec._encode_root(snapshot)
	return GameSaveResult.encoded_success(JSON.stringify(root, "\t", false))


static func decode(text: String) -> GameSaveResult:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return GameSaveResult.failure(GameSaveResult.Outcome.MALFORMED_JSON, "root", parser.get_error_message())
	var codec := GameSaveJsonCodec.new()
	var snapshot: GameSaveSnapshot = codec._decode_root(parser.data)
	if codec._error != null: return codec._error
	return GameSaveSnapshotValidator.validate(snapshot)


func _encode_root(snapshot: GameSaveSnapshot) -> Dictionary[String, Variant]:
	var npcs: Array[Variant] = []
	for npc: Values.NpcSpawnStateSnapshot in snapshot.npc_spawn_states: npcs.append(_encode_npc(npc))
	var corpses: Array[Variant] = []
	for corpse: Values.CorpseSnapshot in snapshot.corpses: corpses.append(_encode_corpse(corpse))
	return {
		"metadata": {
			"format_id": snapshot.metadata.format_id,
			"schema_version": snapshot.metadata.schema_version,
			"saved_at_utc": snapshot.metadata.saved_at_utc,
			"build_commit": snapshot.metadata.build_commit.value if snapshot.metadata.build_commit.has_value else null,
			"storage_profile": String(snapshot.metadata.storage_profile),
			"slot_id": String(snapshot.metadata.slot_id),
		},
		"session_kind": String(snapshot.session_kind),
		"item_id_allocator": {"scope": String(snapshot.item_id_allocator.scope), "next_dynamic_sequence": _i(snapshot.item_id_allocator.next_dynamic_sequence)},
		"player": _encode_player(snapshot.player),
		"npc_spawn_states": npcs,
		"corpses": corpses,
		"items": _encode_items(snapshot.items),
		"rng": {
			"combat": _encode_rng(snapshot.combat_rng),
			"npc_initialization": _encode_rng(snapshot.npc_initialization_rng),
			"world_interaction": _encode_rng(snapshot.world_interaction_rng),
		},
	}


func _encode_character(value: Values.CharacterStateSnapshot) -> Dictionary[String, Variant]:
	var raw: Array[Variant] = []
	for record: Values.SkillValueSnapshot in value.skills.raw_levels: raw.append({"skill_id": String(record.skill_id), "value": _i(record.value)})
	var learned: Array[Variant] = []
	for record: Values.SkillValueSnapshot in value.skills.learned_progress: learned.append({"skill_id": String(record.skill_id), "value": _i(record.value)})
	var mappings: Array[Variant] = []
	for record: Values.SkillMappingSnapshot in value.skills.mappings: mappings.append({"use_id": String(record.use_id), "skill_id": String(record.skill_id)})
	var conditions: Array[Variant] = []
	for condition: Values.ConditionSnapshot in value.conditions:
		if condition.payload_kind == Values.ConditionSnapshot.KIND_DURATION:
			conditions.append({"condition_id": String(condition.condition_id), "payload_kind": "duration", "remaining": _i(condition.remaining)})
		else:
			conditions.append({"condition_id": String(condition.condition_id), "payload_kind": "poison", "damage": _i(condition.damage), "remaining": _i(condition.remaining), "legacy_message": condition.legacy_message})
	return {
		"gender": String(value.gender),
		"attributes": {
			"strength": _i(value.attributes.strength), "courage": _i(value.attributes.courage),
			"intelligence": _i(value.attributes.intelligence), "spirituality": _i(value.attributes.spirituality),
			"composure": _i(value.attributes.composure), "personality": _i(value.attributes.personality),
			"constitution": _i(value.attributes.constitution), "karma": _i(value.attributes.karma),
			"force_factor": _i(value.attributes.force_factor), "bellicosity": _i(value.attributes.bellicosity),
		},
		"resources": {"gin": _encode_track(value.gin), "kee": _encode_track(value.kee), "sen": _encode_track(value.sen)},
		"internal_resources": {
			"force": _i(value.internal_resources.force), "max_force": _i(value.internal_resources.max_force),
			"mana": _i(value.internal_resources.mana), "max_mana": _i(value.internal_resources.max_mana),
			"atman": _i(value.internal_resources.atman), "max_atman": _i(value.internal_resources.max_atman),
			"food": _i(value.internal_resources.food), "water": _i(value.internal_resources.water),
		},
		"progression": {"combat_experience": _i(value.progression.combat_experience), "potential": _i(value.progression.potential), "potential_spent": _i(value.progression.potential_spent)},
		"skills": {"has_skills_mapping": value.skills.has_skills_mapping, "has_learned_mapping": value.skills.has_learned_mapping, "raw_levels": raw, "learned_progress": learned, "mappings": mappings},
		"conditions": conditions,
		"family": {"family_id": String(value.family.family_id), "generation": _i(value.family.generation)},
		"apprenticeship": {"master_teacher_id": String(value.apprenticeship.master_teacher_id), "legacy_master_name": value.apprenticeship.legacy_master_name, "betrayer_count": _i(value.apprenticeship.betrayer_count)},
	}


func _encode_track(value: Values.ResourceTrackSnapshot) -> Dictionary[String, Variant]:
	return {"current": _i(value.current), "effective": _i(value.effective), "maximum": _i(value.maximum)}


func _encode_player(value: Values.PlayerRuntimeSnapshot) -> Dictionary[String, Variant]:
	return {"character_id": String(value.character_id), "character": _encode_character(value.character), "life_status": String(value.life_status), "exists_in_world": value.exists_in_world, "combat_available": value.combat_available, "maximum_encumbrance": _i(value.maximum_encumbrance), "world_location": _encode_location(value.world_location), "map_position": {"x": value.map_position.x, "y": value.map_position.y}}


func _encode_npc(value: Values.NpcSpawnStateSnapshot) -> Dictionary[String, Variant]:
	var loadout: Array[Variant] = []
	for item_id: StringName in value.live_loadout_item_ids: loadout.append(String(item_id))
	return {"spawn_id": String(value.spawn_id), "spawn_point_id": String(value.spawn_point_id), "npc_definition_id": String(value.npc_definition_id), "character_id": String(value.character_id), "exists_in_world": value.exists_in_world, "life_status": String(value.life_status), "combat_available": value.combat_available, "character": _encode_character(value.character), "age": _i(value.age), "body_weight": _i(value.body_weight), "maximum_encumbrance": _i(value.maximum_encumbrance), "world_location": _encode_location(value.world_location), "map_position": {"x": value.map_position.x, "y": value.map_position.y}, "live_loadout_item_ids": loadout}


func _encode_corpse(value: Values.CorpseSnapshot) -> Dictionary[String, Variant]:
	var worn: Array[Variant] = []
	for record: Values.CorpseWornItemSnapshot in value.worn_items: worn.append({"armor_type": String(record.armor_type), "item_instance_id": String(record.item_instance_id)})
	return {"corpse_item_instance_id": String(value.corpse_item_instance_id), "victim_character_id": String(value.victim_character_id), "victim_display_name": value.victim_display_name, "victim_gender": String(value.victim_gender), "victim_age": _i(value.victim_age), "decay_stage": _i(value.decay_stage), "maximum_contents_encumbrance": _i(value.maximum_contents_encumbrance), "worn_items": worn, "world_location": _encode_location(value.world_location), "map_position": {"x": value.map_position.x, "y": value.map_position.y}}


func _encode_location(value: Values.WorldLocationSnapshot) -> Dictionary[String, Variant]:
	return {"region_id": String(value.region_id), "map_id": String(value.map_id), "zone_id": String(value.zone_id), "combat_location_id": String(value.combat_location_id)}


func _encode_rng(value: RandomStreamSnapshot) -> Dictionary[String, Variant]:
	return {"adapter_id": String(value.adapter_id), "seed": _i(value.seed), "state": _i(value.state)}


func _encode_items(value: NativeItemStateSnapshot) -> Dictionary[String, Variant]:
	var records: Array[Variant] = []
	for record: NativeItemRecord in value.item_records:
		var parent: Variant = null
		if record.direct_parent != null:
			parent = {"kind": _endpoint_kind(record.direct_parent.kind), "endpoint_id": String(record.direct_parent.endpoint_id)}
		records.append({"item_instance_id": String(record.item_instance_id), "item_definition_id": String(record.item_definition_id), "own_weight": _i(record.own_weight), "direct_parent": parent})
	var stacks: Array[Variant] = []
	for record: NativeCombinedStackRecord in value.combined_stack_records: stacks.append({"item_instance_id": String(record.item_instance_id), "amount": _i(record.amount)})
	var equipment: Array[Variant] = []
	for record: NativeCharacterEquipmentRecord in value.character_equipment_records:
		equipment.append({"character_id": String(record.character_id), "primary_item_instance_id": null if record.primary_item_instance_id.is_empty() else String(record.primary_item_instance_id), "secondary_item_instance_id": null if record.secondary_item_instance_id.is_empty() else String(record.secondary_item_instance_id)})
	var armor: Array[Variant] = []
	for record: NativeCharacterArmorRecord in value.character_armor_records:
		var slots: Array[Variant] = []
		for slot: NativeArmorSlotRecord in record.slots: slots.append({"armor_type": String(slot.armor_type), "item_instance_id": String(slot.item_instance_id)})
		armor.append({"character_id": String(record.character_id), "slots": slots})
	return {"schema_version": value.schema_version, "records": records, "combined_stacks": stacks, "equipment": equipment, "armor": armor}


func _decode_root(value: Variant) -> GameSaveSnapshot:
	if typeof(value) != TYPE_DICTIONARY:
		_fail(GameSaveResult.Outcome.INVALID_ROOT, "root", "expected object")
		return null
	var root: Dictionary = _obj(value, "root", ["metadata", "session_kind", "item_id_allocator", "player", "npc_spawn_states", "corpses", "items", "rng"])
	if _error: return null
	var metadata_object: Dictionary = _obj(root["metadata"], "metadata", ["format_id", "schema_version", "saved_at_utc", "build_commit", "storage_profile", "slot_id"])
	if _error: return null
	var format_id: String = _string(metadata_object["format_id"], "metadata.format_id")
	var schema: int = _small_int(metadata_object["schema_version"], "metadata.schema_version")
	var build_commit_value: Variant = metadata_object["build_commit"]
	if build_commit_value != null and typeof(build_commit_value) != TYPE_STRING: _fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, "metadata.build_commit")
	if _error: return null
	if format_id != GameSaveSnapshot.FORMAT_ID: _fail(GameSaveResult.Outcome.INVALID_FORMAT_ID, "metadata.format_id")
	if schema != GameSaveSnapshot.CURRENT_SCHEMA_VERSION: _fail(GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA, "metadata.schema_version")
	if _error: return null
	var build_commit: Values.OptionalText = Values.OptionalText.none() if build_commit_value == null else Values.OptionalText.some(build_commit_value)
	var metadata := Values.GameSaveMetadata.new(format_id, schema, _string(metadata_object["saved_at_utc"], "metadata.saved_at_utc"), build_commit, StringName(_string(metadata_object["storage_profile"], "metadata.storage_profile")), StringName(_string(metadata_object["slot_id"], "metadata.slot_id")))
	var allocator_object: Dictionary = _obj(root["item_id_allocator"], "item_id_allocator", ["scope", "next_dynamic_sequence"])
	if _error: return null
	var allocator := Values.ItemIdAllocatorSnapshot.new(StringName(_string(allocator_object["scope"], "item_id_allocator.scope")), _int64(allocator_object["next_dynamic_sequence"], "item_id_allocator.next_dynamic_sequence"))
	var npc_values: Array = _array(root["npc_spawn_states"], "npc_spawn_states")
	var npcs: Array[Values.NpcSpawnStateSnapshot] = []
	for index: int in range(npc_values.size()): npcs.append(_decode_npc(npc_values[index], "npc_spawn_states[%d]" % index))
	var corpse_values: Array = _array(root["corpses"], "corpses")
	var corpses: Array[Values.CorpseSnapshot] = []
	for index: int in range(corpse_values.size()): corpses.append(_decode_corpse(corpse_values[index], "corpses[%d]" % index))
	var rng_object: Dictionary = _obj(root["rng"], "rng", ["combat", "npc_initialization", "world_interaction"])
	if _error: return null
	return GameSaveSnapshot.new(metadata, StringName(_string(root["session_kind"], "session_kind")), allocator, _decode_player(root["player"], "player"), npcs, corpses, _decode_items(root["items"], "items"), _decode_rng(rng_object["combat"], "rng.combat"), _decode_rng(rng_object["npc_initialization"], "rng.npc_initialization"), _decode_rng(rng_object["world_interaction"], "rng.world_interaction"))


func _decode_character(value: Variant, path: String) -> Values.CharacterStateSnapshot:
	var object: Dictionary = _obj(value, path, ["gender", "attributes", "resources", "internal_resources", "progression", "skills", "conditions", "family", "apprenticeship"])
	if _error: return null
	var a: Dictionary = _obj(object["attributes"], path + ".attributes", ["strength", "courage", "intelligence", "spirituality", "composure", "personality", "constitution", "karma", "force_factor", "bellicosity"])
	var attributes := Values.BaseAttributesSnapshot.new(_int64(a.get("strength"), path + ".attributes.strength"), _int64(a.get("courage"), path + ".attributes.courage"), _int64(a.get("intelligence"), path + ".attributes.intelligence"), _int64(a.get("spirituality"), path + ".attributes.spirituality"), _int64(a.get("composure"), path + ".attributes.composure"), _int64(a.get("personality"), path + ".attributes.personality"), _int64(a.get("constitution"), path + ".attributes.constitution"), _int64(a.get("karma"), path + ".attributes.karma"), _int64(a.get("force_factor"), path + ".attributes.force_factor"), _int64(a.get("bellicosity"), path + ".attributes.bellicosity"))
	var resources: Dictionary = _obj(object["resources"], path + ".resources", ["gin", "kee", "sen"])
	var internal: Dictionary = _obj(object["internal_resources"], path + ".internal_resources", ["force", "max_force", "mana", "max_mana", "atman", "max_atman", "food", "water"])
	var internal_resources := Values.InternalResourcesSnapshot.new(_int64(internal.get("force"), path + ".internal_resources.force"), _int64(internal.get("max_force"), path + ".internal_resources.max_force"), _int64(internal.get("mana"), path + ".internal_resources.mana"), _int64(internal.get("max_mana"), path + ".internal_resources.max_mana"), _int64(internal.get("atman"), path + ".internal_resources.atman"), _int64(internal.get("max_atman"), path + ".internal_resources.max_atman"), _int64(internal.get("food"), path + ".internal_resources.food"), _int64(internal.get("water"), path + ".internal_resources.water"))
	var progression_object: Dictionary = _obj(object["progression"], path + ".progression", ["combat_experience", "potential", "potential_spent"])
	var progression := Values.ProgressionSnapshot.new(_int64(progression_object.get("combat_experience"), path + ".progression.combat_experience"), _int64(progression_object.get("potential"), path + ".progression.potential"), _int64(progression_object.get("potential_spent"), path + ".progression.potential_spent"))
	var skills_object: Dictionary = _obj(object["skills"], path + ".skills", ["has_skills_mapping", "has_learned_mapping", "raw_levels", "learned_progress", "mappings"])
	var raw: Array[Values.SkillValueSnapshot] = _decode_skill_values(skills_object.get("raw_levels"), path + ".skills.raw_levels")
	var learned: Array[Values.SkillValueSnapshot] = _decode_skill_values(skills_object.get("learned_progress"), path + ".skills.learned_progress")
	var mapping_values: Array = _array(skills_object.get("mappings"), path + ".skills.mappings")
	var mappings: Array[Values.SkillMappingSnapshot] = []
	for index: int in range(mapping_values.size()):
		var mapping: Dictionary = _obj(mapping_values[index], path + ".skills.mappings[%d]" % index, ["use_id", "skill_id"])
		mappings.append(Values.SkillMappingSnapshot.new(StringName(_string(mapping.get("use_id"), path + ".skills.mappings[%d].use_id" % index)), StringName(_string(mapping.get("skill_id"), path + ".skills.mappings[%d].skill_id" % index))))
	var skills := Values.SkillStateSnapshot.new(_bool(skills_object.get("has_skills_mapping"), path + ".skills.has_skills_mapping"), _bool(skills_object.get("has_learned_mapping"), path + ".skills.has_learned_mapping"), raw, learned, mappings)
	var condition_values: Array = _array(object["conditions"], path + ".conditions")
	var conditions: Array[Values.ConditionSnapshot] = []
	for index: int in range(condition_values.size()): conditions.append(_decode_condition(condition_values[index], path + ".conditions[%d]" % index))
	var family_object: Dictionary = _obj(object["family"], path + ".family", ["family_id", "generation"])
	var family := Values.FamilySnapshot.new(StringName(_string(family_object.get("family_id"), path + ".family.family_id")), _int64(family_object.get("generation"), path + ".family.generation"))
	var apprentice_object: Dictionary = _obj(object["apprenticeship"], path + ".apprenticeship", ["master_teacher_id", "legacy_master_name", "betrayer_count"])
	var apprenticeship := Values.ApprenticeshipSnapshot.new(StringName(_string(apprentice_object.get("master_teacher_id"), path + ".apprenticeship.master_teacher_id")), _string(apprentice_object.get("legacy_master_name"), path + ".apprenticeship.legacy_master_name"), _int64(apprentice_object.get("betrayer_count"), path + ".apprenticeship.betrayer_count"))
	if _error: return null
	return Values.CharacterStateSnapshot.new(StringName(_string(object["gender"], path + ".gender")), attributes, _decode_track(resources.get("gin"), path + ".resources.gin"), _decode_track(resources.get("kee"), path + ".resources.kee"), _decode_track(resources.get("sen"), path + ".resources.sen"), internal_resources, progression, skills, conditions, family, apprenticeship)


func _decode_track(value: Variant, path: String) -> Values.ResourceTrackSnapshot:
	var object: Dictionary = _obj(value, path, ["current", "effective", "maximum"])
	return Values.ResourceTrackSnapshot.new(_int64(object.get("current"), path + ".current"), _int64(object.get("effective"), path + ".effective"), _int64(object.get("maximum"), path + ".maximum"))


func _decode_skill_values(value: Variant, path: String) -> Array[Values.SkillValueSnapshot]:
	var values: Array = _array(value, path)
	var result: Array[Values.SkillValueSnapshot] = []
	for index: int in range(values.size()):
		var object: Dictionary = _obj(values[index], path + "[%d]" % index, ["skill_id", "value"])
		result.append(Values.SkillValueSnapshot.new(StringName(_string(object.get("skill_id"), path + "[%d].skill_id" % index)), _int64(object.get("value"), path + "[%d].value" % index)))
	return result


func _decode_condition(value: Variant, path: String) -> Values.ConditionSnapshot:
	if typeof(value) != TYPE_DICTIONARY:
		_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path)
		return null
	var raw: Dictionary = value
	if not raw.has("payload_kind"):
		_fail(GameSaveResult.Outcome.MISSING_FIELD, path + ".payload_kind")
		return null
	var kind: String = _string(raw["payload_kind"], path + ".payload_kind")
	var object: Dictionary
	if kind == "duration":
		object = _obj(value, path, ["condition_id", "payload_kind", "remaining"])
		return Values.ConditionSnapshot.duration(StringName(_string(object.get("condition_id"), path + ".condition_id")), _int64(object.get("remaining"), path + ".remaining"))
	if kind == "poison":
		object = _obj(value, path, ["condition_id", "payload_kind", "damage", "remaining", "legacy_message"])
		return Values.ConditionSnapshot.poison(StringName(_string(object.get("condition_id"), path + ".condition_id")), _int64(object.get("damage"), path + ".damage"), _int64(object.get("remaining"), path + ".remaining"), _string(object.get("legacy_message"), path + ".legacy_message"))
	_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path + ".payload_kind", "unsupported condition payload")
	return null


func _decode_player(value: Variant, path: String) -> Values.PlayerRuntimeSnapshot:
	var object: Dictionary = _obj(value, path, ["character_id", "character", "life_status", "exists_in_world", "combat_available", "maximum_encumbrance", "world_location", "map_position"])
	if _error: return null
	return Values.PlayerRuntimeSnapshot.new(StringName(_string(object["character_id"], path + ".character_id")), _decode_character(object["character"], path + ".character"), StringName(_string(object["life_status"], path + ".life_status")), _bool(object["exists_in_world"], path + ".exists_in_world"), _bool(object["combat_available"], path + ".combat_available"), _int64(object["maximum_encumbrance"], path + ".maximum_encumbrance"), _decode_location(object["world_location"], path + ".world_location"), _decode_position(object["map_position"], path + ".map_position"))


func _decode_npc(value: Variant, path: String) -> Values.NpcSpawnStateSnapshot:
	var object: Dictionary = _obj(value, path, ["spawn_id", "spawn_point_id", "npc_definition_id", "character_id", "exists_in_world", "life_status", "combat_available", "character", "age", "body_weight", "maximum_encumbrance", "world_location", "map_position", "live_loadout_item_ids"])
	if _error: return null
	var ids: Array[StringName] = _decode_id_array(object["live_loadout_item_ids"], path + ".live_loadout_item_ids")
	return Values.NpcSpawnStateSnapshot.new(StringName(_string(object["spawn_id"], path + ".spawn_id")), StringName(_string(object["spawn_point_id"], path + ".spawn_point_id")), StringName(_string(object["npc_definition_id"], path + ".npc_definition_id")), StringName(_string(object["character_id"], path + ".character_id")), _bool(object["exists_in_world"], path + ".exists_in_world"), StringName(_string(object["life_status"], path + ".life_status")), _bool(object["combat_available"], path + ".combat_available"), _decode_character(object["character"], path + ".character"), _int64(object["age"], path + ".age"), _int64(object["body_weight"], path + ".body_weight"), _int64(object["maximum_encumbrance"], path + ".maximum_encumbrance"), _decode_location(object["world_location"], path + ".world_location"), _decode_position(object["map_position"], path + ".map_position"), ids)


func _decode_corpse(value: Variant, path: String) -> Values.CorpseSnapshot:
	var object: Dictionary = _obj(value, path, ["corpse_item_instance_id", "victim_character_id", "victim_display_name", "victim_gender", "victim_age", "decay_stage", "maximum_contents_encumbrance", "worn_items", "world_location", "map_position"])
	if _error: return null
	var worn_values: Array = _array(object["worn_items"], path + ".worn_items")
	var worn: Array[Values.CorpseWornItemSnapshot] = []
	for index: int in range(worn_values.size()):
		var record: Dictionary = _obj(worn_values[index], path + ".worn_items[%d]" % index, ["armor_type", "item_instance_id"])
		worn.append(Values.CorpseWornItemSnapshot.new(StringName(_string(record.get("armor_type"), path + ".worn_items[%d].armor_type" % index)), StringName(_string(record.get("item_instance_id"), path + ".worn_items[%d].item_instance_id" % index))))
	return Values.CorpseSnapshot.new(StringName(_string(object["corpse_item_instance_id"], path + ".corpse_item_instance_id")), StringName(_string(object["victim_character_id"], path + ".victim_character_id")), _string(object["victim_display_name"], path + ".victim_display_name"), StringName(_string(object["victim_gender"], path + ".victim_gender")), _int64(object["victim_age"], path + ".victim_age"), _int64(object["decay_stage"], path + ".decay_stage"), _int64(object["maximum_contents_encumbrance"], path + ".maximum_contents_encumbrance"), worn, _decode_location(object["world_location"], path + ".world_location"), _decode_position(object["map_position"], path + ".map_position"))


func _decode_location(value: Variant, path: String) -> Values.WorldLocationSnapshot:
	var object: Dictionary = _obj(value, path, ["region_id", "map_id", "zone_id", "combat_location_id"])
	return Values.WorldLocationSnapshot.new(StringName(_string(object.get("region_id"), path + ".region_id")), StringName(_string(object.get("map_id"), path + ".map_id")), StringName(_string(object.get("zone_id"), path + ".zone_id")), StringName(_string(object.get("combat_location_id"), path + ".combat_location_id")))


func _decode_position(value: Variant, path: String) -> Values.MapPositionSnapshot:
	var object: Dictionary = _obj(value, path, ["x", "y"])
	return Values.MapPositionSnapshot.new(_finite(object.get("x"), path + ".x"), _finite(object.get("y"), path + ".y"))


func _decode_rng(value: Variant, path: String) -> RandomStreamSnapshot:
	var object: Dictionary = _obj(value, path, ["adapter_id", "seed", "state"])
	var result := RandomStreamSnapshot.new(StringName(_string(object.get("adapter_id"), path + ".adapter_id")), _int64(object.get("seed"), path + ".seed"), _int64(object.get("state"), path + ".state"))
	if not result.is_supported(): _fail(GameSaveResult.Outcome.INVALID_RANDOM_STREAM, path + ".adapter_id")
	return result


func _decode_items(value: Variant, path: String) -> NativeItemStateSnapshot:
	var object: Dictionary = _obj(value, path, ["schema_version", "records", "combined_stacks", "equipment", "armor"])
	if _error: return null
	var schema: int = _small_int(object["schema_version"], path + ".schema_version")
	if schema != NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION: _fail(GameSaveResult.Outcome.UNSUPPORTED_ITEM_SCHEMA, path + ".schema_version")
	var records: Array[NativeItemRecord] = []
	var record_values: Array = _array(object["records"], path + ".records")
	for index: int in range(record_values.size()):
		var record_path: String = path + ".records[%d]" % index
		var record: Dictionary = _obj(record_values[index], record_path, ["item_instance_id", "item_definition_id", "own_weight", "direct_parent"])
		var parent: ContainmentEndpoint = null
		if record.get("direct_parent") != null:
			var parent_object: Dictionary = _obj(record["direct_parent"], record_path + ".direct_parent", ["kind", "endpoint_id"])
			parent = Endpoint.new(_endpoint_kind_value(_string(parent_object.get("kind"), record_path + ".direct_parent.kind"), record_path + ".direct_parent.kind"), StringName(_string(parent_object.get("endpoint_id"), record_path + ".direct_parent.endpoint_id")))
		records.append(NativeItemRecord.new(StringName(_string(record.get("item_instance_id"), record_path + ".item_instance_id")), StringName(_string(record.get("item_definition_id"), record_path + ".item_definition_id")), _int64(record.get("own_weight"), record_path + ".own_weight"), parent))
	var stacks: Array[NativeCombinedStackRecord] = []
	var stack_values: Array = _array(object["combined_stacks"], path + ".combined_stacks")
	for index: int in range(stack_values.size()):
		var record_path: String = path + ".combined_stacks[%d]" % index
		var record: Dictionary = _obj(stack_values[index], record_path, ["item_instance_id", "amount"])
		stacks.append(NativeCombinedStackRecord.new(StringName(_string(record.get("item_instance_id"), record_path + ".item_instance_id")), _int64(record.get("amount"), record_path + ".amount")))
	var equipment: Array[NativeCharacterEquipmentRecord] = []
	var equipment_values: Array = _array(object["equipment"], path + ".equipment")
	for index: int in range(equipment_values.size()):
		var record_path: String = path + ".equipment[%d]" % index
		var record: Dictionary = _obj(equipment_values[index], record_path, ["character_id", "primary_item_instance_id", "secondary_item_instance_id"])
		equipment.append(NativeCharacterEquipmentRecord.new(StringName(_string(record.get("character_id"), record_path + ".character_id")), _nullable_id(record.get("primary_item_instance_id"), record_path + ".primary_item_instance_id"), _nullable_id(record.get("secondary_item_instance_id"), record_path + ".secondary_item_instance_id")))
	var armor: Array[NativeCharacterArmorRecord] = []
	var armor_values: Array = _array(object["armor"], path + ".armor")
	for index: int in range(armor_values.size()):
		var record_path: String = path + ".armor[%d]" % index
		var record: Dictionary = _obj(armor_values[index], record_path, ["character_id", "slots"])
		var slot_values: Array = _array(record.get("slots"), record_path + ".slots")
		var slots: Array[NativeArmorSlotRecord] = []
		for slot_index: int in range(slot_values.size()):
			var slot_path: String = record_path + ".slots[%d]" % slot_index
			var slot: Dictionary = _obj(slot_values[slot_index], slot_path, ["armor_type", "item_instance_id"])
			slots.append(NativeArmorSlotRecord.new(StringName(_string(slot.get("armor_type"), slot_path + ".armor_type")), StringName(_string(slot.get("item_instance_id"), slot_path + ".item_instance_id"))))
		armor.append(NativeCharacterArmorRecord.new(StringName(_string(record.get("character_id"), record_path + ".character_id")), slots))
	return NativeItemStateSnapshot.new(schema, records, stacks, equipment, armor)


func _obj(value: Variant, path: String, expected_keys: Array[String]) -> Dictionary:
	if _error: return {}
	if typeof(value) != TYPE_DICTIONARY:
		_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "expected object")
		return {}
	var object: Dictionary = value
	for key: String in expected_keys:
		if not object.has(key):
			_fail(GameSaveResult.Outcome.MISSING_FIELD, path + "." + key)
			return {}
	for key: Variant in object.keys():
		if typeof(key) != TYPE_STRING or not expected_keys.has(key):
			_fail(GameSaveResult.Outcome.INVALID_ROOT, path + "." + str(key), "unknown field")
			return {}
	return object


func _array(value: Variant, path: String) -> Array:
	if _error: return []
	if typeof(value) != TYPE_ARRAY:
		_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "expected array")
		return []
	return value


func _string(value: Variant, path: String) -> String:
	if _error: return ""
	if typeof(value) != TYPE_STRING:
		_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "expected string")
		return ""
	return value


func _bool(value: Variant, path: String) -> bool:
	if _error: return false
	if typeof(value) != TYPE_BOOL:
		_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "expected boolean")
		return false
	return value


func _small_int(value: Variant, path: String) -> int:
	if _error: return 0
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value and value >= -2147483648.0 and value <= 2147483647.0:
		return int(value)
	else:
		_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "expected integer")
		return 0


func _int64(value: Variant, path: String) -> int:
	if _error: return 0
	var result: GameSaveResult = DecimalInt64Codec.decode(value, path)
	if not result.succeeded():
		_error = result
		return 0
	return DecimalInt64Codec.integer_value(result)


func _finite(value: Variant, path: String) -> float:
	if _error: return 0.0
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "expected number")
		return 0.0
	var number: float = float(value)
	if not is_finite(number):
		_fail(GameSaveResult.Outcome.INVALID_FINITE_NUMBER, path)
		return 0.0
	return number


func _decode_id_array(value: Variant, path: String) -> Array[StringName]:
	var values: Array = _array(value, path)
	var result: Array[StringName] = []
	for index: int in range(values.size()): result.append(StringName(_string(values[index], path + "[%d]" % index)))
	return result


func _nullable_id(value: Variant, path: String) -> StringName:
	if value == null: return &""
	var decoded: String = _string(value, path)
	if decoded.is_empty(): _fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "optional ID must be null or nonempty")
	return StringName(decoded)


func _endpoint_kind(kind: int) -> String:
	match kind:
		Endpoint.Kind.CHARACTER: return "character"
		Endpoint.Kind.ITEM: return "item"
		Endpoint.Kind.WORLD: return "world"
	return "invalid"


func _endpoint_kind_value(value: String, path: String) -> int:
	match value:
		"character": return Endpoint.Kind.CHARACTER
		"item": return Endpoint.Kind.ITEM
		"world": return Endpoint.Kind.WORLD
	_fail(GameSaveResult.Outcome.INVALID_FIELD_TYPE, path, "unknown endpoint kind")
	return Endpoint.Kind.INVALID


func _fail(outcome: int, path: String, detail: String = "") -> void:
	if _error == null: _error = GameSaveResult.failure(outcome, path, detail)


static func _i(value: int) -> String:
	return DecimalInt64Codec.encode(value)
