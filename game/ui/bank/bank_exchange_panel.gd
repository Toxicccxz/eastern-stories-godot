class_name BankExchangePanel
extends PanelContainer

## d/snow/bank.c `convert`: pay one currency, receive another.
signal conversion_requested(from: CurrencyDenomination.Value, to: CurrencyDenomination.Value, amount_text: String)

var title: Label
var source: OptionButton
var target: OptionButton
var quantity: LineEdit
var holdings: Label
var feedback: Label


func _init() -> void:
	name = "Panel"
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)
	title = _label(rows, "Title", "")
	holdings = _label(rows, "Holdings", "")
	_label(rows, "SourceLabel", "支付货币")
	source = _selector(rows, "Source")
	_label(rows, "TargetLabel", "取得货币")
	target = _selector(rows, "Target")
	quantity = LineEdit.new()
	quantity.name = "Quantity"
	quantity.custom_minimum_size = Vector2(0, 40)
	quantity.text = "1"
	quantity.placeholder_text = "支付数量（正整数）"
	rows.add_child(quantity)
	var convert: Button = Button.new()
	convert.name = "Convert"
	convert.custom_minimum_size = Vector2(0, 48)
	convert.text = "兑换"
	rows.add_child(convert)
	feedback = _label(rows, "Feedback", "请选择货币与数量。同币种亦可兑换。")
	source.select(1)
	target.select(0)
	convert.pressed.connect(_submit)
	quantity.text_submitted.connect(func(_text: String) -> void: _submit())


func _label(rows: VBoxContainer, node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(label)
	return label


func _selector(rows: VBoxContainer, node_name: String) -> OptionButton:
	var selector: OptionButton = OptionButton.new()
	selector.name = node_name
	selector.custom_minimum_size = Vector2(0, 40)
	selector.add_item("铜钱 · 文", CurrencyDenomination.Value.COIN)
	selector.add_item("银子 · 两", CurrencyDenomination.Value.SILVER)
	selector.add_item("黄金 · 两", CurrencyDenomination.Value.GOLD)
	rows.add_child(selector)
	return selector


func _submit() -> void:
	quantity.release_focus()
	conversion_requested.emit(source.get_selected_id() as CurrencyDenomination.Value,
		target.get_selected_id() as CurrencyDenomination.Value, quantity.text)


## Strict decimal input, checked before conversion. No float/SpinBox rounding,
## sign/coercion, clamping, or overflowing String.to_int(). Zero rejects too.
static func positive_amount(text: String) -> int:
	if text.is_empty(): return -1
	var amount: int = 0
	for digit: String in text:
		if digit < "0" or digit > "9": return -1
		var value: int = digit.unicode_at(0) - 48
		if amount > 922337203685477580 or (amount == 922337203685477580 and value > 7): return -1
		amount = amount * 10 + value
	return amount if amount > 0 else -1


func show_conversion(result: BankConversionResult) -> void:
	match result.outcome:
		BankConversionResult.Outcome.SUCCESS:
			feedback.text = tr("兑换成功：扣除 {paid}，取得 {received}。").format({"paid": result.source_quantity, "received": result.target_quantity})
		BankConversionResult.Outcome.DELIVERY_FAILED:
			feedback.text = "负重过高，兑换未交付：原币已扣除，未收到目标货币；未交付物品已清理，无退款。"
		BankConversionResult.Outcome.SOURCE_MISSING:
			feedback.text = "你没有直接携带这种货币。"
		BankConversionResult.Outcome.INSUFFICIENT_SOURCE:
			feedback.text = "所选货币数量不足。"
		BankConversionResult.Outcome.ROUNDED_TO_ZERO:
			feedback.text = "数量不足以兑换一单位目标货币。"
		BankConversionResult.Outcome.INVALID_QUANTITY:
			feedback.text = "请输入有效的正整数。"
		_:
			feedback.text = "兑换状态异常，请停止操作。"
			push_error("Bank conversion outcome=%d stage=%d" % [result.outcome, result.stage])
