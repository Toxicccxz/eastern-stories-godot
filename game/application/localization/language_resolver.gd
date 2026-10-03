class_name LanguageResolver
extends RefCounted

## Which listed language follows a system locale. Godot's own matching ranks by language
## first, so with only Traditional Chinese loaded a zh_CN or zh_SG system would get it:
## Chinese is matched by script here (Hans: CN, SG, MY and no region; Hant: TW, HK, MO).
const TRADITIONAL_REGIONS: PackedStringArray = ["TW", "HK", "MO"]


## `os_locale` as OS.get_locale() reports it on any platform: zh_CN, zh_Hant_HK, zh-Hans-SG, en_US, ja.
static func resolve(os_locale: String, catalog: LanguageCatalog) -> String:
	var parts: PackedStringArray = os_locale.replace("-", "_").split("_", false)
	if parts.is_empty():
		return catalog.default_code()
	var language: String = parts[0].to_lower()
	var script_tag: String = ""
	var region: String = ""
	for part: String in parts.slice(1):
		if part.length() == 4:
			script_tag = part.capitalize()
		elif region.is_empty():
			region = part.to_upper()
	if language == "zh" and script_tag.is_empty():
		script_tag = "Hant" if TRADITIONAL_REGIONS.has(region) else "Hans"
	var candidates: Array[LanguageDefinition] = []
	for candidate: LanguageDefinition in catalog.languages():
		if candidate.language() == language:
			candidates.append(candidate)
	if candidates.is_empty():
		return catalog.default_code()
	for candidate: LanguageDefinition in candidates:
		if not script_tag.is_empty() and candidate.script_code == script_tag:
			return candidate.code
	for candidate: LanguageDefinition in candidates:
		if candidate.code == "%s_%s" % [language, region]:
			return candidate.code
	return candidates[0].code
