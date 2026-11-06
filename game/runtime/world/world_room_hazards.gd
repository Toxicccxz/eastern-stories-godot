class_name WorldRoomHazards
extends RefCounted

## The Session's room hazards (hazards[] in world.json, RoomHazardDefinition): while the
## player stands in a hazard's zone its act comes after `first_ms` of world time and then
## every `every_ms`; leaving clears the wait (trap_castle.c's arrowing() finds the player
## gone and stops). Not saved: a Continue there waits the first time again. A native hazard
## (第八章 A, DECISIONS「寒气」) runs only with pacing's native_hazards, and a time it spares (the
## 宝衣 worn, a mark borne) passes with nothing done.
var _session: WorldSessionController
var _zone_id: StringName = &""
var _elapsed_ms: float = 0.0
var _next_ms: float = 0.0


func _init(session: WorldSessionController) -> void:
	_session = session


## World time passes; each act due is run where the player stands.
func advance(delta: float) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = null if map == null else map.player_runtime()
	var location: WorldLocationState = null if player == null or not player.exists_in_world else player.world_location()
	var hazard: RoomHazardDefinition = null if location == null else GameContent.catalog().hazard_in(location.zone_id)
	if hazard != null and hazard.native and not GameContent.catalog().pacing().native_hazards:
		hazard = null
	if hazard == null:
		_zone_id = &""
		return
	if hazard.zone_id != _zone_id:
		_zone_id = hazard.zone_id
		_elapsed_ms = 0.0
		_next_ms = hazard.first_ms
	_elapsed_ms += delta * 1000.0
	while _elapsed_ms >= _next_ms:
		_next_ms += hazard.every_ms
		var status: CharacterRuntimeLifeStatus.Value = player.life_status
		if hazard.spares(_session.player_worn_item_ids(), player.state.marks):
			continue
		var act: ScriptedAct = hazard.act_for(player.state.gender, player.state.affiliation.class_id, map.acts.facts(hazard.zone_id))
		if act == null:
			continue
		map.acts.run(act, null, map.world_interaction_random_source().legacy_random, hazard.zone_id)
		# The act may have taken the player away (a death's revival), felled them or stopped
		# world time: the next volley waits for the next advance, as each call_out() did.
		if _session.active_map() != map or not player.exists_in_world or player.world_location() == null or player.world_location().zone_id != hazard.zone_id:
			_zone_id = &""
			return
		if player.life_status != status or not _session.npc_world_time_allowed():
			_elapsed_ms = minf(_elapsed_ms, _next_ms - 1.0)
			return


## How long the player has stood in the hazard's zone (tests).
func elapsed_ms() -> float:
	return _elapsed_ms if not _zone_id.is_empty() else 0.0
