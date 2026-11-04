class_name ItemModelView
extends SubViewportContainer
## The 背包's large picture of the item read (owner, 2026-11-04): its voxel look
## (VoxelItemLook) turning slowly in a studio of its own, the panel showing through behind it.

## Radians a second.
const TURN_SPEED: float = 0.55

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model: Node3D
## The item definition shown, "" none.
var shown: StringName = &""


func _init(pixels: int = 200) -> void:
	name = "ItemModelView"
	stretch = true
	custom_minimum_size = Vector2(pixels, pixels)
	# The menu's layout clears minimum widths; the picture keeps its square.
	set_meta(ResponsivePanelLayout.KEEPS_WIDTH, true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(pixels, pixels)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	_pivot = VoxelItemLook.furnish(_viewport)
	_camera = _viewport.get_node("Stage/Camera") as Camera3D


## Shows the look of `item_definition_id` ("" none), facing the same way the last one did.
func show_item(item_definition_id: StringName) -> void:
	if item_definition_id == shown and _model != null:
		return
	shown = item_definition_id
	if _model != null:
		_pivot.remove_child(_model)
		_model.queue_free()
		_model = null
	if item_definition_id.is_empty():
		return
	_model = Node3D.new()
	_model.name = "Model"
	_pivot.add_child(_model)
	VoxelItemLook.build(_model, VoxelItemLook.look(item_definition_id))
	VoxelItemLook.frame(_pivot, _model, _camera, true)


func _process(delta: float) -> void:
	if _model != null and is_visible_in_tree():
		_pivot.rotation.y = fposmod(_pivot.rotation.y + delta * TURN_SPEED, TAU)
