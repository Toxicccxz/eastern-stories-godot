class_name PlayerDeathResult
extends RefCounted

## What PlayerDeathRules.die() took from the player, for the death screen.
var penalized: bool = false
var combat_experience_lost: int = 0
var potential_lost: int = 0
var bellicosity_lost: int = 0
var conditions_cleared: int = 0
var skill_changes: Array[SkillDeathPenaltyChange] = []
## Enabled special skills (enable) that skill_map = 0 disabled.
var enabled_skills_cleared: int = 0
