class_name SharedGameplayUI
extends CanvasLayer

const MAX_LOG_LINES: int = 60
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)

## The status card: the player's name, the place (world_title), 精/气/神 as bars with
## their numbers, and the conditions line (player_vitality_text, 蛇毒).
var player_name: Label
var world_title: Label
var player_essence: ProgressBar
var player_essence_text: Label
var player_vitality: ProgressBar
var player_vitality_value: Label
var player_spirit: ProgressBar
var player_spirit_text: Label
var player_vitality_text: Label
var selected_target_label: Label
var target_vitality: ProgressBar
var target_vitality_text: Label
var inspect_button: Button
var attack_button: Button
var spar_button: Button
var ask_button: Button
var portal_button: Button
var open_loot_button: Button
## 驱尸 (necromancy/animate.c) on the selected corpse, when the player's spells reach it.
var animate_button: Button
## 疗伤他人 (lotusforce/lifeheal.c) on the selected NPC, when the player's force reaches it.
var lifeheal_button: Button
## 心识神通 (essencemagic/heart_sense.c) on the selected NPC lying unconscious, when the
## player's magic reaches it.
var heart_sense_button: Button
## 游识神通's question (DriftSensePanel), opened from the 武学 page.
var drift_panel: DriftSensePanel
## steal <item> from the selected NPC (cmds/std/steal.c): its list (StealPanel).
var steal_button: Button
var steal_panel: StealPanel
## bribe the constable leading the player (d/choyin/npc/yamen_po.c accept_bribery()): BribePanel.
var bribe_button: Button
var bribe_panel: BribePanel
var inventory_button: Button
var inspection_text: RichTextLabel
var combat_log: RichTextLabel
var loot_panel: OldPineLootPanel
var inventory_panel: PlayerInventoryPanel
## Asked in the shared frame before an important or deadly choice (ask_first()).
var confirm_prompt: ConfirmPrompt
var _confirmed_action: Callable = Callable()
var _cancelled_action: Callable = Callable()

# TRANSLATORS: asked before 攻击 on the player's own master: killing them is killing one's master (killer_reward(), betrayal's cost). {master} the NPC, {family} the player's family (封山剑派), {score} the player's 综合评价 now, {next} the betrayals counted after it.
const MASTER_ATTACK_WARNING: String = "{master}是你的师父。攻击就是生死相搏；若你亲手杀了{master}，便是弑师，等同背叛师门：\n· 被逐出{family}，门派、师父和称号都没有了。\n· 综合评价清零（现在是 {score}）。\n· 背叛师门的次数变成 {next} 次。\n确定要攻击吗？"
# TRANSLATORS: asked before 切磋 when the player or the NPC ({npc}) holds a weapon: a blow from it wounds as in a real fight (combatd.c).
const ARMED_SPAR_WARNING: String = "刀剑无眼：有人手持兵刃时，切磋中挨的刀剑会留下真伤，伤重了一样会丧命。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before 切磋 with an NPC ({npc}) whose answer to a spar is a fight to the death (accept_fight() calls kill_ob()).
const DEADLY_SPAR_WARNING: String = "{npc}不会只跟你点到为止：这一场切磋会变成生死相搏。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before a bare-handed 切磋 with an NPC ({npc}) clearly stronger than the player (native, owner A10): one blow can knock the player out.
const STRONGER_SPAR_WARNING: String = "{npc}看起来比你强得多：即使只是切磋，一招就可能把你打昏。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before 切磋 with a weapon in hand on either side and an NPC ({npc}) clearly stronger than the player (native, owner A10).
const ARMED_STRONGER_SPAR_WARNING: String = "{npc}看起来比你强得多，而且有人手持兵刃：切磋中挨的刀剑会留下真伤，伤重了一样会丧命。\n确定要和{npc}切磋吗？"
# TRANSLATORS: asked before 化尸粉 dissolves a corpse that still holds things (dust.c destructs it whole): {name} whose corpse, {count} how many things are in it.
const DISSOLVE_WARNING: String = "化尸粉会把{name}的尸体连同里面的 {count} 件物品一起化成一滩黄水，化掉的东西再也找不回来。\n确定要化掉吗？"
# TRANSLATORS: asked before the rope's 上吊 (rope.c hang_self(): die()): the character dies as in a fight.
const HANG_WARNING: String = "把绳子往脖子上一套，就是寻死：你会就此死去，和战死一样付出死亡的代价。\n确定要上吊吗？"
# TRANSLATORS: asked before 驱尸 (animate.c) when its 30 神 ({sen}) would leave the player below zero: they faint.
const ANIMATE_FAINT_WARNING: String = "施法驱尸要耗去 {sen} 点神，你现在撑不住，会当场昏过去。\n确定要施法吗？"
# TRANSLATORS: asked before 画符 (scribe.c, haunt.c) when its 40 神 ({sen}) would leave the player below zero: they faint.
const SCRIBE_FAINT_WARNING: String = "画这道符要耗去 {sen} 点神，你现在撑不住，会当场昏过去。\n确定要画吗？"
# TRANSLATORS: asked before 画符 (scribe.c) when the drop of blood it is drawn in (1 point of 气 off its effective value) would kill the badly wounded player.
const SCRIBE_DEATH_WARNING: String = "你伤得太重了：画符要咬破手指流血，这一点血就会要了你的命。\n确定要画吗？"
# TRANSLATORS: asked before a 僵尸追魂符 sends the player's zombie ({zombie}) after their own master ({master}): its kill counts as the player's (killer_reward()). {family}, {score}, {next} as in the 攻击 question.
const HAUNT_MASTER_WARNING: String = "{master}是你的师父。{zombie}会追杀{master}，它若得手，就算你弑师，等同背叛师门：\n· 被逐出{family}，门派、师父和称号都没有了。\n· 综合评价清零（现在是 {score}）。\n· 背叛师门的次数变成 {next} 次。\n确定要贴上这道符吗？"
# TRANSLATORS: asked before 跪下受戒 (daemon/class/bonze/master.c do_kneel()): {npc} the master, {prefixes} the characters a 法名 begins with (空明圆净虚悟方渡慧法), {first} the first character of the player's name, {example} one 法名 it could make.
const ORDINATION_WARNING: String = "跪下受戒就是剃度出家：{npc}会剃去你的头发，你从此是僧人。\n你的名字会改成法名：「{prefixes}」中随机一字，加上你名字的第一个字「{first}」（例如「{example}」），原来的名字从此不再使用。\n确定要跪下受戒吗？"
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
# TRANSLATORS: asked before 空识神通 (void_sense.c) when its 50 gin ({gin}) would knock the player out.
const VOID_FAINT_WARNING: String = "空识神通要耗去 {gin} 点精，你现在撑不住，会当场昏过去。\n确定要施展吗？"
# TRANSLATORS: asked before 游识神通 goes to the one chosen (drift_sense.c) when its 30 gin ({gin}) would knock the player out.
const DRIFT_FAINT_WARNING: String = "游识神通要耗去 {gin} 点精，你现在撑不住，施展完就会昏过去。\n确定要施展吗？"
# TRANSLATORS: the 偷窃 button's tooltip (cmds/std/steal.c): caught at it, the one robbed fights to the death and the town's constables know the player for a thief.
const STEAL_HINT: String = "偷窃：从对方身上偷一样东西（三秒后见分晓）。失手被发现，对方会和你拼命，城里的巡捕也会把你当贼抓。"
# TRANSLATORS: the 行贿 button's tooltip (yamen_po.c accept_bribery()): money to the constable leading the player.
const BRIBE_HINT: String = "行贿：塞钱给押着你的巡捕，钱给够了他就放你走；给少了反倒罪加一等。"
# TRANSLATORS: asked before 偷窃 from an NPC ({npc}) clearly stronger than the player (plan default, A10): one caught at it is attacked to the death (steal.c kill_ob()).
const STRONGER_STEAL_WARNING: String = "{npc}看起来比你强得多：要是失手被发现，{npc}会和你拼个你死我活。\n确定要下手吗？"
# TRANSLATORS: the 驱尸 button's tooltip: animate.c's 50 mana and 30 sen; the zombie lives on the player's 灵力 (zombie.c heal_up()).
const ANIMATE_HINT: String = "施法「驱尸」：让这具尸体站起来跟着你（50 法力、30 神）。僵尸靠吸你的灵力维持，灵力不足时就会倒下化为血水。"

var _player: WorldPlayerRuntimeType
const ALERT_COLOR: Color = Color(1.0, 0.38, 0.38)
## Plain log text is a light grey, so ES2's HIW (bright white) stands out from it
## (owner, modern fixes II); the log, the toasts and the battle log share it.
const PLAIN_LOG_COLOR: Color = Color(0.78, 0.79, 0.76)
## How include/ansi.h's bright colours look in the log and in the HUD's toasts.
const ES2_COLORS: Dictionary[StringName, Color] = {
	ColoredLine.HIR: ALERT_COLOR,
	ColoredLine.HIY: Color(1.0, 0.9, 0.35),
	ColoredLine.HIC: Color(0.45, 0.92, 1.0),
	ColoredLine.HIW: Color(1.0, 1.0, 1.0),
	ColoredLine.HIM: Color(1.0, 0.5, 1.0),
	ColoredLine.HIG: Color(0.45, 1.0, 0.45),
	ColoredLine.HIB: Color(0.5, 0.62, 1.0),
	ColoredLine.CYN: Color(0.3, 0.75, 0.8),
	ColoredLine.RED: Color(0.82, 0.24, 0.24),
	ColoredLine.GRN: Color(0.35, 0.78, 0.35),
}
var _presentation_layout: SharedGameplayLayout
var life_overlay: PlayerLifeOverlay
var _session: WorldSessionController
var _bound_map: WorldResidentMapController
var _food: HeldFoodPanel
var _liquid: HeldLiquidPanel
var _supplies: VBoxContainer
var _elapsed: float = 0.0
var _ask_panel: VBoxContainer
var _ask_topics: HFlowContainer
var _ask_relay: HFlowContainer
## The NPC's own commands the player can use beside it now (跪下受戒).
var _ask_verbs: HFlowContainer
var _ask_answer: Label
## Owner (modern fixes II): giving away what the player has equipped, or a large sum
## (GIVE_MONEY_ASK_AT 文 or more), is asked first; give.c asks nothing. An NPC that
## takes bets or donations (the 宝官, the 功德箱's keeper) is not asked about money.
const GIVE_MONEY_ASK_AT: int = 10000
# TRANSLATORS: asked before 给 (give.c) of an item the player has equipped ({item}) to an NPC ({npc}).
const GIVE_EQUIPPED_WARNING: String = "{item}正装备在你身上。确定把它送给{npc}吗？送出去的东西一般就要不回来了。"
# TRANSLATORS: asked before 给 (give.c) of a large sum ({money}, e.g. 三两黄金) to an NPC ({npc}).
const GIVE_MONEY_WARNING: String = "确定把{money}送给{npc}吗？送出去的钱一般就要不回来了。"

## The HUD's components (code moved out of this file; this class forwards to them).
var message_log: SharedUiMessageLog = SharedUiMessageLog.new(self)
var card: SharedUiStatusCard = SharedUiStatusCard.new(self)
var selection: SharedUiSelection = SharedUiSelection.new(self)


func _ready() -> void:
	_session = get_parent() as WorldSessionController
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	process_physics_priority = -100
	_presentation_layout = SharedGameplayLayout.new()
	_presentation_layout.name = "PresentationLayout"
	add_child(_presentation_layout)
	_presentation_layout.build(self)
	inspect_button.pressed.connect(_inspect_context)
	attack_button.pressed.connect(_attack_context)
	spar_button.pressed.connect(_spar_context)
	ask_button.pressed.connect(_ask_context)
	portal_button.pressed.connect(_traverse_context)
	open_loot_button.pressed.connect(_loot_context)
	animate_button.pressed.connect(_animate_context)
	animate_button.tooltip_text = ANIMATE_HINT
	lifeheal_button.pressed.connect(_lifeheal_context)
	lifeheal_button.tooltip_text = LIFEHEAL_HINT
	heart_sense_button.pressed.connect(_heart_sense_context)
	heart_sense_button.tooltip_text = HEART_SENSE_HINT
	steal_button.pressed.connect(_steal_context)
	steal_button.tooltip_text = STEAL_HINT
	steal_panel.chosen.connect(_steal_choose)
	steal_panel.cancelled.connect(_close_panel_of.bind(steal_panel))
	bribe_button.pressed.connect(_bribe_context)
	bribe_button.tooltip_text = BRIBE_HINT
	bribe_panel.bribed.connect(_bribe)
	bribe_panel.cancelled.connect(_close_panel_of.bind(bribe_panel))
	drift_panel.chosen.connect(_drift_choose)
	drift_panel.cancelled.connect(_drift_cancel)
	inventory_button.pressed.connect(open_inventory)
	loot_panel.take_requested.connect(_take_context)
	inventory_panel.inspect_requested.connect(_inspect_item)
	inventory_panel.wield_requested.connect(_wield_item)
	inventory_panel.unwield_requested.connect(_unwield_item)
	inventory_panel.wear_requested.connect(_wear_item)
	inventory_panel.remove_requested.connect(_remove_item)
	inventory_panel.give_requested.connect(_give_item)
	inventory_panel.drop_requested.connect(_drop_item)
	inventory_panel.put_requested.connect(_put_item)
	inventory_panel.play_requested.connect(_play_item)
	inventory_panel.apply_requested.connect(_apply_item)
	inventory_panel.act_requested.connect(_act_with_item)
	inventory_panel.dissolve_requested.connect(_dissolve_with)
	inventory_panel.hang_requested.connect(_hang_with)
	inventory_panel.pour_requested.connect(_pour_item)
	inventory_panel.take_out_requested.connect(_take_out_item)
	inventory_panel.put_into_requested.connect(_put_into_carried)
	inventory_panel.scribe_requested.connect(_scribe_on)
	inventory_panel.attach_requested.connect(_attach_sheet)
	confirm_prompt.confirmed.connect(_on_prompt_confirmed)
	confirm_prompt.cancelled.connect(_on_prompt_cancelled)
	_presentation_layout.character.arts.configure(_session)
	if _session != null:
		life_overlay = PlayerLifeOverlay.new()
		life_overlay.name = "PlayerLifeOverlay"
		life_overlay.configure(_session)
		_session.add_child.call_deferred(life_overlay)


## The overlay joins the session a frame late; free it if the session never got it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(life_overlay) and life_overlay.get_parent() == null:
		life_overlay.free()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _presentation_layout != null and is_inside_tree():
		# The selection's name and an open panel were put together in the old language;
		# the heading and the status line follow on the next refresh, the log keeps its lines.
		selected_target_label.text = selection.selection_text()
		_presentation_layout.close_panel()


func configure(player: WorldPlayerRuntimeType) -> bool:
	if player == null or not player.is_valid():
		return false
	_player = player
	selection.set_selected_target(null)
	selection.refresh_live_state()
	return true


func show_loot(title: String, rows: Array[WorldItemRowProjection]) -> void:
	close_inventory()
	loot_panel.show_loot(title, rows)
	_presentation_layout.open_panel(title, loot_panel)
	_presentation_layout.refresh_rows()


func close_loot() -> void:
	if loot_panel != null:
		loot_panel.close_loot()


func loot_is_open() -> bool:
	return loot_panel != null and loot_panel.is_open()


func loot_rows() -> Array[WorldItemRowProjection]:
	return [] if loot_panel == null else loot_panel.visible_rows()


func show_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
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
	inventory_panel.set_handling_targets(give_target, container)
	inventory_panel.set_dissolvable_corpse(map.dissolvable_corpse_name() if map != null and map.can_handle_items() else "")
	# scribe.c on a paper for the selected NPC; attach.c on the zombie here.
	var scribed: NpcRuntimeState = map.scribable_npc() if map != null and map.can_handle_items() else null
	var carrier: NpcRuntimeState = map.sheet_carrier() if map != null and map.can_handle_items() else null
	inventory_panel.set_spell_targets("" if scribed == null else scribed.definition().display_name, "" if carrier == null else carrier.definition().display_name)
	var pour_targets: Array = []
	if map != null and map.can_handle_items():
		for id: StringName in map.pour_targets():
			var held: ItemInstance = map.item_instance_index().resolve(id)
			var content: ItemContentDefinition = null if held == null else GameContent.catalog().item(held.item_definition_id)
			if content != null:
				pour_targets.append([id, content.display_name])
	inventory_panel.set_pour_targets(pour_targets)
	inventory_panel.show_inventory(rows)
	_presentation_layout.open_panel("背包", inventory_panel)
	_presentation_layout.refresh_rows()


func close_inventory() -> void:
	if inventory_panel != null:
		inventory_panel.close_inventory()


func inventory_is_open() -> bool:
	return inventory_panel != null and inventory_panel.is_open()


func inventory_rows() -> Array[PlayerInventoryRowProjection]:
	return [] if inventory_panel == null else inventory_panel.visible_rows()


func show_inventory_inspection(row: PlayerInventoryRowProjection) -> void:
	if inventory_panel != null:
		inventory_panel.show_inspection(row)


## ask.c without a topic: "你可以打听这些事情：" and the list; each topic asks, and
## the answer shows under the list (and in the log).
func open_ask() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null or not _session.portable_inventory_available() or not map.can_ask_selected():
		return
	if _ask_panel == null:
		_ask_panel = VBoxContainer.new()
		_ask_panel.name = "AskPanel"
		_ask_panel.add_theme_constant_override("separation", 10)
		var heading := Label.new()
		heading.text = "你可以打听这些事情："
		_ask_panel.add_child(heading)
		_ask_topics = HFlowContainer.new()
		_ask_topics.name = "Topics"
		_ask_topics.add_theme_constant_override("h_separation", 8)
		_ask_topics.add_theme_constant_override("v_separation", 8)
		_ask_panel.add_child(_ask_topics)
		# say.c beside the NPC for what its relay_say() answers (owner: a 接话 button).
		_ask_relay = HFlowContainer.new()
		_ask_relay.name = "Relay"
		_ask_relay.add_theme_constant_override("h_separation", 8)
		_ask_relay.add_theme_constant_override("v_separation", 8)
		_ask_panel.add_child(_ask_relay)
		_ask_verbs = HFlowContainer.new()
		_ask_verbs.name = "Verbs"
		_ask_verbs.add_theme_constant_override("h_separation", 8)
		_ask_verbs.add_theme_constant_override("v_separation", 8)
		_ask_panel.add_child(_ask_verbs)
		_ask_answer = Label.new()
		_ask_answer.name = "Answer"
		_ask_answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ask_panel.add_child(_ask_answer)
		_ask_panel.hide()
		_presentation_layout.holding.add_child(_ask_panel)
	for child: Node in _ask_topics.get_children():
		child.queue_free()
	for topic: String in map.ask_topics_selected():
		var button := Button.new()
		button.name = "Topic"
		button.text = tr(topic)
		button.custom_minimum_size = Vector2(80, 40)
		button.pressed.connect(_ask_topic.bind(topic))
		_ask_topics.add_child(button)
	for child: Node in _ask_relay.get_children():
		child.queue_free()
	for phrase: String in map.relay_phrases_selected():
		var say := Button.new()
		say.name = "Relay"
		# TRANSLATORS: say a line beside the NPC that it answers ({line}: 必有妖孽).
		say.text = tr("接话：{line}").format({"line": tr(phrase)})
		say.custom_minimum_size = Vector2(80, 40)
		say.pressed.connect(_say_beside.bind(phrase))
		_ask_relay.add_child(say)
	_ask_relay.visible = not map.relay_phrases_selected().is_empty()
	_refresh_ask_verbs(map)
	_ask_answer.text = ""
	message_log.open_panel_with_lines(tr("打听 · %s") % tr(selection.selected_target.definition().display_name), _ask_panel, selection.selected_npc_askable)
	_presentation_layout.refresh_rows()


func ask_topics_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_topics != null and _presentation_layout._content == _ask_panel:
		for child: Node in _ask_topics.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result


func ask_answer_text() -> String:
	return "" if _ask_answer == null else _ask_answer.text


func _ask_topic(topic: String) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null:
		_ask_answer.text = "\n".join(map.ask_selected(topic))
		_refresh_ask_verbs(map)
		_presentation_layout.refresh_rows()


## The kneel command of a master whose 剃度 the player asked for (daemon/class/bonze/master.c).
func _refresh_ask_verbs(map: WorldMapController) -> void:
	for child: Node in _ask_verbs.get_children():
		child.queue_free()
	if map.ordination_selected() != null:
		var kneel := Button.new()
		kneel.name = "Kneel"
		kneel.text = tr(NpcOrdination.LABEL)
		kneel.custom_minimum_size = Vector2(80, 40)
		kneel.pressed.connect(_kneel)
		_ask_verbs.add_child(kneel)
	_ask_verbs.visible = map.ordination_selected() != null


## The NPC commands the open 打听 panel offers (as shown).
func ask_verbs_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_verbs != null and _presentation_layout._content == _ask_panel:
		for child: Node in _ask_verbs.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result


## kneel (do_kneel()), asked first: the player's name becomes a 法名 for good (owner).
## 取消 goes back to the 打听 panel.
func _kneel() -> void:
	var map := _session.active_map() as WorldMapController
	var ordination: NpcOrdination = null if map == null else map.ordination_selected()
	if ordination == null:
		# The master was knocked out (or the like) while the panel stood open: the button goes.
		if map != null and _presentation_layout._content == _ask_panel:
			_refresh_ask_verbs(map)
		return
	var first: String = _player.facts.display_name.substr(0, 1)
	var text: String = tr(ORDINATION_WARNING).format({
		"npc": tr(selection.selected_target.definition().display_name), "prefixes": "".join(ordination.prefixes),
		"first": first, "example": ordination.prefixes[0] + first,
	})
	var kneel: Callable = func() -> void:
		map.kneel_selected()
	ask_first(text, "确定受戒", kneel, func() -> bool: return map.ordination_selected() != null, open_ask)


func _say_beside(phrase: String) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null:
		_ask_answer.text = "\n".join(map.say_beside_selected(phrase))


## The 接话 lines the open 打听 panel offers (as shown).
func relay_buttons_shown() -> Array[String]:
	var result: Array[String] = []
	if _ask_relay != null and _presentation_layout._content == _ask_panel:
		for child: Node in _ask_relay.get_children():
			if not child.is_queued_for_deletion():
				result.append((child as Button).text)
	return result


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


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _presentation_layout.frame.visible and event.is_action_pressed("ui_accept") and not event.is_echo() and not context_title().is_empty():
		get_viewport().set_input_as_handled()
		open_current_context()


func _process(delta: float) -> void:
	if _session == null or not _session.is_initialized() or _session.active_map_child_count() == 0:
		visible = false
		if _presentation_layout != null:
			_presentation_layout.close_panel()
		return
	var current: WorldResidentMapController = _session.active_map()
	# A new map or a HUD that just reappeared refreshes now, not 0.1 s later.
	if current != _bound_map:
		_presentation_layout.close_panel()
		selection.set_selected_target(null)
		_bound_map = current
		_elapsed = INF
	var available: bool = not _session.is_restore_candidate_staged() and not _session.is_session_swap_suspended() and _session.can_process() and _session.application_gameplay_allows_encounter_advance()
	var fighting: bool = _session.combat_encounter_coordinator().has_active_encounter()
	if not visible and available and not fighting:
		_elapsed = INF
	visible = available and not fighting
	if not visible:
		_presentation_layout.close_panel()
		# A fight clears the toasts from before it.
		message_log.refresh_toasts()
		return
	_presentation_layout.validate_open_panel()
	if _presentation_layout._content == _presentation_layout.details:
		if (selection.selected_target != null and (not selection.selected_target.exists_in_map or selection.selected_target.life_status == CharacterRuntimeLifeStatus.Value.DEAD)) or (selection.selected_landmark != null and not selection.selected_landmark_source_available) or (selection.selected_corpse_available and not selection.selected_corpse_in_range and not selection.selected_floor_item):
			_presentation_layout.close_panel()
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	selection.refresh_live_state()
	card.refresh_exploration()


func _physics_process(_delta: float) -> void:
	if _presentation_layout != null and _presentation_layout.frame.visible:
		quarantine_movement()


func quarantine_movement() -> void:
	if _session != null and _session.is_initialized() and _session.active_map_child_count() > 0 and _session.active_map() != null:
		_session.active_map().runtime_player_body().quarantine_current_movement_input()


func open_look() -> void:
	var zone: ZoneDefinition = card.current_zone()
	if zone == null or not _session.portable_inventory_available():
		return
	_presentation_layout.room.text = SharedUiMessageLog.room_prose(tr(zone.description))
	_presentation_layout.open_panel(tr(zone.display_name), _presentation_layout.room)


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


func open_business(title: String, form: Control, validate: Callable) -> void:
	if not _session.portable_inventory_available(): return
	message_log.business_feedback = ""
	message_log.open_panel_with_lines(title, form, validate)


func open_character() -> void:
	if not _session.portable_inventory_available(): return
	_refresh_character()
	_presentation_layout.open_panel("角色", _presentation_layout.character)


## The character panel on its 武学 page.
func open_martial_arts() -> void:
	open_character()
	if _presentation_layout.character.is_visible_in_tree():
		_presentation_layout.character.show_arts()


func martial_arts_page() -> MartialArtsPage:
	return _presentation_layout.character.arts


func _refresh_character() -> void:
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


func open_inventory() -> void:
	if _session.portable_inventory_available():
		show_inventory(_session.player_inventory_rows())


func open_supplies() -> void:
	if not _session.portable_inventory_available() or _supplies == null: return
	_food.show()
	_liquid.show()
	_presentation_layout.open_panel("随身补给", _supplies)


func _inspect_item(id: StringName) -> void:
	if not _session.portable_inventory_available(): return
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if row.item_instance_id == id:
			show_inventory_inspection(row)
			return
	open_inventory()


func _give_item(id: StringName, amount: int) -> void:
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
	ask_first(warning, "确定送出", give, still_valid, open_inventory)


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
		if row.equipment_slot != PlayerInventoryRowProjection.EquipmentSlot.NONE:
			return tr(GIVE_EQUIPPED_WARNING).format({"item": tr(content.display_name), "npc": npc_name})
		var given: int = amount if amount > 0 else row.amount
		var takes_money: bool = npc.definition().dealings().object_rules.any(
			func(rule: NpcObjectRule) -> bool: return rule.effect in NpcObjectRule.EFFECTS
		)
		if content.currency_base_value > 0 and not takes_money and given * content.currency_base_value >= GIVE_MONEY_ASK_AT:
			return tr(GIVE_MONEY_WARNING).format({"money": HeldItemFacts.counted(content, given), "npc": npc_name})
		return ""
	return ""


func _drop_item(id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.drop_item(id, amount)


func _put_item(id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.put_in_container(id, amount)


func _play_item(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.play_item(id)


func _apply_item(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.apply_item(id)


func _act_with_item(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.act_with_item(id)


func _pour_item(id: StringName, container_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.pour_into(id, container_id)


func _take_out_item(container_id: StringName, id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.take_from_carried_container(container_id, id)


func _put_into_carried(id: StringName, amount: int, container_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.put_in_carried_container(id, amount, container_id)


func _dissolve_with(id: StringName) -> void:
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
	ask_first(tr(DISSOLVE_WARNING).format({"name": tr(map.dissolvable_corpse_name()), "count": count}), "确定化掉", dissolve, Callable(), open_inventory)


## 驱尸 on the selected corpse; asked first when its 30 sen would knock the player out.
func _animate_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	if not map.animate_knocks_out():
		map.animate_selected_corpse()
		return
	ask_first(tr(ANIMATE_FAINT_WARNING).format({"sen": AnimateSpell.SEN_COST}), "确定施法", map.animate_selected_corpse, func() -> bool: return map.animatable_corpse() != null)


## exert lifeheal <the selected NPC> (疗伤他人): no question, it costs only force.
func _lifeheal_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null and map.selected_npc_here() != null:
		_session.martial_arts().exert_at(&"lifeheal", map.selected_npc_here())


## 心识神通 on the selected NPC lying unconscious: asked first whenever it goes ahead, as
## a failure knocks the player out (owner's rule; DECISIONS 山烟寺 A). A refusal (too little
## atman, busy, a no_magic room) asks nothing.
func _heart_sense_context() -> void:
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
	ask_first(question, "确定施展", magic.heart_sense, func() -> bool: return magic.heart_target() == npc)


## 空识神通 from the 武学 page; asked first when its gin would knock the player out.
## 取消 goes back to the page.
func conjure_void_sense() -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	if not magic.void_knocks_out():
		magic.void_sense()
		return
	ask_first(tr(VOID_FAINT_WARNING).format({"gin": VoidSenseConjure.GIN_COST}), "确定施展", magic.void_sense, magic.available, open_martial_arts)


## 游识神通 from the 武学 page: conjure.c's and the file's checks, then its question with
## the names the player may go to; a refusal is only logged.
func open_drift_sense() -> void:
	if _session.essence_magic().drift_begin():
		_show_drift_question()


func _show_drift_question(lines: Array[ColoredLine] = []) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	drift_panel.show_names(magic.drift_names(), lines)
	_presentation_layout.open_panel(tr(DriftSenseConjure.LABEL), drift_panel, magic.available)


## A name answered: asked first when the 30 gin would knock the player out.
func _drift_choose(npc_name: String) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	if magic.drift_knocks_out(npc_name):
		ask_first(tr(DRIFT_FAINT_WARNING).format({"gin": DriftSenseConjure.GIN_COST}), "确定施展", _drift_to.bind(npc_name), magic.available, _show_drift_question)
		return
	_drift_to(npc_name)


## select_target(): over, the question closes; nobody of that name now, it asks again.
func _drift_to(npc_name: String) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	if magic.drift_to(npc_name):
		if _presentation_layout._content == drift_panel:
			_presentation_layout.close_panel()
		return
	_show_drift_question(magic.last_lines)


## 偷窃 on the selected NPC: the list of what it is seen to wear or wield, and 随手摸一样.
func _steal_context() -> void:
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
	steal_panel.show_items(tr(npc.definition().display_name), ids, names)
	var npc_id: StringName = npc.character_id
	_presentation_layout.open_panel(tr("偷窃"), steal_panel, func() -> bool: return map.thefts.can_steal_selected() and map.selected_character_id() == npc_id)
	_presentation_layout.refresh_rows()


## A thing (or 随手摸一样) chosen: asked first from one clearly stronger; 取消 shows the list again.
func _steal_choose(item_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null if map == null else map.selected_npc_here()
	if npc == null:
		return
	var npc_id: StringName = npc.character_id
	if map.thefts.asks_first(npc):
		ask_first(tr(STRONGER_STEAL_WARNING).format({"npc": tr(npc.definition().display_name)}), "确定下手", _steal_now.bind(npc_id, item_id), func() -> bool: return map.thefts.can_steal_selected() and map.selected_character_id() == npc_id, _show_steal_question)
		return
	_steal_now(npc_id, item_id)


func _steal_now(npc_id: StringName, item_id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	if _presentation_layout._content == steal_panel:
		_presentation_layout.close_panel()
	map.thefts.begin(map.npcs.find_resident_npc(npc_id), item_id)


## 行贿 to the constable leading the player: the money they carry, how much of each.
func _bribe_context(lines: Array[String] = []) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null or not map.patrols.can_bribe(selection.selected_target):
		return
	var npc: NpcRuntimeState = selection.selected_target
	var ids: Array[StringName] = []
	var names: Array[String] = []
	var amounts: Array[int] = []
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
		if content != null and content.currency_base_value > 0 and row.amount > 0:
			ids.append(row.item_instance_id)
			names.append(tr(content.display_name))
			amounts.append(row.amount)
	bribe_panel.show_money(tr(npc.definition().display_name), ids, names, amounts, lines)
	var npc_id: StringName = npc.character_id
	_presentation_layout.open_panel(tr("行贿"), bribe_panel, func() -> bool: return map.patrols.can_bribe(map.npcs.find_resident_npc(npc_id)))
	_presentation_layout.refresh_rows()


## accept_bribery(): taken, the panel closes (they are free); refused, it shows again with the line.
func _bribe(item_id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	if not map.patrols.bribe(item_id, amount):
		return
	if map.patrols.can_bribe(selection.selected_target):
		_bribe_context(map.patrols.last_lines)
	elif _presentation_layout._content == bribe_panel:
		_presentation_layout.close_panel()


func _close_panel_of(panel: Control) -> void:
	if _presentation_layout._content == panel:
		_presentation_layout.close_panel()


## 中止施法 (an empty answer): its line, and back to the 武学 page.
func _drift_cancel() -> void:
	message_log.append_log_lines([tr(DriftSenseConjure.CANCELLED)])
	open_martial_arts()


## 画符 on a 桃符纸 for the selected NPC; asked first when its cost would kill the player or
## knock them out. 取消 goes back to the 背包.
func _scribe_on(id: StringName) -> void:
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
	ask_first(warning, "确定画符", scribe, Callable(), open_inventory)


## 贴符 on the zombie here; asked first when it would go after the player's own master
## (its kill is the player's: 弑师, as 攻击 asks). 取消 goes back to the 背包.
func _attach_sheet(id: StringName) -> void:
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
	ask_first(tr(HAUNT_MASTER_WARNING).format({
		"master": tr(target.definition().display_name), "zombie": tr(carrier.definition().display_name),
		"family": tr(family.display_name) if family != null else "",
		"score": _player.state.progression.score, "next": _player.state.apprenticeship.betrayer_count + 1,
	}), "确定贴符", attach, Callable(), open_inventory)


## rope.c hang: deadly, so asked first (owner); 取消 goes back to the 背包. Outdoors
## the rope finds nothing to hang from, so there is nothing to ask.
func _hang_with(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	if not map.can_hang_here():
		map.hang_with(id)
		return
	var hang: Callable = func() -> void:
		map.hang_with(id)
	ask_first(tr(HANG_WARNING), "确定上吊", hang, Callable(), open_inventory)


## Asks in the shared frame before an important or deadly choice (owner,
## 2026-10-06): `action` runs on the choice; 取消, 关闭 or Back drop it, and 取消 then
## runs `on_cancel` (back where the question came from). While `still_valid` returns
## false the question closes, as any panel does.
func ask_first(text: String, choice: String, action: Callable, still_valid: Callable = Callable(), on_cancel: Callable = Callable()) -> void:
	_confirmed_action = action
	_cancelled_action = on_cancel
	confirm_prompt.ask(text, choice)
	_presentation_layout.open_panel(tr("请确认"), confirm_prompt, still_valid)
	if _presentation_layout._content == confirm_prompt:
		# A question that wraps is taller than the frame's first layout.
		_presentation_layout.refresh_rows()
		confirm_prompt.focus_default()
	else:
		confirm_prompt.cancel()


## Whether the shared frame is asking (ask_first()).
func is_asking() -> bool:
	return confirm_prompt.is_asking() and _presentation_layout._content == confirm_prompt


func _on_prompt_confirmed() -> void:
	var action: Callable = _confirmed_action
	_confirmed_action = Callable()
	_cancelled_action = Callable()
	_presentation_layout.close_panel()
	if action.is_valid():
		action.call()


func _on_prompt_cancelled() -> void:
	var back: Callable = _cancelled_action
	_confirmed_action = Callable()
	_cancelled_action = Callable()
	# Hidden along with the HUD (a fight starts), _process() closes the frame itself;
	# closing it here would reparent the prompt while its visibility propagates.
	if _presentation_layout._content == confirm_prompt and confirm_prompt.is_visible_in_tree():
		_presentation_layout.close_panel()
		if back.is_valid():
			back.call()


func _wield_item(id: StringName) -> void:
	_session.wield_player_item(id)
	open_inventory()


func _unwield_item(id: StringName) -> void:
	_session.unwield_player_item(id)
	open_inventory()


func _wear_item(id: StringName) -> void:
	var result: OldPineArmorInteractionResult = _session.wear_player_item(id)
	if result != null and result.outcome == OldPineArmorInteractionResult.Outcome.FEMALE_ONLY:
		# wear.c's line, or the item's own wear() (d/latemoon/obj/skirt.c).
		var item: ItemInstance = _session.item_instance_index().resolve(id)
		var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
		if content != null and not content.wear_refusal.is_empty():
			message_log.append_log_lines([tr(content.wear_refusal).strip_edges()])
		else:
			message_log.append_log_lines([tr("这是女人的衣衫，你一个大男人也想穿，羞也不羞？")])
	open_inventory()


func _remove_item(id: StringName) -> void:
	_session.remove_player_item(id)
	open_inventory()


func _inspect_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.inspect_selected()


## 攻击; on the player's own master it asks first: the kill is a betrayal (3C).
func _attack_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var npc: NpcRuntimeState = map.selected_npc()
	if npc == null or not map.selected_attack_starts() or not PlayerKillerReward.is_own_master(_player.state, npc.definition()):
		map.attack_selected()
		return
	var teaching: NpcTeaching = npc.definition().teaching()
	var family: FamilyDefinition = GameContent.catalog().family(teaching.family_id)
	ask_first(tr(MASTER_ATTACK_WARNING).format({
		"master": tr(npc.definition().display_name), "family": tr(family.display_name) if family != null else "",
		"score": _player.state.progression.score, "next": _player.state.apprenticeship.betrayer_count + 1,
	}), "确定攻击", map.attack_selected, selection.attack_is_enabled)


## 切磋; asked first when it will be fought to the death (accept_fight()'s kill_ob()),
## with a weapon in hand on either side (its blows wound), or against an NPC clearly
## stronger than the player (one blow can knock them out; owner A10).
func _spar_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var risk: WorldMapController.SparRisk = map.selected_spar_risk()
	if risk == WorldMapController.SparRisk.NONE:
		map.spar_selected()
		return
	var warning: String = DEADLY_SPAR_WARNING
	match risk:
		WorldMapController.SparRisk.ARMED:
			warning = ARMED_STRONGER_SPAR_WARNING if map.selected_spar_stronger() else ARMED_SPAR_WARNING
		WorldMapController.SparRisk.STRONGER:
			warning = STRONGER_SPAR_WARNING
	ask_first(tr(warning).format({"npc": tr(map.selected_npc().definition().display_name)}), "确定切磋", map.spar_selected, selection.spar_is_enabled)


func _ask_context() -> void:
	open_ask()


func _traverse_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.traverse_selected_portal()


func _loot_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.open_selected_loot()


func _take_context(id: StringName) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.take_selected_loot_item(id)


func dismiss_current_panel() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null and map.dismiss_panel(_presentation_layout._content):
		_presentation_layout.validate_open_panel()
	else:
		_presentation_layout.close_panel()


func close_business(form: Control) -> void:
	if _presentation_layout._content == form:
		_presentation_layout.close_panel()


# --- forwarded to SharedUiMessageLog (message_log) ---


func show_combat_result(text: String) -> void:
	message_log.show_combat_result(text)


func append_after_fight(lines: Array[ColoredLine]) -> void:
	message_log.append_after_fight(lines)


func append_log_lines(lines: Array[String], alert: bool = false) -> void:
	message_log.append_log_lines(lines, alert)


func append_colored_lines(lines: Array[ColoredLine]) -> void:
	message_log.append_colored_lines(lines)


func toasts() -> MessageToasts:
	return message_log.toasts()


func refresh_toasts() -> void:
	message_log.refresh_toasts()


func panel_opened() -> void:
	message_log.panel_opened()


func log_lines() -> Array[String]:
	return message_log.log_lines()


static func room_prose(text: String) -> String:
	return SharedUiMessageLog.room_prose(text)


func describe_arrival() -> void:
	message_log.describe_arrival()


func describe_again() -> void:
	message_log.describe_again()


func open_messages() -> void:
	message_log.open_messages()


# --- forwarded to SharedUiStatusCard (card) ---


func refresh_exploration() -> void:
	card.refresh_exploration()


func current_zone() -> ZoneDefinition:
	return card.current_zone()


func location_name() -> String:
	return card.location_name()


# --- forwarded to SharedUiSelection (selection) ---


func set_selected_target(target: NpcRuntimeState) -> void:
	selection.set_selected_target(target)


func set_selected_landmark(landmark: WorldLandmarkDefinition, source_available: bool) -> void:
	selection.set_selected_landmark(landmark, source_available)


func set_selected_landmark_source_available(value: bool) -> void:
	selection.set_selected_landmark_source_available(value)


func set_selected_corpse(victim_display_name: String, content_count: int, in_range: bool, clear_inspection: bool = true) -> void:
	selection.set_selected_corpse(victim_display_name, content_count, in_range, clear_inspection)


func set_selected_floor_item(display_name: String, in_range: bool, clear_inspection: bool = true) -> void:
	selection.set_selected_floor_item(display_name, in_range, clear_inspection)


func show_inspection(definition: NpcDefinition, relation: String = "", gender: StringName = &"", strength: String = "") -> void:
	selection.show_inspection(definition, relation, gender, strength)


func show_landmark_inspection(definition: WorldLandmarkDefinition, text: String = "") -> void:
	selection.show_landmark_inspection(definition, text)


func show_item_inspection(display_name: String, description: String) -> void:
	selection.show_item_inspection(display_name, description)


func show_corpse_inspection(victim_display_name: String, content_count: int) -> void:
	selection.show_corpse_inspection(victim_display_name, content_count)


func refresh_live_state() -> void:
	selection.refresh_live_state()


func selected_target_text() -> String:
	return selection.selected_target_text()


func inspection_display() -> String:
	return selection.inspection_display()


func attack_is_enabled() -> bool:
	return selection.attack_is_enabled()


func spar_is_enabled() -> bool:
	return selection.spar_is_enabled()


func ask_is_enabled() -> bool:
	return selection.ask_is_enabled()


func portal_action_is_enabled() -> bool:
	return selection.portal_action_is_enabled()


func portal_action_text() -> String:
	return selection.portal_action_text()


func open_loot_is_enabled() -> bool:
	return selection.open_loot_is_enabled()
