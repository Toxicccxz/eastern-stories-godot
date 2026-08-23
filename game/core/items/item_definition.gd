class_name ItemDefinition
extends RefCounted

## Immutable native definition identity. Authored item facts and runtime state
## are deliberately deferred beyond Phase 4B1.
var _item_definition_id: StringName
var _legacy_source_path: String

var item_definition_id: StringName:
	get:
		return _item_definition_id

var legacy_source_path: String:
	get:
		return _legacy_source_path


func _init(
	p_item_definition_id: StringName = &"",
	p_legacy_source_path: String = "",
) -> void:
	_item_definition_id = p_item_definition_id
	_legacy_source_path = p_legacy_source_path
