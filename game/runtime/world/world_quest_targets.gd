class_name WorldQuestTargets
extends RefCounted

## Native (主线卡死点; owner 2026-11-10; DECISIONS「主线卡死点」): which of 朱鸿雪's kill targets
## (god.c's qlist, by name: killer_reward() compares victim->name(1)) can be killed in the world
## now — judged when she draws, not only once from the definitions (ContentCatalog
## quest_target_available()). One of that name counts while it is placed (a spawn), can be
## fought, is not one a story step still keeps (StoryKeeps), is on the story's stage now
## (WorldStoryPresence.on_stage(): 芙云 and 梦玉楼 gone with the fourth chapter's choice, the 武官
## with the fifth's), and is alive or will be made anew by its room's reset. One who walked onto
## another map (a wanderer through a door) is looked for there; a stage the day brings round (a
## `phase` in its conditions) counts whatever the hour.


static func at_hand(session: WorldSessionController, target: String) -> bool:
	var catalog: ContentCatalog = GameContent.catalog()
	if not catalog.quest_target_available(target):
		return false
	var player: WorldPlayerRuntimeState = null if session == null else session.player_runtime() as WorldPlayerRuntimeState
	if player == null or player.state == null:
		return true
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	var worn: Dictionary[StringName, bool] = session.player_worn_item_ids()
	var phase_id: StringName = session.day_phase_id()
	var quests: Array[StoryQuestDefinition] = catalog.story_quests()
	# Every NPC by its spawn point, on whichever map it stands now.
	var by_point: Dictionary[StringName, NpcRuntimeState] = {}
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			by_point[npc.spawn_point_id] = npc
	for spawn: NpcSpawnDefinition in catalog.spawns():
		var npc: NpcDefinition = catalog.npc(spawn.npc_definition_id)
		if npc == null or npc.display_name != target or npc.dealings().is_fight_deferred():
			continue
		if StoryKeeps.holds(player.state, npc.definition_id, quests):
			continue
		var round_the_day: bool = WorldStoryPresence._comes_round(spawn.present) or WorldStoryPresence._comes_round(spawn.until)
		if spawn.staged and not round_the_day and not WorldStoryPresence.on_stage(spawn.present, spawn.until, player, held, worn, phase_id):
			continue
		for point_id: StringName in spawn.spawn_point_ids():
			var standing: NpcRuntimeState = by_point.get(point_id)
			if standing == null:
				# Not made yet on a map not built: as it will be.
				if session.world_map_of(spawn.map_id) == null:
					return true
				continue
			if standing.life_status != CharacterRuntimeLifeStatus.Value.DEAD and not standing.has_flag(NpcDefinition.FLAG_GONE):
				return true
			if spawn.remade_by_reset() and WorldMapNpcs.made_anew(spawn, standing):
				return true
	return false
