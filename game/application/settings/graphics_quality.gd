class_name GraphicsQuality
extends RefCounted

## The 画质 setting (DECISIONS「画质」): a setting, not the save, as DayNightPreference is. 高 draws
## the game as it was drawn before the setting; 低 trades the shadows' soft edges and detail, the
## smooth edges and the farther lamps' shadows for the frame (data/common/graphics_quality.json).
## The application settings set it once loaded and on 应用. What the whole renderer holds (the
## shadows' filter, the sun shadow's size) changes here at once; what a map's view holds (its
## MSAA, the sun's splits, how many lamps cast) the view reads from settings() when `revision`
## moves.
enum Value { HIGH, LOW }

const STORAGE: Dictionary[int, String] = {Value.HIGH: "high", Value.LOW: "low"}
const DATA_PATH: String = "res://data/common/graphics_quality.json"
const FILTERS: Dictionary[String, int] = {
	"hard": RenderingServer.SHADOW_QUALITY_HARD,
	"soft_very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	"soft_low": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	"soft_medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	"soft_high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	"soft_ultra": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
}
const MSAA: Dictionary[int, Viewport.MSAA] = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}

static var level: int = Value.HIGH
## Moves each time a level is applied: a view compares it with the one it last applied.
static var revision: int = 0
## The slow-frame hint has been told (kept with the settings; told once ever).
static var hint_told: bool = false
## Keeps hint_told with the settings (the settings service sets it).
static var keep_hint_told: Callable = Callable()
static var _data: Dictionary = {}


static func is_valid(value: int) -> bool:
	return STORAGE.has(value)


static func storage_value(value: int) -> String:
	return STORAGE.get(value, STORAGE[Value.HIGH])


## -1 for a stored value that is neither.
static func from_storage(text: String) -> int:
	for value: int in STORAGE:
		if STORAGE[value] == text:
			return value
	return -1


## graphics_quality.json, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## A level's values (the data's `levels` entry): label, shadow_filter, sun_shadow_size,
## sun_splits, msaa, lamp_shadows.
static func settings(value: int = level) -> Dictionary:
	var levels: Dictionary = data().get("levels", {})
	return levels.get(storage_value(value), levels.get(STORAGE[Value.HIGH], {}))


static func label(value: int) -> String:
	return String(settings(value).get("label", storage_value(value)))


## What the 3D viewport's MSAA is at this level.
static func msaa(value: int = level) -> Viewport.MSAA:
	return MSAA.get(int(settings(value).get("msaa", 4)), Viewport.MSAA_4X)


static func sun_shadow_mode(value: int = level) -> DirectionalLight3D.ShadowMode:
	match int(settings(value).get("sun_splits", 4)):
		1:
			return DirectionalLight3D.SHADOW_ORTHOGONAL
		2:
			return DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	return DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


static func lamp_shadows(value: int = level) -> int:
	return int(settings(value).get("lamp_shadows", 8))


## The level a first start (or a settings file from before 画质) takes on this machine: the
## data's default, or its Steam Deck level on a Steam Deck.
static func device_default() -> int:
	return default_for(OS.get_name(), RenderingServer.get_video_adapter_name(), OS.get_environment(String(data().get("steam_deck", {}).get("environment", "SteamDeck"))))


## device_default() for a given system name, video adapter and the Steam Deck's environment
## variable (Steam sets it to "1" there).
static func default_for(os_name: String, adapter: String, deck_variable: String) -> int:
	var fallback: int = from_storage(String(data().get("default", "high")))
	if fallback < 0:
		fallback = Value.HIGH
	var deck: Dictionary = data().get("steam_deck", {})
	if os_name != "Linux" or deck.is_empty():
		return fallback
	var on_deck: bool = deck_variable == "1"
	for name: Variant in deck.get("adapters", []):
		if adapter.containsn(String(name)):
			on_deck = true
	var deck_level: int = from_storage(String(deck.get("level", "")))
	return deck_level if on_deck and deck_level >= 0 else fallback


## Sets the level: the whole renderer's part at once, a view's when it sees `revision` move.
static func apply(value: int) -> void:
	if not is_valid(value) or (value == level and revision > 0):
		return
	level = value
	revision += 1
	var values: Dictionary = settings(value)
	var filter: int = FILTERS.get(String(values.get("shadow_filter", "soft_low")), RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)
	RenderingServer.positional_soft_shadow_filter_set_quality(filter)
	RenderingServer.directional_shadow_atlas_set_size(int(values.get("sun_shadow_size", 4096)), bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)))


## The slow-frame hint (data `slow_hint`): below_fps, seconds, settle_seconds.
static func slow_hint() -> Dictionary:
	return data().get("slow_hint", {})


## The hint has been told: kept so it is never told again.
static func note_hint_told() -> void:
	hint_told = true
	if keep_hint_told.is_valid():
		keep_hint_told.call()
