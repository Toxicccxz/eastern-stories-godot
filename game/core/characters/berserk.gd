class_name Berserk
extends RefCounted

## Bellicosity that boils over, for NPCs and the player alike. feature/attack.c
## init(): someone full of bellicosity goes berserk at a living one who comes into
## its room (or into whose room it comes) when random(bellicosity / 40) beats its
## cps; cmds/std/look.c: an NPC looked at turns on the looker when
## random(bellicosity / 10) beats the looker's per. combatd.c start_berserk() then
## stares at everyone, calms down when its force beats (random(bellicosity) +
## bellicosity) / 2, and otherwise, when its bellicosity is above its score, attacks
## to kill (kill_ob()), else only to fight (fight_ob(): a spar).
enum Outcome { NONE, STARE, KILL, FIGHT }

const INIT_DIVISOR: int = 40
const LOOK_DIVISOR: int = 10
## Owner (水烟阁 C): told once, the first time the player's bellicosity can boil over
## (can_lose_control()). Native; ES2 says nothing.
# TRANSLATORS: told once, when the player's 杀气 (bellicosity) first gets high enough that entering a place with people may make them attack someone by themselves.
const WARNING: String = "你胸中杀气翻涌，渐渐压不住了：杀气这么重，走进有人的地方时，你可能会控制不住，向人出手。"


## attack.c init()'s berserk case for an NPC: a non-aggressive one (an aggressive
## one attacks first).
static func applies_to(definition: NpcDefinition) -> bool:
	return definition.bellicosity() > 0 and definition.attitude != NpcDefinition.Attitude.AGGRESSIVE


## attack.c init(): random(bellicosity / 40) > cps.
static func init_roll(state: CharacterState, random_source: WorldInteractionRandomSource) -> bool:
	@warning_ignore("integer_division")
	return random_source.legacy_random(state.attributes.bellicosity / INIT_DIVISOR) > state.attributes.composure


## look.c: random(bellicosity / 10) > the looker's per.
static func look_roll(state: CharacterState, looker_per: int, random_source: WorldInteractionRandomSource) -> bool:
	@warning_ignore("integer_division")
	return random_source.legacy_random(state.attributes.bellicosity / LOOK_DIVISOR) > looker_per


## combatd.c start_berserk() once its own checks passed: STARE (calmed by its force),
## KILL or FIGHT.
static func start(state: CharacterState, score: int, random_source: WorldInteractionRandomSource) -> Outcome:
	var bellicosity: int = state.attributes.bellicosity
	@warning_ignore("integer_division")
	if state.recovery.inner_force.current > (random_source.legacy_random(bellicosity) + bellicosity) / 2:
		return Outcome.STARE
	return Outcome.KILL if bellicosity > score else Outcome.FIGHT


## init()'s roll, then start_berserk() when it went over.
static func roll(state: CharacterState, score: int, random_source: WorldInteractionRandomSource) -> Outcome:
	return start(state, score, random_source) if init_roll(state, random_source) else Outcome.NONE


## The least bellicosity at which init()'s roll can go over: random(n) is at most
## n - 1, so bellicosity / 40 must reach cps + 2.
static func threshold(composure: int) -> int:
	return INIT_DIVISOR * (composure + 2)


## Whether init()'s roll can now go over for this character.
static func can_lose_control(state: CharacterState) -> bool:
	return state.attributes.bellicosity >= threshold(state.attributes.composure)


## The one-time warning is due now: marks it given (saved) and returns true once.
static func take_warning(state: CharacterState) -> bool:
	if state.progression.berserk_warned or not can_lose_control(state):
		return false
	state.progression.berserk_warned = true
	return true
