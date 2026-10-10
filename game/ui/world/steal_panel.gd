class_name StealPanel
extends VBoxContainer

## steal <item> from <npc> (cmds/std/steal.c): one button for each thing the NPC is seen to wear
## or wield (look.c shows only those), 随手摸一样 for whatever the hand finds (steal.c's pick
## when the name matches nothing), and 算了.
signal chosen(item_id: StringName)
signal cancelled

var question: Label
var items_box: VBoxContainer
var anything_button: Button
var cancel_button: Button


func _init() -> void:
	name = "Steal"
	add_theme_constant_override("separation", 10)
	question = Label.new()
	question.name = "Question"
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(question)
	items_box = VBoxContainer.new()
	items_box.name = "Items"
	items_box.add_theme_constant_override("separation", 6)
	add_child(items_box)
	anything_button = Button.new()
	anything_button.name = "Anything"
	# TRANSLATORS: the 偷窃 list's choice for no thing in particular: steal.c takes one of everything the NPC carries.
	anything_button.text = "随手摸一样"
	anything_button.custom_minimum_size = Vector2(0, 44)
	anything_button.pressed.connect(func() -> void: chosen.emit(&""))
	add_child(anything_button)
	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	# TRANSLATORS: closes the 偷窃 list without stealing.
	cancel_button.text = "算了"
	cancel_button.custom_minimum_size = Vector2(120, 44)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	add_child(cancel_button)


## `npc_name` shown, and the things seen on it: item IDs with their shown names.
func show_items(npc_name: String, ids: Array[StringName], names: Array[String]) -> void:
	# TRANSLATORS: the 偷窃 list's question: {npc} the one the player means to steal from.
	question.text = tr("想从{npc}身上偷什么？").format({"npc": npc_name})
	for child: Node in items_box.get_children():
		items_box.remove_child(child)
		child.queue_free()
	for index: int in range(ids.size()):
		var button := Button.new()
		button.name = "Item"
		button.text = names[index]
		button.custom_minimum_size = Vector2(0, 44)
		var id: StringName = ids[index]
		button.pressed.connect(func() -> void: chosen.emit(id))
		items_box.add_child(button)


## The things' buttons as shown, in order.
func shown_items() -> Array[String]:
	var out: Array[String] = []
	for child: Node in items_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			out.append((child as Button).text)
	return out
