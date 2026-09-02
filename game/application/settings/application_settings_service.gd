class_name ApplicationSettingsService
extends RefCounted

var _repository: ApplicationSettingsRepository
var _window_capability: ApplicationWindowModeCapability
var _committed: ApplicationSettingsSnapshot = ApplicationSettingsSnapshot.defaults()


func _init(
	repository: ApplicationSettingsRepository,
	window_capability: ApplicationWindowModeCapability,
) -> void:
	_repository = repository
	_window_capability = window_capability


func load_and_apply() -> ApplicationSettingsServiceResult:
	var repository_result: ApplicationSettingsResult = _repository.load()
	var requested: ApplicationSettingsSnapshot = (
		repository_result.snapshot()
		if repository_result.succeeded()
		else ApplicationSettingsSnapshot.defaults()
	)
	if not _window_capability.can_edit_window_mode():
		_committed = requested
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.UNSUPPORTED_CAPABILITY,
			repository_result.outcome(),
			_committed,
		)
	if not _window_capability.apply_window_mode(requested.window_mode()):
		_committed = ApplicationSettingsSnapshot.new(
			ApplicationSettingsSnapshot.SCHEMA_VERSION,
			_window_capability.current_window_mode(),
		)
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
	if not ApplicationWindowMode.is_valid(mode) or not _window_capability.apply_window_mode(mode):
		return ApplicationSettingsServiceResult.new(
			ApplicationSettingsServiceResult.Outcome.APPLY_FAILURE,
			ApplicationSettingsResult.Outcome.INVALID_SETTINGS,
			_committed,
		)
	_committed = ApplicationSettingsSnapshot.new(ApplicationSettingsSnapshot.SCHEMA_VERSION, mode)
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


func committed_snapshot() -> ApplicationSettingsSnapshot:
	return _committed


func can_edit_window_mode() -> bool:
	return _window_capability.can_edit_window_mode()
