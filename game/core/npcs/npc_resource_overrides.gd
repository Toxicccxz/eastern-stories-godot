class_name NpcResourceOverrides
extends RefCounted

const TrackOverrideType := preload("res://core/npcs/npc_resource_track_override.gd")

var _essence: TrackOverrideType
var _vitality: TrackOverrideType
var _spirit: TrackOverrideType


func _init(
	p_essence: TrackOverrideType = null,
	p_vitality: TrackOverrideType = null,
	p_spirit: TrackOverrideType = null,
) -> void:
	_essence = (
		TrackOverrideType.new()
		if p_essence == null
		else p_essence.duplicate_snapshot()
	)
	_vitality = (
		TrackOverrideType.new()
		if p_vitality == null
		else p_vitality.duplicate_snapshot()
	)
	_spirit = (
		TrackOverrideType.new()
		if p_spirit == null
		else p_spirit.duplicate_snapshot()
	)


func essence() -> TrackOverrideType:
	return _essence.duplicate_snapshot()


func vitality() -> TrackOverrideType:
	return _vitality.duplicate_snapshot()


func spirit() -> TrackOverrideType:
	return _spirit.duplicate_snapshot()


func is_empty() -> bool:
	return _essence.is_empty() and _vitality.is_empty() and _spirit.is_empty()


func duplicate_snapshot() -> NpcResourceOverrides:
	return NpcResourceOverrides.new(_essence, _vitality, _spirit)
