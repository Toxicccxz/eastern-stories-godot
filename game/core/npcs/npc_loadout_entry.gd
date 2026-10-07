class_name NpcLoadoutEntry
extends RefCounted

enum EquipmentIntent {
	NONE,
	WIELD_PRIMARY,
	WEAR,
}

var _item_definition_id: StringName
var _quantity: int
var _equipment_intent: int
var _legacy_source_path: String
## add_money(id, b + random(n)): the amount create() draws (green's children); null
## when the amount is fixed. Only a stack (money) may have one.
var _amount_roll: NpcRandomInteger
## `if (random(bound) < below) carry this else carry _alternative` (worker2.c's hammer
## or rope); 0 when the entry is always carried.
var _choice_bound: int = 0
var _choice_below: int = 0
var _alternative: NpcLoadoutEntry

var item_definition_id: StringName:
	get:
		return _item_definition_id
var quantity: int:
	get:
		return _quantity
var equipment_intent: int:
	get:
		return _equipment_intent
var legacy_source_path: String:
	get:
		return _legacy_source_path


func _init(
	p_item_definition_id: StringName = &"",
	p_quantity: int = 0,
	p_equipment_intent: int = EquipmentIntent.NONE,
	p_legacy_source_path: String = "",
) -> void:
	_item_definition_id = p_item_definition_id
	_quantity = p_quantity
	_equipment_intent = p_equipment_intent
	_legacy_source_path = p_legacy_source_path


func amount_roll() -> NpcRandomInteger:
	return _amount_roll


func with_amount_roll(roll: NpcRandomInteger) -> NpcLoadoutEntry:
	_amount_roll = roll
	if roll != null:
		_quantity = roll.base
	return self


## Carried only when random(bound) < below; else `alternative` is.
func with_choice(bound: int, below: int, alternative: NpcLoadoutEntry) -> NpcLoadoutEntry:
	_choice_bound = bound
	_choice_below = below
	_alternative = alternative
	return self


func is_choice() -> bool:
	return _alternative != null


func alternative() -> NpcLoadoutEntry:
	return _alternative


var choice_bound: int:
	get: return _choice_bound


## This entry or its alternative, for random(choice_bound) == `draw`; null out of range.
func chosen(draw: int) -> NpcLoadoutEntry:
	if _alternative == null:
		return self
	if draw < 0 or draw >= _choice_bound:
		return null
	return self if draw < _choice_below else _alternative


## Every item the entry may put on the NPC (both sides of a choice).
func possible_entries() -> Array[NpcLoadoutEntry]:
	var result: Array[NpcLoadoutEntry] = [self]
	if _alternative != null:
		result.append(_alternative)
	return result


func is_valid() -> bool:
	if _alternative != null and (_choice_bound <= 0 or not _alternative.is_valid() or _alternative.is_choice()):
		return false
	if _amount_roll != null and not _amount_roll.is_valid():
		return false
	return (
		not _item_definition_id.is_empty()
		and _quantity > 0
		and _equipment_intent >= EquipmentIntent.NONE
		and _equipment_intent <= EquipmentIntent.WEAR
		and not _legacy_source_path.is_empty()
	)


func duplicate_snapshot() -> NpcLoadoutEntry:
	var copy := NpcLoadoutEntry.new(
		_item_definition_id,
		_quantity,
		_equipment_intent,
		_legacy_source_path,
	)
	copy._amount_roll = _amount_roll
	copy._choice_bound = _choice_bound
	copy._choice_below = _choice_below
	copy._alternative = null if _alternative == null else _alternative.duplicate_snapshot()
	return copy
