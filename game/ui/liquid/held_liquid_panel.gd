class_name HeldLiquidPanel
extends PanelContainer

## Session view, stable selected ID. Never owns content, water or source facts.
var _session: OldPineWorldSessionController
var _panel: PanelContainer
var _select: OptionButton
var _drink: Button
var _fill: Button
var _feedback: Label
var _ids: Array[StringName] = []
var last_result: LiquidUseResult


func configure(session: OldPineWorldSessionController) -> void:
	_session = session


func _ready() -> void:
	# Presentation must hide during Pause; gameplay remains Session-gated.
	_panel = self
	var rows: VBoxContainer = VBoxContainer.new()
	_panel.add_child(rows)
	var title: Label = Label.new()
	title.text = "随身酒袋 · 清水补给"
	rows.add_child(title)
	_select = OptionButton.new()
	_select.name = "LiquidInstance"
	_select.custom_minimum_size = Vector2(320, 36)
	rows.add_child(_select)
	_drink = Button.new()
	_drink.name = "Drink"
	_drink.text = "喝一份清水"
	_drink.custom_minimum_size.y = 40
	_drink.pressed.connect(request_drink)
	rows.add_child(_drink)
	_fill = Button.new()
	_fill.name = "Fill"
	_fill.text = "装满清水（倒掉现有内容）"
	_fill.custom_minimum_size.y = 40
	_fill.pressed.connect(request_fill)
	rows.add_child(_fill)
	_feedback = Label.new()
	_feedback.name = "Feedback"
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_feedback)
	_panel.hide()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_panel.visible = _session != null and _session.liquid_interaction_available() and not _session.combat_encounter_coordinator().has_active_encounter() and not _session.player_runtime().relationship.is_fighting()
	if not _panel.visible:
		return
	var ids: Array[StringName] = []
	var parent: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _session.player_runtime().character_id)
	for id: StringName in _session.inventory_state().direct_children(parent):
		if _session.liquid_collection().state(id) != null:
			ids.append(id)
	if ids != _ids:
		var previous: StringName = _selected_id()
		_ids = ids
		_select.clear()
		for id: StringName in _ids:
			_select.add_item(String(id))
			if id == previous:
				_select.select(_select.item_count - 1)
	for i: int in range(_ids.size()):
		var state: LiquidState = _session.liquid_collection().state(_ids[i])
		_select.set_item_text(i, "%s #%d · %s · %d/%d份" % [_item_name(_ids[i]), i + 1, LiquidState.content_name(state.content), state.remaining, _maximum_portions(_ids[i])])
	_drink.disabled = _ids.is_empty()
	if not _ids.is_empty():
		_drink.text = "饮用（酒精暂未开放）" if _session.liquid_collection().state(_selected_id()).content == LiquidState.Content.RED_WINE else "喝一份清水"
	_fill.visible = _session.fill_water_available()
	_fill.disabled = _ids.is_empty()



func _maximum_portions(id: StringName) -> int:
	var item: ItemInstance = _session.item_instance_index().resolve(id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	return 0 if content == null or content.liquid_definition() == null else content.liquid_definition().maximum_portions


func _selected_id() -> StringName:
	return &"" if _select.selected < 0 or _select.selected >= _ids.size() else _ids[_select.selected]


func request_drink() -> LiquidUseResult:
	return _use(false)


func request_fill() -> LiquidUseResult:
	return _use(true)


func _use(fill: bool) -> LiquidUseResult:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var context: MoneyInventoryContext = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), _session.inventory_state(), _session.stack_collection(), _session.item_instance_index())
	var definitions: NativeItemDefinitionProjections = GameContent.catalog().native_item_projections()
	var encounter: bool = _session.combat_encounter_coordinator().has_active_encounter()
	var vessel: String = _item_name(_selected_id())
	var held: LiquidState = _session.liquid_collection().state(_selected_id())
	var liquid_name: String = "" if held == null else LiquidState.content_name(held.content)
	last_result = HeldLiquidUseService.fill(player, context, _session.liquid_collection(), definitions, _selected_id(), _session.liquid_interaction_available(), _session.fill_water_available(), encounter) if fill else HeldLiquidUseService.drink(player, context, _session.liquid_collection(), definitions, _selected_id(), _session.liquid_interaction_available(), encounter)
	# feature/liquid.c do_drink() and do_fill(), in their words.
	match last_result.outcome:
		LiquidUseResult.Outcome.FILLED:
			_feedback.text = tr("你将%s装满清水。") % vessel
			if last_result.remaining_before > 0:
				_feedback.text = tr("你将%s里剩下的%s倒掉。") % [vessel, liquid_name] + "\n" + _feedback.text
		LiquidUseResult.Outcome.DRANK:
			_feedback.text = tr("你拿起%s咕噜噜地喝了几口%s。") % [vessel, liquid_name]
			if last_result.remaining_after == 0:
				_feedback.text += "\n" + tr("你已经将%s里的%s喝得一滴也不剩了。") % [vessel, liquid_name]
		LiquidUseResult.Outcome.ALCOHOL_DEFERRED:
			_feedback.text = "酒精饮用暂未开放；请到瀑布或水潭取水点换装清水。"
		LiquidUseResult.Outcome.TOO_FULL:
			_feedback.text = tr("你已经喝太多了，再也灌不下一滴水了。")
		LiquidUseResult.Outcome.EMPTY:
			# liquid.c has no full stop on this line.
			_feedback.text = tr("%s已经被喝得一滴也不剩了") % vessel
		LiquidUseResult.Outcome.NO_WATER_SOURCE:
			_feedback.text = tr("这里没有地方可以装水。")
		LiquidUseResult.Outcome.BUSY:
			_feedback.text = tr("你上一个动作还没有完成。")
		LiquidUseResult.Outcome.COMBAT_BLOCKED:
			_feedback.text = "战斗中暂不能装水或饮用。"
		LiquidUseResult.Outcome.AUTHORITY_FAILURE:
			_feedback.text = "物品状态异常，请停止操作。"
		_:
			_feedback.text = "现在不能使用这个酒袋。"
	return last_result


func _item_name(id: StringName) -> String:
	var item: ItemInstance = _session.item_instance_index().resolve(id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	return "" if content == null else content.display_name
