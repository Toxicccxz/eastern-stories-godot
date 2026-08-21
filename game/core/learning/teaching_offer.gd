class_name TeachingOffer
extends RefCounted

var _skill_id: StringName

var skill_id: StringName:
	get:
		return _skill_id


func _init(p_skill_id: StringName = &"") -> void:
	_skill_id = p_skill_id
