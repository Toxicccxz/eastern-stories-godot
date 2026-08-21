class_name TeacherDefinition
extends RefCounted

const TeachingOfferType := preload("res://core/learning/teaching_offer.gd")

## Immutable authored teaching metadata. Current spirit, intelligence, and
## skill levels belong to TeachingContext, never to this shared definition.
var _teacher_id: StringName
var _legacy_source_path: String
var _legacy_primary_id: String
var _legacy_display_name: String
var _offers: Array[TeachingOfferType] = []

var teacher_id: StringName:
	get:
		return _teacher_id

var legacy_source_path: String:
	get:
		return _legacy_source_path

var legacy_primary_id: String:
	get:
		return _legacy_primary_id

var legacy_display_name: String:
	get:
		return _legacy_display_name


func _init(
	p_teacher_id: StringName = &"",
	p_offers: Array[TeachingOfferType] = [],
	p_legacy_source_path: String = "",
	p_legacy_primary_id: String = "",
	p_legacy_display_name: String = "",
) -> void:
	_teacher_id = p_teacher_id
	_offers = []
	for offer: TeachingOfferType in p_offers:
		_offers.append(TeachingOfferType.new(offer.skill_id))
	_legacy_source_path = p_legacy_source_path
	_legacy_primary_id = p_legacy_primary_id
	_legacy_display_name = p_legacy_display_name


func has_offer(skill_id: StringName) -> bool:
	for offer: TeachingOfferType in _offers:
		if offer.skill_id == skill_id:
			return true
	return false


func offer_count() -> int:
	return _offers.size()
