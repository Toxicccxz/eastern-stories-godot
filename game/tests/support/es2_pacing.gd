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


static func restore(previous: PacingDefinition) -> void:
	GameContent.catalog().set_pacing(previous)
