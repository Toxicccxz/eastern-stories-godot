class_name GameSaveSnapshotValidator
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")


static func validate(snapshot: GameSaveSnapshot) -> GameSaveResult:
	if snapshot == null:
		return _invalid("root", "snapshot is null")
	if snapshot.metadata == null:
		return _invalid("metadata", "metadata is null")
	if snapshot.metadata.format_id != GameSaveSnapshot.FORMAT_ID:
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_FORMAT_ID, "metadata.format_id")
	if snapshot.metadata.schema_version != GameSaveSnapshot.CURRENT_SCHEMA_VERSION:
		return GameSaveResult.failure(GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA, "metadata.schema_version")
	if snapshot.metadata.saved_at_utc.is_empty():
		return _invalid("metadata.saved_at_utc", "timestamp is required metadata")
	if snapshot.metadata.slot_id != GameSaveSnapshot.FIXED_SLOT_ID:
		return _invalid("metadata.slot_id", "unsupported slot")
	if snapshot.metadata.storage_profile not in [&"development", &"release", &"test"]:
		return _invalid("metadata.storage_profile", "unsupported storage profile")
	if snapshot.session_kind != GameSaveSnapshot.SESSION_KIND_OLDPINE:
		return _invalid("session_kind", "unsupported session kind")
	if snapshot.item_id_allocator == null or snapshot.item_id_allocator.scope.is_empty():
		return _invalid("item_id_allocator.scope", "empty allocator scope")
	if snapshot.player == null or snapshot.player.character_id.is_empty():
		return _invalid("player.character_id", "empty character ID")
	var player_result: GameSaveResult = _validate_runtime_character(snapshot.player.character, snapshot.player.life_status, snapshot.player.world_location, snapshot.player.map_position, "player")
	if not player_result.succeeded(): return player_result
	if snapshot.items == null:
		return _invalid("items", "item snapshot is null")
	if snapshot.items.schema_version != NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION:
		return GameSaveResult.failure(GameSaveResult.Outcome.UNSUPPORTED_ITEM_SCHEMA, "items.schema_version")
	var item_ids: Dictionary[StringName, bool] = {}
	for index: int in range(snapshot.items.item_records.size()):
		var item: NativeItemRecord = snapshot.items.item_records[index]
		if item == null or item.item_instance_id.is_empty() or item.item_definition_id.is_empty():
			return _invalid("items.records[%d].item_instance_id" % index, "empty item ID")
		if item.direct_parent != null and not item.direct_parent.is_valid():
			return _invalid("items.records[%d].direct_parent" % index, "invalid parent")
		if item_ids.has(item.item_instance_id):
			return _duplicate("items.records[%d].item_instance_id" % index)
		item_ids[item.item_instance_id] = true
	var stack_ids: Dictionary[StringName, bool] = {}
	for index: int in range(snapshot.items.combined_stack_records.size()):
		var stack: NativeCombinedStackRecord = snapshot.items.combined_stack_records[index]
		if stack == null or stack.item_instance_id.is_empty(): return _invalid("items.combined_stacks[%d]" % index, "empty stack ID")
		if stack_ids.has(stack.item_instance_id): return _duplicate("items.combined_stacks[%d].item_instance_id" % index)
		stack_ids[stack.item_instance_id] = true
	var equipment_characters: Dictionary[StringName, bool] = {}
	for index: int in range(snapshot.items.character_equipment_records.size()):
		var equipment: NativeCharacterEquipmentRecord = snapshot.items.character_equipment_records[index]
		if equipment == null or equipment.character_id.is_empty(): return _invalid("items.equipment[%d].character_id" % index, "empty character ID")
		if equipment_characters.has(equipment.character_id): return _duplicate("items.equipment[%d].character_id" % index)
		equipment_characters[equipment.character_id] = true
	var armor_characters: Dictionary[StringName, bool] = {}
	for index: int in range(snapshot.items.character_armor_records.size()):
		var armor: NativeCharacterArmorRecord = snapshot.items.character_armor_records[index]
		if armor == null or armor.character_id.is_empty(): return _invalid("items.armor[%d].character_id" % index, "empty character ID")
		if armor_characters.has(armor.character_id): return _duplicate("items.armor[%d].character_id" % index)
		armor_characters[armor.character_id] = true
		var slots: Dictionary[StringName, bool] = {}
		for slot_index: int in range(armor.slots.size()):
			var slot: NativeArmorSlotRecord = armor.slots[slot_index]
			if slot == null or slot.armor_type.is_empty() or slot.item_instance_id.is_empty(): return _invalid("items.armor[%d].slots[%d]" % [index, slot_index], "empty armor identity")
			if slots.has(slot.armor_type): return _duplicate("items.armor[%d].slots[%d].armor_type" % [index, slot_index])
			slots[slot.armor_type] = true
	var spawn_ids: Dictionary[StringName, bool] = {}
	for index: int in range(snapshot.npc_spawn_states.size()):
		var npc: Values.NpcSpawnStateSnapshot = snapshot.npc_spawn_states[index]
		if npc == null or npc.spawn_id.is_empty():
			return _invalid("npc_spawn_states[%d].spawn_id" % index, "empty spawn ID")
		if spawn_ids.has(npc.spawn_id): return _duplicate("npc_spawn_states[%d].spawn_id" % index)
		spawn_ids[npc.spawn_id] = true
		if npc.spawn_point_id.is_empty() or npc.npc_definition_id.is_empty() or npc.character_id.is_empty(): return _invalid("npc_spawn_states[%d]" % index, "empty NPC stable identity")
		var loadout_ids: Dictionary[StringName, bool] = {}
		for loadout_index: int in range(npc.live_loadout_item_ids.size()):
			var loadout_id: StringName = npc.live_loadout_item_ids[loadout_index]
			if loadout_id.is_empty(): return _invalid("npc_spawn_states[%d].live_loadout_item_ids[%d]" % [index, loadout_index], "empty item ID")
			if loadout_ids.has(loadout_id): return _duplicate("npc_spawn_states[%d].live_loadout_item_ids[%d]" % [index, loadout_index])
			loadout_ids[loadout_id] = true
		var npc_result: GameSaveResult = _validate_runtime_character(npc.character, npc.life_status, npc.world_location, npc.map_position, "npc_spawn_states[%d]" % index)
		if not npc_result.succeeded(): return npc_result
	var corpse_ids: Dictionary[StringName, bool] = {}
	for index: int in range(snapshot.corpses.size()):
		var corpse: Values.CorpseSnapshot = snapshot.corpses[index]
		if corpse == null or corpse.corpse_item_instance_id.is_empty():
			return _invalid("corpses[%d].corpse_item_instance_id" % index, "empty corpse ID")
		if corpse_ids.has(corpse.corpse_item_instance_id): return _duplicate("corpses[%d].corpse_item_instance_id" % index)
		corpse_ids[corpse.corpse_item_instance_id] = true
		if corpse.victim_character_id.is_empty(): return _invalid("corpses[%d].victim_character_id" % index, "empty victim ID")
		var worn_slots: Dictionary[StringName, bool] = {}
		for worn_index: int in range(corpse.worn_items.size()):
			var worn: Values.CorpseWornItemSnapshot = corpse.worn_items[worn_index]
			if worn == null or worn.armor_type.is_empty() or worn.item_instance_id.is_empty(): return _invalid("corpses[%d].worn_items[%d]" % [index, worn_index], "empty worn identity")
			if worn_slots.has(worn.armor_type): return _duplicate("corpses[%d].worn_items[%d].armor_type" % [index, worn_index])
			worn_slots[worn.armor_type] = true
		var location_result: GameSaveResult = _validate_location(corpse.world_location, corpse.map_position, "corpses[%d]" % index)
		if not location_result.succeeded(): return location_result
	for pair: Array in [[snapshot.combat_rng, "rng.combat"], [snapshot.npc_initialization_rng, "rng.npc_initialization"], [snapshot.world_interaction_rng, "rng.world_interaction"]]:
		var random: RandomStreamSnapshot = pair[0]
		if random == null or not random.is_supported():
			return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_RANDOM_STREAM, pair[1], "unsupported adapter")
	return GameSaveResult.success(snapshot)


static func _validate_runtime_character(character: Values.CharacterStateSnapshot, life_status: StringName, location: Values.WorldLocationSnapshot, position: Values.MapPositionSnapshot, path: String) -> GameSaveResult:
	if character == null:
		return _invalid(path + ".character", "character snapshot is null")
	for pair: Array in [[character.gin, "gin"], [character.kee, "kee"], [character.sen, "sen"]]:
		var track: Values.ResourceTrackSnapshot = pair[0]
		if track == null or track.maximum < 0 or track.effective < -1 or track.current < -1 or track.current > track.effective or track.effective > track.maximum:
			return _invalid(path + ".character.resources." + pair[1], "invalid current/effective/maximum invariant")
	if life_status not in [&"active", &"unconscious", &"dead"]:
		return _invalid(path + ".life_status", "invalid life status")
	var skill_ids: Dictionary[StringName, bool] = {}
	for index: int in range(character.skills.raw_levels.size()):
		var raw: Values.SkillValueSnapshot = character.skills.raw_levels[index]
		if raw == null or raw.skill_id.is_empty(): return _invalid(path + ".character.skills.raw_levels[%d].skill_id" % index, "empty skill ID")
		if skill_ids.has(raw.skill_id): return _duplicate(path + ".character.skills.raw_levels[%d].skill_id" % index)
		skill_ids[raw.skill_id] = true
	var learned_ids: Dictionary[StringName, bool] = {}
	for index: int in range(character.skills.learned_progress.size()):
		var learned: Values.SkillValueSnapshot = character.skills.learned_progress[index]
		if learned == null or learned.skill_id.is_empty(): return _invalid(path + ".character.skills.learned_progress[%d].skill_id" % index, "empty skill ID")
		if learned_ids.has(learned.skill_id): return _duplicate(path + ".character.skills.learned_progress[%d].skill_id" % index)
		learned_ids[learned.skill_id] = true
	var mapping_ids: Dictionary[StringName, bool] = {}
	for index: int in range(character.skills.mappings.size()):
		var mapping: Values.SkillMappingSnapshot = character.skills.mappings[index]
		if mapping == null or mapping.use_id.is_empty() or mapping.skill_id.is_empty(): return _invalid(path + ".character.skills.mappings[%d]" % index, "empty mapping ID")
		if mapping_ids.has(mapping.use_id): return _duplicate(path + ".character.skills.mappings[%d].use_id" % index)
		if not skill_ids.has(mapping.skill_id): return _invalid(path + ".character.skills.mappings[%d].skill_id" % index, "mapping target has no raw record")
		mapping_ids[mapping.use_id] = true
	if not character.skills.has_skills_mapping and (not character.skills.raw_levels.is_empty() or not character.skills.mappings.is_empty()):
		return _invalid(path + ".character.skills.has_skills_mapping", "mapping-presence contradiction")
	if not character.skills.has_learned_mapping and not character.skills.learned_progress.is_empty():
		return _invalid(path + ".character.skills.has_learned_mapping", "mapping-presence contradiction")
	var condition_ids: Dictionary[StringName, bool] = {}
	for index: int in range(character.conditions.size()):
		var condition: Values.ConditionSnapshot = character.conditions[index]
		if condition == null or condition.condition_id.is_empty(): return _invalid(path + ".character.conditions[%d].condition_id" % index, "empty condition ID")
		if condition_ids.has(condition.condition_id): return _duplicate(path + ".character.conditions[%d].condition_id" % index)
		if condition.payload_kind not in [Values.ConditionSnapshot.KIND_DURATION, Values.ConditionSnapshot.KIND_POISON]: return _invalid(path + ".character.conditions[%d].payload_kind" % index, "unsupported payload kind")
		condition_ids[condition.condition_id] = true
	return _validate_location(location, position, path)


static func _validate_location(location: Values.WorldLocationSnapshot, position: Values.MapPositionSnapshot, path: String) -> GameSaveResult:
	if location == null or location.region_id.is_empty() or location.map_id.is_empty() or location.zone_id.is_empty() or location.combat_location_id.is_empty():
		return _invalid(path + ".world_location", "location IDs must be nonempty")
	if position == null or not is_finite(position.x) or not is_finite(position.y):
		return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_FINITE_NUMBER, path + ".map_position")
	return GameSaveResult.success()


static func _invalid(path: String, detail: String) -> GameSaveResult:
	return GameSaveResult.failure(GameSaveResult.Outcome.INVALID_SNAPSHOT, path, detail)


static func _duplicate(path: String) -> GameSaveResult:
	return GameSaveResult.failure(GameSaveResult.Outcome.DUPLICATE_ID, path)
