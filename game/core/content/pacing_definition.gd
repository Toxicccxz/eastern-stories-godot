class_name PacingDefinition
extends RefCounted

## Game-wide timing, one record in game/data/common/pacing.json. ES2 ran every
## living object on one driver heart_beat; the native combat round is that beat.
## Rooms reset on the driver's `time to reset` (adm/etc/config.ES2: 1800).
##
## The single-player pacing knobs (DECISIONS, pacing knobs) scale what a rule
## yields without changing the rule; a record that leaves one out gets ES2's pace:
## - player_exp_gain: what combatd.c do_attack() gives the player per gain, the
##   +1 combat_exp and the +1 potential (still only up to 100 unspent).
## - player_recovery_gain: what damage.c heal_up() restores to the player per tick
##   (gin/kee/sen, their effective values, atman/force/mana); not its food or water.
## - quest_time_percent: the time 朱鸿雪 (u/cloud/npc/god.c) gives for a task.
## - npc_thirst: the water an NPC uses up on one heal_up() tick (ES2: 1). Only a
##   drinking NPC cares (d/snow/npc/drunk.c drinks again once below 380 water).
## - player_wake_seconds: how long an unconscious player's screen stays dark, in real
##   seconds, while world time runs damage.c's whole revive delay (random(100 - con)
##   + 30) that much faster (owner, modern fixes II, A9). 0 (ES2): the player waits
##   the delay itself.
const ES2_ROOM_RESET_SECONDS: int = 1800
const ES2_GAIN: int = 1
const ES2_QUEST_TIME_PERCENT: int = 100
const ES2_WAKE_SECONDS: int = 0

var _combat_round_ms: int
var _room_reset_seconds: int
var _player_exp_gain: int
var _player_recovery_gain: int
var _quest_time_percent: int
var _npc_thirst: int
var _player_wake_seconds: int

## Seconds between two combat rounds of an encounter (the scheduler's opportunity interval).
var combat_round_seconds: float:
	get:
		return float(_combat_round_ms) / 1000.0
## MudOS TIME_TO_RESET: a room resets half to all of this many seconds after its last reset.
var room_reset_seconds: int:
	get:
		return _room_reset_seconds
## Combat experience (and potential) the player gets where combatd.c gives 1.
var player_exp_gain: int:
	get:
		return _player_exp_gain
## Times what heal_up() restores to the player on one tick.
var player_recovery_gain: int:
	get:
		return _player_recovery_gain
## 朱鸿雪's time for a task, in percent of the qlist time.
var quest_time_percent: int:
	get:
		return _quest_time_percent
## Water an NPC uses up on one heal_up() tick, where damage.c uses 1.
var npc_thirst: int:
	get:
		return _npc_thirst
## Real seconds an unconscious player lies in the dark (0: the whole revive delay).
var player_wake_seconds: int:
	get:
		return _player_wake_seconds


func _init(
	p_combat_round_ms: int = 0,
	p_room_reset_seconds: int = ES2_ROOM_RESET_SECONDS,
	p_player_exp_gain: int = ES2_GAIN,
	p_player_recovery_gain: int = ES2_GAIN,
	p_quest_time_percent: int = ES2_QUEST_TIME_PERCENT,
	p_npc_thirst: int = ES2_GAIN,
	p_player_wake_seconds: int = ES2_WAKE_SECONDS,
) -> void:
	_combat_round_ms = p_combat_round_ms
	_room_reset_seconds = p_room_reset_seconds
	_player_exp_gain = p_player_exp_gain
	_player_recovery_gain = p_player_recovery_gain
	_quest_time_percent = p_quest_time_percent
	_npc_thirst = p_npc_thirst
	_player_wake_seconds = p_player_wake_seconds


static func from_record(reader: ContentRecordReader) -> PacingDefinition:
	var definition: PacingDefinition = PacingDefinition.new(
		reader.required_integer("combat_round_ms"),
		reader.integer("room_reset_seconds", ES2_ROOM_RESET_SECONDS),
		reader.integer("player_exp_gain", ES2_GAIN),
		reader.integer("player_recovery_gain", ES2_GAIN),
		reader.integer("quest_time_percent", ES2_QUEST_TIME_PERCENT),
		reader.integer("npc_thirst", ES2_GAIN),
		reader.integer("player_wake_seconds", ES2_WAKE_SECONDS),
	)
	reader.finish()
	if definition._combat_round_ms <= 0:
		reader.fail("combat_round_ms", "must be positive")
	if definition._room_reset_seconds < 2:
		reader.fail("room_reset_seconds", "must be at least 2")
	if definition._player_exp_gain < 1:
		reader.fail("player_exp_gain", "must be at least 1")
	if definition._player_recovery_gain < 1:
		reader.fail("player_recovery_gain", "must be at least 1")
	if definition._quest_time_percent < 1:
		reader.fail("quest_time_percent", "must be at least 1")
	if definition._npc_thirst < 1:
		reader.fail("npc_thirst", "must be at least 1")
	if definition._player_wake_seconds < 0:
		reader.fail("player_wake_seconds", "must not be negative")
	return definition
