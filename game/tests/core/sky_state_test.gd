extends RefCounted

## 天气 (美术优化 G, owner 批准 2026-10-27; DECISIONS「天气」): natured.c's five weather_msg
## lines (day_phases.json sky_levels), the SkyState that turns through them one step at a
## time every 2–4 game hours from an injected stream, the pacing's sky_weather knob (ES2:
## off; 经典 off), and the catalog's lines.

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_lines()
	_turning()
	_knob()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _lines() -> void:
	var lines: Array[String] = GameContent.catalog().sky_levels()
	_check(lines.size() == SkyState.LEVELS, "five lines: %d" % lines.size())
	_check(lines.size() == 5 and lines[0] == "天空中万里无云" and lines[1] == "几朵淡淡的云彩妆点著清朗的天空" and lines[2] == "白云在天空中飘来飘去" and lines[3] == "厚厚的云层堆积在天边" and lines[4] == "天空中乌云密布", "natured.c's weather_msg as authored: %s" % [lines])
	var builder := ContentCatalogBuilder.new()
	builder.add_document({"sky_levels": ["a", "b", "c"]}, "t")
	builder.build()
	_check(builder.errors().any(func(e: String) -> bool: return e.contains("3 lines, not 5")), "three lines are refused: %s" % [builder.errors()])


func _turning() -> void:
	var sky := SkyState.new()
	_check(sky.level() == SkyState.NEW_GAME_LEVEL and sky.level() == 1 and sky.minutes_left() == 180, "a new game: a few light clouds, the first change in three hours")
	# ES2's day (24 real minutes): a real minute is a game hour.
	sky.set_state(2, 100)
	var random := GodotWorldInteractionRandomSource.new(11, true)
	_check(not sky.advance(60.0, 24, random) and sky.level() == 2 and sky.minutes_left() == 40, "an hour on, 40 minutes to go")
	_check(sky.advance(60.0, 24, random) and absi(sky.level() - 2) == 1 and sky.minutes_left() >= 100 and sky.minutes_left() <= 220, "the change comes on time, one step, the next 2–4 hours off less what ran over: %d, %d" % [sky.level(), sky.minutes_left()])
	# Fractions carry: 0.3 s steps at 24 min a day are 18 s each, with no drift.
	sky.set_state(2, 30)
	var still: bool = true
	for step: int in 99:
		still = still and not sky.advance(0.3, 24, random)
	_check(still and sky.minutes_left() == 0 and sky.level() == 2, "99 steps of 18 s leave 18 s: %d" % sky.minutes_left())
	_check(sky.advance(0.3, 24, random) and sky.level() != 2, "the hundredth changes it")
	_check(not sky.advance(0.0, 24, random) and not sky.advance(-1.0, 24, random) and not sky.advance(1.0, 0, random) and not sky.advance(1.0, 24, null), "no step for no time, no day length or no stream")
	# From the ends there is one way to go.
	sky.set_state(0, 1)
	_check(sky.advance(60.0, 24, random) and sky.level() == 1, "from 万里无云 only up")
	sky.set_state(4, 1)
	_check(sky.advance(60.0, 24, random) and sky.level() == 3, "from 乌云密布 only down")
	# A long run: every change one step within 0 .. 4, every wait 120 .. 240 minutes, the
	# same again from the same seed.
	var first: Array[int] = _run(SkyState.new(), GodotWorldInteractionRandomSource.new(23, true))
	var second: Array[int] = _run(SkyState.new(), GodotWorldInteractionRandomSource.new(23, true))
	var other: Array[int] = _run(SkyState.new(), GodotWorldInteractionRandomSource.new(24, true))
	_check(first == second and first != other and first.size() >= 30, "ten game days from one seed turn the same way, another seed differently: %d changes" % first.size())
	var steps: bool = true
	var previous: int = SkyState.NEW_GAME_LEVEL
	for level: int in first:
		steps = steps and absi(level - previous) == 1 and SkyState.is_valid_level(level)
		previous = level
	_check(steps, "each change one step, never past the ends: %s" % [first])
	_check(first.has(0) and first.has(4), "clear and overcast both come: %s" % [first])
	var waits: Array[int] = _waits(SkyState.new(), GodotWorldInteractionRandomSource.new(23, true))
	var within: bool = not waits.is_empty()
	for wait: int in waits:
		within = within and wait >= SkyState.MIN_MINUTES and wait <= SkyState.MAX_MINUTES
	_check(within, "every wait 120 .. 240 minutes: %s" % [waits])
	_check(SkyState.is_valid_level(0) and SkyState.is_valid_level(4) and not SkyState.is_valid_level(5) and not SkyState.is_valid_level(-1), "a level is 0 .. 4")
	_check(SkyState.is_valid_minutes_left(0) and SkyState.is_valid_minutes_left(240) and not SkyState.is_valid_minutes_left(241) and not SkyState.is_valid_minutes_left(-1), "minutes left are 0 .. 240")
	sky.set_state(9, 999)
	_check(sky.level() == 4 and sky.minutes_left() == 240, "set clamps")


## The levels after each change over ten game days of 0.5 s steps.
func _run(sky: SkyState, random: WorldInteractionRandomSource) -> Array[int]:
	var levels: Array[int] = []
	for step: int in 10 * 24 * 60 * 2:
		if sky.advance(0.5, 24, random):
			levels.append(sky.level())
	return levels


## The game minutes between changes (the wait drawn at each), the first from the new game's.
func _waits(sky: SkyState, random: WorldInteractionRandomSource) -> Array[int]:
	var waits: Array[int] = []
	var since: float = 0.0
	for step: int in 10 * 24 * 60 * 2:
		since += 0.5
		if sky.advance(0.5, 24, random):
			# A 0.5 s step is 30 game seconds: the wait in whole minutes, the overrun inside it.
			waits.append(roundi(since * 60.0 / 60.0))
			since = 0.0
	waits.remove_at(0)
	return waits


func _knob() -> void:
	_check(not PacingDefinition.new(1000).sky_weather, "constructed without the knob: ES2 shows no weather")
	var errors: Array[String] = []
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "sky_weather": true}, "pacing", errors))
	_check(read.sky_weather and errors.is_empty() and read.copy().sky_weather, "read and copied")
	_check(not PacePresets.of(read, CharacterState.PACE_CLASSIC).sky_weather and PacePresets.of(read, CharacterState.PACE_MODERN).sky_weather, "经典 turns it off; 现代 keeps the catalog's")
	_check(GameContent.catalog().pacing().sky_weather, "pacing.json: on")


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
