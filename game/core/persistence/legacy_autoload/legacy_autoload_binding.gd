class_name LegacyAutoloadBinding
extends RefCounted

enum DecoderKind {
	MONEY,
	BANDAGE,
	MARRY_CARD,
	TOKEN,
	ROOMMAKER,
}

var _legacy_program_path: String
var _item_definition_id: StringName
var _decoder_kind: int
var _initial_own_weight: int

var legacy_program_path: String:
	get: return _legacy_program_path
var item_definition_id: StringName:
	get: return _item_definition_id
var decoder_kind: int:
	get: return _decoder_kind
var initial_own_weight: int:
	get: return _initial_own_weight


func _init(
	p_legacy_program_path: String = "",
	p_item_definition_id: StringName = &"",
	p_decoder_kind: int = DecoderKind.MONEY,
	p_initial_own_weight: int = 0,
) -> void:
	_legacy_program_path = p_legacy_program_path
	_item_definition_id = p_item_definition_id
	_decoder_kind = p_decoder_kind
	_initial_own_weight = p_initial_own_weight


func is_valid() -> bool:
	return (
		_legacy_program_path.length() > 1
		and _legacy_program_path.begins_with("/")
		and _item_definition_id != &""
		and _decoder_kind >= DecoderKind.MONEY
		and _decoder_kind <= DecoderKind.ROOMMAKER
		and _initial_own_weight >= 0
	)


func duplicate_snapshot() -> LegacyAutoloadBinding:
	return LegacyAutoloadBinding.new(
		_legacy_program_path,
		_item_definition_id,
		_decoder_kind,
		_initial_own_weight,
	)
