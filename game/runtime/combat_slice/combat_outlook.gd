class_name CombatOutlook
extends RefCounted

## What the HUD says of fighting an NPC before the player does (目标详情, the popup's line,
## the confirm page's `about`): under pacing.json's combat_forecast the CombatForecast's
## line, with the ES2 numbers RelativeStrength's line by combat_exp (owner A10). The
## template keeps {pronoun} (他/她/它) and {count} for the caller's language.

var template: String = ""
var count: int = 1
## The forecast behind the line, null for RelativeStrength's.
var forecast: CombatForecast


func _init(p_template: String = "", p_count: int = 1, p_forecast: CombatForecast = null) -> void:
	template = p_template
	count = p_count
	forecast = p_forecast


func is_empty() -> bool:
	return template.is_empty()


## The line in the shown language; `pronoun` already translated.
func shown(pronoun: String) -> String:
	if template.is_empty():
		return ""
	return TranslationServer.translate(template).format({"pronoun": pronoun, "count": count})
