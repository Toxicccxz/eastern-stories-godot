class_name ArmorDefinition
extends RefCounted

const ArmorNumericModifiersType := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)

## Immutable authored armor facts. Identity matches ItemDefinitionId; slot IDs
## remain open StringName values exactly as authored by armor_type.
var _item_definition_id: StringName
var _armor_type: StringName
var _numeric_modifiers: ArmorNumericModifiersType

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
	p_item_definition_id: StringName = &"",
	p_armor_type: StringName = &"",
	p_numeric_modifiers: ArmorNumericModifiersType = null,
) -> void:
	_item_definition_id = p_item_definition_id
	_armor_type = p_armor_type
	_numeric_modifiers = (
		ArmorNumericModifiersType.new()
		if p_numeric_modifiers == null
		else p_numeric_modifiers.duplicate_snapshot()
	)


func has_valid_identity() -> bool:
	return _item_definition_id != &""
