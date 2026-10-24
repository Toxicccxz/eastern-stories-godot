class_name FeelDefinition
extends RefCounted

## How the world feels to move through (现代化修正 III B「手感」, DECISIONS「手感」): the
## `feel` record inside game/data/common/pacing.json. Each knob changes only how a thing
## shows, never what happens; left out, each is 0, which is how the game looked before:
## - map_fade_out_ms / map_fade_in_ms: the screen goes dark before a walked passage
##   changes the map, and comes back after any map change.
## - map_banner_ms: how long the region and place name shows on arriving on another map.
## - door_fade_out_ms / door_fade_in_ms: the same, shorter, for a door: a walked passage
##   into or out of a building's own map (MapDefinition.interior), which shows no banner.
## - camera_follow_speed: Camera2D position smoothing (0: the camera sticks to the player).
## - move_accel_ms / move_stop_ms: the player's walk reaches full speed / stops in this long.
## - speech_bubble_ms / speech_bubble_char_ms: how long a line an NPC says stays over its
##   head, and how much longer for each character past BUBBLE_SHORT_CHARACTERS (0: none,
##   and what NPCs say shows in the bottom left's toasts as before).
## - speech_reach_px: how near (and on the screen) the player must be for an NPC's
##   greeting and chat (DECISIONS「说话和交互」); 0: anywhere in its room, as ES2.
## - room_text_ms / room_text_char_ms: a room's title and description show at the top this
##   long on coming into it, and this much longer for each character past
##   ROOM_TEXT_SHORT_CHARACTERS (0: in the bottom left's toasts, as before).
## - menu_fade_ms: the menu window (and the battle panel) fades in (0: at once).
## - battle_slow_percent / battle_fast_percent: the real time a round takes at the
##   战斗速度 慢 / 快, in percent of the round (BattlePace; 0: as 标准).
## - battle_line_ms: a round's lines come this far apart (sooner when they would not
##   be told before the next round); 0: all at once.
## - bar_tween_ms: a card's 气 bar moves to its new value in this long.
## - hit_flash_ms: a card flashes red this long when its fighter loses 气 (the setting
##   受击闪红 turns it off).
## - battle_end_hold_ms: the battle panel stays this long on a fight's last lines, the
##   world held, before the result and the world come back.
## - training_step_ms: a continuous 请教 / 练习 / 打坐 takes its steps this far apart, the
##   progress shown between them (0: all at once; DECISIONS「连续修炼」).
## - corner_slide_px: the player's walk keeps its speed along a wall it runs into, and run
##   nearly head-on into an edge it looks this far to either side for an opening and slips
##   round it (0: move_and_slide alone; DECISIONS「手感」).

## A bubble of this many characters or fewer shows for speech_bubble_ms alone.
const BUBBLE_SHORT_CHARACTERS: int = 24
## A room text of this many characters or fewer shows for room_text_ms alone.
const ROOM_TEXT_SHORT_CHARACTERS: int = 40

var _map_fade_out_ms: int = 0
var _map_fade_in_ms: int = 0
var _map_banner_ms: int = 0
var _door_fade_out_ms: int = 0
var _door_fade_in_ms: int = 0
var _camera_follow_speed: int = 0
var _move_accel_ms: int = 0
var _move_stop_ms: int = 0
var _speech_bubble_ms: int = 0
var _speech_bubble_char_ms: int = 0
var _speech_reach_px: int = 0
var _room_text_ms: int = 0
var _room_text_char_ms: int = 0
var _menu_fade_ms: int = 0
var _battle_slow_percent: int = 0
var _battle_fast_percent: int = 0
var _battle_line_ms: int = 0
var _bar_tween_ms: int = 0
var _hit_flash_ms: int = 0
var _battle_end_hold_ms: int = 0
var _training_step_ms: int = 0
var _corner_slide_px: int = 0

var map_fade_out_seconds: float:
	get:
		return float(_map_fade_out_ms) / 1000.0
var map_fade_in_seconds: float:
	get:
		return float(_map_fade_in_ms) / 1000.0
var map_banner_seconds: float:
	get:
		return float(_map_banner_ms) / 1000.0
var door_fade_out_seconds: float:
	get:
		return float(_door_fade_out_ms) / 1000.0
var door_fade_in_seconds: float:
	get:
		return float(_door_fade_in_ms) / 1000.0
var camera_follow_speed: float:
	get:
		return float(_camera_follow_speed)
var move_accel_seconds: float:
	get:
		return float(_move_accel_ms) / 1000.0
var move_stop_seconds: float:
	get:
		return float(_move_stop_ms) / 1000.0
var corner_slide_px: float:
	get:
		return float(_corner_slide_px)
var speech_reach: float:
	get:
		return float(_speech_reach_px)
var menu_fade_seconds: float:
	get:
		return float(_menu_fade_ms) / 1000.0
var battle_slow_percent: int:
	get:
		return _battle_slow_percent
var battle_fast_percent: int:
	get:
		return _battle_fast_percent
var battle_line_seconds: float:
	get:
		return float(_battle_line_ms) / 1000.0
var bar_tween_seconds: float:
	get:
		return float(_bar_tween_ms) / 1000.0
var hit_flash_seconds: float:
	get:
		return float(_hit_flash_ms) / 1000.0
var battle_end_hold_seconds: float:
	get:
		return float(_battle_end_hold_ms) / 1000.0
var training_step_seconds: float:
	get:
		return float(_training_step_ms) / 1000.0


## Seconds a bubble saying `line` stays up (0: no bubbles).
func bubble_seconds(line: String) -> float:
	if _speech_bubble_ms <= 0:
		return 0.0
	var extra: int = maxi(0, line.length() - BUBBLE_SHORT_CHARACTERS)
	return float(_speech_bubble_ms + extra * _speech_bubble_char_ms) / 1000.0


## NPCs' lines show over their heads (not as toasts).
func shows_bubbles() -> bool:
	return _speech_bubble_ms > 0


## Seconds a room's `text` stays at the top (0: rooms are told in the toasts).
func room_text_seconds(text: String) -> float:
	if _room_text_ms <= 0:
		return 0.0
	var extra: int = maxi(0, text.length() - ROOM_TEXT_SHORT_CHARACTERS)
	return float(_room_text_ms + extra * _room_text_char_ms) / 1000.0


## This record with every knob set (milliseconds; tests, and from_record()).
func with_values(values: Dictionary) -> FeelDefinition:
	_map_fade_out_ms = int(values.get("map_fade_out_ms", _map_fade_out_ms))
	_map_fade_in_ms = int(values.get("map_fade_in_ms", _map_fade_in_ms))
	_map_banner_ms = int(values.get("map_banner_ms", _map_banner_ms))
	_door_fade_out_ms = int(values.get("door_fade_out_ms", _door_fade_out_ms))
	_door_fade_in_ms = int(values.get("door_fade_in_ms", _door_fade_in_ms))
	_camera_follow_speed = int(values.get("camera_follow_speed", _camera_follow_speed))
	_move_accel_ms = int(values.get("move_accel_ms", _move_accel_ms))
	_move_stop_ms = int(values.get("move_stop_ms", _move_stop_ms))
	_speech_bubble_ms = int(values.get("speech_bubble_ms", _speech_bubble_ms))
	_speech_bubble_char_ms = int(values.get("speech_bubble_char_ms", _speech_bubble_char_ms))
	_speech_reach_px = int(values.get("speech_reach_px", _speech_reach_px))
	_room_text_ms = int(values.get("room_text_ms", _room_text_ms))
	_room_text_char_ms = int(values.get("room_text_char_ms", _room_text_char_ms))
	_menu_fade_ms = int(values.get("menu_fade_ms", _menu_fade_ms))
	_battle_slow_percent = int(values.get("battle_slow_percent", _battle_slow_percent))
	_battle_fast_percent = int(values.get("battle_fast_percent", _battle_fast_percent))
	_battle_line_ms = int(values.get("battle_line_ms", _battle_line_ms))
	_bar_tween_ms = int(values.get("bar_tween_ms", _bar_tween_ms))
	_hit_flash_ms = int(values.get("hit_flash_ms", _hit_flash_ms))
	_battle_end_hold_ms = int(values.get("battle_end_hold_ms", _battle_end_hold_ms))
	_training_step_ms = int(values.get("training_step_ms", _training_step_ms))
	_corner_slide_px = int(values.get("corner_slide_px", _corner_slide_px))
	return self


const KEYS: Array[String] = [
	"map_fade_out_ms", "map_fade_in_ms", "map_banner_ms", "door_fade_out_ms", "door_fade_in_ms", "camera_follow_speed", "move_accel_ms",
	"move_stop_ms", "speech_bubble_ms", "speech_bubble_char_ms", "speech_reach_px", "room_text_ms", "room_text_char_ms", "menu_fade_ms", "battle_slow_percent",
	"battle_fast_percent", "battle_line_ms", "bar_tween_ms", "hit_flash_ms", "battle_end_hold_ms",
	"training_step_ms", "corner_slide_px",
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
