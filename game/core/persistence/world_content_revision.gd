class_name WorldContentRevision
extends RefCounted

## Versioned world contract, independent of save schema and Session bootstrap mode.
enum Value { LEGACY_OLDPINE_V1, SOURCE_ENTRY_V1, SOURCE_ENTRY_LAKE_V1, SOURCE_ENTRY_OLDPINE_MAPS_V1, SOURCE_ENTRY_SNOW_NPCS_V1, SOURCE_ENTRY_SNOW_SOUTH_V1, SOURCE_ENTRY_SNOW_INNER_V1, SOURCE_ENTRY_SNOW_SERVICES_V1, SOURCE_ENTRY_SNOW_ROUTES_V1 }

## Public supported content changes only with atomic world publication, never per commit.
const CURRENT_PUBLIC: Value = Value.SOURCE_ENTRY_SNOW_ROUTES_V1

static func public_support(value: Value) -> GameSaveResult:
	if not is_supported(value):
		return GameSaveResult.failure(GameSaveResult.Outcome.UNKNOWN_WORLD_REVISION, "world_content_revision")
	if value != CURRENT_PUBLIC:
		return GameSaveResult.failure(GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, "world_content_revision")
	return GameSaveResult.success()

static func is_supported(value: Value) -> bool:
	return value in [Value.LEGACY_OLDPINE_V1, Value.SOURCE_ENTRY_V1, Value.SOURCE_ENTRY_LAKE_V1, Value.SOURCE_ENTRY_OLDPINE_MAPS_V1, Value.SOURCE_ENTRY_SNOW_NPCS_V1, Value.SOURCE_ENTRY_SNOW_SOUTH_V1, Value.SOURCE_ENTRY_SNOW_INNER_V1, Value.SOURCE_ENTRY_SNOW_SERVICES_V1, Value.SOURCE_ENTRY_SNOW_ROUTES_V1]

static func serialized(value: Value) -> String:
	match value:
		Value.LEGACY_OLDPINE_V1: return "LEGACY_OLDPINE_V1"
		Value.SOURCE_ENTRY_V1: return "SOURCE_ENTRY_V1"
		Value.SOURCE_ENTRY_LAKE_V1: return "SOURCE_ENTRY_LAKE_V1"
		Value.SOURCE_ENTRY_OLDPINE_MAPS_V1: return "SOURCE_ENTRY_OLDPINE_MAPS_V1"
		Value.SOURCE_ENTRY_SNOW_NPCS_V1: return "SOURCE_ENTRY_SNOW_NPCS_V1"
		Value.SOURCE_ENTRY_SNOW_SOUTH_V1: return "SOURCE_ENTRY_SNOW_SOUTH_V1"
		Value.SOURCE_ENTRY_SNOW_INNER_V1: return "SOURCE_ENTRY_SNOW_INNER_V1"
		Value.SOURCE_ENTRY_SNOW_SERVICES_V1: return "SOURCE_ENTRY_SNOW_SERVICES_V1"
		Value.SOURCE_ENTRY_SNOW_ROUTES_V1: return "SOURCE_ENTRY_SNOW_ROUTES_V1"
	return ""
