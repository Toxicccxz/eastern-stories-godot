class_name SnowBankExchangePanel
extends PanelContainer

signal conversion_requested(from: CurrencyDenomination.Value, to: CurrencyDenomination.Value, amount_text: String)

@onready var source: OptionButton = $Rows/Source
@onready var target: OptionButton = $Rows/Target
@onready var quantity: LineEdit = $Rows/Quantity
@onready var holdings: Label = $Rows/Holdings
@onready var feedback: Label = $Rows/Feedback


func _ready() -> void:
	for selector: OptionButton in [source, target]:
		selector.add_item("铜钱 · 文", CurrencyDenomination.Value.COIN)
		selector.add_item("银子 · 两", CurrencyDenomination.Value.SILVER)
		selector.add_item("黄金 · 两", CurrencyDenomination.Value.GOLD)
	source.select(1)
	target.select(0)
	$Rows/Convert.pressed.connect(_submit)
	quantity.text_submitted.connect(func(_text: String) -> void: _submit())


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
			feedback.text = "兑换成功：扣除 %d，取得 %d。" % [result.source_quantity, result.target_quantity]
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
			push_error("Snow bank conversion outcome=%d stage=%d" % [result.outcome, result.stage])
