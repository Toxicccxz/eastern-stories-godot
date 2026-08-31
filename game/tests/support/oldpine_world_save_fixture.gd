class_name OldPineWorldSaveFixture
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")


static func from_new_game(
	session: OldPineWorldSessionController,
	player_location_override: Values.WorldLocationSnapshot = null,
	player_position_override: Values.MapPositionSnapshot = null,
) -> GameSaveSnapshot:
	if session == null or session.outdoor_map() == null:
		return null
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var equipment_sources: Array[NativeCharacterEquipmentSource] = [
		NativeCharacterEquipmentSource.new(player.character_id, player.state.equipment),
	]
	var armor_sources: Array[NativeCharacterArmorSource] = [
		NativeCharacterArmorSource.new(player.character_id, player.armor),
	]
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		equipment_sources.append(
			NativeCharacterEquipmentSource.new(npc.character_id, npc.character_state.equipment)
		)
		armor_sources.append(
			NativeCharacterArmorSource.new(npc.character_id, npc.armor)
		)
	var item_capture: NativeItemSnapshotCaptureResult = (
		NativeItemPersistenceComposition.capture(
			session.inventory_state(),
			session.stack_collection(),
			session.item_instance_index(),
			equipment_sources,
			armor_sources,
			OldPineNativeItemDefinitionProjections.create(),
		)
	)
	if not item_capture.succeeded:
		return null
	var player_location: Values.WorldLocationSnapshot = (
		_location_snapshot(player.world_location())
		if player_location_override == null
		else player_location_override
	)
	var player_position: Values.MapPositionSnapshot = (
		Values.MapPositionSnapshot.new(
			outdoor.player_body.global_position.x,
			outdoor.player_body.global_position.y,
		)
		if player_position_override == null
		else player_position_override
	)
	var player_snapshot: Values.PlayerRuntimeSnapshot = Values.PlayerRuntimeSnapshot.new(
		player.character_id,
		_character_snapshot(player.state),
		_life_text(player.life_status),
		player.exists_in_world,
		player.combat_available,
		player.maximum_encumbrance,
		player_location,
		player_position,
	)
	var npc_snapshots: Array[Values.NpcSpawnStateSnapshot] = []
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		var body: WorldCharacterBody2D = _body_for(outdoor, npc.character_id)
		var loadout_ids: Array[StringName] = []
		for item: ItemInstance in npc.loadout_items():
			loadout_ids.append(item.item_instance_id)
		npc_snapshots.append(Values.NpcSpawnStateSnapshot.new(
			npc.spawn_id,
			npc.spawn_point_id,
			npc.definition_id,
			npc.character_id,
			npc.exists_in_map,
			_life_text(npc.life_status),
			npc.combat_available,
			_character_snapshot(npc.character_state),
			npc.age,
			npc.body_weight,
			npc.maximum_encumbrance,
			_location_snapshot(npc.world_location()),
			Values.MapPositionSnapshot.new(body.global_position.x, body.global_position.y),
			loadout_ids,
		))
	return GameSaveSnapshot.new(
		Values.GameSaveMetadata.new(
			GameSaveSnapshot.FORMAT_ID,
			GameSaveSnapshot.CURRENT_SCHEMA_VERSION,
			"2026-08-31T12:34:56Z",
			Values.OptionalText.none(),
			&"test",
			GameSaveSnapshot.FIXED_SLOT_ID,
		),
		GameSaveSnapshot.SESSION_KIND_OLDPINE,
		session.item_id_allocator().snapshot(),
		player_snapshot,
		npc_snapshots,
		[],
		item_capture.snapshot,
		session.combat_random_source().capture_random_state(),
		session.npc_random_source().capture_random_state(),
		session.world_interaction_random_source().capture_random_state(),
	)


static func with_fat_bandit_corpse(
	base: GameSaveSnapshot,
) -> GameSaveSnapshot:
	var fat: Values.NpcSpawnStateSnapshot
	var npcs: Array[Values.NpcSpawnStateSnapshot] = []
	for npc: Values.NpcSpawnStateSnapshot in base.npc_spawn_states:
		if npc.npc_definition_id == OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID:
			fat = Values.NpcSpawnStateSnapshot.new(
				npc.spawn_id, npc.spawn_point_id, npc.npc_definition_id,
				npc.character_id, false, &"dead", false, npc.character,
				npc.age, npc.body_weight, npc.maximum_encumbrance,
				npc.world_location, npc.map_position, npc.live_loadout_item_ids,
			)
			npcs.append(fat)
		else:
			npcs.append(npc)
	var corpse_id: StringName = StringName(
		"%s.dynamic.0" % String(base.item_id_allocator.scope)
	)
	var fat_short_sword: StringName
	var fat_leather: StringName
	var fat_silver: StringName
	for item_id: StringName in fat.live_loadout_item_ids:
		var definition_id: StringName = _definition_id(base.items, item_id)
		match definition_id:
			OldPineNpcDefinitions.SHORT_SWORD_ITEM_ID:
				fat_short_sword = item_id
			OldPineNpcDefinitions.LEATHER_ITEM_ID:
				fat_leather = item_id
			OldPineNpcDefinitions.SILVER_ITEM_ID:
				fat_silver = item_id
	var records: Array[NativeItemRecord] = []
	for record: NativeItemRecord in base.items.item_records:
		var parent: ContainmentEndpoint = record.direct_parent
		if record.item_instance_id in [fat_short_sword, fat_leather]:
			parent = ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_id)
		elif record.item_instance_id == fat_silver:
			parent = ContainmentEndpoint.new(
				ContainmentEndpoint.Kind.ITEM,
				fat_short_sword,
			)
		records.append(NativeItemRecord.new(
			record.item_instance_id,
			record.item_definition_id,
			record.own_weight,
			parent,
		))
	records.append(NativeItemRecord.new(
		corpse_id,
		&"es2:obj/corpse",
		fat.body_weight,
		ContainmentEndpoint.new(
			ContainmentEndpoint.Kind.WORLD,
			fat.world_location.combat_location_id,
		),
	))
	var equipment: Array[NativeCharacterEquipmentRecord] = []
	for record: NativeCharacterEquipmentRecord in base.items.character_equipment_records:
		equipment.append(
			NativeCharacterEquipmentRecord.new(record.character_id)
			if record.character_id == fat.character_id
			else record
		)
	var armor: Array[NativeCharacterArmorRecord] = []
	for record: NativeCharacterArmorRecord in base.items.character_armor_records:
		armor.append(
			NativeCharacterArmorRecord.new(record.character_id)
			if record.character_id == fat.character_id
			else record
		)
	var item_snapshot: NativeItemStateSnapshot = NativeItemStateSnapshot.new(
		base.items.schema_version,
		records,
		base.items.combined_stack_records,
		equipment,
		armor,
	)
	var corpse: Values.CorpseSnapshot = Values.CorpseSnapshot.new(
		corpse_id,
		fat.character_id,
		OldPineNpcDefinitions.fat_bandit_definition().display_name,
		fat.character.gender,
		fat.age,
		CorpseState.Stage.FRESH,
		fat.maximum_encumbrance,
		[Values.CorpseWornItemSnapshot.new(&"cloth", fat_leather)],
		fat.world_location,
		fat.map_position,
	)
	return GameSaveSnapshot.new(
		base.metadata,
		base.session_kind,
		Values.ItemIdAllocatorSnapshot.new(base.item_id_allocator.scope, 1),
		base.player,
		npcs,
		[corpse],
		item_snapshot,
		base.combat_rng,
		base.npc_initialization_rng,
		base.world_interaction_rng,
	)


static func _character_snapshot(state: CharacterState) -> Values.CharacterStateSnapshot:
	var raw: Array[Values.SkillValueSnapshot] = [
		Values.SkillValueSnapshot.new(&"force", state.skills.raw_level(&"force")),
		Values.SkillValueSnapshot.new(&"unarmed", state.skills.raw_level(&"unarmed")),
	]
	return Values.CharacterStateSnapshot.new(
		state.gender,
		Values.BaseAttributesSnapshot.new(
			state.attributes.strength,
			state.attributes.courage,
			state.attributes.intelligence,
			state.attributes.spirituality,
			state.attributes.composure,
			state.attributes.personality,
			state.attributes.constitution,
			state.attributes.karma,
			state.attributes.force_factor,
			state.attributes.bellicosity,
		),
		_track(state.essence),
		_track(state.vitality),
		_track(state.spirit),
		Values.InternalResourcesSnapshot.new(
			state.recovery.inner_force.current,
			state.recovery.inner_force.maximum,
			state.recovery.mana.current,
			state.recovery.mana.maximum,
			state.recovery.atman.current,
			state.recovery.atman.maximum,
			state.recovery.food,
			state.recovery.water,
		),
		Values.ProgressionSnapshot.new(
			state.progression.combat_experience,
			state.progression.potential,
			state.progression.potential_spent,
		),
		Values.SkillStateSnapshot.new(true, true, raw, [
			Values.SkillValueSnapshot.new(&"force", 7),
		], [
			Values.SkillMappingSnapshot.new(&"force", &"force"),
		]),
		[],
		Values.FamilySnapshot.new(state.family.family_id, state.family.generation),
		Values.ApprenticeshipSnapshot.new(
			state.apprenticeship.master_teacher_id,
			state.apprenticeship.legacy_master_name,
			state.apprenticeship.betrayer_count,
		),
	)


static func _track(value: CharacterResourceState) -> Values.ResourceTrackSnapshot:
	return Values.ResourceTrackSnapshot.new(value.current, value.effective, value.maximum)


static func _location_snapshot(value: WorldLocationState) -> Values.WorldLocationSnapshot:
	return Values.WorldLocationSnapshot.new(
		value.region_id, value.map_id, value.zone_id, value.combat_location_id,
	)


static func _life_text(value: int) -> StringName:
	match value:
		CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			return &"unconscious"
		CharacterRuntimeLifeStatus.Value.DEAD:
			return &"dead"
	return &"active"


static func _body_for(
	outdoor: OldPineOutdoorController,
	character_id: StringName,
) -> WorldCharacterBody2D:
	for node: Node in outdoor.get_node("Characters").get_children():
		var body: WorldCharacterBody2D = node as WorldCharacterBody2D
		if body != null and body.character_id == character_id:
			return body
	return null


static func _definition_id(
	items: NativeItemStateSnapshot,
	item_id: StringName,
) -> StringName:
	for record: NativeItemRecord in items.item_records:
		if record.item_instance_id == item_id:
			return record.item_definition_id
	return &""
