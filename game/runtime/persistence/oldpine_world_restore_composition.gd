class_name OldPineWorldRestoreComposition
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const Result := preload(
	"res://runtime/persistence/oldpine_world_restore_result.gd"
)
const CORPSE_DEFINITION_ID: StringName = &"es2:obj/corpse"


static func prepare(snapshot: GameSaveSnapshot) -> OldPineWorldRestoreResult:
	var root_validation: GameSaveResult = GameSaveSnapshotValidator.validate(snapshot)
	if not root_validation.succeeded():
		return Result.failure(
			Result.Outcome.INVALID_SNAPSHOT,
			root_validation.path,
			root_validation.detail,
		)
	if snapshot.player.character_id != OldPineWorldSessionController.PLAYER_ID:
		return Result.failure(
			Result.Outcome.UNKNOWN_CONTENT_ID,
			"player.character_id",
		)
	if not _location_is_current(snapshot.player.world_location):
		return Result.failure(
			Result.Outcome.INVALID_WORLD_LOCATION,
			"player.world_location",
		)

	var item_restore: NativeItemRestoreCompositionResult = (
		NativeItemPersistenceComposition.restore(
			snapshot.items,
			OldPineNativeItemDefinitionProjections.create(),
			snapshot.item_id_allocator,
		)
	)
	if not item_restore.succeeded:
		return Result.failure(
			Result.Outcome.ITEM_RESTORE_FAILED,
			"items",
			"item or allocator reconstruction rejected",
		)
	var domain: NativeItemDomainState = item_restore.domain_state
	var character_ids: Array[StringName] = [snapshot.player.character_id]
	for spawn: NpcSpawnDefinition in OldPineSpawnDefinitions.all_spawns():
		for point_id: StringName in spawn.spawn_point_ids():
			character_ids.append(_character_id_for_spawn_point(point_id))
	if not _character_aggregate_ids_match(domain, character_ids):
		return Result.failure(
			Result.Outcome.ITEM_RESTORE_FAILED,
			"items.character_equipment",
			"Equipment/Armor character records do not match the current ledger",
		)

	var player_equipment: EquipmentState = domain.equipment_state(
		snapshot.player.character_id
	)
	var player_armor: ArmorState = domain.armor_state(snapshot.player.character_id)
	var player_state: CharacterState = CharacterStateSnapshotRestorer.restore(
		snapshot.player.character,
		player_equipment,
	)
	if player_state == null or player_armor == null:
		return Result.failure(
			Result.Outcome.CHARACTER_RESTORE_FAILED,
			"player.character",
		)
	if snapshot.player.maximum_encumbrance != (
		CharacterDerivedValues.maximum_encumbrance(
			player_state.attributes.strength
		)
	):
		return Result.failure(
			Result.Outcome.CHARACTER_RESTORE_FAILED,
			"player.maximum_encumbrance",
		)
	var player_life: int = _life_status(snapshot.player.life_status)
	if player_life < 0:
		return Result.failure(
			Result.Outcome.CHARACTER_RESTORE_FAILED,
			"player.life_status",
		)
	var player: WorldPlayerRuntimeState = WorldPlayerRuntimeState.new(
		snapshot.player.character_id,
		player_state,
		CombatRelationshipState.new(snapshot.player.character_id),
		ActionBusyState.new(),
		player_armor,
		_location(snapshot.player.world_location),
		player_life,
		snapshot.player.exists_in_world,
		snapshot.player.combat_available,
		snapshot.player.maximum_encumbrance,
	)
	if not player.is_valid():
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"player",
		)

	var npc_result: OldPineWorldRestoreResult = _restore_npc_ledger(
		snapshot,
		domain,
		item_restore.item_index,
	)
	if npc_result.outcome != Result.Outcome.SUCCESS:
		return npc_result
	var npc_entries: Array[OldPineRestoredNpcEntry] = []
	npc_entries.assign(npc_result.preparation.npc_entries())

	var corpse_result: OldPineWorldRestoreResult = _restore_corpses(
		snapshot,
		domain,
	)
	if corpse_result.outcome != Result.Outcome.SUCCESS:
		return corpse_result
	var corpse_entries: Array[OldPineRestoredCorpseEntry] = []
	corpse_entries.assign(corpse_result.preparation.corpse_entries())

	var npc_random: GodotNpcInitializationRandomSource = (
		GodotNpcInitializationRandomSource.new(0, true)
	)
	var combat_random: GodotCombatRandomSource = GodotCombatRandomSource.new(0, true)
	var world_random: GodotWorldInteractionRandomSource = (
		GodotWorldInteractionRandomSource.new(0, true)
	)
	if (
		not npc_random.restore_random_state(snapshot.npc_initialization_rng)
		or not combat_random.restore_random_state(snapshot.combat_rng)
		or not world_random.restore_random_state(snapshot.world_interaction_rng)
	):
		return Result.failure(
			Result.Outcome.INVALID_RANDOM_STREAM,
			"rng",
		)
	var preparation: OldPineWorldRestorePreparation = (
		OldPineWorldRestorePreparation.new(
			player,
			Vector2(snapshot.player.map_position.x, snapshot.player.map_position.y),
			domain,
			item_restore.item_index,
			item_restore.allocator,
			npc_random,
			combat_random,
			world_random,
			npc_entries,
			corpse_entries,
		)
	)
	if not preparation.is_valid():
		return Result.failure(
			Result.Outcome.RECONSTRUCTION_FAILED,
			"preparation",
		)
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		null,
		preparation,
	)


static func _restore_npc_ledger(
	snapshot: GameSaveSnapshot,
	domain: NativeItemDomainState,
	item_index: WorldItemInstanceIndex,
) -> OldPineWorldRestoreResult:
	var saved_by_point: Dictionary[StringName, Values.NpcSpawnStateSnapshot] = {}
	for saved: Values.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		if saved_by_point.has(saved.spawn_point_id):
			return Result.failure(
				Result.Outcome.INCONSISTENT_SPAWN_STATE,
				"npc_spawn_states",
				"duplicate authored spawn point",
			)
		saved_by_point[saved.spawn_point_id] = saved
	var entries: Array[OldPineRestoredNpcEntry] = []
	var referenced_loadout_ids: Dictionary[StringName, bool] = {}
	for spawn: NpcSpawnDefinition in OldPineSpawnDefinitions.all_spawns():
		var definition: NpcDefinition = OldPineNpcDefinitions.npc_by_id(
			spawn.npc_definition_id
		)
		if definition == null:
			return Result.failure(
				Result.Outcome.UNKNOWN_CONTENT_ID,
				"npc_spawn_states.npc_definition_id",
			)
		for point_id: StringName in spawn.spawn_point_ids():
			if not saved_by_point.has(point_id):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					"npc_spawn_states",
					"missing authored spawn slot",
				)
			var saved: Values.NpcSpawnStateSnapshot = saved_by_point[point_id]
			var path: String = "npc_spawn_states.%s" % String(point_id)
			if (
				saved.spawn_id != spawn.spawn_id
				or saved.npc_definition_id != spawn.npc_definition_id
				or saved.character_id != _character_id_for_spawn_point(point_id)
				or not _location_is_current(saved.world_location)
				or saved.world_location.map_id != spawn.map_id
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path,
				)
			if definition.has_authored_age and saved.age != definition.age:
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path + ".age",
				)
			var expected_weight: int = CharacterDerivedValues.human_weight(
				saved.character.attributes.strength
			)
			var expected_capacity: int = CharacterDerivedValues.maximum_encumbrance(
				saved.character.attributes.strength
			)
			if (
				saved.body_weight != expected_weight
				or saved.maximum_encumbrance != expected_capacity
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path + ".derived_character_facts",
				)
			if not _loadout_matches(
				saved,
				definition,
				item_index,
				referenced_loadout_ids,
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_SPAWN_STATE,
					path + ".live_loadout_item_ids",
				)
			var equipment: EquipmentState = domain.equipment_state(saved.character_id)
			var armor: ArmorState = domain.armor_state(saved.character_id)
			var state: CharacterState = CharacterStateSnapshotRestorer.restore(
				saved.character,
				equipment,
			)
			var life: int = _life_status(saved.life_status)
			if state == null or armor == null or life < 0:
				return Result.failure(
					Result.Outcome.CHARACTER_RESTORE_FAILED,
					path + ".character",
				)
			var loadout: Array[ItemInstance] = []
			for item_id: StringName in saved.live_loadout_item_ids:
				loadout.append(item_index.resolve(item_id))
			var runtime: NpcRuntimeState = NpcRuntimeState.new(
				saved.character_id,
				definition,
				saved.spawn_id,
				saved.spawn_point_id,
				state,
				CombatRelationshipState.new(saved.character_id),
				ActionBusyState.new(),
				armor,
				_location(saved.world_location),
				life,
				saved.combat_available,
				saved.exists_in_world,
				saved.age,
				saved.body_weight,
				saved.maximum_encumbrance,
				loadout,
			)
			if not runtime.is_valid():
				return Result.failure(
					Result.Outcome.RECONSTRUCTION_FAILED,
					path,
				)
			entries.append(OldPineRestoredNpcEntry.new(
				runtime,
				Vector2(saved.map_position.x, saved.map_position.y),
			))
	if saved_by_point.size() != entries.size():
		return Result.failure(
			Result.Outcome.INCONSISTENT_SPAWN_STATE,
			"npc_spawn_states",
			"unknown authored spawn slot",
		)
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		null,
		OldPineWorldRestorePreparation.new(
			null, Vector2.ZERO, null, null, null, null, null, null, entries,
		),
	)


static func _restore_corpses(
	snapshot: GameSaveSnapshot,
	domain: NativeItemDomainState,
) -> OldPineWorldRestoreResult:
	var item_records: Dictionary[StringName, NativeItemRecord] = {}
	for item: NativeItemRecord in snapshot.items.item_records:
		item_records[item.item_instance_id] = item
	var character_facts: Dictionary[StringName, Variant] = {
		snapshot.player.character_id: snapshot.player,
	}
	for npc: Values.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		character_facts[npc.character_id] = npc
	var entries: Array[OldPineRestoredCorpseEntry] = []
	for saved: Values.CorpseSnapshot in snapshot.corpses:
		var path: String = "corpses.%s" % String(saved.corpse_item_instance_id)
		if (
			not item_records.has(saved.corpse_item_instance_id)
			or not character_facts.has(saved.victim_character_id)
			or not _location_is_current(saved.world_location)
			or saved.world_location.map_id != OldPineWorldDefinitions.OUTDOOR_MAP_ID
			or saved.decay_stage < CorpseState.Stage.FRESH
			or saved.decay_stage > CorpseState.Stage.FINAL
		):
			return Result.failure(
				Result.Outcome.INCONSISTENT_CORPSE_STATE,
				path,
			)
		var record: NativeItemRecord = item_records[saved.corpse_item_instance_id]
		var parent: ContainmentEndpoint = record.direct_parent
		if (
			record.item_definition_id != CORPSE_DEFINITION_ID
			or parent == null
			or parent.kind != ContainmentEndpoint.Kind.WORLD
			or parent.endpoint_id != saved.world_location.combat_location_id
		):
			return Result.failure(
				Result.Outcome.INCONSISTENT_CORPSE_STATE,
				path + ".item_cross_reference",
			)
		var victim: Variant = character_facts[saved.victim_character_id]
		var victim_character: Values.CharacterStateSnapshot = victim.character
		var victim_life: StringName = victim.life_status
		var victim_exists: bool = victim.exists_in_world
		var expected_name: String = "Player"
		var expected_age: int = saved.victim_age
		var expected_weight: int = CharacterDerivedValues.human_weight(
			victim_character.attributes.strength
		)
		if victim is Values.NpcSpawnStateSnapshot:
			var victim_npc: Values.NpcSpawnStateSnapshot = victim
			var definition: NpcDefinition = OldPineNpcDefinitions.npc_by_id(
				victim_npc.npc_definition_id
			)
			if definition == null:
				return Result.failure(Result.Outcome.UNKNOWN_CONTENT_ID, path)
			expected_name = definition.display_name
			expected_age = victim_npc.age
			expected_weight = victim_npc.body_weight
		if (
			victim_life != &"dead"
			or victim_exists
			or saved.victim_display_name != expected_name
			or saved.victim_gender != victim_character.gender
			or saved.victim_age != expected_age
			or saved.maximum_contents_encumbrance
			!= CharacterDerivedValues.maximum_encumbrance(
				victim_character.attributes.strength
			)
			or record.own_weight != expected_weight
		):
			return Result.failure(
				Result.Outcome.INCONSISTENT_CORPSE_STATE,
				path + ".victim_facts",
			)
		var corpse: CorpseState = CorpseState.new(
			saved.corpse_item_instance_id,
			saved.victim_character_id,
			saved.victim_display_name,
			saved.victim_gender,
			saved.victim_age,
			saved.maximum_contents_encumbrance,
		)
		for worn: Values.CorpseWornItemSnapshot in saved.worn_items:
			if not item_records.has(worn.item_instance_id):
				return Result.failure(
					Result.Outcome.INCONSISTENT_CORPSE_STATE,
					path + ".worn_items",
				)
			var worn_record: NativeItemRecord = item_records[worn.item_instance_id]
			var worn_parent: ContainmentEndpoint = worn_record.direct_parent
			var armor_definition: ArmorDefinition = (
				OldPineNativeItemDefinitionProjections.create().armor_definition(
					worn_record.item_definition_id
				)
			)
			if (
				worn_parent == null
				or worn_parent.kind != ContainmentEndpoint.Kind.ITEM
				or worn_parent.endpoint_id != saved.corpse_item_instance_id
				or armor_definition == null
				or armor_definition.armor_type != worn.armor_type
				or not corpse._try_wear(
					worn.armor_type,
					worn.item_instance_id,
					domain.inventory,
				)
			):
				return Result.failure(
					Result.Outcome.INCONSISTENT_CORPSE_STATE,
					path + ".worn_items",
				)
		for stage: int in range(CorpseState.Stage.ROTTEN, saved.decay_stage + 1):
			if not corpse._apply_next_decay_stage(stage):
				return Result.failure(
					Result.Outcome.RECONSTRUCTION_FAILED,
					path + ".decay_stage",
				)
		entries.append(OldPineRestoredCorpseEntry.new(
			corpse,
			_location(saved.world_location),
			Vector2(saved.map_position.x, saved.map_position.y),
		))
	return OldPineWorldRestoreResult.new(
		Result.Outcome.SUCCESS,
		"",
		"",
		null,
		OldPineWorldRestorePreparation.new(
			null, Vector2.ZERO, null, null, null, null, null, null, [], entries,
		),
	)


static func _loadout_matches(
	saved: Values.NpcSpawnStateSnapshot,
	definition: NpcDefinition,
	item_index: WorldItemInstanceIndex,
	global_ids: Dictionary[StringName, bool],
) -> bool:
	var expected_definitions: Array[StringName] = []
	for entry: NpcLoadoutEntry in definition.loadout_entries():
		var content: NpcLoadoutItemDefinition = (
			OldPineNpcDefinitions.loadout_content_by_id(entry.item_definition_id)
		)
		if content == null:
			return false
		var instance_count: int = 1 if content.stack_definition() != null else entry.quantity
		for _index: int in range(instance_count):
			expected_definitions.append(entry.item_definition_id)
	var actual_definitions: Array[StringName] = []
	for item_id: StringName in saved.live_loadout_item_ids:
		if global_ids.has(item_id):
			return false
		var item: ItemInstance = item_index.resolve(item_id)
		if item == null:
			return false
		global_ids[item_id] = true
		actual_definitions.append(item.item_definition_id)
	expected_definitions.sort_custom(_string_name_less_than)
	actual_definitions.sort_custom(_string_name_less_than)
	return expected_definitions == actual_definitions


static func _character_aggregate_ids_match(
	domain: NativeItemDomainState,
	expected_ids: Array[StringName],
) -> bool:
	var expected: Array[StringName] = expected_ids.duplicate()
	expected.sort_custom(_string_name_less_than)
	return (
		domain.equipment_character_ids() == expected
		and domain.armor_character_ids() == expected
	)


static func _location_is_current(value: Values.WorldLocationSnapshot) -> bool:
	if value == null or value.region_id != OldPineWorldDefinitions.REGION_ID:
		return false
	if value.map_id not in [
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.CAVE_MAP_ID,
	]:
		return false
	var zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(value.zone_id)
	return (
		zone != null
		and zone.map_id == value.map_id
		and zone.combat_location_id == value.combat_location_id
		and (
			value.map_id != OldPineWorldDefinitions.CAVE_MAP_ID
			or value.zone_id
			== OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID
		)
	)


static func _location(value: Values.WorldLocationSnapshot) -> WorldLocationState:
	return WorldLocationState.new(
		value.region_id,
		value.map_id,
		value.zone_id,
		value.combat_location_id,
	)


static func _life_status(value: StringName) -> int:
	match value:
		&"active":
			return CharacterRuntimeLifeStatus.Value.ACTIVE
		&"unconscious":
			return CharacterRuntimeLifeStatus.Value.UNCONSCIOUS
		&"dead":
			return CharacterRuntimeLifeStatus.Value.DEAD
	return -1


static func _character_id_for_spawn_point(point_id: StringName) -> StringName:
	return StringName("%s.character" % String(point_id))


static func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
