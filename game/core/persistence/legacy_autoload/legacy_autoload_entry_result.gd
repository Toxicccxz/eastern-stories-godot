class_name LegacyAutoloadEntryResult
extends RefCounted

const EntryType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry.gd"
)

enum Outcome {
	IMPORTED_MONEY,
	IMPORTED_MONEY_ZERO_PENDING_DESTRUCTION,
	IMPORTED_BANDAGE_WORN,
	IMPORTED_BANDAGE_UNWORN_SLOT_COLLISION,
	IMPORTED_MARRY_CARD_WITH_DEFERRED_RUNTIME_EFFECT,
	UNSUPPORTED_TOKEN_EXECUTABLE_DEFECT,
	UNSUPPORTED_ROOMMAKER_DRIVER_AMBIGUITY,
	UNKNOWN_LEGACY_PATH,
	INVALID_ENTRY_PARSE,
	INVALID_INSTANCE_ID_PLAN,
	MAPPED_DEFINITION_UNAVAILABLE,
	INVALID_MONEY_PARAMETER,
	UNSUPPORTED_MONEY_PARAMETER_DRIVER_AMBIGUITY,
	MONEY_DEFINITION_NOT_STACK_CAPABLE,
	INVALID_BANDAGE_PARAMETER,
	INVALID_BANDAGE_ARMOR_DEFINITION,
	INVALID_MARRY_CARD_PARAMETER,
}

var _legacy_index: int
var _original_entry: String
var _item_instance_id: StringName
var _entry: EntryType
var _outcome: int
var _item_definition_id: StringName
var _decoder_kind: int

var legacy_index: int:
	get: return _legacy_index
var original_entry: String:
	get: return _original_entry
var item_instance_id: StringName:
	get: return _item_instance_id
var entry: EntryType:
	get: return null if _entry == null else _entry.duplicate_snapshot()
var outcome: int:
	get: return _outcome
var item_definition_id: StringName:
	get: return _item_definition_id
var decoder_kind: int:
	get: return _decoder_kind


func _init(
	p_legacy_index: int = -1,
	p_original_entry: String = "",
	p_item_instance_id: StringName = &"",
	p_entry: EntryType = null,
	p_outcome: int = Outcome.INVALID_ENTRY_PARSE,
	p_item_definition_id: StringName = &"",
	p_decoder_kind: int = -1,
) -> void:
	_legacy_index = p_legacy_index
	_original_entry = p_original_entry
	_item_instance_id = p_item_instance_id
	_entry = null if p_entry == null else p_entry.duplicate_snapshot()
	_outcome = p_outcome
	_item_definition_id = p_item_definition_id
	_decoder_kind = p_decoder_kind
