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
const MSTREET1_ZONE_ID: StringName = &"snow.mstreet1"
const MSTREET2_ZONE_ID: StringName = &"snow.mstreet2"
const MSTREET3_ZONE_ID: StringName = &"snow.mstreet3"
const MSTREET4_ZONE_ID: StringName = &"snow.mstreet4"
const CROSSROAD_ZONE_ID: StringName = &"snow.crossroad"
const NORTH_SPINE_ZONE_IDS: Array[StringName] = [MSTREET2_ZONE_ID, MSTREET3_ZONE_ID, MSTREET4_ZONE_ID, CROSSROAD_ZONE_ID]
const WORKPLACE_ZONE_ID: StringName = &"snow.workplace"
const WORKPLACE_TARGET_ID: StringName = &"snow.workplace.work"
const BANK_ZONE_ID: StringName = &"snow.bank"
const HOCKSHOP_ZONE_ID: StringName = &"snow.hockshop"
const SCHOOL1_ZONE_ID: StringName = &"snow.school1"
const SCHOOL2_ZONE_ID: StringName = &"snow.school2"
const SCHOOLHALL_ZONE_ID: StringName = &"snow.schoolhall"
const SCHOOL_ZONE_IDS: Array[StringName] = [SCHOOL1_ZONE_ID, SCHOOL2_ZONE_ID, SCHOOLHALL_ZONE_ID]
const LEGACY_MSTREET2_DRUNK_COUNT: int = 1
const LEGACY_MSTREET2_SCAVENGER_COUNT: int = 1
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
	var ids: Array[StringName] = ROUTE_ZONE_IDS.duplicate()
	ids.append_array([MSTREET1_ZONE_ID, MSTREET2_ZONE_ID, WORKPLACE_ZONE_ID, BANK_ZONE_ID])
	ids.append_array([MSTREET3_ZONE_ID, MSTREET4_ZONE_ID, CROSSROAD_ZONE_ID])
	ids.append(HOCKSHOP_ZONE_ID)
	ids.append_array(SCHOOL_ZONE_IDS)
	return MapDefinition.new(OUTDOOR_MAP_ID, REGION_ID, OUTDOOR_SCENE, ids, [INN_RETURN_PORTAL_ID], [SQUARE_ENTRY_SPAWN_ID])


static func route_zones() -> Array[ZoneDefinition]:
	return [
		ZoneDefinition.new(&"snow.square", OUTDOOR_MAP_ID, &"snow.square", "广场", ["/d/snow/square"]),
		ZoneDefinition.new(&"snow.sroad1", OUTDOOR_MAP_ID, &"snow.sroad1", "雪亭镇街道", ["/d/snow/sroad1"]),
		ZoneDefinition.new(&"snow.eroad1", OUTDOOR_MAP_ID, &"snow.eroad1", "黄土小径", ["/d/snow/eroad1"]),
		ZoneDefinition.new(&"snow.eroad2", OUTDOOR_MAP_ID, &"snow.eroad2", "黄土小径", ["/d/snow/eroad2"]),
		ZoneDefinition.new(&"snow.eroad3", OUTDOOR_MAP_ID, &"snow.eroad3", "山路", ["/d/snow/eroad3"]),
		ZoneDefinition.new(MSTREET1_ZONE_ID, OUTDOOR_MAP_ID, MSTREET1_ZONE_ID, "雪亭镇街道", ["/d/snow/mstreet1"]),
		ZoneDefinition.new(MSTREET2_ZONE_ID, OUTDOOR_MAP_ID, MSTREET2_ZONE_ID, "雪亭镇大街", ["/d/snow/mstreet2"]),
		ZoneDefinition.new(WORKPLACE_ZONE_ID, OUTDOOR_MAP_ID, WORKPLACE_ZONE_ID, "谷物加工厂", ["/d/snow/workplace"]),
		ZoneDefinition.new(BANK_ZONE_ID, OUTDOOR_MAP_ID, BANK_ZONE_ID, "安记钱庄", ["/d/snow/bank"]),
		ZoneDefinition.new(MSTREET3_ZONE_ID, OUTDOOR_MAP_ID, MSTREET3_ZONE_ID, "雪亭镇街道", ["/d/snow/mstreet3"]),
		ZoneDefinition.new(MSTREET4_ZONE_ID, OUTDOOR_MAP_ID, MSTREET4_ZONE_ID, "雪亭镇街道", ["/d/snow/mstreet4"]),
		ZoneDefinition.new(CROSSROAD_ZONE_ID, OUTDOOR_MAP_ID, CROSSROAD_ZONE_ID, "山坳", ["/d/snow/crossroad"]),
		ZoneDefinition.new(HOCKSHOP_ZONE_ID, OUTDOOR_MAP_ID, HOCKSHOP_ZONE_ID, "丰登当铺", ["/d/snow/hockshop"]),
		ZoneDefinition.new(SCHOOL1_ZONE_ID, OUTDOOR_MAP_ID, SCHOOL1_ZONE_ID, "淳风武馆大门", ["/d/snow/school1"]),
		ZoneDefinition.new(SCHOOL2_ZONE_ID, OUTDOOR_MAP_ID, SCHOOL2_ZONE_ID, "淳风武馆教练场", ["/d/snow/school2"]),
		ZoneDefinition.new(SCHOOLHALL_ZONE_ID, OUTDOOR_MAP_ID, SCHOOLHALL_ZONE_ID, "淳风武馆大厅", ["/d/snow/schoolhall"]),
	]


static func zone_by_id(id: StringName) -> ZoneDefinition:
	if id == MAIN_FLOOR_ZONE_ID:
		return main_floor()
	for zone: ZoneDefinition in route_zones():
		if zone.zone_id == id:
			return zone
	return null


static func route_neighbours(from_id: StringName, to_id: StringName) -> bool:
	var school_route: Array[StringName] = [MSTREET1_ZONE_ID, SCHOOL1_ZONE_ID, SCHOOL2_ZONE_ID, SCHOOLHALL_ZONE_ID]
	var school_from: int = school_route.find(from_id)
	var school_to: int = school_route.find(to_id)
	if school_from >= 0 and school_to >= 0 and absi(school_from - school_to) == 1:
		return true
	if (from_id == HOCKSHOP_ZONE_ID and to_id == MSTREET3_ZONE_ID) or (to_id == HOCKSHOP_ZONE_ID and from_id == MSTREET3_ZONE_ID):
		return true
	var north_from: int = NORTH_SPINE_ZONE_IDS.find(from_id)
	var north_to: int = NORTH_SPINE_ZONE_IDS.find(to_id)
	if north_from >= 0 and north_to >= 0 and absi(north_from - north_to) == 1:
		return true
	if (from_id == BANK_ZONE_ID and to_id == MSTREET1_ZONE_ID) or (to_id == BANK_ZONE_ID and from_id == MSTREET1_ZONE_ID):
		return true
	if (from_id == &"snow.square" and to_id == MSTREET1_ZONE_ID) or (to_id == &"snow.square" and from_id == MSTREET1_ZONE_ID):
		return true
	if (from_id == MSTREET1_ZONE_ID and to_id == MSTREET2_ZONE_ID) or (to_id == MSTREET1_ZONE_ID and from_id == MSTREET2_ZONE_ID):
		return true
	if (from_id == MSTREET2_ZONE_ID and to_id == WORKPLACE_ZONE_ID) or (to_id == MSTREET2_ZONE_ID and from_id == WORKPLACE_ZONE_ID):
		return true
	var from_index: int = ROUTE_ZONE_IDS.find(from_id)
	var to_index: int = ROUTE_ZONE_IDS.find(to_id)
	return from_index >= 0 and to_index >= 0 and absi(from_index - to_index) == 1


## Traceability only: these entries do not create native portals or destinations.
static func authored_outdoor_exits() -> Dictionary[String, String]:
	return {
		"school1:west": "/d/snow/mstreet1", "school1:east": "/d/snow/school2",
		"school2:west": "/d/snow/school1", "school2:east": "/d/snow/schoolhall",
		"school2:north": "/d/snow/weapon_storage", # Deferred side route.
		"schoolhall:west": "/d/snow/school2", "schoolhall:east": "/d/snow/inneryard",
		"hockshop:west": "/d/snow/mstreet3", "hockshop:east": "/d/snow/hockshop2", # East is metadata only; no destination.
		"bank:east": "/d/snow/mstreet1",
		"mstreet1:south": "/d/snow/square", "mstreet1:north": "/d/snow/mstreet2",
		"mstreet1:east": "/d/snow/school1", "mstreet1:west": "/d/snow/bank",
		"mstreet2:south": "/d/snow/mstreet1", "mstreet2:north": "/d/snow/mstreet3",
		"mstreet2:east": "/d/snow/workplace", "mstreet2:west": "/d/snow/smithy",
		"workplace:west": "/d/snow/mstreet2",
		"mstreet3:south": "/d/snow/mstreet2", "mstreet3:north": "/d/snow/mstreet4",
		"mstreet3:east": "/d/snow/hockshop", "mstreet3:west": "/d/snow/herbshop",
		"mstreet4:south": "/d/snow/mstreet3", "mstreet4:north": "/d/snow/crossroad",
		"mstreet4:west": "/d/snow/postoffice",
		"crossroad:south": "/d/snow/mstreet4", "crossroad:north": "/d/goathill/mroad1",
		"crossroad:east": "/d/green/path6",
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
