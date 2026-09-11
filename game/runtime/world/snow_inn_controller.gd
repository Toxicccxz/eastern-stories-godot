class_name SnowInnController
extends SnowResidentMapController

@onready var floor_area: Area2D = %MainFloor


func map_id() -> StringName:
	return SnowWorldDefinitions.INN_MAP_ID


func default_spawn_id() -> StringName:
	return SnowWorldDefinitions.BIRTH_SPAWN_ID


func exit_portal_id() -> StringName:
	return SnowWorldDefinitions.INN_EXIT_PORTAL_ID
