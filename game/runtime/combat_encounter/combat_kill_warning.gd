class_name CombatKillWarning
extends RefCounted

## feature/attack.c kill_ob()'s line to its victim, 看起来X想杀死你！, once per name
## (DECISIONS「同名杀意合一行」): ES2 tells it once for each who turns on the player, so five
## of one kind print it five times; here those of one name share a line, their count after it.


## The lines for `names` (as the player reads them, one per killer, in order): each name once,
## where it first came, with how many of that name there are when more than one.
static func lines(names: Array[String]) -> Array[String]:
	var order: Array[String] = []
	var counts: Dictionary[String, int] = {}
	for shown: String in names:
		if not counts.has(shown):
			order.append(shown)
			counts[shown] = 0
		counts[shown] += 1
	var result: Array[String] = []
	for shown: String in order:
		result.append(line(shown, counts[shown]))
	return result


## One line: `shown` wants the player dead (`count` of that name).
static func line(shown: String, count: int = 1) -> String:
	if count <= 1:
		return TranslationServer.translate("看起来%s想杀死你！") % shown
	return TranslationServer.translate("看起来%s（×%d）想杀死你！") % [shown, count]
