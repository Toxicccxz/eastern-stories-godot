class_name VendorPanel
extends PanelContainer

## feature/vendor.c's goods as the player reads them: one button per good, and what the
## last `buy` did. VendorService gives it the goods' labels and acts on the one pressed.
signal purchase_requested(goods_key: String)

var goods_rows: VBoxContainer
var feedback: Label
var _title: Label
var _goods_buttons: Dictionary[String, Button] = {}


func _init() -> void:
	name = "Panel"
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	add_child(rows)
	_title = _label(rows, "Title")
	goods_rows = VBoxContainer.new()
	goods_rows.name = "Goods"
	rows.add_child(goods_rows)
	feedback = _label(rows, "Feedback")


func _label(rows: VBoxContainer, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(label)
	return label


## One button per good, in the vendor's order.
func build_goods(keys: Array[String]) -> void:
	for key: String in keys:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(func() -> void: purchase_requested.emit(key))
		goods_rows.add_child(button)
		_goods_buttons[key] = button


## The title and each good's label (goods key -> label), in the shown language.
func present(title: String, labels: Dictionary[String, String]) -> void:
	for key: String in labels:
		_goods_buttons[key].text = labels[key]
	_title.text = title


## What `buy` did with `goods_name` (in the shown language).
func show_purchase(result: VendorPurchaseResult, goods_name: String) -> void:
	if result.delivered:
		feedback.text = tr("已付款，%s已放入你的随身物品。") % goods_name
	elif result.paid:
		feedback.text = tr("已付款，但未收到%s。") % goods_name + (tr("负重过高。") if result.outcome == VendorPurchaseResult.Outcome.DELIVERY_FAILED else tr("物品状态异常，请停止操作。"))
	# buy.c: can_afford() 0 and 2.
	elif result.affordability != null and result.affordability.outcome == MoneyAffordabilityResult.Outcome.INSUFFICIENT_TOTAL:
		feedback.text = "你的钱不够。"
	elif result.affordability != null and result.affordability.outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED:
		feedback.text = "你没有足够的零钱，而对方也找不开...。"
	else:
		feedback.text = "交易未完成，状态异常；已发生的扣款不会退回。"
