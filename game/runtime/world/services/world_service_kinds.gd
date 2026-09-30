class_name WorldServiceKinds
extends RefCounted

## ServiceDefinition.kind → the runtime rules for that kind.
const SCRIPTS: Dictionary[StringName, Script] = {
	&"bank": preload("res://runtime/world/services/bank_service.gd"),
	&"work": preload("res://runtime/world/services/work_service.gd"),
	&"vendor": preload("res://runtime/world/services/vendor_service.gd"),
	&"hockshop": preload("res://runtime/world/services/hockshop_service.gd"),
	&"teacher": preload("res://runtime/world/services/teacher_service.gd"),
}


static func create(kind: StringName) -> WorldService:
	var script: Script = SCRIPTS.get(kind)
	return null if script == null else script.new() as WorldService
