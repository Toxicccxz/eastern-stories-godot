class_name MobileLifecycleAdapter
extends Node
## The application's lifecycle as ApplicationActivity events: on a phone or tablet the
## system's background / foreground / focus; on the desktop the window's focus, while
## 切出窗口时暂停 is on (DECISIONS「切出窗口」; the shell sets pause_on_focus_loss from the settings).

signal activity_event(event: ApplicationActivity.Event)

var _capability: MobileLifecycleCapability = MobileLifecycleCapability.new()
## 切出窗口时暂停: the desktop window losing its focus pauses the game.
var pause_on_focus_loss: bool = true
## The desktop window lost its focus and that was told (FOCUS_OUT sent, FOCUS_IN owed).
var _desktop_out: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func capability() -> MobileLifecycleCapability:
	return _capability


func set_capability(capability: MobileLifecycleCapability) -> void:
	if capability != null:
		_capability = capability


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if not _capability.enabled():
		_desktop_notification(what)
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			activity_event.emit(ApplicationActivity.Event.PAUSED)
		NOTIFICATION_APPLICATION_RESUMED:
			activity_event.emit(ApplicationActivity.Event.RESUMED)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			activity_event.emit(ApplicationActivity.Event.FOCUS_OUT)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			activity_event.emit(ApplicationActivity.Event.FOCUS_IN)


## The desktop window's focus. A return is always told once a loss was (the setting may have
## been turned off meanwhile from the pause it brought).
func _desktop_notification(what: int) -> void:
	if not _capability.desktop_focus():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and not _desktop_out:
		_desktop_out = true
		activity_event.emit(ApplicationActivity.Event.FOCUS_OUT)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _desktop_out:
		_desktop_out = false
		activity_event.emit(ApplicationActivity.Event.FOCUS_IN)
