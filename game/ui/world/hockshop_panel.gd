class_name HockshopPanel
extends PanelContainer

## inherit HOCKSHOP (d/snow/hockshop.c) as the player reads it: the money carried, one
## button per carried thing, 估价 and 卖断… with the sale's question, and what the last act
## did. HockshopService fills it and acts on what the player asks.
signal item_selected(id: StringName)
signal value_requested
signal sell_requested
signal sale_confirmed
signal sale_cancelled
signal close_requested

const NO_SELECTION: String = "请选择随身物品。"

var title: Label
var holdings: Label
var selection: Label
var feedback: Label
var value_button: Button
var sell_button: Button
## Asks before a sale (ConfirmPrompt); its confirm button is `confirm_button`.
var sale_prompt: ConfirmPrompt
var confirm_button: Button
var _rows: VBoxContainer
var _goods: VBoxContainer
var _actions: HBoxContainer


func _init() -> void:
	name = "Panel"
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.09, 0.085, 1)
	for side: String in ["left", "right", "top", "bottom"]:
		background.set("content_margin_" + side, 12.0)
	add_theme_stylebox_override("panel", background)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	add_child(_rows)
	title = _label("", "Title")
	holdings = _label("", "Holdings")
	_goods = VBoxContainer.new()
	_goods.name = "Goods"
	_rows.add_child(_goods)
	selection = _label(NO_SELECTION, "Selection")
	_actions = HBoxContainer.new()
	_rows.add_child(_actions)
	value_button = _button(_actions, "Value", "估价", func() -> void: value_requested.emit())
	sell_button = _button(_actions, "Sell", "卖断…", func() -> void: sell_requested.emit())
	sale_prompt = ConfirmPrompt.new()
	sale_prompt.name = "SaleConfirm"
	sale_prompt.hide()
	_rows.add_child(sale_prompt)
	confirm_button = sale_prompt.confirm_button
	sale_prompt.confirmed.connect(func() -> void: sale_confirmed.emit())
	sale_prompt.cancelled.connect(func() -> void: sale_cancelled.emit())
	feedback = _label("", "Feedback")
	_button(_rows, "Close", "关闭", func() -> void: close_requested.emit())


func _label(text: String, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	return label


func _button(parent: Node, node_name: String, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## One button per carried thing that may be valued (`labels[i]` names `ids[i]`).
func show_goods(ids: Array[StringName], labels: Array[String]) -> void:
	for child: Node in _goods.get_children():
		_goods.remove_child(child)
		child.queue_free()
	for i: int in range(ids.size()):
		var id: StringName = ids[i]
		var button: Button = _button(_goods, "Item%d" % i, labels[i], func() -> void: item_selected.emit(id))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## What may be pressed now: 估价, 卖断… and the carried things.
func enable(can_value: bool, can_sell: bool, can_pick: bool) -> void:
	value_button.disabled = not can_value
	sell_button.disabled = not can_sell
	for child: Node in _goods.get_children():
		(child as Button).disabled = not can_pick


## The chosen thing's label; none chosen, the hint.
func show_selection(label: String) -> void:
	selection.text = NO_SELECTION if label.is_empty() else label


## The sale's question in place of the selection and its buttons (the question names the item).
func ask_sale(question: String) -> void:
	sale_prompt.ask(question, "确认卖断（不可撤销）")
	selection.hide()
	_actions.hide()


## The question gone: the selection and its buttons again.
func end_sale() -> void:
	sale_prompt.dismiss()
	selection.show()
	_actions.show()


static func valuation_text(result: HockshopValuationResult) -> String:
	if result.outcome == HockshopValuationResult.Outcome.SELLABLE:
		return TranslationServer.translate("价值{value}文 · 卖断可得{payout}文（以实际交付为准）。").format({
			"value": result.source_value, "payout": result.actual_payout,
		})
	if result.outcome == HockshopValuationResult.Outcome.WORTHLESS:
		return TranslationServer.translate("一文不值，不能卖断。")
	return TranslationServer.translate("物品已变化或现在不可交易，请重新选择。")


static func sell_text(result: HockshopSellResult) -> String:
	var delivered: int = 0 if result.payout == null else result.payout.delivered_value
	if result.outcome == HockshopSellResult.Outcome.SOLD:
		if delivered < result.valuation.actual_payout:
			return TranslationServer.translate("卖断完成，物品已移除；实际收到%d文。部分钱款因负重不足未能交付，已销毁，不会补发或退款。") % delivered
		return TranslationServer.translate("卖断完成，物品已移除；实际收到%d文。") % delivered
	if result.outcome == HockshopSellResult.Outcome.AUTHORITY_FAILURE:
		return TranslationServer.translate("交易技术异常（阶段{stage}），请停止操作。已交付{delivered}文；物品与钱款以当前实际状态为准，未回滚，请勿重复尝试。").format({
			"stage": result.stage, "delivered": delivered,
		})
	return TranslationServer.translate("卖断未执行，物品状态已变化；请重新选择。")
