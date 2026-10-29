class_name PacePresets
extends RefCounted

## The one 现代 / 经典 switch (前两小时 E; DECISIONS「经典模式总开关」): chosen on the New Game
## panel, kept in CharacterState.pace and the save. 经典 puts the A2 progression knobs at
## ES2's — no 历练, no 落后补偿, potential cap 100, 打坐 ×1, no 悬赏榜, no 木人 — and the day
## at ES2's 24 real minutes (DECISIONS「昼夜」) and the sky always clear (no cloud turning,
## DECISIONS「天气」) and the story's parley and sure burial off (DECISIONS「老松寨的三条路」
## 「安葬必得书」) on top of whatever pacing the catalog has; the feel knobs stay. 现代 leaves the catalog's pacing as
## it is. A session applies it before its world is built (the 木人 are spawned or not) and
## puts the pacing back when it goes.


## The pacing `pace` makes of `base`.
static func of(base: PacingDefinition, pace: StringName) -> PacingDefinition:
	if pace != CharacterState.PACE_CLASSIC:
		return base
	return base.copy().with_progression(false, 0, false, 1).with_training(false, base.bounty_refresh_seconds, false).with_day_length(PacingDefinition.ES2_DAY_LENGTH_MINUTES).with_sky_weather(false).with_story(false, false)


## Sets the catalog's pacing for `pace` and gives back what it was (restore() takes it).
static func apply(catalog: ContentCatalog, pace: StringName) -> PacingDefinition:
	var before: PacingDefinition = catalog.pacing()
	if before != null:
		catalog.set_pacing(of(before, pace))
	return before


static func restore(catalog: ContentCatalog, before: PacingDefinition) -> void:
	if before != null:
		catalog.set_pacing(before)


## The pace's name on the 角色 page.
static func shown_name(pace: StringName) -> String:
	# TRANSLATORS: the character sheet's pace line: 经典 is ES2's own numbers, 现代 the game's.
	return TranslationServer.translate("经典") if pace == CharacterState.PACE_CLASSIC else TranslationServer.translate("现代")
