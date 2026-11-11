class_name Es2Pacing
extends RefCounted

## Suites that pin ES2's own numbers end to end (combatd.c's +1 combat_exp,
## heal_up()'s amounts) run with the pacing knobs at ES2's pace: the production
## record with the knobs left out (DECISIONS, pacing knobs). use() before the
## session is made; restore() with what it returned when the suite ends.


static func use() -> PacingDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	# The day's length stays the runner's (TestDay: standing still), not a running ES2 day.
	catalog.set_pacing(PacingDefinition.new(roundi(production.combat_round_seconds * 1000.0), production.room_reset_seconds).with_day_length(production.day_length_minutes))
	return production


## Only the responsiveness knobs at ES2's (DECISIONS「响应性」): each call_out its own
## seconds, a master's test in one go, no fade. Everything else stays the game's as the
## suite runner left it: the fight, its decisions and beats, the NPCs' modern values, the
## story's parley, the stealth, the gains. For suites that pin a call_out's ES2 time
## (taolord.c's two seconds, a greeting's one, three lashes at once); a suite that also pins
## a fight's LPC numbers says so with use_combat().
static func use_reactions() -> PacingDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	catalog.set_pacing(production.copy().with_responsiveness(0, 0, roundi(production.heart_beat_seconds * 1000.0), 0))
	return production


## The game's pacing with the A2 progression knobs at ES2's (no 历练, no catch-up, cap 100,
## 打坐 ×1) and the fight at ES2's numbers (DECISIONS「战斗数值」: the cubic curve, the
## experience loop, the NPCs' `classic` values, no forecast): for suites that pin a fight's
## or a sitting's numbers (combat_exp, its draw bounds) while the rest of the pacing stays
## the game's.
static func use_without_progression() -> PacingDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	catalog.set_pacing(production.copy().with_progression(false, 0, false, 1).with_training(false, production.bounty_refresh_seconds, false).with_day_length(production.day_length_minutes).with_combat(CombatPowerRules.classic(), false, true).with_decisions(CombatDecisionRules.classic()).with_beats(CombatBeatRules.classic()).with_death(PacingDefinition.ES2_DEATH_EXP_PERCENT, false, false, false).with_autosave(0))
	return production


## The game's pacing with only the fight at ES2's numbers (DECISIONS「战斗数值」: the cubic
## curve, the experience loop, the NPCs' `classic` values, no forecast): for suites that pin
## a fight's course or an NPC's LPC numbers while the 木人, the board and the rest stay.
static func use_combat() -> PacingDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	catalog.set_pacing(production.copy().with_combat(CombatPowerRules.classic(), false, true).with_decisions(CombatDecisionRules.classic()).with_beats(CombatBeatRules.classic()))
	return production


static func restore(previous: PacingDefinition) -> void:
	GameContent.catalog().set_pacing(previous)
