class_name CombatOutlook
extends RefCounted

## What the HUD says of fighting an NPC before the player does (目标详情, the popup's line,
## the confirm page's `about`): under pacing.json's combat_forecast the CombatForecast's
## line, with the ES2 numbers RelativeStrength's line by combat_exp (owner A10). The
## template keeps {pronoun} (他/她/它) and {count} for the caller's language.

var template: String = ""
## The template's sentences, each a message (the verdict, the reason); empty: the template is one.
var parts: PackedStringArray = PackedStringArray()
var count: int = 1
## The forecast behind the line, null for RelativeStrength's.
var forecast: CombatForecast


func _init(p_template: String = "", p_count: int = 1, p_forecast: CombatForecast = null, p_parts: PackedStringArray = PackedStringArray()) -> void:
	template = p_template
	count = p_count
	forecast = p_forecast
	parts = p_parts


func is_empty() -> bool:
	return template.is_empty()


## The line in the shown language; `pronoun` already translated.
func shown(pronoun: String) -> String:
	if template.is_empty():
		return ""
	if parts.size() <= 1:
		return TranslationServer.translate(template).format({"pronoun": pronoun, "count": count})
	# Each sentence is its own message; a language that spaces its words puts a space between.
	var shown_parts := PackedStringArray()
	for part: String in parts:
		shown_parts.append(TranslationServer.translate(part).format({"pronoun": pronoun, "count": count}))
	var joined_tight: bool = MessageGrammar.shows_chinese() or TranslationServer.get_locale().begins_with("ja")
	return ("" if joined_tight else " ").join(shown_parts)
