class_name CombatSliceLifecycleResult
extends RefCounted

enum Outcome {
	INVALID_CONTEXT,
	INCOHERENT_INPUT,
	UNCONSCIOUS_COMPLETE,
	DEATH_COMPLETE,
	DEATH_INVENTORY_BLOCKED,
	DEATH_INVENTORY_FAILED,
	RELATIONSHIP_CLEANUP_FAILED,
}

enum RequestedKind { NONE, UNCONSCIOUS, DEATH }
enum PartialStage { NONE, PRE_RELATIONSHIP_CLEANUP, RESOURCE_TRANSITION, DEATH_INVENTORY, FINAL_RELATIONSHIP_CLEANUP, COMPLETE }

var _outcome: int = Outcome.INVALID_CONTEXT
var _requested_kind: int = RequestedKind.NONE
var _victim_id: StringName = &""
var _old_life_status: int = CombatSliceLifeStatus.Value.ACTIVE
var _new_life_status: int = CombatSliceLifeStatus.Value.ACTIVE
var _reciprocal_cleanup_attempts: int = 0
var _reciprocal_cleanup_successes: int = 0
var _local_opponents_cleared: bool = false
var _resources_zeroed: bool = false
var _final_lethal_cleanup_complete: bool = false
var _partial_stage: int = PartialStage.NONE
var _death_inventory_result: DeathInventoryResult
var _second_corpse_placement_result: InventoryTransferResult
var _corpse_item_instance_id: StringName = &""

var outcome: int:
	get: return _outcome
var requested_kind: int:
	get: return _requested_kind
var victim_id: StringName:
	get: return _victim_id
var old_life_status: int:
	get: return _old_life_status
var new_life_status: int:
	get: return _new_life_status
var reciprocal_cleanup_attempts: int:
	get: return _reciprocal_cleanup_attempts
var reciprocal_cleanup_successes: int:
	get: return _reciprocal_cleanup_successes
var local_opponents_cleared: bool:
	get: return _local_opponents_cleared
var resources_zeroed: bool:
	get: return _resources_zeroed
var final_lethal_cleanup_complete: bool:
	get: return _final_lethal_cleanup_complete
var partial_stage: int:
	get: return _partial_stage
var death_inventory_result: DeathInventoryResult:
	get: return _death_inventory_result
var second_corpse_placement_result: InventoryTransferResult:
	get: return _second_corpse_placement_result
var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id


func completed() -> bool:
	return _outcome in [Outcome.UNCONSCIOUS_COMPLETE, Outcome.DEATH_COMPLETE]
