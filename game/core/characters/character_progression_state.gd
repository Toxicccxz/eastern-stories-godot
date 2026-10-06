class_name CharacterProgressionState
extends RefCounted

## Minimal persistent progression fields required by cmds/std/selflearn.c.
## Legacy mappings: combat_experience -> combat_exp,
## potential_spent -> learned_points.
var combat_experience: int
var potential: int
var potential_spent: int
## query("score") (综合评价): betrayal (recruit.c) sets it to 0.
var score: int
## query("MKS"): NPCs killed (combatd.c killer_reward()).
var kills: int


func _init(
	p_combat_experience: int = 0,
	p_potential: int = 0,
	p_potential_spent: int = 0,
	p_score: int = 0,
	p_kills: int = 0,
) -> void:
	combat_experience = p_combat_experience
	potential = p_potential
	potential_spent = p_potential_spent
	score = p_score
	kills = p_kills
