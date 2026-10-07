class_name LookSpawnLandmarkPolicy
extends WorldLandmarkPolicy

## house3.c's web: set("item_desc", (: call_spider :)), so looking at it runs
## call_spider(). While fewer than `limit` came since the room's reset (num_of_spider)
## one NPC of the summoned `spawn` comes in and the look reads `spawn`; else the
## landmark's own text (一个很大的蜘蛛网.). Native: no more than its points stand here
## at once (ES2 made a new one each time; DECISIONS 青石村 A).


func look(map: WorldMapController, landmark: WorldLandmarkDefinition) -> String:
	if map == null or landmark == null or map.landmark_uses(landmark.landmark_id) >= landmark.setting("limit"):
		return landmark.description
	var location: WorldLocationState = null if map.player_runtime() == null else map.player_runtime().world_location()
	if location == null or location.zone_id != landmark.zone_id:
		return landmark.description
	if map.summon_one(landmark.spawn_id) == null:
		return landmark.description
	map.count_landmark_use(landmark.landmark_id)
	return landmark.message("spawn")
