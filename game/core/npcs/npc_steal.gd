class_name NpcSteal
extends RefCounted

## An NPC that steals from the player who comes into its place (u/cloud thief.c
## init() and steal_it(), with cmds/std/steal.c doing the stealing): when the player
## arrives, random(player kar) < `chance_below` starts a one-second call_out that
## steals `what` (present(what, victim), else a random thing they carry). steal.c
## then waits three seconds and rolls; the thief's own lines go to the thief, so
## the player reads only being caught at it. Data: {"what", "chance_below"}.

const COMPLETE_DELAY_SECONDS: float = 3.0
const START_DELAY_SECONDS: float = 1.0

enum Outcome {
	## random(sp+dp) > dp, or the victim is not conscious: the thing changes hands.
	TAKEN,
	## Failed, but random(sp) > dp/2: the victim notices nothing.
	UNNOTICED,
	## Failed and seen: the victim shouts and the two fight.
	CAUGHT,
}

var what: StringName = &""
var chance_below: int = 0


## thief.c init(): an arriving (interactive) player with random(kar) < chance_below.
func starts(player_karma: int, random: WorldInteractionRandomSource) -> bool:
	return random.legacy_random(player_karma) < chance_below


## steal.c sp: query_skill("stealing") * 5 + kar * 2 - query("thief") * 20, at least
## 1; halved while the thief fights.
static func thief_odds(stealing_effective: int, karma: int, times_caught: int, fighting: bool) -> int:
	var sp: int = stealing_effective * 5 + karma * 2 - times_caught * 20
	if sp < 1:
		sp = 1
	if fighting:
		@warning_ignore("integer_division")
		sp /= 2
	return sp


## steal.c dp: sen * 2 + weight / 25, ten times while the victim fights and ten
## times more for an equipped thing.
@warning_ignore("integer_division")
static func victim_odds(sen: int, item_weight: int, fighting: bool, equipped: bool) -> int:
	var dp: int = sen * 2 + item_weight / 25
	if fighting:
		dp *= 10
	if equipped:
		dp *= 10
	return dp


## steal.c compelete_steal(). Taken: random(sp+dp) > dp (no roll on a victim who is
## not conscious); on a conscious victim improve_skill("stealing", random(int))
## (NPC skills do not improve; the draw is kept) and random(sp) < dp/2 for whether
## others see it (nobody else is there; kept too). Failed: random(sp) > dp/2 is unnoticed.
@warning_ignore("integer_division")
static func resolve(sp: int, dp: int, victim_conscious: bool, thief_intelligence: int, random: WorldInteractionRandomSource) -> Outcome:
	if not victim_conscious or random.legacy_random(sp + dp) > dp:
		if victim_conscious:
			random.legacy_random(thief_intelligence)
			random.legacy_random(sp)
		return Outcome.TAKEN
	if random.legacy_random(sp) > dp / 2:
		return Outcome.UNNOTICED
	return Outcome.CAUGHT


func is_valid() -> bool:
	return not what.is_empty() and chance_below > 0


static func from_record(reader: ContentRecordReader) -> NpcSteal:
	var steal := NpcSteal.new()
	steal.what = StringName(reader.required_text("what"))
	steal.chance_below = reader.required_integer("chance_below")
	reader.finish()
	if not steal.is_valid():
		reader.fail("", "needs what and a positive chance_below")
	return steal
