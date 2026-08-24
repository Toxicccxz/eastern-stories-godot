class_name EquippedArmorRef
extends RefCounted

const ArmorDefinitionType := preload("res://core/armor/armor_definition.gd")
const ArmorNumericModifiersType := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)

## Stable runtime identity plus the immutable definition facts needed to
## reverse a worn contribution without a catalog/repository lookup.
var _item_instance_id: StringName
var _item_definition_id: StringName
var _armor_type: StringName
var _numeric_modifiers: ArmorNumericModifiersType

var item_instance_id: StringName:
	get:
		return _item_instance_id
var item_definition_id: StringName:
	get:
		return _item_definition_id
var armor_type: StringName:
	get:
		return _armor_type
var numeric_modifiers: ArmorNumericModifiersType:
	get:
		return _numeric_modifiers.duplicate_snapshot()


func _init(
	p_item_instance_id: StringName = &"",
	p_definition: ArmorDefinitionType = null,
) -> void:
	_item_instance_id = p_item_instance_id
	if p_definition == null:
		_item_definition_id = &""
		_armor_type = &""
		_numeric_modifiers = ArmorNumericModifiersType.new()
		return
	_item_definition_id = p_definition.item_definition_id
	_armor_type = p_definition.armor_type
	_numeric_modifiers = p_definition.numeric_modifiers


func is_valid() -> bool:
	return (
		_item_instance_id != &""
		and _item_definition_id != &""
		and _armor_type != &""
	)


func duplicate_snapshot() -> EquippedArmorRef:
	var snapshot: EquippedArmorRef = EquippedArmorRef.new()
	snapshot._item_instance_id = _item_instance_id
	snapshot._item_definition_id = _item_definition_id
	snapshot._armor_type = _armor_type
	snapshot._numeric_modifiers = _numeric_modifiers.duplicate_snapshot()
	return snapshot
