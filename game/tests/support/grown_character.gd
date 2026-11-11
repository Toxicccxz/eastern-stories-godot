extends RefCounted

## TEST-ONLY: a character grown to a combat_exp the way a player who follows the story grows
## (DECISIONS「考验三招」), for the suites and probes that measure a fight or a trial against
## the region's recommended_exp instead of a character made unbeatable:
## - potential: progression.json's potential_percent of the exp, spread evenly over seven
##   skills — 柳家拳 on unarmed, 倒乱七星步 on dodge, 封山派内功 on force (each pair two skills)
##   and parry (`sword`: 封山剑法 on sword and parry in 柳家拳's place, for a sword in hand);
## - each skill's raw level is what that potential buys on average (learn.c: random(int +
##   exp / (1000 + exp / 1000)) points a 请教, a level up past (level + 1)^2 points, so about
##   level^3 / 3 points to reach it), no higher than learn.c's gate (level^3 / 10 <= exp);
## - max_force: `force_percent` of exercise.c's cap for that force (half by default: about an
##   hour of 打坐 at 10000 exp), the force full, kee and the rest at their age-14 maxima.
## Nothing is put in the hand: New Game's player is unarmed, and a sword is the caller's.

const PAIRS: Array[Array] = [
	[&"unarmed", &"liuh-ken"],
	[&"dodge", &"chaos-steps"],
	[&"force", &"fonxanforce"],
	[&"parry", &""],
]
const SWORD_PAIRS: Array[Array] = [
	[&"sword", &"fonxansword"],
	[&"dodge", &"chaos-steps"],
	[&"force", &"fonxanforce"],
	[&"parry", &"fonxansword"],
]
const SKILLS: int = 7
const INTELLIGENCE: int = 30
const AGE: int = 14


## The raw level each of the seven skills reaches at `experience`.
static func level_for(experience: int) -> int:
	@warning_ignore("integer_division")
	var potential: float = float(experience * GameContent.catalog().progression().potential_percent / 100) / float(SKILLS)
	@warning_ignore("integer_division")
	var mean_points: float = float(INTELLIGENCE + experience / (1000 + experience / 1000)) / 2.0
	var level: int = int(pow(3.0 * potential * mean_points, 1.0 / 3.0))
	while level > 0 and LearnService.required_combat_experience(level) > experience:
		level -= 1
	return level


static func grow(state: CharacterState, experience: int, force_percent: int = 50, sword: bool = false) -> void:
	state.progression.combat_experience = experience
	var level: int = level_for(experience)
	for pair: Array in SWORD_PAIRS if sword else PAIRS:
		state.skills.set_raw_level(pair[0], level)
		if not (pair[1] as StringName).is_empty():
			state.skills.set_raw_level(pair[1], level)
			state.skills.map_skill(pair[0], pair[1])
	@warning_ignore("integer_division")
	var max_force: int = CultivationService.exercise_cap(state) * force_percent / 100
	state.recovery.inner_force.maximum = max_force
	state.recovery.inner_force.current = max_force
	CharacterDerivedValues.refresh_human_player_maxima(state, AGE)
	heal(state)


static func heal(state: CharacterState) -> void:
	state.conditions.clear()
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	state.recovery.inner_force.current = state.recovery.inner_force.maximum
