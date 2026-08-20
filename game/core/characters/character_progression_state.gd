class_name CharacterProgressionState
extends RefCounted

## Minimal persistent progression fields required by cmds/std/selflearn.c.
## Legacy mappings: combat_experience -> combat_exp,
## potential_spent -> learned_points.
var combat_experience: int
var potential: int
var potential_spent: int


func _init(
	p_combat_experience: int = 0,
	p_potential: int = 0,
	p_potential_spent: int = 0,
) -> void:
	combat_experience = p_combat_experience
	potential = p_potential
	potential_spent = p_potential_spent
