class_name Es2Pacing
extends RefCounted

## Suites that pin ES2's own numbers end to end (combatd.c's +1 combat_exp,
## heal_up()'s amounts) run with the pacing knobs at ES2's pace: the production
## record with the knobs left out (DECISIONS, pacing knobs). use() before the
## session is made; restore() with what it returned when the suite ends.


static func use() -> PacingDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	catalog.set_pacing(PacingDefinition.new(roundi(production.combat_round_seconds * 1000.0), production.room_reset_seconds))
	return production


## Only the responsiveness knobs at ES2's (DECISIONS「响应性」): each call_out its own
## seconds, a master's test in one go, no fade; the gains stay the game's. For suites that
## pin a call_out's ES2 time (taolord.c's two seconds, a greeting's one, three lashes at once).
static func use_reactions() -> PacingDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	catalog.set_pacing(PacingDefinition.new(
		roundi(production.combat_round_seconds * 1000.0), production.room_reset_seconds, production.player_exp_gain,
		production.player_recovery_gain, production.quest_time_percent, production.npc_thirst, production.player_wake_seconds,
	).with_responsiveness(0, 0, roundi(production.heart_beat_seconds * 1000.0), 0))
	return production


## The game's pacing with nobody moved while the player is away (away_wander_moves and the
## neighbour pulse at ES2's 0, DECISIONS「别的地图时间补算」): for suites that walk past or
## count a map's people where its rooms put them.
static func use_still() -> PacingDefinition:
	var catalog: ContentCatalog = GameContent.catalog()
	var production: PacingDefinition = catalog.pacing()
	catalog.set_pacing(production.copy().with_away_catch_up_limit(production.away_catch_up_limit_seconds, 0, 0))
	return production


static func restore(previous: PacingDefinition) -> void:
	GameContent.catalog().set_pacing(previous)
