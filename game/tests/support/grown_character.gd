extends RefCounted

## TEST-ONLY: a character grown to a combat_exp the way a player who follows the story grows
## (DECISIONS「考验三招」「成长曲线 C」), for the suites and probes that measure a fight or a trial
## against the exp the story brings instead of a character made unbeatable:
## - the seven skills' raw levels are the growth sim's (tests/sim/growth_curve_sim.gd, PLAYED): a
##   封山剑派 disciple who spends every chapter's potential at 柳淳风, one lesson to each skill in turn,
##   his own levels capping each (基本内功 40, 封山派内功 60) and learn.c's gate holding — the
##   main-story and exploring runs merged, levels in between read off the line between two rows.
##   Below and past the table: the potential spread evenly over seven skills (learn.c: random(int +
##   exp / (1000 + exp / 1000)) points a 请教, about level^3 / 3 points to reach a level), no higher
##   than learn.c's gate (level^3 / 10 <= exp), and never under the table's last row;
## - the sword build (`sword`): 封山剑法 on sword and parry, 倒乱七星步 on dodge, 封山派内功 on force;
##   the fist build: 柳家拳 on unarmed at the sword's two levels, parry and the rest as above;
## - max_force: `force_percent` of exercise.c's cap for those levels (the sim's player sits to the
##   cap: 100; half by default, about an hour of 打坐 at 10000 exp as 考验三招 was set), the force full;
## - 精, 气 and 神 at race/human.c's maxima for the age the game's `player_age_by_exp` gives that exp
##   (TestAging.production_age(): 成长曲线 C), whatever the suite runner has turned off.
## Nothing is put in the hand: New Game's player is unarmed, and a sword is the caller's.

const TestAging := preload("res://tests/support/test_aging.gd")

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
## The growth sim's rows (成长曲线 A merged, `-- start=main auto` and `-- start=exploring auto`,
## each level the most reached by then): combat_exp, then 剑法, 封山剑法, 招架, 闪躲, 倒乱七星步,
## 基本内功, 封山派内功, and the max_force 打坐 to the cap gives.
const PLAYED: Array[Array] = [
	[1000, 14, 0, 14, 14, 0, 14, 14, 180],
	[1825, 18, 13, 17, 17, 13, 17, 17, 220],
	[2500, 19, 16, 19, 19, 16, 19, 19, 240],
	[4150, 25, 16, 25, 25, 16, 25, 24, 320],
	[4690, 25, 22, 25, 25, 23, 25, 24, 320],
	[5500, 27, 22, 27, 27, 23, 28, 27, 360],
	[6490, 27, 26, 27, 27, 26, 28, 27, 360],
	[8470, 30, 29, 30, 30, 29, 30, 30, 390],
	[8680, 32, 29, 32, 32, 29, 32, 31, 410],
	[11650, 34, 33, 34, 34, 34, 34, 34, 440],
	[12280, 36, 33, 36, 36, 34, 36, 36, 460],
	[14260, 38, 35, 38, 38, 35, 38, 38, 490],
	[14470, 38, 36, 38, 38, 37, 38, 38, 490],
	[19720, 44, 42, 44, 44, 42, 40, 44, 520],
	[21130, 44, 44, 45, 44, 45, 40, 45, 530],
	[22930, 46, 46, 47, 46, 46, 40, 46, 530],
	[25360, 49, 48, 49, 49, 47, 40, 49, 530],
	[31450, 54, 54, 54, 54, 54, 40, 54, 540],
	[32920, 56, 55, 56, 56, 54, 40, 56, 550],
	[34720, 57, 56, 57, 58, 56, 40, 57, 550],
	[37330, 59, 58, 59, 59, 59, 40, 59, 550],
	[40930, 62, 62, 62, 62, 62, 40, 60, 560],
	[43240, 65, 64, 64, 65, 63, 40, 60, 560],
	[55490, 75, 74, 74, 75, 74, 40, 60, 560],
	[62990, 80, 79, 80, 80, 79, 40, 60, 560],
]
## PLAYED's columns.
const COLUMNS: Array[StringName] = [&"sword", &"fonxansword", &"parry", &"dodge", &"chaos-steps", &"force", &"fonxanforce"]


## The main skill's raw level at `experience` (the sword build's 剑法).
static func level_for(experience: int) -> int:
	return int(levels_for(experience)[&"sword"])


## The seven skills' raw levels at `experience` (PLAYED, or the even spread outside it).
static func levels_for(experience: int) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if experience < int(PLAYED[0][0]):
		var even: int = _even_level(experience)
		for column: StringName in COLUMNS:
			out[column] = even
		return out
	var last: Array = PLAYED.back()
	if experience >= int(last[0]):
		var even: int = _even_level(experience)
		for index: int in COLUMNS.size():
			# 柳淳风 teaches 基本内功 to 40 and 封山派内功 to 60: those stay where the sim left them.
			out[COLUMNS[index]] = int(last[index + 1]) if COLUMNS[index] in [&"force", &"fonxanforce"] else maxi(int(last[index + 1]), even)
		return out
	for row: int in range(1, PLAYED.size()):
		var high: Array = PLAYED[row]
		if experience < int(high[0]):
			var low: Array = PLAYED[row - 1]
			var share: float = float(experience - int(low[0])) / float(int(high[0]) - int(low[0]))
			for index: int in COLUMNS.size():
				out[COLUMNS[index]] = int(floor(lerpf(float(low[index + 1]), float(high[index + 1]), share)))
			return out
	return out


static func grow(state: CharacterState, experience: int, force_percent: int = 50, sword: bool = false) -> void:
	state.progression.combat_experience = experience
	var levels: Dictionary[StringName, int] = levels_for(experience)
	var raw: Dictionary[StringName, int] = levels.duplicate()
	if not sword:
		raw[&"unarmed"] = levels[&"sword"]
		raw[&"liuh-ken"] = levels[&"fonxansword"]
	for pair: Array in SWORD_PAIRS if sword else PAIRS:
		var special: StringName = pair[1]
		state.skills.set_raw_level(pair[0], raw[pair[0]])
		if not special.is_empty():
			state.skills.set_raw_level(special, raw[special])
			state.skills.map_skill(pair[0], special)
	@warning_ignore("integer_division")
	var max_force: int = CultivationService.exercise_cap(state) * force_percent / 100
	state.recovery.inner_force.maximum = max_force
	state.recovery.inner_force.current = max_force
	CharacterDerivedValues.refresh_human_player_maxima(state, TestAging.production_age(experience))
	heal(state)


static func heal(state: CharacterState) -> void:
	state.conditions.clear()
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	state.recovery.inner_force.current = state.recovery.inner_force.maximum


## The potential spread evenly over SKILLS, learn.c's points a 请教 and gate (outside PLAYED).
static func _even_level(experience: int) -> int:
	@warning_ignore("integer_division")
	var potential: float = float(experience * GameContent.catalog().progression().potential_percent / 100) / float(SKILLS)
	@warning_ignore("integer_division")
	var mean_points: float = float(INTELLIGENCE + experience / (1000 + experience / 1000)) / 2.0
	var level: int = int(pow(3.0 * potential * mean_points, 1.0 / 3.0))
	while level > 0 and LearnService.required_combat_experience(level) > experience:
		level -= 1
	return level
