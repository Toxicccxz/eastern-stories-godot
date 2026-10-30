class_name WorldStoryPresence
extends RefCounted

## Native (主线 A, 剧情总纲 §8 第 3 步; DECISIONS「剧情演出」): who and what the story puts on
## a map now. A spawn with `present` / `until` (NpcSpawnDefinition, ItemSpawnDefinition) is on
## the stage while its `present` holds and its `until` does not; both are journal `when`s
## read against the player's state (a quest ledger key, a mark, a milestone). The stage is
## judged only when the player comes onto the map (a handoff, the first map, a Continue),
## never in front of them: an NPC on the stage and absent appears on its marker, one off the
## stage and standing leaves for good (as an act's `leave`: not made anew); an item on the
## stage and never made lies down on its marker, one off the stage and still lying untouched
## on its marker is gone (one the player took and dropped is theirs, wherever it lies). What the player took, killed or was given stays as it is.


static func stage(session: WorldSessionController, map: WorldMapController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime() as WorldPlayerRuntimeState
	if player == null or player.state == null or map == null or not map.is_map_initialized():
		return
	var catalog: ContentCatalog = GameContent.catalog()
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	var worn: Dictionary[StringName, bool] = session.player_worn_item_ids()
	for spawn: NpcSpawnDefinition in catalog.spawns_for_map(map.map_id()):
		if not spawn.staged:
			continue
		var on: bool = on_stage(spawn.present, spawn.until, player, held, worn)
		for point_id: StringName in spawn.spawn_point_ids():
			var npc: NpcRuntimeState = map.npcs.npc_at_point(point_id)
			if npc == null or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or npc.has_flag(NpcDefinition.FLAG_GONE):
				continue
			if on and not npc.exists_in_map:
				map.npcs.appear(npc, spawn)
			elif not on and npc.exists_in_map:
				map.npcs.leave_for_good(npc)
	for spawn: ItemSpawnDefinition in catalog.item_spawns_for_map(map.map_id()):
		if not spawn.staged:
			continue
		var on: bool = on_stage(spawn.present, spawn.until, player, held, worn)
		for point_id: StringName in spawn.spawn_point_ids():
			var item_id: StringName = map.floor_items.spawn_item_id(point_id)
			var made: bool = map.inventory_state().is_registered(item_id)
			if on and not made:
				if not map.floor_items.place_floor_item(spawn, point_id):
					push_error("the story could not lay %s on %s" % [spawn.item_definition_id, point_id])
			# Only the untouched one on its marker goes; one the player took and dropped is theirs
			# (saved where they dropped it: the Save/Continue policy).
			elif not on and made and map.floor_items.item_views.has(item_id) and not map.floor_items.dropped_item_ids().has(item_id):
				map.floor_items.destroy_floor_item(item_id)


## Whether a spawn with these conditions is on the stage for this player.
static func on_stage(present: JournalEntryDefinition, until: JournalEntryDefinition, player: WorldPlayerRuntimeState, held: Dictionary[StringName, bool], worn: Dictionary[StringName, bool] = {}) -> bool:
	if present != null and not JournalLog.holds(present, player.state, player.temp_marks, held, &"", worn):
		return false
	return until == null or not JournalLog.holds(until, player.state, player.temp_marks, held, &"", worn)
