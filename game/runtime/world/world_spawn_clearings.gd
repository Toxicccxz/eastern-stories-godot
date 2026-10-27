class_name WorldSpawnClearings
extends RefCounted

## Native (前两小时 B; DECISIONS「客栈的老鼠」): a spawn with a `cleared_mark` (snow's
## 老鼠) marks the player once none of its NPCs stands any more — every one of them
## knocked down or dead, on the journal's beat. The mark stays (CharacterState.marks is
## saved) when the room's reset brings them back: what was done was done. Nothing
## else in the world changes; an NPC's answer (NpcInquiryRule.asker_marks) reads it.


## Looks at every such spawn the player has not cleared yet.
static func note(session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	if player == null or player.state == null:
		return
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns():
		if spawn.cleared_mark.is_empty() or int(player.state.marks.get(spawn.cleared_mark, 0)) != 0:
			continue
		var map: WorldMapController = session.resident_map(spawn.map_id) as WorldMapController
		if map != null and cleared(map, spawn.spawn_id):
			player.state.marks[spawn.cleared_mark] = 1


## None of the spawn's NPCs on `map` stands (there is at least one, and each is down,
## dead or gone from the map).
static func cleared(map: WorldMapController, spawn_id: StringName) -> bool:
	var seen: bool = false
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_id != spawn_id:
			continue
		seen = true
		if npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			return false
	return seen
