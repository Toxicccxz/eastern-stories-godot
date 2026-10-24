class_name WorkService
extends WorldService

## d/snow/workplace.c `work`: spend gin/sen for one silver (SnowWorkService). Its panel
## (WorkPanel, ui/) shows the player's gin/sen/silver and says when they ask to work.
var panel: WorkPanel
var last_result: SnowWorkResult


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	panel = WorkPanel.new()
	panel.hide()
	panel.work_requested.connect(request_work)
	ui_layer().add_child(panel)


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
		panel.show_resources(state.essence.current, state.spirit.current, silver_amount())


func request_work() -> SnowWorkResult:
	last_result = SnowWorkResult.new()
	if not in_reach():
		last_result.outcome = SnowWorkResult.Outcome.INTERACTION_BLOCKED
		return last_result
	var player: WorldPlayerRuntimeState = map.player_runtime()
	last_result = SnowWorkService.work(player.state, player.character_id, player.maximum_encumbrance,
		player.armor, map.inventory_state(), map.stack_collection(), map.item_instance_index(), map.item_id_allocator())
	panel.show_work(last_result)
	return last_result


func silver_amount() -> int:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var amount: int = 0
	for id: StringName in map.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		var item: ItemInstance = map.item_instance_index().resolve(id)
		if item != null and GameContent.catalog().denomination_of(item.item_definition_id) == CurrencyDenomination.Value.SILVER and map.stack_collection().has_stack(id):
			amount += map.stack_collection().stack_state(id).amount
	return amount
