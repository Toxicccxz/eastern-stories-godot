class_name ItemIcons
extends Node
## The 背包 rows' small pictures (owner, 2026-11-04): each item definition's voxel look
## (VoxelItemLook) taken once in a still studio, a few a frame, and kept for the game's run.
## Without a screen to draw on (headless runs) there are none.

signal icon_ready(item_definition_id: StringName, texture: Texture2D)

## Pixels a side; rows show it smaller, so it stays sharp.
const PIXELS: int = 96
## Pictures taken a frame at most.
const PER_FRAME: int = 2

## Taken pictures by item definition, for every 背包 of the run.
static var _taken: Dictionary[StringName, Texture2D] = {}
## Pictures that came back empty: not asked for again.
static var _failed: Dictionary[StringName, bool] = {}

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _waiting: Array[StringName] = []
var _busy: bool = false


func _ready() -> void:
	name = "ItemIcons"
	if not drawing():
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PIXELS, PIXELS)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_pivot = VoxelItemLook.furnish(_viewport)
	_camera = _viewport.get_node("Stage/Camera") as Camera3D


## Whether pictures can be taken here (a real renderer).
static func drawing() -> bool:
	return DisplayServer.get_name() != "headless"


## The picture of `item_definition_id`, or null while it is being taken (icon_ready follows).
func icon(item_definition_id: StringName) -> Texture2D:
	if _taken.has(item_definition_id):
		return _taken[item_definition_id]
	if drawing() and not _failed.has(item_definition_id) and not _waiting.has(item_definition_id):
		_waiting.append(item_definition_id)
	return null


func _process(_delta: float) -> void:
	if _busy or _waiting.is_empty() or _viewport == null:
		return
	_take_some()


func _take_some() -> void:
	_busy = true
	for i: int in mini(PER_FRAME, _waiting.size()):
		var id: StringName = _waiting.pop_front()
		if _taken.has(id):
			continue
		var model := Node3D.new()
		_pivot.add_child(model)
		VoxelItemLook.build(model, VoxelItemLook.look(id))
		VoxelItemLook.frame(_pivot, model, _camera, false)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(_viewport):
			return
		var image: Image = _viewport.get_texture().get_image()
		_pivot.remove_child(model)
		model.queue_free()
		if image == null or image.is_empty():
			_failed[id] = true
			continue
		var texture := ImageTexture.create_from_image(image)
		_taken[id] = texture
		icon_ready.emit(id, texture)
	_busy = false
