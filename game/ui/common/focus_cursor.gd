class_name FocusCursor
extends TextureRect

## The bobbing voxel arrow beside the focused button (界面重做, DECISIONS「界面样式」): the
## same sign as the arrows over a map's exits, so keys and a pad always show where they are.
## It follows the viewport's focus owner while that is a visible button inside `scope`.

const GAP: float = 6.0
const BOB_SPEED: float = 5.0
const BOB_PIXELS: float = 2.0

var scope: Node
var _clock: float = 0.0


func _init(p_scope: Node = null) -> void:
	name = "FocusCursor"
	scope = p_scope
	texture = ImageTexture.create_from_image(UiBlocks.arrow_image())
	# Not in a container: the rect is the arrow's own size, set rather than left to the minimum.
	size = texture.get_size()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	visible = false


func _process(delta: float) -> void:
	_clock += delta
	var target: BaseButton = focused_button()
	visible = target != null
	if target == null:
		return
	var bob: float = sin(_clock * BOB_SPEED) * BOB_PIXELS
	global_position = (target.global_position + Vector2(-size.x - GAP + bob, (target.size.y - size.y) / 2.0)).round()


## The button the arrow points at, or null.
func focused_button() -> BaseButton:
	if not is_inside_tree() or scope == null or not is_instance_valid(scope):
		return null
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner is BaseButton and owner.is_visible_in_tree() and scope.is_ancestor_of(owner) and not _in_a_row(owner):
		return owner as BaseButton
	return null


## Buttons side by side (覆盖 | 取消, 应用 | 取消) leave no room for the arrow: their rim shows
## the focus there.
static func _in_a_row(button: Control) -> bool:
	var parent: Node = button.get_parent()
	var across: bool = parent is HBoxContainer or parent is HFlowContainer
	if not across:
		return false
	for sibling: Node in parent.get_children():
		if sibling != button and sibling is BaseButton and (sibling as Control).visible:
			return true
	return false
