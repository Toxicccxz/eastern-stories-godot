class_name CombatEncounterMode
extends RefCounted

enum Value {
	SPAR,
	LETHAL,
	SCRIPTED,
	## 战斗拍数 D: a guide's three harmless rounds (a spar whose blows draw no blood, ended
	## by the round count, not a hit; DECISIONS「战斗拍数 D」).
	LESSON,
}


static func is_valid(value: int) -> bool:
	return value >= Value.SPAR and value <= Value.LESSON
