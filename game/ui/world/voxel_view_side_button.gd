class_name VoxelViewSideButton
extends Button

## Like the day/night choice, the camera side belongs to this UI session, not the save.
var ui: SharedGameplayUI
var left_view: bool = false
var _view: WorldVoxelView

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = tr("切至左侧")
	tooltip_text = tr("切换左侧与右侧 45° 固定视角")
	pressed.connect(_toggle)
	visible = false

func _process(_delta: float) -> void:
	var session: WorldSessionController = ui.session()
	var live: bool = is_instance_valid(session) and session.is_initialized() and session.active_map_child_count()>0
	var map: WorldResidentMapController = session.active_map() if live else null
	var view := map.get_node_or_null("MapView") as WorldVoxelView if map != null else null
	visible = view != null
	if view != _view:
		_view = view
		if _view != null:
			_view.set_view_side(left_view,true)

func _toggle() -> void:
	left_view = not left_view
	text = tr("切至右侧") if left_view else tr("切至左侧")
	if is_instance_valid(_view):
		_view.set_view_side(left_view)
