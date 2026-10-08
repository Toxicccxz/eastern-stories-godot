class_name PlayerLifeFlow
extends RefCounted

## Time-driven part of the player's unconsciousness and death. The session
## feeds it frame time and acts on the events it returns; the rules themselves
## live in UnconsciousReviveDelay and PlayerDeathRules.
enum Phase { NONE, UNCONSCIOUS, DEATH_SEQUENCE }
enum Event { NONE, REVIVE_DUE, MESSAGE_SHOWN, REINCARNATE_DUE }

## d/death/npc/wgargoyle.c: call_out("death_stage", 5) before each line.
const DEATH_STAGE_SECONDS: float = 5.0
const DEATH_MESSAGES: Array[String] = [
	"白无常说道：喂！新来的，你叫什么名字？",
	"白无常用奇异的眼光盯著你，好像要看穿你的一切似的。",
	"白无常「哼」的一声，从袖中掏出一本像帐册的东西翻看著。",
	"白无常阁上册子，说道：咦？阳寿未尽？怎么可能？",
	"白无常搔了搔头，叹道：罢了罢了，你走吧。\n一股阴冷的浓雾突然出现，很快地包围了你。",
]

var _phase: Phase = Phase.NONE
var _revive_remaining: float = 0.0
var _revive_total: float = 0.0
var _world_scale: float = 1.0
var _stage_elapsed: float = 0.0
var _messages_shown: int = 0
var _death_result: PlayerDeathResult
var _corpse_place: String = ""
var _corpse_item_instance_id: StringName = &""

var phase: Phase:
	get: return _phase
var revive_remaining_seconds: float:
	get: return _revive_remaining
var death_result: PlayerDeathResult:
	get: return _death_result
var corpse_place: String:
	get: return _corpse_place
## The corpse the death left (empty when unknown), so the screen can tell whether it
## still lies there (化尸粉 destroys it with all it holds).
var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id


func is_active() -> bool:
	return _phase != Phase.NONE


## `delay_seconds` is damage.c's call_out("revive"), in world seconds. With
## `wake_seconds` > 0 (pacing knob player_wake_seconds) the player lies that long in
## real time while world time runs the whole delay (owner, A9).
func begin_unconscious(delay_seconds: int, wake_seconds: float = 0.0) -> void:
	_phase = Phase.UNCONSCIOUS
	_revive_remaining = float(delay_seconds)
	_revive_total = float(delay_seconds)
	_world_scale = maxf(1.0, float(delay_seconds) / wake_seconds) if wake_seconds > 0.0 else 1.0


## World seconds per real second now: above 1 only while the player lies unconscious
## with a quick wake.
func world_time_scale() -> float:
	return _world_scale if _phase == Phase.UNCONSCIOUS else 1.0


## The player lies in the dark for a few seconds, not the delay itself.
func wakes_quickly() -> bool:
	return _phase == Phase.UNCONSCIOUS and _world_scale > 1.0


## How much of the revive delay has passed, 0 to 1.
func revive_progress() -> float:
	return 1.0 if _revive_total <= 0.0 else clampf(1.0 - _revive_remaining / _revive_total, 0.0, 1.0)


## A death replaces a pending revive, as die() calls revive(1) first.
func begin_death(result: PlayerDeathResult, corpse_place: String, corpse_item_instance_id: StringName = &"") -> void:
	_phase = Phase.DEATH_SEQUENCE
	_death_result = result
	_corpse_place = corpse_place
	_corpse_item_instance_id = corpse_item_instance_id
	_stage_elapsed = 0.0
	_messages_shown = 0


func messages_shown() -> Array[String]:
	return DEATH_MESSAGES.slice(0, _messages_shown)


## Returns at most one event per call so the session handles each in order.
func advance(delta: float) -> Event:
	match _phase:
		Phase.UNCONSCIOUS:
			_revive_remaining = maxf(0.0, _revive_remaining - delta)
			return Event.REVIVE_DUE if _revive_remaining <= 0.0 else Event.NONE
		Phase.DEATH_SEQUENCE:
			_stage_elapsed += delta
			if _stage_elapsed < DEATH_STAGE_SECONDS:
				return Event.NONE
			return _show_next_message()
	return Event.NONE


## Presentation convenience: the player may read faster than the gargoyle talks.
func skip_to_next_message() -> Event:
	if _phase != Phase.DEATH_SEQUENCE:
		return Event.NONE
	return _show_next_message()


## The move to the revive room could not happen yet; try again next frame.
func retry_reincarnation() -> void:
	_stage_elapsed = DEATH_STAGE_SECONDS
	_messages_shown = DEATH_MESSAGES.size() - 1


func finish() -> void:
	_phase = Phase.NONE
	_revive_remaining = 0.0
	_revive_total = 0.0
	_world_scale = 1.0
	_stage_elapsed = 0.0


func _show_next_message() -> Event:
	_stage_elapsed = 0.0
	_messages_shown = mini(_messages_shown + 1, DEATH_MESSAGES.size())
	# death_stage(): the last line and reincarnate() happen together.
	return Event.REINCARNATE_DUE if _messages_shown >= DEATH_MESSAGES.size() else Event.MESSAGE_SHOWN
