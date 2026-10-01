class_name SharedGameplayUI
extends CanvasLayer

const MAX_LOG_LINES: int = 60
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)

var player_vitality: ProgressBar
var world_title: Label
var player_vitality_text: Label
var selected_target_label: Label
var target_vitality: ProgressBar
var target_vitality_text: Label
var inspect_button: Button
var attack_button: Button
var portal_button: Button
var open_loot_button: Button
var inventory_button: Button
var inspection_text: RichTextLabel
var combat_log: RichTextLabel
var loot_panel: OldPineLootPanel
var inventory_panel: PlayerInventoryPanel

var _player: WorldPlayerRuntimeType
var _selected_target: NpcRuntimeState
var _selected_landmark: WorldLandmarkDefinition
var _selected_landmark_source_available: bool = false
var _selected_corpse_name: String = ""
var _selected_corpse_available: bool = false
var _selected_corpse_in_range: bool = false
var _log_lines: Array[String] = []
var _presentation_layout: SharedGameplayLayout
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
	portal_button.pressed.connect(_traverse_context)
	open_loot_button.pressed.connect(_loot_context)
	inventory_button.pressed.connect(open_inventory)
	loot_panel.take_requested.connect(_take_context)
	inventory_panel.inspect_requested.connect(_inspect_item)
	inventory_panel.wield_requested.connect(_wield_item)
	inventory_panel.unwield_requested.connect(_unwield_item)
	inventory_panel.wear_requested.connect(_wear_item)
	inventory_panel.remove_requested.connect(_remove_item)
	if _session != null:
		life_overlay = PlayerLifeOverlay.new()
		life_overlay.name = "PlayerLifeOverlay"
		life_overlay.configure(_session)
		_session.add_child.call_deferred(life_overlay)


## The overlay joins the session a frame late; free it if the session never got it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(life_overlay) and life_overlay.get_parent() == null:
		life_overlay.free()


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
	if target == null:
		selected_target_label.text = ""
	else:
		selected_target_label.text = target.definition().short_name()
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
	selected_target_label.text = (
		""
		if landmark == null
		else "%s" % landmark.display_name
	)
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
	_selected_corpse_available = not victim_display_name.is_empty()
	_selected_corpse_in_range = in_range
	if clear_inspection:
		inspection_text.text = ""
		close_loot()
	selected_target_label.text = (
		""
		if not _selected_corpse_available
		else "%s的遗体 · %d件物品" % [victim_display_name, content_count]
	)
	refresh_live_state()


func show_inspection(definition: NpcDefinition) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	if definition == null:
		inspection_text.text = ""
		return
	inspection_text.text = "%s\n%s" % [
		definition.short_name(),
		definition.description.strip_edges(),
	]


func show_landmark_inspection(definition: WorldLandmarkDefinition) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	if definition == null:
		inspection_text.text = ""
		return
	inspection_text.text = "%s\n%s" % [
		definition.display_name,
		definition.description.strip_edges(),
	]


func show_corpse_inspection(victim_display_name: String, content_count: int) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	inspection_text.text = "Corpse of %s\nContents: %d" % [
		victim_display_name,
		content_count,
	]


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
		_update_vitality(
			_player.state.vitality,
			player_vitality,
			player_vitality_text,
		)
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
	attack_button.disabled = not target_available or not player_available
	open_loot_button.disabled = (
		not corpse_available
		or not _selected_corpse_in_range
		or not player_available
	)
	inventory_button.disabled = not player_available
	portal_button.disabled = (
		not landmark_available
		or not _selected_landmark_source_available
		or not player_available
	)
	portal_button.text = "Traverse" if _selected_landmark == null else _selected_landmark.action_label


func show_combat_result(text: String) -> void:
	append_log_lines([text])
	# Existing always-visible heading, not a modal input blocker on compact HUDs.
	_presentation_layout.recent.text = text.get_slice("\n", 0)
	world_title.tooltip_text = text


func append_log_lines(lines: Array[String]) -> void:
	for line: String in lines:
		if not line.is_empty():
			_log_lines.append(line)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	combat_log.text = "\n".join(_log_lines)
	_presentation_layout.recent.text = "" if _log_lines.is_empty() else _log_lines.back().get_slice("\n", 0)


func log_lines() -> Array[String]:
	return _log_lines.duplicate()


func selected_target_text() -> String:
	return selected_target_label.text


func inspection_display() -> String:
	return inspection_text.text


func attack_is_enabled() -> bool:
	return not attack_button.disabled


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


func _update_vitality(
	resource: CharacterResourceState,
	bar: ProgressBar,
	text_label: Label,
) -> void:
	bar.min_value = 0.0
	bar.max_value = float(maxi(resource.maximum, 1))
	bar.value = float(clampi(resource.current, 0, maxi(resource.maximum, 1)))
	text_label.text = "%d / %d / %d" % [
		resource.current,
		resource.effective,
		resource.maximum,
	]


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
		return
	_presentation_layout.validate_open_panel()
	if _presentation_layout._content == _presentation_layout.details:
		if (_selected_target != null and (not _selected_target.exists_in_map or _selected_target.life_status == CharacterRuntimeLifeStatus.Value.DEAD)) or (_selected_landmark != null and not _selected_landmark_source_available) or (_selected_corpse_available and not _selected_corpse_in_range):
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
	world_title.text = "%s · %s" % [_player.facts.display_name, location_name()]
	player_vitality_text.text = "精 %d  ·  气 %d/%d  ·  神 %d" % [state.essence.current, state.vitality.current, state.vitality.effective, state.spirit.current]
	var local_target: bool = _bound_map is WorldMapController and not selected_target_label.text.is_empty()
	inspect_button.visible = local_target and not inspect_button.disabled
	attack_button.visible = local_target and not attack_button.disabled
	portal_button.visible = local_target and not portal_button.disabled
	open_loot_button.visible = local_target and not open_loot_button.disabled
	selected_target_label.visible = local_target
	var context: String = context_title()
	_presentation_layout.context_button.text = context
	_presentation_layout.context_button.visible = not context.is_empty()
	_presentation_layout.contexts.visible = local_target or not context.is_empty()
	if _presentation_layout.character.is_visible_in_tree():
		_refresh_character()
	_collect_feedback()
	_describe_new_zone()
	_presentation_layout.recent.visible = not _presentation_layout.recent.text.is_empty()
	_presentation_layout.fit_bar()


func current_zone() -> ZoneDefinition:
	return null if _player == null else GameContent.catalog().zone(_player.world_location().zone_id)


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
	append_log_lines([tr("【%s】%s") % [zone.display_name, room_prose(zone.description)]])


func open_look() -> void:
	var zone: ZoneDefinition = current_zone()
	if zone == null or not _session.portable_inventory_available():
		return
	_presentation_layout.room.text = room_prose(zone.description)
	_presentation_layout.open_panel(zone.display_name, _presentation_layout.room)


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
	_presentation_layout.open_panel(title, form, validate)


func open_character() -> void:
	if not _session.portable_inventory_available(): return
	_refresh_character()
	_presentation_layout.open_panel("角色", _presentation_layout.character)


func _refresh_character() -> void:
	var state := _player.state
	var attr := state.attributes
	var text: String = "%s · %s · %d岁\n%s\n\n当前 / 有效 / 最大\n精 %s\n气 %s\n神 %s\n\n食物 %d · 饮水 %d\n实战经验 %d · 潜能 %d（已用 %d）\n\n膂力 %d · 胆识 %d · 悟性 %d · 灵性 %d\n定力 %d · 容貌 %d · 根骨 %d · 福缘 %d\n" % [_player.facts.display_name, state.gender, _player.facts.age, _player.facts.title, _resource_text(state.essence), _resource_text(state.vitality), _resource_text(state.spirit), state.recovery.food, state.recovery.water, state.progression.combat_experience, state.progression.potential, state.progression.potential_spent, attr.strength, attr.courage, attr.intelligence, attr.spirituality, attr.composure, attr.personality, attr.constitution, attr.karma]
	text += "\n基本拳脚 %d · 学习进度 %d\n柳家拳 %d · 学习进度 %d\n有效拳脚 %d" % [state.skills.raw_level(&"unarmed"), state.skills.learned_progress(&"unarmed"), state.skills.raw_level(LiuhKenDefinition.SKILL_ID), state.skills.learned_progress(LiuhKenDefinition.SKILL_ID), state.skills.effective_level(&"unarmed", _player.armor.aggregate_numeric_modifiers().unarmed)]
	text += "\n负重 %d / %d · 体重 %d" % [_session.inventory_state().contents_weight(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)), _player.maximum_encumbrance, _player.body_facts.body_weight]
	_presentation_layout.character.text = text


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
		_presentation_layout.open_panel("消息", combat_log)


func _inspect_item(id: StringName) -> void:
	if not _session.portable_inventory_available(): return
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if row.item_instance_id == id:
			show_inventory_inspection(row)
			return
	open_inventory()


func _wield_item(id: StringName) -> void:
	_session.wield_player_item(id)
	open_inventory()


func _unwield_item(id: StringName) -> void:
	_session.unwield_player_item(id)
	open_inventory()


func _wear_item(id: StringName) -> void:
	_session.wear_player_item(id)
	open_inventory()


func _remove_item(id: StringName) -> void:
	_session.remove_player_item(id)
	open_inventory()


func _inspect_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.inspect_selected()


func _attack_context() -> void:
	var map := _session.active_map() as WorldMapController
	if map != null: map.attack_selected()


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
		if label.name == "Feedback" and not label.text.is_empty(): lines.append(label.text)
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
