class_name WorkPanel
extends PanelContainer

## d/snow/workplace.c `work` as the player reads it. WorkService fills the player's
## gin/sen/silver and acts on 工作.
signal work_requested

var resources: Label
var feedback: Label


func _init() -> void:
	name = "Panel"
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	add_child(rows)
	resources = _label(rows, "Resources", "")
	var work: Button = Button.new()
	work.name = "WorkButton"
	work.custom_minimum_size = Vector2(0, 48)
	work.text = "工作 · 消耗精30 / 神30 · 工钱一两"
	work.pressed.connect(func() -> void: work_requested.emit())
	rows.add_child(work)
	feedback = _label(rows, "Feedback", "靠近磨盘，可以在这里工作。")


func _label(rows: VBoxContainer, node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(label)
	return label


func show_resources(gin: int, sen: int, silver: int) -> void:
	resources.text = tr("精 {gin} / 神 {sen} · 银子 {silver} 两").format({"gin": gin, "sen": sen, "silver": silver})


func show_work(result: SnowWorkResult) -> void:
	match result.outcome:
		SnowWorkResult.Outcome.SUCCESS:
			feedback.text = "你完成了一份工作，得到一两银子。"
		SnowWorkResult.Outcome.TOO_TIRED:
			feedback.text = "你的精神太差了，现在不能工作。"
		SnowWorkResult.Outcome.DELIVERY_FAILED_CAPACITY:
			feedback.text = "工作已完成，但你负重过高，未能取得工钱。"
		_:
			feedback.text = "工作状态异常，请停止操作。"
			push_error("Work authority failure: %s" % result.outcome)
