class_name TestDeath
extends RefCounted

## Suites run with death at ES2's price and no autosave (run_suite.gd, DECISIONS「减轻死亡」
## 「自动存档」): those written before pin killer_reward()'s numbers, and a suite that walks
## through doors writes no files. A suite about these turns pacing.json's on with use() and
## restore() when it is done.

static var _exp_percent: int = PacingDefinition.ES2_DEATH_EXP_PERCENT
static var _keeps_potential: bool = false
static var _keeps_skills: bool = false
static var _corpse_stays: bool = false
static var _keeps_equipped: bool = false
static var _autosave_seconds: int = 0


## The suite runner, once: keeps pacing.json's knobs and turns them off.
static func turn_off() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_exp_percent = pacing.death_exp_percent
	_keeps_potential = pacing.death_keeps_potential
	_keeps_skills = pacing.death_keeps_skills
	_corpse_stays = pacing.player_corpse_stays
	_keeps_equipped = pacing.death_keeps_equipped
	_autosave_seconds = pacing.autosave_min_seconds
	restore()


## pacing.json's death_exp_percent, whatever a suite turned on or off.
static func game_exp_percent() -> int:
	return _exp_percent


## pacing.json's death_keeps_equipped, whatever a suite turned on or off.
static func game_keeps_equipped() -> bool:
	return _keeps_equipped


static func use() -> void:
	GameContent.catalog().pacing().with_death(_exp_percent, _keeps_potential, _keeps_skills, _corpse_stays).with_death_equipped(_keeps_equipped).with_autosave(_autosave_seconds)


static func restore() -> void:
	GameContent.catalog().pacing().with_death(PacingDefinition.ES2_DEATH_EXP_PERCENT, false, false, false).with_death_equipped(false).with_autosave(0)
