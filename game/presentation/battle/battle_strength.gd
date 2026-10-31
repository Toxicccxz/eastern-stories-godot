class_name BattleStrength
extends RefCounted

## 战斗决策层 2 (DECISIONS「战斗界面」): the one word an enemy's card carries after its name —
## the 战前预判 (CombatForecast) of the player against that one alone, read once when the
## fight begins and kept by the panel until it ends (not read again each frame). `verdict` is
## CombatForecast.Verdict; `line` the forecast's full line, translated, for the hover.
var verdict: int = CombatForecast.Verdict.EVEN
var line: String = ""


func _init(p_verdict: int = CombatForecast.Verdict.EVEN, p_line: String = "") -> void:
	verdict = p_verdict
	line = p_line


## The forecast's word (稳赢 / 占优 / 五五开 / 吃亏 / 必败), translated.
func word() -> String:
	return CombatForecast.verdict_word(verdict)


## The player against `npc` alone, as the map stands now; null when nothing can be
## foreseen (the forecast off, the npc not on the map, no attack to read).
static func read(map: WorldMapController, npc: NpcRuntimeState, pronoun: String) -> BattleStrength:
	if map == null or npc == null or not GameContent.catalog().pacing().combat_forecast:
		return null
	var forecast: CombatForecast = CombatForecastBuilder.for_one(map, npc)
	if forecast == null:
		return null
	return BattleStrength.new(forecast.verdict, TranslationServer.translate(forecast.line()).format({"pronoun": pronoun, "count": 1}))
