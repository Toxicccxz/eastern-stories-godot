class_name NpcService
extends WorldService

## A service an NPC offers from its body, as its LPC object does (buy.c and
## learn.c find the NPC with present()): the map binds one per NPC whose data
## asks for it, it is reached by standing beside the body in its place, and it
## goes with the body when the NPC dies and comes back with the new one.

## Pixels from the body within which the player can use the service.
const REACH: int = 96

var npc: NpcRuntimeState


func bind_npc(p_map: WorldMapController, p_npc: NpcRuntimeState) -> void:
	map = p_map
	npc = p_npc
	name = String(service_id()).replace(".", "_")


## The NPC's spawn: stable across the generations a room reset makes.
func service_id() -> StringName:
	return npc.spawn_id


func display_name() -> String:
	return npc.definition().display_name


## Its body is here and it is not dead (an unconscious vendor still sells: buy.c
## asks only present()).
func npc_present() -> bool:
	return (
		map != null and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
		and map.runtime_body_for_character(npc.character_id) != null
	)


func in_reach() -> bool:
	if not npc_present() or not map.can_act(requires_idle()):
		return false
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	return map.player_near([npc.world_location().zone_id], body.global_position, REACH)
