class_name SharedUiContextActions
extends RefCounted
## The HUD's context buttons on the selected thing: 查看, 攻击, 切磋, 打听, 通行, 拾取,
## 驱尸, 疗伤他人, 心识, 偷窃 and 行贿, with the questions some of them ask first, and the
## place's own context action. Code moved from SharedGameplayUI as it was; the HUD is `_ui`.

# TRANSLATORS: asked before 切磋 when the player or the NPC ({npc}) holds a weapon: a blow from it wounds as in a real fight (combatd.c).
const ARMED_SPAR_WARNING: String = "刀剑无眼：有人手持兵刃时，切磋中挨的刀剑会留下真伤，伤重了一样会丧命。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before 切磋 with an NPC ({npc}) whose answer to a spar is a fight to the death (accept_fight() calls kill_ob()).
const DEADLY_SPAR_WARNING: String = "{npc}不会只跟你点到为止：这一场切磋会变成生死相搏。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before a bare-handed 切磋 with an NPC ({npc}) clearly stronger than the player (native, owner A10): one blow can knock the player out.
const STRONGER_SPAR_WARNING: String = "{npc}看起来比你强得多：即使只是切磋，一招就可能把你打昏。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before 切磋 with a weapon in hand on either side and an NPC ({npc}) clearly stronger than the player (native, owner A10).
const ARMED_STRONGER_SPAR_WARNING: String = "{npc}看起来比你强得多，而且有人手持兵刃：切磋中挨的刀剑会留下真伤，伤重了一样会丧命。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before 驱尸 (animate.c) when its 30 神 ({sen}) would leave the player below zero: they faint.
const ANIMATE_FAINT_WARNING: String = "施法驱尸要耗去 {sen} 点神，你现在撑不住，会当场昏过去。\n确定要施法吗？"
# TRANSLATORS: the 疗伤他人 button's tooltip (lotusforce/lifeheal.c): 150 force, which must be 150 above the maximum; neither side in a fight.
const LIFEHEAL_HINT: String = "运功「疗伤他人」：把真气输入对方体内，为他疗伤（耗 150 点内力，内力须比最大内力多 150 以上；双方都不能在战斗中）。"
# TRANSLATORS: the 心识神通 button's tooltip (essencemagic/heart_sense.c): its 50 atman and 30 sen; random(max_atman) must be above 100, else the caster falls unconscious.
const HEART_SENSE_HINT: String = "施展「心识神通」：救醒昏迷的人（50 灵力、30 神）。最大灵力不过 101 必定失败，失败时你自己会昏倒。"
# TRANSLATORS: asked before every 心识神通 (heart_sense.c), which knocks the caster out when it fails: {npc} the one lying unconscious, {atman} and {sen} its cost, {max_atman} the player's maximum atman, {odds} one of the three lines below.
const HEART_SENSE_WARNING: String = "心识神通要耗去 {atman} 点灵力和 {sen} 点神。能否救醒{npc}，全看你的灵力修为（最大灵力 {max_atman}）：{odds}\n确定要施展吗？"
# TRANSLATORS: {odds} in the 心识神通 question when the player's maximum atman is 101 or less (random(max_atman) > 100 cannot happen).
const HEART_SURE_FAIL: String = "最大灵力不过 101 必定失败，失败时你自己会当场昏过去。"
# TRANSLATORS: {odds} in the 心识神通 question: {percent} the chance in a hundred that random(max_atman) is 100 or less.
const HEART_MAY_FAIL: String = "约有 {percent}% 的机会失败，失败时你自己会当场昏过去。"
# TRANSLATORS: {odds} in the 心识神通 question when its 30 sen alone would knock the player out.
const HEART_SPENT: String = "你现在的神撑不住这一下，无论成败都会当场昏过去。"
# TRANSLATORS: the 偷窃 button's tooltip (cmds/std/steal.c): caught at it, the one robbed fights to the death and the town's constables know the player for a thief.
const STEAL_HINT: String = "偷窃：从对方身上偷一样东西（三秒后见分晓）。失手被发现，对方会和你拼命，城里的巡捕也会把你当贼抓。"
# TRANSLATORS: the 行贿 button's tooltip (yamen_po.c accept_bribery()): money to the constable leading the player.
const BRIBE_HINT: String = "行贿：塞钱给押着你的巡捕，钱给够了他就放你走；给少了反倒罪加一等。"
# TRANSLATORS: asked before 偷窃 from an NPC ({npc}) clearly stronger than the player (plan default, A10): one caught at it is attacked to the death (steal.c kill_ob()).
const STRONGER_STEAL_WARNING: String = "{npc}看起来比你强得多：要是失手被发现，{npc}会和你拼个你死我活。\n确定要下手吗？"
# TRANSLATORS: the 驱尸 button's tooltip: animate.c's 50 mana and 30 sen; the zombie lives on the player's 灵力 (zombie.c heal_up()).
const ANIMATE_HINT: String = "施法「驱尸」：让这具尸体站起来跟着你（50 法力、30 神）。僵尸靠吸你的灵力维持，灵力不足时就会倒下化为血水。"

var _ui: SharedGameplayUI

# The HUD's authorities, read as SharedGameplayUI reads them.
var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player
var _bound_map: WorldResidentMapController:
	get: return _ui._bound_map


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


## In the interaction popup every act is confirmed on its page first (owner, 2026-10-17;
## DECISIONS「说话和交互」): `about` what it is, `question` and `choice`; 确认 closes the
## popup with the act. Elsewhere `act` runs at once.
func confirm_in_popup(question: String, choice: String, act: Callable, still_valid: Callable = Callable(), about: String = "") -> void:
	if _ui.interaction_open():
		_ui.questions.ask_first(question, choice, act, still_valid, Callable(), about)
	else:
		act.call()


## How strong `npc` looks to the player (RelativeStrength), for a confirm page.
func _strength_of(npc: NpcRuntimeState) -> String:
	if npc == null or _player == null:
		return ""
	var line: String = RelativeStrength.line(_player.state.progression.combat_experience, npc.character_state.progression.combat_experience)
	return "" if line.is_empty() else tr(line).format({"pronoun": tr(Es2CombatMessages.pronoun(npc.character_state.gender))})


## The map's door or service at the player's spot, as the context button text.
func context_title() -> String:
	var map := _bound_map as WorldMapController
	if map == null or not _session.portable_inventory_available():
		return ""
	return map.interaction_title()


func open_current_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null and _session.portable_inventory_available():
		map.interact()


## 驱尸 on the selected corpse; asked first when its 30 sen would knock the player out.
func animate_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var still: Callable = func() -> bool: return map.animatable_corpse() != null
	if not map.animate_knocks_out():
		# TRANSLATORS: the interaction popup's confirm page before 驱尸 (animate.c).
		confirm_in_popup(tr("确定施法驱尸吗？"), "确定施法", map.animate_selected_corpse, still, tr(ANIMATE_HINT))
		return
	_ui.questions.ask_first(tr(ANIMATE_FAINT_WARNING).format({"sen": AnimateSpell.SEN_COST}), "确定施法", map.animate_selected_corpse, still, Callable(), tr(ANIMATE_HINT) if _ui.interaction_open() else "")


## exert lifeheal <the selected NPC> (疗伤他人): it costs only force, so it asks only on
## the popup's confirm page.
func lifeheal_context() -> void:
	var map := _session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null if map == null else map.selected_npc_here()
	if npc == null:
		return
	# TRANSLATORS: the interaction popup's confirm page before 疗伤他人 (lifeheal.c) on {npc}.
	confirm_in_popup(tr("确定为{npc}运功疗伤吗？").format({"npc": tr(npc.definition().display_name)}), "确定运功",
		func() -> void: _session.martial_arts().exert_at(&"lifeheal", npc),
		func() -> bool: return map.selected_npc_here() == npc, tr(LIFEHEAL_HINT))


## 心识神通 on the selected NPC lying unconscious: asked first whenever it goes ahead, as
## a failure knocks the player out (owner's rule; DECISIONS 山烟寺 A). A refusal (too little
## atman, busy, a no_magic room) asks nothing.
func heart_sense_context() -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	var npc: NpcRuntimeState = magic.heart_target()
	if npc == null:
		return
	if not magic.heart_asks():
		magic.heart_sense()
		return
	var state: CharacterState = _player.state
	var odds: String = tr(HEART_SPENT)
	if state.spirit.current >= HeartSenseConjure.SEN_COST:
		var percent: int = HeartSenseConjure.faint_percent(state.recovery.atman.maximum)
		odds = tr(HEART_SURE_FAIL) if percent >= 100 else tr(HEART_MAY_FAIL).format({"percent": percent})
	var question: String = tr(HEART_SENSE_WARNING).format({
		"atman": HeartSenseConjure.ATMAN_COST, "sen": HeartSenseConjure.SEN_COST, "npc": tr(npc.definition().display_name),
		"max_atman": state.recovery.atman.maximum, "odds": odds,
	})
	_ui.questions.ask_first(question, "确定施展", magic.heart_sense, func() -> bool: return magic.heart_target() == npc)


## 偷窃 on the selected NPC: the list of what it is seen to wear or wield, and 随手摸一样.
func steal_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null and map.thefts.can_steal_selected():
		_show_steal_question()


func _show_steal_question() -> void:
	var map := _session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null if map == null else map.selected_npc_here()
	if npc == null:
		return
	var ids: Array[StringName] = map.thefts.seen_items(npc)
	var names: Array[String] = []
	for id: StringName in ids:
		names.append(map.thefts.item_name(id))
	_ui.steal_panel.show_items(tr(npc.definition().display_name), ids, names)
	var npc_id: StringName = npc.character_id
	_presentation_layout.open_panel(tr("偷窃"), _ui.steal_panel, func() -> bool: return map.thefts.can_steal_selected() and map.selected_character_id() == npc_id)
	_presentation_layout.refresh_rows()


## A thing (or 随手摸一样) chosen: asked first from one clearly stronger; 取消 shows the list again.
func steal_choose(item_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null if map == null else map.selected_npc_here()
	if npc == null:
		return
	var npc_id: StringName = npc.character_id
	var still: Callable = func() -> bool: return map.thefts.can_steal_selected() and map.selected_character_id() == npc_id
	# In the popup: what is aimed at, above its question (随手摸一样 when nothing is named).
	# TRANSLATORS: the interaction popup's confirm page before 偷窃: {item} what the player reaches for.
	var about: String = tr("下手目标：{item}").format({"item": tr("随手摸一样") if item_id.is_empty() else map.thefts.item_name(item_id)}) if _ui.interaction_open() else ""
	if map.thefts.asks_first(npc):
		_ui.questions.ask_first(tr(STRONGER_STEAL_WARNING).format({"npc": tr(npc.definition().display_name)}), "确定下手", _steal_now.bind(npc_id, item_id), still, _show_steal_question, about)
		return
	if _ui.interaction_open():
		# TRANSLATORS: the interaction popup's confirm page before 偷窃 from {npc} (steal.c): caught at it, a fight to the death.
		_ui.questions.ask_first(tr("失手被发现，{npc}会和你拼命。确定要下手吗？").format({"npc": tr(npc.definition().display_name)}), "确定下手", _steal_now.bind(npc_id, item_id), still, _show_steal_question, about)
		return
	_steal_now(npc_id, item_id)


func _steal_now(npc_id: StringName, item_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	_ui.panel_done(_ui.steal_panel)
	map.thefts.begin(map.npcs.find_resident_npc(npc_id), item_id)


## 行贿 to the constable leading the player: the money they carry, how much of each.
func bribe_context(lines: Array[String] = []) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null or not map.patrols.can_bribe(_ui.selection.selected_target):
		return
	var npc: NpcRuntimeState = _ui.selection.selected_target
	var ids: Array[StringName] = []
	var names: Array[String] = []
	var amounts: Array[int] = []
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
		if content != null and content.currency_base_value > 0 and row.amount > 0:
			ids.append(row.item_instance_id)
			names.append(tr(content.display_name))
			amounts.append(row.amount)
	_ui.bribe_panel.show_money(tr(npc.definition().display_name), ids, names, amounts, lines)
	var npc_id: StringName = npc.character_id
	_presentation_layout.open_panel(tr("行贿"), _ui.bribe_panel, func() -> bool: return map.patrols.can_bribe(map.npcs.find_resident_npc(npc_id)))
	_presentation_layout.refresh_rows()


## accept_bribery(): taken, the panel closes (they are free); refused, it shows again with the line.
func bribe(item_id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	if not map.patrols.bribe(item_id, amount):
		return
	if map.patrols.can_bribe(_ui.selection.selected_target):
		bribe_context(map.patrols.last_lines)
	else:
		_ui.panel_done(_ui.bribe_panel)


func inspect_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.inspect_selected()


## 攻击; on the player's own master it asks first: the kill is a betrayal (3C); so it does
## on an NPC whose data asks it (NpcHooks attack_ask: 小娟, owner F3).
func attack_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var npc: NpcRuntimeState = map.selected_npc()
	var hooks: NpcHooks = null if npc == null else npc.definition().hooks()
	var about: String = _strength_of(npc) if _ui.interaction_open() else ""
	if npc != null and map.selected_attack_starts() and hooks != null and not hooks.attack_ask.is_empty():
		_ui.questions.ask_first(tr(hooks.attack_ask), hooks.attack_choice, map.attack_selected, _ui.selection.attack_is_enabled, Callable(), about)
		return
	if npc == null or not map.selected_attack_starts():
		# No fight would start (kill.c refuses): its line, nothing asked.
		map.attack_selected()
		return
	if not PlayerKillerReward.is_own_master(_player.state, npc.definition()):
		# TRANSLATORS: the interaction popup's confirm page before 攻击 on {npc} (kill.c): a fight to the death.
		confirm_in_popup(tr("攻击就是生死相搏。确定要攻击{npc}吗？").format({"npc": tr(npc.definition().display_name)}), "确定攻击", map.attack_selected, _ui.selection.attack_is_enabled, about)
		return
	var teaching: NpcTeaching = npc.definition().teaching()
	var family: FamilyDefinition = GameContent.catalog().family(teaching.family_id)
	_ui.questions.ask_first(tr(SharedGameplayUI.MASTER_ATTACK_WARNING).format({
		"master": tr(npc.definition().display_name), "family": tr(family.display_name) if family != null else "",
		"score": _player.state.progression.score, "next": _player.state.apprenticeship.betrayer_count + 1,
	}), "确定攻击", map.attack_selected, _ui.selection.attack_is_enabled, Callable(), about)


## 切磋; asked first when it will be fought to the death (accept_fight()'s kill_ob()),
## with a weapon in hand on either side (its blows wound), or against an NPC clearly
## stronger than the player (one blow can knock them out; owner A10).
func spar_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var risk: WorldMapController.SparRisk = map.selected_spar_risk()
	var npc: NpcRuntimeState = map.selected_npc()
	var about: String = _strength_of(npc) if _ui.interaction_open() else ""
	if risk == WorldMapController.SparRisk.NONE:
		# TRANSLATORS: the interaction popup's confirm page before a 切磋 with no risk named (fight.c): {npc} the one asked.
		confirm_in_popup(tr("切磋点到为止。确定要和{npc}切磋吗？").format({"npc": "" if npc == null else tr(npc.definition().display_name)}), "确定切磋", map.spar_selected, _ui.selection.spar_is_enabled, about)
		return
	var warning: String = DEADLY_SPAR_WARNING
	match risk:
		WorldMapController.SparRisk.ARMED:
			warning = ARMED_STRONGER_SPAR_WARNING if map.selected_spar_stronger() else ARMED_SPAR_WARNING
		WorldMapController.SparRisk.STRONGER:
			warning = STRONGER_SPAR_WARNING
	_ui.questions.ask_first(tr(warning).format({"npc": tr(map.selected_npc().definition().display_name)}), "确定切磋", map.spar_selected, _ui.selection.spar_is_enabled, Callable(), about)


func ask_context() -> void:
	_ui.ask.open_ask()


func traverse_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.traverse_selected_portal()


## Another of the selected landmark's actions (a dial's turn, by its count).
func landmark_action_context(action: String) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.traverse_selected_portal(action)


func loot_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.open_selected_loot()


func take_context(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.take_selected_loot_item(id)
