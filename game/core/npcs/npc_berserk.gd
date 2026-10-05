class_name NpcBerserk
extends RefCounted

## feature/attack.c init(): an NPC that is not aggressive but full of bellicosity
## goes berserk at a player who comes in when random(bellicosity / 40) beats its
## cps; combatd.c start_berserk() then stares at everyone, calms down when its
## force beats (random(bellicosity) + bellicosity) / 2, and otherwise, when its
## bellicosity is above its score, attacks to kill. (Not above its score it would
## only fight, fight_ob(); the loader refuses such an NPC until a berserk spar is
## ported.)
enum Outcome { NONE, STARE, KILL }


static func applies_to(definition: NpcDefinition) -> bool:
	return definition.bellicosity() > 0 and definition.attitude != NpcDefinition.Attitude.AGGRESSIVE


static func roll(state: CharacterState, score: int, random_source: WorldInteractionRandomSource) -> Outcome:
	var bellicosity: int = state.attributes.bellicosity
	@warning_ignore("integer_division")
	if random_source.legacy_random(bellicosity / 40) <= state.attributes.composure:
		return Outcome.NONE
	@warning_ignore("integer_division")
	if state.recovery.inner_force.current > (random_source.legacy_random(bellicosity) + bellicosity) / 2:
		return Outcome.STARE
	return Outcome.KILL if bellicosity > score else Outcome.STARE
