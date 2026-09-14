class_name HeldFoodPanel
extends CanvasLayer

## One Session-owned view across all resident maps. IDs are selection only;
## the collection, Player resources and Inventory remain authoritative.
var _session: OldPineWorldSessionController
var _panel: PanelContainer
var _select: OptionButton
var _eat: Button
var _feedback: Label
var _ids: Array[StringName] = []
var last_result: FoodUseResult


func configure(session: OldPineWorldSessionController) -> void:
	_session = session


func _ready() -> void:
	layer = 9
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -370
	_panel.offset_top = -166
	_panel.offset_right = -24
	_panel.offset_bottom = -24
	add_child(_panel)
	var rows: VBoxContainer = VBoxContainer.new()
	_panel.add_child(rows)
	var title: Label = Label.new()
	title.text = "随身食物"
	rows.add_child(title)
	_select = OptionButton.new()
	_select.name = "FoodInstance"
	_select.custom_minimum_size = Vector2(320, 36)
	rows.add_child(_select)
	_eat = Button.new()
	_eat.name = "Eat"
	_eat.text = "吃一份"
	_eat.custom_minimum_size.y = 40
	_eat.pressed.connect(request_eat)
	rows.add_child(_eat)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_feedback)
	_panel.hide()


func available() -> bool:
	if _session == null or not _session.is_initialized() or not is_inside_tree() or get_tree().paused or not _session.world_simulation_gate().is_open():
		return false
	var map: WorldResidentMapController = _session.active_map()
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return map != null and map.is_map_initialized() and map.runtime_player_body() != null and map.runtime_player_body().player_controlled and player.exists_in_world and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not player.relationship.is_fighting()


func _process(_delta: float) -> void:
	_panel.visible = available()
	if not _panel.visible:
		return
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var ids: Array[StringName] = []
	for id: StringName in _session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		if _session.food_collection().state(id) != null:
			ids.append(id)
	if ids != _ids:
		var selected: StringName = &"" if _select.selected < 0 or _select.selected >= _ids.size() else _ids[_select.selected]
		_ids = ids
		_select.clear()
		for id: StringName in _ids:
			_select.add_item(String(id))
			if id == selected:
				_select.select(_select.item_count - 1)
	for i: int in range(_ids.size()):
		var state: FoodState = _session.food_collection().state(_ids[i])
		_select.set_item_text(i, "包子 #%d · %d份 · 价值%d文" % [i + 1, state.remaining_portions, state.current_value])
	_eat.disabled = _ids.is_empty()
	_panel.visible = not _ids.is_empty() or last_result != null


func request_eat() -> FoodUseResult:
	if _select.selected < 0 or _select.selected >= _ids.size():
		return FoodUseResult.new()
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var context: MoneyInventoryContext = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), _session.inventory_state(), _session.stack_collection(), _session.item_instance_index())
	last_result = HeldFoodUseService.eat(player, context, _session.food_collection(), OldPineNativeItemDefinitionProjections.create(_session.world_content_revision()), _ids[_select.selected], available())
	match last_result.outcome:
		FoodUseResult.Outcome.ATE:
			_feedback.text = "吃了一份。食物：%d" % last_result.food_after
		FoodUseResult.Outcome.TOO_FULL:
			_feedback.text = "已经太饱了，吃不下。"
		FoodUseResult.Outcome.NOT_DIRECT_HELD:
			_feedback.text = "只能吃自己直接携带的食物。"
		FoodUseResult.Outcome.COMBAT_BLOCKED:
			_feedback.text = "战斗中暂不能吃东西。"
		FoodUseResult.Outcome.BUSY:
			_feedback.text = "上一个动作还没有完成。"
		FoodUseResult.Outcome.AUTHORITY_FAILURE:
			_feedback.text = "物品状态异常，请停止操作。"
		_:
			_feedback.text = "现在不能吃这个物品。"
	return last_result
