class_name TestAging
extends RefCounted

## Suites run with the player kept at New Game's age (run_suite.gd; DECISIONS「成长曲线 C」): those
## written before pin a 14-year-old's 精, 气 and forms of address at any exp, and a suite that sets
## combat_exp by hand would otherwise age the player on the next heart beat. A suite about growing
## up turns pacing.json's ages on with use() and restore() when it is done. production_age() is the
## age the game's own table gives an exp whatever is turned off: a character grown to an exp
## (grown_character.gd) has the 精 and 气 of that age, as a player of that exp does.

## New Game's age (new_player_initialization_policy.gd).
const NEW_GAME_AGE: int = 14

static var _steps: Array[PlayerAging.Step] = []
static var _kept: bool = false


## The suite runner, once: keeps pacing.json's ages and turns them off.
static func turn_off() -> void:
	_steps = GameContent.catalog().pacing().player_age_steps
	_kept = true
	restore()


static func use() -> void:
	GameContent.catalog().pacing().with_player_ages(_steps if _kept else GameContent.catalog().pacing().player_age_steps)


static func restore() -> void:
	var none: Array[PlayerAging.Step] = []
	GameContent.catalog().pacing().with_player_ages(none)


## The age pacing.json's player_age_by_exp gives `experience` (from New Game's 14).
static func production_age(experience: int) -> int:
	var steps: Array[PlayerAging.Step] = _steps if _kept else GameContent.catalog().pacing().player_age_steps
	return PlayerAging.grown_age(NEW_GAME_AGE, experience, steps)
