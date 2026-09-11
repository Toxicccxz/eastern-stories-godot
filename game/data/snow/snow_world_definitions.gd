class_name SnowWorldDefinitions
extends RefCounted

## d/snow/inn.c. Only main-floor physical content is supported by NGE2.
const REGION_ID: StringName = &"snow"
const INN_MAP_ID: StringName = &"snow.inn"
const MAIN_FLOOR_ZONE_ID: StringName = &"snow.inn.main_floor"
const MAIN_FLOOR_COMBAT_LOCATION_ID: StringName = &"snow.inn.main_floor"
const BIRTH_SPAWN_ID: StringName = &"snow.inn.main_floor.player_birth"
const INN_SCENE: String = "res://scenes/world/snow/snow_inn.tscn"
const LEGACY_ROOM: String = "/d/snow/inn"
const LEGACY_EAST_EXIT: String = "/d/snow/square"
const LEGACY_UP_EXIT: String = "/d/snow/inn_2f"
const LEGACY_NORTHWEST_EXIT: String = "/d/wiz/entrance"
const LEGACY_VALID_STARTROOM: bool = true
const LEGACY_NORTHWEST_DOOR_CLOSED: bool = true
const LEGACY_TRAVELLER_COUNT: int = 2
const LEGACY_WAITER_COUNT: int = 1
const DISPLAY_NAME: String = "饮风客栈"


static func inn_map() -> MapDefinition:
	# No executable portals: destinations and authored services are deferred.
	return MapDefinition.new(INN_MAP_ID, REGION_ID, INN_SCENE, [MAIN_FLOOR_ZONE_ID], [], [BIRTH_SPAWN_ID])


static func main_floor() -> ZoneDefinition:
	return ZoneDefinition.new(MAIN_FLOOR_ZONE_ID, INN_MAP_ID, MAIN_FLOOR_COMBAT_LOCATION_ID,
		DISPLAY_NAME, [LEGACY_ROOM], "雪亭镇南边的一家小客栈。")


static func birth_location() -> WorldLocationState:
	return WorldLocationState.new(REGION_ID, INN_MAP_ID, MAIN_FLOOR_ZONE_ID, MAIN_FLOOR_COMBAT_LOCATION_ID)
