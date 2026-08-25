class_name DeathItemFacts
extends RefCounted

const ArmorDefinitionType := preload("res://core/armor/armor_definition.gd")
const ItemInstanceType := preload("res://core/items/item_instance.gd")

var _item_instance_id: StringName
var _item_definition_id: StringName
var _armor_definition: ArmorDefinitionType

var item_instance_id: StringName:
	get: return _item_instance_id
var item_definition_id: StringName:
	get: return _item_definition_id
var armor_definition: ArmorDefinitionType:
	get:
		return (
			null
			if _armor_definition == null
			else ArmorDefinitionType.new(
				_armor_definition.item_definition_id,
				_armor_definition.armor_type,
				_armor_definition.numeric_modifiers,
			)
		)


func _init(
	p_item: ItemInstanceType = null,
	p_armor_definition: ArmorDefinitionType = null,
) -> void:
	## Bind the definition projection to one immutable ItemInstance snapshot.
	## Callers cannot pair one live instance ID with a separately supplied
	## definition ID when evaluating authored death policy.
	_item_instance_id = &"" if p_item == null else p_item.item_instance_id
	_item_definition_id = &"" if p_item == null else p_item.item_definition_id
	_armor_definition = (
		null
		if p_armor_definition == null
		else ArmorDefinitionType.new(
			p_armor_definition.item_definition_id,
			p_armor_definition.armor_type,
			p_armor_definition.numeric_modifiers,
		)
	)


func has_valid_identity() -> bool:
	return _item_instance_id != &"" and _item_definition_id != &""


func has_aligned_armor_definition() -> bool:
	return (
		_armor_definition != null
		and _armor_definition.has_valid_identity()
		and _armor_definition.item_definition_id == _item_definition_id
		and _armor_definition.armor_type != &""
	)
