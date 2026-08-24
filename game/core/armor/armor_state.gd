class_name ArmorState
extends RefCounted

const EquippedArmorRefType := preload("res://core/armor/equipped_armor_ref.gd")
const ArmorNumericModifiersType := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)
const ArmorTransitionResultType := preload(
	"res://core/armor/armor_transition_result.gd"
)

## Native authority replacing character temp armor/<armor_type> references.
## The slot map is private and all references returned to callers are copies.
var _equipped_by_slot: Dictionary[StringName, EquippedArmorRef] = {}


func is_slot_occupied(armor_type: StringName) -> bool:
	return armor_type != &"" and _equipped_by_slot.has(armor_type)


func item_instance_id_in_slot(armor_type: StringName) -> StringName:
	var reference: EquippedArmorRefType = _equipped_by_slot.get(armor_type)
	return &"" if reference == null else reference.item_instance_id


func equipped_ref_in_slot(armor_type: StringName) -> EquippedArmorRefType:
	var reference: EquippedArmorRefType = _equipped_by_slot.get(armor_type)
	return null if reference == null else reference.duplicate_snapshot()


func equipped_ref_for_instance(item_instance_id: StringName) -> EquippedArmorRefType:
	var slot: StringName = slot_for_instance(item_instance_id)
	return null if slot == &"" else equipped_ref_in_slot(slot)


func slot_for_instance(item_instance_id: StringName) -> StringName:
	if item_instance_id == &"":
		return &""
	for armor_type: StringName in _equipped_by_slot:
		var reference: EquippedArmorRefType = _equipped_by_slot[armor_type]
		if reference.item_instance_id == item_instance_id:
			return armor_type
	return &""


func is_worn(item_instance_id: StringName) -> bool:
	return slot_for_instance(item_instance_id) != &""


func occupied_slots() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_equipped_by_slot.keys())
	result.sort_custom(_string_name_less_than)
	return result


## Internal transition seam used by ArmorService after direct-ownership and
## definition checks. The leading underscore prevents callers from treating
## ArmorState as an authorization boundary.
func _apply_wear(reference: EquippedArmorRefType) -> ArmorTransitionResultType:
	if reference == null or reference.item_instance_id == &"":
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.INVALID_ITEM_INSTANCE,
			false,
			false,
			&"" if reference == null else reference.item_instance_id,
		)
	if reference.item_definition_id == &"":
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.INVALID_ARMOR_DEFINITION,
			false,
			false,
			reference.item_instance_id,
		)
	if reference.armor_type == &"":
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.INVALID_ARMOR_SLOT,
			false,
			false,
			reference.item_instance_id,
			reference.item_definition_id,
		)
	if is_worn(reference.item_instance_id):
		var existing: EquippedArmorRefType = equipped_ref_for_instance(
			reference.item_instance_id
		)
		return _result_from_ref(
			ArmorTransitionResultType.Outcome.ALREADY_WORN,
			true,
			false,
			existing,
		)
	if is_slot_occupied(reference.armor_type):
		return _result_from_ref(
			ArmorTransitionResultType.Outcome.SLOT_OCCUPIED,
			false,
			false,
			reference,
		)
	_equipped_by_slot[reference.armor_type] = reference.duplicate_snapshot()
	return _result_from_ref(
		ArmorTransitionResultType.Outcome.WORN,
		true,
		true,
		reference,
	)


## feature/equip.c removes the exact object reference and never moves it.
func remove(item_instance_id: StringName) -> ArmorTransitionResultType:
	var armor_type: StringName = slot_for_instance(item_instance_id)
	if armor_type == &"":
		return ArmorTransitionResultType.new(
			ArmorTransitionResultType.Outcome.NOT_WORN,
			false,
			false,
			item_instance_id,
		)
	var removed: EquippedArmorRefType = _equipped_by_slot[armor_type]
	## The reference (legacy armor/<type>) is removed first. With a derived
	## aggregate, erasing it also removes exactly its immutable contribution.
	_equipped_by_slot.erase(armor_type)
	return _result_from_ref(
		ArmorTransitionResultType.Outcome.REMOVED,
		true,
		true,
		removed,
	)


func aggregate_numeric_modifiers() -> ArmorNumericModifiersType:
	var result: ArmorNumericModifiersType = ArmorNumericModifiersType.new()
	for armor_type: StringName in occupied_slots():
		var reference: EquippedArmorRefType = _equipped_by_slot[armor_type]
		result = result.added(reference.numeric_modifiers)
	return result


func _result_from_ref(
	outcome: int,
	succeeded: bool,
	changed: bool,
	reference: EquippedArmorRefType,
) -> ArmorTransitionResultType:
	return ArmorTransitionResultType.new(
		outcome,
		succeeded,
		changed,
		reference.item_instance_id,
		reference.item_definition_id,
		reference.armor_type,
		reference.numeric_modifiers,
	)


func _string_name_less_than(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
