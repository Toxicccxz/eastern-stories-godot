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
# TRANSLATORS: asked before 空识神通 (void_sense.c) when its 50 gin ({gin}) would knock the player out.
const VOID_FAINT_WARNING: String = "空识神通要耗去 {gin} 点精，你现在撑不住，会当场昏过去。\n确定要施展吗？"
# TRANSLATORS: asked before 游识神通 goes to the one chosen (drift_sense.c) when its 30 gin ({gin}) would knock the player out.
const DRIFT_FAINT_WARNING: String = "游识神通要耗去 {gin} 点精，你现在撑不住，施展完就会昏过去。\n确定要施展吗？"

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

## The HUD's components (code moved out of this file; this class forwards to them).
var message_log: SharedUiMessageLog = SharedUiMessageLog.new(self)
var card: SharedUiStatusCard = SharedUiStatusCard.new(self)
var selection: SharedUiSelection = SharedUiSelection.new(self)
var actions: SharedUiContextActions = SharedUiContextActions.new(self)
var ask: SharedUiAskPanel = SharedUiAskPanel.new(self)
var items: SharedUiInventory = SharedUiInventory.new(self)


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
	inspect_button.pressed.connect(actions.inspect_context)
	attack_button.pressed.connect(actions.attack_context)
	spar_button.pressed.connect(actions.spar_context)
	ask_button.pressed.connect(actions.ask_context)
	portal_button.pressed.connect(actions.traverse_context)
	open_loot_button.pressed.connect(actions.loot_context)
	animate_button.pressed.connect(actions.animate_context)
	animate_button.tooltip_text = SharedUiContextActions.ANIMATE_HINT
	lifeheal_button.pressed.connect(actions.lifeheal_context)
	lifeheal_button.tooltip_text = SharedUiContextActions.LIFEHEAL_HINT
	heart_sense_button.pressed.connect(actions.heart_sense_context)
	heart_sense_button.tooltip_text = SharedUiContextActions.HEART_SENSE_HINT
	steal_button.pressed.connect(actions.steal_context)
	steal_button.tooltip_text = SharedUiContextActions.STEAL_HINT
	steal_panel.chosen.connect(actions.steal_choose)
	steal_panel.cancelled.connect(_close_panel_of.bind(steal_panel))
	bribe_button.pressed.connect(actions.bribe_context)
	bribe_button.tooltip_text = SharedUiContextActions.BRIBE_HINT
	bribe_panel.bribed.connect(actions.bribe)
	bribe_panel.cancelled.connect(_close_panel_of.bind(bribe_panel))
	drift_panel.chosen.connect(_drift_choose)
	drift_panel.cancelled.connect(_drift_cancel)
	inventory_button.pressed.connect(items.open_inventory)
	loot_panel.take_requested.connect(actions.take_context)
	inventory_panel.inspect_requested.connect(items.inspect_item)
	inventory_panel.wield_requested.connect(items.wield_item)
	inventory_panel.unwield_requested.connect(items.unwield_item)
	inventory_panel.wear_requested.connect(items.wear_item)
	inventory_panel.remove_requested.connect(items.remove_item)
	inventory_panel.give_requested.connect(items.give_item)
	inventory_panel.drop_requested.connect(items.drop_item)
	inventory_panel.put_requested.connect(items.put_item)
	inventory_panel.play_requested.connect(items.play_item)
	inventory_panel.apply_requested.connect(items.apply_item)
	inventory_panel.act_requested.connect(items.act_with_item)
	inventory_panel.dissolve_requested.connect(items.dissolve_with)
	inventory_panel.hang_requested.connect(items.hang_with)
	inventory_panel.pour_requested.connect(items.pour_item)
	inventory_panel.take_out_requested.connect(items.take_out_item)
	inventory_panel.put_into_requested.connect(items.put_into_carried)
	inventory_panel.scribe_requested.connect(items.scribe_on)
	inventory_panel.attach_requested.connect(items.attach_sheet)
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
	if visible and not _presentation_layout.frame.visible and event.is_action_pressed("ui_accept") and not event.is_echo() and not actions.context_title().is_empty():
		get_viewport().set_input_as_handled()
		actions.open_current_context()


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


func _close_panel_of(panel: Control) -> void:
	if _presentation_layout._content == panel:
		_presentation_layout.close_panel()


## 中止施法 (an empty answer): its line, and back to the 武学 page.
func _drift_cancel() -> void:
	message_log.append_log_lines([tr(DriftSenseConjure.CANCELLED)])
	open_martial_arts()


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


# --- forwarded to SharedUiContextActions (actions) ---


func context_title() -> String:
	return actions.context_title()


func open_current_context() -> void:
	actions.open_current_context()


# --- forwarded to SharedUiAskPanel (ask) ---


func open_ask() -> void:
	ask.open_ask()


func ask_topics_shown() -> Array[String]:
	return ask.ask_topics_shown()


func ask_answer_text() -> String:
	return ask.ask_answer_text()


func ask_verbs_shown() -> Array[String]:
	return ask.ask_verbs_shown()


func relay_buttons_shown() -> Array[String]:
	return ask.relay_buttons_shown()


# --- forwarded to SharedUiInventory (items) ---


func show_loot(title: String, rows: Array[WorldItemRowProjection]) -> void:
	items.show_loot(title, rows)


func close_loot() -> void:
	items.close_loot()


func loot_is_open() -> bool:
	return items.loot_is_open()


func loot_rows() -> Array[WorldItemRowProjection]:
	return items.loot_rows()


func show_inventory(rows: Array[PlayerInventoryRowProjection]) -> void:
	items.show_inventory(rows)


func close_inventory() -> void:
	items.close_inventory()


func inventory_is_open() -> bool:
	return items.inventory_is_open()


func inventory_rows() -> Array[PlayerInventoryRowProjection]:
	return items.inventory_rows()


func show_inventory_inspection(row: PlayerInventoryRowProjection) -> void:
	items.show_inventory_inspection(row)


func open_inventory() -> void:
	items.open_inventory()
