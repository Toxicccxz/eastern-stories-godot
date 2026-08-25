class_name DeferredNpcSpawnIntent
extends RefCounted

const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)

enum CompletionOrder {
	SPAWN_RESET_CHANT_THEN_DESTROY_SOURCE,
}

var _source_item_instance_id: StringName
var _npc_definition_id: StringName
var _legacy_npc_source_path: String
var _world_endpoint: ContainmentEndpointType
var _completion_order: int

var source_item_instance_id: StringName:
	get: return _source_item_instance_id
var npc_definition_id: StringName:
	get: return _npc_definition_id
var legacy_npc_source_path: String:
	get: return _legacy_npc_source_path
var world_endpoint: ContainmentEndpointType:
	get:
		return null if _world_endpoint == null else _world_endpoint.duplicate_snapshot()
var completion_order: int:
	get: return _completion_order


func _init(
	p_source_item_instance_id: StringName = &"",
	p_npc_definition_id: StringName = &"",
	p_legacy_npc_source_path: String = "",
	p_world_endpoint: ContainmentEndpointType = null,
	p_completion_order: int = CompletionOrder.SPAWN_RESET_CHANT_THEN_DESTROY_SOURCE,
) -> void:
	_source_item_instance_id = p_source_item_instance_id
	_npc_definition_id = p_npc_definition_id
	_legacy_npc_source_path = p_legacy_npc_source_path
	_world_endpoint = (
		null
		if p_world_endpoint == null
		else p_world_endpoint.duplicate_snapshot()
	)
	_completion_order = p_completion_order
