class_name GameSaveRecoverySource
extends RefCounted

enum Value {
	BACKUP,
	TEMP,
}


static func is_valid(value: int) -> bool:
	return value == Value.BACKUP or value == Value.TEMP
