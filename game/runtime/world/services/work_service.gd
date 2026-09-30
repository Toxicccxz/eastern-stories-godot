class_name WorkService
extends WorldService

## d/snow/workplace.c `work`: spend gin/sen for one silver (SnowWorkService).
var panel: PanelContainer
var resources: Label
var feedback: Label
var last_result: SnowWorkResult


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	panel.add_child(rows)
	resources = _label(rows, "Resources", "")
	var work: Button = Button.new()
	work.name = "WorkButton"
	work.custom_minimum_size = Vector2(0, 48)
	work.text = tr("工作 · 消耗精30 / 神30 · 工钱一两")
	work.pressed.connect(request_work)
	rows.add_child(work)
	feedback = _label(rows, "Feedback", tr("靠近磨盘，可以在这里工作。"))
	ui_layer().add_child(panel)


func _label(rows: VBoxContainer, node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(label)
	return label


func verb() -> String:
	return tr("工作")


func interact() -> void:
	if in_reach():
		open_panel(context_title(), panel)


func _process(_delta: float) -> void:
	if panel.visible and not in_reach():
		panel.hide()
	if panel.visible:
		var state: CharacterState = map.player_runtime().state
		resources.text = tr("精 %d / 神 %d · 银子 %d 两") % [state.essence.current, state.spirit.current, silver_amount()]


func request_work() -> SnowWorkResult:
	last_result = SnowWorkResult.new()
	if not in_reach():
		last_result.outcome = SnowWorkResult.Outcome.INTERACTION_BLOCKED
		return last_result
	var player: WorldPlayerRuntimeState = map.player_runtime()
	last_result = SnowWorkService.work(player.state, player.character_id, player.maximum_encumbrance,
		player.armor, map.inventory_state(), map.stack_collection(), map.item_instance_index(), map.item_id_allocator())
	match last_result.outcome:
		SnowWorkResult.Outcome.SUCCESS:
			feedback.text = tr("你完成了一份工作，得到一两银子。")
		SnowWorkResult.Outcome.TOO_TIRED:
			feedback.text = tr("你的精神太差了，现在不能工作。")
		SnowWorkResult.Outcome.DELIVERY_FAILED_CAPACITY:
			feedback.text = tr("工作已完成，但你负重过高，未能取得工钱。")
		_:
			feedback.text = tr("工作状态异常，请停止操作。")
			push_error("Work authority failure: %s" % last_result.outcome)
	return last_result


func silver_amount() -> int:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var amount: int = 0
	for id: StringName in map.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		var item: ItemInstance = map.item_instance_index().resolve(id)
		if item != null and GameContent.catalog().denomination_of(item.item_definition_id) == CurrencyDenomination.Value.SILVER and map.stack_collection().has_stack(id):
			amount += map.stack_collection().stack_state(id).amount
	return amount
