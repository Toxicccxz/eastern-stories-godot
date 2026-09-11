class_name SnowOldPineConnectionDefinitions
extends RefCounted

## Cross-region content only. Neither region definition imports the other.
const SOUTH_PORTAL_ID: StringName = &"snow.eroad3.south"
const NORTH_PORTAL_ID: StringName = &"oldpine.npath1.north"
const SNOW_RETURN_SPAWN_ID: StringName = &"snow.eroad3.oldpine_return"
const NORTH_ENTRY_SPAWN_ID: StringName = &"oldpine.outdoor.north_approach.snow_entry"


static func to_oldpine() -> PortalDefinition:
	return PortalDefinition.new(SOUTH_PORTAL_ID,
		SnowWorldDefinitions.OUTDOOR_MAP_ID, &"snow.eroad3",
		OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID,
		NORTH_ENTRY_SPAWN_ID, PortalDefinition.InteractionKind.TRAVERSE,
		&"", "/d/snow/eroad3", &"south")


static func to_snow() -> PortalDefinition:
	return PortalDefinition.new(NORTH_PORTAL_ID,
		OldPineWorldDefinitions.OUTDOOR_MAP_ID, OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID,
		SnowWorldDefinitions.OUTDOOR_MAP_ID, &"snow.eroad3",
		SNOW_RETURN_SPAWN_ID, PortalDefinition.InteractionKind.TRAVERSE,
		&"", "/d/oldpine/npath1", &"north")
