class_name TechnicalShellFixture
extends RefCounted

## Explicit test-only graph setup for old combat/pointer/cave regression subjects.
## NOT a public New Game path, and never included in sanitized production.
static func start(shell: ApplicationShellController) -> void:
	assert(shell.shell_state().mode() == ApplicationShellState.Mode.NEW_GAME_SETUP)
	assert(shell.runtime_host().current_session() == null)
	shell.cancel_new_game_setup()
	# Explicit fixture-only Save/Continue boundary, never the production source gate.
	var host: OldPineGameRuntimeHost = shell.runtime_host()
	host._coordinator = OldPineSessionLoadCoordinator.new(GameSaveRepository.new(host._profile, host._files))
	shell._set_state(ApplicationShellState.starting(ApplicationShellState.Operation.NEW_GAME))
	var session: OldPineWorldSessionController = preload("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	shell._on_new_game_completed(shell.runtime_host()._attach_new_game_session(session))
