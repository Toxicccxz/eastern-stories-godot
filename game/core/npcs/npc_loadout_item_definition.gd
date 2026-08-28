class_name NpcLoadoutItemDefinition
extends RefCounted

const ItemDefinitionType := preload("res://core/items/item_definition.gd")
const WeaponDefinitionType := preload("res://core/equipment/weapon_definition.gd")
const StackDefinitionType := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const CurrencyDefinitionType := preload(
	"res://core/items/combined/currency_definition.gd"
)

var _item_definition: ItemDefinitionType
var _own_weight: int
var _weapon_definition: WeaponDefinitionType
var _weapon_damage: int
var _stack_definition: StackDefinitionType
var _currency_definition: CurrencyDefinitionType
var _legacy_source_paths: Array[String] = []

var own_weight: int:
	get:
		return _own_weight
var weapon_damage: int:
	get:
		return _weapon_damage


func _init(
	p_item_definition: ItemDefinitionType = null,
	p_own_weight: int = 0,
	p_weapon_definition: WeaponDefinitionType = null,
	p_weapon_damage: int = 0,
	p_stack_definition: StackDefinitionType = null,
	p_currency_definition: CurrencyDefinitionType = null,
	p_legacy_source_paths: Array[String] = [],
) -> void:
	_item_definition = _copy_item_definition(p_item_definition)
	_own_weight = p_own_weight
	_weapon_definition = _copy_weapon_definition(p_weapon_definition)
	_weapon_damage = p_weapon_damage
	_stack_definition = _copy_stack_definition(p_stack_definition)
	_currency_definition = _copy_currency_definition(p_currency_definition)
	_legacy_source_paths = p_legacy_source_paths.duplicate()


func item_definition() -> ItemDefinitionType:
	return _copy_item_definition(_item_definition)


func weapon_definition() -> WeaponDefinitionType:
	return _copy_weapon_definition(_weapon_definition)


func stack_definition() -> StackDefinitionType:
	return _copy_stack_definition(_stack_definition)


func currency_definition() -> CurrencyDefinitionType:
	return _copy_currency_definition(_currency_definition)


func legacy_source_paths() -> Array[String]:
	return _legacy_source_paths.duplicate()


func is_valid() -> bool:
	if _item_definition == null or _item_definition.item_definition_id.is_empty():
		return false
	if _own_weight < 0 or _weapon_damage < 0 or _legacy_source_paths.is_empty():
		return false
	var definition_id: StringName = _item_definition.item_definition_id
	if _weapon_definition != null and _weapon_definition.weapon_id != definition_id:
		return false
	if _stack_definition != null and _stack_definition.item_definition_id != definition_id:
		return false
	if _currency_definition != null and _currency_definition.item_definition_id != definition_id:
		return false
	return true


func duplicate_snapshot() -> NpcLoadoutItemDefinition:
	return NpcLoadoutItemDefinition.new(
		_item_definition,
		_own_weight,
		_weapon_definition,
		_weapon_damage,
		_stack_definition,
		_currency_definition,
		_legacy_source_paths,
	)


static func _copy_item_definition(value: ItemDefinitionType) -> ItemDefinitionType:
	return (
		null
		if value == null
		else ItemDefinitionType.new(value.item_definition_id, value.legacy_source_path)
	)


static func _copy_weapon_definition(value: WeaponDefinitionType) -> WeaponDefinitionType:
	return (
		null
		if value == null
		else WeaponDefinitionType.new(
			value.weapon_id,
			value.skill_type,
			value.can_wield_as_secondary,
			value.is_two_handed,
			value.legacy_source_path,
		)
	)


static func _copy_stack_definition(value: StackDefinitionType) -> StackDefinitionType:
	return (
		null
		if value == null
		else StackDefinitionType.new(
			value.item_definition_id,
			value.stack_compatibility_id,
			value.base_weight,
		)
	)


static func _copy_currency_definition(value: CurrencyDefinitionType) -> CurrencyDefinitionType:
	return (
		null
		if value == null
		else CurrencyDefinitionType.new(value.item_definition_id, value.base_value)
	)
