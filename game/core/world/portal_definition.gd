class_name PortalDefinition
extends RefCounted

enum InteractionKind {
	INVALID,
	CLIMB,
}

var _portal_id: StringName
var _source_map_id: StringName
var _source_zone_id: StringName
var _destination_map_id: StringName
var _destination_zone_id: StringName
var _destination_spawn_point_id: StringName
var _interaction_kind: int
var _policy_id: StringName
var _legacy_source_path: String
var _legacy_action_verb: StringName
var _legacy_action_argument: StringName

var portal_id: StringName:
	get:
		return _portal_id
var source_map_id: StringName:
	get:
		return _source_map_id
var source_zone_id: StringName:
	get:
		return _source_zone_id
var destination_map_id: StringName:
	get:
		return _destination_map_id
var destination_zone_id: StringName:
	get:
		return _destination_zone_id
var destination_spawn_point_id: StringName:
	get:
		return _destination_spawn_point_id
var interaction_kind: int:
	get:
		return _interaction_kind
var policy_id: StringName:
	get:
		return _policy_id
var legacy_source_path: String:
	get:
		return _legacy_source_path
var legacy_action_verb: StringName:
	get:
		return _legacy_action_verb
var legacy_action_argument: StringName:
	get:
		return _legacy_action_argument


func _init(
	p_portal_id: StringName = &"",
	p_source_map_id: StringName = &"",
	p_source_zone_id: StringName = &"",
	p_destination_map_id: StringName = &"",
	p_destination_zone_id: StringName = &"",
	p_destination_spawn_point_id: StringName = &"",
	p_interaction_kind: int = InteractionKind.INVALID,
	p_policy_id: StringName = &"",
	p_legacy_source_path: String = "",
	p_legacy_action_verb: StringName = &"",
	p_legacy_action_argument: StringName = &"",
) -> void:
	_portal_id = p_portal_id
	_source_map_id = p_source_map_id
	_source_zone_id = p_source_zone_id
	_destination_map_id = p_destination_map_id
	_destination_zone_id = p_destination_zone_id
	_destination_spawn_point_id = p_destination_spawn_point_id
	_interaction_kind = p_interaction_kind
	_policy_id = p_policy_id
	_legacy_source_path = p_legacy_source_path
	_legacy_action_verb = p_legacy_action_verb
	_legacy_action_argument = p_legacy_action_argument


func is_valid() -> bool:
	return (
		not _portal_id.is_empty()
		and not _source_map_id.is_empty()
		and not _source_zone_id.is_empty()
		and not _destination_map_id.is_empty()
		and not _destination_zone_id.is_empty()
		and not _destination_spawn_point_id.is_empty()
		and _interaction_kind > InteractionKind.INVALID
		and _interaction_kind <= InteractionKind.CLIMB
		and not _legacy_source_path.is_empty()
		and not _legacy_action_verb.is_empty()
	)
