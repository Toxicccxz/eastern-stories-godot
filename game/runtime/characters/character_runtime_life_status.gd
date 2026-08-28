class_name CharacterRuntimeLifeStatus
extends RefCounted

## Committed runtime lifecycle status. This is deliberately independent from
## CharacterState.life_threshold(), which reports current resource evidence.
enum Value {
	ACTIVE,
	UNCONSCIOUS,
	DEAD,
}


static func is_valid(value: int) -> bool:
	return value >= Value.ACTIVE and value <= Value.DEAD
