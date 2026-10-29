class_name WorldContentRevision
extends RefCounted

## Versioned world contract, independent of save schema and Session bootstrap mode.
enum Value { LEGACY_OLDPINE_V1, SOURCE_ENTRY_V1, SOURCE_ENTRY_LAKE_V1, SOURCE_ENTRY_OLDPINE_MAPS_V1, SOURCE_ENTRY_SNOW_NPCS_V1, SOURCE_ENTRY_SNOW_SOUTH_V1, SOURCE_ENTRY_SNOW_INNER_V1, SOURCE_ENTRY_SNOW_SERVICES_V1, SOURCE_ENTRY_SNOW_ROUTES_V1, SOURCE_ENTRY_OLDPINE_KEEP_V1, SOURCE_ENTRY_OLDPINE_VENOM_V1, SOURCE_ENTRY_GOATHILL_V1, SOURCE_ENTRY_CLOUD_V1, SOURCE_ENTRY_WATERFOG_V1, SOURCE_ENTRY_CLOUD_FLOORS_V1, SOURCE_ENTRY_OLDPINE_PAINTED_V1, SOURCE_ENTRY_SNOW_PAINTED_V1, SOURCE_ENTRY_GREEN_V1, SOURCE_ENTRY_TEMPLE_V1, SOURCE_ENTRY_LATEMOON_V1, SOURCE_ENTRY_SANYEN_V1, SOURCE_ENTRY_CHOYIN_V1, SOURCE_ENTRY_CHOYIN_B_V1, SOURCE_ENTRY_CHOYIN_C_V1, SOURCE_ENTRY_CHOYIN_D_V1, SOURCE_ENTRY_CANYON_V1, SOURCE_ENTRY_VILLAGE_V1, SOURCE_ENTRY_CITY_V1, SOURCE_ENTRY_CITY_B_V1, SOURCE_ENTRY_CHUENYU_V1, SOURCE_ENTRY_CHUENYU_B_V1, SOURCE_ENTRY_DEATH_V1, SOURCE_ENTRY_REMAP_V1, SOURCE_ENTRY_REMAP_SNOW_V1, SOURCE_ENTRY_REMAP_R1_V1, SOURCE_ENTRY_REMAP_R2_V1, SOURCE_ENTRY_REMAP_R3_V1, SOURCE_ENTRY_REMAP_R4_V1, SOURCE_ENTRY_ROADS_V1, SOURCE_ENTRY_OLDPINE_RELAYOUT_V1, SOURCE_ENTRY_OLDPINE_TRAIL_V1, SOURCE_ENTRY_STORY_CH1_V1, SOURCE_ENTRY_STORY_CH2_V1 }

## Public supported content changes only with atomic world publication, never per commit.
const CURRENT_PUBLIC: Value = Value.SOURCE_ENTRY_STORY_CH2_V1

static func public_support(value: Value) -> GameSaveResult:
	if not is_supported(value):
		return GameSaveResult.failure(GameSaveResult.Outcome.UNKNOWN_WORLD_REVISION, "world_content_revision")
	if value != CURRENT_PUBLIC:
		return GameSaveResult.failure(GameSaveResult.Outcome.INCOMPATIBLE_DEVELOPMENT_CONTRACT, "world_content_revision")
	return GameSaveResult.success()

## Every revision is known (its name in a save is its enum name); only CURRENT_PUBLIC loads
## as a current save (public_support()). A new revision is one more enum value.
static func is_supported(value: Value) -> bool:
	return value in Value.values()

static func serialized(value: Value) -> String:
	return Value.keys()[value] if is_supported(value) else ""

## The revision a save names, or -1 when no revision has that name.
static func parsed(text: String) -> int:
	return Value.keys().find(text)
