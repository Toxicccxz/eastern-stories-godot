class_name PacePresets
extends RefCounted

## The one 现代 / 经典 switch (前两小时 E; DECISIONS「经典模式总开关」): chosen on the New Game
## panel, kept in CharacterState.pace and the save. 经典 puts the A2 progression knobs at
## ES2's — no 历练, no 落后补偿, potential cap 100, 打坐 ×1, no 悬赏榜, no 木人 — and the day
## at ES2's 24 real minutes (DECISIONS「昼夜」) and the sky always clear (no cloud turning,
## DECISIONS「天气」) and the story's parley and sure burial off (DECISIONS「老松寨的三条路」
## 「安葬必得书」) and the fight at ES2's numbers (DECISIONS「战斗数值」: the cubic curve, the
## experience loop, no forecast, the NPCs' `classic` values) and death at ES2's price with no
## autosave (DECISIONS「减轻死亡」「自动存档」) and every number shown (DECISIONS「数值用到才出现」)
## on top of whatever pacing the catalog has; the feel knobs stay. 现代 leaves the catalog's pacing as
## it is. A session applies it before its world is built (the 木人 are spawned or not) and
## puts the pacing back when it goes.


## The sessions standing on the catalog now, by pace, in the order they came: a load in play
## builds its session beside the one it replaces, and either may go first (the old one once
## the new one stands, the new one when it fails). What they stand on, and what they set.
static var _paces: Array[StringName] = []
static var _base: PacingDefinition
static var _applied: PacingDefinition


## The pacing `pace` makes of `base`.
static func of(base: PacingDefinition, pace: StringName) -> PacingDefinition:
	if pace != CharacterState.PACE_CLASSIC:
		return base
	return base.copy().with_progression(false, 0, false, 1).with_training(false, base.bounty_refresh_seconds, false).with_day_length(PacingDefinition.ES2_DAY_LENGTH_MINUTES).with_sky_weather(false).with_story(false, false).with_combat(CombatPowerRules.classic(), false, true).with_decisions(CombatDecisionRules.classic()).with_death(PacingDefinition.ES2_DEATH_EXP_PERCENT, false, false, false).with_autosave(0).with_stats_display(false).with_map_page(false)


## The pacing a world of `pace` stands on, whichever the catalog stands on now: what a save of
## that pace is checked under before its session applies it.
static func of_save(catalog: ContentCatalog, pace: StringName) -> PacingDefinition:
	var current: PacingDefinition = catalog.pacing()
	return of(_base if not _paces.is_empty() and current == _applied else current, pace)


## Sets the catalog's pacing for `pace` and gives back what it was (restore() takes it).
static func apply(catalog: ContentCatalog, pace: StringName) -> PacingDefinition:
	var before: PacingDefinition = catalog.pacing()
	if before == null:
		return null
	if _paces.is_empty() or before != _applied:
		_paces.clear()
		_base = before
	_paces.append(pace)
	_applied = of(_base, pace)
	catalog.set_pacing(_applied)
	return _base


## The session of `pace` is gone: the catalog goes back to `before`, or to the pace of the
## session still standing on it.
static func restore(catalog: ContentCatalog, before: PacingDefinition, pace: StringName = CharacterState.PACE_MODERN) -> void:
	if before == null:
		return
	_paces.erase(pace)
	if _paces.is_empty():
		catalog.set_pacing(before)
		return
	_applied = of(_base, _paces[-1])
	catalog.set_pacing(_applied)


## The pace's name on the 角色 page.
static func shown_name(pace: StringName) -> String:
	# TRANSLATORS: the character sheet's pace line: 经典 is ES2's own numbers, 现代 the game's.
	return TranslationServer.translate("经典") if pace == CharacterState.PACE_CLASSIC else TranslationServer.translate("现代")
