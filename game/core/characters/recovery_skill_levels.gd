class_name RecoverySkillLevels
extends RefCounted

## Minimal raw-skill snapshot needed by feature/damage.c::heal_up(). These are
## deliberately not effective or mapped skill levels and are not a SkillSystem.
var raw_magic: int
var raw_force: int
var raw_spells: int


func _init(p_raw_magic: int = 0, p_raw_force: int = 0, p_raw_spells: int = 0) -> void:
	raw_magic = p_raw_magic
	raw_force = p_raw_force
	raw_spells = p_raw_spells
