class_name WorldDeeds
extends RefCounted

## Native (任务系统, 剧情总纲 §7「事迹记录」; DECISIONS「任务系统」): the one place that
## reports what the player did. report() fills in where they stand and who stood there awake
## (the zone's NPCs, the rule's witnesses), writes the deed down (DeedLog) and tells it once
## as a 【事迹】 line. Owned by the session.

var _session: WorldSessionController


func _init(session: WorldSessionController) -> void:
	_session = session


## The player did `did` here and now. Null when nothing was written (no player, "" did).
func report(did: String) -> DeedLog.Deed:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player == null or player.state == null or did.is_empty():
		return null
	var location: WorldLocationState = player.world_location()
	var zone_id: StringName = &"" if location == null else location.zone_id
	var deed: DeedLog.Deed = DeedLog.record(player.state, did, zone_id, witnesses(zone_id))
	var hud: SharedGameplayUI = _session.shared_ui()
	if deed != null and hud != null:
		var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
		# Each name once: two definitions of one name (the inn's and the square's 旅客) read as one.
		var names: Array[String] = []
		for npc_id: StringName in deed.seen_by:
			var npc: NpcDefinition = GameContent.catalog().npc(npc_id)
			var shown: String = hud.tr(npc.display_name) if npc != null else String(npc_id)
			if not names.has(shown):
				names.append(shown)
		hud.append_colored_lines([ColoredLine.new(DeedLog.told_line(deed, "" if zone == null else hud.tr(zone.display_name), names))])
	return deed


## The NPC definitions awake in `zone_id` on the active map, each once.
func witnesses(zone_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var map: WorldMapController = _session.active_map() as WorldMapController
	if map == null or zone_id.is_empty():
		return result
	for npc: NpcRuntimeState in map.npc_runtimes():
		var location: WorldLocationState = npc.world_location()
		if location == null or location.zone_id != zone_id or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			continue
		var definition_id: StringName = npc.definition().definition_id
		if not result.has(definition_id):
			result.append(definition_id)
	return result
