class_name CorpseContentTransferService
extends RefCounted

const CorpseStateType := preload("res://core/corpses/corpse_state.gd")
const EndpointType := preload("res://core/inventory/containment_endpoint.gd")
const InventoryStateType := preload("res://core/inventory/inventory_state.gd")
const DestinationType := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const TransferServiceType := preload(
	"res://core/inventory/inventory_transfer_service.gd"
)
const ResultType := preload(
	"res://core/corpses/corpse_content_transfer_result.gd"
)


static func transfer_out(
	corpse: CorpseStateType,
	inventory: InventoryStateType,
	item_instance_id: StringName,
	destination: DestinationType,
) -> ResultType:
	if corpse == null or inventory == null or not corpse.is_valid():
		return ResultType.new(
			ResultType.Outcome.INVALID_DOMAIN_STATE,
			false,
			item_instance_id,
		)
	var corpse_endpoint: EndpointType = EndpointType.new(
		EndpointType.Kind.ITEM,
		corpse.corpse_item_instance_id,
	)
	if not inventory.is_direct_child(item_instance_id, corpse_endpoint):
		return ResultType.new(
			ResultType.Outcome.ITEM_NOT_DIRECT_CORPSE_CONTENT,
			false,
			item_instance_id,
		)
	var released: bool = false
	if corpse.is_worn(item_instance_id):
		if not corpse.is_legacy_character_for_equipment():
			return ResultType.new(
				ResultType.Outcome.CORPSE_WORN_LOCKED,
				false,
				item_instance_id,
			)
		released = corpse._release_worn_for_transfer(item_instance_id)
		if not released:
			return ResultType.new(
				ResultType.Outcome.CORPSE_WORN_LOCKED,
				false,
				item_instance_id,
			)
	var transfer: InventoryTransferResult = TransferServiceType.new().transfer(
		inventory,
		item_instance_id,
		destination,
	)
	if not transfer.succeeded:
		return ResultType.new(
			ResultType.Outcome.TRANSFER_FAILED,
			false,
			item_instance_id,
			released,
			transfer,
		)
	return ResultType.new(
		ResultType.Outcome.TRANSFERRED,
		true,
		item_instance_id,
		released,
		transfer,
	)
