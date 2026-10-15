class_name InputGlyphBinding
extends Node
## Keeps a Button's icon on its action's glyph (InputGlyphs.decorate()): the glyph while
## the player uses keys or a pad, no icon on touch, so touch buttons keep their size.

const NODE_NAME: String = "InputGlyph"

var texture: InputGlyphTexture


## Binds `button`'s icon to `action` (again: the new action).
static func attach(button: Button, action: StringName) -> InputGlyphBinding:
	var binding := button.get_node_or_null(NODE_NAME) as InputGlyphBinding
	if binding == null:
		binding = InputGlyphBinding.new()
		binding.name = NODE_NAME
		binding.texture = InputGlyphTexture.new(action)
		button.add_child(binding)
	else:
		binding.texture = InputGlyphTexture.new(action)
		binding.apply()
	return binding


## The action a button shows, or &"" (tests).
static func action_of(button: Button) -> StringName:
	var binding := button.get_node_or_null(NODE_NAME) as InputGlyphBinding
	return &"" if binding == null else binding.texture.action


func _enter_tree() -> void:
	var devices: InputDevices = InputDevices.shared()
	if not devices.changed.is_connected(apply):
		devices.changed.connect(apply)
	apply()


func _exit_tree() -> void:
	var devices: InputDevices = InputDevices.shared()
	if devices.changed.is_connected(apply):
		devices.changed.disconnect(apply)


func apply() -> void:
	var button := get_parent() as Button
	if button == null:
		return
	button.icon = texture if texture.has_glyph() else null
