class_name SnowOutdoorController
extends SnowResidentMapController

@onready var work_marker: Marker2D = $WorkplaceWork
@onready var work_panel: Control = $WorkUI/Panel
@onready var work_button: Button = $WorkUI/Panel/Rows/WorkButton
@onready var work_feedback: Label = $WorkUI/Panel/Rows/Feedback
var last_work_result: SnowWorkResult
@onready var bank_marker: Marker2D = $BankExchange
@onready var bank_panel: SnowBankExchangePanel = $BankUI/Panel
var last_bank_result: SnowBankInteractionResult


func _ready() -> void:
	super._ready()
	work_button.pressed.connect(request_work)
	work_panel.hide()
	bank_panel.conversion_requested.connect(request_bank_conversion)
	bank_panel.hide()


func _process(_delta: float) -> void:
	bank_panel.visible = can_exchange_here()
	if bank_panel.visible:
		var context: MoneyInventoryContext = bank_money_context()
		bank_panel.holdings.text = "直接携带（每种选定一堆）：\n铜钱 %s 文 / 银子 %s 两 / 黄金 %s 两" % [bank_amount_text(context, CurrencyDenomination.Value.COIN), bank_amount_text(context, CurrencyDenomination.Value.SILVER), bank_amount_text(context, CurrencyDenomination.Value.GOLD)]
	work_panel.visible = can_work_here()
	if work_panel.visible:
		($WorkUI/Panel/Rows/Resources as Label).text = "精 %d / 神 %d · 银子 %d 两" % [_player.state.essence.current, _player.state.spirit.current, silver_amount()]


func _physics_process(delta: float) -> void:
	# Editing a quantity must not move the character with cursor/selection keys.
	# Reuse the existing held-input quarantine; no new world freeze authority.
	if bank_panel.visible and (bank_panel.quantity.has_focus() or bank_panel.source.get_popup().visible or bank_panel.target.get_popup().visible):
		player_body.quarantine_current_movement_input()
	super._physics_process(delta)


func can_exchange_here() -> bool:
	return is_inside_tree() and _initialized and not get_tree().paused and player_body.player_controlled and _world_simulation_gate.is_open() and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not _player.relationship.is_fighting() and _player.world_location().map_id == map_id() and _player.world_location().zone_id == SnowWorldDefinitions.BANK_ZONE_ID and player_body.global_position.distance_squared_to(bank_marker.global_position) <= 96.0 * 96.0 and OldPineMapPlacementValidator.is_valid_character_position(self, SnowWorldDefinitions.BANK_ZONE_ID, player_body.global_position)


func bank_money_context() -> MoneyInventoryContext:
	return MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor), _inventory, _stacks, _item_index)


func bank_amount_text(context: MoneyInventoryContext, denomination: CurrencyDenomination.Value) -> String:
	var selected: CurrencyStackSelection = context.select(denomination)
	return "异常" if selected.outcome == CurrencyStackSelection.Outcome.AUTHORITY_FAILURE else str(selected.amount)


func request_bank_conversion(from: CurrencyDenomination.Value, to: CurrencyDenomination.Value, amount_text: String) -> SnowBankInteractionResult:
	last_bank_result = SnowBankInteractionResult.new()
	if not can_exchange_here():
		bank_panel.feedback.text = "现在无法在此兑换。"
		return last_bank_result
	var amount: int = SnowBankExchangePanel.positive_amount(amount_text)
	if amount < 1:
		last_bank_result.outcome = SnowBankInteractionResult.Outcome.INVALID_INPUT
		bank_panel.feedback.text = "请输入范围内的正整数，不支持小数或自动取整。"
		return last_bank_result
	last_bank_result.outcome = SnowBankInteractionResult.Outcome.CONVERSION
	last_bank_result.conversion = BankConversionService.convert(bank_money_context(), _item_id_allocator, _player.maximum_encumbrance, from, to, amount)
	bank_panel.show_conversion(last_bank_result.conversion)
	return last_bank_result


func can_work_here() -> bool:
	return is_inside_tree() and _initialized and not get_tree().paused and player_body.player_controlled and _world_simulation_gate.is_open() and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not _player.relationship.is_fighting() and _player.world_location().map_id == map_id() and _player.world_location().zone_id == SnowWorldDefinitions.WORKPLACE_ZONE_ID and player_body.global_position.distance_squared_to(work_marker.global_position) <= 96.0 * 96.0 and OldPineMapPlacementValidator.is_valid_character_position(self, SnowWorldDefinitions.WORKPLACE_ZONE_ID, player_body.global_position)


func request_work() -> SnowWorkResult:
	last_work_result = SnowWorkResult.new()
	if not can_work_here():
		last_work_result.outcome = SnowWorkResult.Outcome.INTERACTION_BLOCKED
		return last_work_result
	last_work_result = SnowWorkService.work(_player.state, _player.character_id, _player.maximum_encumbrance,
		_player.armor, _inventory, _stacks, _item_index, _item_id_allocator)
	match last_work_result.outcome:
		SnowWorkResult.Outcome.SUCCESS:
			work_feedback.text = "你完成了一份工作，得到一两银子。"
		SnowWorkResult.Outcome.TOO_TIRED:
			work_feedback.text = "你的精神太差了，现在不能工作。"
		SnowWorkResult.Outcome.DELIVERY_FAILED_CAPACITY:
			work_feedback.text = "工作已完成，但你负重过高，未能取得工钱。"
		_:
			work_feedback.text = "工作状态异常，请停止操作。"
			push_error("Snow work authority failure: %s" % last_work_result.outcome)
	return last_work_result


func silver_amount() -> int:
	var amount: int = 0
	for id: StringName in _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)):
		var item: ItemInstance = _item_index.resolve(id)
		if item != null and item.item_definition_id == SourceSilver.DEFINITION_ID and _stacks.has_stack(id):
			amount += _stacks.stack_state(id).amount
	return amount


func map_id() -> StringName:
	return SnowWorldDefinitions.OUTDOOR_MAP_ID


func default_spawn_id() -> StringName:
	return SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID


func local_passages() -> Array[PortalDefinition]:
	return [SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_RETURN_PORTAL_ID)]
