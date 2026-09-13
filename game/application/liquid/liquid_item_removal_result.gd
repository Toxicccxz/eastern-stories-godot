class_name LiquidItemRemovalResult
extends RefCounted

var removal: ItemLifecycleResult
var liquid_forgotten: bool = false
var index_forgotten: bool = false


func succeeded() -> bool:
	return removal != null and removal.succeeded and liquid_forgotten and index_forgotten
