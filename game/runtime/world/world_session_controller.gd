class_name WorldSessionController
extends WorldResidentMapCoordinator

const PLAYER_ID: StringName = &"oldpine.player"
## Retained internal Old Pine/CXR regression bootstrap, not public New Game
## or an LPC formula. SOURCE_ENTRY and RESTORE never enter this initializer.
const NEW_GAME_COMBAT_EXPERIENCE: int = 600
## The player object's own reset() (obj/user.c), scheduled as a room's.
const PLAYER_RESET: String = "obj/user"
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)
const SessionItemIdScopeFactoryType := preload(
	"res://core/persistence/session_item_id_scope_factory.gd"
)

enum BootstrapMode {
	NEW_GAME,
	RESTORE,
	SOURCE_ENTRY,
}

@export var deterministic_npc_seed: bool = false
@export var npc_seed: int = 7_021
@export var deterministic_combat_seed: bool = false
@export var combat_seed: int = 5_232
@export var deterministic_world_interaction_seed: bool = false
@export var world_interaction_seed: int = 93_232

## Test runs only (tests/run_suite.gd): every map scene read stays loaded, so a suite's
## next world does not parse the scene files again. The game reads them per session;
## exported scenes are binary and quick to load, and keeping them would cost memory.
static var keep_map_scenes: bool = false
static var _kept_map_scenes: Dictionary[String, PackedScene] = {}

var _inventory: InventoryState
var _stacks: CombinedStackCollection
var _foods: FoodCollection = FoodCollection.new()
var _liquids: LiquidCollection = LiquidCollection.new()
var _item_index: WorldItemInstanceIndex
var _npc_random: NpcInitializationRandomSource
var _combat_random: CombatRandomSource
var _world_interaction_random: WorldInteractionRandomSource
var _item_instance_scope: StringName = &""
var _item_id_allocator: SessionItemIdAllocator
var _combat_encounter_coordinator: CombatEncounterCoordinator
var _bootstrap_mode: int = BootstrapMode.NEW_GAME
var _world_content_revision: WorldContentRevision.Value = WorldContentRevision.Value.LEGACY_OLDPINE_V1
var _restore_preparation: OldPineWorldRestorePreparation
var _restore_failure_outcome: int = OldPineWorldRestoreResult.Outcome.SUCCESS
var _restore_candidate_staged: bool = false
## The process frame that activated a restored save (-1: none): the engine's own _process of
## that frame is not world time. One-shot: the first _process call after activation decides.
var _activation_frame: int = -1
var _session_swap_suspended: bool = false
var _session_swap_reparenting: bool = false
var _source_name: String = ""
var _source_gender: StringName = &""
## The pace of this world (CharacterState.pace; PacePresets): the catalog's pacing is set
## for it before the world is built and put back when the session goes.
var _source_pace: StringName = CharacterState.PACE_MODERN
var _pacing_before: PacingDefinition
var _recovery_random: RecoveryCadenceRandomSource
var _player_recovery_cadence: PlayerRecoveryCadence
var _player_timed_remainder_ms: float = 0.0
var _quest_remainder_ms: float = 0.0
## Real time since the 任务 page's entries were last looked for (JOURNAL_INTERVAL).
var _journal_elapsed: float = 0.0
## Transient NPC streams (not in Save): heal ticks and revive delays.
var _npc_recovery_random: RecoveryCadenceRandomSource
var _npc_revive_random: CombatRandomSource
var _npc_ambience_random: WorldInteractionRandomSource
var _life_flow: PlayerLifeFlow = PlayerLifeFlow.new()
var _last_revival_handoff: OldPineMapHandoffResult
var _last_temple_handoff: OldPineMapHandoffResult
## A gargoyle's or the little shop's reincarnate() (ScriptedAct reincarnate): the player goes
## to the Snow temple once the world lets it (after the acting map's beat).
var _reincarnation_due: bool = false
## logind.c: a ghost Continued anywhere but 阴间 is taken to DEATH_ROOM once the world lets it.
var _realm_return_due: bool = false
## Whether the maps' ghosts were last drawn as seen (CharacterState.sees_ghosts()).
var _ghost_sight_shown: bool = false
## How many times the player came back to life (the screen tells it once each).
var _reincarnations: int = 0
## The room a spell took the player to was seen a frame ago: the move may be made now.
var _departure_due: bool = false
var _hidden_passages: WorldHiddenPassages
var _room_states: WorldRoomStates = WorldRoomStates.new()
var _room_traps: WorldRoomTraps
var _room_hazards: WorldRoomHazards
var _room_resets: WorldRoomResets
## obj/user.c reset() of the player object, on a schedule of its own (WorldRoomResets).
var _player_resets: WorldRoomResets
var _maps_by_room: Dictionary[String, Array] = {}
## The world clock and each map's time without the player (DECISIONS「别的地图时间补算」).
var _away: WorldAwayTimes = WorldAwayTimes.new()
## The time of day (DECISIONS「昼夜」), going on with the world clock; saved as day_seconds.
var _day: DayClock = DayClock.new()
## The cloud (DECISIONS「天气」), going on with the world clock when the pacing's sky_weather
## is on; saved as sky_level and sky_minutes_left. Its draws come from a stream of its own
## (the world-interaction seed's), not saved: a Continue draws the next change afresh.
var _sky: SkyState = SkyState.new()
var _sky_random: WorldInteractionRandomSource
## A phase of the day began (DayClock.advance()): the outdoor player hears natured.c's line.
signal day_phase_began(phase: DayPhaseDefinition)
## The player's corpses that scattered (obj/corpse.c decay(3)): what they held lies where they
## lay. Not saved (the death card that reads it cannot be saved on).
var _scattered_corpses: Dictionary[StringName, bool] = {}
## A catch-up's own revive draws (one falling while the player was away), while it runs.
var _catch_up_revive_random: CombatRandomSource
## The neighbour the pulse looks at next (_door_neighbours() order), and world seconds to its
## next look (one a heart beat). Not saved.
var _neighbour_pulse_index: int = 0
var _neighbour_pulse_wait: float = 0.0
## The maps a door leads to from each map (_door_neighbours()), by map ID.
var _neighbours_by_map: Dictionary[StringName, Array] = {}
## The maps the player was on, the latest first: the first `voxel_worlds_kept` keep their
## built voxel world, an older one's is freed (WorldVoxelView.release_world()). Presentation
## only, not saved: a freed map's world is built again when the player comes back.
var _recent_maps: Array[StringName] = []


func _ready() -> void:
	# Physics interpolation (DECISIONS「手感」) is for the player's walk and its camera only
	# (WorldCharacterBody2D.bind_player()); everything else is drawn where it is.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_day = DayClock.new(GameContent.catalog().day_phases())
	if initialize_session():
		shared_ui().configure(player_runtime())
		shared_ui().initialize_supplies()
	# On once the maps are made (_instantiate_map()).
	get_tree().physics_interpolation = true


func shared_ui() -> SharedGameplayUI:
	return get_node("SharedGameplayUI") as SharedGameplayUI


func liquid_interaction_available() -> bool:
	if not application_gameplay_allows_encounter_advance() or not can_process() or _restore_candidate_staged or _session_swap_reparenting or _transitioning:
		return false
	var map: WorldResidentMapController = active_map()
	return _world_content_revision == WorldContentRevision.CURRENT_PUBLIC and world_simulation_gate().is_open() and map != null and map.is_map_initialized() and map.runtime_player_body() != null and map.runtime_player_body().player_controlled and _player.exists_in_world and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE


## A water service (resource/water) of the active map is within reach.
func fill_water_available() -> bool:
	var map: WorldMapController = active_map() as WorldMapController
	return liquid_interaction_available() and map != null and map.water_available()


func food_collection() -> FoodCollection:
	return _foods


func liquid_collection() -> LiquidCollection:
	return _liquids


func _process(delta: float) -> void:
	# The engine's _process of the frame that activated a restored save is not world time: its
	# delta is the loading frame's, and the player has not seen the world yet (DECISIONS「别的
	# 地图时间补算」: the save's away_ms, day and recovery come back exactly; under load that
	# delta reached them). A call stepped by hand in that frame (the suites' _process(1.0))
	# carries its own delta and runs.
	if _activation_frame >= 0:
		var engine_call: bool = Engine.get_process_frames() == _activation_frame and is_equal_approx(delta, get_process_delta_time())
		_activation_frame = -1
		if engine_call:
			return
	if presentation_frozen():
		_sync_ghost_sight()
		advance_journal(delta)
		return
	if world_time_held():
		_process_held(delta)
		return
	# Inspect before combat advances: a combat-ending frame is not world time.
	var world_delta: float = _world_delta(delta)
	advance_player_recovery(delta)
	advance_player_timed_applies(world_delta)
	# A fight's own clock (BattlePace, owner B Q2): its rounds cost the task their
	# combat_round_ms whatever the 战斗速度.
	var fighting: bool = _combat_encounter_coordinator != null and _combat_encounter_coordinator.has_active_encounter()
	# 战斗决策层 1B: while the fight's clock waits for the player's order, nothing on it moves.
	var fight_delta: float = 0.0 if fighting and _combat_encounter_coordinator.waiting_for_player() else BattlePace.fight_seconds(delta)
	advance_quest_time(fight_delta if fighting else world_delta)
	advance_bounty_time(fight_delta if fighting else world_delta)
	advance_npc_heartbeat(world_delta)
	advance_hidden_passages(world_delta)
	advance_room_hazards(world_delta)
	advance_room_resets(world_delta)
	if _initialized and _combat_encounter_coordinator != null:
		_combat_encounter_coordinator.advance_scheduler(fight_delta)
		advance_departure()
	# One lying unconscious while the fight goes on wakes on its clock (BattlePace).
	_advance_life_flow(fight_delta if fighting else world_delta)
	_advance_reincarnation()
	_sync_ghost_sight()
	advance_journal(delta)


## The menu is open (owner, 2026-10-15, DECISIONS「菜单窗口」): world time stands still —
## no heart beats, call_outs, recovery, conditions, timed applies, task time, hazards or
## resets. The player's own busy still wears down: in ES2 a busy character's heart beat
## goes to continue_action() alone, so those beats run (two 运功 in a row work). A fight
## an action starts runs (the menu closes for it).
func _process_held(delta: float) -> void:
	if _player != null and _player.busy.is_busy():
		advance_player_recovery(delta, true)
	if _initialized and _combat_encounter_coordinator != null:
		_combat_encounter_coordinator.advance_scheduler(0.0 if _combat_encounter_coordinator.waiting_for_player() else BattlePace.fight_seconds(delta))
		advance_departure()
	_advance_reincarnation()
	_sync_ghost_sight()
	advance_journal(delta)


## Stops world time for `owner` until release_world_time() (the menu window). Not saved.
func hold_world_time(owner: StringName) -> void:
	_world_time_holds[owner] = true


func release_world_time(owner: StringName) -> void:
	_world_time_holds.erase(owner)


## While the view fades out and in around a map change (DECISIONS「手感」) world time
## stands still and the player does not walk: the fade takes nobody's time.
const VIEW_TIME_HOLD: StringName = &"map_transition"
var _presentation_holds: Dictionary[StringName, bool] = {}


func _fade_out_seconds(door: bool) -> float:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	return feel.door_fade_out_seconds if door else feel.map_fade_out_seconds


func _fade_in_seconds(door: bool) -> float:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	return feel.door_fade_in_seconds if door else feel.map_fade_in_seconds


func _hold_view(on: bool) -> void:
	hold_presentation(VIEW_TIME_HOLD, on)


## The battle panel is on the screen (a fight, or the last lines of one).
func battle_panel_shown() -> bool:
	var panel: CanvasItem = get_node_or_null("BattlePresentationLayer/BattleSurface") as CanvasItem
	return panel != null and panel.visible


func presentation_held(owner: StringName) -> bool:
	return _presentation_holds.has(owner)


## A presentation beat holds (hold_presentation()) and no fight runs: nothing at all
## advances — not the player's busy, not a lying player's revive, whatever their state
## (unlike the menu's hold, world_time_held()). It takes nobody's time.
func presentation_frozen() -> bool:
	return not _presentation_holds.is_empty() and (_combat_encounter_coordinator == null or not _combat_encounter_coordinator.has_active_encounter())


## A presentation beat that takes nobody's time (the view's fade, a fight's last lines on
## the battle panel: DECISIONS「手感」): world time stands still and the player does not
## walk while any `owner` holds it.
func hold_presentation(owner: StringName, on: bool) -> void:
	if on:
		hold_world_time(owner)
		_presentation_holds[owner] = true
	else:
		release_world_time(owner)
		_presentation_holds.erase(owner)
	_sync_walk_pause()


## Native (主线 A; DECISIONS「剧情演出」): a scene holds the player (WorldMapNpcLife): they
## stand and watch, the HUD takes E as 继续 and nothing in reach is offered; world time
## runs on (the scene's lines come on it). Not saved: a scene begins anew as they come in.
var _scene_held: bool = false


func hold_scene(on: bool) -> void:
	_scene_held = on
	_sync_walk_pause()


func scene_held() -> bool:
	return _scene_held


func _sync_walk_pause() -> void:
	var map: WorldMapController = active_map() as WorldMapController
	if map != null and map.player_body != null:
		map.player_body.walk_paused = not _presentation_holds.is_empty() or _scene_held


## Only while the player can act: one who falls, dies or is drawn into a fight under the
## menu lives world time at once (the HUD closes the menu on its next frame).
func world_time_held() -> bool:
	return (
		not _world_time_holds.is_empty() and _player != null
		and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and (_combat_encounter_coordinator == null or not _combat_encounter_coordinator.has_active_encounter())
	)


## World time this frame. Deviation (owner, modern fixes II, A9): while the player lies
## unconscious with a quick wake and no fight runs, the world (NPC heart beats and their
## waking, room resets, call_outs, 朱鸿雪's task time) lives damage.c's whole revive delay
## in pacing.json's player_wake_seconds; never past the moment the player comes to.
func _world_delta(delta: float) -> float:
	var scale: float = _life_flow.world_time_scale()
	if scale <= 1.0 or not is_finite(delta) or delta <= 0.0:
		return delta
	if _combat_encounter_coordinator != null and _combat_encounter_coordinator.has_active_encounter():
		return delta
	return minf(delta * scale, maxf(_life_flow.revive_remaining_seconds, delta))


## One transient authority across every resident. Injection is pre-initialization only.
func configure_recovery_random_source(value: RecoveryCadenceRandomSource) -> bool:
	if value == null or _player_recovery_cadence != null or _initialized:
		return false
	_recovery_random = value
	return true


func player_recovery_cadence() -> PlayerRecoveryCadence:
	return _player_recovery_cadence


func _initialize_player_recovery() -> bool:
	if _world_content_revision != WorldContentRevision.CURRENT_PUBLIC:
		return true
	if _player_recovery_cadence == null:
		if _recovery_random == null:
			_recovery_random = GodotRecoveryCadenceRandomSource.new()
		var pacing: PacingDefinition = GameContent.catalog().pacing()
		_player_recovery_cadence = PlayerRecoveryCadence.new(_recovery_random, true, null, pacing.player_recovery_gain, 1, pacing.heart_beat_seconds)
	return _player_recovery_cadence.is_valid()


## The player's heart beat outside a fight (S5B; conditions update on its tick since
## Old Pine remainder B). Busy is NOT a time gate.
func player_recovery_time_allowed() -> bool:
	if (
		_world_content_revision != WorldContentRevision.CURRENT_PUBLIC
		or not application_gameplay_allows_encounter_advance()
		or not can_process() or _restore_candidate_staged
		or _session_swap_reparenting or _transitioning
		or _player_recovery_cadence == null or _player == null
		or not _player.exists_in_world
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
	):
		return false
	# Separate documented omissions, not a claim gate.is_open alone means eligibility.
	if _combat_encounter_coordinator.has_active_encounter() or _player.relationship.is_fighting():
		return false
	if not _world_simulation_gate.is_open():
		return false
	if _last_map_handoff != null and not _last_map_handoff.succeeded():
		if _last_map_handoff.location_committed or (_last_map_handoff.source_detached and not _last_map_handoff.source_restored):
			return false
	var map: WorldResidentMapController = active_map()
	var location: WorldLocationState = _player.world_location()
	return (
		map != null and map.is_inside_tree() and map.can_process()
		and map.get_parent() == active_map_slot and active_map_child_count() == 1
		and location != null and location.map_id == _active_map_id
		and map.runtime_player_body() != null and map.runtime_player_body().is_inside_tree()
	)


## Test injection before initialization; production draws from fresh generators.
func configure_npc_random_sources(recovery: RecoveryCadenceRandomSource, revive: CombatRandomSource) -> bool:
	if recovery == null or revive == null or _initialized:
		return false
	_npc_recovery_random = recovery
	_npc_revive_random = revive
	return true


func npc_recovery_random_source() -> RecoveryCadenceRandomSource:
	if _npc_recovery_random == null:
		_npc_recovery_random = GodotRecoveryCadenceRandomSource.new()
	return _npc_recovery_random


func npc_revive_random_source() -> CombatRandomSource:
	if _catch_up_revive_random != null:
		return _catch_up_revive_random
	if _npc_revive_random == null:
		_npc_revive_random = GodotCombatRandomSource.new()
	return _npc_revive_random


## Transient (not in Save): chat beats, random_move exits and where a walk ends, and
## room reset times. Seeded with the world-interaction seed when that one is.
func npc_ambience_random_source() -> WorldInteractionRandomSource:
	if _npc_ambience_random == null:
		_npc_ambience_random = GodotWorldInteractionRandomSource.new(world_interaction_seed + 1, deterministic_world_interaction_seed)
	return _npc_ambience_random


## Test injection; the maps draw from it from their next NPC beat on.
func configure_npc_ambience_random_source(value: WorldInteractionRandomSource) -> bool:
	if value == null:
		return false
	_npc_ambience_random = value
	return true


## NPC heart_beat time flows when the world does and no fight runs; the player's
## own life state does not matter (NPCs heal while the player lies unconscious).
func npc_world_time_allowed() -> bool:
	return (
		_initialized and _world_content_revision == WorldContentRevision.CURRENT_PUBLIC
		and application_gameplay_allows_encounter_advance()
		and can_process() and not _restore_candidate_staged
		and not _session_swap_reparenting and not _transitioning
		and _world_simulation_gate != null and _world_simulation_gate.is_open()
		and _combat_encounter_coordinator != null and not _combat_encounter_coordinator.has_active_encounter()
	)


## The world clock runs with it (DECISIONS「别的地图时间补算」): the time the other maps owe.
func advance_npc_heartbeat(delta: float) -> void:
	if not npc_world_time_allowed():
		return
	_away.advance(delta)
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var began: DayPhaseDefinition = _day.advance(delta, pacing.day_length_minutes)
	if began != null:
		day_phase_began.emit(began)
	if pacing.sky_weather:
		_sky.advance(delta, pacing.day_length_minutes, sky_random_source())
	var map: WorldMapController = active_map() as WorldMapController
	if map != null and map.is_inside_tree() and map.can_process():
		map.advance_npc_heartbeat(delta)
		# The map's beat may have begun a fight or taken the player elsewhere.
		if npc_world_time_allowed() and active_map() == map and map.gameplay_open():
			_advance_neighbour_pulse(delta, map)


## 邻图来客 (owner Q1, DECISIONS「别的地图时间补算」): each map within two doors of the
## player's is caught up once it owes pacing.json away_neighbour_pulse_seconds of world time,
## and one of its wanderers whose move leads in comes in through the door, as it would to a
## player standing in the shop while the street goes on. One map a heart beat, in turn, so the
## work is spread. 0 (ES2): never.
func _advance_neighbour_pulse(delta: float, map: WorldMapController) -> void:
	var pulse: int = GameContent.catalog().pacing().away_neighbour_pulse_seconds
	var neighbours: Array = _door_neighbours(map.map_id())
	if pulse <= 0 or neighbours.is_empty():
		return
	_neighbour_pulse_wait -= delta
	if _neighbour_pulse_wait > 0.0:
		return
	_neighbour_pulse_wait = GameContent.catalog().pacing().heart_beat_seconds
	for _tried: int in neighbours.size():
		_neighbour_pulse_index = (_neighbour_pulse_index + 1) % neighbours.size()
		var map_id: StringName = neighbours[_neighbour_pulse_index]
		if _away.owed_ms(map_id) >= pulse * 1000:
			catch_up_map(world_map_of(map_id), true)
			return


## The maps within two passages of `map_id`, nearest first: a wanderer ranges over its home
## and the rooms next to it, so one that could come in by a door stands at most two doors off.
func _door_neighbours(map_id: StringName) -> Array:
	if not _neighbours_by_map.has(map_id):
		var maps: Array[StringName] = []
		var ring: Array[StringName] = [map_id]
		for _depth: int in 2:
			var next: Array[StringName] = []
			for from: StringName in ring:
				for portal: PortalDefinition in GameContent.catalog().portals_for_map(from):
					var to: StringName = portal.destination_map_id
					if to != map_id and not maps.has(to) and world_map_of(to) != null:
						maps.append(to)
						next.append(to)
			ring = next
		_neighbours_by_map[map_id] = maps
	return _neighbours_by_map[map_id]


func note_corpse_scattered(corpse_id: StringName) -> void:
	_scattered_corpses[corpse_id] = true


## The player's corpse `corpse_id` still lies somewhere, waiting for them (WorldMapCorpses.holds_for_player()).
func corpse_waits(corpse_id: StringName) -> bool:
	for map: WorldMapController in world_maps():
		var corpse: CorpseState = map.corpses.find_corpse(corpse_id)
		if corpse != null:
			return map.corpses.holds_for_player(corpse)
	return false


func corpse_scattered(corpse_id: StringName) -> bool:
	return _scattered_corpses.has(corpse_id)


func away_times() -> WorldAwayTimes:
	return _away


## The time of day (DECISIONS「昼夜」): presentation and the outdoor rooms' line read it.
func day_clock() -> DayClock:
	return _day


## The day's phase now (day_phases.json phase_id; "" without phases): what a `phase` condition
## reads (JournalEntryDefinition.When.PHASE, ScriptedAct `phase`).
func day_phase_id() -> StringName:
	var phase: DayPhaseDefinition = _day.phase()
	return &"" if phase == null else phase.phase_id


## Native (关北 C; DECISIONS「等到天黑」): the player waits until the next of `phase_ids` begins
## (an act's `until_phase`: the 篝火's 等到天黑). The world clock goes forward by that much as one
## stretch: the day (its phase begun told), the sky, the player's own recovery and timed applies,
## rooms' resets, hazards and hidden passages, the time every other map is owed (别的地图时间补算,
## caught up when the player comes to them), and the player's own map caught up as a map they
## come back to (its NPCs healed and wandered, its corpses aged). Not in a fight, nor while the
## world is held. True when the clock moved (false in one of the phases already, or none such).
func wait_until_phase(phase_ids: Array[StringName]) -> bool:
	if not npc_world_time_allowed():
		return false
	var game_seconds: int = _day.seconds_until_phase(phase_ids)
	if game_seconds <= 0:
		return false
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	# A real second is DAY_MINUTES / day_length_minutes game minutes (DayClock.advance()).
	var real_seconds: float = float(game_seconds) * float(pacing.day_length_minutes) / float(DayClock.DAY_MINUTES)
	var before: int = _day.phase_index()
	_day.set_day_seconds(_day.day_seconds() + game_seconds)
	if _day.phase_index() != before and _day.phase() != null:
		day_phase_began.emit(_day.phase())
	if pacing.sky_weather:
		_sky.advance(real_seconds, pacing.day_length_minutes, sky_random_source())
	_away.advance(real_seconds)
	advance_player_recovery(real_seconds)
	advance_player_timed_applies(real_seconds)
	advance_quest_time(real_seconds)
	advance_bounty_time(real_seconds)
	advance_hidden_passages(real_seconds)
	advance_room_hazards(real_seconds)
	advance_room_resets(real_seconds)
	var map: WorldMapController = active_map() as WorldMapController
	if map != null:
		# The player's own map as one they come back to: up to the catch-up limit beat by beat.
		var limit: int = pacing.away_catch_up_limit_seconds
		var owed: int = _away.owed_ms(map.map_id())
		_away.stamp(map.map_id())
		var seed: int = _away_seed(map.map_id(), owed)
		_catch_up_revive_random = GodotCombatRandomSource.new(hash([seed, "revive"]), true)
		map.npc_life.catch_up(real_seconds if limit <= 0 else minf(real_seconds, float(limit)), seed)
		_catch_up_revive_random = null
		if limit > 0 and real_seconds > float(limit):
			map.npc_life.settle()
	return true


## The cloud (DECISIONS「天气」): the save reads it whole; presentation and the outdoor
## rooms' line read sky_level().
func sky_state() -> SkyState:
	return _sky


## The cloud's level as the game shows it: 0 (clear, nothing said) while the pacing's
## sky_weather is off (经典), else the SkyState's.
func sky_level() -> int:
	return _sky.level() if GameContent.catalog().pacing().sky_weather else 0


## The sky's own stream (transient, not in Save): each change's direction and the wait to
## the next. A suite injects its own (configure_sky_random_source()).
func sky_random_source() -> WorldInteractionRandomSource:
	if _sky_random == null:
		_sky_random = GodotWorldInteractionRandomSource.new(world_interaction_seed + 2, deterministic_world_interaction_seed)
	return _sky_random


func configure_sky_random_source(value: WorldInteractionRandomSource) -> bool:
	if value == null:
		return false
	_sky_random = value
	return true


## 别的地图时间补算 (DECISIONS): the world time `map` went without the player, caught up at
## once (WorldMapNpcLife.catch_up()), before anything looks at it or changes it: the player
## coming onto it, a room reset there, an NPC leaving it or coming onto it. Up to pacing.json
## away_catch_up_limit_seconds beat by beat, the rest settled. Its draws (heal ticks, the
## revive of one falling) come from the world-interaction seed, the map and the time owed,
## never from a session stream, so leaving and coming back draws nothing the map's own beat
## would, and a Continue owes the same where time changes its people's state (where its
## wanderers stand goes on from the save); only a death the player caused (a drug) gives its
## reward as on the player's map. Nothing for the player's map.
func catch_up_map(map: WorldMapController, arrivals: bool = false) -> void:
	if map == null or map == active_map() or not _initialized or _world_content_revision != WorldContentRevision.CURRENT_PUBLIC:
		return
	var owed: int = _away.owed_ms(map.map_id())
	_away.stamp(map.map_id())
	if owed <= 0:
		return
	var limit: int = GameContent.catalog().pacing().away_catch_up_limit_seconds * 1000
	var seed: int = _away_seed(map.map_id(), owed)
	_catch_up_revive_random = GodotCombatRandomSource.new(hash([seed, "revive"]), true)
	map.npc_life.catch_up((owed if limit <= 0 else mini(owed, limit)) / 1000.0, seed, arrivals)
	_catch_up_revive_random = null
	if limit > 0 and owed > limit:
		map.npc_life.settle()


func _away_seed(map_id: StringName, owed_ms: int) -> int:
	var source: WorldInteractionRandomSource = world_interaction_random_source()
	var stream: RandomStreamSnapshot = source.capture_random_state() if source != null and source.has_method(&"capture_random_state") else null
	return hash([0 if stream == null else stream.seed, String(map_id), owed_ms])


func _entering(destination: WorldResidentMapController) -> void:
	catch_up_map(destination as WorldMapController)
	# The story's stage on the map the player comes onto (DECISIONS「剧情演出」).
	WorldStoryPresence.stage(self, destination as WorldMapController)


func _switched(source: WorldResidentMapController, destination: WorldResidentMapController) -> void:
	_away.stamp(source.map_id())
	_away.stamp(destination.map_id())
	_note_recent_map(destination.map_id())


## `map_id` is the player's map now: it moves to the front of the recent maps, and the maps
## past the kept count (feel.voxel_worlds_kept; 0 keeps every one) let their voxel world go.
## The 2D maps stay resident whatever happens here (DECISIONS「别的地图时间补算」).
func _note_recent_map(map_id: StringName) -> void:
	_recent_maps.erase(map_id)
	_recent_maps.push_front(map_id)
	var kept: int = GameContent.catalog().pacing().feel.voxel_worlds_kept
	if kept <= 0:
		return
	while _recent_maps.size() > kept:
		var old: StringName = _recent_maps.pop_back()
		var map: WorldResidentMapController = resident_map(old)
		var view: WorldVoxelView = null if map == null else map.get_node_or_null("MapView") as WorldVoxelView
		if view != null:
			view.release_world()


## Which maps still hold a built voxel world's place, the player's first (tests, kits).
func recent_maps() -> Array[StringName]:
	return _recent_maps.duplicate()


## What each map but the player's is owed (the save's away_ms), leaving out those time
## could not change (WorldMapNpcLife.owes_time(): their catch-up would do and draw nothing).
func away_owed_by_map() -> Dictionary[StringName, int]:
	var away: Array[StringName] = []
	for map: WorldMapController in world_maps():
		if map != active_map() and map.npc_life.owes_time():
			away.append(map.map_id())
	return _away.owed_by_map(away)


## The player's timed applies (fakefault.c's, 阴阳眼) count down on world time outside a
## fight, as call_out() does; a perform's ending there only takes its applies back (its
## remove_effect() strikes only in the fight it began in, owner), a spell's says its line.
func advance_player_timed_applies(delta: float) -> void:
	if not npc_world_time_allowed() or _player == null or not is_finite(delta) or delta < 0.0:
		return
	var timed: CharacterTimedApplies = _player.state.timed_applies
	if timed.is_empty():
		_player_timed_remainder_ms = 0.0
		return
	var elapsed: float = _player_timed_remainder_ms + delta * 1000.0
	var whole: int = int(elapsed)
	_player_timed_remainder_ms = elapsed - whole
	var ended: Array[CharacterTimedApplies.Entry] = timed.advance_entries(whole)
	if not ended.is_empty():
		martial_arts().effects_ended(ended)


## The time left for 朱鸿雪's task (task_time - time()) runs while the game does,
## fights, map changes and a lying player included; pause and a closed game stop it
## (DECISIONS 3C).
func advance_quest_time(delta: float) -> void:
	if (
		not _initialized or _world_content_revision != WorldContentRevision.CURRENT_PUBLIC
		or not application_gameplay_allows_encounter_advance() or not can_process()
		or _restore_candidate_staged or _session_swap_reparenting
		or _player == null or not is_finite(delta) or delta < 0.0
	):
		return
	var quest: CharacterQuestState = _player.state.quest
	if not quest.has_task() or quest.remaining_ms < 0:
		_quest_remainder_ms = 0.0
		return
	var elapsed: float = _quest_remainder_ms + delta * 1000.0
	var whole: int = int(elapsed)
	_quest_remainder_ms = elapsed - whole
	quest.advance(whole)


## The 雪亭驿 board's empty slots fill on the same play time as 朱鸿雪's task (A2).
func advance_bounty_time(delta: float) -> void:
	if (
		not _initialized or not application_gameplay_allows_encounter_advance() or not can_process()
		or _restore_candidate_staged or _session_swap_reparenting or _player == null
		or not is_finite(delta) or delta < 0.0
	):
		return
	bounties().advance(delta)


## Hidden passages close on world time, which stops in a fight.
func advance_hidden_passages(delta: float) -> void:
	if _hidden_passages != null and npc_world_time_allowed():
		_hidden_passages.advance(delta)


## Room hazards come on world time, which stops in a fight.
func advance_room_hazards(delta: float) -> void:
	if _room_hazards != null and npc_world_time_allowed():
		_room_hazards.advance(delta)


func room_hazards() -> WorldRoomHazards:
	return _room_hazards


## Rooms reset on world time, on every map (native rooms are always loaded).
func advance_room_resets(delta: float) -> void:
	if _room_resets != null and npc_world_time_allowed():
		for room: String in _room_resets.advance(delta):
			reset_room(room)
	if _player_resets != null and npc_world_time_allowed() and _player != null:
		for _due: String in _player_resets.advance(delta):
			PlayerObjectReset.apply(_player.state)


## std/room.c reset() of one ES2 room: its spawns on whichever map holds them, and
## weapon_storage.c's own reset() of the shelf.
func reset_room(legacy_room: String) -> void:
	# Only the maps holding the room's content: on the others its reset does nothing.
	# No room ("") is every map's (WorldMapNpcs._draw_groups("")).
	if _maps_by_room.is_empty():
		_maps_by_room = WorldRoomResets.maps_by_room()
	var maps: Array = _maps_by_room.get(legacy_room, [])
	for map: WorldMapController in world_maps():
		if legacy_room.is_empty() or maps.has(map.map_id()):
			catch_up_map(map)
			map.reset_room(legacy_room)
	if _hidden_passages != null:
		_hidden_passages.reset_room(legacy_room)
	if _room_traps != null:
		_room_traps.reset_room(legacy_room)


func room_resets() -> WorldRoomResets:
	return _room_resets


func hidden_passages() -> WorldHiddenPassages:
	return _hidden_passages


func room_traps() -> WorldRoomTraps:
	return _room_traps


## The rooms' own flags (bamboo3.c's exits/enter, train.c's got), not saved.
func room_states() -> WorldRoomStates:
	return _room_states


## 放过 on `npc` as it lay (DECISIONS「剧情演出」; NpcHooks `spared`): it goes into the mood
## its hooks name (with what the mood carries in hand), and the player is marked. Nothing
## for an NPC without the hook (the fight's own 放过 stands as it is).
func npc_spared(npc: NpcRuntimeState) -> void:
	var hooks: NpcHooks = null if npc == null else npc.definition().hooks()
	if hooks == null or not hooks.has_spared():
		return
	# Only while it is in the mood the hook names (刘安禄 revealed): otherwise 放过 leaves it as it was.
	if not hooks.spared_only_in_mood.is_empty() and not npc.has_flag(StringName(NpcMood.FLAG_PREFIX + hooks.spared_only_in_mood)):
		return
	if not hooks.spared_mood.is_empty() and hooks.moods.has(hooks.spared_mood):
		var mood: NpcMood = hooks.moods[hooks.spared_mood]
		npc.put_in_mood(mood)
		var map: WorldMapController = resident_map(npc.world_location().map_id) as WorldMapController
		if map != null:
			for item_id: StringName in mood.carry:
				map.floor_items.give_new_item_to(npc, item_id)
	if not hooks.spared_mark.is_empty() and _player != null and _player.state != null:
		_player.state.marks[hooks.spared_mark] = 1
	# Let fall where it lies (玄冥子's 残卷): a new one on the floor at its feet, once — spared a
	# second time it has nothing more to drop (FLAG_DROPPED_WHEN_SPARED, which its die_carries
	# of the same item reads too).
	if not hooks.spared_drop.is_empty() and not npc.has_flag(NpcDefinition.FLAG_DROPPED_WHEN_SPARED):
		var lying: WorldMapController = resident_map(npc.world_location().map_id) as WorldMapController
		var body: WorldCharacterBody2D = null if lying == null else lying.npcs.runtime_body_for_character(npc.character_id)
		if lying == null or body == null or lying.floor_items.place_new_floor_item(hooks.spared_drop, body.global_position).is_empty():
			push_error("%s could not drop %s as it was spared" % [npc.definition().definition_id, hooks.spared_drop])
		else:
			npc.set_flag(NpcDefinition.FLAG_DROPPED_WHEN_SPARED, true)
	# Fled: gone for good once the fight is over (WorldMapHostilities.after_fight()).
	if hooks.spared_leave:
		npc.set_flag(NpcDefinition.FLAG_LEAVES_WHEN_FREE, true)


## A room's valid_leave() as the player walks out of `from_zone_id` (WorldRoomTraps).
func player_leaving_zone(from_zone_id: StringName, to_zone_id: StringName) -> void:
	if _room_traps != null:
		_room_traps.player_leaving(from_zone_id, to_zone_id)


func advance_player_recovery(delta: float, busy_only: bool = false) -> PlayerRecoveryCadenceResult:
	if not player_recovery_time_allowed():
		var frozen: PlayerRecoveryCadenceResult = PlayerRecoveryCadenceResult.new()
		frozen.outcome = PlayerRecoveryCadenceResult.Outcome.FROZEN
		return frozen
	var result: PlayerRecoveryCadenceResult = _player_recovery_cadence.advance(delta, _player.state, _player.busy, true, busy_only)
	if not result.lines.is_empty() and shared_ui() != null:
		shared_ui().append_colored_lines(result.lines)
	# char.c heart_beat(): below zero after a condition (蛇毒), the player falls or dies.
	if result.conditions_updated > 0 and _player.state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		var map: WorldMapController = active_map() as WorldMapController
		if map != null:
			map.player_fall_below_zero()
	return result


func _exit_tree() -> void:
	if _session_swap_reparenting:
		return
	if _pacing_before != null:
		PacePresets.restore(GameContent.catalog(), _pacing_before)
		_pacing_before = null
	for map_id: StringName in _resident_maps.keys():
		var value: Variant = _resident_maps.get(map_id)
		if not is_instance_valid(value):
			continue
		var resident: WorldResidentMapController = (
			value as WorldResidentMapController
		)
		if resident != null and resident.get_parent() == null:
			resident.free()
	_resident_maps.clear()


func initialize_session() -> bool:
	if _initialized:
		return true
	if active_map_slot == null:
		return false
	# No world is built on unreadable or inconsistent content data.
	if not GameContent.load_errors().is_empty():
		return false
	if _bootstrap_mode == BootstrapMode.RESTORE:
		if not _initialize_restore_authorities():
			_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.RECONSTRUCTION_FAILED
			return false
	elif not _initialize_authorities():
		return false
	_world_simulation_gate = WorldSimulationGate.new()
	_combat_encounter_coordinator = CombatEncounterCoordinator.new(
		self,
		_world_simulation_gate,
	)
	# The pace (前两小时 E): a Continue's is the save's, a New Game's the panel's; the 木人
	# and the board follow it from the first map.
	if _bootstrap_mode == BootstrapMode.RESTORE and _restore_preparation != null and _restore_preparation.player != null and _restore_preparation.player.state != null:
		_source_pace = _restore_preparation.player.state.pace
	if _pacing_before == null:
		_pacing_before = PacePresets.apply(GameContent.catalog(), _source_pace)
	# 经典 (DECISIONS「天气」): the sky stays clear from the first moment, and saves so.
	if not GameContent.catalog().pacing().sky_weather:
		_sky.set_state(0, SkyState.NEW_GAME_MINUTES)
	for map_id: StringName in _world_map_ids():
		if not _register_map(map_id):
			return false

	var ready: bool
	if _bootstrap_mode == BootstrapMode.RESTORE:
		ready = _initialize_restore_residents()
	elif _bootstrap_mode == BootstrapMode.SOURCE_ENTRY:
		ready = _initialize_source_residents()
	else:
		# The technical fixture world starts in the Old Pine clearing.
		ready = _bind_residents_staged() and _activate_first_map(OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	if ready:
		_hidden_passages = WorldHiddenPassages.new(self)
		_hidden_passages.open_for_player_below()
		_room_traps = WorldRoomTraps.new(self)
		_room_hazards = WorldRoomHazards.new(self)
		_room_states = WorldRoomStates.new()
		_room_resets = WorldRoomResets.new(WorldRoomResets.resetting_rooms(), GameContent.catalog().pacing().room_reset_seconds, npc_ambience_random_source())
		_player_resets = WorldRoomResets.new([PLAYER_RESET], GameContent.catalog().pacing().room_reset_seconds, npc_ambience_random_source())
		if _bootstrap_mode == BootstrapMode.SOURCE_ENTRY:
			if _player != null and _player.state != null:
				_player.state.pace = _source_pace
			progression_rewards().note_birthplace()
	return ready


## Public ApplicationShell/Host selects SOURCE_ENTRY before tree attachment. `pace` is the
## New Game panel's 现代 / 经典 (CharacterState.PACE_*; DECISIONS「经典模式总开关」).
func configure_source_entry(display_name: String, gender: StringName, pace: StringName = CharacterState.PACE_MODERN) -> bool:
	if is_inside_tree() or _initialized or _bootstrap_mode != BootstrapMode.NEW_GAME:
		return false
	if display_name.strip_edges().is_empty() or gender not in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		return false
	if pace not in [CharacterState.PACE_MODERN, CharacterState.PACE_CLASSIC]:
		return false
	_source_name = display_name
	_source_gender = gender
	_source_pace = pace
	_bootstrap_mode = BootstrapMode.SOURCE_ENTRY
	_world_content_revision = WorldContentRevision.CURRENT_PUBLIC
	return true


func configure_restore(preparation: OldPineWorldRestorePreparation) -> bool:
	if (
		is_inside_tree()
		or _initialized
		or _bootstrap_mode != BootstrapMode.NEW_GAME
		or preparation == null
		or not preparation.is_valid()
	):
		return false
	_bootstrap_mode = BootstrapMode.RESTORE
	_restore_preparation = preparation
	_world_content_revision = preparation.world_content_revision
	process_mode = Node.PROCESS_MODE_DISABLED
	return true


func world_content_revision() -> WorldContentRevision.Value:
	return _world_content_revision


func bootstrap_mode() -> int:
	return _bootstrap_mode


func is_initialized() -> bool:
	return _initialized


func is_restore_candidate_staged() -> bool:
	return _restore_candidate_staged


func restore_failure_outcome() -> int:
	return _restore_failure_outcome


func restored_player_position() -> Vector2:
	return Vector2.ZERO if _restore_preparation == null else _restore_preparation.player_position


func restored_npc_entries() -> Array[OldPineRestoredNpcEntry]:
	return [] if _restore_preparation == null else _restore_preparation.npc_entries()


func restored_corpse_entries() -> Array[OldPineRestoredCorpseEntry]:
	return [] if _restore_preparation == null else _restore_preparation.corpse_entries()


## Dropped items and where they lie, while Continue builds the maps.
func restored_floor_items() -> Array[GameSaveValueTypes.FloorItemSnapshot]:
	return [] if _restore_preparation == null else _restore_preparation.floor_items.duplicate()


## The notes the note mazes showed, while Continue builds the maps.
func restored_maze_notes() -> Dictionary[StringName, int]:
	var none: Dictionary[StringName, int] = {}
	return none if _restore_preparation == null else _restore_preparation.maze_notes.duplicate()


## What each map was owed at the save (DECISIONS「别的地图时间补算」).
func restored_away_ms() -> Dictionary[StringName, int]:
	var none: Dictionary[StringName, int] = {}
	return none if _restore_preparation == null else _restore_preparation.away_ms.duplicate()


func activate_restore_candidate() -> bool:
	if (
		_bootstrap_mode != BootstrapMode.RESTORE
		or not _initialized
		or not _restore_candidate_staged
	):
		return false
	var map: WorldResidentMapController = active_map()
	if map == null:
		return false
	process_mode = Node.PROCESS_MODE_INHERIT
	map.set_restore_staging(false)
	WorldStoryPresence.stage(self, map as WorldMapController)
	if not map.complete_activation() or not _reconcile_active_residents():
		map.prepare_for_deactivation()
		map.set_restore_staging(true)
		process_mode = Node.PROCESS_MODE_DISABLED
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.ACTIVATION_FAILED
		return false
	map.resume_after_relationship_reconciliation()
	if not _initialize_player_recovery():
		map.prepare_for_deactivation()
		map.set_restore_staging(true)
		process_mode = Node.PROCESS_MODE_DISABLED
		return false
	_restore_candidate_staged = false
	_activation_frame = Engine.get_process_frames()
	_away.restore(restored_away_ms())
	if _restore_preparation != null:
		_day.set_day_seconds(_restore_preparation.day_seconds)
		_sky.set_state(_restore_preparation.sky_level, _restore_preparation.sky_minutes_left)
	var world_map: WorldMapController = map as WorldMapController
	if world_map != null:
		world_map.npc_life.restored_zone_id = _player.world_location().zone_id
	_resume_restored_life_flow()
	return true


func player_runtime() -> WorldPlayerRuntimeType:
	return _player


func inventory_state() -> InventoryState:
	return _inventory


func stack_collection() -> CombinedStackCollection:
	return _stacks


func item_instance_index() -> WorldItemInstanceIndex:
	return _item_index


func npc_random_source() -> NpcInitializationRandomSource:
	return _npc_random


func combat_random_source() -> CombatRandomSource:
	return _combat_random


func world_interaction_random_source() -> WorldInteractionRandomSource:
	return _world_interaction_random


func item_instance_scope() -> StringName:
	return _item_instance_scope


func item_id_allocator() -> SessionItemIdAllocator:
	return _item_id_allocator


func world_simulation_gate() -> WorldSimulationGate:
	return _world_simulation_gate


## Who holds world time now (hold_world_time()): the menu window.
var _world_time_holds: Dictionary[StringName, bool] = {}


func combat_encounter_coordinator() -> CombatEncounterCoordinator:
	return _combat_encounter_coordinator


func encounter_combat_bindings(
	encounter: CombatEncounter,
) -> Array[CombatSliceCharacterBinding]:
	var map: WorldResidentMapController = active_map()
	return [] if map == null else map.encounter_combat_bindings(encounter)


## Content presentation lookup; semantic IDs remain independent of scene names.
func encounter_display_name(character_id: StringName) -> String:
	if _player != null and character_id == _player.character_id:
		return _player.facts.display_name
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return String(character_id) if npc == null else npc.definition().display_name


## Content presentation lookup: someone's 气 now (the battle panel's last look at a
## finished fight); null when nobody here has `character_id`.
func encounter_vitality(character_id: StringName) -> CharacterResourceState:
	if _player != null and character_id == _player.character_id:
		return _player.state.vitality
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return null if npc == null else npc.character_state.vitality


## Content presentation lookup: the legacy gender behind ES2's pronouns.
func encounter_gender(character_id: StringName) -> StringName:
	if _player != null and character_id == _player.character_id:
		return _player.state.gender
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return &"" if npc == null else npc.character_state.gender


## Content presentation lookup: the skill dodge is mapped to (whose lines a dodge reads).
func encounter_dodge_skill(character_id: StringName) -> StringName:
	if _player != null and character_id == _player.character_id:
		return _player.state.skills.mapped_skill(&"dodge")
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return &"" if npc == null else npc.character_state.skills.mapped_skill(&"dodge")


func encounter_skill_effect_registry() -> SkillImprovementEffectRegistry:
	var map: WorldResidentMapController = active_map()
	return null if map == null else map.encounter_skill_effect_registry()


## One combat round per ES2 heart_beat, on every map (common/pacing.json).
func encounter_opportunity_interval_seconds() -> float:
	return GameContent.catalog().pacing().combat_round_seconds


func application_gameplay_allows_encounter_advance() -> bool:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	return (
		_initialized
		and not _session_swap_suspended
		and process_mode != Node.PROCESS_MODE_DISABLED
		and tree != null
		and not tree.paused
	)


func resolve_encounter_binding(
	character_id: StringName,
) -> CombatEncounterAuthorityBinding:
	if not _initialized or character_id.is_empty():
		return null
	if _player != null and character_id == _player.character_id:
		return CombatEncounterAuthorityBinding.new(
			character_id,
			_player.state,
			_player.relationship,
			_player.busy,
			_player.armor,
		)
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	if npc == null:
		return null
	return CombatEncounterAuthorityBinding.new(
		character_id,
		npc.character_state,
		npc.relationship,
		npc.busy,
		npc.armor,
	)


func resolve_encounter_location(character_id: StringName) -> WorldLocationState:
	return _location_for_character(character_id)


## `downed`: an NPC lying unconscious counts too (kill.c: the player's 攻击 at one).
func encounter_participant_is_available(character_id: StringName, downed: bool = false) -> bool:
	if _player != null and character_id == _player.character_id:
		return (
			_player.exists_in_world
			and _player.combat_available
			and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		)
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return (
		npc != null
		and npc.exists_in_map
		and npc.combat_available
		and (
			npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
			or (downed and npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
		)
	)


func freeze_world_for_encounter(encounter_id: StringName) -> bool:
	var map: WorldResidentMapController = active_map()
	return (
		_initialized
		and not _transitioning
		and _world_simulation_gate != null
		and _world_simulation_gate.freeze_owner_id() == encounter_id
		and map != null
		and map.freeze_world_gameplay(encounter_id)
	)


func thaw_world_after_encounter(encounter_id: StringName) -> bool:
	var map: WorldResidentMapController = active_map()
	return (
		_initialized
		and _world_simulation_gate != null
		and _world_simulation_gate.freeze_owner_id() == encounter_id
		and map != null
		and map.thaw_world_gameplay(encounter_id)
	)


func active_map() -> WorldResidentMapController:
	return _resident_maps.get(_active_map_id)


func resident_map(map_id: StringName) -> WorldResidentMapController:
	return _resident_maps.get(map_id)


func world_map_of(map_id: StringName) -> WorldMapController:
	return _resident_maps.get(map_id) as WorldMapController


## The resident map a zone lies on (a shop's own since the remap); null when none is.
func world_map_of_zone(zone_id: StringName) -> WorldMapController:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	return null if zone == null else world_map_of(zone.map_id)


## room.c valid_leave() for a door between two zones, on whichever map holds the first.
func door_closed_between(from_zone_id: StringName, to_zone_id: StringName) -> bool:
	var map: WorldMapController = world_map_of_zone(from_zone_id)
	return map != null and map.npc_life.door_closed_between(from_zone_id, to_zone_id)


## Where a catch-up's moves left an NPC of `source` (WorldMapNpcLife._wander()): on a free
## spot of `zone_id`, drawn from the catch-up's `random`, on whichever map holds it (through a
## building's door: onto that map, caught up first). False when it could not be put there
## (it stays where it stood).
func place_away(npc: NpcRuntimeState, source: WorldMapController, zone_id: StringName, random: WorldInteractionRandomSource) -> bool:
	var destination: WorldMapController = world_map_of_zone(zone_id)
	var location: WorldLocationState = null if destination == null else destination.location_for_zone(zone_id)
	var zone: WorldPhysicalZoneArea2D = null if destination == null else destination.physical_zone(zone_id)
	if location == null or zone == null or destination == active_map():
		return false
	if destination == source:
		if not source.npc_life.npc_walker().place_into(npc.character_id, source.npcs.runtime_body_for_character(npc.character_id), zone, random):
			return false
		npc.set_world_location(location)
		return true
	var body: Node2D = source.npcs.runtime_body_for_character(npc.character_id)
	if body == null:
		return false
	var was: WorldLocationState = npc.world_location()
	var stood: Vector2 = body.global_position
	# Caught up before its spot is chosen, so the spot is clear of who stands there now.
	catch_up_map(destination)
	if not _move_npc(npc, source, destination, location, _clear_spot(destination, zone_id, zone.global_rect().get_center())):
		return false
	var moved: Node2D = destination.npcs.runtime_body_for_character(npc.character_id)
	if (
		not destination.npc_life.npc_walker().place_into(npc.character_id, moved, zone, random)
		and (moved == null or not MapPlacementValidator.is_valid_character_position(destination, zone_id, moved.global_position))
	):
		_move_npc(npc, destination, source, was, stood)
		return false
	return true


## A neighbour's wanderer coming in through `portal` onto the player's map (the neighbour
## pulse): beside its arrival marker, met as one walking in (greeting, notice), and go.c's
## 走了过来。 where the player hears it.
func arrive_away(npc: NpcRuntimeState, source: WorldMapController, portal: PortalDefinition) -> bool:
	var destination: WorldMapController = active_map() as WorldMapController
	if destination == null or portal == null or portal.destination_map_id != destination.map_id() or not move_npc_through(npc, source, portal):
		return false
	if destination.npc_life.player_hears(npc) and destination.hud() != null:
		destination.hud().append_log_lines([tr("{name}走了过来。").format({"name": tr(npc.definition().display_name)})])
	return true


## world_map_of_zone() for a look at who is there now, to decide on it (a scripted act's
## NPC in a room on another map): that map caught up first (catch_up_map()), so nobody
## drugged there meanwhile still seems to stand.
func caught_up_map_of_zone(zone_id: StringName) -> WorldMapController:
	var map: WorldMapController = world_map_of_zone(zone_id)
	catch_up_map(map)
	return map


## Every resident map, in content order (stable for saves).
func world_maps() -> Array[WorldMapController]:
	var result: Array[WorldMapController] = []
	for definition: MapDefinition in GameContent.catalog().maps():
		var map: WorldMapController = world_map_of(definition.map_id)
		if map != null:
			result.append(map)
	return result


## Every resident NPC, map by map in spawn order.
func world_npcs() -> Array[NpcRuntimeState]:
	var result: Array[NpcRuntimeState] = []
	for map: WorldMapController in world_maps():
		result.append_array(map.npc_runtimes())
	return result


func is_session_swap_suspended() -> bool:
	return _session_swap_suspended


func configure_combat_random_source(value: CombatRandomSource) -> bool:
	if value == null:
		return false
	_combat_random = value
	for map: WorldResidentMapController in _resident_maps.values():
		if not map.replace_combat_random_source(value):
			return false
	return true


func configure_world_interaction_random_source(
	value: WorldInteractionRandomSource,
) -> bool:
	if value == null:
		return false
	_world_interaction_random = value
	for map: WorldResidentMapController in _resident_maps.values():
		if not map.replace_world_interaction_random_source(value):
			return false
	return true


func suspend_for_session_swap() -> bool:
	if (
		not _initialized
		or _transitioning
		or _session_swap_suspended
		or active_map_slot == null
		or active_map_slot.get_child_count() != 1
	):
		return false
	var map: WorldResidentMapController = active_map()
	if map == null or not map.suspend_for_session_swap():
		return false
	map.set_restore_staging(true)
	process_mode = Node.PROCESS_MODE_DISABLED
	_session_swap_suspended = true
	return true


func resume_after_failed_session_swap() -> bool:
	if not _session_swap_suspended:
		return false
	var map: WorldResidentMapController = active_map()
	if map == null:
		return false
	process_mode = Node.PROCESS_MODE_INHERIT
	map.set_restore_staging(false)
	if not map.resume_after_session_swap_rollback():
		map.set_restore_staging(true)
		process_mode = Node.PROCESS_MODE_DISABLED
		return false
	_session_swap_suspended = false
	return true


func begin_session_swap_reparent() -> bool:
	if (
		_bootstrap_mode != BootstrapMode.RESTORE
		or not _initialized
		or _session_swap_reparenting
	):
		return false
	_session_swap_reparenting = true
	return true


func complete_session_swap_reparent() -> void:
	_session_swap_reparenting = false


func _initialize_authorities() -> bool:
	_item_instance_scope = _new_item_instance_scope()
	_item_id_allocator = SessionItemIdAllocator.new(_item_instance_scope)
	if not _item_id_allocator.is_valid():
		return false
	_npc_random = GodotNpcInitializationRandomSource.new(
		npc_seed,
		deterministic_npc_seed,
	)
	_combat_random = GodotCombatRandomSource.new(
		combat_seed,
		deterministic_combat_seed,
	)
	_world_interaction_random = GodotWorldInteractionRandomSource.new(
		world_interaction_seed,
		deterministic_world_interaction_seed,
	)
	if _bootstrap_mode == BootstrapMode.SOURCE_ENTRY:
		var birth: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
		if not birth.initialize(PLAYER_ID, _source_gender, _source_name, _item_id_allocator):
			return false
		_inventory = birth.inventory
		_stacks = birth.stacks
		_item_index = birth.item_index
		_player = NewPlayerRuntimeComposition.create(PLAYER_ID, birth.player, SnowWorldDefinitions.birth_location())
		return _player != null
	_inventory = InventoryState.new()
	_stacks = CombinedStackCollection.new()
	_item_index = WorldItemInstanceIndex.new()
	var prototype: CombatSliceCharacterBinding = CombatSliceDemoFactory.create_player()
	var start_zone: ZoneDefinition = GameContent.catalog().zone(
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID
	)
	if prototype == null or start_zone == null:
		return false
	prototype.state.progression.combat_experience = NEW_GAME_COMBAT_EXPERIENCE
	_player = WorldPlayerRuntimeType.new(
		PLAYER_ID,
		prototype.state,
		CombatRelationshipState.new(PLAYER_ID),
		ActionBusyState.new(),
		ArmorState.new(),
		WorldLocationState.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			start_zone.zone_id,
			start_zone.combat_location_id,
		),
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		PlayerBodyFacts.fresh_human(
			prototype.state.attributes.strength
		),
	)
	var demo_primary: EquippedWeaponRef = _player.state.equipment.primary_weapon()
	if demo_primary == null:
		return false
	if not _player.state.equipment.unwield(demo_primary.instance_id).succeeded:
		return false
	var definition: WeaponDefinition = WeaponDefinition.new(
		CombatSliceContentProfile.LONG_SWORD_ID,
		CombatSliceContentProfile.LONG_SWORD_SKILL_ID,
		false,
		false,
		CombatSliceContentProfile.LONG_SWORD_SOURCE,
	)
	var primary: EquippedWeaponRef = EquippedWeaponRef.new(
		StringName("%s.player-long-sword" % String(_item_instance_scope)),
		definition,
	)
	if not _player.state.equipment.wield(primary, false).succeeded:
		return false
	var player_item: ItemInstance = ItemInstance.new(primary.instance_id, primary.weapon_id)
	if (
		not _inventory.register_item(
			player_item,
			CombatSliceContentProfile.LONG_SWORD_WEIGHT,
		)
		or not _item_index.register_snapshot(player_item)
	):
		return false
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, PLAYER_ID),
		true,
		true,
		_player.maximum_encumbrance,
	)
	return InventoryTransferService.new().transfer(
		_inventory,
		player_item.item_instance_id,
		destination,
	).succeeded


func _initialize_restore_authorities() -> bool:
	if _restore_preparation == null or not _restore_preparation.is_valid():
		return false
	_player = _restore_preparation.player
	_inventory = _restore_preparation.item_domain.inventory
	_stacks = _restore_preparation.item_domain.combined_stacks
	_foods = _restore_preparation.item_domain.food_collection
	_liquids = _restore_preparation.item_domain.liquid_collection
	_item_index = _restore_preparation.item_index
	_item_id_allocator = _restore_preparation.item_allocator
	_item_instance_scope = _item_id_allocator.scope
	_npc_random = _restore_preparation.npc_random
	_combat_random = _restore_preparation.combat_random
	_world_interaction_random = _restore_preparation.world_interaction_random
	return true


func _initialize_source_residents() -> bool:
	# Every map binds the same authority graph. Fresh source entry alone starts in Inn.
	if not (_bind_residents_staged() and _activate_first_map(SnowWorldDefinitions.INN_MAP_ID) and _initialize_player_recovery()):
		return false
	# The world ran before the player came into it (DECISIONS「别的地图时间补算」): every
	# NPC is as time away leaves it (one create() made with less force than its maximum has
	# it), so no map owes time from the start.
	for map: WorldMapController in world_maps():
		map.npc_life.settle()
	return true


## Ready-time binding once per resident map, in initialization order. Each map is
## then detached, inert, until it becomes active.
func _bind_residents_staged() -> bool:
	for map: WorldResidentMapController in _residents_in_initialization_order():
		map.set_restore_staging(true)
		active_map_slot.add_child(map)
		if not map.initialize_map():
			return false
		map.prepare_for_deactivation()
		map.set_restore_staging(true)
		active_map_slot.remove_child(map)
	return true


func _activate_first_map(map_id: StringName) -> bool:
	var first: WorldResidentMapController = _resident_maps[map_id]
	_active_map_id = map_id
	_note_recent_map(map_id)
	first.set_restore_staging(false)
	active_map_slot.add_child(first)
	WorldStoryPresence.stage(self, first as WorldMapController)
	if not first.complete_activation():
		return false
	_initialized = true
	return _reconcile_active_residents()


func _instantiate_map(map_id: StringName) -> Node:
	var map: MapDefinition = GameContent.catalog().map(map_id)
	if map == null:
		return null
	var scene: PackedScene = _kept_map_scenes.get(map.scene_path) if keep_map_scenes else null
	if scene == null:
		scene = load(map.scene_path) as PackedScene
		if scene != null and keep_map_scenes:
			_kept_map_scenes[map.scene_path] = scene
	if scene == null:
		return null
	# A map's camera is made before its player sets it to follow in physics steps
	# (WorldCharacterBody2D._interpolate()); with interpolation on Godot would switch it and warn.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var interpolating: bool = tree != null and tree.physics_interpolation
	if interpolating:
		tree.physics_interpolation = false
	var made: Node = scene.instantiate()
	if interpolating:
		tree.physics_interpolation = true
	return made


## Every map of the session shares one authority graph; passages open toward
## the maps registered here.
func _register_map(map_id: StringName) -> bool:
	var map: WorldMapController = _instantiate_map(map_id) as WorldMapController
	if map == null or not map.configure_session(self) or not map.configure_world_authorities(_player, _inventory, _stacks, _item_index,
		_npc_random, _combat_random, _world_interaction_random, _item_id_allocator, _world_simulation_gate, _foods, _liquids) or not register_resident_map(map):
		return false
	map.tree_exiting.connect(_on_resident_map_tree_exiting.bind(map.map_id()))
	return true


## The technical fixture world is Old Pine alone; the public world adds every
## other region. Old Pine first: spawns draw from the NPC random source map by
## map in this order, then in spawn order.
func _world_map_ids() -> Array[StringName]:
	return world_map_ids_for(_world_content_revision)


## The maps, in initialization order, of a world with this content revision.
static func world_map_ids_for(revision: WorldContentRevision.Value) -> Array[StringName]:
	var result: Array[StringName] = []
	var others: Array[StringName] = []
	for definition: MapDefinition in GameContent.catalog().maps():
		if definition.region_id == OldPineWorldDefinitions.REGION_ID:
			result.append(definition.map_id)
		elif revision == WorldContentRevision.CURRENT_PUBLIC:
			others.append(definition.map_id)
	result.append_array(others)
	return result


func _residents_in_initialization_order() -> Array[WorldResidentMapController]:
	var result: Array[WorldResidentMapController] = []
	for map_id: StringName in _world_map_ids():
		if _resident_maps.has(map_id):
			result.append(_resident_maps[map_id])
	return result


func _initialize_restore_residents() -> bool:
	for resident: WorldResidentMapController in _residents_in_initialization_order():
		resident.set_restore_staging(true)
		active_map_slot.add_child(resident)
		if not resident.initialize_map():
			_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.BODY_BINDING_FAILED
			return false
		# Runtime binding may create fresh interaction Areas (for example CorpseView).
		# Re-apply staging after initialization so the candidate remains fully inert.
		resident.set_restore_staging(true)
		active_map_slot.remove_child(resident)
	var player_location: WorldLocationState = _player.world_location()
	if player_location == null or player_location.map_id not in _resident_maps:
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.INVALID_WORLD_LOCATION
		return false
	_active_map_id = player_location.map_id
	_note_recent_map(_active_map_id)
	var active: WorldResidentMapController = _resident_maps[_active_map_id]
	active_map_slot.add_child(active)
	# Restore is exact placement, never a spawn lookup or an initial Inn activation.
	active.runtime_player_body().global_position = _restore_preparation.player_position
	if not _validate_restore_positions():
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION
		return false
	_initialized = true
	_restore_candidate_staged = true
	return active_map_slot.get_child_count() == 1


func _validate_restore_positions() -> bool:
	var player_location: WorldLocationState = _player.world_location()
	var player_map: WorldResidentMapController = _resident_maps.get(
		player_location.map_id
	)
	if not MapPlacementValidator.is_valid_character_position(
		player_map,
		player_location.zone_id,
		_restore_preparation.player_position,
	):
		return false
	for entry: OldPineRestoredNpcEntry in _restore_preparation.npc_entries():
		var location: WorldLocationState = entry.runtime.world_location()
		if not MapPlacementValidator.is_valid_character_position(
			_resident_maps.get(location.map_id),
			location.zone_id,
			entry.map_position,
		):
			return false
	for entry: OldPineRestoredCorpseEntry in _restore_preparation.corpse_entries():
		if not MapPlacementValidator.is_valid_corpse_position(
			_resident_maps.get(entry.world_location.map_id),
			entry.world_location.zone_id,
			entry.map_position,
		):
			return false
	# A dropped item lies where its holder stood.
	for record: GameSaveValueTypes.FloorItemSnapshot in _restore_preparation.floor_items:
		if not MapPlacementValidator.is_valid_character_position(
			_resident_maps.get(record.world_location.map_id),
			record.world_location.zone_id,
			Vector2(record.map_position.x, record.map_position.y),
		):
			return false
	return true


func _new_item_instance_scope() -> StringName:
	## The scope is durable data, not a Node ObjectID or a gameplay-RNG draw.
	## Platform cryptographic entropy remains independent across fresh processes;
	## save/load preserves this exact value thereafter.
	return SessionItemIdScopeFactoryType.create_old_pine_scope()


func _on_resident_map_tree_exiting(map_id: StringName) -> void:
	if (
		_initialized
		and not _transitioning
		and not _session_swap_reparenting
		and map_id == _active_map_id
		and not is_queued_for_deletion()
	):
		call_deferred("queue_free")


## go.c's follow_me() across maps: a raised NPC following the player out of the room they
## left by its exit (one next to where they arrived) comes along (WorldMapSpells); one that
## follows every way (owner, 黑松山 plan F2) along any way the player takes (handoff_led()).
func _carry_followers(source: WorldResidentMapController, destination: WorldResidentMapController, left: WorldLocationState) -> void:
	var from_map := source as WorldMapController
	var to_map := destination as WorldMapController
	if from_map == null or to_map == null or left == null or _player == null:
		return
	var adjacent: bool = GameContent.catalog().zones_adjacent(left.zone_id, _player.world_location().zone_id)
	if adjacent or leading():
		from_map.spells.carry_followers(to_map, left.zone_id, adjacent)


## go.c for an NPC whose way leads onto another map (a wanderer leaving a shop by its door,
## WorldMapNpcLife._depart()): it leaves `source`, body and all, and comes onto the portal's
## map beside the portal's arrival marker, clear of whoever stands there. False when it
## could not (it stays where it was).
func move_npc_through(npc: NpcRuntimeState, source: WorldMapController, portal: PortalDefinition) -> bool:
	var destination: WorldMapController = world_map_of(portal.destination_map_id)
	var marker: WorldSpawnMarker2D = null if destination == null else destination.resolve_spawn_marker(portal.destination_spawn_point_id)
	var location: WorldLocationState = null if destination == null else destination.location_for_zone(portal.destination_zone_id)
	if marker == null or location == null or source == null or destination == source:
		return false
	var at: Vector2 = _clear_spot(destination, portal.destination_zone_id, marker.global_position)
	if not _move_npc(npc, source, destination, location, at):
		return false
	destination.npc_life.npc_arrived(npc)
	return true


## An NPC called over from a room on another map (ScriptedAct COMES): it leaves `source` and
## stands on `destination` (the active map) in `zone_id`, clear of the player there. False
## when it could not.
func bring_npc_onto(npc: NpcRuntimeState, source: WorldMapController, destination: WorldMapController, zone_id: StringName) -> bool:
	var location: WorldLocationState = destination.location_for_zone(zone_id)
	if location == null:
		return false
	var near: Vector2 = destination.runtime_player_body().global_position
	return _move_npc(npc, source, destination, location, _clear_spot(destination, zone_id, near))


## An NPC leaves `source` for `destination` (its record, body and all); when it cannot come
## there, it stays on `source` where it stood, as it was. False then.
func _move_npc(npc: NpcRuntimeState, source: WorldMapController, destination: WorldMapController, location: WorldLocationState, at: Vector2) -> bool:
	# Each map is caught up to now first: the NPC brings its own time along, no more.
	catch_up_map(source)
	catch_up_map(destination)
	var body: Node2D = source.runtime_body_for_character(npc.character_id)
	var was: WorldLocationState = npc.world_location()
	var stood: Vector2 = Vector2.INF if body == null else body.global_position
	if not stood.is_finite() or not source.npcs.release_follower(npc):
		return false
	if destination.npcs.admit_follower(npc, location, at):
		return true
	push_error("%s could not come onto %s; it stays on %s" % [npc.character_id, destination.map_id(), source.map_id()])
	if not source.npcs.admit_follower(npc, was, stood):
		push_error("%s could not stay on %s either" % [npc.character_id, source.map_id()])
	return false


## Where an NPC on its way out by a door (WorldMapNpcLife.departures) stands once through it:
## [location, position] on the portal's map, as move_npc_through() would put it; [] when it
## is not leaving, or its way shut meanwhile (a door closed across it: it stays, as
## finish_departures() would leave it). A save takes the move as made (the 往…离开 was told):
## Continue finds it there.
func departure_projection(npc: NpcRuntimeState, source: WorldMapController) -> Array:
	var departure: Dictionary = {} if source == null else source.npc_life.departures.get(npc.character_id, {})
	if departure.is_empty() or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting():
		return []
	var portal: PortalDefinition = departure["portal"]
	if not source.npc_life.departure_open(npc, portal):
		return []
	var destination: WorldMapController = world_map_of(portal.destination_map_id)
	var marker: WorldSpawnMarker2D = null if destination == null else destination.resolve_spawn_marker(portal.destination_spawn_point_id)
	var location: WorldLocationState = null if destination == null else destination.location_for_zone(portal.destination_zone_id)
	if marker == null or location == null:
		return []
	return [location, _clear_spot(destination, portal.destination_zone_id, marker.global_position)]


## room.c reset() calling home (return_home()) an NPC of `home`'s spawn point that went
## onto another map: it comes back to its marker from wherever it is, a dead one's record
## too (the reset makes it anew). Null when no map holds it.
func bring_npc_home(point_id: StringName, home: WorldMapController) -> NpcRuntimeState:
	# Whether it may leave is as it is now (awake, not fighting): its map caught up first,
	# which may move it (home too, where the reset finds it).
	var away: Array = _npc_away_from(point_id, home)
	if away.is_empty():
		return null
	catch_up_map(away[0])
	for npc: NpcRuntimeState in home.npc_runtimes():
		if npc.spawn_point_id == point_id:
			return npc
	away = _npc_away_from(point_id, home)
	if not away.is_empty():
		var map: WorldMapController = away[0]
		var npc: NpcRuntimeState = away[1]
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
		var marker: WorldSpawnMarker2D = home.resolve_spawn_marker(point_id)
		var location: WorldLocationState = null if spawn == null else home.location_for_zone(spawn.zone_id)
		if spawn == null or marker == null or location == null or spawn.map_id != home.map_id():
			return null
		var alive: bool = npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
		# A fighting or senseless one does not leave (npc.c return_home()); nor one that
		# follows the player every way (小娟), nor a summoned one.
		if alive and (npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting() or map.npc_life.follows_every_way(npc)):
			return null
		# A dead one is made anew at home, unless it is gone for good (it stays a record there).
		if not alive and not WorldMapNpcs.made_anew(spawn, npc):
			return null
		if not alive:
			return npc if map.npcs.release_follower(npc) else null
		var heard: bool = map.npc_life.player_hears(npc) and map.hud() != null
		if not _move_npc(npc, map, home, location, _clear_spot(home, spawn.zone_id, marker.global_position)):
			return null
		if heard:
			map.hud().append_log_lines([tr("%s急急忙忙地离开了。") % tr(npc.definition().display_name)])
		home.npc_life.npc_arrived(npc)
		return npc
	return null


## [map, NPC] of the NPC of `point_id` on a map other than `home`, or [].
func _npc_away_from(point_id: StringName, home: WorldMapController) -> Array:
	for map: WorldMapController in world_maps():
		if map == home:
			continue
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.spawn_point_id == point_id:
				return [map, npc]
	return []


## The first spot from two bodies inside `near` (an arrival marker, where the player too
## arrives) towards the zone's middle that a body may stand on clear of the other bodies;
## `near` itself when there is none.
static func _clear_spot(map: WorldMapController, zone_id: StringName, near: Vector2) -> Vector2:
	var zone: WorldPhysicalZoneArea2D = map.physical_zone(zone_id)
	if zone == null:
		return near
	var inward: Vector2 = (zone.global_rect().get_center() - near).normalized()
	var bodies: Array[Vector2] = [map.runtime_player_body().global_position]
	for npc: NpcRuntimeState in map.npc_runtimes():
		var body: Node2D = map.runtime_body_for_character(npc.character_id)
		if body != null and npc.exists_in_map:
			bodies.append(body.global_position)
	for step: int in range(0, 10):
		var spot: Vector2 = near + inward * (68.0 + 16.0 * step)
		if bodies.all(func(other: Vector2) -> bool: return other.distance_to(spot) >= 44.0) and MapPlacementValidator.is_valid_character_position(map, zone_id, spot):
			return spot
	return near


func _reconcile_active_residents() -> bool:
	if not _reconcile_relationship(_player.relationship):
		return false
	var map: WorldResidentMapController = active_map()
	if map == null:
		return false
	for npc: NpcRuntimeState in map.resident_npcs():
		if not _reconcile_relationship(npc.relationship):
			return false
	return true


func _reconcile_relationship(relationship: CombatRelationshipState) -> bool:
	if relationship == null or not relationship.is_valid():
		return false
	var facts: Array[CombatOpponentAvailabilityFacts] = []
	for opponent_id: StringName in relationship.opponent_ids():
		facts.append(_availability_facts(opponent_id, relationship.owner_character_id))
	var result: CombatOpponentSelectionResult = CombatOpponentSelectionService.prepare(
		relationship,
		facts,
		_combat_random,
	)
	return result.outcome not in [
		CombatOpponentSelectionResult.Outcome.INVALID_AVAILABILITY_PROJECTION,
		CombatOpponentSelectionResult.Outcome.CLEANUP_INVARIANT_FAILURE,
		CombatOpponentSelectionResult.Outcome.RANDOM_SOURCE_MISSING,
		CombatOpponentSelectionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE,
		CombatOpponentSelectionResult.Outcome.LAST_OPPONENT_INVARIANT_FAILURE,
	]


func _availability_facts(
	opponent_id: StringName,
	owner_id: StringName,
) -> CombatOpponentAvailabilityFacts:
	var opponent_location: WorldLocationState
	var opponent_exists: bool = false
	var opponent_living: bool = false
	if opponent_id == _player.character_id:
		opponent_location = _player.world_location()
		opponent_exists = _player.exists_in_world
		opponent_living = _player.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	else:
		var npc: NpcRuntimeState = _find_resident_npc(opponent_id)
		if npc != null:
			opponent_location = npc.world_location()
			opponent_exists = npc.exists_in_map
			opponent_living = npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	var owner_location: WorldLocationState = _location_for_character(owner_id)
	return CombatOpponentAvailabilityFacts.new(
		opponent_id,
		opponent_exists,
		owner_location != null
		and opponent_location != null
		and owner_location.shares_combat_location(opponent_location),
		opponent_living,
	)


func _location_for_character(character_id: StringName) -> WorldLocationState:
	if character_id == _player.character_id:
		return _player.world_location()
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return null if npc == null else npc.world_location()


## The NPC `character_id` on any resident map, or null.
func resident_npc(character_id: StringName) -> NpcRuntimeState:
	return _find_resident_npc(character_id)


func _find_resident_npc(character_id: StringName) -> NpcRuntimeState:
	for map: WorldResidentMapController in _resident_maps.values():
		var npc: NpcRuntimeState = map.find_resident_npc(character_id)
		if npc != null:
			return npc
	return null


## Portable interaction composition: the current Session and active body own the
## permission, never an inactive Outdoor controller or the displayed row.
func portable_inventory_available() -> bool:
	if not _initialized or not can_process() or not application_gameplay_allows_encounter_advance() or _restore_candidate_staged or _session_swap_suspended or _transitioning:
		return false
	var map: WorldResidentMapController = active_map()
	return map != null and map.is_inside_tree() and map.is_map_initialized() and map.runtime_player_body().player_controlled and _world_simulation_gate.is_open() and not _combat_encounter_coordinator.has_active_encounter() and _player.exists_in_world and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not _player.relationship.is_fighting()


func player_inventory_rows() -> Array[PlayerInventoryRowProjection]:
	return PlayerInventoryProjection.new().project_rows(_player, _inventory, _stacks, _item_index)


func wield_player_item(id: StringName) -> OldPineEquipmentInteractionResult:
	if not portable_inventory_available(): return OldPineEquipmentInteractionResult.new()
	_last_portable_equipment = OldPineEquipmentInteractionAdapter.new().wield(_player, id, _inventory, _item_index)
	return _last_portable_equipment


func unwield_player_item(id: StringName) -> OldPineEquipmentInteractionResult:
	if not portable_inventory_available(): return OldPineEquipmentInteractionResult.new()
	_last_portable_equipment = OldPineEquipmentInteractionAdapter.new().unwield(_player, id, _inventory)
	return _last_portable_equipment


func wear_player_item(id: StringName) -> OldPineArmorInteractionResult:
	if not portable_inventory_available(): return OldPineArmorInteractionResult.new()
	_last_portable_armor = OldPineArmorInteractionAdapter.new().wear(_player, id, _inventory, _item_index)
	return _last_portable_armor


func remove_player_item(id: StringName) -> OldPineArmorInteractionResult:
	if not portable_inventory_available(): return OldPineArmorInteractionResult.new()
	_last_portable_armor = OldPineArmorInteractionAdapter.new().remove(_player, id, _inventory, _item_index)
	return _last_portable_armor


var _last_portable_equipment: OldPineEquipmentInteractionResult
var _last_portable_armor: OldPineArmorInteractionResult
var _martial_arts: PlayerMartialArts
var _progression_rewards: WorldProgressionRewards
var _bounties: WorldBounties


## The 雪亭驿 board's bounties (A2).
func bounties() -> WorldBounties:
	if _bounties == null:
		_bounties = WorldBounties.new(self)
	return _bounties


## The one-time 历练 rewards and the player's catch-up (A2).
func progression_rewards() -> WorldProgressionRewards:
	if _progression_rewards == null:
		_progression_rewards = WorldProgressionRewards.new(self)
	return _progression_rewards
var _essence_magic: PlayerEssenceMagic


## The player's enable, practice, exercise, self-learning and study (the 武学 page).
func martial_arts() -> PlayerMartialArts:
	if _martial_arts == null:
		_martial_arts = PlayerMartialArts.new(self)
	return _martial_arts


## The player's 神通 (空识 and 游识 on the 武学 page, 心识 on the HUD).
func essence_magic() -> PlayerEssenceMagic:
	if _essence_magic == null:
		_essence_magic = PlayerEssenceMagic.new(self)
	return _essence_magic


func last_equipment_interaction() -> OldPineEquipmentInteractionResult:
	return _last_portable_equipment


func last_armor_interaction() -> OldPineArmorInteractionResult:
	return _last_portable_armor


func player_life_flow() -> PlayerLifeFlow:
	return _life_flow


func last_revival_handoff() -> OldPineMapHandoffResult:
	return _last_revival_handoff


## The map reports a completed combat lifecycle of the player. Only the public
## world runs the ES2 unconscious/death flow; the technical fixture keeps its
## terminal defeat.
func on_player_lifecycle(lifecycle: CombatSliceLifecycleResult, has_killer: bool, location: WorldLocationState) -> void:
	if lifecycle == null or _player == null or _world_content_revision != WorldContentRevision.CURRENT_PUBLIC:
		return
	match lifecycle.outcome:
		CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE:
			_life_flow.begin_unconscious(
				UnconsciousReviveDelay.seconds(_player.state.attributes.constitution, _combat_random),
				GameContent.catalog().pacing().player_wake_seconds,
			)
		CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE:
			# The dead are out of the law's hands (a constable's catch, a court's).
			_player.led_by = &""
			_player.awaiting_sentence = false
			_forgive_debts()
			# A ghost leaves no corpse (chard.c make_corpse()): the card names none.
			var place: String = "" if _player.state.ghost else place_name(location)
			_life_flow.begin_death(PlayerDeathRules.die(_player.state, has_killer, GameContent.catalog().pacing()), place, lifecycle.corpse_item_instance_id)


## The dead owe nothing (默认, DECISIONS 玉螺湖村 B): a catch's marks (meloner.c's
## melon/catch_thief, NpcSettle) go from the player and from whoever caught them, so the one who
## killed them neither holds them nor asks for his money any more.
func _forgive_debts() -> void:
	for definition: NpcDefinition in GameContent.catalog().npcs():
		if definition.dealings().settle != null:
			_player.temp_marks.erase(definition.dealings().settle.temp)
	for resident: WorldResidentMapController in _resident_maps.values():
		var map: WorldMapController = resident as WorldMapController
		if map != null:
			map.debts.forgive()


## "老松岭 · 南坡林道" for a world location, in the shown language.
func place_name(location: WorldLocationState) -> String:
	if location == null:
		return ""
	var catalog: ContentCatalog = GameContent.catalog()
	var zone: ZoneDefinition = catalog.zone(location.zone_id)
	var map: MapDefinition = null if zone == null else catalog.map(zone.map_id)
	var region: RegionDefinition = null if map == null else catalog.region(map.region_id)
	if region == null:
		return ""
	return "%s · %s" % [tr(region.display_name), tr(zone.display_name)]


## 继续 on the death card: the ghost goes to 阴间 (now, or as soon as the world lets it).
func continue_after_death() -> void:
	if _life_flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and application_gameplay_allows_encounter_advance():
		_life_flow.continue_from_death()
		_handle_life_event(_life_flow.advance(0.0))


## A gargoyle's last line or the little shop's double (ScriptedAct reincarnate): the move to
## the temple is made after the acting map's beat (an NPC's call_out runs inside it). A living
## player there (游识) is moved too: reincarnate() and move() ask nothing of ghost.
func request_reincarnation() -> void:
	if _player != null:
		_reincarnation_due = true


## Whether a reincarnation or a ghost's way back to 阴间 waits for its move (Save waits too).
func reincarnation_pending() -> bool:
	return _reincarnation_due or _realm_return_due


## How many times the player came back to life in this session.
func reincarnations() -> int:
	return _reincarnations


## A save made while the player lay unconscious or dead (before this flow
## existed) continues where ES2 would: waking up, or the way back from death.
## Penalties are not applied again.
func _resume_restored_life_flow() -> void:
	if _player == null or _world_content_revision != WorldContentRevision.CURRENT_PUBLIC:
		return
	match _player.life_status:
		CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			_life_flow.begin_unconscious(
				UnconsciousReviveDelay.seconds(_player.state.attributes.constitution, _combat_random),
				GameContent.catalog().pacing().player_wake_seconds,
			)
		CharacterRuntimeLifeStatus.Value.DEAD:
			_player.state.ghost = true
			_life_flow.begin_death(PlayerDeathResult.new(), "")
		CharacterRuntimeLifeStatus.Value.ACTIVE:
			# logind.c: a ghost logs in at DEATH_ROOM (owner D7: the gargoyle's talk again). A
			# long road's count (a set_temp()) is left behind with the road.
			var map: WorldMapController = active_map() as WorldMapController
			if not _player.state.ghost or map == null:
				return
			map.clear_tries(_player.world_location().zone_id)
			if active_map_id() == DeathWorldDefinitions.MAP_ID:
				map.relocate_player(DeathWorldDefinitions.GATE_ZONE_ID, DeathWorldDefinitions.ARRIVAL_SPAWN_ID)
			else:
				_realm_return_due = true


func _advance_life_flow(delta: float) -> void:
	if not _life_flow.is_active() or _transitioning or _restore_candidate_staged or not application_gameplay_allows_encounter_advance():
		return
	_handle_life_event(_life_flow.advance(delta))


func _handle_life_event(event: PlayerLifeFlow.Event) -> void:
	match event:
		PlayerLifeFlow.Event.REVIVE_DUE:
			_revive_from_unconscious()
		PlayerLifeFlow.Event.ENTER_REALM_DUE:
			_enter_death_realm()


## feature/damage.c revive(): the player gets up where they fell. While a
## killer is still at them the encounter decides first.
func _revive_from_unconscious() -> void:
	if _player.life_status != CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
		_life_flow.finish()
		return
	if _combat_encounter_coordinator != null and _combat_encounter_coordinator.has_active_encounter():
		return
	_player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	var map: WorldResidentMapController = active_map()
	if map != null and map.runtime_player_body() != null:
		map.runtime_player_body().refresh_runtime_state()
	_life_flow.finish()


## /d/snow/temple (REVIVE_ROOM, and where dun.c sends its caster), on the temple's own map
## (SnowWorldDefinitions.temple_map_id()): on that map already, just the move; else a handoff
## there. Whether the player is there now.
func _move_player_to_temple() -> bool:
	return _move_player_to(SnowWorldDefinitions.temple_map_id(), SnowWorldDefinitions.TEMPLE_ZONE_ID, SnowWorldDefinitions.REVIVE_SPAWN_ID)


## ob->move(room) for the player: on the active map a move, else a handoff (its result in
## _last_temple_handoff). Whether the player is there now.
func _move_player_to(map_id: StringName, zone_id: StringName, spawn_id: StringName) -> bool:
	if active_map_id() == map_id:
		var map: WorldMapController = active_map() as WorldMapController
		return map != null and not _transitioning and map.relocate_player(zone_id, spawn_id)
	_last_temple_handoff = handoff_to(map_id, zone_id, zone_id, spawn_id)
	return _last_temple_handoff.succeeded()


## dun.c's me->move() after the fight let the player go: from the next frame on (the
## fight's result and the spell's lines are told first) the player is taken to the room
## the spell named, once the world is free; meanwhile no fight starts. A move refused for
## good (anything but a frozen or busy world) is dropped with an error. Only Snow's temple
## is such a room.
func advance_departure() -> void:
	var coordinator: CombatEncounterCoordinator = _combat_encounter_coordinator
	var room: StringName = &"" if coordinator == null else coordinator.pending_departure()
	if room.is_empty():
		_departure_due = false
		return
	if not _departure_due:
		_departure_due = true
		return
	if _transitioning or _restore_candidate_staged or coordinator.has_active_encounter() or not application_gameplay_allows_encounter_advance():
		return
	var on_snow: bool = active_map_id() == SnowWorldDefinitions.temple_map_id()
	if room == DunSpell.DESTINATION and _player != null and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
		if not _move_player_to_temple():
			if not on_snow and _last_temple_handoff.outcome in [OldPineMapHandoffResult.Outcome.WORLD_SIMULATION_FROZEN, OldPineMapHandoffResult.Outcome.SESSION_NOT_READY]:
				return
			push_error("遁 could not reach %s from %s" % [room, active_map_id()])
	elif room != DunSpell.DESTINATION:
		push_error("no way to %s" % room)
	coordinator.finish_departure()
	_departure_due = false


## feature/damage.c die(): the ghost (ghost = 1, PlayerDeathRules.die()) is moved to
## DEATH_ROOM (/d/death/gate), before the white gargoyle. If the move cannot happen now the
## player stays dead and it is tried again next frame, so the world never holds a living
## player without a body.
func _enter_death_realm() -> void:
	var previous_life: int = _player.life_status
	var previous_exists: bool = _player.exists_in_world
	_player.state.ghost = true
	_player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_player.set_exists_in_world(true)
	if not _move_player_to(DeathWorldDefinitions.MAP_ID, DeathWorldDefinitions.GATE_ZONE_ID, DeathWorldDefinitions.ARRIVAL_SPAWN_ID):
		_player.set_life_status(previous_life)
		_player.set_exists_in_world(previous_exists)
		return
	_life_flow.finish()
	_refresh_ghost_sight()


## d/death/npc/wgargoyle.c death_stage() and inn1.c do_stuff(): reincarnate() and the
## move to REVIVE_ROOM (/d/snow/temple). If the move cannot happen now the player stays
## a ghost and it is tried again next frame.
func _advance_reincarnation() -> void:
	if not _initialized or _transitioning or _restore_candidate_staged or not application_gameplay_allows_encounter_advance():
		return
	if _realm_return_due:
		if _player == null or not _player.state.ghost or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			_realm_return_due = false
		elif _move_player_to(DeathWorldDefinitions.MAP_ID, DeathWorldDefinitions.GATE_ZONE_ID, DeathWorldDefinitions.ARRIVAL_SPAWN_ID):
			_realm_return_due = false
		return
	if not _reincarnation_due:
		return
	# Dead again before the move (a fight in the meantime): the death goes on instead.
	if _player == null or _player.life_status == CharacterRuntimeLifeStatus.Value.DEAD or _life_flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE:
		_reincarnation_due = false
		return
	# Lying unconscious (a spell's cost): the move waits until they come to.
	if _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return
	var on_snow: bool = active_map_id() == SnowWorldDefinitions.temple_map_id()
	if not _move_player_to_temple():
		return
	if not on_snow:
		_last_revival_handoff = _last_temple_handoff
	_reincarnation_due = false
	PlayerDeathRules.reincarnate(_player.state)
	_reincarnations += 1
	_refresh_ghost_sight()


## How often (real seconds) the 任务 page's entries and the 百科's items are looked for.
const JOURNAL_INTERVAL: float = 0.5


## What happened is written down (JournalLog): the entries whose condition now holds and
## the items carried, every JOURNAL_INTERVAL, world time or not (the menu's actions count).
func advance_journal(delta: float) -> void:
	_journal_elapsed += delta
	if _journal_elapsed < JOURNAL_INTERVAL:
		return
	_journal_elapsed = 0.0
	record_journal()


## What the player carries, inside a carried container too (the 劲竹书 in its 书匣), by the
## item's own ID: a master, named, broken or eaten form counts as the item (the letter#master).
func player_held_item_ids() -> Dictionary[StringName, bool]:
	var held: Dictionary[StringName, bool] = {}
	if _player == null or _inventory == null or _item_index == null:
		return held
	var open: Array[ContainmentEndpoint] = [ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)]
	while not open.is_empty():
		for item_id: StringName in _inventory.direct_children(open.pop_back()):
			var item: ItemInstance = _item_index.resolve(item_id) if _inventory.is_registered(item_id) else null
			if item == null:
				continue
			var base := StringName(String(item.item_definition_id).get_slice("#", 0))
			if GameContent.catalog().item(base) != null:
				held[base] = true
			open.append(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, item_id))
	return held


## What the player wears (the armor on them), by the item's own ID (as player_held_item_ids();
## 逆灵宫 A: a journal `wearing` condition, an act's `wears`, an NPC's `ignores_when`).
func player_worn_item_ids() -> Dictionary[StringName, bool]:
	var worn: Dictionary[StringName, bool] = {}
	if _player == null or _player.armor == null:
		return worn
	for slot: StringName in _player.armor.occupied_slots():
		var reference: EquippedArmorRef = _player.armor.equipped_ref_in_slot(slot)
		if reference == null:
			continue
		var base := StringName(String(reference.item_definition_id).get_slice("#", 0))
		if GameContent.catalog().item(base) != null:
			worn[base] = true
	return worn


## Looks for the entries and items now (tests; advance_journal()).
func record_journal() -> void:
	if not _initialized or _player == null or _player.state == null or _inventory == null or _item_index == null:
		return
	var held: Dictionary[StringName, bool] = player_held_item_ids()
	var worn: Dictionary[StringName, bool] = player_worn_item_ids()
	JournalLog.note_items(_player.state, held)
	WorldSpawnClearings.note(self)
	var location: WorldLocationState = _player.world_location()
	var zone_id: StringName = &"" if location == null else location.zone_id
	var phase_id: StringName = day_phase_id()
	tell_journal(JournalLog.record_entries(_player.state, _player.temp_marks, held, GameContent.catalog().journal_chains(), zone_id, worn, phase_id))
	tell_quests(StoryQuestLog.record(_player.state, _player.temp_marks, held, zone_id, GameContent.catalog().story_quests(), worn, phase_id))
	progression_rewards().look()
	bounties().look()


## Entries just recorded (JournalLog; 前两小时 A, DECISIONS「新手链与当前目标」) are told once
## in 消息 and as a toast, a guide chain's with what to do next while 目标提示 is on.
func tell_journal(fresh: Array[JournalLog.Fresh]) -> void:
	var hud: SharedGameplayUI = shared_ui()
	if hud == null or fresh.is_empty():
		return
	var lines: Array[ColoredLine] = []
	for entry: JournalLog.Fresh in fresh:
		lines.append_array(JournalLog.told_lines(entry, ObjectiveHints.shown))
	hud.append_colored_lines(lines)


## The player heard `npc` say `text` (npc.c chat(), or chat_msg_combat in a fight): the 任务
## page's entries that wait for those words (JournalEntryDefinition CHAT; 前两小时 D).
func chat_heard(npc: NpcRuntimeState, text: String) -> void:
	if _player == null or _player.state == null or npc == null:
		return
	tell_journal(JournalLog.chat_heard(_player.state, npc.definition().definition_id, text, GameContent.catalog().journal_chains()))
	tell_quests(StoryQuestLog.chat_heard(_player.state, npc.definition().definition_id, text, GameContent.catalog().story_quests()))


## What the quests just recorded (StoryQuestLog; 任务系统, DECISIONS「任务系统」) is told once
## in 消息 and as a toast (a step done with what to do next while 目标提示 is on), and what
## it gives is given: the 历练 reward (WorldProgressionRewards.quest_done) and the deed
## (WorldDeeds.report), in the order recorded.
func tell_quests(fresh: Array[StoryQuestLog.Fresh]) -> void:
	if fresh.is_empty() or _player == null or _player.state == null:
		return
	var hud: SharedGameplayUI = shared_ui()
	for entry: StoryQuestLog.Fresh in fresh:
		if hud != null:
			hud.append_colored_lines(StoryQuestLog.told_lines(entry, ObjectiveHints.shown, _player.state))
		var reward: StoryQuestDefinition.Reward = entry.reward()
		if reward == null:
			continue
		if reward.milestone and entry.kind == StoryQuestLog.Kind.DONE:
			progression_rewards().quest_done(entry.quest)
		if not reward.deed.is_empty():
			deeds().report(reward.deed)


var _deeds: WorldDeeds


## Where the player's deeds are reported (任务系统).
func deeds() -> WorldDeeds:
	if _deeds == null:
		_deeds = WorldDeeds.new(self)
	return _deeds


## Native (前两小时 B; DECISIONS「开场卡片」): New Game begins with the theme story's card
## (OpeningDefinition) over the world, world time held, until 继续. Asked for by the host
## once (a save is never made under it, so it is not saved); the overlay takes it.
var _opening_card_due: bool = false


func request_opening_card() -> void:
	_opening_card_due = _bootstrap_mode == BootstrapMode.SOURCE_ENTRY and GameContent.catalog().opening() != null


func opening_card_due() -> bool:
	return _opening_card_due


func take_opening_card() -> void:
	_opening_card_due = false


## 阴阳眼 began or ended (in a fight, on the 武学 page, on world time, from a save): the
## ghosts are seen or not from this frame (char.c visible() asks each time).
func _sync_ghost_sight() -> void:
	var sees: bool = _player != null and _player.state != null and _player.state.sees_ghosts()
	if sees != _ghost_sight_shown:
		_refresh_ghost_sight()


## The player became a ghost or lives again: every map's ghosts are seen or not (char.c visible()).
func _refresh_ghost_sight() -> void:
	_ghost_sight_shown = _player != null and _player.state != null and _player.state.sees_ghosts()
	for resident: WorldResidentMapController in _resident_maps.values():
		var map: WorldMapController = resident as WorldMapController
		if map != null:
			map.npcs.refresh_ghost_sight()
