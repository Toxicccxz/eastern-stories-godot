class_name ExplorationPresentationBlocker
extends Node

## Non-dismissable presentation/input context, not a gameplay or pause authority.
signal context_changed

const GROUP: StringName = &"exploration_presentation_blockers"
var _surface: Control
var _leaving: bool = false


func _enter_tree() -> void:
	_leaving = false
	if is_instance_valid(_surface):
		_changed.call_deferred() # Restore promotion reparents the same Session nodes.


func _ready() -> void:
	_surface = get_parent() as Control
	add_to_group(GROUP)
	_surface.visibility_changed.connect(_changed)
	_changed()


func _exit_tree() -> void:
	_leaving = true
	context_changed.emit()


func _changed() -> void:
	context_changed.emit()


static func is_blocked(tree: SceneTree) -> bool:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var blocker: ExplorationPresentationBlocker = node as ExplorationPresentationBlocker
		if blocker != null and not blocker._leaving and is_instance_valid(blocker._surface) and blocker._surface.is_visible_in_tree():
			return true
	return false
