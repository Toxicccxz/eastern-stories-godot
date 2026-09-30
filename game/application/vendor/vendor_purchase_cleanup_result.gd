class_name VendorPurchaseCleanupResult
extends RefCounted

var removal: ItemLifecycleResult
var food_forgotten: bool = false
var liquid_forgotten: bool = false
var index_forgotten: bool = false


func succeeded() -> bool:
	return removal != null and removal.succeeded and food_forgotten and liquid_forgotten and index_forgotten
