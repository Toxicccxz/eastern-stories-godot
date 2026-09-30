class_name WaterService
extends WorldService

## ES2 set("resource/water", 1) (waterfall.c, lake.c): standing here, a held
## wineskin can be filled from the supplies panel. No context action of its own.


func available() -> bool:
	return map != null and map.can_act(false) and map.player_near([definition.zone_id], point.global_position, definition.reach)


func context_title() -> String:
	return ""
