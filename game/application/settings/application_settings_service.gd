class_name ApplicationSettingsService
extends RefCounted

var _repository: ApplicationSettingsRepository
var _window_capability: ApplicationWindowModeCapability
## Null where only the window mode matters (older tests); the shell always has one.
var _localization: LocalizationService
var _committed: ApplicationSettingsSnapshot = ApplicationSettingsSnapshot.defaults()


func _init(
	repository: ApplicationSettingsRepository,
	window_capability: ApplicationWindowModeCapability,
	localization: LocalizationService = null,
) -> void:
	_repository = repository
	_window_capability = window_capability
	_localization = localization


## The language, battle settings and 界面缩放 apply on every platform, whatever the
## window mode capability says.
func load_and_apply() -> ApplicationSettingsServiceResult:
	var repository_result: ApplicationSettingsResult = _repository.load()
	var requested: ApplicationSettingsSnapshot = (
		repository_result.snapshot()
		if repository_result.succeeded()
		else ApplicationSettingsSnapshot.defaults()
	)
	if _localization != null:
		if not _localization.is_known(requested.language()):
			requested = requested.with_language(LocalizationService.FOLLOW_SYSTEM)
		_localization.apply(requested.language())
	_apply_battle(requested)
	_window_capability.prepare_platform_window()
	_window_capability.apply_ui_scale(requested.ui_scale())
	if requested.window_mode() == ApplicationWindowMode.Value.FULLSCREEN and not _window_capability.offers_exclusive_fullscreen():
		requested = requested.with_window_mode(ApplicationWindowMode.Value.BORDERLESS)
	if not _window_capability.can_edit_window_mode():
		_committed = requested
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.UNSUPPORTED_CAPABILITY,
			repository_result.outcome(),
			_committed,
		)
	if not _window_capability.apply_window_mode(requested.window_mode()):
		_committed = requested.with_window_mode(_window_capability.current_window_mode())
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			repository_result.outcome(),
			_committed,
		)
	_committed = requested
	var service_outcome: int = (
		ApplicationSettingsServiceResult.Outcome.SUCCESS
		if repository_result.succeeded()
		else ApplicationSettingsServiceResult.Outcome.DEFAULTED
	)
	return ApplicationSettingsServiceResult.new(
		service_outcome,
		repository_result.outcome(),
		_committed,
	)


func apply_and_persist(mode: int) -> ApplicationSettingsServiceResult:
	if not _window_capability.can_edit_window_mode():
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.UNSUPPORTED_CAPABILITY,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	if (
		not ApplicationWindowMode.is_valid(mode)
		or (mode == ApplicationWindowMode.Value.FULLSCREEN and not _window_capability.offers_exclusive_fullscreen())
		or not _window_capability.apply_window_mode(mode)
	):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_window_mode(mode)
	var repository_result: ApplicationSettingsResult = _repository.write(_committed)
	if not repository_result.succeeded():
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.PERSISTENCE_FAILURE,
			repository_result.outcome(),
			_committed,
		)
	return ApplicationSettingsServiceResult.new(
		ApplicationSettingsServiceResult.Outcome.SUCCESS,
		repository_result.outcome(),
		_committed,
	)


## Shows the game in `language` (a code, or FOLLOW_SYSTEM) at once and keeps the choice.
func apply_and_persist_language(language: String) -> ApplicationSettingsServiceResult:
	if _localization == null or not _localization.is_known(language):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_localization.apply(language)
	if _localization.active_code() != _localization.language_for(language).code:
		# Its translation would not load: the shown language stays, the choice is not kept.
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_language(language)
	var repository_result: ApplicationSettingsResult = _repository.write(_committed)
	return ApplicationSettingsServiceResult.new(
		(
			ApplicationSettingsServiceResult.Outcome.SUCCESS
			if repository_result.succeeded()
			else ApplicationSettingsServiceResult.Outcome.PERSISTENCE_FAILURE
		),
		repository_result.outcome(),
		_committed,
	)


## The 战斗速度 and 受击闪红 (BattlePace) at once, kept with the other settings.
func apply_and_persist_battle(speed: int, flash: bool) -> ApplicationSettingsServiceResult:
	if not BattlePace.is_valid(speed):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_battle(speed, flash)
	_apply_battle(_committed)
	var repository_result: ApplicationSettingsResult = _repository.write(_committed)
	return ApplicationSettingsServiceResult.new(
		(
			ApplicationSettingsServiceResult.Outcome.SUCCESS
			if repository_result.succeeded()
			else ApplicationSettingsServiceResult.Outcome.PERSISTENCE_FAILURE
		),
		repository_result.outcome(),
		_committed,
	)


## The 界面缩放 at once, kept with the other settings.
func apply_and_persist_ui_scale(percent: int) -> ApplicationSettingsServiceResult:
	if not ApplicationUiScale.is_valid(percent):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_ui_scale(percent)
	_window_capability.apply_ui_scale(percent)
	var repository_result: ApplicationSettingsResult = _repository.write(_committed)
	return ApplicationSettingsServiceResult.new(
		(
			ApplicationSettingsServiceResult.Outcome.SUCCESS
			if repository_result.succeeded()
			else ApplicationSettingsServiceResult.Outcome.PERSISTENCE_FAILURE
		),
		repository_result.outcome(),
		_committed,
	)


static func _apply_battle(settings: ApplicationSettingsSnapshot) -> void:
	BattlePace.speed = settings.battle_speed()
	BattlePace.hit_flash = settings.hit_flash()


func committed_snapshot() -> ApplicationSettingsSnapshot:
	return _committed


func can_edit_window_mode() -> bool:
	return _window_capability.can_edit_window_mode()


func offers_exclusive_fullscreen() -> bool:
	return _window_capability.offers_exclusive_fullscreen()
