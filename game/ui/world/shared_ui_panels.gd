class_name SharedUiPanels
extends RefCounted
## Opening and filling the HUD's other panels: 观察 and a business's form in the shared
## frame; the menu's 角色 and 武学 pages (空识 and 游识 from there); closing the shared
## frame. The HUD is `_ui`.

# TRANSLATORS: asked before 空识神通 (void_sense.c) when its 50 gin ({gin}) would knock the player out.
const VOID_FAINT_WARNING: String = "空识神通要耗去 {gin} 点精，你现在撑不住，会当场昏过去。\n确定要施展吗？"
# TRANSLATORS: asked before 游识神通 goes to the one chosen (drift_sense.c) when its 30 gin ({gin}) would knock the player out.
const DRIFT_FAINT_WARNING: String = "游识神通要耗去 {gin} 点精，你现在撑不住，施展完就会昏过去。\n确定要施展吗？"
# TRANSLATORS: asked before a spell the player casts at themselves from the 武学 page ({spell}: 阴阳眼) when its {sen} sen would knock them out.
const SPELL_FAINT_WARNING: String = "施展{spell}要耗去 {sen} 点神，你现在撑不住，施展完就会昏过去。\n确定要施展吗？"

var _ui: SharedGameplayUI

# The HUD's authorities, read as SharedGameplayUI reads them.
var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


func refresh_panel_rows() -> void:
	_presentation_layout.refresh_rows()


func open_look() -> void:
	var zone: ZoneDefinition = _ui.card.current_zone()
	if zone == null or not _session.portable_inventory_available():
		return
	_presentation_layout.room.text = SharedUiMessageLog.room_prose(tr(zone.description)) + _ui.message_log.sky_line(zone)
	_presentation_layout.open_panel(tr(zone.display_name), _presentation_layout.room)


func open_business(title: String, form: Control, validate: Callable) -> void:
	if not _session.portable_inventory_available(): return
	_ui.message_log.business_feedback = ""
	_ui.message_log.open_panel_with_lines(title, form, validate)


## The menu on its 角色 page.
func open_character() -> void:
	if not _session.portable_inventory_available(): return
	_ui.menu.open(GameMenu.Tab.CHARACTER)


## The menu on its 武学 page.
func open_martial_arts() -> void:
	if not _session.portable_inventory_available(): return
	_ui.menu.open(GameMenu.Tab.MARTIAL_ARTS)


## Fills the shown page of 角色 and 武学.
func refresh_character() -> void:
	if _player == null:
		return
	_ui.character_sheet.refresh(_player, _session)
	if _ui.arts_page.is_visible_in_tree():
		_ui.arts_page.refresh()


## The menu on its 背包 page, on 补给 (food, drink, what heals): eaten and drunk from there.
func open_supplies() -> void:
	if not _session.portable_inventory_available(): return
	_ui.inventory_panel.show_section(InventorySections.Section.SUPPLIES)
	_ui.menu.open(GameMenu.Tab.INVENTORY)


## 空识神通 from the 武学 page; asked first when its gin would knock the player out.
## 取消 goes back to the page.
func conjure_void_sense() -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	if not magic.void_knocks_out():
		magic.void_sense()
		return
	_ui.questions.ask_danger(tr(VOID_FAINT_WARNING).format({"gin": VoidSenseConjure.GIN_COST}), "确定施展", magic.void_sense, magic.available, open_martial_arts)


## A spell cast at oneself from the 武学 page (阴阳眼); asked first when its sen would
## knock the player out. 取消 goes back to the page.
func cast_self(function_id: StringName) -> void:
	var arts: PlayerMartialArts = _session.martial_arts()
	if not arts.cast_self_knocks_out(function_id):
		arts.cast_self(function_id)
		return
	var spell: CastFunction = SpecialFunctions.cast(function_id)
	_ui.questions.ask_danger(tr(SPELL_FAINT_WARNING).format({"spell": tr(spell.self_label), "sen": spell.self_sen_cost(_player.state)}), "确定施展", arts.cast_self.bind(function_id), arts.available, open_martial_arts)


## 游识神通 from the 武学 page: conjure.c's and the file's checks, then its question with
## the names the player may go to; a refusal is only logged.
func open_drift_sense() -> void:
	if _session.essence_magic().drift_begin():
		_show_drift_question()


func _show_drift_question(lines: Array[ColoredLine] = []) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	_ui.drift_panel.show_names(magic.drift_names(), lines)
	_presentation_layout.open_panel(tr(DriftSenseConjure.LABEL), _ui.drift_panel, magic.available)


## A name answered: asked first when the 30 gin would knock the player out.
func drift_choose(npc_name: String) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	if magic.drift_knocks_out(npc_name):
		_ui.questions.ask_danger(tr(DRIFT_FAINT_WARNING).format({"gin": DriftSenseConjure.GIN_COST}), "确定施展", _drift_to.bind(npc_name), magic.available, _show_drift_question)
		return
	_drift_to(npc_name)


## select_target(): over, the question closes; nobody of that name now, it asks again.
## The menu closes first: the player goes elsewhere.
func _drift_to(npc_name: String) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	_ui.close_menu()
	if magic.drift_to(npc_name):
		if _presentation_layout._content == _ui.drift_panel:
			_presentation_layout.close_panel()
		return
	_show_drift_question(magic.last_lines)


func close_panel_of(panel: Control) -> void:
	if _presentation_layout._content == panel:
		_presentation_layout.close_panel()


## 中止施法 (an empty answer): its line, and back to the 武学 page.
func drift_cancel() -> void:
	_ui.message_log.append_log_lines([tr(DriftSenseConjure.CANCELLED)])
	open_martial_arts()


## Back on the shared frame closes its panel; with only the menu open, the menu.
func dismiss_current_panel() -> void:
	if not _presentation_layout.frame.visible and _ui.menu.is_presented():
		_ui.menu.close()
		return
	# A question in the interaction popup: Back is its 取消, one step back to where it was
	# asked (给予's page after an equipped gift's question).
	if _ui.interaction_open() and _presentation_layout.page() == _ui.confirm_prompt and _ui.is_asking():
		_ui.confirm_prompt.cancel()
		return
	var map := _session.active_map() as WorldMapController
	if map != null and map.dismiss_panel(_presentation_layout._content):
		_presentation_layout.validate_open_panel()
	else:
		_presentation_layout.close_panel()


func close_business(form: Control) -> void:
	if _presentation_layout._content == form:
		_presentation_layout.close_panel()
