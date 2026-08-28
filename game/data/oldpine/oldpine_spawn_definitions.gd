class_name OldPineSpawnDefinitions
extends RefCounted

const SPATH1_BANDIT_SPAWN_ID: StringName = &"oldpine.outdoor.spath1.bandits"


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


static func spawn_by_id(spawn_id: StringName) -> NpcSpawnDefinition:
	return spath1_bandit_spawn() if spawn_id == SPATH1_BANDIT_SPAWN_ID else null


static func validate() -> bool:
	if not OldPineWorldDefinitions.validate() or not OldPineNpcDefinitions.validate():
		return false
	var spawn: NpcSpawnDefinition = spath1_bandit_spawn()
	if not spawn.is_valid():
		return false
	var map: MapDefinition = OldPineWorldDefinitions.map_by_id(spawn.map_id)
	var zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(spawn.zone_id)
	var npc: NpcDefinition = OldPineNpcDefinitions.npc_by_id(
		spawn.npc_definition_id
	)
	if not (
		map != null
		and map.spawn_ids().has(spawn.spawn_id)
		and zone != null
		and zone.map_id == spawn.map_id
		and npc != null
		and npc.is_valid()
	):
		return false

	var spawn_membership_count: int = 0
	for candidate_map: MapDefinition in OldPineWorldDefinitions.map_definitions():
		for spawn_id: StringName in candidate_map.spawn_ids():
			var candidate: NpcSpawnDefinition = spawn_by_id(spawn_id)
			if candidate == null or candidate.map_id != candidate_map.map_id:
				return false
			if spawn_id == spawn.spawn_id:
				spawn_membership_count += 1
	if spawn_membership_count != 1:
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
	if not _register_unique_id(native_ids, npc.definition_id):
		return false
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
