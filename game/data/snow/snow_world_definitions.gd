class_name SnowWorldDefinitions
extends RefCounted

## IDs the Snow runtime refers to by name. The maps, zones, rooms and portals
## themselves are data (snow/world.json, snow/rooms.json).
const REGION_ID: StringName = &"snow"
const INN_MAP_ID: StringName = &"snow.inn"
const MAIN_FLOOR_ZONE_ID: StringName = &"snow.inn.main_floor"
const BIRTH_SPAWN_ID: StringName = &"snow.inn.main_floor.player_birth"
const INN_RETURN_SPAWN_ID: StringName = &"snow.inn.main_floor.square_return"
const OUTDOOR_MAP_ID: StringName = &"snow.outdoor"
const SQUARE_ENTRY_SPAWN_ID: StringName = &"snow.square.inn_entry"
const INN_EXIT_PORTAL_ID: StringName = &"snow.inn.east"
const INN_RETURN_PORTAL_ID: StringName = &"snow.square.west"
const MSTREET1_ZONE_ID: StringName = &"snow.mstreet1"
const MSTREET2_ZONE_ID: StringName = &"snow.mstreet2"
const MSTREET3_ZONE_ID: StringName = &"snow.mstreet3"
const WORKPLACE_ZONE_ID: StringName = &"snow.workplace"
const BANK_ZONE_ID: StringName = &"snow.bank"
const HOCKSHOP_ZONE_ID: StringName = &"snow.hockshop"
const SCHOOL1_ZONE_ID: StringName = &"snow.school1"
const SCHOOL2_ZONE_ID: StringName = &"snow.school2"
const SCHOOLHALL_ZONE_ID: StringName = &"snow.schoolhall"
## include/login.h REVIVE_ROOM: dead players come back here.
const TEMPLE_ZONE_ID: StringName = &"snow.temple"
const REVIVE_SPAWN_ID: StringName = &"snow.temple.revive"


static func birth_location() -> WorldLocationState:
	return WorldLocationState.new(REGION_ID, INN_MAP_ID, MAIN_FLOOR_ZONE_ID, MAIN_FLOOR_ZONE_ID)
