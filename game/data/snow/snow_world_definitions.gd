class_name SnowWorldDefinitions
extends RefCounted

## d/snow/inn.c. Only main-floor physical content is supported by NGE2.
const REGION_ID: StringName = &"snow"
const INN_MAP_ID: StringName = &"snow.inn"
const MAIN_FLOOR_ZONE_ID: StringName = &"snow.inn.main_floor"
const MAIN_FLOOR_COMBAT_LOCATION_ID: StringName = &"snow.inn.main_floor"
const BIRTH_SPAWN_ID: StringName = &"snow.inn.main_floor.player_birth"
const INN_RETURN_SPAWN_ID: StringName = &"snow.inn.main_floor.square_return"
const OUTDOOR_MAP_ID: StringName = &"snow.outdoor"
const OUTDOOR_SCENE: String = "res://scenes/world/snow/snow_outdoor.tscn"
const SQUARE_ENTRY_SPAWN_ID: StringName = &"snow.square.inn_entry"
const INN_EXIT_PORTAL_ID: StringName = &"snow.inn.east"
const INN_RETURN_PORTAL_ID: StringName = &"snow.square.west"
const ROUTE_ZONE_IDS: Array[StringName] = [&"snow.square", &"snow.sroad1", &"snow.eroad1", &"snow.eroad2", &"snow.eroad3"]
const LEGACY_SQUARE_TRAV_BLADE_COUNT: int = 3
const LEGACY_EROAD2_DOG_COUNT: int = 2
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
	return MapDefinition.new(INN_MAP_ID, REGION_ID, INN_SCENE, [MAIN_FLOOR_ZONE_ID], [INN_EXIT_PORTAL_ID], [BIRTH_SPAWN_ID, INN_RETURN_SPAWN_ID])


static func main_floor() -> ZoneDefinition:
	return ZoneDefinition.new(MAIN_FLOOR_ZONE_ID, INN_MAP_ID, MAIN_FLOOR_COMBAT_LOCATION_ID,
		DISPLAY_NAME, [LEGACY_ROOM], "雪亭镇南边的一家小客栈。")


static func birth_location() -> WorldLocationState:
	return WorldLocationState.new(REGION_ID, INN_MAP_ID, MAIN_FLOOR_ZONE_ID, MAIN_FLOOR_COMBAT_LOCATION_ID)


static func outdoor_map() -> MapDefinition:
	return MapDefinition.new(OUTDOOR_MAP_ID, REGION_ID, OUTDOOR_SCENE, ROUTE_ZONE_IDS, [INN_RETURN_PORTAL_ID], [SQUARE_ENTRY_SPAWN_ID])


static func route_zones() -> Array[ZoneDefinition]:
	return [
		ZoneDefinition.new(&"snow.square", OUTDOOR_MAP_ID, &"snow.square", "广场", ["/d/snow/square"]),
		ZoneDefinition.new(&"snow.sroad1", OUTDOOR_MAP_ID, &"snow.sroad1", "雪亭镇街道", ["/d/snow/sroad1"]),
		ZoneDefinition.new(&"snow.eroad1", OUTDOOR_MAP_ID, &"snow.eroad1", "黄土小径", ["/d/snow/eroad1"]),
		ZoneDefinition.new(&"snow.eroad2", OUTDOOR_MAP_ID, &"snow.eroad2", "黄土小径", ["/d/snow/eroad2"]),
		ZoneDefinition.new(&"snow.eroad3", OUTDOOR_MAP_ID, &"snow.eroad3", "山路", ["/d/snow/eroad3"]),
	]


static func zone_by_id(id: StringName) -> ZoneDefinition:
	if id == MAIN_FLOOR_ZONE_ID:
		return main_floor()
	for zone: ZoneDefinition in route_zones():
		if zone.zone_id == id:
			return zone
	return null


static func route_neighbours(from_id: StringName, to_id: StringName) -> bool:
	var from_index: int = ROUTE_ZONE_IDS.find(from_id)
	var to_index: int = ROUTE_ZONE_IDS.find(to_id)
	return from_index >= 0 and to_index >= 0 and absi(from_index - to_index) == 1


## Traceability only: these entries do not create native portals or destinations.
static func authored_outdoor_exits() -> Dictionary[String, String]:
	return {
		"square:north": "/d/snow/mstreet1", "square:west": "/d/snow/inn",
		"square:south": "/d/snow/sroad1", "square:east": "/d/snow/temple",
		"sroad1:north": "/d/snow/square", "sroad1:east": "/d/snow/eroad1",
		"sroad1:west": "/d/snow/sroad2", "sroad1:south": "/u/cloud/dragonhill/nroad",
		"eroad1:west": "/d/snow/sroad1", "eroad1:east": "/d/snow/eroad2", "eroad1:north": "/d/snow/temple",
		"eroad2:west": "/d/snow/eroad1", "eroad2:east": "/d/snow/eroad3",
		"eroad3:west": "/d/snow/eroad2", "eroad3:south": "/d/oldpine/npath1", "eroad3:east": "/d/temple/sroad",
	}


static func portal_by_id(id: StringName) -> PortalDefinition:
	if id == INN_EXIT_PORTAL_ID:
		return PortalDefinition.new(id, INN_MAP_ID, MAIN_FLOOR_ZONE_ID, OUTDOOR_MAP_ID, &"snow.square", SQUARE_ENTRY_SPAWN_ID, PortalDefinition.InteractionKind.TRAVERSE, &"", "/d/snow/inn", &"east")
	if id == INN_RETURN_PORTAL_ID:
		return PortalDefinition.new(id, OUTDOOR_MAP_ID, &"snow.square", INN_MAP_ID, MAIN_FLOOR_ZONE_ID, INN_RETURN_SPAWN_ID, PortalDefinition.InteractionKind.TRAVERSE, &"", "/d/snow/square", &"west")
	return null
