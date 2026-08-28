class_name WorldInteractionTarget
extends RefCounted

enum Kind {
	INVALID,
	CHARACTER,
	LANDMARK,
}

var _kind: int
var _target_id: StringName

var kind: int:
	get:
		return _kind
var target_id: StringName:
	get:
		return _target_id


func _init(p_kind: int = Kind.INVALID, p_target_id: StringName = &"") -> void:
	_kind = p_kind
	_target_id = p_target_id


func is_valid() -> bool:
	return _kind in [Kind.CHARACTER, Kind.LANDMARK] and not _target_id.is_empty()


static func character(character_id: StringName) -> WorldInteractionTarget:
	return WorldInteractionTarget.new(Kind.CHARACTER, character_id)


static func landmark(landmark_id: StringName) -> WorldInteractionTarget:
	return WorldInteractionTarget.new(Kind.LANDMARK, landmark_id)
