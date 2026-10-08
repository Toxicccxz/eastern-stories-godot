class_name RelativeStrength
extends RefCounted

## How strong someone looks next to the player, by combat_exp. Native (owner, modern
## fixes II, A10): cmds/std/look.c says nothing of it and fight.c's accept_fight()
## never compares the two, so today's players read it on 目标详情 and are asked
## before sparring someone clearly stronger. Small differences near zero count as
## even (the absolute margins), so a fresh character is not warned off a trainee.
enum Band { MUCH_WEAKER, WEAKER, EVEN, STRONGER, MUCH_STRONGER }

## "Clearly stronger": at least four times the player's combat_exp and 500 more.
const MUCH_RATIO: int = 4
const MUCH_MARGIN: int = 500
## "Stronger": at least twice and 100 more.
const RATIO: int = 2
const MARGIN: int = 100

## TRANSLATORS: 目标详情 (native, no ES2 line): how strong the NPC looks next to the player. {pronoun} is 他/她/它.
const LINES: Dictionary[Band, String] = {
	Band.MUCH_WEAKER: "{pronoun}看起来远不如你。",
	Band.WEAKER: "{pronoun}看起来不如你。",
	Band.EVEN: "{pronoun}看起来和你不相上下。",
	Band.STRONGER: "{pronoun}看起来比你强。",
	Band.MUCH_STRONGER: "{pronoun}看起来比你强得多。",
}


static func band(player_exp: int, other_exp: int) -> Band:
	var player: int = maxi(player_exp, 0)
	var other: int = maxi(other_exp, 0)
	if other >= player * MUCH_RATIO and other >= player + MUCH_MARGIN:
		return Band.MUCH_STRONGER
	if other >= player * RATIO and other >= player + MARGIN:
		return Band.STRONGER
	if player >= other * MUCH_RATIO and player >= other + MUCH_MARGIN:
		return Band.MUCH_WEAKER
	if player >= other * RATIO and player >= other + MARGIN:
		return Band.WEAKER
	return Band.EVEN


static func clearly_stronger(player_exp: int, other_exp: int) -> bool:
	return band(player_exp, other_exp) == Band.MUCH_STRONGER


## The 目标详情 line, untranslated template with {pronoun} left to fill.
static func line(player_exp: int, other_exp: int) -> String:
	return LINES[band(player_exp, other_exp)]
