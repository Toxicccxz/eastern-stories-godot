class_name NpcWager
extends RefCounted

## An NPC that takes bets (u/cloud/npc/judge.c accept_object()): money it accepts
## through an `effect: wager` rule is the stake. random(`out_of`) < `lose_below` loses:
## the NPC says the `lose` lines and the stake is gone (give.c destructs money given to
## an NPC). Otherwise it says the `win` lines and pay_player() pays `payout` times the
## stake's value, at least one coin, in silver and coins.
## Data: {"lose_below", "out_of", "payout", "lose": {line|say|emote}, "win": {...}}.
var lose_below: int = 0
var out_of: int = 0
var payout: int = 0
var lose_lines: Array[NpcLine] = []
var win_lines: Array[NpcLine] = []


## judge.c: if( random(10) < 8 ) the house wins.
func wins(random: WorldInteractionRandomSource) -> bool:
	return random.legacy_random(out_of) >= lose_below


## pay_player(who, val * 2): if( amount < 1 ) amount = 1. -1 when it overflows.
func winnings(stake_value: int) -> int:
	return maxi(1, stake_value * payout) if CurrencyArithmetic.multiply(stake_value, payout) >= 0 else -1


func is_valid() -> bool:
	return out_of > 0 and lose_below >= 0 and lose_below <= out_of and payout > 0 and not lose_lines.is_empty() and not win_lines.is_empty()


static func from_record(reader: ContentRecordReader) -> NpcWager:
	var wager := NpcWager.new()
	wager.lose_below = reader.required_integer("lose_below")
	wager.out_of = reader.required_integer("out_of")
	wager.payout = reader.required_integer("payout")
	var lose: ContentRecordReader = reader.child("lose")
	if lose != null:
		wager.lose_lines = NpcLine.optional_lines(lose)
		lose.finish()
	var win: ContentRecordReader = reader.child("win")
	if win != null:
		wager.win_lines = NpcLine.optional_lines(win)
		win.finish()
	reader.finish()
	if not wager.is_valid():
		reader.fail("", "needs 0 <= lose_below <= out_of, out_of and payout above 0, and lose and win lines")
	return wager
