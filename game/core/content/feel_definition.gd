class_name FeelDefinition
extends RefCounted

## How the world feels to move through (现代化修正 III B「手感」, DECISIONS「手感」): the
## `feel` record inside game/data/common/pacing.json. Each knob changes only how a thing
## shows, never what happens; left out, each is 0, which is how the game looked before:
## - map_fade_out_ms / map_fade_in_ms: the screen goes dark before a walked passage
##   changes the map, and comes back after any map change.
## - map_banner_ms: how long the region and place name shows on arriving on another map.
## - camera_follow_speed: Camera2D position smoothing (0: the camera sticks to the player).
## - move_accel_ms / move_stop_ms: the player's walk reaches full speed / stops in this long.
## - speech_bubble_ms / speech_bubble_char_ms: how long a line an NPC says stays over its
##   head, and how much longer for each character past BUBBLE_SHORT_CHARACTERS (0: none).
## - menu_fade_ms: the menu window fades in and out (0: at once).

## A bubble of this many characters or fewer shows for speech_bubble_ms alone.
const BUBBLE_SHORT_CHARACTERS: int = 24

var _map_fade_out_ms: int = 0
var _map_fade_in_ms: int = 0
var _map_banner_ms: int = 0
var _camera_follow_speed: int = 0
var _move_accel_ms: int = 0
var _move_stop_ms: int = 0
var _speech_bubble_ms: int = 0
var _speech_bubble_char_ms: int = 0
var _menu_fade_ms: int = 0

var map_fade_out_seconds: float:
	get:
		return float(_map_fade_out_ms) / 1000.0
var map_fade_in_seconds: float:
	get:
		return float(_map_fade_in_ms) / 1000.0
var map_banner_seconds: float:
	get:
		return float(_map_banner_ms) / 1000.0
var camera_follow_speed: float:
	get:
		return float(_camera_follow_speed)
var move_accel_seconds: float:
	get:
		return float(_move_accel_ms) / 1000.0
var move_stop_seconds: float:
	get:
		return float(_move_stop_ms) / 1000.0
var menu_fade_seconds: float:
	get:
		return float(_menu_fade_ms) / 1000.0


## Seconds a bubble saying `line` stays up (0: no bubbles).
func bubble_seconds(line: String) -> float:
	if _speech_bubble_ms <= 0:
		return 0.0
	var extra: int = maxi(0, line.length() - BUBBLE_SHORT_CHARACTERS)
	return float(_speech_bubble_ms + extra * _speech_bubble_char_ms) / 1000.0


## This record with every knob set (milliseconds; tests, and from_record()).
func with_values(values: Dictionary) -> FeelDefinition:
	_map_fade_out_ms = int(values.get("map_fade_out_ms", _map_fade_out_ms))
	_map_fade_in_ms = int(values.get("map_fade_in_ms", _map_fade_in_ms))
	_map_banner_ms = int(values.get("map_banner_ms", _map_banner_ms))
	_camera_follow_speed = int(values.get("camera_follow_speed", _camera_follow_speed))
	_move_accel_ms = int(values.get("move_accel_ms", _move_accel_ms))
	_move_stop_ms = int(values.get("move_stop_ms", _move_stop_ms))
	_speech_bubble_ms = int(values.get("speech_bubble_ms", _speech_bubble_ms))
	_speech_bubble_char_ms = int(values.get("speech_bubble_char_ms", _speech_bubble_char_ms))
	_menu_fade_ms = int(values.get("menu_fade_ms", _menu_fade_ms))
	return self


const KEYS: Array[String] = [
	"map_fade_out_ms", "map_fade_in_ms", "map_banner_ms", "camera_follow_speed", "move_accel_ms",
	"move_stop_ms", "speech_bubble_ms", "speech_bubble_char_ms", "menu_fade_ms",
]


static func from_record(reader: ContentRecordReader) -> FeelDefinition:
	var values: Dictionary = {}
	for key: String in KEYS:
		values[key] = reader.integer(key, 0)
	reader.finish()
	for key: String in KEYS:
		if int(values[key]) < 0:
			reader.fail(key, "must not be negative")
	return FeelDefinition.new().with_values(values)
