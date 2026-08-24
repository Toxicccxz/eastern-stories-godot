class_name NativeItemDefinitionProjections
extends RefCounted

## Restore-scoped immutable content projections. This is an explicit caller
## input, not a global ItemCatalog or runtime ItemRepository.
var _is_valid: bool = true
var _items: Dictionary[StringName, ItemDefinition] = {}
var _weapons: Dictionary[StringName, WeaponDefinition] = {}
var _armor: Dictionary[StringName, ArmorDefinition] = {}
var _stacks: Dictionary[StringName, CombinedStackDefinition] = {}

var is_valid: bool:
	get:
		return _is_valid


func _init(
	p_items: Array[ItemDefinition] = [],
	p_weapons: Array[WeaponDefinition] = [],
	p_armor: Array[ArmorDefinition] = [],
	p_stacks: Array[CombinedStackDefinition] = [],
) -> void:
	for definition: ItemDefinition in p_items:
		if (
			definition == null
			or definition.item_definition_id == &""
			or _items.has(definition.item_definition_id)
		):
			_is_valid = false
			continue
		_items[definition.item_definition_id] = ItemDefinition.new(
			definition.item_definition_id,
			definition.legacy_source_path,
		)
	for definition: WeaponDefinition in p_weapons:
		if (
			definition == null
			or definition.weapon_id == &""
			or not _items.has(definition.weapon_id)
			or _weapons.has(definition.weapon_id)
		):
			_is_valid = false
			continue
		_weapons[definition.weapon_id] = _copy_weapon(definition)
	for definition: ArmorDefinition in p_armor:
		if (
			definition == null
			or not definition.has_valid_identity()
			or definition.armor_type == &""
			or not _items.has(definition.item_definition_id)
			or _armor.has(definition.item_definition_id)
		):
			_is_valid = false
			continue
		_armor[definition.item_definition_id] = _copy_armor(definition)
	for definition: CombinedStackDefinition in p_stacks:
		if (
			definition == null
			or not definition.is_valid()
			or not _items.has(definition.item_definition_id)
			or _stacks.has(definition.item_definition_id)
		):
			_is_valid = false
			continue
		_stacks[definition.item_definition_id] = _copy_stack(definition)


func has_item_definition(item_definition_id: StringName) -> bool:
	return item_definition_id != &"" and _items.has(item_definition_id)


func item_definition(item_definition_id: StringName) -> ItemDefinition:
	var definition: ItemDefinition = _items.get(item_definition_id)
	return (
		null
		if definition == null
		else ItemDefinition.new(
			definition.item_definition_id,
			definition.legacy_source_path,
		)
	)


func weapon_definition(item_definition_id: StringName) -> WeaponDefinition:
	var definition: WeaponDefinition = _weapons.get(item_definition_id)
	return null if definition == null else _copy_weapon(definition)


func armor_definition(item_definition_id: StringName) -> ArmorDefinition:
	var definition: ArmorDefinition = _armor.get(item_definition_id)
	return null if definition == null else _copy_armor(definition)


func stack_definition(item_definition_id: StringName) -> CombinedStackDefinition:
	var definition: CombinedStackDefinition = _stacks.get(item_definition_id)
	return null if definition == null else _copy_stack(definition)


func _copy_weapon(definition: WeaponDefinition) -> WeaponDefinition:
	return WeaponDefinition.new(
		definition.weapon_id,
		definition.skill_type,
		definition.can_wield_as_secondary,
		definition.is_two_handed,
		definition.legacy_source_path,
	)


func _copy_armor(definition: ArmorDefinition) -> ArmorDefinition:
	return ArmorDefinition.new(
		definition.item_definition_id,
		definition.armor_type,
		definition.numeric_modifiers,
	)


func _copy_stack(definition: CombinedStackDefinition) -> CombinedStackDefinition:
	return CombinedStackDefinition.new(
		definition.item_definition_id,
		definition.stack_compatibility_id,
		definition.base_weight,
	)
