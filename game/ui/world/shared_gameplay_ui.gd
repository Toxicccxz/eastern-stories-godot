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
# TRANSLATORS: asked before 化尸粉 dissolves a corpse that still holds things (dust.c destructs it whole): {name} whose corpse, {count} how many things are in it.
const DISSOLVE_WARNING: String = "化尸粉会把{name}的尸体连同里面的 {count} 件物品一起化成一滩黄水，化掉的东西再也找不回来。\n确定要化掉吗？"

var _player: WorldPlayerRuntimeType
var _selected_target: NpcRuntimeState
var _selected_landmark: WorldLandmarkDefinition
var _selected_landmark_source_available: bool = false
var _selected_corpse_name: String = ""
var _selected_corpse_count: int = 0
var _selected_corpse_available: bool = false
var _selected_corpse_in_range: bool = false
var _selected_floor_item: bool = false
var _log_lines: Array[String] = []
## The ES2 colour of each log line (ColoredLine; &"" plain), e.g. kill_ob()'s
## 看起来X想杀死你！ in HIR bright red.
var _log_colors: Array[StringName] = []
## Lines the world printed while a fight ran that read best after its result
## (killer_reward()'s quest reward): shown with show_combat_result().
var _after_fight_lines: Array[ColoredLine] = []
const ALERT_COLOR: Color = Color(1.0, 0.38, 0.38)
## How include/ansi.h's bright colours look in the log and in the HUD's toasts.
const ES2_COLORS: Dictionary[StringName, Color] = {
	ColoredLine.HIR: ALERT_COLOR,
	ColoredLine.HIY: Color(1.0, 0.9, 0.35),
	ColoredLine.HIC: Color(0.45, 0.92, 1.0),
	ColoredLine.HIW: Color(1.0, 1.0, 1.0),
	ColoredLine.HIM: Color(1.0, 0.5, 1.0),
	ColoredLine.HIG: Color(0.45, 1.0, 0.45),
	ColoredLine.CYN: Color(0.3, 0.75, 0.8),
	ColoredLine.RED: Color(0.82, 0.24, 0.24),
}
var _presentation_layout: SharedGameplayLayout
## Names the player's shown conditions (蛇毒) on the HUD.
var _conditions: ConditionSystem = ConditionSystem.new()
var life_overlay: PlayerLifeOverlay


func _ready() -> void:
	_session = get_parent() as OldPineWorldSessionController
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
	inventory_panel.dissolve_requested.connect(_dissolve_with)
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
		selected_target_label.text = _selection_text()
		_presentation_layout.close_panel()


## The selected thing's name in the shown language.
func _selection_text() -> String:
	if _selected_target != null:
		return _selected_target.definition().short_name()
	if _selected_landmark != null:
		return tr(_selected_landmark.display_name)
	if _selected_floor_item:
		return tr(_selected_corpse_name)
	if _selected_corpse_available:
		return tr("{name}的尸体 · {count}件物品").format({"name": tr(_selected_corpse_name), "count": _selected_corpse_count})
	return ""


func configure(player: WorldPlayerRuntimeType) -> bool:
	if player == null or not player.is_valid():
		return false
	_player = player
	set_selected_target(null)
	refresh_live_state()
	return true


func set_selected_target(target: NpcRuntimeState) -> void:
	_selected_target = target
	_selected_landmark = null
	_selected_landmark_source_available = false
	_clear_selected_corpse()
	close_loot()
	inspection_text.text = ""
	selected_target_label.text = _selection_text()
	refresh_live_state()


func set_selected_landmark(
	landmark: WorldLandmarkDefinition,
	source_available: bool,
) -> void:
	_selected_target = null
	_selected_landmark = landmark
	_selected_landmark_source_available = source_available
	_clear_selected_corpse()
	close_loot()
	inspection_text.text = ""
	selected_target_label.text = _selection_text()
	refresh_live_state()


func set_selected_landmark_source_available(value: bool) -> void:
	_selected_landmark_source_available = value
	refresh_live_state()


func set_selected_corpse(
	victim_display_name: String,
	content_count: int,
	in_range: bool,
	clear_inspection: bool = true,
) -> void:
	_selected_target = null
	_selected_landmark = null
	_selected_landmark_source_available = false
	_selected_corpse_name = victim_display_name
	_selected_corpse_count = content_count
	_selected_corpse_available = not victim_display_name.is_empty()
	_selected_corpse_in_range = in_range
	_selected_floor_item = false
	if clear_inspection:
		inspection_text.text = ""
		close_loot()
	selected_target_label.text = _selection_text()
	refresh_live_state()


## An item lying on the floor: 拾取 picks it up (get.c) when in reach.
func set_selected_floor_item(display_name: String, in_range: bool, clear_inspection: bool = true) -> void:
	_selected_target = null
	_selected_landmark = null
	_selected_landmark_source_available = false
	_selected_corpse_name = display_name
	_selected_corpse_available = not display_name.is_empty()
	_selected_corpse_in_range = in_range
	_selected_floor_item = _selected_corpse_available
	if clear_inspection:
		inspection_text.text = ""
		close_loot()
	selected_target_label.text = _selection_text()
	refresh_live_state()


## `relation` is look.c's word for what the NPC is to the player (FamilyRelation), "" for none.
func show_inspection(definition: NpcDefinition, relation: String = "", gender: StringName = &"") -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	if definition == null:
		inspection_text.text = ""
		return
	inspection_text.text = "%s\n%s" % [
		definition.short_name(),
		tr(definition.description).strip_edges(),
	]
	if not relation.is_empty():
		# TRANSLATORS: look.c: {pronoun} is 他/她/它, {relation} what the NPC is to the player (师父, 同门师兄 …).
		inspection_text.text += "\n" + tr("{pronoun}是你的{relation}。").format({"pronoun": tr(Es2CombatMessages.pronoun(gender)), "relation": tr(relation)})


func show_landmark_inspection(definition: WorldLandmarkDefinition) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	if definition == null:
		inspection_text.text = ""
		return
	inspection_text.text = "%s\n%s" % [
		tr(definition.display_name),
		tr(definition.description).strip_edges(),
	]


## `display_name` as authored; `description` already in the shown language
## (ItemContentDefinition.shown_description()).
func show_item_inspection(display_name: String, description: String) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	inspection_text.text = "%s\n%s" % [tr(display_name), description.strip_edges()]


func show_corpse_inspection(victim_display_name: String, content_count: int) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	# chard.c make_corpse(): set_name(victim->name(1) + "的尸体").
	inspection_text.text = tr("{name}的尸体\n里面有{count}件物品。").format({"name": tr(victim_display_name), "count": content_count})


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


func refresh_live_state() -> void:
	target_vitality.visible = _selected_target != null
	target_vitality_text.visible = _selected_target != null
	if _player != null:
		_update_player_vitals(_player.state)
	if _selected_target == null:
		target_vitality.value = 0.0
		target_vitality_text.text = "-"
	else:
		_update_vitality(
			_selected_target.character_state.vitality,
			target_vitality,
			target_vitality_text,
		)
	var target_available: bool = (
		_selected_target != null
		and _selected_target.exists_in_map
		and _selected_target.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	)
	var landmark_available: bool = _selected_landmark != null and _selected_landmark.is_valid()
	var corpse_available: bool = _selected_corpse_available
	var player_available: bool = (
		_player != null
		and _player.exists_in_world
		and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)
	inspect_button.disabled = (
		not target_available and not landmark_available and not corpse_available
	)
	# Fights with an NPC whose skills are not ported yet would abort (fight_deferred, DECISIONS 4E).
	var fightable: bool = target_available and not _selected_target.definition().dealings().is_fight_deferred()
	attack_button.disabled = not fightable or not player_available
	# fight.c: a speaking character is asked; beasts are not (see DECISIONS).
	spar_button.disabled = not fightable or not player_available or not _selected_target.definition().can_speak()
	# ask.c: the same speakers, who must be here (present()).
	ask_button.disabled = not player_available or not _selected_npc_askable()
	open_loot_button.disabled = (
		not corpse_available
		or not _selected_corpse_in_range
		or not player_available
	)
	inventory_button.disabled = not player_available
	portal_button.disabled = (
		not landmark_available
		or _selected_landmark.action_label.is_empty() # a sign is only looked at
		or not _selected_landmark_source_available
		or not player_available
	)
	portal_button.text = tr("前往") if _selected_landmark == null else tr(_selected_landmark.action_label)


func show_combat_result(text: String) -> void:
	_append(_colored([text]), false)
	# The result's first line as a toast, not a modal input blocker on compact HUDs.
	_presentation_layout.toasts.push(text.get_slice("\n", 0))
	world_title.tooltip_text = text
	if not _after_fight_lines.is_empty():
		var lines: Array[ColoredLine] = _after_fight_lines.duplicate()
		_after_fight_lines.clear()
		append_colored_lines(lines)


## Lines for the log once the running fight's result is shown (at once outside a fight).
func append_after_fight(lines: Array[ColoredLine]) -> void:
	if _session != null and _session.is_initialized() and _session.combat_encounter_coordinator().has_active_encounter():
		_after_fight_lines.append_array(lines)
	else:
		append_colored_lines(lines)


## `alert`: the lines are warnings ES2 prints in bright red (HIR).
func append_log_lines(lines: Array[String], alert: bool = false) -> void:
	append_colored_lines(_colored(lines, alert))


static func _colored(lines: Array[String], alert: bool = false) -> Array[ColoredLine]:
	var colored: Array[ColoredLine] = []
	for line: String in lines:
		colored.append(ColoredLine.new(line, ColoredLine.HIR if alert else ColoredLine.PLAIN))
	return colored


## Lines in the colours ES2 prints them in: in 消息, and as toasts while no panel or
## fight shows its own lines.
func append_colored_lines(lines: Array[ColoredLine]) -> void:
	_append(lines, true)


func _append(lines: Array[ColoredLine], toast: bool) -> void:
	var stack: MessageToasts = _presentation_layout.toasts
	stack.set_suppressed(_toasts_suppressed())
	for line: ColoredLine in lines:
		if not line.text.is_empty():
			_log_lines.append(line.text)
			_log_colors.append(line.color)
			if toast:
				# A message of several lines (god.c's 朱鸿雪沉思了一会儿，说道： / 请在…) is shown whole.
				stack.push(line.text.replace("\n", " "), ES2_COLORS.get(line.color, MessageToasts.PLAIN_TEXT), ES2_COLORS.has(line.color))
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
		_log_colors.pop_front()
	var shown: PackedStringArray = []
	for index: int in _log_lines.size():
		var plain: String = _log_lines[index].replace("[", "[lb]")
		var color: StringName = _log_colors[index]
		shown.append("[color=#%s]%s[/color]" % [ES2_COLORS[color].to_html(false), plain] if ES2_COLORS.has(color) else plain)
	combat_log.text = "\n".join(shown)


## The bottom left's toasts (MessageToasts).
func toasts() -> MessageToasts:
	return _presentation_layout.toasts


func refresh_toasts() -> void:
	if not _presentation_layout.frame.visible:
		_panel_shows_lines = false
	_presentation_layout.toasts.set_suppressed(_toasts_suppressed())


## SharedGameplayLayout opened a panel: one that shows its own lines says so after.
func panel_opened() -> void:
	_panel_shows_lines = false
	refresh_toasts()


## A panel that shows its own lines (打听, a teacher, a shop: dialogue stays in its
## panel) or a fight shows them then. Other panels (背包, 拾取, 角色) let toasts through.
func _toasts_suppressed() -> bool:
	return (_presentation_layout.frame.visible and _panel_shows_lines) or (
		_session != null and _session.is_initialized() and _session.combat_encounter_coordinator().has_active_encounter()
	)


func log_lines() -> Array[String]:
	return _log_lines.duplicate()


func selected_target_text() -> String:
	return selected_target_label.text


func inspection_display() -> String:
	return inspection_text.text


func attack_is_enabled() -> bool:
	return not attack_button.disabled


func spar_is_enabled() -> bool:
	return not spar_button.disabled


func ask_is_enabled() -> bool:
	return not ask_button.disabled


func _selected_npc_askable() -> bool:
	var map := _bound_map as WorldMapController
	return map != null and _selected_target != null and map.selected_npc() == _selected_target and map.can_ask_selected()


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
	_ask_answer.text = ""
	_open_panel_with_lines(tr("打听 · %s") % tr(_selected_target.definition().display_name), _ask_panel, _selected_npc_askable)
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


func portal_action_is_enabled() -> bool:
	return not portal_button.disabled


func portal_action_text() -> String:
	return portal_button.text


func open_loot_is_enabled() -> bool:
	return not open_loot_button.disabled


func _clear_selected_corpse() -> void:
	_selected_corpse_name = ""
	_selected_corpse_available = false
	_selected_corpse_in_range = false
	_selected_floor_item = false


func _update_vitality(
	resource: CharacterResourceState,
	bar: ProgressBar,
	text_label: Label,
) -> void:
	_update_bar(resource, bar)
	text_label.text = "%d / %d / %d" % [
		resource.current,
		resource.effective,
		resource.maximum,
	]


## The card's 精/气/神: bars, and 精 and 神 current, 气 current/effective.
func _update_player_vitals(state: CharacterState) -> void:
	_update_bar(state.essence, player_essence)
	_update_bar(state.vitality, player_vitality)
	_update_bar(state.spirit, player_spirit)
	player_essence_text.text = str(state.essence.current)
	player_vitality_value.text = "%d/%d" % [state.vitality.current, state.vitality.effective]
	player_spirit_text.text = str(state.spirit.current)


## A resource's bar: current out of maximum; the tooltip has all three.
func _update_bar(resource: CharacterResourceState, bar: ProgressBar) -> void:
	bar.min_value = 0.0
	bar.max_value = float(maxi(resource.maximum, 1))
	bar.value = float(clampi(resource.current, 0, maxi(resource.maximum, 1)))
	# TRANSLATORS: a resource bar's tooltip: current / effective / maximum.
	bar.tooltip_text = tr("当前 {current} / 有效 {effective} / 最大 {maximum}").format({
		"current": resource.current, "effective": resource.effective, "maximum": resource.maximum,
	})


var _session: OldPineWorldSessionController
var _bound_map: WorldResidentMapController
var _food: HeldFoodPanel
var _liquid: HeldLiquidPanel
var _supplies: VBoxContainer
var _elapsed: float = 0.0
## Zone whose description was last written to the log; entering another zone
## writes the new one, as ES2 printed a room on arrival.
var _described_zone_id: StringName = &""
var _business_feedback: String = ""
## The open panel shows its own lines (an NPC's panel, 打听): no toasts while it is open.
var _panel_shows_lines: bool = false
var _ask_panel: VBoxContainer
var _ask_topics: HFlowContainer
var _ask_answer: Label


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
		set_selected_target(null)
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
		refresh_toasts()
		return
	_presentation_layout.validate_open_panel()
	if _presentation_layout._content == _presentation_layout.details:
		if (_selected_target != null and (not _selected_target.exists_in_map or _selected_target.life_status == CharacterRuntimeLifeStatus.Value.DEAD)) or (_selected_landmark != null and not _selected_landmark_source_available) or (_selected_corpse_available and not _selected_corpse_in_range and not _selected_floor_item):
			_presentation_layout.close_panel()
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	refresh_live_state()
	refresh_exploration()


func _physics_process(_delta: float) -> void:
	if _presentation_layout != null and _presentation_layout.frame.visible:
		quarantine_movement()


func quarantine_movement() -> void:
	if _session != null and _session.is_initialized() and _session.active_map_child_count() > 0 and _session.active_map() != null:
		_session.active_map().runtime_player_body().quarantine_current_movement_input()


func refresh_exploration() -> void:
	var state: CharacterState = _player.state
	player_name.text = _player.facts.display_name
	world_title.text = tr(location_name())
	_update_player_vitals(state)
	# TRANSLATORS: between two conditions on the HUD (蛇毒).
	player_vitality_text.text = tr("、").join(_conditions.shown_names(state))
	player_vitality_text.visible = not player_vitality_text.text.is_empty()
	var local_target: bool = _bound_map is WorldMapController and not selected_target_label.text.is_empty()
	inspect_button.visible = local_target and not inspect_button.disabled
	attack_button.visible = local_target and not attack_button.disabled
	spar_button.visible = local_target and not spar_button.disabled
	ask_button.visible = local_target and not ask_button.disabled
	portal_button.visible = local_target and not portal_button.disabled
	open_loot_button.visible = local_target and not open_loot_button.disabled
	selected_target_label.visible = local_target
	_presentation_layout.target_section.visible = local_target
	var context: String = context_title()
	_presentation_layout.context_button.text = context
	_presentation_layout.context_button.visible = not context.is_empty()
	_presentation_layout.contexts.visible = local_target or not context.is_empty()
	if _presentation_layout.character.is_visible_in_tree():
		_refresh_character()
	_collect_feedback()
	_describe_new_zone()
	refresh_toasts()
	_presentation_layout.fit_bar()


func current_zone() -> ZoneDefinition:
	return null if _player == null else GameContent.catalog().zone(_player.world_location().zone_id)


## The current zone's name, as authored.
func location_name() -> String:
	var zone: ZoneDefinition = current_zone()
	return "" if zone == null else zone.display_name


## ES2 room text keeps the MUD's hard line breaks; the UI wraps it itself.
static func room_prose(text: String) -> String:
	return text.strip_edges().replace("\n", "")


func _describe_new_zone() -> void:
	var zone: ZoneDefinition = current_zone()
	if zone == null or zone.zone_id == _described_zone_id:
		return
	_described_zone_id = zone.zone_id
	# TRANSLATORS: a room's title and its description, as the log shows them on arrival.
	append_log_lines([tr("【{title}】{description}").format({"title": tr(zone.display_name), "description": room_prose(tr(zone.description))})])


func open_look() -> void:
	var zone: ZoneDefinition = current_zone()
	if zone == null or not _session.portable_inventory_available():
		return
	_presentation_layout.room.text = room_prose(tr(zone.description))
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
	_business_feedback = ""
	_open_panel_with_lines(title, form, validate)


## Opens a panel that shows its own lines: toasts stay off while it is open.
func _open_panel_with_lines(title: String, content: Control, validate: Callable = Callable()) -> void:
	_presentation_layout.open_panel(title, content, validate)
	_panel_shows_lines = _presentation_layout._content == content
	refresh_toasts()


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
	# TRANSLATORS: the character sheet (score): name, gender, age and title, then 精/气/神 as current / effective / maximum, food and water, experience, potential and the attributes.
	var lines: Array[String] = [tr("{name} · {gender} · {age}岁\n{title}\n\n当前 / 有效 / 最大\n精 {gin}\n气 {kee}\n神 {sen}\n\n食物 {food} · 饮水 {water}\n实战经验 {exp} · 潜能 {potential}（已用 {spent}）\n\n膂力 {str} · 胆识 {cor} · 悟性 {int} · 灵性 {spi}\n定力 {cps} · 容貌 {per} · 根骨 {con} · 福缘 {kar}\n").format({
		"name": _player.facts.display_name, "gender": tr(state.gender), "age": _player.facts.age, "title": _player.shown_title(),
		"gin": _resource_text(state.essence), "kee": _resource_text(state.vitality), "sen": _resource_text(state.spirit),
		"food": state.recovery.food, "water": state.recovery.water, "exp": state.progression.combat_experience,
		"potential": state.progression.potential, "spent": state.progression.potential_spent,
		"str": attr.strength, "cor": attr.courage, "int": attr.intelligence, "spi": attr.spirituality,
		"cps": attr.composure, "per": attr.personality, "con": attr.constitution, "kar": attr.karma,
	})]
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


func open_messages() -> void:
	if _session.portable_inventory_available():
		_presentation_layout.open_panel("消息", _presentation_layout.messages)


func _inspect_item(id: StringName) -> void:
	if not _session.portable_inventory_available(): return
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if row.item_instance_id == id:
			show_inventory_inspection(row)
			return
	open_inventory()


func _give_item(id: StringName, amount: int) -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.give_to_selected(id, amount)


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
		append_log_lines([tr("这是女人的衣衫，你一个大男人也想穿，羞也不羞？")])
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
	}), "确定攻击", map.attack_selected, attack_is_enabled)


## 切磋; asked first when it will be fought to the death (accept_fight()'s kill_ob())
## or with a weapon in hand on either side (its blows wound).
func _spar_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map == null:
		return
	var risk: WorldMapController.SparRisk = map.selected_spar_risk()
	if risk == WorldMapController.SparRisk.NONE:
		map.spar_selected()
		return
	var warning: String = DEADLY_SPAR_WARNING if risk == WorldMapController.SparRisk.DEADLY else ARMED_SPAR_WARNING
	ask_first(tr(warning).format({"npc": tr(map.selected_npc().definition().display_name)}), "确定切磋", map.spar_selected, spar_is_enabled)


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


func _collect_feedback() -> void:
	if not _presentation_layout.frame.visible: return
	var lines: Array[String] = []
	for node: Node in _presentation_layout.mount.find_children("*", "Label", true, false):
		var label := node as Label
		# A fixed feedback holds its source text and translates itself: the log takes what it shows.
		if label.name == "Feedback" and not label.text.is_empty(): lines.append(label.atr(label.text) if label.can_auto_translate() else label.text)
	var text := "\n".join(lines)
	if not text.is_empty() and text != _business_feedback:
		_business_feedback = text
		append_log_lines(lines)


func dismiss_current_panel() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null and map.dismiss_panel(_presentation_layout._content):
		_presentation_layout.validate_open_panel()
	else:
		_presentation_layout.close_panel()


func close_business(form: Control) -> void:
	if _presentation_layout._content == form:
		_presentation_layout.close_panel()
