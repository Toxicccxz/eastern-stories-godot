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
##
## The responsiveness knobs (现代化修正 III, DECISIONS「响应性」): each changes when
## something shows, never what happens; left out, each is ES2's:
## - reaction_beat_ms: an NPC's call_out answering what the player just did (a master's
##   拜师 answer, a greeting, a sentence, a dissolve, a zombie's end) comes at most this
##   long after it (ES2: each call_out's own 1-3 s, kept in the NPC's data). 0: ES2.
## - trial_blow_ms: the time between a master's test blows (三招, 三鞭); ES2's
##   champion.c strikes all three in one command. 0: ES2.
## - heart_beat_ms: the driver heart_beat outside a fight (ES2: "usually 2 seconds",
##   DECISIONS S5B B): NPC chat, busy wearing off, heal_up's tick count.
## - dim_fade_ms: how long the screen takes to go dark when the player falls unconscious.
##   0 (ES2 has no screen): at once.
## - away_catch_up_limit_seconds (DECISIONS「别的地图时间补算」): a map the player was away
##   from longer catches up this much of its NPCs' heart beat, and the rest comes to what
##   it would given time enough (healed, awake, conditions over). 0 (ES2): all of it.
const ES2_ROOM_RESET_SECONDS: int = 1800
const ES2_GAIN: int = 1
const ES2_QUEST_TIME_PERCENT: int = 100
const ES2_WAKE_SECONDS: int = 0
const ES2_HEART_BEAT_MS: int = 2000

var _combat_round_ms: int
var _room_reset_seconds: int
var _player_exp_gain: int
var _player_recovery_gain: int
var _quest_time_percent: int
var _npc_thirst: int
var _player_wake_seconds: int
var _reaction_beat_ms: int = 0
var _trial_blow_ms: int = 0
var _heart_beat_ms: int = ES2_HEART_BEAT_MS
var _dim_fade_ms: int = 0
var _away_catch_up_limit_seconds: int = 0

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
## Seconds between a master's test blows (0: all in one go).
var trial_blow_seconds: float:
	get:
		return float(_trial_blow_ms) / 1000.0
## Seconds of one heart beat outside a fight.
var heart_beat_seconds: float:
	get:
		return float(_heart_beat_ms) / 1000.0
## Seconds the screen takes to go dark for an unconscious player (0: at once).
var dim_fade_seconds: float:
	get:
		return float(_dim_fade_ms) / 1000.0
## Seconds of a map's absence caught up beat by beat (0: all of them).
var away_catch_up_limit_seconds: int:
	get:
		return _away_catch_up_limit_seconds
## The presentation's feel knobs (the record's `feel`; all 0 when left out).
var feel: FeelDefinition = FeelDefinition.new()


## When an NPC's call_out that answers the player comes: its ES2 time `es2_seconds`, or
## the reaction beat when that is sooner.
func reaction_seconds(es2_seconds: float) -> float:
	if _reaction_beat_ms <= 0:
		return es2_seconds
	return minf(es2_seconds, float(_reaction_beat_ms) / 1000.0)


## This record with the away catch-up limit set (seconds; tests, and from_record()).
func with_away_catch_up_limit(seconds: int) -> PacingDefinition:
	_away_catch_up_limit_seconds = seconds
	return self


## This record with the responsiveness knobs set (milliseconds; tests, and from_record()).
func with_responsiveness(reaction_beat_ms: int, trial_blow_ms: int, heart_beat_ms: int = ES2_HEART_BEAT_MS, dim_fade_ms: int = 0) -> PacingDefinition:
	_reaction_beat_ms = reaction_beat_ms
	_trial_blow_ms = trial_blow_ms
	_heart_beat_ms = heart_beat_ms
	_dim_fade_ms = dim_fade_ms
	return self


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
	).with_responsiveness(
		reader.integer("reaction_beat_ms", 0),
		reader.integer("trial_blow_ms", 0),
		reader.integer("heart_beat_ms", ES2_HEART_BEAT_MS),
		reader.integer("dim_fade_ms", 0),
	).with_away_catch_up_limit(reader.integer("away_catch_up_limit_seconds", 0))
	var feel: ContentRecordReader = reader.child("feel")
	if feel != null:
		definition.feel = FeelDefinition.from_record(feel)
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
	if definition._reaction_beat_ms < 0:
		reader.fail("reaction_beat_ms", "must not be negative")
	if definition._trial_blow_ms < 0:
		reader.fail("trial_blow_ms", "must not be negative")
	if definition._dim_fade_ms < 0:
		reader.fail("dim_fade_ms", "must not be negative")
	if definition._away_catch_up_limit_seconds < 0:
		reader.fail("away_catch_up_limit_seconds", "must not be negative")
	if definition._heart_beat_ms <= 0:
		reader.fail("heart_beat_ms", "must be positive")
	return definition
