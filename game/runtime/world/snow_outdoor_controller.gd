class_name SnowOutdoorController
extends SnowResidentMapController


func map_id() -> StringName:
	return SnowWorldDefinitions.OUTDOOR_MAP_ID


func default_spawn_id() -> StringName:
	return SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID


func exit_portal_id() -> StringName:
	return SnowWorldDefinitions.INN_RETURN_PORTAL_ID
