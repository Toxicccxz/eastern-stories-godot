class_name LegacyAutoloadImportPlan
extends RefCounted

var _character_id: StringName
var _legacy_entries: Array[String] = []
var _item_instance_ids: Array[StringName] = []

var character_id: StringName:
	get: return _character_id
var legacy_entries: Array[String]:
	get: return _legacy_entries.duplicate()
var item_instance_ids: Array[StringName]:
	get: return _item_instance_ids.duplicate()


func _init(
	p_character_id: StringName = &"",
	p_legacy_entries: Array[String] = [],
	p_item_instance_ids: Array[StringName] = [],
) -> void:
	_character_id = p_character_id
	_legacy_entries = p_legacy_entries.duplicate()
	_item_instance_ids = p_item_instance_ids.duplicate()
