class_name WorldContentRevision
extends RefCounted

## Versioned world contract, independent of save schema and Session bootstrap mode.
enum Value { LEGACY_OLDPINE_V1, SOURCE_ENTRY_V1 }

static func is_supported(value: Value) -> bool:
	return value in [Value.LEGACY_OLDPINE_V1, Value.SOURCE_ENTRY_V1]

static func serialized(value: Value) -> String:
	match value:
		Value.LEGACY_OLDPINE_V1: return "LEGACY_OLDPINE_V1"
		Value.SOURCE_ENTRY_V1: return "SOURCE_ENTRY_V1"
	return ""
