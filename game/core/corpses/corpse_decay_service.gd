class_name CorpseDecayService
extends RefCounted

const CorpseStateType := preload("res://core/corpses/corpse_state.gd")
const IntentType := preload(
	"res://core/corpses/corpse_decay_schedule_intent.gd"
)
const ContentTransferServiceType := preload(
	"res://core/corpses/corpse_content_transfer_service.gd"
)
const ContentTransferResultType := preload(
	"res://core/corpses/corpse_content_transfer_result.gd"
)
const ResultType := preload("res://core/corpses/corpse_decay_result.gd")
const EndpointType := preload("res://core/inventory/containment_endpoint.gd")
const DestinationType := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const LifecycleOwnerType := preload(
	"res://core/items/lifecycle/item_lifecycle_owner_context.gd"
)
const LifecycleResultType := preload(
	"res://core/items/lifecycle/item_lifecycle_result.gd"
)
const LifecycleServiceType := preload(
	"res://core/items/lifecycle/item_lifecycle_service.gd"
)


static func initial_intent(corpse: CorpseStateType) -> IntentType:
	if corpse == null or not corpse.is_valid():
		return null
	return IntentType.new(
		corpse.corpse_item_instance_id,
		CorpseStateType.Stage.FRESH,
		CorpseStateType.Stage.ROTTEN,
		120,
	)


static func advance(
	corpse: CorpseStateType,
	intent: IntentType,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	corpse_environment_destination: DestinationType = null,
	corpse_direct_owner: LifecycleOwnerType = null,
) -> ResultType:
	var previous_stage: int = 0 if corpse == null else corpse.decay_stage
	if (
		corpse == null
		or inventory == null
		or stacks == null
		or not corpse.is_valid()
		or not inventory.is_registered(corpse.corpse_item_instance_id)
	):
		return ResultType.new(
			ResultType.Outcome.INVALID_DOMAIN_STATE,
			false,
			previous_stage,
			previous_stage,
		)
	if not _intent_matches(corpse, intent):
		return ResultType.new(
			ResultType.Outcome.INVALID_INTENT,
			false,
			previous_stage,
			corpse.decay_stage,
		)

	var corpse_parent: EndpointType = inventory.direct_parent(
		corpse.corpse_item_instance_id
	)
	if intent.next_stage == CorpseStateType.Stage.FINAL and corpse_parent != null:
		if corpse_environment_destination == null:
			return ResultType.new(
				ResultType.Outcome.DESTINATION_CONTEXT_REQUIRED,
				false,
				previous_stage,
				corpse.decay_stage,
			)
		var requested: EndpointType = corpse_environment_destination.endpoint
		if requested == null or not requested.same_identity(corpse_parent):
			return ResultType.new(
				ResultType.Outcome.DESTINATION_MISMATCH,
				false,
				previous_stage,
				corpse.decay_stage,
			)

	if not corpse._apply_next_decay_stage(intent.next_stage):
		return ResultType.new(
			ResultType.Outcome.INVALID_INTENT,
			false,
			previous_stage,
			corpse.decay_stage,
		)
	if corpse.decay_stage == CorpseStateType.Stage.ROTTEN:
		return ResultType.new(
			ResultType.Outcome.TRANSITIONED,
			true,
			previous_stage,
			corpse.decay_stage,
			IntentType.new(
				corpse.corpse_item_instance_id,
				CorpseStateType.Stage.ROTTEN,
				CorpseStateType.Stage.SKELETON,
				120,
			),
		)
	if corpse.decay_stage == CorpseStateType.Stage.SKELETON:
		return ResultType.new(
			ResultType.Outcome.TRANSITIONED,
			true,
			previous_stage,
			corpse.decay_stage,
			IntentType.new(
				corpse.corpse_item_instance_id,
				CorpseStateType.Stage.SKELETON,
				CorpseStateType.Stage.FINAL,
				60,
			),
		)

	var scatter_results: Array[ContentTransferResultType] = []
	if corpse_parent != null:
		var corpse_endpoint: EndpointType = EndpointType.new(
			EndpointType.Kind.ITEM,
			corpse.corpse_item_instance_id,
		)
		var direct_snapshot: Array[StringName] = inventory.direct_children(
			corpse_endpoint
		)
		for item_instance_id: StringName in direct_snapshot:
			scatter_results.append(
				ContentTransferServiceType.transfer_out(
					corpse,
					inventory,
					item_instance_id,
					corpse_environment_destination,
				)
			)
	var lifecycle: LifecycleResultType = LifecycleServiceType.destroy_item(
		inventory,
		stacks,
		corpse.corpse_item_instance_id,
		LifecycleResultType.ChildDisposition.DESTROY_SUBTREE,
		corpse_direct_owner,
	)
	if not lifecycle.succeeded:
		return ResultType.new(
			ResultType.Outcome.FINAL_DESTRUCTION_FAILED,
			false,
			previous_stage,
			corpse.decay_stage,
			null,
			scatter_results,
			lifecycle,
		)
	return ResultType.new(
		ResultType.Outcome.FINALIZED,
		true,
		previous_stage,
		corpse.decay_stage,
		null,
		scatter_results,
		lifecycle,
	)


static func _intent_matches(corpse: CorpseStateType, intent: IntentType) -> bool:
	if (
		intent == null
		or intent.corpse_item_instance_id != corpse.corpse_item_instance_id
		or intent.expected_stage != corpse.decay_stage
		or intent.next_stage != corpse.decay_stage + 1
	):
		return false
	if intent.expected_stage == CorpseStateType.Stage.FRESH:
		return intent.next_stage == CorpseStateType.Stage.ROTTEN and intent.delay_seconds == 120
	if intent.expected_stage == CorpseStateType.Stage.ROTTEN:
		return intent.next_stage == CorpseStateType.Stage.SKELETON and intent.delay_seconds == 120
	if intent.expected_stage == CorpseStateType.Stage.SKELETON:
		return intent.next_stage == CorpseStateType.Stage.FINAL and intent.delay_seconds == 60
	return false
