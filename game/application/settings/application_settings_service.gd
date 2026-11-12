class_name ApplicationSettingsService
extends RefCounted

var _repository: ApplicationSettingsRepository
var _window_capability: ApplicationWindowModeCapability
## Null where only the window mode matters (older tests); the shell always has one.
var _localization: LocalizationService
var _committed: ApplicationSettingsSnapshot = ApplicationSettingsSnapshot.defaults()
## A window mode or 分辨率 on show but not yet kept.
var _previewing: bool = false


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
	# A first start opens as this machine's screen suits (DECISIONS「显示设置」); a kept
	# setting, even a bad file read as defaults, is not second-guessed.
	if repository_result.outcome() == ApplicationSettingsResult.Outcome.NO_SETTINGS:
		requested = requested.with_window_mode(_window_capability.first_start_window_mode())
	if _localization != null:
		if not _localization.is_known(requested.language()):
			requested = requested.with_language(LocalizationService.FOLLOW_SYSTEM)
		_localization.apply(requested.language())
	_apply_battle(requested)
	GraphicsQuality.keep_hint_told = _keep_quality_hint_told
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
	_window_capability.show_on_screen(requested.screen())
	if not _window_capability.apply_window_mode(requested.window_mode()):
		_committed = requested.with_window_mode(_window_capability.current_window_mode())
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			repository_result.outcome(),
			_committed,
		)
	_window_capability.apply_resolution(requested.resolution())
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
	return apply_and_persist_display(mode, _committed.resolution())


## Keeps the window mode, the 分辨率 and the monitor the game is on.
func apply_and_persist_display(mode: int, resolution: Vector2i) -> ApplicationSettingsServiceResult:
	if not _window_capability.can_edit_window_mode():
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.UNSUPPORTED_CAPABILITY,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	if not _show_display(mode, resolution):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_previewing = false
	_committed = _committed.with_display(mode, resolution, _window_capability.current_screen())
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


## The window mode and 分辨率 show the moment they are picked; 应用 keeps them, 取消 is
## restore_display().
func preview_display(mode: int, resolution: Vector2i) -> bool:
	if not _window_capability.can_edit_window_mode():
		return false
	_previewing = true
	return _show_display(mode, resolution)


## Back to what is kept.
func restore_display() -> void:
	if _previewing:
		_previewing = false
		_show_display(_committed.window_mode(), _committed.resolution())


## 分辨率's choices in `mode` on the monitor the game is on, smallest first.
func resolution_choices(mode: int) -> Array[Vector2i]:
	return ApplicationWindowSize.choices(_window_capability.resolution_room(mode))


## The largest picture `mode` has room for on the monitor the game is on.
func resolution_room(mode: int) -> Vector2i:
	return _window_capability.resolution_room(mode)


func current_screen() -> int:
	return _window_capability.current_screen()


func _show_display(mode: int, resolution: Vector2i) -> bool:
	if (
		not ApplicationWindowMode.is_valid(mode)
		or not ApplicationWindowSize.is_valid(resolution)
		or (mode == ApplicationWindowMode.Value.FULLSCREEN and not _window_capability.offers_exclusive_fullscreen())
		or not _window_capability.apply_window_mode(mode)
	):
		return false
	_window_capability.apply_resolution(resolution)
	return true


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


## The 战斗速度, 受击闪红 and 击倒后 (BattlePace) at once, kept with the other settings.
func apply_and_persist_battle(speed: int, flash: bool, after_knockout: int) -> ApplicationSettingsServiceResult:
	if not BattlePace.is_valid(speed) or not BattlePace.is_valid_knockout(after_knockout):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_battle(speed, flash, after_knockout)
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
	apply_master_volume(settings.master_volume())
	BattlePace.speed = settings.battle_speed()
	BattlePace.hit_flash = settings.hit_flash()
	BattlePace.after_knockout = settings.after_knockout()
	BattlePace.opening = settings.battle_opening()
	ObjectiveHints.shown = settings.objective_hints()
	DayNightPreference.mode = settings.day_night()
	AutosaveNotice.shown = settings.autosave_notice()
	GraphicsQuality.apply(settings.graphics_quality())
	GraphicsQuality.hint_told = settings.quality_hint_told()


## 目标提示 (ObjectiveHints; DECISIONS「新手链与当前目标」) at once, kept with the other settings.
func apply_and_persist_objective_hints(shown: bool) -> ApplicationSettingsServiceResult:
	_committed = _committed.with_objective_hints(shown)
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


## 自动存档提示 (AutosaveNotice; DECISIONS「自动存档」) at once, kept with the other settings.
## 切出窗口时暂停 (DECISIONS「切出窗口」): kept; the shell hands it to the lifecycle adapter.
func apply_and_persist_pause_on_focus_loss(paused: bool) -> ApplicationSettingsServiceResult:
	_committed = _committed.with_pause_on_focus_loss(paused)
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


func apply_and_persist_autosave_notice(shown: bool) -> ApplicationSettingsServiceResult:
	_committed = _committed.with_autosave_notice(shown)
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


## 总音量 (DECISIONS「战斗拍数 C」): the Master bus at `percent` of full (0: muted).
static func apply_master_volume(percent: int) -> void:
	var bus: int = AudioServer.get_bus_index(&"Master")
	if bus < 0:
		return
	var share: float = clampf(float(percent) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus, share <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(share, 0.001)))


## 战斗开场动画 (DECISIONS「战斗演出 B」) at once, kept with the other settings.
func apply_and_persist_battle_opening(choice: int) -> ApplicationSettingsServiceResult:
	if not BattlePace.is_valid_opening(choice):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_battle_opening(choice)
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


## The 总音量 at once, kept with the other settings.
func apply_and_persist_master_volume(percent: int) -> ApplicationSettingsServiceResult:
	if percent < 0 or percent > 100:
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_master_volume(percent)
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


## 昼夜 (DayNightPreference; DECISIONS「昼夜」) at once, kept with the other settings.
func apply_and_persist_day_night(mode: int) -> ApplicationSettingsServiceResult:
	if not DayNightPreference.is_valid(mode):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_day_night(mode)
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


## 画质 (GraphicsQuality; DECISIONS「画质」) at once, kept with the other settings.
func apply_and_persist_graphics_quality(quality: int) -> ApplicationSettingsServiceResult:
	if not GraphicsQuality.is_valid(quality):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = _committed.with_graphics_quality(quality)
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


## The 画质 slow-frame hint was told (GraphicsQuality.note_hint_told()): kept, never told again.
func _keep_quality_hint_told() -> void:
	if _committed.quality_hint_told():
		return
	_committed = _committed.with_quality_hint_told(true)
	_repository.write(_committed)


func committed_snapshot() -> ApplicationSettingsSnapshot:
	return _committed


func can_edit_window_mode() -> bool:
	return _window_capability.can_edit_window_mode()


func offers_exclusive_fullscreen() -> bool:
	return _window_capability.offers_exclusive_fullscreen()
