class_name BankService
extends WorldService

## inherit BANK (d/snow/bank.c): `convert` between directly carried currencies.
var panel: BankExchangePanel
var last_result: SnowBankInteractionResult


func setup(p_map: WorldMapController, p_definition: ServiceDefinition, p_point: WorldServicePoint) -> void:
	super.setup(p_map, p_definition, p_point)
	panel = BankExchangePanel.new()
	panel.hide()
	_present()
	panel.conversion_requested.connect(request_conversion)
	ui_layer().add_child(panel)


func verb() -> String:
	return tr("兑换")


func interact() -> void:
	if in_reach():
		_present()
		open_panel(context_title(), panel)


## The title in the shown language, put together again on each opening.
func _present() -> void:
	var zone: ZoneDefinition = GameContent.catalog().zone(definition.zone_id)
	panel.title.text = tr("%s · 兑换（非存取款）") % tr(zone.display_name)


func _process(_delta: float) -> void:
	if panel.visible and not in_reach():
		panel.hide()
	if panel.visible:
		var context: MoneyInventoryContext = money_context()
		panel.holdings.text = tr("直接携带（每种选定一堆）：\n铜钱 {coins} 文 / 银子 {silver} 两 / 黄金 {gold} 两").format({
			"coins": amount_text(context, CurrencyDenomination.Value.COIN),
			"silver": amount_text(context, CurrencyDenomination.Value.SILVER),
			"gold": amount_text(context, CurrencyDenomination.Value.GOLD),
		})


func _physics_process(_delta: float) -> void:
	# Editing a quantity must not move the character with cursor/selection keys.
	if panel.visible and (panel.quantity.has_focus() or panel.source.get_popup().visible or panel.target.get_popup().visible):
		map.player_body.quarantine_current_movement_input()


func money_context() -> MoneyInventoryContext:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	return MoneyInventoryContext.new(
		ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor),
		map.inventory_state(), map.stack_collection(), map.item_instance_index(),
	)


static func amount_text(context: MoneyInventoryContext, denomination: CurrencyDenomination.Value) -> String:
	var selected: CurrencyStackSelection = context.select(denomination)
	return TranslationServer.translate("异常") if selected.outcome == CurrencyStackSelection.Outcome.AUTHORITY_FAILURE else str(selected.amount)


func request_conversion(from: CurrencyDenomination.Value, to: CurrencyDenomination.Value, amount_text: String) -> SnowBankInteractionResult:
	last_result = SnowBankInteractionResult.new()
	if not in_reach():
		panel.feedback.text = "现在无法在此兑换。"
		return last_result
	var amount: int = BankExchangePanel.positive_amount(amount_text)
	if amount < 1:
		last_result.outcome = SnowBankInteractionResult.Outcome.INVALID_INPUT
		panel.feedback.text = "请输入范围内的正整数，不支持小数或自动取整。"
		return last_result
	last_result.outcome = SnowBankInteractionResult.Outcome.CONVERSION
	last_result.conversion = BankConversionService.convert(money_context(), map.item_id_allocator(), map.player_runtime().maximum_encumbrance, from, to, amount)
	panel.show_conversion(last_result.conversion)
	return last_result
