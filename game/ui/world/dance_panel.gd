class_name DancePanel
extends PanelContainer

## A dance floor's panel (DanceDefinition): one button per dance the player knows here,
## then 随意起舞. DanceService gives it the dances and acts on the one chosen (`step`
## null: the player's own).
signal step_chosen(step: DanceDefinition.Step)

var steps: VBoxContainer


func _init() -> void:
	name = "Panel"
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "你想跳哪一曲？"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(heading)
	steps = VBoxContainer.new()
	steps.name = "Steps"
	rows.add_child(steps)


## The buttons: each known dance, then the player's own.
func show_steps(known: Array[DanceDefinition.Step]) -> void:
	for child: Node in steps.get_children():
		child.queue_free()
	for step: DanceDefinition.Step in known:
		# TRANSLATORS: a dance the player may dance on the floor ({name}: 西出阳关).
		steps.add_child(_button(tr("跳「{name}」").format({"name": tr(step.name)}), step))
	steps.add_child(_button(tr("随意起舞"), null))


func _button(text: String, step: DanceDefinition.Step) -> Button:
	var button := Button.new()
	button.name = "Step"
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(func() -> void: step_chosen.emit(step))
	return button
