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
## - hostile_alert_ms: the beat between a gang noticing the player and falling on them (its
##   first to notice shouts, a red ！ over its head, the rest turn; DECISIONS「进门一起上」).
##   The player who leaves the place within it escapes. 0 (ES2's call_out(0)): at once.
## - heart_beat_ms: the driver heart_beat outside a fight (ES2: "usually 2 seconds",
##   DECISIONS S5B B): NPC chat, busy wearing off, heal_up's tick count.
## - dim_fade_ms: how long the screen takes to go dark when the player falls unconscious.
##   0 (ES2 has no screen): at once.
## - away_catch_up_limit_seconds (DECISIONS「别的地图时间补算」): a map the player was away
##   from longer catches up this much of its NPCs' heart beat, and the rest comes to what
##   it would given time enough (healed, awake, conditions over). 0 (ES2): all of it.
## - away_wander_moves: how many random_move()s and patrol()s a map's wanderers and
##   constables make at most while the player is away, where they end up when the player
##   comes back. 0 (ES2: a healed NPC's heart beat stops where no player is): none.
## - corpse_rot_seconds, corpse_bones_seconds, corpse_scatter_seconds (obj/corpse.c decay(),
##   DECISIONS「尸体腐烂」): a corpse rots this long after it is made, dries to bones this long
##   after that, and scatters (what it held falls where it lay) this long after that; ES2's
##   120, 120 and 60. 0: it goes no further than the stage before (0 rot: corpses stay).
## - away_neighbour_pulse_seconds: how often the maps a door leads to from the player's are
##   caught up, so a wanderer may come in through the door (邻图来客). 0 (ES2): never.
##
## The progression knobs (owner, A2 经验节奏; DECISIONS「经验节奏」); left out, each is ES2's:
## - milestone_rewards: the one-time 历练 rewards (MilestoneRewards, common/progression.json).
##   false (ES2): none.
## - catch_up_max_percent: 落后补偿, the most a gain grows (percent) while the player's
##   combat_exp is below the region's recommended_exp (ProgressionGain). 0 (ES2): none.
## - staged_potential_cap: the player keeps up to the stage's potential_cap unspent
##   (progression.json) where combatd.c stops at 100. false (ES2): 100.
## - player_exercise_gain: what exercise.c's force_gain gives the player (打坐), times this;
##   a step that gains nothing stays nothing. 1 (ES2).
## - bounty_board: the 雪亭驿 board's bounties (BountyBoard, native/bounties.json). false (ES2):
##   no board.
## - bounty_refresh_seconds: play time a bounty's slot stays empty once it is done or given up.
## - training_dummies: the 武馆 教练场's 木人 stand (native/spawns.json `pacing`). false (ES2):
##   none.
##
## The day (DECISIONS「昼夜」):
## - day_length_minutes: real minutes one game day of natured.c's 1440 minutes takes, the
##   voxel view's light and the outdoor rooms' line going round with it. ES2: 24 (one game
##   minute a real second), also the default (owner Q3); 经典 is 24 too.
##
## The sky (DECISIONS「天气」):
## - sky_weather: the cloud turns through natured.c's five weather_msg lines (SkyState), the
##   outdoor room's text ending with the line and the voxel view greying by it. false (ES2:
##   the lines are declared and never shown; the sky is always clear); 经典 is false too.
##
## Death and autosave (现代基线 A; DECISIONS「减轻死亡」「自动存档」); left out, each is ES2's:
## - death_exp_percent: what killer_reward() takes of combat_exp, in percent. 10 (ES2).
## - death_keeps_potential: unspent potential stays. false (ES2): it halves toward learned_points.
## - death_keeps_skills: skill_death_penalty() does not run. false (ES2): every skill loses a
##   level or its learning progress, and all enables go.
## - player_corpse_stays: the player's own corpse does not decay while it holds anything. false
##   (ES2): it decays as any other.
## - autosave_min_seconds: real seconds at least between two autosaves. 0 (ES2 has none): none.
##
## - stats_appear_when_used (现代基线 C; DECISIONS「数值用到才出现」): a number with a `when_*` in
##   stats_display.json shows only then. false (ES2, score.c lists all): every number shows.
## - map_page (现代基线 B; DECISIONS「总图」): the menu has its 地图 page, and 指路 with it. false
##   (ES2 has no map): no such page.
const ES2_ROOM_RESET_SECONDS: int = 1800
const ES2_GAIN: int = 1
const ES2_QUEST_TIME_PERCENT: int = 100
const ES2_WAKE_SECONDS: int = 0
const ES2_HEART_BEAT_MS: int = 2000
## natured.c: TIME_TICK is time()*60, one game minute a real second: 24 real minutes a day.
const ES2_DAY_LENGTH_MINUTES: int = 24
## obj/corpse.c: call_out("decay", 120, 1), then 120, then 60.
const ES2_CORPSE_DECAY_SECONDS: Array[int] = [120, 120, 60]
## combatd.c killer_reward(): -(combat_exp / 10).
const ES2_DEATH_EXP_PERCENT: int = 10

var _combat_round_ms: int
var _room_reset_seconds: int
var _player_exp_gain: int
var _player_recovery_gain: int
var _quest_time_percent: int
var _npc_thirst: int
var _player_wake_seconds: int
var _reaction_beat_ms: int = 0
var _trial_blow_ms: int = 0
var _hostile_alert_ms: int = 0
var _heart_beat_ms: int = ES2_HEART_BEAT_MS
var _dim_fade_ms: int = 0
var _away_catch_up_limit_seconds: int = 0
var _away_wander_moves: int = 0
var _away_neighbour_pulse_seconds: int = 0
var _corpse_decay_seconds: Array[int] = ES2_CORPSE_DECAY_SECONDS.duplicate()
var _milestone_rewards: bool = false
var _catch_up_max_percent: int = 0
var _staged_potential_cap: bool = false
var _player_exercise_gain: int = ES2_GAIN
var _bounty_board: bool = false
var _bounty_refresh_seconds: int = 600
var _training_dummies: bool = false
var _day_length_minutes: int = ES2_DAY_LENGTH_MINUTES
var _sky_weather: bool = false
## 主线 A (DECISIONS「老松寨的三条路」,「安葬必得书」): the story's parley with a toll-taker
## marked `parley` (NpcDealings) and a trap's `unless_mark` hold; false (ES2): they are
## plain aggressive and the trap always falls. And a burial always rewards (BuryRoll's BOOK);
## false (ES2): random(kar + 10) decides.
var _story_parley: bool = false
var _bury_always_rewards: bool = false
## 战斗决策层 1A (DECISIONS「战斗数值」): the combat power knobs (CombatPowerRules, ES2's when
## left out), the fight forecast shown before one (combat_forecast; false: RelativeStrength's
## line by combat_exp) and whether NPCs carry their ES2 numbers (es2_npc_values: the record's
## `classic` block; true left out, so a record without the knobs is ES2 throughout).
var _combat_rules: CombatPowerRules = CombatPowerRules.classic()
## 战斗决策层 1B (DECISIONS「战斗决策」): the decision layer's knobs (CombatDecisionRules), ES2's
## auto-fight when left out.
var _decision_rules: CombatDecisionRules = CombatDecisionRules.classic()
var _combat_forecast: bool = false
var _es2_npc_values: bool = true
var _death_exp_percent: int = ES2_DEATH_EXP_PERCENT
var _death_keeps_potential: bool = false
var _death_keeps_skills: bool = false
var _player_corpse_stays: bool = false
var _autosave_min_seconds: int = 0
var _stats_appear_when_used: bool = false
var _map_page: bool = false

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
## Seconds between a gang noticing the player and falling on them (0: at once).
var hostile_alert_seconds: float:
	get:
		return float(_hostile_alert_ms) / 1000.0
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
## Moves a wanderer or constable makes at most while the player is away (0: none).
var away_wander_moves: int:
	get:
		return _away_wander_moves
## Seconds between neighbour pulses (0: none).
var away_neighbour_pulse_seconds: int:
	get:
		return _away_neighbour_pulse_seconds
## Seconds from a corpse's making to its rotting, then to its bones, then to its scattering.
var corpse_rot_seconds: int:
	get:
		return _corpse_decay_seconds[0]
var corpse_bones_seconds: int:
	get:
		return _corpse_decay_seconds[1]
var corpse_scatter_seconds: int:
	get:
		return _corpse_decay_seconds[2]
## Whether the one-time 历练 rewards are given (false: ES2).
var milestone_rewards: bool:
	get:
		return _milestone_rewards
## The most 落后补偿 adds to a gain, in percent (0: ES2).
var catch_up_max_percent: int:
	get:
		return _catch_up_max_percent
## Whether the player's unspent potential stops at the stage's cap (false: combatd.c's 100).
var staged_potential_cap: bool:
	get:
		return _staged_potential_cap
## Times exercise.c's force_gain for the player (1: ES2).
var player_exercise_gain: int:
	get:
		return _player_exercise_gain
## Whether the 雪亭驿 board posts bounties (false: ES2).
var bounty_board: bool:
	get:
		return _bounty_board
## Seconds of play a bounty's slot stays empty once done or given up.
var bounty_refresh_seconds: int:
	get:
		return _bounty_refresh_seconds
## Whether the 武馆's 木人 stand (false: ES2).
var training_dummies: bool:
	get:
		return _training_dummies
## Real minutes a game day takes (24: ES2).
var day_length_minutes: int:
	get:
		return _day_length_minutes
## Whether the cloud turns and shows (false: ES2).
var sky_weather: bool:
	get:
		return _sky_weather
## Whether the story's parley holds (false: ES2).
var story_parley: bool:
	get:
		return _story_parley
## Whether a burial always rewards (false: ES2).
var bury_always_rewards: bool:
	get:
		return _bury_always_rewards
var combat_forecast: bool:
	get:
		return _combat_forecast
var es2_npc_values: bool:
	get:
		return _es2_npc_values
## What killer_reward() takes of combat_exp, in percent (10: ES2).
var death_exp_percent: int:
	get:
		return _death_exp_percent
## Whether death leaves unspent potential alone (false: ES2).
var death_keeps_potential: bool:
	get:
		return _death_keeps_potential
## Whether death leaves skills and enables alone (false: ES2).
var death_keeps_skills: bool:
	get:
		return _death_keeps_skills
## Whether the player's own corpse waits for them while it holds anything (false: ES2).
var player_corpse_stays: bool:
	get:
		return _player_corpse_stays
## Real seconds at least between two autosaves (0: no autosave).
var autosave_min_seconds: int:
	get:
		return _autosave_min_seconds
## Whether a number appears only once it is used (false: ES2, all of them, always).
var stats_appear_when_used: bool:
	get:
		return _stats_appear_when_used
var map_page: bool:
	get:
		return _map_page
## The presentation's feel knobs (the record's `feel`; all 0 when left out).
var feel: FeelDefinition = FeelDefinition.new()


## When an NPC's call_out that answers the player comes: its ES2 time `es2_seconds`, or
## the reaction beat when that is sooner.
func reaction_seconds(es2_seconds: float) -> float:
	if _reaction_beat_ms <= 0:
		return es2_seconds
	return minf(es2_seconds, float(_reaction_beat_ms) / 1000.0)


## This record with the corpse decay knobs set (seconds; tests, and from_record()).
func with_corpse_decay(rot: int, bones: int, scatter: int) -> PacingDefinition:
	_corpse_decay_seconds = [rot, bones, scatter]
	return self


## A copy of this record (a suite changes a knob on it, never on the game's).
func copy() -> PacingDefinition:
	var record: PacingDefinition = PacingDefinition.new(
		_combat_round_ms, _room_reset_seconds, _player_exp_gain, _player_recovery_gain,
		_quest_time_percent, _npc_thirst, _player_wake_seconds,
	).with_responsiveness(_reaction_beat_ms, _trial_blow_ms, _heart_beat_ms, _dim_fade_ms).with_away_catch_up_limit(
		_away_catch_up_limit_seconds, _away_wander_moves, _away_neighbour_pulse_seconds,
	)
	record.with_corpse_decay(corpse_rot_seconds, corpse_bones_seconds, corpse_scatter_seconds)
	record.with_progression(_milestone_rewards, _catch_up_max_percent, _staged_potential_cap, _player_exercise_gain)
	record.with_training(_bounty_board, _bounty_refresh_seconds, _training_dummies)
	record.with_hostile_alert(_hostile_alert_ms)
	record.with_day_length(_day_length_minutes)
	record.with_sky_weather(_sky_weather)
	record.with_story(_story_parley, _bury_always_rewards)
	record.with_combat(_combat_rules, _combat_forecast, _es2_npc_values)
	record.with_decisions(_decision_rules)
	record.with_death(_death_exp_percent, _death_keeps_potential, _death_keeps_skills, _player_corpse_stays)
	record.with_autosave(_autosave_min_seconds)
	record.with_stats_display(_stats_appear_when_used)
	record.with_map_page(_map_page)
	record.feel = feel
	return record


## This record with the death knobs set (tests, PacePresets, and from_record()).
func with_death(exp_percent: int, keeps_potential: bool, keeps_skills: bool, corpse_stays: bool) -> PacingDefinition:
	_death_exp_percent = exp_percent
	_death_keeps_potential = keeps_potential
	_death_keeps_skills = keeps_skills
	_player_corpse_stays = corpse_stays
	return self


## This record with the autosave's least interval set (seconds; tests, PacePresets, and from_record()).
func with_autosave(min_seconds: int) -> PacingDefinition:
	_autosave_min_seconds = min_seconds
	return self


## This record with the numbers appearing when used, or all shown (tests, PacePresets, and from_record()).
func with_stats_display(appear_when_used: bool) -> PacingDefinition:
	_stats_appear_when_used = appear_when_used
	return self


## This record with the 地图 page on or off (tests, PacePresets, and from_record()).
func with_map_page(on: bool) -> PacingDefinition:
	_map_page = on
	return self


## The decision layer's knobs (a snapshot; ES2's auto-fight when none were set).
func decision_rules() -> CombatDecisionRules:
	return _decision_rules.duplicate_snapshot()


## This record with the decision knobs set (tests, PacePresets, and from_record()).
func with_decisions(rules: CombatDecisionRules) -> PacingDefinition:
	_decision_rules = rules.duplicate_snapshot() if rules != null else CombatDecisionRules.classic()
	return self


## The combat power knobs this world fights under (a snapshot; ES2's when none were set).
func combat_rules() -> CombatPowerRules:
	return _combat_rules.duplicate_snapshot()


## This record with the combat knobs set (tests, PacePresets, and from_record()).
func with_combat(rules: CombatPowerRules, forecast: bool, es2_npc_values: bool) -> PacingDefinition:
	_combat_rules = rules.duplicate_snapshot() if rules != null else CombatPowerRules.classic()
	_combat_forecast = forecast
	_es2_npc_values = es2_npc_values
	return self


## This record with the story's knobs set (tests, and from_record()).
func with_story(parley: bool, bury_rewards: bool) -> PacingDefinition:
	_story_parley = parley
	_bury_always_rewards = bury_rewards
	return self


## This record with the day's length set (real minutes; tests, and from_record()).
func with_day_length(minutes: int) -> PacingDefinition:
	_day_length_minutes = minutes
	return self


## This record with the sky's weather on or off (tests, and from_record()).
func with_sky_weather(enabled: bool) -> PacingDefinition:
	_sky_weather = enabled
	return self


## This record with the gang's alert beat set (milliseconds; tests, and from_record()).
func with_hostile_alert(milliseconds: int) -> PacingDefinition:
	_hostile_alert_ms = milliseconds
	return self


## This record with the bounty board and 木人 knobs set (tests, and from_record()).
func with_training(board: bool, refresh_seconds: int, dummies: bool) -> PacingDefinition:
	_bounty_board = board
	_bounty_refresh_seconds = refresh_seconds
	_training_dummies = dummies
	return self


## This record with the progression knobs set (tests, and from_record()).
func with_progression(milestones: bool, catch_up_max_percent: int, staged_potential_cap: bool, exercise_gain: int = ES2_GAIN) -> PacingDefinition:
	_milestone_rewards = milestones
	_catch_up_max_percent = catch_up_max_percent
	_staged_potential_cap = staged_potential_cap
	_player_exercise_gain = exercise_gain
	return self


## This record with the away catch-up limit set (seconds; tests, and from_record()).
func with_away_catch_up_limit(seconds: int, wander_moves: int = 0, neighbour_pulse_seconds: int = 0) -> PacingDefinition:
	_away_catch_up_limit_seconds = seconds
	_away_wander_moves = wander_moves
	_away_neighbour_pulse_seconds = neighbour_pulse_seconds
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
	).with_away_catch_up_limit(
		reader.integer("away_catch_up_limit_seconds", 0),
		reader.integer("away_wander_moves", 0),
		reader.integer("away_neighbour_pulse_seconds", 0),
	).with_corpse_decay(
		reader.integer("corpse_rot_seconds", ES2_CORPSE_DECAY_SECONDS[0]),
		reader.integer("corpse_bones_seconds", ES2_CORPSE_DECAY_SECONDS[1]),
		reader.integer("corpse_scatter_seconds", ES2_CORPSE_DECAY_SECONDS[2]),
	).with_progression(
		reader.boolean("milestone_rewards", false),
		reader.integer("catch_up_max_percent", 0),
		reader.boolean("staged_potential_cap", false),
		reader.integer("player_exercise_gain", ES2_GAIN),
	).with_training(
		reader.boolean("bounty_board", false),
		reader.integer("bounty_refresh_seconds", 600),
		reader.boolean("training_dummies", false),
	).with_hostile_alert(reader.integer("hostile_alert_ms", 0)).with_day_length(reader.integer("day_length_minutes", ES2_DAY_LENGTH_MINUTES)).with_sky_weather(reader.boolean("sky_weather", false)).with_story(reader.boolean("story_parley", false), reader.boolean("bury_always_rewards", false))
	definition.with_combat(CombatPowerRules.from_record(reader), reader.boolean("combat_forecast", false), reader.boolean("es2_npc_values", true))
	definition.with_decisions(CombatDecisionRules.from_record(reader))
	definition.with_death(reader.integer("death_exp_percent", ES2_DEATH_EXP_PERCENT), reader.boolean("death_keeps_potential", false), reader.boolean("death_keeps_skills", false), reader.boolean("player_corpse_stays", false))
	definition.with_autosave(reader.integer("autosave_min_seconds", 0))
	definition.with_stats_display(reader.boolean("stats_appear_when_used", false))
	definition.with_map_page(reader.boolean("map_page", false))
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
	if definition._hostile_alert_ms < 0:
		reader.fail("hostile_alert_ms", "must not be negative")
	if definition._dim_fade_ms < 0:
		reader.fail("dim_fade_ms", "must not be negative")
	if definition._away_catch_up_limit_seconds < 0:
		reader.fail("away_catch_up_limit_seconds", "must not be negative")
	for index: int in 3:
		if definition._corpse_decay_seconds[index] < 0:
			reader.fail(["corpse_rot_seconds", "corpse_bones_seconds", "corpse_scatter_seconds"][index], "must not be negative")
	if definition._away_wander_moves < 0:
		reader.fail("away_wander_moves", "must not be negative")
	if definition._away_neighbour_pulse_seconds < 0:
		reader.fail("away_neighbour_pulse_seconds", "must not be negative")
	if definition._heart_beat_ms <= 0:
		reader.fail("heart_beat_ms", "must be positive")
	if definition._catch_up_max_percent < 0:
		reader.fail("catch_up_max_percent", "must not be negative")
	if definition._player_exercise_gain < 1:
		reader.fail("player_exercise_gain", "must be at least 1")
	if definition._bounty_refresh_seconds < 0:
		reader.fail("bounty_refresh_seconds", "must not be negative")
	if definition._day_length_minutes <= 0:
		reader.fail("day_length_minutes", "must be positive")
	if definition._death_exp_percent < 0 or definition._death_exp_percent > 100:
		reader.fail("death_exp_percent", "must be 0 to 100")
	if definition._autosave_min_seconds < 0:
		reader.fail("autosave_min_seconds", "must not be negative")
	return definition
