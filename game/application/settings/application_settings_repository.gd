class_name ApplicationSettingsRepository
extends RefCounted

const SETTINGS_PATH: String = "user://settings/application-v1.cfg"
const SETTINGS_DIRECTORY: String = "user://settings"
const SECTION: String = "application"
const VERSION_KEY: String = "schema_version"
const WINDOW_MODE_KEY: String = "window_mode"
const LANGUAGE_KEY: String = "language"
const BATTLE_SPEED_KEY: String = "battle_speed"
const HIT_FLASH_KEY: String = "hit_flash"
## Version 1 had no language; it is read as following the system language.
const VERSION_WITHOUT_LANGUAGE: int = 1
## Version 2 had no battle settings; it is read as 标准 with the flash on.
const VERSION_WITHOUT_BATTLE: int = 2

var _files: SaveFileOperations


func _init(files: SaveFileOperations = null) -> void:
	_files = GodotSaveFileOperations.new() if files == null else files


func storage_path() -> String:
	return SETTINGS_PATH


func load() -> ApplicationSettingsResult:
	if not _files.file_exists(SETTINGS_PATH):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.NO_SETTINGS)
	var read: SaveFileReadResult = _files.read_bytes(SETTINGS_PATH, 65536)
	if read == null or read.error != OK:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.READ_FAILURE)
	var config := ConfigFile.new()
	var parse_error: int = config.parse(read.bytes.get_string_from_utf8())
	if parse_error != OK:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	if not config.has_section_key(SECTION, VERSION_KEY):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var version_value: Variant = config.get_value(SECTION, VERSION_KEY)
	if typeof(version_value) != TYPE_INT:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var version: int = int(version_value)
	if version != ApplicationSettingsSnapshot.SCHEMA_VERSION and version != VERSION_WITHOUT_LANGUAGE and version != VERSION_WITHOUT_BATTLE:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.UNSUPPORTED_VERSION)
	if not _has_exact_structure(config, version):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var mode_value: Variant = config.get_value(SECTION, WINDOW_MODE_KEY)
	if typeof(mode_value) != TYPE_STRING:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var mode: int = ApplicationWindowMode.from_storage(String(mode_value))
	if not ApplicationWindowMode.is_valid(mode):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var language: Variant = config.get_value(SECTION, LANGUAGE_KEY, LocalizationService.FOLLOW_SYSTEM)
	if typeof(language) != TYPE_STRING:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var speed_value: Variant = config.get_value(SECTION, BATTLE_SPEED_KEY, BattlePace.storage_value(BattlePace.Speed.NORMAL))
	var flash_value: Variant = config.get_value(SECTION, HIT_FLASH_KEY, true)
	if typeof(speed_value) != TYPE_STRING or typeof(flash_value) != TYPE_BOOL:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var speed: int = BattlePace.from_storage(String(speed_value))
	if not BattlePace.is_valid(speed):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	return ApplicationSettingsResult.success(
		ApplicationSettingsSnapshot.new(ApplicationSettingsSnapshot.SCHEMA_VERSION, mode, language, speed, bool(flash_value))
	)


func write(snapshot: ApplicationSettingsSnapshot) -> ApplicationSettingsResult:
	if snapshot == null or not snapshot.is_valid():
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	if _files.make_directory_recursive(SETTINGS_DIRECTORY) != OK:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.WRITE_FAILURE)
	var config := ConfigFile.new()
	config.set_value(SECTION, VERSION_KEY, snapshot.version())
	config.set_value(
		SECTION,
		WINDOW_MODE_KEY,
		ApplicationWindowMode.storage_value(snapshot.window_mode()),
	)
	config.set_value(SECTION, LANGUAGE_KEY, snapshot.language())
	config.set_value(SECTION, BATTLE_SPEED_KEY, BattlePace.storage_value(snapshot.battle_speed()))
	config.set_value(SECTION, HIT_FLASH_KEY, snapshot.hit_flash())
	var error: int = _files.write_bytes(SETTINGS_PATH, config.encode_to_text().to_utf8_buffer())
	if error != OK:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.WRITE_FAILURE)
	return ApplicationSettingsResult.success(snapshot)


func _has_exact_structure(config: ConfigFile, version: int) -> bool:
	var sections: PackedStringArray = config.get_sections()
	if sections.size() != 1 or sections[0] != SECTION:
		return false
	var keys: PackedStringArray = config.get_section_keys(SECTION)
	var expected: PackedStringArray = [VERSION_KEY, WINDOW_MODE_KEY]
	if version != VERSION_WITHOUT_LANGUAGE:
		expected.append(LANGUAGE_KEY)
	if version == ApplicationSettingsSnapshot.SCHEMA_VERSION:
		expected.append_array([BATTLE_SPEED_KEY, HIT_FLASH_KEY])
	if keys.size() != expected.size():
		return false
	for key: String in expected:
		if not keys.has(key):
			return false
	return true
