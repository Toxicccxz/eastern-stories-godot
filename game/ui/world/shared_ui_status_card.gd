class_name SharedUiStatusCard
extends RefCounted
## The status card at the top left: the player's name and place, 精/气/神 as bars, the
## conditions line, and the refresh that shows the context buttons there is something
## for. Code moved from SharedGameplayUI as it was; the HUD is `_ui`.


var _ui: SharedGameplayUI
## Names the player's shown conditions (蛇毒) on the HUD.
var _conditions: ConditionSystem = ConditionSystem.new()

# The HUD's authorities, read as SharedGameplayUI reads them.
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player
var _bound_map: WorldResidentMapController:
	get: return _ui._bound_map


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


func update_vitality(
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
func update_player_vitals(state: CharacterState) -> void:
	_update_bar(state.essence, _ui.player_essence)
	_update_bar(state.vitality, _ui.player_vitality)
	_update_bar(state.spirit, _ui.player_spirit)
	_ui.player_essence_text.text = str(state.essence.current)
	_ui.player_vitality_value.text = "%d/%d" % [state.vitality.current, state.vitality.effective]
	_ui.player_spirit_text.text = str(state.spirit.current)


## A resource's bar: current out of maximum; the tooltip has all three.
func _update_bar(resource: CharacterResourceState, bar: ProgressBar) -> void:
	bar.min_value = 0.0
	bar.max_value = float(maxi(resource.maximum, 1))
	bar.value = float(clampi(resource.current, 0, maxi(resource.maximum, 1)))
	# TRANSLATORS: a resource bar's tooltip: current / effective / maximum.
	bar.tooltip_text = tr("当前 {current} / 有效 {effective} / 最大 {maximum}").format({
		"current": resource.current, "effective": resource.effective, "maximum": resource.maximum,
	})


func refresh_exploration() -> void:
	var state: CharacterState = _player.state
	_ui.player_name.text = _player.facts.display_name
	_ui.world_title.text = tr(location_name())
	update_player_vitals(state)
	# TRANSLATORS: between two conditions on the HUD (蛇毒).
	_ui.player_vitality_text.text = tr("、").join(_conditions.shown_names(state))
	_ui.player_vitality_text.visible = not _ui.player_vitality_text.text.is_empty()
	# What is in reach, one group each (owner, 2026-10-11); the selected thing's own
	# buttons and the context button stay off the card.
	_ui.nearby.refresh()
	_ui.message_log.collect_feedback()
	_ui.message_log.describe_new_zone()
	_ui.message_log.refresh_toasts()
	_presentation_layout.fit_bar()


func current_zone() -> ZoneDefinition:
	return null if _player == null else GameContent.catalog().zone(_player.world_location().zone_id)


## The current zone's name, as authored.
func location_name() -> String:
	var zone: ZoneDefinition = current_zone()
	return "" if zone == null else zone.display_name
