extends RefCounted

## 昼夜 (DECISIONS「昼夜」): natured.c's eight phases (day_phases.json), the DayClock that goes
## round them, the pacing's day_length_minutes (ES2's 24, 经典 24), and the voxel light's five
## frames over them (VoxelLighting.frame_weights_at(), resolve_frames(), merge_profile()).

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_phases()
	_clock()
	_day_length()
	_frame_weights()
	_resolve_and_merge()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _phases() -> void:
	var phases: Array[DayPhaseDefinition] = GameContent.catalog().day_phases()
	var ids: Array[StringName] = []
	var total: int = 0
	for phase: DayPhaseDefinition in phases:
		ids.append(phase.phase_id)
		total += phase.minutes
	_check(ids == [&"dawn", &"sunrise", &"morning", &"noon", &"afternoon", &"evening", &"night", &"midnight"], "day_phase's eight phases in order: %s" % [ids])
	_check(total == DayClock.DAY_MINUTES, "their lengths add up to 1440: %d" % total)
	_check(phases[0].minutes == 240 and phases[1].minutes == 120 and phases[6].minutes == 120 and phases[7].minutes == 240, "微曦 240, 日出 120, 夜晚 120, 午夜 240")
	_check(phases[5].time_msg == "傍晚了，太阳的馀晖将西方的天空映成一片火红。" and phases[5].desc_msg == "一轮火红的夕阳正徘徊在西方的地平线上", "傍晚's two lines as authored")
	_check(phases[0].frame == "dawn" and phases[1].frame == "dawn" and phases[2].frame == "day" and phases[4].frame == "day" and phases[5].frame == "dusk" and phases[6].frame == "night" and phases[7].frame == "midnight", "the phases' lighting frames")
	var errors: Array[String] = []
	var bad: ContentRecordReader = ContentRecordReader.new({"phase_id": "x", "name": "x", "minutes": 0, "frame": "noon", "time_msg": "a", "desc_msg": "b"}, "p", errors)
	DayPhaseDefinition.from_record(bad)
	_check(errors.size() == 2, "a phase of no length or an unknown frame is refused: %s" % [errors])
	var builder := ContentCatalogBuilder.new()
	builder.add_document({"day_phases": [{"phase_id": "a", "name": "a", "minutes": 1000, "time_msg": "a", "desc_msg": "a"}, {"phase_id": "b", "name": "b", "minutes": 400, "time_msg": "b", "desc_msg": "b"}]}, "t")
	builder.build()
	_check(builder.errors().any(func(e: String) -> bool: return e.contains("1400 minutes")), "phases that do not make a day are refused: %s" % [builder.errors()])


func _clock() -> void:
	var clock := DayClock.new(GameContent.catalog().day_phases())
	_check(clock.day_seconds() == 21600 and clock.phase().phase_id == &"morning" and is_zero_approx(clock.phase_progress()), "a new game starts at 6:00, the morning just begun")
	_check(clock.advance(60.0, 24) == null and clock.day_seconds() == 21600 + 3600, "ES2's day: a real minute is a game hour")
	clock.set_day_seconds(21600)
	_check(clock.advance(60.0, 48) == null and clock.day_seconds() == 21600 + 1800, "a 48-minute day: a real minute is half a game hour")
	clock.set_day_seconds(539 * 60 + 59)
	var began: DayPhaseDefinition = clock.advance(2.0, 24)
	_check(began != null and began.phase_id == &"noon" and clock.phase().phase_id == &"noon", "crossing into 正午 says so once")
	_check(clock.advance(1.0, 24) == null, "and not again within it")
	clock.set_day_seconds(1439 * 60)
	began = clock.advance(2.0, 24)
	_check(began != null and began.phase_id == &"dawn" and clock.day_seconds() == 60, "midnight wraps into 微曦: %d" % clock.day_seconds())
	clock.set_day_seconds(700 * 60)
	_check(is_equal_approx(clock.phase_progress(), (700.0 - 540.0) / 180.0) and clock.phase().phase_id == &"noon", "progress through the phase")
	_check(clock.advance(0.0, 24) == null and clock.advance(-1.0, 24) == null and clock.advance(1.0, 0) == null and clock.day_seconds() == 700 * 60, "no step for no time or no day length")
	# Fractions carry: 0.3 s steps at 24 min a day are 18 s each, with no drift.
	clock.set_day_seconds(0)
	for step: int in 100:
		clock.advance(0.3, 24)
	_check(clock.day_seconds() == 1800, "a hundred 0.3 s steps are exactly 30 game minutes: %d" % clock.day_seconds())
	_check(DayClock.is_valid_day_seconds(0) and DayClock.is_valid_day_seconds(86399) and not DayClock.is_valid_day_seconds(86400) and not DayClock.is_valid_day_seconds(-1), "a time of day is 0 .. 86399")
	clock.set_day_seconds(-60)
	_check(clock.day_seconds() == 86340, "set wraps")
	var bare := DayClock.new()
	_check(bare.phase() == null and bare.advance(5.0, 24) == null and bare.day_seconds() == 21900, "without phases the clock still goes, saying nothing")


func _day_length() -> void:
	_check(PacingDefinition.new(1000).day_length_minutes == 24 and PacingDefinition.ES2_DAY_LENGTH_MINUTES == 24, "constructed without the knob: ES2's 24 minutes")
	var errors: Array[String] = []
	var read: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "day_length_minutes": 48}, "pacing", errors))
	_check(read.day_length_minutes == 48 and errors.is_empty() and read.copy().day_length_minutes == 48, "read and copied")
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "day_length_minutes": 0}, "pacing", errors))
	_check(errors.size() == 1, "a day of no length is refused")
	# The runner keeps the day standing still (TestDay); pacing.json's own value is 24.
	TestDay.use()
	var production: PacingDefinition = GameContent.catalog().pacing()
	_check(production.day_length_minutes == 24, "pacing.json: 24 (owner Q3: the default is ES2's)")
	TestDay.restore()
	_check(PacePresets.of(read, CharacterState.PACE_CLASSIC).day_length_minutes == 24 and PacePresets.of(read, CharacterState.PACE_MODERN).day_length_minutes == 48, "经典 puts the day back to 24; 现代 keeps the catalog's")


func _frame_weights() -> void:
	var phases: Array[DayPhaseDefinition] = GameContent.catalog().day_phases()
	_check(_one(VoxelLighting.frame_weights_at(180.0, phases), "dawn") and _one(VoxelLighting.frame_weights_at(630.0, phases), "day") and _one(VoxelLighting.frame_weights_at(990.0, phases), "dusk") and _one(VoxelLighting.frame_weights_at(1140.0, phases), "night") and _one(VoxelLighting.frame_weights_at(1320.0, phases), "midnight"), "each frame is itself through the middle of its phases")
	var boundary: Dictionary[String, float] = VoxelLighting.frame_weights_at(360.0, phases)
	_check(is_equal_approx(boundary["dawn"], 0.5) and is_equal_approx(boundary["day"], 0.5), "halfway between dawn and day as 日出 ends: %s" % [boundary])
	# 傍晚 is 180 minutes: its margin is 45, the day's 60, so its first minute is already 60/105 dusk.
	var evening: Dictionary[String, float] = VoxelLighting.frame_weights_at(900.0, phases)
	_check(is_equal_approx(evening["day"], 45.0 / 105.0) and is_equal_approx(evening["dusk"], 60.0 / 105.0), "between day and dusk as 傍晚 begins: %s" % [evening])
	_check(_one(VoxelLighting.frame_weights_at(1000.0, phases), "dusk") and _one(VoxelLighting.frame_weights_at(960.0, phases), "dusk"), "dusk holds through the middle 90 minutes of 傍晚")
	var wrap: Dictionary[String, float] = VoxelLighting.frame_weights_at(0.0, phases)
	_check(is_equal_approx(wrap["midnight"], 0.5) and is_equal_approx(wrap["dawn"], 0.5), "midnight blends into dawn over 0:00: %s" % [wrap])
	var smooth: bool = true
	var previous: Dictionary[String, float] = VoxelLighting.frame_weights_at(-1.0, phases)
	for minute: int in 1441:
		var now: Dictionary[String, float] = VoxelLighting.frame_weights_at(float(minute), phases)
		var total: float = 0.0
		for frame: String in VoxelLighting.FRAMES:
			total += now[frame]
			smooth = smooth and absf(now[frame] - previous[frame]) < 0.02 and now[frame] >= 0.0
		smooth = smooth and is_equal_approx(total, 1.0)
		previous = now
	_check(smooth, "the weights sum to one and never jump through the day")
	_check(_one(VoxelLighting.frame_weights_at(500.0, []), "day"), "without phases: day")


func _resolve_and_merge() -> void:
	var pair: Dictionary = VoxelLighting.resolve_frames(["000000", "ffffff"])
	_check(pair["day"] == "000000" and pair["night"] == "ffffff" and pair["midnight"] == "ffffff", "a [day, night] pair: day, night, midnight as night")
	_check(pair["dawn"] == Color("ffffff").lerp(Color("000000"), 0.4).to_html(false) and pair["dusk"] == Color("000000").lerp(Color("ffffff"), 360.0 / 510.0).to_html(false), "dawn and dusk interpolated by their minutes: %s" % [pair])
	var numbers: Dictionary = VoxelLighting.resolve_frames([0.0, 1.0])
	_check(is_equal_approx(float(numbers["dusk"]), 360.0 / 510.0) and is_equal_approx(float(numbers["midnight"]), 1.0), "numbers too")
	var one: Dictionary = VoxelLighting.resolve_frames({"dusk": "ff8800"})
	_check(one["dawn"] == "ff8800" and one["midnight"] == "ff8800", "one frame written: every frame is it")
	var angles: Dictionary = VoxelLighting.resolve_frames({"day": [-55.0, -32.0], "night": [-43.0, -55.0]})
	_check(angles["dusk"] is Array and is_equal_approx(float(angles["dusk"][0]), lerpf(-55.0, -43.0, 360.0 / 510.0)), "arrays element by element")
	_check(VoxelLighting.resolve_frames({}).is_empty() and VoxelLighting.resolve_frames(["x"]).is_empty(), "nothing written: nothing")
	var region: Dictionary = {"sky": {"dawn": "a", "day": "b", "dusk": "c", "night": "d", "midnight": "e"}, "sun_energy": {"day": 0.9, "night": 0.3}, "carried": {"day": 0.0, "night": 1.0}, "fog": {"color": {"day": "f", "night": "g"}, "height": -3.0}}
	var merged: Dictionary = VoxelLighting.merge_profile(region, {"sky": {"dusk": "x"}, "sun_energy": [0.5, 0.1], "carried": {"day": 0.2}, "fog": {"color": {"dusk": "h"}, "depth": [1, 2]}, "areas": [{"rect": [0, 0, 1, 1]}]})
	_check(merged["sky"] == {"dawn": "a", "day": "b", "dusk": "x", "night": "d", "midnight": "e"}, "a frame written by the map replaces that frame alone: %s" % [merged["sky"]])
	_check(merged["sun_energy"] == [0.5, 0.1], "a map's pair replaces the region's key whole")
	_check(merged["carried"] == {"day": 0.2} and merged["areas"].size() == 1, "carried and areas are the map's")
	_check(merged["fog"]["color"] == {"day": "f", "night": "g", "dusk": "h"} and merged["fog"]["height"] == -3.0 and merged["fog"]["depth"] == [1, 2], "fog merges key by key, its colours frame by frame")
	_check(region["sky"]["dusk"] == "c" and VoxelLighting.merge_profile({}, {"sky": ["a", "b"]}) == {"sky": ["a", "b"]}, "the region's own record is untouched; no region: the map's")


func _one(weights: Dictionary[String, float], frame: String) -> bool:
	for name: String in VoxelLighting.FRAMES:
		if not is_equal_approx(weights[name], 1.0 if name == frame else 0.0):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
