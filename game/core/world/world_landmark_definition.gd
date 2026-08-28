class_name WorldLandmarkDefinition
extends RefCounted

var _landmark_id: StringName
var _display_name: String
var _description: String
var _portal_id: StringName
var _action_label: String
var _legacy_source_path: String

var landmark_id: StringName:
	get:
		return _landmark_id
var display_name: String:
	get:
		return _display_name
var description: String:
	get:
		return _description
var portal_id: StringName:
	get:
		return _portal_id
var action_label: String:
	get:
		return _action_label
var legacy_source_path: String:
	get:
		return _legacy_source_path


func _init(
	p_landmark_id: StringName = &"",
	p_display_name: String = "",
	p_description: String = "",
	p_portal_id: StringName = &"",
	p_action_label: String = "",
	p_legacy_source_path: String = "",
) -> void:
	_landmark_id = p_landmark_id
	_display_name = p_display_name
	_description = p_description
	_portal_id = p_portal_id
	_action_label = p_action_label
	_legacy_source_path = p_legacy_source_path


func is_valid() -> bool:
	return (
		not _landmark_id.is_empty()
		and not _display_name.is_empty()
		and not _description.is_empty()
		and not _portal_id.is_empty()
		and not _action_label.is_empty()
		and not _legacy_source_path.is_empty()
	)
