class_name DeathItemPolicyResult
extends RefCounted

const SpawnIntentType := preload(
	"res://core/death/deferred_npc_spawn_intent.gd"
)

enum Outcome {
	KEEP,
	DESTROY_ITEM,
	DEFERRED_RUNTIME_EFFECT,
	DEPENDENCY_UNAVAILABLE,
}

var _outcome: int
var _item_instance_id: StringName
var _spawn_intent: SpawnIntentType

var outcome: int:
	get: return _outcome
var item_instance_id: StringName:
	get: return _item_instance_id
var spawn_intent: SpawnIntentType:
	get: return _spawn_intent


func _init(
	p_outcome: int = Outcome.KEEP,
	p_item_instance_id: StringName = &"",
	p_spawn_intent: SpawnIntentType = null,
) -> void:
	_outcome = p_outcome
	_item_instance_id = p_item_instance_id
	_spawn_intent = p_spawn_intent
