class_name CombatStyle
extends RefCounted

## 战斗决策层 4 (DECISIONS「战斗内容」): an NPC's fight style — how the move its telegraph draws
## one beat early is weighed by tag, how long its specials rest after one, and how both
## change once it is hurt. Data (data/common/combat_styles.json); an NPC names its style
## (`fight_style`) or takes its race's default. Classic (no telegraph) never reads one:
## the move is random(n) as combatd.c, the special runs when chat() draws it.

## The style IDs the first two hours use; any other is data.
const STEADY: StringName = &"steady"
const BEAST: StringName = &"beast"

var style_id: StringName
## Player text ("稳健"), for the 见识录 and tests.
var display_name: String = ""
## Weight per tag (CombatMoveTags; 平 under &""), 1 when left out. All 1: random(n).
var tag_weights: Dictionary[StringName, int] = {}
## Rounds a special rests after one ran; -1 takes the pacing knob.
var cooldown_rounds: int = -1
## Whether its chat()'s specials run at all (a beast has none to run; false drops them).
var specials: bool = true
## The 气 percent (status_msg's) under which `hurt_tag_weights` / `hurt_cooldown_rounds`
## replace the two above; 0: never.
var hurt_below: int = 0
var hurt_tag_weights: Dictionary[StringName, int] = {}
var hurt_cooldown_rounds: int = -1
## Whether this style is the default of a race (`default_for`: "human", "beast").
var default_for: Array[StringName] = []


func _init(p_style_id: StringName = &"", p_display_name: String = "") -> void:
	style_id = p_style_id
	display_name = p_display_name


func is_hurt(kee_percent: int) -> bool:
	return hurt_below > 0 and kee_percent < hurt_below


## The weights the move draw uses at `kee_percent` 气.
func weights_at(kee_percent: int) -> Dictionary[StringName, int]:
	return hurt_tag_weights if is_hurt(kee_percent) and not hurt_tag_weights.is_empty() else tag_weights


## The rest a special takes at `kee_percent` 气; `fallback` is the pacing knob.
func cooldown_at(kee_percent: int, fallback: int) -> int:
	var rounds: int = hurt_cooldown_rounds if is_hurt(kee_percent) and hurt_cooldown_rounds >= 0 else cooldown_rounds
	return fallback if rounds < 0 else rounds


## {id, name, weights?: {quick, heavy, feint, guard, plain}, cooldown?, specials?,
## hurt_below?, hurt_weights?, hurt_cooldown?, default_for?: [race]}
static func from_record(reader: ContentRecordReader) -> CombatStyle:
	var style := CombatStyle.new(StringName(reader.required_text("id")), reader.required_text("name"))
	style.tag_weights = _weights(reader, "weights")
	style.cooldown_rounds = reader.integer("cooldown", -1)
	style.specials = reader.boolean("specials", true)
	style.hurt_below = reader.integer("hurt_below", 0)
	style.hurt_tag_weights = _weights(reader, "hurt_weights")
	style.hurt_cooldown_rounds = reader.integer("hurt_cooldown", -1)
	for race: String in reader.text_list("default_for"):
		style.default_for.append(StringName(race))
	if style.hurt_below < 0 or style.hurt_below > 100:
		reader.fail("hurt_below", "a kee percent, 0 to 100")
	reader.finish()
	return style


static func _weights(reader: ContentRecordReader, key: String) -> Dictionary[StringName, int]:
	var weights: Dictionary[StringName, int] = {}
	if not reader.has(key):
		return weights
	var map: Dictionary[String, int] = reader.integer_map(key)
	for name: String in map:
		var tag: StringName = CombatMoveTags.NONE if name == "plain" else StringName(name)
		if not CombatMoveTags.is_valid(tag):
			reader.fail(key, "'%s' is not a move tag (quick, heavy, feint, guard, plain)" % name)
			continue
		if map[name] < 0:
			reader.fail(key, "a weight must not be negative")
			continue
		weights[tag] = map[name]
	return weights
