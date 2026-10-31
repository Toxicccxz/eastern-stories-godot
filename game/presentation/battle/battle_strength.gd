class_name BattleStrength
extends RefCounted

## 战斗决策层 2 (DECISIONS「战斗界面」): the one word an enemy's card carries after its name —
## the 战前预判 (CombatForecast) of the player against that one alone, read once when the
## fight begins and kept by the panel until it ends (not read again each frame). `verdict` is
## CombatForecast.Verdict; `line` the forecast's full line, translated, for the hover. In a
## 切磋 the verdict and the line are the spar's (who lands first, CombatForecast.spar_verdict).
var verdict: int = CombatForecast.Verdict.EVEN
var line: String = ""


func _init(p_verdict: int = CombatForecast.Verdict.EVEN, p_line: String = "") -> void:
	verdict = p_verdict
	line = p_line


## The forecast's word (稳赢 / 占优 / 五五开 / 吃亏 / 必败), translated.
func word() -> String:
	return CombatForecast.verdict_word(verdict)


## The player against `npc` alone, as the map stands now; null when nothing can be
## foreseen (the forecast off, the npc not on the map, no attack to read). `spar`: the
## fight is a 切磋 (CombatEncounterMode.SPAR).
static func read(map: WorldMapController, npc: NpcRuntimeState, pronoun: String, spar: bool = false) -> BattleStrength:
	if map == null or npc == null or not GameContent.catalog().pacing().combat_forecast:
		return null
	var forecast: CombatForecast = CombatForecastBuilder.for_one(map, npc)
	return null if forecast == null else of(forecast, pronoun, spar)


## The word and the line of `forecast`: the spar's verdict and line in a 切磋, else the
## fight's verdict and its reason. The verdict and the reason are two messages, each
## translated on its own.
static func of(forecast: CombatForecast, pronoun: String, spar: bool = false) -> BattleStrength:
	if spar:
		return BattleStrength.new(forecast.spar_verdict, TranslationServer.translate(CombatForecast.SPAR_LINES[forecast.spar_verdict]).format({"pronoun": pronoun}))
	var text: String = TranslationServer.translate(CombatForecast.VERDICT_LINES[forecast.verdict])
	if forecast.reason != CombatForecast.Reason.NONE:
		text += TranslationServer.translate(CombatForecast.REASON_LINES[forecast.reason])
	return BattleStrength.new(forecast.verdict, text.format({"pronoun": pronoun, "count": 1}))
