class_name ArmorService
extends RefCounted

const ArmorDefinitionType := preload("res://core/armor/armor_definition.gd")
const EquippedArmorRefType := preload("res://core/armor/equipped_armor_ref.gd")
const ArmorStateType := preload("res://core/armor/armor_state.gd")
const ArmorTransitionResultType := preload(
	"res://core/armor/armor_transition_result.gd"
)
const ContainmentEndpointType := preload(
	"res://core/inventory/containment_endpoint.gd"
)
const InventoryStateType := preload("res://core/inventory/inventory_state.gd")
const ItemInstanceType := preload("res://core/items/item_instance.gd")


## Normal low-level wear orchestration. Command gates such as female_only and
## presentation strings remain outside this service.
static func wear(
	armor_state: ArmorStateType,
	inventory: InventoryStateType,
	direct_owner: ContainmentEndpointType,
	item: ItemInstanceType,
	definition: ArmorDefinitionType,
) -> ArmorTransitionResultType:
	if armor_state == null:
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.INVALID_ARMOR_STATE,
		)
	if item == null or item.item_instance_id == &"" or item.item_definition_id == &"":
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.INVALID_ITEM_INSTANCE,
			false,
			false,
			&"" if item == null else item.item_instance_id,
		)
	if definition == null or not definition.has_valid_identity():
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.INVALID_ARMOR_DEFINITION,
			false,
			false,
			item.item_instance_id,
		)
	if item.item_definition_id != definition.item_definition_id:
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.DEFINITION_MISMATCH,
			false,
			false,
			item.item_instance_id,
			definition.item_definition_id,
			definition.armor_type,
		)
	## feature/equip.c verifies the direct environment is a character before
	## recognizing an existing equipped marker.
	if (
		inventory == null
		or direct_owner == null
		or not direct_owner.is_valid()
		or direct_owner.kind != ContainmentEndpointType.Kind.CHARACTER
		or not inventory.is_registered(item.item_instance_id)
		or not inventory.is_direct_child(item.item_instance_id, direct_owner)
	):
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.ITEM_NOT_DIRECTLY_OWNED,
			false,
			false,
			item.item_instance_id,
			definition.item_definition_id,
			definition.armor_type,
		)
	## The LPC equipped marker short-circuits before armor_prop/type checks.
	if armor_state.is_worn(item.item_instance_id):
		var existing: EquippedArmorRefType = armor_state.equipped_ref_for_instance(
			item.item_instance_id
		)
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.ALREADY_WORN,
			true,
			false,
			existing.item_instance_id,
			existing.item_definition_id,
			existing.armor_type,
			existing.numeric_modifiers,
		)
	if definition.armor_type == &"":
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.INVALID_ARMOR_SLOT,
			false,
			false,
			item.item_instance_id,
			definition.item_definition_id,
		)
	return armor_state._apply_wear(
		EquippedArmorRefType.new(item.item_instance_id, definition)
	)
