class_name NpcBaseAttributeOverrides
extends RefCounted

var _has_strength: bool
var _strength: int
var _has_courage: bool
var _courage: int
var _has_intelligence: bool
var _intelligence: int
var _has_spirituality: bool
var _spirituality: int
var _has_composure: bool
var _composure: int
var _has_personality: bool
var _personality: int
var _has_constitution: bool
var _constitution: int
var _has_karma: bool
var _karma: int


func _init(
	p_has_strength: bool = false,
	p_strength: int = 0,
	p_has_courage: bool = false,
	p_courage: int = 0,
	p_has_intelligence: bool = false,
	p_intelligence: int = 0,
	p_has_spirituality: bool = false,
	p_spirituality: int = 0,
	p_has_composure: bool = false,
	p_composure: int = 0,
	p_has_personality: bool = false,
	p_personality: int = 0,
	p_has_constitution: bool = false,
	p_constitution: int = 0,
	p_has_karma: bool = false,
	p_karma: int = 0,
) -> void:
	_has_strength = p_has_strength
	_strength = p_strength
	_has_courage = p_has_courage
	_courage = p_courage
	_has_intelligence = p_has_intelligence
	_intelligence = p_intelligence
	_has_spirituality = p_has_spirituality
	_spirituality = p_spirituality
	_has_composure = p_has_composure
	_composure = p_composure
	_has_personality = p_has_personality
	_personality = p_personality
	_has_constitution = p_has_constitution
	_constitution = p_constitution
	_has_karma = p_has_karma
	_karma = p_karma


func has_strength() -> bool:
	return _has_strength


func strength() -> int:
	return _strength


func has_courage() -> bool:
	return _has_courage


func courage() -> int:
	return _courage


func has_intelligence() -> bool:
	return _has_intelligence


func intelligence() -> int:
	return _intelligence


func has_spirituality() -> bool:
	return _has_spirituality


func spirituality() -> int:
	return _spirituality


func has_composure() -> bool:
	return _has_composure


func composure() -> int:
	return _composure


func has_personality() -> bool:
	return _has_personality


func personality() -> int:
	return _personality


func has_constitution() -> bool:
	return _has_constitution


func constitution() -> int:
	return _constitution


func has_karma() -> bool:
	return _has_karma


func karma() -> int:
	return _karma


func is_empty() -> bool:
	return not (
		_has_strength
		or _has_courage
		or _has_intelligence
		or _has_spirituality
		or _has_composure
		or _has_personality
		or _has_constitution
		or _has_karma
	)


func duplicate_snapshot() -> NpcBaseAttributeOverrides:
	return NpcBaseAttributeOverrides.new(
		_has_strength, _strength,
		_has_courage, _courage,
		_has_intelligence, _intelligence,
		_has_spirituality, _spirituality,
		_has_composure, _composure,
		_has_personality, _personality,
		_has_constitution, _constitution,
		_has_karma, _karma,
	)
