class_name WaterService
extends WorldService

## ES2 set("resource/water", 1) (waterfall.c, lake.c): standing here, a held
## wineskin can be filled from the supplies panel. No context action of its own.
## liquid.c do_fill has no fighting gate; the liquid rules decide the rest.


func available() -> bool:
	return (
		map != null
		and map.is_inside_tree()
		and map.is_map_initialized()
		and not map.get_tree().paused
		and map.player_body.player_controlled
		and map.gameplay_open()
		and map.player_runtime().world_location().map_id == map.map_id()
		and map.player_near([definition.zone_id], point.global_position, definition.reach)
	)


func context_title() -> String:
	return ""
