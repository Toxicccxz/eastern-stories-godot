class_name SnowOutdoorController
extends SnowResidentMapController


func map_id() -> StringName:
	return SnowWorldDefinitions.OUTDOOR_MAP_ID


func default_spawn_id() -> StringName:
	return SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID


func local_passages() -> Array[PortalDefinition]:
	return [SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_RETURN_PORTAL_ID)]
