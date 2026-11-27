class_name SceneStage
extends RefCounted

## 过场动作 (过场演出 B; DECISIONS「过场动作」): scene_stage.json — how long each of a scene's
## actions (SceneCue.WORDS) takes, how fast a staged walk goes, how a shot frames. Read once; the
## map's staging times the actions by it and the view frames and draws by it.

const DATA_PATH: String = "res://data/common/scene_stage.json"
const STORY_FX_PATH: String = "res://data/common/story_fx.json"

static var _data: Dictionary = {}
static var _fx: Array[String] = []


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## One of the file's records ("flight", "shots", "emerge", "dissolve").
static func part(key: String) -> Dictionary:
	var value: Variant = data().get(key, {})
	return value if value is Dictionary else {}


## Whether a scene's actions are shown at all (the feel's scene_action_ms).
static func on() -> bool:
	return GameContent.catalog().pacing().feel.scene_action_seconds() > 0.0


## Seconds the action `word` takes now (its share of the feel's scene_action_ms); 0: not shown.
static func seconds(word: StringName) -> float:
	return GameContent.catalog().pacing().feel.scene_action_seconds() * float(part("seconds").get(String(word), 1.0))


## Pixels a second a staged walk goes.
static func walk_speed() -> float:
	return maxf(1.0, float(data().get("walk_speed", 100.0)))


static func step_back_px() -> float:
	return float(data().get("step_back_px", 30.0))


## The scenes of story_fx.json by name (a step's `fx` is one of them).
static func fx_names() -> Array[String]:
	if _fx.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FX_PATH))
		var scenes: Variant = parsed.get("scenes", {}) if parsed is Dictionary else {}
		if scenes is Dictionary:
			for name: Variant in scenes:
				_fx.append(String(name))
	return _fx
