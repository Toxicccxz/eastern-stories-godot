class_name PublicNewGameTestFixture
extends RefCounted

## Existing lifecycle tests start a valid public source journey explicitly.
## Setup-specific tests exercise the unwrapped Shell API and real controls.
static func request(shell: ApplicationShellController) -> bool:
	if not shell.request_new_game_from_menu():
		return false
	return complete_setup(shell)


static func confirm(shell: ApplicationShellController) -> bool:
	if not shell.confirm_current_result():
		return false
	return complete_setup(shell)


static func complete_setup(shell: ApplicationShellController) -> bool:
	if shell.shell_state().mode() != ApplicationShellState.Mode.NEW_GAME_SETUP:
		return true
	shell.player_name_edit.text = "凌雪"
	shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
	return shell.submit_new_game_setup()
