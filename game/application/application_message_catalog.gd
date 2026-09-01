class_name ApplicationMessageCatalog
extends RefCounted

const MESSAGES: Dictionary[StringName, String] = {
	&"save.no_save": "No saved journey was found.",
	&"save.continue_available": "A saved journey is ready to continue.",
	&"save.recovery_required": "The main save cannot be used. Recovery will be available in a later update.",
	&"save.unusable": "The saved journey cannot be read.",
	&"save.unsupported": "This saved journey was created by an unsupported version.",
	&"save.storage_failure": "Saved journeys cannot be checked right now.",
	&"operation.success": "The operation completed.",
	&"operation.busy": "Another application operation is still in progress.",
	&"operation.session_failure": "The journey could not be started.",
	&"continue.restore_failure": "The saved journey could not be restored.",
	&"new_game.confirm": "Starting a new game will not erase the current save now. A later successful Save will replace it.",
}


static func text_for(message_key: StringName) -> String:
	return MESSAGES.get(message_key, "The operation could not be completed.")
