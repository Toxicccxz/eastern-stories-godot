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
const UI_SCALE_KEY: String = "ui_scale"
const AFTER_KNOCKOUT_KEY: String = "after_knockout"
const OBJECTIVE_HINTS_KEY: String = "objective_hints"
const DAY_NIGHT_KEY: String = "day_night"
## Version 1 had no language; it is read as following the system language.
const VERSION_WITHOUT_LANGUAGE: int = 1
## Version 2 had no battle settings; it is read as 标准 with the flash on.
const VERSION_WITHOUT_BATTLE: int = 2
## Version 3 had no 无边框全屏 and no 界面缩放: its "fullscreen" was the borderless
## kind, so it reads as BORDERLESS, the scale as 100%.
const VERSION_WITHOUT_UI_SCALE: int = 3
## Version 4 had no 击倒后; it reads as 询问.
const VERSION_WITHOUT_KNOCKOUT: int = 4
## Version 5 had no 目标提示; it reads as on.
const VERSION_WITHOUT_OBJECTIVE: int = 5
## Version 6 had no 昼夜; it reads as 跟随游戏时间.
const VERSION_WITHOUT_DAY_NIGHT: int = 6

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
	if version not in [ApplicationSettingsSnapshot.SCHEMA_VERSION, VERSION_WITHOUT_LANGUAGE, VERSION_WITHOUT_BATTLE, VERSION_WITHOUT_UI_SCALE, VERSION_WITHOUT_KNOCKOUT, VERSION_WITHOUT_OBJECTIVE, VERSION_WITHOUT_DAY_NIGHT]:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.UNSUPPORTED_VERSION)
	if not _has_exact_structure(config, version):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var mode_value: Variant = config.get_value(SECTION, WINDOW_MODE_KEY)
	if typeof(mode_value) != TYPE_STRING:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var mode: int = ApplicationWindowMode.from_storage(String(mode_value))
	if not ApplicationWindowMode.is_valid(mode):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	if version < VERSION_WITHOUT_KNOCKOUT:
		if mode == ApplicationWindowMode.Value.BORDERLESS:
			return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
		if mode == ApplicationWindowMode.Value.FULLSCREEN:
			mode = ApplicationWindowMode.Value.BORDERLESS
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
	var scale_value: Variant = config.get_value(SECTION, UI_SCALE_KEY, ApplicationUiScale.DEFAULT)
	if typeof(scale_value) != TYPE_INT or not ApplicationUiScale.is_valid(int(scale_value)):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var knockout_value: Variant = config.get_value(SECTION, AFTER_KNOCKOUT_KEY, BattlePace.knockout_storage_value(BattlePace.AfterKnockout.ASK))
	var knockout: int = BattlePace.knockout_from_storage(String(knockout_value)) if typeof(knockout_value) == TYPE_STRING else -1
	if not BattlePace.is_valid_knockout(knockout):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var hints_value: Variant = config.get_value(SECTION, OBJECTIVE_HINTS_KEY, true)
	if typeof(hints_value) != TYPE_BOOL:
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	var day_night_value: Variant = config.get_value(SECTION, DAY_NIGHT_KEY, DayNightPreference.storage_value(DayNightPreference.Value.FOLLOW))
	var day_night: int = DayNightPreference.from_storage(String(day_night_value)) if typeof(day_night_value) == TYPE_STRING else -1
	if not DayNightPreference.is_valid(day_night):
		return ApplicationSettingsResult.failure(ApplicationSettingsResult.Outcome.INVALID_SETTINGS)
	return ApplicationSettingsResult.success(
		ApplicationSettingsSnapshot.new(
			ApplicationSettingsSnapshot.SCHEMA_VERSION, mode, language, speed, bool(flash_value), int(scale_value), knockout, bool(hints_value), day_night
		)
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
	config.set_value(SECTION, UI_SCALE_KEY, snapshot.ui_scale())
	config.set_value(SECTION, AFTER_KNOCKOUT_KEY, BattlePace.knockout_storage_value(snapshot.after_knockout()))
	config.set_value(SECTION, OBJECTIVE_HINTS_KEY, snapshot.objective_hints())
	config.set_value(SECTION, DAY_NIGHT_KEY, DayNightPreference.storage_value(snapshot.day_night()))
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
	if version >= VERSION_WITHOUT_UI_SCALE:
		expected.append_array([BATTLE_SPEED_KEY, HIT_FLASH_KEY])
	if version >= VERSION_WITHOUT_KNOCKOUT:
		expected.append(UI_SCALE_KEY)
	if version >= VERSION_WITHOUT_OBJECTIVE:
		expected.append(AFTER_KNOCKOUT_KEY)
	if version >= VERSION_WITHOUT_DAY_NIGHT:
		expected.append(OBJECTIVE_HINTS_KEY)
	if version == ApplicationSettingsSnapshot.SCHEMA_VERSION:
		expected.append(DAY_NIGHT_KEY)
	if keys.size() != expected.size():
		return false
	for key: String in expected:
		if not keys.has(key):
			return false
	return true
