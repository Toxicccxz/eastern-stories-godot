class_name ShopFrontPanel
extends PanelContainer

## A keeper's own list and buy (NpcShopFront, shen.c) as the player reads them:
## what list writes, a 购买 button, and the keeper's answer. ShopFrontService gives it
## the lines.
signal buy_requested

var listing: Label
var answer: Label
var buy_button: Button


func _init() -> void:
	name = "Panel"
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)
	listing = Label.new()
	listing.name = "Listing"
	listing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(listing)
	buy_button = Button.new()
	buy_button.name = "Buy"
	buy_button.text = "购买"
	buy_button.custom_minimum_size = Vector2(0, 44)
	buy_button.pressed.connect(func() -> void: buy_requested.emit())
	rows.add_child(buy_button)
	answer = Label.new()
	answer.name = "Answer"
	answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(answer)


## list's lines; the last answer is cleared.
func show_listing(lines: Array[String]) -> void:
	listing.text = "\n".join(lines)
	answer.text = ""


## buy's lines.
func show_answer(lines: Array[String]) -> void:
	answer.text = "\n".join(lines)
