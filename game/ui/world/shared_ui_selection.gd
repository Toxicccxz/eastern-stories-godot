class_name SharedUiSelection
extends RefCounted
## What the HUD has selected (an NPC, a landmark, a corpse or a floor item), its 目标详情
## and 气 bar, and which context buttons it can press now. Code moved from
## SharedGameplayUI as it was; the HUD is `_ui`.
##
## Seam for gamepad focus navigation (not built yet): refresh_live_state() decides every
## context button's state in one place; a focus order can be derived from it.


var _ui: SharedGameplayUI
var selected_target: NpcRuntimeState
var selected_landmark: WorldLandmarkDefinition
var selected_landmark_source_available: bool = false
var _selected_corpse_name: String = ""
var _selected_corpse_count: int = 0
var selected_corpse_available: bool = false
var selected_corpse_in_range: bool = false
var selected_floor_item: bool = false

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


## The selected thing's name in the shown language.
func selection_text() -> String:
	if selected_target != null:
		return selected_target.short_name()
	if selected_landmark != null:
		return tr(selected_landmark.display_name)
	if selected_floor_item:
		return tr(_selected_corpse_name)
	if selected_corpse_available:
		return tr("{name}的尸体 · {count}件物品").format({"name": tr(_selected_corpse_name), "count": _selected_corpse_count})
	return ""


func set_selected_target(target: NpcRuntimeState) -> void:
	selected_target = target
	selected_landmark = null
	selected_landmark_source_available = false
	_clear_selected_corpse()
	_ui.items.close_loot()
	_ui.inspection_text.text = ""
	_ui.selected_target_label.text = selection_text()
	refresh_live_state()


func set_selected_landmark(
	landmark: WorldLandmarkDefinition,
	source_available: bool,
) -> void:
	selected_target = null
	selected_landmark = landmark
	selected_landmark_source_available = source_available
	_clear_selected_corpse()
	_ui.items.close_loot()
	_ui.inspection_text.text = ""
	_ui.selected_target_label.text = selection_text()
	refresh_live_state()


func set_selected_landmark_source_available(value: bool) -> void:
	selected_landmark_source_available = value
	refresh_live_state()


func set_selected_corpse(
	victim_display_name: String,
	content_count: int,
	in_range: bool,
	clear_inspection: bool = true,
) -> void:
	selected_target = null
	selected_landmark = null
	selected_landmark_source_available = false
	_selected_corpse_name = victim_display_name
	_selected_corpse_count = content_count
	selected_corpse_available = not victim_display_name.is_empty()
	selected_corpse_in_range = in_range
	selected_floor_item = false
	if clear_inspection:
		_ui.inspection_text.text = ""
		_ui.items.close_loot()
	_ui.selected_target_label.text = selection_text()
	refresh_live_state()


## An item lying on the floor: 拾取 picks it up (get.c) when in reach.
func set_selected_floor_item(display_name: String, in_range: bool, clear_inspection: bool = true) -> void:
	selected_target = null
	selected_landmark = null
	selected_landmark_source_available = false
	_selected_corpse_name = display_name
	selected_corpse_available = not display_name.is_empty()
	selected_corpse_in_range = in_range
	selected_floor_item = selected_corpse_available
	if clear_inspection:
		_ui.inspection_text.text = ""
		_ui.items.close_loot()
	_ui.selected_target_label.text = selection_text()
	refresh_live_state()


## `relation` is look.c's word for what the NPC is to the player (FamilyRelation), "" for none;
## `strength` the native line on how strong it looks (RelativeStrength.line()), "" for none.
## `title`: the one its mood shows (悲愤欲绝) instead of its own.
func show_inspection(definition: NpcDefinition, relation: String = "", gender: StringName = &"", strength: String = "", title: String = "") -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	if definition == null:
		_ui.inspection_text.text = ""
		return
	_ui.inspection_text.text = "%s\n%s" % [
		definition.short_name(title),
		tr(definition.description).strip_edges(),
	]
	if not relation.is_empty():
		# TRANSLATORS: look.c: {pronoun} is 他/她/它, {relation} what the NPC is to the player (师父, 同门师兄 …).
		_ui.inspection_text.text += "\n" + tr("{pronoun}是你的{relation}。").format({"pronoun": tr(Es2CombatMessages.pronoun(gender)), "relation": tr(relation)})
	if not strength.is_empty():
		_ui.inspection_text.text += "\n" + tr(strength).format({"pronoun": tr(Es2CombatMessages.pronoun(gender))})


## `text`: what looking at it shows now (the landmark policy's look()), as authored.
func show_landmark_inspection(definition: WorldLandmarkDefinition, text: String = "") -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	if definition == null:
		_ui.inspection_text.text = ""
		return
	_ui.inspection_text.text = "%s\n%s" % [
		tr(definition.display_name),
		tr(definition.description if text.is_empty() else text).strip_edges(),
	]


## `display_name` as authored; `description` already in the shown language
## (ItemContentDefinition.shown_description()).
func show_item_inspection(display_name: String, description: String) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	_ui.inspection_text.text = "%s\n%s" % [tr(display_name), description.strip_edges()]


func show_corpse_inspection(victim_display_name: String, content_count: int) -> void:
	_presentation_layout.open_panel("目标详情", _presentation_layout.details)
	# chard.c make_corpse(): set_name(victim->name(1) + "的尸体").
	_ui.inspection_text.text = tr("{name}的尸体\n里面有{count}件物品。").format({"name": tr(victim_display_name), "count": content_count})


func refresh_live_state() -> void:
	_ui.target_vitality.visible = selected_target != null
	_ui.target_vitality_text.visible = selected_target != null
	if _player != null:
		_ui.card.update_player_vitals(_player.state)
	if selected_target == null:
		_ui.target_vitality.value = 0.0
		_ui.target_vitality_text.text = "-"
	else:
		_ui.card.update_vitality(
			selected_target.character_state.vitality,
			_ui.target_vitality,
			_ui.target_vitality_text,
		)
	var target_available: bool = (
		selected_target != null
		and selected_target.exists_in_map
		and selected_target.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	)
	var landmark_available: bool = selected_landmark != null and selected_landmark.is_valid()
	var corpse_available: bool = selected_corpse_available
	var player_available: bool = (
		_player != null
		and _player.exists_in_world
		and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)
	_ui.inspect_button.disabled = (
		not target_available and not landmark_available and not corpse_available
	)
	# Fights with an NPC whose skills are not ported yet would abort (fight_deferred, DECISIONS 4E).
	var fightable: bool = target_available and not selected_target.definition().dealings().is_fight_deferred()
	_ui.attack_button.disabled = not fightable or not player_available
	# fight.c: a speaking character is asked; beasts are not (see DECISIONS).
	_ui.spar_button.disabled = not fightable or not player_available or not selected_target.definition().can_speak()
	# ask.c: the same speakers, who must be here (present()).
	_ui.ask_button.disabled = not player_available or not selected_npc_askable()
	_ui.open_loot_button.disabled = (
		not corpse_available
		or not selected_corpse_in_range
		or not player_available
	)
	var map := _bound_map as WorldMapController
	_ui.animate_button.disabled = not corpse_available or selected_floor_item or not player_available or map == null or map.animatable_corpse() == null
	_ui.lifeheal_button.disabled = (
		not target_available or not player_available or map == null or map.selected_npc_here() != selected_target
		or not _session.martial_arts().exert_at_functions().has(&"lifeheal")
	)
	_ui.heart_sense_button.disabled = (
		not target_available or not player_available or map == null or _session.essence_magic().heart_target() != selected_target
	)
	_ui.steal_button.disabled = (
		not target_available or not player_available or map == null or map.selected_npc_here() != selected_target
		or not map.thefts.can_steal_selected()
	)
	_ui.bribe_button.disabled = not target_available or not player_available or map == null or not map.patrols.can_bribe(selected_target)
	_ui._presentation_layout.menu_button.disabled = not player_available
	_ui.portal_button.disabled = (
		not landmark_available
		or selected_landmark.action_label.is_empty() # a sign is only looked at
		or not selected_landmark_source_available
		or not player_available
	)
	_ui.portal_button.text = tr("前往") if selected_landmark == null else tr(selected_landmark.action_label)


func selected_target_text() -> String:
	return _ui.selected_target_label.text


func inspection_display() -> String:
	return _ui.inspection_text.text


func attack_is_enabled() -> bool:
	return not _ui.attack_button.disabled


func spar_is_enabled() -> bool:
	return not _ui.spar_button.disabled


func ask_is_enabled() -> bool:
	return not _ui.ask_button.disabled


func selected_npc_askable() -> bool:
	var map := _bound_map as WorldMapController
	return map != null and selected_target != null and map.selected_npc() == selected_target and map.can_ask_selected()


func portal_action_is_enabled() -> bool:
	return not _ui.portal_button.disabled


func portal_action_text() -> String:
	return _ui.portal_button.text


func open_loot_is_enabled() -> bool:
	return not _ui.open_loot_button.disabled


func _clear_selected_corpse() -> void:
	_selected_corpse_name = ""
	selected_corpse_available = false
	selected_corpse_in_range = false
	selected_floor_item = false
