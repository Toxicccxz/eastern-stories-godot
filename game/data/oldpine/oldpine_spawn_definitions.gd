class_name OldPineSpawnDefinitions
extends RefCounted

const SPATH1_BANDIT_SPAWN_ID: StringName = &"oldpine.outdoor.spath1.bandits"
const PINE1_TALL_BANDIT_SPAWN_ID: StringName = (
	&"oldpine.outdoor.pine1.tall_bandit"
)
const PINE1_FAT_BANDIT_SPAWN_ID: StringName = (
	&"oldpine.outdoor.pine1.fat_bandit"
)


static func spath1_bandit_spawn() -> NpcSpawnDefinition:
	return NpcSpawnDefinition.new(
		SPATH1_BANDIT_SPAWN_ID,
		OldPineNpcDefinitions.BANDIT_DEFINITION_ID,
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.SOUTH_SLOPE_ZONE_ID,
		[
			&"oldpine.outdoor.south_slope.spath1.bandit.1",
			&"oldpine.outdoor.south_slope.spath1.bandit.2",
			&"oldpine.outdoor.south_slope.spath1.bandit.3",
		],
		3,
		"d/oldpine/spath1.c",
		3,
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
	)


static func pine1_tall_bandit_spawn() -> NpcSpawnDefinition:
	return NpcSpawnDefinition.new(
		PINE1_TALL_BANDIT_SPAWN_ID,
		OldPineNpcDefinitions.TALL_BANDIT_DEFINITION_ID,
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
		[&"oldpine.outdoor.pine_entrance.pine1.tall_bandit.1"],
		1,
		"d/oldpine/pine1.c",
		1,
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
	)


static func pine1_fat_bandit_spawn() -> NpcSpawnDefinition:
	return NpcSpawnDefinition.new(
		PINE1_FAT_BANDIT_SPAWN_ID,
		OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID,
		OldPineWorldDefinitions.OUTDOOR_MAP_ID,
		OldPineWorldDefinitions.PINE_ENTRANCE_ZONE_ID,
		[&"oldpine.outdoor.pine_entrance.pine1.fat_bandit.1"],
		1,
		"d/oldpine/pine1.c",
		1,
		NpcSpawnDefinition.InitialSpawnPolicy.INITIAL_ONLY,
	)


static func spawn_by_id(spawn_id: StringName) -> NpcSpawnDefinition:
	match spawn_id:
		SPATH1_BANDIT_SPAWN_ID:
			return spath1_bandit_spawn()
		PINE1_TALL_BANDIT_SPAWN_ID:
			return pine1_tall_bandit_spawn()
		PINE1_FAT_BANDIT_SPAWN_ID:
			return pine1_fat_bandit_spawn()
	return null


static func all_spawns() -> Array[NpcSpawnDefinition]:
	return [
		spath1_bandit_spawn(),
		pine1_tall_bandit_spawn(),
		pine1_fat_bandit_spawn(),
	]


static func validate() -> bool:
	if not OldPineWorldDefinitions.validate() or not OldPineNpcDefinitions.validate():
		return false
	var spawns: Array[NpcSpawnDefinition] = all_spawns()
	for spawn: NpcSpawnDefinition in spawns:
		var map: MapDefinition = OldPineWorldDefinitions.map_by_id(spawn.map_id)
		var zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(spawn.zone_id)
		var npc: NpcDefinition = OldPineNpcDefinitions.npc_by_id(
			spawn.npc_definition_id
		)
		if not (
			spawn.is_valid()
			and map != null
			and map.spawn_ids().has(spawn.spawn_id)
			and zone != null
			and zone.map_id == spawn.map_id
			and npc != null
			and npc.is_valid()
		):
			return false

	var spawn_membership_count: Dictionary[StringName, int] = {}
	for candidate_map: MapDefinition in OldPineWorldDefinitions.map_definitions():
		for spawn_id: StringName in candidate_map.spawn_ids():
			var candidate: NpcSpawnDefinition = spawn_by_id(spawn_id)
			if candidate == null or candidate.map_id != candidate_map.map_id:
				return false
			spawn_membership_count[spawn_id] = (
				spawn_membership_count.get(spawn_id, 0) + 1
			)
	for spawn: NpcSpawnDefinition in spawns:
		if spawn_membership_count.get(spawn.spawn_id, 0) != 1:
			return false

	var native_ids: Dictionary[StringName, bool] = {}
	if not _register_unique_id(native_ids, OldPineWorldDefinitions.region_definition().region_id):
		return false
	for candidate_map: MapDefinition in OldPineWorldDefinitions.map_definitions():
		if not _register_unique_id(native_ids, candidate_map.map_id):
			return false
	for candidate_zone: ZoneDefinition in OldPineWorldDefinitions.zone_definitions():
		if not _register_unique_id(native_ids, candidate_zone.zone_id):
			return false
	for portal: PortalDefinition in OldPineWorldDefinitions.portal_definitions():
		if not _register_unique_id(native_ids, portal.portal_id):
			return false
	for definition_id: StringName in [
		OldPineNpcDefinitions.BANDIT_DEFINITION_ID,
		OldPineNpcDefinitions.TALL_BANDIT_DEFINITION_ID,
		OldPineNpcDefinitions.FAT_BANDIT_DEFINITION_ID,
	]:
		if not _register_unique_id(native_ids, definition_id):
			return false
	for spawn: NpcSpawnDefinition in spawns:
		if not _register_unique_id(native_ids, spawn.spawn_id):
			return false
	for content: NpcLoadoutItemDefinition in OldPineNpcDefinitions.loadout_item_definitions():
		if not _register_unique_id(
			native_ids,
			content.item_definition().item_definition_id,
		):
			return false
	return true


static func _register_unique_id(
	seen: Dictionary[StringName, bool],
	id: StringName,
) -> bool:
	if id.is_empty() or seen.has(id):
		return false
	seen[id] = true
	return true
