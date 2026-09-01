class_name ApplicationMessageCatalog
extends RefCounted

const MESSAGES: Dictionary[StringName, String] = {
	&"save.no_save": "No saved journey was found.",
	&"save.continue_available": "A saved journey is ready to continue.",
	&"save.recovery_required": "The main save cannot be used. A recovery candidate is available.",
	&"save.unusable": "The saved journey cannot be read.",
	&"save.unsupported": "This saved journey was created by an unsupported version.",
	&"save.storage_failure": "Saved journeys cannot be checked right now.",
	&"operation.success": "The operation completed.",
	&"operation.busy": "Another application operation is still in progress.",
	&"operation.session_failure": "The journey could not be started.",
	&"continue.restore_failure": "The saved journey could not be restored.",
	&"new_game.confirm": "Starting a new game will not erase the current save now. A later successful Save will replace it.",
	&"save.success": "Your journey was saved.",
	&"save.blocked.combat_or_action": "Saving is unavailable during combat or an unfinished action.",
	&"save.blocked.world_transition": "Saving is unavailable while moving between areas.",
	&"save.blocked.lifecycle": "Saving is unavailable while a character lifecycle change is incomplete.",
	&"save.blocked.temporary_effect": "Saving is unavailable while a temporary effect cannot be preserved.",
	&"save.blocked.runtime_not_ready": "Saving is unavailable until the current journey is ready.",
	&"save.capture_failure": "The current journey could not be prepared for saving.",
	&"save.write_failure": "The save could not be written.",
	&"return.confirm": "Progress since the last successful save may be lost.",
}


static func text_for(message_key: StringName) -> String:
	return MESSAGES.get(message_key, "The operation could not be completed.")
