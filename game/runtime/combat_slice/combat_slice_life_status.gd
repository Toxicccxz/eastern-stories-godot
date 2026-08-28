class_name CombatSliceLifeStatus
extends RefCounted

const RuntimeLifeStatusType := preload(
	"res://runtime/characters/character_runtime_life_status.gd"
)

## Compatibility facade for the closed Phase 6 combat-slice API. The shared
## runtime status is now also used by world NPCs; numeric behavior is unchanged.
enum Value {
	ACTIVE = RuntimeLifeStatusType.Value.ACTIVE,
	UNCONSCIOUS = RuntimeLifeStatusType.Value.UNCONSCIOUS,
	DEAD = RuntimeLifeStatusType.Value.DEAD,
}


static func is_valid(value: int) -> bool:
	return RuntimeLifeStatusType.is_valid(value)
