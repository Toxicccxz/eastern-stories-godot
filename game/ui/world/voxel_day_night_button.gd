class_name VoxelDayNightButton
extends Button

## Session-local visual preference, kept across map handoffs but excluded from saves.
var ui: SharedGameplayUI
var night: bool = false
var _view: WorldVoxelView

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = tr("切换夜景")
	tooltip_text = tr("切换白天与夜晚的光照")
	pressed.connect(_toggle)
	visible = false

func _process(_delta: float) -> void:
	var session: WorldSessionController = ui.session()
	# While a session tears down its maps are freed before the slot empties: ask the slot first.
	var live: bool = is_instance_valid(session) and session.is_initialized() and session.active_map_child_count() > 0
	var map: WorldResidentMapController = session.active_map() if live else null
	var view: WorldVoxelView = map.get_node_or_null("MapView") as WorldVoxelView if map != null else null
	visible = view != null
	if view != _view:
		_view = view
		if _view != null:
			_view.set_night(night,true)

func _toggle() -> void:
	night = not night
	text = tr("切换白天") if night else tr("切换夜景")
	if is_instance_valid(_view):
		_view.set_night(night)
