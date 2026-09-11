class_name PlayerIdentityFacts
extends RefCounted

## One narrow Player identity authority; gender remains in CharacterState.
## NGE1 supports Human only, not a race registry or aging system.
const HUMAN_RACE_ID: StringName = &"human"

var _display_name: String
var _title: String
var _age: int

var display_name: String:
	get: return _display_name
var title: String:
	get: return _title
var age: int:
	get: return _age
var race_id: StringName:
	get: return HUMAN_RACE_ID


func _init(p_display_name: String, p_title: String, p_age: int) -> void:
	_display_name = p_display_name
	_title = p_title
	_age = p_age


func is_valid() -> bool:
	return not _display_name.strip_edges().is_empty() and _age >= 0


static func legacy_technical() -> PlayerIdentityFacts:
	# Current pre-cutover technical New Game identity, not a save fallback.
	return PlayerIdentityFacts.new("Player", "", 20)


func is_legacy_technical() -> bool:
	return _display_name == "Player" and _title.is_empty() and _age == 20
