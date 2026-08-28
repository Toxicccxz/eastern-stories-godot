class_name CombatSliceDeathExecutionResult
extends RefCounted

var _death_inventory_result: DeathInventoryResult
var _second_placement_result: InventoryTransferResult

var death_inventory_result: DeathInventoryResult:
	get: return _death_inventory_result
var second_placement_result: InventoryTransferResult:
	get: return _second_placement_result


func _init(
	p_death_inventory_result: DeathInventoryResult = null,
	p_second_placement_result: InventoryTransferResult = null,
) -> void:
	_death_inventory_result = p_death_inventory_result
	_second_placement_result = p_second_placement_result
