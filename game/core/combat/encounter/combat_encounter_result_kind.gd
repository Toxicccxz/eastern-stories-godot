class_name CombatEncounterResultKind
extends RefCounted

enum Value {
	VICTORY,
	DEFEAT,
	SPAR_CONCLUDED,
	FLED,
	SCRIPTED,
	FAILED_TO_ESTABLISH,
	## An attack chain or lifecycle failed mid-fight: the fight ends where it stood.
	ABORTED,
	## 战斗拍数 D: a guide's lesson ran its rounds (CombatEncounterMode.LESSON).
	LESSON_CONCLUDED,
}


static func is_valid(value: int) -> bool:
	return value >= Value.VICTORY and value <= Value.LESSON_CONCLUDED
