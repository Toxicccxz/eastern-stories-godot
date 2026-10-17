class_name SharedUiInventory
extends RefCounted
## The 背包 and 拾取 panels: what they show, and what the player does with a carried
## thing (inspect, give, drop, put, play, apply, pour, take out, dissolve, scribe, attach,
## hang, wield, wear), with the questions some of them ask first. Code moved from
## SharedGameplayUI as it was; the HUD is `_ui`.

# TRANSLATORS: asked before 化尸粉 dissolves a corpse that still holds things (dust.c destructs it whole): {name} whose corpse, {count} how many things are in it.
const DISSOLVE_WARNING: String = "化尸粉会把{name}的尸体连同里面的 {count} 件物品一起化成一滩黄水，化掉的东西再也找不回来。\n确定要化掉吗？"
# TRANSLATORS: asked before the rope's 上吊 (rope.c hang_self(): die()): the character dies as in a fight.
const HANG_WARNING: String = "把绳子往脖子上一套，就是寻死：你会就此死去，和战死一样付出死亡的代价。\n确定要上吊吗？"
# TRANSLATORS: asked before 画符 (scribe.c, haunt.c) when its 40 神 ({sen}) would leave the player below zero: they faint.
const SCRIBE_FAINT_WARNING: String = "画这道符要耗去 {sen} 点神，你现在撑不住，会当场昏过去。\n确定要画吗？"
# TRANSLATORS: asked before 画符 (scribe.c) when the drop of blood it is drawn in (1 point of 气 off its effective value) would kill the badly wounded player.
const SCRIBE_DEATH_WARNING: String = "你伤得太重了：画符要咬破手指流血，这一点血就会要了你的命。\n确定要画吗？"
# TRANSLATORS: asked before a 僵尸追魂符 sends the player's zombie ({zombie}) after their own master ({master}): its kill counts as the player's (killer_reward()). {family}, {score}, {next} as in the 攻击 question.
const HAUNT_MASTER_WARNING: String = "{master}是你的师父。{zombie}会追杀{master}，它若得手，就算你弑师，等同背叛师门：\n· 被逐出{family}，门派、师父和称号都没有了。\n· 综合评价清零（现在是 {score}）。\n· 背叛师门的次数变成 {next} 次。\n确定要贴上这道符吗？"
## Owner (modern fixes II): giving away what the player has equipped, or a large sum
## (GIVE_MONEY_ASK_AT 文 or more), is asked first; give.c asks nothing. An NPC that
## takes bets or donations (the 宝官, the 功德箱's keeper) is not asked about money.
const GIVE_MONEY_ASK_AT: int = 10000
# TRANSLATORS: asked before 给 (give.c) of an item the player has equipped ({item}) to an NPC ({npc}).
const GIVE_EQUIPPED_WARNING: String = "{item}正装备在你身上。确定把它送给{npc}吗？送出去的东西一般就要不回来了。"
# TRANSLATORS: asked before 给 (give.c) of a large sum ({money}, e.g. 三两黄金) to an NPC ({npc}).
const GIVE_MONEY_WARNING: String = "确定把{money}送给{npc}吗？送出去的钱一般就要不回来了。"
## A gift the NPC answers with its recruit (d/city/npc/chen.c: 陈剑秋's letter) is asked first
## (owner, 京师 plan): the rule's own question, or, when a 拜师 request already waits on the NPC
## and it would take the player at once, the 拜师 question that change asks.
# TRANSLATORS: asked before a gift ({item}) to a master ({npc}) who will take the player as apprentice at once; {warning} is the 拜师 question (betrayal, first master or change of master).
const GIVE_RECRUITS_AT_ONCE: String = "{npc}收下{item}，就会当场收你为徒。\n{warning}"

var _ui: SharedGameplayUI
## The rows show_inventory() opens the 背包 page with.
var _opening_rows: Array[PlayerInventoryRowProjection] = []
## 给予's page in the interaction popup.
var give_panel: GivePanel

# The HUD's authorities, read as SharedGameplayUI reads them.
var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


func show_loot(title: String, rows: Array[WorldItemRowProjection]) -> void:
	close_inventory()
	_ui.loot_panel.show_loot(title, rows)
	_presentation_layout.open_panel(title, _ui.loot_panel)
	_presentation_layout.refresh_rows()


func close_loot() -> void:
	if _ui.loot_panel != null:
		_ui.loot_panel.close_loot()


func loot_is_open() -> bool:
	return _ui.loot_panel != null and _ui.loot_panel.is_open()


func loot_rows() -> Array[WorldItemRowProjection]:
	return [] if _ui.loot_panel == null else _ui.loot_panel.visible_rows()


## The menu on its 背包 page with these rows, filled once (a second fill in the same
## frame would leave the freed rows beside the new ones).
func show_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
	if _ui.menu.is_presented() and _ui.menu.current_tab() == GameMenu.Tab.INVENTORY:
		fill_inventory(rows)
		return
	_opening_rows = rows
	_ui.menu.open(GameMenu.Tab.INVENTORY)
	_opening_rows = []


## The 背包 page was shown: the rows show_inventory() was given, else the player's.
func fill_shown_page() -> void:
	if not _opening_rows.is_empty():
		fill_inventory(_opening_rows)
	elif _session != null and _session.is_initialized():
		fill_inventory(_session.player_inventory_rows())


## The 背包 page's rows and what each row may do here (the selected NPC, a container
## or corpse in reach), without opening anything.
func fill_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
	close_loot()
	var map: WorldMapController = (_session.active_map() as WorldMapController) if _session != null else null
	var give_target: String = ""
	var container: String = ""
	if map != null and map.can_handle_items():
		if map.selected_npc_takes_gifts():
			give_target = map.selected_npc().definition().display_name
		var container_id: StringName = map.container_in_reach()
		if not container_id.is_empty():
			container = map.floor_item_view(container_id).display_name
	_ui.inventory_panel.set_handling_targets(give_target, container)
	_ui.inventory_panel.set_dissolvable_corpse(map.dissolvable_corpse_name() if map != null and map.can_handle_items() else "")
	# scribe.c on a paper for the selected NPC; attach.c on the zombie here.
	var scribed: NpcRuntimeState = map.scribable_npc() if map != null and map.can_handle_items() else null
	var carrier: NpcRuntimeState = map.sheet_carrier() if map != null and map.can_handle_items() else null
	_ui.inventory_panel.set_spell_targets("" if scribed == null else scribed.definition().display_name, "" if carrier == null else carrier.definition().display_name)
	var pour_targets: Array = []
	if map != null and map.can_handle_items():
		for id: StringName in map.pour_targets():
			var held: ItemInstance = map.item_instance_index().resolve(id)
			var content: ItemContentDefinition = null if held == null else GameContent.catalog().item(held.item_definition_id)
			if content != null:
				pour_targets.append([id, content.display_name])
	_ui.inventory_panel.set_pour_targets(pour_targets)
	_ui.inventory_panel.show_inventory(rows)
	_ui.menu.refresh_rows()


func close_inventory() -> void:
	if _ui.inventory_panel != null:
		_ui.inventory_panel.close_inventory()


func inventory_is_open() -> bool:
	return _ui.inventory_panel != null and _ui.inventory_panel.is_open()


func inventory_rows() -> Array[PlayerInventoryRowProjection]:
	return [] if _ui.inventory_panel == null else _ui.inventory_panel.visible_rows()


func show_inventory_inspection(row: PlayerInventoryRowProjection) -> void:
	if _ui.inventory_panel != null:
		_ui.inventory_panel.show_inspection(row)


func open_inventory() -> void:
	if _session.portable_inventory_available():
		show_inventory(_session.player_inventory_rows())


func inspect_item(id: StringName) -> void:
	if not _session.portable_inventory_available(): return
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if row.item_instance_id == id:
			show_inventory_inspection(row)
			return
	open_inventory()


func give_item(id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var warning: String = _give_warning(map, id, amount)
	if warning.is_empty():
		map.give_to_selected(id, amount)
		return
	var give: Callable = func() -> void:
		map.give_to_selected(id, amount)
	# The question closes once the gift can no longer be made: the NPC walked away or is
	# no longer selected, the thing is gone, or the player cannot handle items now.
	var npc_id: StringName = map.selected_character_id()
	var still_valid: Callable = func() -> bool:
		return (
			_session.active_map() == map and map.selected_character_id() == npc_id
			and map.can_handle_items() and map.selected_npc_takes_gifts() and _carries(id)
		)
	# 取消 goes back to the 背包 the question came from.
	_ui.questions.ask_first(warning, "确定送出", give, still_valid, open_inventory)


## 给予 in the interaction popup (owner, 2026-10-17; DECISIONS「说话和交互」): its page lists
## what the player carries to tick; the 背包's questions show as warnings above 确认给予,
## which closes the popup and gives the ticked things one by one.
func open_give() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null or not _session.portable_inventory_available() or not map.can_handle_items() or not map.selected_npc_takes_gifts():
		return
	if give_panel == null:
		give_panel = GivePanel.new()
		give_panel.hide()
		_presentation_layout.holding.add_child(give_panel)
		give_panel.picks_changed.connect(_warn_gifts)
		give_panel.confirmed.connect(_give_picked)
	give_panel.reset()
	give_panel.fill(_session.player_inventory_rows())
	var npc_id: StringName = map.selected_character_id()
	var still_valid: Callable = func() -> bool:
		return _session.active_map() == map and map.selected_character_id() == npc_id and map.can_handle_items() and map.selected_npc_takes_gifts()
	# TRANSLATORS: the 给予 page's title: {npc} whom the player gives to.
	_presentation_layout.open_panel(tr("给予 · {npc}").format({"npc": tr(map.selected_npc().definition().display_name)}), give_panel, still_valid)


## The ticked gifts' questions (an equipped thing, a large sum, a letter that recruits at
## once), as the warnings above 确认给予.
func _warn_gifts() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null or give_panel == null:
		return
	var warnings: PackedStringArray = []
	for pick: Array in give_panel.picks():
		var warning: String = _give_warning(map, pick[0], pick[1])
		if not warning.is_empty():
			warnings.append(warning)
	give_panel.show_warning("\n".join(warnings))


## 确认给予: the popup closes, then each ticked thing is given (give.c, one by one, in the
## list's order) while the NPC still takes gifts: one that walked off or turned on the
## player gets no more.
func _give_picked(picks: Array) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	if _ui.interaction_open():
		_presentation_layout.close_frame()
	for pick: Array in picks:
		if not map.can_handle_items() or not map.selected_npc_takes_gifts():
			break
		if _carries(pick[0]):
			map.give_to_selected(pick[0], pick[1])


func _carries(id: StringName) -> bool:
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if row.item_instance_id == id:
			return true
	return false


func _give_warning(map: WorldMapController, id: StringName, amount: int) -> String:
	var npc: NpcRuntimeState = map.selected_npc()
	if npc == null:
		return ""
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if row.item_instance_id != id:
			continue
		var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
		if content == null:
			return ""
		var npc_name: String = tr(npc.definition().display_name)
		var rule: NpcObjectRule = map.gift_rule_for_selected(id, amount)
		if rule != null and not rule.ask.is_empty():
			return _ask_before_gift(rule, npc, content)
		if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE:
			return tr(GIVE_EQUIPPED_WARNING).format({"item": tr(content.display_name), "npc": npc_name})
		var given: int = amount if amount > 0 else row.amount
		var takes_money: bool = npc.definition().dealings().object_rules.any(
			func(each: NpcObjectRule) -> bool: return each.effect in NpcObjectRule.EFFECTS
		)
		if content.currency_base_value > 0 and not takes_money and given * content.currency_base_value >= GIVE_MONEY_ASK_AT:
			return tr(GIVE_MONEY_WARNING).format({"money": HeldItemFacts.counted(content, given), "npc": npc_name})
		return ""
	return ""


func _ask_before_gift(rule: NpcObjectRule, npc: NpcRuntimeState, content: ItemContentDefinition) -> String:
	var master: NpcDefinition = npc.definition()
	var teaching: NpcTeaching = master.teaching()
	var family: FamilyDefinition = null if teaching == null else GameContent.catalog().family(teaching.family_id)
	if rule.recruit and family != null and _player.apprenticeship_request.recruit_takes_at_once(_player.state, master):
		var change: String = TeacherPanel.family_change_warning(_player, master, tr(family.display_name))
		if not change.is_empty():
			return tr(GIVE_RECRUITS_AT_ONCE).format({"npc": tr(master.display_name), "item": tr(content.display_name), "warning": change})
	return tr(rule.ask)


func drop_item(id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.drop_item(id, amount)


func put_item(id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.put_in_container(id, amount)


func play_item(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.play_item(id)


func apply_item(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.apply_item(id)


func act_with_item(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.act_with_item(id)


func pour_item(id: StringName, container_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.pour_into(id, container_id)


func take_out_item(container_id: StringName, id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.take_from_carried_container(container_id, id)


func put_into_carried(id: StringName, amount: int, container_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.put_in_carried_container(id, amount, container_id)


func dissolve_with(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var count: int = map.dissolvable_corpse_contents()
	if count == 0:
		map.dissolve_selected_corpse(id)
		return
	var dissolve: Callable = func() -> void:
		if map.dissolve_selected_corpse(id):
			open_inventory()
	# 取消 goes back to the 背包 the question came from.
	_ui.questions.ask_first(tr(DISSOLVE_WARNING).format({"name": tr(map.dissolvable_corpse_name()), "count": count}), "确定化掉", dissolve, Callable(), open_inventory)


## 画符 on a 桃符纸 for the selected NPC; asked first when its cost would kill the player or
## knock them out. 取消 goes back to the 背包.
func scribe_on(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var warning: String = ""
	if map.scribe_kills():
		warning = tr(SCRIBE_DEATH_WARNING)
	elif map.scribe_knocks_out():
		warning = tr(SCRIBE_FAINT_WARNING).format({"sen": ScribeService.SEN_COST + HauntScribe.SEN_COST})
	if warning.is_empty():
		map.scribe_on(id)
		return
	var scribe: Callable = func() -> void:
		map.scribe_on(id)
	_ui.questions.ask_first(warning, "确定画符", scribe, Callable(), open_inventory)


## 贴符 on the zombie here; asked first when it would go after the player's own master
## (its kill is the player's: 弑师, as 攻击 asks). 取消 goes back to the 背包.
func attach_sheet(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var target: NpcRuntimeState = map.sheet_target(id)
	var carrier: NpcRuntimeState = map.sheet_carrier()
	if target == null or carrier == null or not PlayerKillerReward.is_own_master(_player.state, target.definition()):
		map.attach_sheet(id)
		return
	var teaching: NpcTeaching = target.definition().teaching()
	var family: FamilyDefinition = GameContent.catalog().family(teaching.family_id)
	var attach: Callable = func() -> void:
		map.attach_sheet(id)
	_ui.questions.ask_first(tr(HAUNT_MASTER_WARNING).format({
		"master": tr(target.definition().display_name), "zombie": tr(carrier.definition().display_name),
		"family": tr(family.display_name) if family != null else "",
		"score": _player.state.progression.score, "next": _player.state.apprenticeship.betrayer_count + 1,
	}), "确定贴符", attach, Callable(), open_inventory)


## rope.c hang: deadly, so asked first (owner); 取消 goes back to the 背包. Outdoors
## the rope finds nothing to hang from, so there is nothing to ask.
func hang_with(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	if not map.can_hang_here():
		map.hang_with(id)
		return
	var hang: Callable = func() -> void:
		map.hang_with(id)
	_ui.questions.ask_first(tr(HANG_WARNING), "确定上吊", hang, Callable(), open_inventory)


func wield_item(id: StringName) -> void:
	_session.wield_player_item(id)
	open_inventory()


func unwield_item(id: StringName) -> void:
	_session.unwield_player_item(id)
	open_inventory()


func wear_item(id: StringName) -> void:
	var result: OldPineArmorInteractionResult = _session.wear_player_item(id)
	if result != null and result.outcome == OldPineArmorInteractionResult.Outcome.FEMALE_ONLY:
		# wear.c's line, or the item's own wear() (d/latemoon/obj/skirt.c).
		var item: ItemInstance = _session.item_instance_index().resolve(id)
		var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
		if content != null and not content.wear_refusal.is_empty():
			_ui.message_log.append_log_lines([tr(content.wear_refusal).strip_edges()])
		else:
			_ui.message_log.append_log_lines([tr("这是女人的衣衫，你一个大男人也想穿，羞也不羞？")])
	open_inventory()


func remove_item(id: StringName) -> void:
	_session.remove_player_item(id)
	open_inventory()
