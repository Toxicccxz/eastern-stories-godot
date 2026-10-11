class_name SharedUiPanels
extends RefCounted
## Opening and filling the HUD's other panels: 观察, 角色 and its 武学 page (空识 and
## 游识 from there), 随身补给, a business's form, and closing the shared frame. Code moved
## from SharedGameplayUI as it was; the HUD is `_ui`.
##
## Seam for the tabbed menu (not built yet): each of the menu's panels opens only through
## an open_* here or in SharedUiInventory / SharedUiMessageLog; the tabs (角色, 武学, 背包,
## 任务, 声望, 系统) will call them in place of SharedGameplayLayout's navigation row.

# TRANSLATORS: asked before 空识神通 (void_sense.c) when its 50 gin ({gin}) would knock the player out.
const VOID_FAINT_WARNING: String = "空识神通要耗去 {gin} 点精，你现在撑不住，会当场昏过去。\n确定要施展吗？"
# TRANSLATORS: asked before 游识神通 goes to the one chosen (drift_sense.c) when its 30 gin ({gin}) would knock the player out.
const DRIFT_FAINT_WARNING: String = "游识神通要耗去 {gin} 点精，你现在撑不住，施展完就会昏过去。\n确定要施展吗？"

var _ui: SharedGameplayUI
var _food: HeldFoodPanel
var _liquid: HeldLiquidPanel
var _supplies: VBoxContainer

# The HUD's authorities, read as SharedGameplayUI reads them.
var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


func initialize_supplies() -> void:
	if _supplies != null:
		return
	_supplies = VBoxContainer.new()
	_supplies.name = "Supplies"
	_presentation_layout.holding.add_child(_supplies)
	_food = HeldFoodPanel.new()
	_food.name = "HeldFoodUI"
	_food.configure(_session)
	_supplies.add_child(_food)
	_liquid = HeldLiquidPanel.new()
	_liquid.name = "HeldLiquidUI"
	_liquid.configure(_session)
	_supplies.add_child(_liquid)
	var hint := Label.new()
	hint.text = "补给仅使用直接携带的物品；取水仍须靠近当前地图的水源。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_supplies.add_child(hint)


func refresh_panel_rows() -> void:
	_presentation_layout.refresh_rows()


func open_look() -> void:
	var zone: ZoneDefinition = _ui.card.current_zone()
	if zone == null or not _session.portable_inventory_available():
		return
	_presentation_layout.room.text = SharedUiMessageLog.room_prose(tr(zone.description))
	_presentation_layout.open_panel(tr(zone.display_name), _presentation_layout.room)


func open_business(title: String, form: Control, validate: Callable) -> void:
	if not _session.portable_inventory_available(): return
	_ui.message_log.business_feedback = ""
	_ui.message_log.open_panel_with_lines(title, form, validate)


func open_character() -> void:
	if not _session.portable_inventory_available(): return
	refresh_character()
	_presentation_layout.open_panel("角色", _presentation_layout.character)


## The character panel on its 武学 page.
func open_martial_arts() -> void:
	open_character()
	if _presentation_layout.character.is_visible_in_tree():
		_presentation_layout.character.show_arts()


func martial_arts_page() -> MartialArtsPage:
	return _presentation_layout.character.arts


func refresh_character() -> void:
	var state := _player.state
	var attr := state.attributes
	# TRANSLATORS: the character sheet (score): name, gender, age, rank (rankd.c, 【 武  者 】) and title, then 精/气/神 as current / effective / maximum, food and water, experience, potential and the attributes.
	var lines: Array[String] = [tr("{name} · {gender} · {age}岁\n{rank}{title}\n\n当前 / 有效 / 最大\n精 {gin}\n气 {kee}\n神 {sen}\n\n食物 {food} · 饮水 {water}\n实战经验 {exp} · 潜能 {potential}（已用 {spent}）\n\n膂力 {str} · 胆识 {cor} · 悟性 {int} · 灵性 {spi}\n定力 {cps} · 容貌 {per} · 根骨 {con} · 福缘 {kar}\n").format({
		"name": _player.facts.display_name, "gender": tr(state.gender), "age": _player.facts.age, "title": _player.shown_title(),
		"rank": tr(RankWords.query_rank(state.gender, state.affiliation.class_id, CrimeRecord.thief(state))),
		"gin": _resource_text(state.essence), "kee": _resource_text(state.vitality), "sen": _resource_text(state.spirit),
		"food": state.recovery.food, "water": state.recovery.water, "exp": state.progression.combat_experience,
		"potential": state.progression.potential, "spent": state.progression.potential_spent,
		"str": attr.strength, "cor": attr.courage, "int": attr.intelligence, "spi": attr.spirituality,
		"cps": attr.composure, "per": attr.personality, "con": attr.constitution, "kar": attr.karma,
	})]
	# TRANSLATORS: the character sheet, score.c's 灵力 (atman) and 法力 (mana), each current / maximum.
	lines.append(tr("灵力 {atman} / {max_atman} · 法力 {mana} / {max_mana}").format({
		"atman": state.recovery.atman.current, "max_atman": state.recovery.atman.maximum,
		"mana": state.recovery.mana.current, "max_mana": state.recovery.mana.maximum,
	}))
	# TRANSLATORS: the character sheet, score.c's lines: 杀气 (bellicosity), 综合评价 (score) and the NPCs the player has killed.
	lines.append(tr("杀气 {bellicosity} · 综合评价 {score}\n总共杀过 {kills} 个人。").format({
		"bellicosity": attr.bellicosity, "score": state.progression.score, "kills": state.progression.kills,
	}))
	if state.quest.has_task():
		lines.append("\n".join(QuestStatus.lines(state.quest)))
	lines.append(tr("负重 {carried} / {capacity} · 体重 {weight}").format({
		"carried": _session.inventory_state().contents_weight(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)),
		"capacity": _player.maximum_encumbrance, "weight": _player.body_facts.body_weight,
	}))
	_presentation_layout.character.sheet.text = "\n".join(lines)
	if _presentation_layout.character.arts_shown():
		_presentation_layout.character.arts.refresh()


func _resource_text(resource: CharacterResourceState) -> String:
	return "%d / %d / %d" % [resource.current, resource.effective, resource.maximum]


func open_supplies() -> void:
	if not _session.portable_inventory_available() or _supplies == null: return
	_food.show()
	_liquid.show()
	_presentation_layout.open_panel("随身补给", _supplies)


## 空识神通 from the 武学 page; asked first when its gin would knock the player out.
## 取消 goes back to the page.
func conjure_void_sense() -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	if not magic.void_knocks_out():
		magic.void_sense()
		return
	_ui.questions.ask_first(tr(VOID_FAINT_WARNING).format({"gin": VoidSenseConjure.GIN_COST}), "确定施展", magic.void_sense, magic.available, open_martial_arts)


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
		_ui.questions.ask_first(tr(DRIFT_FAINT_WARNING).format({"gin": DriftSenseConjure.GIN_COST}), "确定施展", _drift_to.bind(npc_name), magic.available, _show_drift_question)
		return
	_drift_to(npc_name)


## select_target(): over, the question closes; nobody of that name now, it asks again.
func _drift_to(npc_name: String) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
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


func dismiss_current_panel() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null and map.dismiss_panel(_presentation_layout._content):
		_presentation_layout.validate_open_panel()
	else:
		_presentation_layout.close_panel()


func close_business(form: Control) -> void:
	if _presentation_layout._content == form:
		_presentation_layout.close_panel()
