class_name FocusNav
extends RefCounted
## Where keyboard or pad focus lands when a panel opens (owner, gamepad support), and
## whether a remembered control can take it back when the panel closes.


## The first control under `root` (tree order) that can take focus now, or null.
## `skip_text`: not a text box either (a panel opens on a button, not into typing).
static func first_focusable(root: Node, skip_text: bool = false) -> Control:
	if root == null or root.is_queued_for_deletion():
		return null
	var control := root as Control
	# Text is read, not stopped on (the 任务 log scrolls with the right stick).
	if control != null and can_focus(control) and not control is RichTextLabel and not (skip_text and control is LineEdit):
		return control
	# Internal children too: a SpinBox's LineEdit is one.
	for child: Node in root.get_children(true):
		if child is ScrollBar or child is Window or (child is CanvasItem and not (child as CanvasItem).visible):
			continue
		var found: Control = first_focusable(child, skip_text)
		if found != null:
			return found
	return null


## Whether `control` can take focus now: in the tree, shown, focusable, not greyed.
static func can_focus(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	return not (control is BaseButton and (control as BaseButton).disabled)


## Gives `control` the focus when it can take it; false otherwise. On a pad a text box
## is not typed into until A (its D-pad moves on, or steps a number: PadSupport).
static func give(control: Control) -> bool:
	if not can_focus(control):
		return false
	control.grab_focus()
	if control is LineEdit and InputDevices.shared().is_gamepad():
		(control as LineEdit).unedit()
	return true


## The child places from `root` down to `control` (rows being freed do not count).
static func place_of(root: Node, control: Node) -> PackedInt32Array:
	var place := PackedInt32Array()
	var node: Node = control
	while node != null and node != root:
		var parent: Node = node.get_parent()
		if parent == null:
			return PackedInt32Array()
		place.insert(0, _live_children(parent).find(node))
		node = parent
	return place


## The focusable control nearest the same place under `root` (a rebuilt list's row at the
## same index, or the last row when the list got shorter), else null.
static func at_place(root: Node, place: PackedInt32Array) -> Control:
	var trail: Array[Node] = [root]
	var node: Node = root
	for index: int in place:
		var children: Array[Node] = _live_children(node)
		if children.is_empty():
			break
		node = children[clampi(index, 0, children.size() - 1)]
		trail.append(node)
	for step: int in range(trail.size() - 1, -1, -1):
		var found: Control = first_focusable(trail[step])
		if found != null:
			return found
	return null


static func _live_children(node: Node) -> Array[Node]:
	var live: Array[Node] = []
	for child: Node in node.get_children(true):
		if not child.is_queued_for_deletion():
			live.append(child)
	return live


## The control a WeakRef holds, or null.
static func held(ref: WeakRef) -> Control:
	return null if ref == null else ref.get_ref() as Control
