class_name OldPineVineInteractionDefinition
extends RefCounted

var _interaction_id: StringName
var _display_name: String
var _description: String
var _action_label: String
var _legacy_target_alias: StringName
var _legacy_source_path: String
var _source_player_presentation: String
var _waterfall_player_presentation: String
var _waterfall_observer_presentation: String
var _passage_player_presentation: String
var _passage_observer_presentation: String
var _waterfall_portal_id: StringName
var _passage_portal_id: StringName

var interaction_id: StringName:
	get: return _interaction_id
var display_name: String:
	get: return _display_name
var description: String:
	get: return _description
var action_label: String:
	get: return _action_label
var legacy_target_alias: StringName:
	get: return _legacy_target_alias
var legacy_source_path: String:
	get: return _legacy_source_path
var source_player_presentation: String:
	get: return _source_player_presentation
var waterfall_player_presentation: String:
	get: return _waterfall_player_presentation
var waterfall_observer_presentation: String:
	get: return _waterfall_observer_presentation
var passage_player_presentation: String:
	get: return _passage_player_presentation
var passage_observer_presentation: String:
	get: return _passage_observer_presentation
var waterfall_portal_id: StringName:
	get: return _waterfall_portal_id
var passage_portal_id: StringName:
	get: return _passage_portal_id


func _init(
	p_interaction_id: StringName = &"",
	p_display_name: String = "",
	p_description: String = "",
	p_action_label: String = "",
	p_legacy_target_alias: StringName = &"",
	p_legacy_source_path: String = "",
	p_source_player_presentation: String = "",
	p_waterfall_player_presentation: String = "",
	p_waterfall_observer_presentation: String = "",
	p_passage_player_presentation: String = "",
	p_passage_observer_presentation: String = "",
	p_waterfall_portal_id: StringName = &"",
	p_passage_portal_id: StringName = &"",
) -> void:
	_interaction_id = p_interaction_id
	_display_name = p_display_name
	_description = p_description
	_action_label = p_action_label
	_legacy_target_alias = p_legacy_target_alias
	_legacy_source_path = p_legacy_source_path
	_source_player_presentation = p_source_player_presentation
	_waterfall_player_presentation = p_waterfall_player_presentation
	_waterfall_observer_presentation = p_waterfall_observer_presentation
	_passage_player_presentation = p_passage_player_presentation
	_passage_observer_presentation = p_passage_observer_presentation
	_waterfall_portal_id = p_waterfall_portal_id
	_passage_portal_id = p_passage_portal_id


func is_valid() -> bool:
	return (
		not _interaction_id.is_empty()
		and not _display_name.is_empty()
		and not _description.is_empty()
		and not _action_label.is_empty()
		and _legacy_target_alias == &"vine"
		and not _legacy_source_path.is_empty()
		and not _source_player_presentation.is_empty()
		and not _waterfall_player_presentation.is_empty()
		and not _waterfall_observer_presentation.is_empty()
		and not _passage_player_presentation.is_empty()
		and not _passage_observer_presentation.is_empty()
		and not _waterfall_portal_id.is_empty()
		and not _passage_portal_id.is_empty()
		and _waterfall_portal_id != _passage_portal_id
	)
