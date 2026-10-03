class_name CharacterPanel
extends VBoxContainer

## The character panel: 角色 (the score sheet SharedGameplayUI fills) and 武学
## (MartialArtsPage: skills, enabled skills and the player's own training).
var sheet: Label
var arts: MartialArtsPage
var sheet_tab: Button
var arts_tab: Button


func _init() -> void:
	name = "CharacterDetails"
	add_theme_constant_override("separation", 10)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	var group := ButtonGroup.new()
	sheet_tab = _tab(tabs, "SheetTab", "角色", group)
	arts_tab = _tab(tabs, "ArtsTab", "武学", group)
	sheet = Label.new()
	sheet.name = "Sheet"
	sheet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(sheet)
	arts = MartialArtsPage.new()
	add_child(arts)
	sheet_tab.pressed.connect(show_sheet)
	arts_tab.pressed.connect(show_arts)
	show_sheet()


func show_sheet() -> void:
	sheet_tab.button_pressed = true
	sheet.show()
	arts.hide()


func show_arts() -> void:
	arts_tab.button_pressed = true
	sheet.hide()
	arts.show()
	arts.refresh()


func arts_shown() -> bool:
	return arts.visible


func _tab(parent: Node, node_name: String, text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(80, 40)
	parent.add_child(button)
	return button
