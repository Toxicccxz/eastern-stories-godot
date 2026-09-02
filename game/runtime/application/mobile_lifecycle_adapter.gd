class_name MobileLifecycleAdapter
extends Node

signal activity_event(event: ApplicationActivity.Event)

var _capability: MobileLifecycleCapability = MobileLifecycleCapability.new()


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_capability(capability: MobileLifecycleCapability) -> void:
	if capability != null:
		_capability = capability


func _notification(what: int) -> void:
	if not is_inside_tree() or not _capability.enabled():
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
