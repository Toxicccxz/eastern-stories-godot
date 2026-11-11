class_name CombatEncounterScheduler
extends RefCounted

const TIME_EPSILON_SECONDS: float = 0.000000001
## What an NPC's heart beat did before npc.c chat() runs in it: attack() (std/char.c).
## A busy beat (continue_action()) or a falling one says nothing.
const CHAT_AFTER: Array[int] = [
	CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_COMPLETE,
	CombatSliceOpportunityResult.Outcome.ENTERED_GUARDING,
	CombatSliceOpportunityResult.Outcome.FIGHT_NO_ACTION,
]
## What a beat went on when no move was struck (CombatRoundBeats.spent).
const SPENT_BUSY: StringName = &"busy"
## 战斗拍数 E: a beat whose blow felled someone (no 失衡 or 露空 noted on it).
const FELLED: Array[int] = [
	CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH,
	CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS,
]
const SPENT_WAIT: StringName = &"wait"


## A timed apply that ran out this round, and whose it was.
class EndedEffect:
	extends RefCounted
	var binding: CombatSliceCharacterBinding
	var entry: CharacterTimedApplies.Entry

	func _init(p_binding: CombatSliceCharacterBinding, p_entry: CharacterTimedApplies.Entry) -> void:
		binding = p_binding
		entry = p_entry


## What one beat of a fighter is going to be: its move taken without a draw (or none: the
## executor draws), fight()'s courage taken with it, whether it is the player's order, or a
## perform its school's line chose (perform/<id>).
class BeatPick:
	extends RefCounted
	var chosen: StringName = &""
	var courage: CombatPredrawnCourage = null
	var ordered: bool = false
	var perform: StringName = &""


var _encounter: CombatEncounter
var _config: CombatSchedulerConfig
var _accumulated_input_seconds: float = 0.0
var _logical_cycle: int = 0
var _next_event_sequence: int = 1
var _events: Array[CombatSchedulerEvent] = []
var _progression_order := CombatProgressionOrder.new()
var _tactical: CombatTacticalRuntime
var _target_events: Array[CombatOrderedTargetEvent] = []
## Falls and deaths the boundary saw (combatd.c announce()), in progression order.
var _announcements: Array[CombatLifecycleAnnouncement] = []
var _npc_chat: CombatNpcChat
## 战斗决策层 1B (DECISIONS「战斗决策」).
var _decisions: CombatDecisionRules = CombatDecisionRules.classic()
var _player_id: StringName = &""
## The round's standing modifiers (stance, a 守 move, the move tags held), filled each cycle.
var _modifiers: CombatRoundModifiers = CombatRoundModifiers.new()
## Under player_turns: the player's order opened this round; it closes once a cycle ran.
var _round_open: bool = false
## The move the player chose for this round (taken without a draw), and its tag.
var _player_choice: StringName = &""
var _player_choice_tag: StringName = &""
## 战斗拍数 A (DECISIONS「战斗拍数」): the beats of a round (CombatBeatRules), an NPC's own
## beats a round (`beats_for`: character_id -> int), each NPC's plan for its next round
## (npc_telegraph; the first beat settled, the rest its read), each fighter's beats in the
## round running, what each fighter's school skeleton reads of the fight, and the tag of
## each fighter's last move this round (the ring between beats).
var _beat_rules: CombatBeatRules = CombatBeatRules.classic()
var _beats_for: Callable
var _plans: Dictionary[StringName, CombatNpcBeatPlan] = {}
var _round_beats: Dictionary[StringName, CombatRoundBeats] = {}
var _skeleton_states: Dictionary[StringName, CombatSkeletonState] = {}
var _round_tags: Dictionary[StringName, StringName] = {}
## The events of the advance running (the round's notes go here too).
var _emitted: Array[CombatSchedulerEvent] = []
## 战斗拍数 B (DECISIONS「战斗拍数」): the round running now — its fighters in order, the
## cursor on the one whose beat comes next, whether a beat was taken this pass (a pass
## without one ends the round), whether a round runs at all (between rounds: false). Under
## player_turns the player's beat waits for their order (point one, resolve one): advance()
## returns WAITING_FOR_PLAYER mid-round and resumes on the next order. The beats the
## player's orders cost before the round began (a perform queued between rounds, a stance
## changed) are charged when it begins ([key, cost] each); 收势 asked between rounds gives
## up the whole round once it begins.
enum RoundStep { DONE, WAITING, ENDED }
var _round_running: bool = false
var _round_order: Array[StringName] = []
var _round_cursor: int = 0
var _round_progress: bool = false
var _pending_costs: Array = []
var _yield_pending: bool = false
## 战斗拍数 C (DECISIONS「战斗拍数 C」): the beats an NPC's chat() special cost it after its
## round's beats were spent (character_id -> [[key, cost]]), charged to its next round.
var _npc_pending_costs: Dictionary[StringName, Array] = {}
## The special an NPC announced (npc_telegraph), to run on its next beat, and its label.
var _pending_specials: Dictionary[StringName, NpcSpecialAction] = {}
var _pending_labels: Dictionary[StringName, String] = {}
## Whom the player's feint or perform struck this round: their pending special is off.
var _interrupted: Dictionary[StringName, bool] = {}
## 战斗决策层 4 (DECISIONS「战斗内容」): (character_id) -> CombatStyle, the NPC's fight style or
## null; the cycle from which an NPC may use a special again (its rest after one).
var _style_for: Callable
var _special_ready: Dictionary[StringName, int] = {}
## 战斗拍数 D (DECISIONS「战斗拍数 D」): the rounds completed (a lesson ends on its count); the
## guide's line as each round begins (configure_lesson: round index -> String); the beats each
## fighter won this fight; what the player learns watching (configure_insights: an NPC's beat
## number spent on a tag, the NPC whose move drew the player's blood).
var _rounds_completed: int = 0
var _lesson_guide_id: StringName = &""
var _lesson_lines: Callable = Callable()
var _earned_counts: Dictionary[StringName, int] = {}
var _note_habit: Callable = Callable()
var _note_wound: Callable = Callable()
## 战斗拍数 E (DECISIONS「战斗拍数 E · 重招」): who stands open after a 重 of theirs was dodged
## or parried (露空), until the next blow at them.
var _exposed: Dictionary[StringName, bool] = {}
## Who owes a beat to 失衡 still (until their busy beat is paid, or the fight ends).
var _staggered: Dictionary[StringName, bool] = {}
## Who was said to strike twice while the player recovered from a 重 this round (said once).
var _combo_told: Dictionary[StringName, bool] = {}
## The beats each NPC took since the player's 重 this round (-1 at: no 重 yet this round).
var _heavy_spent_at: int = -1
var _npc_beats_after_heavy: Dictionary[StringName, int] = {}

var logical_cycle: int:
	get: return _logical_cycle
var logical_time_seconds: float:
	get:
		return (
			0.0
			if _config == null
			else float(_logical_cycle) * _config.opportunity_interval_seconds
		)
var remainder_seconds: float:
	get:
		if _config == null:
			return 0.0
		return maxf(
			0.0,
			_accumulated_input_seconds - logical_time_seconds,
		)


func _init(
	p_encounter: CombatEncounter = null,
	p_config: CombatSchedulerConfig = null,
) -> void:
	_encounter = p_encounter
	_config = p_config
	# 战斗拍数 D: a lesson's blows land but draw no blood (CombatRoundModifiers.harmless).
	_modifiers.harmless = p_encounter != null and p_encounter.mode == CombatEncounterMode.Value.LESSON


## Configured once before the first advance. Default registry is deliberately empty.
func configure_player_tactics(player_id: StringName, registry: CombatTacticalActionRegistry) -> bool:
	if _tactical != null or _accumulated_input_seconds != 0.0 or registry == null:
		return false
	if _encounter == null or _encounter.participant_for(player_id) == null:
		return false
	_tactical = CombatTacticalRuntime.new(_encounter, player_id, registry, _progression_order)
	_tactical.set_cooldown_rounds(_decisions.perform_cooldown_rounds)
	_tactical.modifiers = _modifiers
	_player_id = player_id
	return true


## The decision layer's knobs, configured once before the first advance.
func configure_decisions(rules: CombatDecisionRules) -> bool:
	if rules == null or _accumulated_input_seconds != 0.0:
		return false
	_decisions = rules.duplicate_snapshot()
	if _tactical != null:
		_tactical.set_cooldown_rounds(_decisions.perform_cooldown_rounds)
	if _npc_chat != null:
		_npc_chat.telegraph = _decisions.npc_telegraph
	return true


func decisions() -> CombatDecisionRules:
	return _decisions


## The beats of a round (CombatBeatRules) and each NPC's own beats (`beats_for`:
## character_id -> int; 1 when it says nothing), configured once before the first advance.
func configure_beats(rules: CombatBeatRules, beats_for: Callable = Callable()) -> bool:
	if rules == null or not rules.is_valid() or _accumulated_input_seconds != 0.0:
		return false
	_beat_rules = rules.duplicate_snapshot()
	_beats_for = beats_for
	return true


func beat_rules() -> CombatBeatRules:
	return _beat_rules


## 战斗拍数 D: the guide `guide_id` says `lines_for_round.call(index)` (0 the first round; ""
## says nothing) as each round begins, as its own line in the record. Configured once.
func configure_lesson(guide_id: StringName, lines_for_round: Callable) -> bool:
	if _accumulated_input_seconds != 0.0 or _rounds_completed > 0:
		return false
	_lesson_guide_id = guide_id
	_lesson_lines = lines_for_round
	return true


## 战斗拍数 D: what the player learns watching — `habit.call(npc_id, beat_number, tag)` for each
## beat an NPC took (1 its first of the round; perform for a special), `wounded.call(npc_id)`
## when an NPC's blow drew the player's blood. Configured once; read only under 识招.
func configure_insights(habit: Callable, wounded: Callable) -> bool:
	if _accumulated_input_seconds != 0.0:
		return false
	_note_habit = habit
	_note_wound = wounded
	return true


## The rounds that ran to their end (or ended the fight) so far.
func rounds_completed() -> int:
	return _rounds_completed


## The beats `actor_id` won by its school this fight.
func earned_count(actor_id: StringName) -> int:
	return _earned_counts.get(actor_id, 0)


## The NPCs' fight styles (CombatStyleTable.style_of() behind `style_for`), configured once.
func configure_styles(style_for: Callable) -> bool:
	if _accumulated_input_seconds != 0.0:
		return false
	_style_for = style_for
	return true


func _style_of(actor: CombatSliceCharacterBinding) -> CombatStyle:
	if actor == null or actor.is_user or not _decisions.uses_styles() or not _style_for.is_valid():
		return null
	return _style_for.call(actor.character_id) as CombatStyle


## status_msg()'s percent: kee x 100 / max_kee.
static func _kee_percent(actor: CombatSliceCharacterBinding) -> int:
	var maximum: int = actor.state.vitality.maximum
	@warning_ignore("integer_division")
	return 100 if maximum <= 0 else actor.state.vitality.current * 100 / maximum


## Whether `actor` may announce or run a special now: not resting, and its style has them.
func _can_special(actor: CombatSliceCharacterBinding) -> bool:
	if _logical_cycle < _special_ready.get(actor.character_id, 0):
		return false
	var style: CombatStyle = _style_of(actor)
	return style == null or style.specials


## The special of `actor` ran this cycle: it rests the knob's rounds, or its style's.
func _rest_special(actor: CombatSliceCharacterBinding) -> void:
	var style: CombatStyle = _style_of(actor)
	var rounds: int = _decisions.npc_special_cooldown_rounds if style == null else style.cooldown_at(_kee_percent(actor), _decisions.npc_special_cooldown_rounds)
	if rounds > 0:
		_special_ready[actor.character_id] = _logical_cycle + rounds + 1


## The fight waits for the player's order each round: pacing player_turns, the 自动
## switch off, and a player who can act (not busy, conscious, someone to fight, nothing
## queued); an open round runs to its end first.
func waiting_for_player(bindings: Array[CombatSliceCharacterBinding]) -> bool:
	if not manual() or _tactical == null or _encounter.queued_player_action() != null:
		return false
	# 战斗拍数 B: a round waiting mid-way on the player's next beat.
	if _round_running and not _one_beat():
		return _round_cursor < _round_order.size() and _player_beat_waits(_round_order[_round_cursor], bindings)
	if _round_open:
		return false
	return _player_can_act(bindings)


## Whether the player could act on a beat now: in the fight, conscious, not busy, with
## someone to fight.
func _player_can_act(bindings: Array[CombatSliceCharacterBinding]) -> bool:
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, _player_id)
	if (
		actor == null or not actor.exists_in_encounter or not actor.combat_available
		or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or actor.busy.is_busy()
		or not actor.relationship.is_fighting()
	):
		return false
	var target_id: StringName = _encounter.current_target_for(actor.character_id)
	if target_id.is_empty() or not _target_is_currently_eligible(actor, target_id, bindings):
		target_id = _first_initial_target(actor, bindings)
	return not target_id.is_empty()


## 战斗拍数 B: whether the beat of `actor_id` coming up is the player's and waits for their
## order — player_turns on, no order given, beats left, and the player able to act (one
## busy pays the beat; one down or without a target forfeits it; an order queued runs at
## the boundary first). Never in ES2's one-beat round.
func _player_beat_waits(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> bool:
	if _one_beat() or not manual() or actor_id != _player_id or not _player_choice.is_empty():
		return false
	if _encounter.queued_player_action() != null or not _beats_of(_player_id, bindings).has_beats():
		return false
	return _player_can_act(bindings)


## Whether a round is running (mid-way, waiting on the player or on its next advance).
func round_running() -> bool:
	return _round_running


func manual() -> bool:
	return _decisions.player_turns and BattlePace.manual_turns and _tactical != null


## The player's order: the round runs (one cycle) and the clock waits again after it.
func open_round() -> void:
	if _round_open:
		return
	_round_open = true
	# A round is a whole cycle from the order: the remainder of the last one is dropped.
	_accumulated_input_seconds = logical_time_seconds


## The moves the player may choose from now (their action set, as reset_action() has it),
## locked ones included (the buttons never reorder; locked_move_reason() says which).
func player_moves(bindings: Array[CombatSliceCharacterBinding]) -> Array[CombatActionDefinition]:
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, _player_id)
	if actor == null or not actor.is_valid():
		return []
	var input: CombatActionSelectionInput = CombatSliceProjectionBuilder.build_action_selection_input(actor)
	var set: CombatActionSet = null if input == null else input.current_action_set()
	return [] if set == null or not set.is_valid() else set.actions()


## The player chose `action_id` for their next beat: it is taken without a draw, and the
## round runs (or resumes, 战斗拍数 B: one order is one beat). False when it is not one of
## their moves now, their school locks it, or it costs more beats than they have (手不够).
func choose_attack(action_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> bool:
	if not locked_move_reason(action_id, bindings).is_empty() or not unaffordable_move_reason(action_id, bindings).is_empty():
		return false
	for action: CombatActionDefinition in player_moves(bindings):
		if action.action_id == action_id:
			_player_choice = action_id
			_player_choice_tag = action.tag
			if not _round_running:
				open_round()
			return true
	return false


func player_choice() -> StringName:
	return _player_choice


## 战斗拍数 B: 收势 — the player gives up the beats left this round (a beat won later still
## comes to them: 封山's wait for 隙). Mid-round the round goes on from the enemies' beats;
## between rounds the round begins without the player's beats. False when there is nothing
## to give up (ES2's one beat, 自动, not the player's turn).
func yield_round(bindings: Array[CombatSliceCharacterBinding]) -> bool:
	if _one_beat() or not manual() or _tactical == null:
		return false
	if _round_running:
		if not waiting_for_player(bindings):
			return false
		_beats_of(_player_id, bindings).yield_rest()
		return true
	if _round_open or not _player_can_act(bindings):
		return false
	_yield_pending = true
	open_round()
	return true


## 战斗拍数 B: the beats the player's round holds now — the round running (what is left,
## what each beat went on, what was won), else the round to come (base beats less what
## the orders given between rounds cost). An NPC's: its beats in the round running, else
## its own base beats. ES2's one beat: the round that last ran (null before the first).
func beats_now(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> CombatRoundBeats:
	if _one_beat():
		return _round_beats.get(actor_id)
	if _round_running:
		return _beats_of(actor_id, bindings)
	var preview := CombatRoundBeats.new(actor_id, _base_beats(_find_binding(bindings, actor_id)))
	if actor_id == _player_id:
		for cost: Array in _pending_costs:
			preview.spend(cost[0], cost[1])
		if _yield_pending:
			preview.yield_rest()
	return preview


## 战斗拍数 B: why the player cannot afford `action_id` on their next beat (手不够), "" when
## they can (or the round is ES2's one beat, where every move costs it).
func unaffordable_move_reason(action_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> String:
	if _one_beat() or _player_id.is_empty():
		return ""
	for action: CombatActionDefinition in player_moves(bindings):
		if action.action_id == action_id:
			return _unaffordable(_beat_rules.cost_of_tag(action.tag), bindings)
	return ""


## The player's moves they cannot afford now, by ID, with why.
func unaffordable_moves(bindings: Array[CombatSliceCharacterBinding]) -> Dictionary[StringName, String]:
	var short: Dictionary[StringName, String] = {}
	for action: CombatActionDefinition in player_moves(bindings):
		var reason: String = unaffordable_move_reason(action.action_id, bindings)
		if not reason.is_empty():
			short[action.action_id] = reason
	return short


## Why the player cannot afford an action costing `key` (perform/<id>, exert, item, flee;
## &"": nothing to pay) on their next beat, "" when they can.
func unaffordable_action_reason(key: StringName, bindings: Array[CombatSliceCharacterBinding]) -> String:
	if _one_beat() or _player_id.is_empty() or key.is_empty():
		return ""
	return _unaffordable(_beat_rules.cost_of_action(key), bindings)


func _unaffordable(cost: int, bindings: Array[CombatSliceCharacterBinding]) -> String:
	var beats: CombatRoundBeats = beats_now(_player_id, bindings)
	if beats == null or beats.can_afford(cost):
		return ""
	if beats.remaining == 0 and beats.yielded > 0:
		# TRANSLATORS: a battle button greyed because the player gave the round's beats up (收势).
		return TranslationServer.translate("已收势")
	# TRANSLATORS: a battle button greyed because the move or action costs more beats than the player has left this round.
	return TranslationServer.translate("手不够")


## 战斗拍数 B: the player's order outside the moves — a perform, exert, item or flight run
## at the boundary, a stance changed — costs its beats (CombatBeatRules.beat_costs): off
## the round running, else off the round to come. ES2's one beat: nothing (a command).
func _charge_player(key: StringName, cost: int, bindings: Array[CombatSliceCharacterBinding]) -> void:
	if _one_beat() or _player_id.is_empty() or key.is_empty() or cost <= 0:
		return
	if _round_running:
		_beats_of(_player_id, bindings).spend(key, cost)
	else:
		_pending_costs.append([key, cost])


## The player changed their stance (CombatStance): a beat (beat_costs `stance`).
func note_stance_change(bindings: Array[CombatSliceCharacterBinding]) -> void:
	_charge_player(CombatBeatRules.COST_STANCE, _beat_rules.cost_of_action(CombatBeatRules.COST_STANCE), bindings)


## 战斗拍数 C (DECISIONS「战斗拍数 C」): a perform's own busy (counterattack.c's 1, fakefault.c's
## failed 1, swordjab.c's none) counts into the beats it cost: the beats paid count the busy
## down first, so a perform loses max(its cost, its busy) beats, never the sum; a busy
## longer than the cost keeps its rest, confiscated beat by beat as before. ES2's one beat
## a round, or busy by rounds: untouched.
func _absorb_special_busy(actor: CombatSliceCharacterBinding, cost: int) -> void:
	if _one_beat() or not _beat_rules.busy_in_beats or actor == null:
		return
	for _beat: int in cost:
		if actor.busy.busy_value <= 0:
			return
		actor.busy.advance()


## 战斗拍数 C: an NPC's chat() special (npc.c perform_action / cast_spell / exert_function,
## a command in ES2) costs its beats as the player's orders do, the same rule for both: off
## the round running while it has beats left, else off its next round (no debt beyond
## that); a perform's own busy counts into them. ES2's one beat a round: nothing.
func _charge_npc_special(actor: CombatSliceCharacterBinding, action: NpcSpecialAction) -> void:
	if _one_beat() or actor == null or action == null:
		return
	var key: StringName = npc_special_key(action)
	if key.is_empty():
		return
	var cost: int = _beat_rules.cost_of_action(key)
	var beats: CombatRoundBeats = _round_beats.get(actor.character_id) if _round_running else null
	if beats != null and beats.has_beats():
		beats.spend(key, cost)
	else:
		if not _npc_pending_costs.has(actor.character_id):
			_npc_pending_costs[actor.character_id] = []
		_npc_pending_costs[actor.character_id].append([key, cost])
	if action.kind == NpcSpecialAction.Kind.PERFORM:
		_absorb_special_busy(actor, cost)


## The key an NPC's chat() special is charged under: perform/<id>, cast, exert; &"" for a
## surrender (no beat).
static func npc_special_key(action: NpcSpecialAction) -> StringName:
	match action.kind:
		NpcSpecialAction.Kind.PERFORM:
			return CombatBeatRules.perform_key(action.function_id)
		NpcSpecialAction.Kind.CAST:
			return CombatBeatRules.COST_CAST
		NpcSpecialAction.Kind.EXERT:
			return CombatBeatRules.COST_EXERT
	return &""


## 战斗拍数 C: whether `actor_id`'s school reads it as close to its target now (柳家拳's
## `state: close`; the voxel figures stand nearer), false for a school without the state.
func skeleton_close(actor_id: StringName) -> bool:
	var state: CombatSkeletonState = _skeleton_states.get(actor_id)
	return state != null and state.close


## The key an order of `category` (CombatTacticalRequest.Category) with `action_id` is
## charged under: perform/<id>, exert, cast, item, flee; &"" for 投降, 攻击 and a settle
## (no beat).
static func cost_key_of(category: int, action_id: StringName) -> StringName:
	match category:
		CombatTacticalRequest.Category.MARTIAL_SPECIAL:
			return CombatBeatRules.perform_key(CombatPerformTacticalPolicy.function_for(action_id))
		CombatTacticalRequest.Category.INTERNAL_FORCE:
			return CombatBeatRules.COST_EXERT
		CombatTacticalRequest.Category.SPELL:
			return CombatBeatRules.COST_CAST
		CombatTacticalRequest.Category.ITEM:
			return CombatBeatRules.COST_ITEM
		CombatTacticalRequest.Category.FLEE:
			return CombatBeatRules.COST_FLEE
	return &""


## 战斗拍数 A: why the player's school locks `action_id` now (够不着), "" when it may be chosen.
## ES2's one-beat round never locks.
func locked_move_reason(action_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> String:
	if _one_beat() or _player_id.is_empty():
		return ""
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, _player_id)
	var skeleton: CombatSchoolSkeleton = _skeleton_of(actor)
	return "" if skeleton == null else skeleton.lock_reason(action_id, _skeleton_state(_player_id))


## The player's locked moves now, by ID, with why.
func locked_moves(bindings: Array[CombatSliceCharacterBinding]) -> Dictionary[StringName, String]:
	var locked: Dictionary[StringName, String] = {}
	for action: CombatActionDefinition in player_moves(bindings):
		var reason: String = locked_move_reason(action.action_id, bindings)
		if not reason.is_empty():
			locked[action.action_id] = reason
	return locked


## The tag of the move an NPC will use on its beat `beat` of the next round (npc_telegraph),
## &"" when none is drawn yet (or that beat is a perform).
func next_move_tag(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding], beat: int = 0) -> StringName:
	var action: CombatActionDefinition = next_move(actor_id, bindings, beat)
	return &"" if action == null else action.tag


## The move an NPC will use on its beat `beat` (npc_telegraph), null when none is drawn yet
## or that beat is a perform (beat_plan() has it).
func next_move(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding], beat: int = 0) -> CombatActionDefinition:
	var plan: CombatNpcBeatPlan = _plans.get(actor_id)
	var entry: CombatNpcBeatPlan.Entry = null if plan == null else plan.entry(beat)
	if entry == null or entry.is_perform():
		return null
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, actor_id)
	if actor == null:
		return null
	var input: CombatActionSelectionInput = CombatSliceProjectionBuilder.build_action_selection_input(actor)
	var set: CombatActionSet = null if input == null else input.current_action_set()
	if set == null:
		return null
	for action: CombatActionDefinition in set.actions():
		if action.action_id == entry.action:
			return action
	return null


## An NPC's plan for its next round (npc_telegraph): the first beat settled, the rest its
## read; null when none is drawn yet.
func beat_plan(actor_id: StringName) -> CombatNpcBeatPlan:
	return _plans.get(actor_id)


## A fighter's beats in the round that last ran (or is running): null before the first.
func round_beats_of(actor_id: StringName) -> CombatRoundBeats:
	return _round_beats.get(actor_id)


## Whether the NPC's courage draw, taken with its next move, fails fight()'s gate: it will
## guard instead (and riposte on a miss), 「起手：守势」. False when none was taken.
func next_move_guards(actor_id: StringName) -> bool:
	var plan: CombatNpcBeatPlan = _plans.get(actor_id)
	var entry: CombatNpcBeatPlan.Entry = null if plan == null else plan.first()
	return entry != null and entry.courage != null and not entry.courage.attacks()


## The special an NPC announced for its next beat (its chat()'s, 蓄势), "" when none.
func pending_special_label(actor_id: StringName) -> String:
	return _pending_labels.get(actor_id, "")


## 战斗拍数 A: the perform an NPC's school line planned as its first beat (封山弟子's 「封」),
## "" when none; the card shows it as 要出 too.
func planned_perform_label(actor_id: StringName) -> String:
	var plan: CombatNpcBeatPlan = _plans.get(actor_id)
	var entry: CombatNpcBeatPlan.Entry = null if plan == null else plan.first()
	if entry == null or not entry.is_perform():
		return ""
	var perform: PerformFunction = SpecialFunctions.perform(CombatBeatRules.perform_of(entry.action))
	return "" if perform == null else TranslationServer.translate(perform.label)


## The round's standing modifiers: the player's stance and chosen move, the NPCs' drawn
## moves (a 守 move guards its user this round; the counter ring reads the tags). Between
## beats a fighter holds its next planned move, else the one it last used this round.
func _fill_modifiers(bindings: Array[CombatSliceCharacterBinding]) -> void:
	_modifiers.clear()
	var bonus: int = GameContent.catalog().pacing().combat_rules().action_tag_bonus_percent
	if not _player_id.is_empty():
		var mine: CombatRoundModifiers.Fighter = _modifiers.side(_player_id)
		if _decisions.has_stances():
			CombatStance.apply(mine, BattlePace.stance, _decisions.stance_percent)
		mine.move_tag = _player_choice_tag if not _player_choice_tag.is_empty() else _round_tags.get(_player_id, &"")
		if mine.move_tag == CombatMoveTags.GUARD:
			mine.add(0, 0, bonus, bonus)
	for binding: CombatSliceCharacterBinding in bindings:
		if binding == null or binding.is_user or binding.character_id == _player_id:
			continue
		var actor_id: StringName = binding.character_id
		# One who will guard holds no move this round (the ring reads nothing of it).
		if next_move_guards(actor_id):
			continue
		var tag: StringName = &""
		var plan: CombatNpcBeatPlan = _plans.get(actor_id)
		if plan != null and not plan.is_empty():
			tag = plan.first().tag
		else:
			tag = _round_tags.get(actor_id, &"")
		if tag.is_empty():
			continue
		var theirs: CombatRoundModifiers.Fighter = _modifiers.side(actor_id)
		theirs.move_tag = tag
		if tag == CombatMoveTags.GUARD:
			theirs.add(0, 0, bonus, bonus)
	# 战斗拍数 E: one standing open (露空) dodges and parries the next blow worse.
	for open_id: StringName in _exposed:
		_modifiers.side(open_id).add(0, 0, -_beat_rules.exposed_percent, -_beat_rules.exposed_percent)


## 战斗拍数 E: a beat `actor_id` took at one standing open (its target) used the opening up,
## whatever it was (a blow, a special's several, nothing that landed).
func _use_opening(actor_id: StringName) -> void:
	var target: StringName = _encounter.current_target_for(actor_id)
	if target != actor_id and _exposed.has(target):
		_exposed.erase(target)


## 战斗拍数 E: the fight is over — a 失衡 still owed is dropped (the beat it took belonged to
## the fight; out of it nobody stands reeling).
func release_stagger(participants: Array[CombatParticipant]) -> void:
	for participant: CombatParticipant in participants:
		if not _staggered.has(participant.participant_id) or participant.binding == null or participant.binding.busy == null:
			continue
		var busy: ActionBusyState = participant.binding.busy
		for _beat: int in _beat_rules.stagger_beats:
			if busy.busy_value > 0:
				busy.advance()
	_staggered.clear()


## 战斗拍数 E: whether `actor_id` stands open after a 重 of theirs missed (露空).
func exposed(actor_id: StringName) -> bool:
	return _exposed.has(actor_id)


## Whether the round is ES2's one beat (round_beats 1, not interleaved): then every draw and
## order is the one before 战斗拍数, bit for bit, and no school skeleton is read.
func _one_beat() -> bool:
	return _beat_rules.round_beats <= 1 and not _beat_rules.interleaved


## The beats `actor` starts a round with: the player's round_beats; an NPC's own `beats`
## (1 when none) once the round has more than one beat.
func _base_beats(actor: CombatSliceCharacterBinding) -> int:
	if actor == null:
		return 0
	if actor.is_user or actor.character_id == _player_id or _one_beat():
		return _beat_rules.round_beats
	var own: int = 1
	if _beats_for.is_valid():
		own = int(_beats_for.call(actor.character_id))
	return maxi(1, own)


## 战斗拍数 B: the skeleton of the school `actor_id` fights with now, for the card's 打法词.
func school_skeleton(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> CombatSchoolSkeleton:
	return _skeleton_of(_find_binding(bindings, actor_id))


## The skeleton of the school `actor` fights with now (the skill mapped to its attack's use),
## null when it has none or the round is ES2's one beat.
func _skeleton_of(actor: CombatSliceCharacterBinding) -> CombatSchoolSkeleton:
	if actor == null or _one_beat() or not actor.is_valid():
		return null
	var primary: EquippedWeaponRef = actor.state.equipment.primary_weapon()
	var use_id: StringName = primary.skill_type if primary != null else CombatSliceProjectionBuilder.UNARMED_SKILL_ID
	var mapped: StringName = actor.state.skills.mapped_skill(use_id)
	if mapped.is_empty():
		return null
	var skill: SkillDefinition = GameContent.catalog().skill(mapped)
	return null if skill == null else skill.skeleton


func _skeleton_state(actor_id: StringName) -> CombatSkeletonState:
	if not _skeleton_states.has(actor_id):
		_skeleton_states[actor_id] = CombatSkeletonState.new()
	return _skeleton_states[actor_id]


## The use (sword, unarmed) through which `actor` reaches `skill_id`'s performs.
func _perform_use(actor: CombatSliceCharacterBinding, skill_id: StringName) -> StringName:
	var skill: SkillDefinition = GameContent.catalog().skill(skill_id)
	if skill == null:
		return &""
	for use_id: StringName in skill.valid_enabled_uses():
		if actor.state.skills.mapped_skill(use_id) == skill_id:
			return use_id
	return &""


## npc_telegraph: the NPC's plan for its next round drawn now, one beat early, so its first
## beat can be shown (its tag) and the rest read; each beat's move is taken without a draw
## when it comes (CombatActionSelector). The fight style weighs each draw
## (CombatStyle.tag_weights); fight()'s courage draw against its target comes with each
## (CombatPredrawnCourage), so the card can say it will guard. With one beat a round this
## is the one draw of 战斗决策层 1B.
func _draw_plan(actor: CombatSliceCharacterBinding, random_source: CombatRandomSource, bindings: Array[CombatSliceCharacterBinding] = []) -> void:
	_plans.erase(actor.character_id)
	if not _decisions.npc_telegraph or actor.is_user or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or not actor.relationship.is_fighting():
		return
	var plan := CombatNpcBeatPlan.new(actor.character_id)
	var budget: int = _base_beats(actor)
	var first: bool = true
	while budget > 0:
		var entry: CombatNpcBeatPlan.Entry = _draw_entry(actor, random_source, bindings, budget, first)
		if entry == null:
			break
		plan.append(entry)
		budget -= maxi(1, entry.cost)
		first = false
	if not plan.is_empty():
		_plans[actor.character_id] = plan


## One beat of an NPC's plan: its school's line when it fires (a perform resting goes to its
## else_cooldown move), else a weighted draw over the moves it can afford and is not locked
## out of (its line's else_pool when it has one and did not fire); then the courage draw.
func _draw_entry(actor: CombatSliceCharacterBinding, random_source: CombatRandomSource, bindings: Array[CombatSliceCharacterBinding], budget: int, confirmed: bool) -> CombatNpcBeatPlan.Entry:
	var input: CombatActionSelectionInput = CombatSliceProjectionBuilder.build_action_selection_input(actor)
	var set: CombatActionSet = null if input == null else input.current_action_set()
	var skeleton: CombatSchoolSkeleton = _skeleton_of(actor)
	var me: CombatSkeletonState = _skeleton_state(actor.character_id)
	var target_state: CombatSkeletonState = _skeleton_states.get(_target_of(actor, bindings))
	var action: StringName = &""
	var from_line: bool = false
	var fired: bool = false
	if skeleton != null and skeleton.has_npc_line() and skeleton.npc_fires(me, target_state):
		fired = true
		var function_id: StringName = CombatBeatRules.perform_of(skeleton.npc_do)
		if not function_id.is_empty():
			if _can_special(actor) and _beat_rules.cost_of_action(skeleton.npc_do) <= budget and not _perform_use(actor, skeleton.skill_id).is_empty():
				action = skeleton.npc_do
				from_line = true
			elif not skeleton.npc_else_cooldown.is_empty():
				action = skeleton.npc_else_cooldown
				from_line = true
		elif not skeleton.is_locked(skeleton.npc_do, me) and _beat_rules.cost_of_tag(_tag_of(set, skeleton.npc_do)) <= budget:
			action = skeleton.npc_do
			from_line = true
	if action.is_empty():
		var style: CombatStyle = _style_of(actor)
		var weights: Dictionary[StringName, int] = {}
		if style != null:
			weights = style.weights_at(_kee_percent(actor))
		var excluded: Array[StringName] = []
		if set != null and not _one_beat():
			var pool: Array[StringName] = []
			if skeleton != null and not fired:
				pool = skeleton.npc_else_pool
			for move: CombatActionDefinition in set.actions():
				var out: bool = _beat_rules.cost_of_tag(move.tag) > budget
				out = out or (skeleton != null and skeleton.is_locked(move.action_id, me))
				out = out or (not pool.is_empty() and not pool.has(move.action_id))
				if out:
					excluded.append(move.action_id)
		var selection: CombatActionSelectionResult = CombatActionSelector.select_action(input, random_source, weights, excluded)
		if not selection.succeeded:
			return null
		action = selection.selected_action.action_id
	var perform: bool = not CombatBeatRules.perform_of(action).is_empty()
	var tag: StringName = &"" if perform else _tag_of(set, action)
	var cost: int = _beat_rules.cost_of_action(action) if perform else _beat_rules.cost_of_tag(tag)
	var courage: CombatPredrawnCourage = null if perform else _draw_courage(actor, random_source, bindings)
	return CombatNpcBeatPlan.Entry.new(action, tag, cost, courage, confirmed, from_line)


static func _tag_of(set: CombatActionSet, action_id: StringName) -> StringName:
	if set == null:
		return &""
	for move: CombatActionDefinition in set.actions():
		if move.action_id == action_id:
			return move.tag
	return &""


## The target an NPC's line reads: its current one, or the first it may take.
func _target_of(actor: CombatSliceCharacterBinding, bindings: Array[CombatSliceCharacterBinding]) -> StringName:
	var target_id: StringName = _encounter.current_target_for(actor.character_id)
	if target_id.is_empty() or not _target_is_currently_eligible(actor, target_id, bindings):
		target_id = _first_initial_target(actor, bindings)
	return target_id


## A read beat of the plan comes up: what the player could see since may change it — its
## school's line now holds (or no longer does), the move is locked now. A change is a fresh
## entry and the log says 变招. The settled first beat never comes here.
func _revise_entry(actor: CombatSliceCharacterBinding, entry: CombatNpcBeatPlan.Entry, beats: CombatRoundBeats, random_source: CombatRandomSource, bindings: Array[CombatSliceCharacterBinding]) -> CombatNpcBeatPlan.Entry:
	var skeleton: CombatSchoolSkeleton = _skeleton_of(actor)
	if skeleton == null:
		return entry
	var me: CombatSkeletonState = _skeleton_state(actor.character_id)
	var changed: bool = false
	if skeleton.has_npc_line():
		var fires: bool = skeleton.npc_fires(me, _skeleton_states.get(_target_of(actor, bindings)))
		changed = fires != entry.from_line
	if not entry.is_perform() and skeleton.is_locked(entry.action, me):
		changed = true
	if not changed:
		return entry
	var revised: CombatNpcBeatPlan.Entry = _draw_entry(actor, random_source, bindings, maxi(1, beats.remaining), true)
	if revised == null or revised.action == entry.action:
		return entry
	# TRANSLATORS: an NPC's read beat changed on what it saw: $N its name.
	_emit(_note_event(actor.character_id, TranslationServer.translate("$N临阵变招！"), ColoredLine.HIC))
	return revised


## fight(): random(victim cps x 3) < cor + 杀气 / 50, drawn now for the target it has (or
## would take); nothing when the victim is busy or down (fight() attacks then without it).
func _draw_courage(actor: CombatSliceCharacterBinding, random_source: CombatRandomSource, bindings: Array[CombatSliceCharacterBinding]) -> CombatPredrawnCourage:
	if bindings.is_empty():
		return null
	var victim: CombatSliceCharacterBinding = _find_binding(bindings, _target_of(actor, bindings))
	if victim == null or victim.busy.is_busy() or victim.life_status != CombatSliceLifeStatus.Value.ACTIVE:
		return null
	var facts: CombatFightDecisionFacts = CombatSliceProjectionBuilder.build_fight_facts(actor, victim)
	var bound: int = facts.victim_raw_composure * 3
	var draw: int = random_source.legacy_random(bound)
	@warning_ignore("integer_division")
	var threshold: int = facts.attacker_raw_courage + facts.attacker_raw_bellicosity / 50
	return CombatPredrawnCourage.new(victim.character_id, bound, draw, threshold)


## The pending special of `actor`, run before its chat on this beat (or dropped with its
## line when the player's feint or perform struck it meanwhile), as an NPC_CHAT event.
func _run_pending_special(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	if _npc_chat == null or not _pending_specials.has(actor.character_id):
		return null
	var action: NpcSpecialAction = _pending_specials[actor.character_id]
	var label: String = _pending_labels.get(actor.character_id, "")
	_pending_specials.erase(actor.character_id)
	_pending_labels.erase(actor.character_id)
	var result: CombatNpcChatResult = null
	if _interrupted.get(actor.character_id, false):
		# TRANSLATORS: an NPC's announced special is lost: {npc} its name, {move} the special's name.
		var line: String = TranslationServer.translate("{npc}的{move}被打断了。").format({"npc": TranslationServer.translate(_shown_name(actor)), "move": label})
		result = CombatNpcChatResult.new([VisionLine.new(line, actor.character_id, &"", ColoredLine.HIC)])
	elif actor.life_status == CombatSliceLifeStatus.Value.ACTIVE and actor.relationship.is_fighting() and not actor.busy.is_busy():
		var sides: Array = _sides_of(actor, bindings)
		result = _npc_chat.run_special(actor, action, sides[0], sides[1], random_source, effect_registry, _modifiers)
		_rest_special(actor)
		# 战斗拍数 C: the special costs its beats, as the player's orders do.
		_charge_npc_special(actor, action)
		if result != null:
			result.with_special_label(label)
	_interrupted.erase(actor.character_id)
	if result == null:
		return null
	return CombatSchedulerEvent.new(
		_next_event_sequence, _logical_cycle, logical_time_seconds, CombatSchedulerEvent.Kind.NPC_CHAT,
		CombatSchedulerEvent.SkipReason.NONE, actor.character_id, &"", null, _progression_order.take(), result,
	)


## 战斗拍数 A: a perform an NPC's school line planned as a beat (封山弟子's 「封」), run as
## npc.c's perform_action() does (NpcSpecials), as an NPC_CHAT event carrying its name; it
## rests the special's rounds. Null when it said and did nothing (the beat is still spent).
func _perform_beat(
	actor: CombatSliceCharacterBinding,
	function_id: StringName,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	var skeleton: CombatSchoolSkeleton = _skeleton_of(actor)
	var use_id: StringName = &"" if skeleton == null else _perform_use(actor, skeleton.skill_id)
	var perform: PerformFunction = SpecialFunctions.perform(function_id)
	if use_id.is_empty() or perform == null:
		return null
	var context: SpecialContext = CombatSpecialAttackSource.context_for(actor, bindings, random_source, effect_registry, _modifiers)
	context.target = context.other(_target_of(actor, bindings))
	if NpcSpecials.run(NpcSpecialAction.new(NpcSpecialAction.Kind.PERFORM, use_id, function_id), context):
		_rest_special(actor)
	if context.lines.is_empty() and context.attacks.is_empty() and context.damaged.is_empty():
		return null
	var said := CombatNpcChatResult.new(context.lines, context.damaged)
	if not context.attacks.is_empty():
		said = said.with_special(context.report())
	said.with_special_label(TranslationServer.translate(perform.label))
	return CombatSchedulerEvent.new(
		_next_event_sequence, _logical_cycle, logical_time_seconds, CombatSchedulerEvent.Kind.NPC_CHAT,
		CombatSchedulerEvent.SkipReason.NONE, actor.character_id, &"", null, _progression_order.take(), said,
	)


func _shown_name(actor: CombatSliceCharacterBinding) -> String:
	return _npc_chat.display_name_of(actor.character_id) if _npc_chat != null else String(actor.character_id)


## The actor's enemies it may still target (its order) and everyone else in the fight.
func _sides_of(actor: CombatSliceCharacterBinding, bindings: Array[CombatSliceCharacterBinding]) -> Array:
	var enemies: Array[CombatSliceCharacterBinding] = []
	for target_id: StringName in actor.relationship.opponent_ids():
		if _target_is_currently_eligible(actor, target_id, bindings):
			enemies.append(_find_binding(bindings, target_id))
	var others: Array[CombatSliceCharacterBinding] = []
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != actor:
			others.append(binding)
	return [enemies, others]


## The blows the player landed on others this round: a feint or a perform that lands
## interrupts the victim's announced special.
func _note_interrupts(blows: Array, feint: bool) -> void:
	if not feint:
		return
	for blow: Array in blows:
		if blow[0] != _player_id:
			_interrupted[blow[0]] = true


func player_tactics() -> CombatTacticalRuntime:
	return _tactical


## NPCs' npc.c chat() in the fight, configured once before the first advance.
func configure_npc_chat(chat: CombatNpcChat) -> bool:
	if _npc_chat != null or _accumulated_input_seconds != 0.0 or chat == null:
		return false
	_npc_chat = chat
	_npc_chat.telegraph = _decisions.npc_telegraph
	return true


func target_events_after(order: int) -> Array[CombatOrderedTargetEvent]:
	var result: Array[CombatOrderedTargetEvent] = []
	for index: int in range(_target_events.size() - 1, -1, -1):
		var value: CombatOrderedTargetEvent = _target_events[index]
		if value.progression_order <= order:
			break
		result.append(value) # Read-only wrapper, defensive Core event getter.
	result.reverse()
	return result


func announcements_after(order: int) -> Array[CombatLifecycleAnnouncement]:
	var result: Array[CombatLifecycleAnnouncement] = []
	for value: CombatLifecycleAnnouncement in _announcements:
		if value.progression_order > order:
			result.append(value)
	return result


## The boundary's inspect(), then who fell or died there, each in its place.
func _inspect(
	boundary: CombatOpportunityBoundary, bindings: Array[CombatSliceCharacterBinding],
	event: CombatSchedulerEvent = null, tactical: CombatTacticalExecutionResult = null,
) -> bool:
	var ok: bool = boundary.inspect(bindings, event, tactical)
	for announcement: CombatLifecycleAnnouncement in boundary.take_announcements():
		_announcements.append(announcement.ordered(_progression_order.take()))
	return ok


## Called only after a successful Core target transition. Does not advance time.
func record_target_change() -> void:
	var value: CombatEncounterEvent = _encounter.latest_event()
	if value == null or value.kind != CombatEncounterEventKind.Value.TARGET_CHANGED:
		return
	if not _target_events.is_empty() and _target_events.back().event.sequence >= value.sequence:
		return
	_target_events.append(CombatOrderedTargetEvent.new(value, _progression_order.take()))


## The player may pick `target_id`; one they cannot see (a ghost: char.c visible(), name.c
## id()) cannot be named, though fight() may still turn on it.
func can_target(actor_id: StringName, target_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> bool:
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, actor_id)
	var target: CombatSliceCharacterBinding = _find_binding(bindings, target_id)
	return (
		actor != null and actor.exists_in_encounter and actor.combat_available
		and actor.life_status == CombatSliceLifeStatus.Value.ACTIVE
		and _target_is_currently_eligible(actor, target_id, bindings)
		and actor.sees(target)
	)


func is_valid() -> bool:
	return (
		_encounter != null
		and _encounter.is_valid()
		and _config != null
		and _config.is_valid()
	)


func events() -> Array[CombatSchedulerEvent]:
	var result: Array[CombatSchedulerEvent] = []
	for event: CombatSchedulerEvent in _events:
		result.append(event.duplicate_snapshot())
	return result


## Incremental defensive read: walks only the new suffix, never clones old history.
func events_after(progression_order: int) -> Array[CombatSchedulerEvent]:
	var result: Array[CombatSchedulerEvent] = []
	for index: int in range(_events.size() - 1, -1, -1):
		var event: CombatSchedulerEvent = _events[index]
		if event.progression_order <= progression_order:
			break
		result.append(event.duplicate_snapshot())
	result.reverse()
	return result


func advance(
	delta_seconds: float,
	application_gameplay_active: bool,
	world_gate_owner_id: StringName,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	boundary: CombatOpportunityBoundary = null,
) -> CombatSchedulerAdvanceResult:
	if not is_valid() or _encounter.phase != CombatEncounterLifecycle.Value.ACTIVE:
		return CombatSchedulerAdvanceResult.new()
	if not application_gameplay_active:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.APPLICATION_PAUSED
		)
	if world_gate_owner_id != _encounter.encounter_id:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.WORLD_GATE_MISMATCH
		)
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.INVALID_DELTA
		)
	if (
		random_source == null
		or effect_registry == null
		or not bindings_match_encounter(bindings)
	):
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.AUTHORITY_INVALID
		)
	_emitted = []
	if boundary != null and not _inspect(boundary, bindings):
		return CombatSchedulerAdvanceResult.new()
	var tactical_result: CombatTacticalExecutionResult = null
	# 战斗拍数 B: the order queued, to charge its beats once it ran.
	var queued: CombatQueuedAction = _encounter.queued_player_action()
	if _tactical != null:
		# The round's modifiers as they stand (the stance) for a special run at the boundary.
		if queued != null:
			_fill_modifiers(bindings)
		tactical_result = _tactical.process_command_boundary(bindings, random_source, effect_registry)
		if tactical_result != null and tactical_result.outcome == CombatTacticalExecutionResult.Outcome.DISENGAGED:
			if boundary != null:
				boundary.accept_tactical(tactical_result)
			# Never accumulate delta or execute an ordinary opportunity after escape,
			# even if a standalone scheduler has no completion adapter installed.
			return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.ADVANCED_NO_OPPORTUNITY)
	if boundary != null and tactical_result != null and not (tactical_result.joiners.is_empty() and tactical_result.allies.is_empty() and tactical_result.joins.is_empty()):
		boundary.admit(bindings, tactical_result)
	# 战斗拍数 B: the order that ran costs its beats.
	if tactical_result != null and tactical_result.outcome == CombatTacticalExecutionResult.Outcome.APPLIED and queued != null:
		var key: StringName = cost_key_of(queued.request.category, queued.request.action_id)
		_charge_player(key, _beat_rules.cost_of_action(key), bindings)
		# 战斗拍数 C: a perform's own busy counts into the beats it cost.
		if queued.request.category == CombatTacticalRequest.Category.MARTIAL_SPECIAL:
			_absorb_special_busy(_find_binding(bindings, _player_id), _beat_rules.cost_of_action(key))
	if tactical_result != null and tactical_result.special != null:
		var special_blows: Array = _report_blows(tactical_result.special)
		_note_interrupts(special_blows, true)
		_hurts(special_blows, bindings, random_source, boundary)
	# An NPC the action sent away (meloner.c do_return()) walks out of the fight.
	if boundary != null and tactical_result != null:
		var walked: Dictionary[StringName, StringName] = tactical_result.walk_outs()
		for character_id: StringName in walked:
			boundary.depart(bindings, character_id, walked[character_id])
	# A perform's attacks fell nobody yet: char.c heart_beat() does, here.
	if boundary != null and not _inspect(boundary, bindings, null, tactical_result):
		return CombatSchedulerAdvanceResult.new()
	# 战斗拍数 B: a round waiting mid-way goes on from the player's beat (their order given, or
	# given up) without the clock moving — the round already paid its cycle; it waits again
	# on their next beat.
	if _round_running and not _one_beat():
		if waiting_for_player(bindings):
			return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER, 0, _emitted)
		var step: int = _run_round(bindings, random_source, effect_registry, boundary)
		if step == RoundStep.WAITING:
			return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER, 0, _emitted)
		if step == RoundStep.DONE:
			_close_manual_round()
		return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.ADVANCED, 0, _emitted)
	# 战斗决策层 1B: under player_turns the clock waits for the player's order; the enemies'
	# first moves are drawn now, so the first order is not made blind.
	if waiting_for_player(bindings):
		for binding: CombatSliceCharacterBinding in bindings:
			if not binding.is_user and not _plans.has(binding.character_id) and binding.exists_in_encounter:
				_draw_plan(binding, random_source, bindings)
		return CombatSchedulerAdvanceResult.new(CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER)
	_accumulated_input_seconds += delta_seconds
	var due_total: int = int(floor(
		(
			_accumulated_input_seconds + TIME_EPSILON_SECONDS
		) / _config.opportunity_interval_seconds
	))
	var due_cycles: int = due_total - _logical_cycle
	if due_cycles <= 0:
		return CombatSchedulerAdvanceResult.new(
			CombatSchedulerAdvanceResult.Outcome.ADVANCED_NO_OPPORTUNITY
		)
	# 战斗决策层 1B: one order is one round, whatever a frame hitch's delta (Codex on #207).
	if manual():
		due_cycles = 1
	var processed_cycles: int = 0
	for _cycle_index: int in range(due_cycles):
		_logical_cycle += 1
		processed_cycles += 1
		_fill_modifiers(bindings)
		if _tactical != null:
			_tactical.note_round()
		for ended: EndedEffect in _wear_timed_applies(bindings):
			var effect: CombatSchedulerEvent = _remove_effect(ended, bindings, random_source, effect_registry)
			if effect == null:
				continue
			_emit(effect)
			if boundary != null and not _inspect(boundary, bindings, effect):
				return CombatSchedulerAdvanceResult.new(
					CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, _emitted,
				)
		var step: int = _run_round(bindings, random_source, effect_registry, boundary)
		if step == RoundStep.ENDED:
			return CombatSchedulerAdvanceResult.new(
				CombatSchedulerAdvanceResult.Outcome.ADVANCED, processed_cycles, _emitted,
			)
		if step == RoundStep.WAITING:
			# 战斗拍数 B: the round waits on the player's next beat; it goes on from there.
			return CombatSchedulerAdvanceResult.new(
				CombatSchedulerAdvanceResult.Outcome.WAITING_FOR_PLAYER, processed_cycles, _emitted,
			)
	if processed_cycles > 0:
		_close_manual_round()
	return CombatSchedulerAdvanceResult.new(
		CombatSchedulerAdvanceResult.Outcome.ADVANCED,
		due_cycles,
		_emitted,
	)


## The order's round ran: the clock waits for the next (under 自动 nothing to close, and
## an order left over is dropped with it).
func _close_manual_round() -> void:
	_round_open = false
	_player_choice = &""
	_player_choice_tag = &""


## An event of this advance: recorded and reported.
func _emit(event: CombatSchedulerEvent) -> void:
	_events.append(event)
	_emitted.append(event)
	_next_event_sequence += 1


## 战斗拍数 A: one round is a string of beats. Each fighter starts with its base beats and
## may win more (its school's skeleton, up to earned_beat_cap); the beats resolve in
## exchange order (interleaved: the player's first, each NPC's first, then the rest by
## turns) or in combatd.c's participant order, each fighter's together. One who joins
## during the round acts from the next. 战斗拍数 B: the round keeps its place — it stops
## on the player's beat when that waits for their order (WAITING) and goes on from there
## on the next call; ENDED when the fight ended inside it, DONE when every beat is spent.
func _run_round(
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	boundary: CombatOpportunityBoundary,
) -> int:
	if not _round_running:
		_begin_round(bindings)
	while true:
		if _round_cursor >= _round_order.size():
			if not _round_progress:
				break
			_round_progress = false
			_round_cursor = 0
			continue
		var actor_id: StringName = _round_order[_round_cursor]
		var beats: CombatRoundBeats = _beats_of(actor_id, bindings)
		if not beats.has_beats():
			_round_cursor += 1
			continue
		if _player_beat_waits(actor_id, bindings):
			return RoundStep.WAITING
		_round_progress = true
		if not _take_beat(actor_id, beats, bindings, random_source, effect_registry, boundary):
			_round_running = false
			_rounds_completed += 1
			return RoundStep.ENDED
		# Interleaved: the next fighter's beat; else this one's beats together.
		if _beat_rules.interleaved:
			_round_cursor += 1
	_round_running = false
	_rounds_completed += 1
	return RoundStep.DONE


## A round begins: fresh beats (the player's less what their orders between rounds cost,
## or none after 收势), the round's tags forgotten, the skeletons' round facts too, the
## fighters in their order.
func _begin_round(bindings: Array[CombatSliceCharacterBinding]) -> void:
	_round_beats.clear()
	_round_tags.clear()
	_combo_told.clear()
	_heavy_spent_at = -1
	_npc_beats_after_heavy.clear()
	for state: CombatSkeletonState in _skeleton_states.values():
		state.new_round()
	_round_order = _beat_order()
	_round_cursor = 0
	_round_progress = false
	_round_running = true
	# 战斗拍数 D: the guide's word for this round, before anyone acts.
	if _lesson_lines.is_valid() and not _lesson_guide_id.is_empty():
		var said: String = str(_lesson_lines.call(_rounds_completed))
		if not said.is_empty():
			# TRANSLATORS: a guide's word as a round of their lesson begins: $N the guide, {line} what they say.
			_emit(_note_event(_lesson_guide_id, TranslationServer.translate("$N说道：{line}").format({"line": said}), &""))
	if not _one_beat() and not _player_id.is_empty() and _find_binding(bindings, _player_id) != null:
		var mine: CombatRoundBeats = _beats_of(_player_id, bindings)
		for cost: Array in _pending_costs:
			mine.spend(cost[0], cost[1])
		if _yield_pending:
			mine.yield_rest()
	_pending_costs.clear()
	_yield_pending = false


## The fighters' order for the round: combatd.c's participant order; interleaved, the
## player first.
func _beat_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for participant: CombatParticipant in _encounter.participants():
		order.append(participant.participant_id)
	if _beat_rules.interleaved and not _player_id.is_empty() and order.has(_player_id):
		order.erase(_player_id)
		order.push_front(_player_id)
	return order


func _beats_of(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> CombatRoundBeats:
	if not _round_beats.has(actor_id):
		var beats := CombatRoundBeats.new(actor_id, _base_beats(_find_binding(bindings, actor_id)))
		# 战斗拍数 C: what its chat() special cost after its last round's beats were spent.
		for cost: Array in _npc_pending_costs.get(actor_id, []):
			beats.spend(cost[0], cost[1])
		_npc_pending_costs.erase(actor_id)
		_round_beats[actor_id] = beats
	return _round_beats[actor_id]


## What `actor`'s beat is going to be. The player: the move they chose (their first beat),
## else a draw; with more than one beat a round the draw leaves out what their school locks
## and what they cannot afford. An NPC: the next beat of its plan (a read beat revised on
## what it saw), a fresh draw once its round-end work ran (a beat it won), else the
## executor's own draw (ES2's).
func _pick_beat(actor: CombatSliceCharacterBinding, beats: CombatRoundBeats, bindings: Array[CombatSliceCharacterBinding], random_source: CombatRandomSource) -> BeatPick:
	var pick := BeatPick.new()
	if actor.is_user or actor.character_id == _player_id:
		pick.chosen = _player_choice
		pick.ordered = not _player_choice.is_empty() and manual()
		if pick.chosen.is_empty() and not _one_beat() and not actor.busy.is_busy():
			pick.chosen = _draw_player_move(actor, beats, random_source)
		return pick
	var plan: CombatNpcBeatPlan = _plans.get(actor.character_id)
	var entry: CombatNpcBeatPlan.Entry = null
	if plan != null and not plan.is_empty() and not beats.settled:
		entry = plan.pop()
		if not entry.confirmed and not _one_beat() and not actor.busy.is_busy():
			entry = _revise_entry(actor, entry, beats, random_source, bindings)
	elif not _one_beat() and _decisions.npc_telegraph and not actor.busy.is_busy():
		entry = _draw_entry(actor, random_source, bindings, maxi(1, beats.remaining), true)
	if entry == null:
		return pick
	# A busy NPC's beat pays its busy whatever it planned (the busy gate, _process_participant):
	# a planned perform is dropped with it, as the special it announced is (Codex on #249).
	if actor.busy.is_busy():
		return pick
	if entry.is_perform():
		pick.perform = CombatBeatRules.perform_of(entry.action)
	else:
		pick.chosen = entry.action
		pick.courage = entry.courage
	return pick


## The player's beat after their order (or under 自动): the set's draw, leaving out the moves
## their school locks and those costing more beats than are left (CombatActionSelector).
func _draw_player_move(actor: CombatSliceCharacterBinding, beats: CombatRoundBeats, random_source: CombatRandomSource) -> StringName:
	var input: CombatActionSelectionInput = CombatSliceProjectionBuilder.build_action_selection_input(actor)
	var set: CombatActionSet = null if input == null else input.current_action_set()
	if set == null or not set.is_valid():
		return &""
	var skeleton: CombatSchoolSkeleton = _skeleton_of(actor)
	var state: CombatSkeletonState = _skeleton_state(actor.character_id)
	var excluded: Array[StringName] = []
	for move: CombatActionDefinition in set.actions():
		if _beat_rules.cost_of_tag(move.tag) > beats.remaining or (skeleton != null and skeleton.is_locked(move.action_id, state)):
			excluded.append(move.action_id)
	var selection: CombatActionSelectionResult = CombatActionSelector.select_action(input, random_source, {}, excluded)
	return selection.selected_action.action_id if selection.succeeded else &""


## One beat of `actor_id`: picked, run, paid for; its blows noted (interrupts, the school
## skeletons, 识招, the NPCs' own hurt lines); then, on an NPC's last base beat, its
## round-end work (its announced special, its next plan, its chat()). Returns false when the
## fight ended.
func _take_beat(
	actor_id: StringName,
	beats: CombatRoundBeats,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	boundary: CombatOpportunityBoundary,
) -> bool:
	var participant: CombatParticipant = _encounter.participant_for(actor_id)
	if participant == null:
		beats.forfeit()
		return true
	var actor: CombatSliceCharacterBinding = _find_binding(bindings, actor_id)
	# Between beats each fighter holds its next move for the ring; ES2's one beat a round
	# keeps the modifiers the cycle began with.
	if not _one_beat():
		_fill_modifiers(bindings)
	var pick: BeatPick = BeatPick.new()
	var available: bool = actor != null and actor.exists_in_encounter and actor.combat_available and actor.life_status == CombatSliceLifeStatus.Value.ACTIVE and actor.relationship.is_fighting()
	if available:
		pick = _pick_beat(actor, beats, bindings, random_source)
	var event: CombatSchedulerEvent = null
	var is_player: bool = actor_id == _player_id or (actor != null and actor.is_user)
	var beat_number: int = beats.beats_taken() + 1
	if not pick.perform.is_empty():
		event = _perform_beat(actor, pick.perform, bindings, random_source, effect_registry)
		if not is_player:
			_note_habit_of(actor_id, beat_number, &"perform")
		beats.spend(CombatBeatRules.perform_key(pick.perform), _beat_rules.cost_of_action(CombatBeatRules.perform_key(pick.perform)))
		_use_opening(actor_id)
		# 战斗拍数 C: its own busy counts into the beats paid.
		_absorb_special_busy(actor, _beat_rules.cost_of_action(CombatBeatRules.perform_key(pick.perform)))
		if event != null:
			_emit(event)
			var ran: CombatNpcChatResult = event.chat
			if ran != null and ran.special() != null:
				_hurts(_report_blows(ran.special()), bindings, random_source, boundary)
		if boundary != null and not _inspect(boundary, bindings, event):
			return false
		if beats.has_beats() or beats.settled:
			return true
		return _npc_round_end(actor, beats, bindings, random_source, effect_registry, boundary)
	# 战斗拍数 E: the blow of this beat is the beat's own (a 重 weighs two); none other is.
	if not _one_beat():
		_modifiers.side(actor_id).beat_blow = true
	event = _process_participant(participant, bindings, random_source, effect_registry, pick.chosen, pick.courage, pick.ordered)
	if not _one_beat():
		_modifiers.side(actor_id).beat_blow = false
		_use_opening(actor_id)
	if event == null:
		beats.spend(SPENT_WAIT, 1)
		return true
	_emit(event)
	var npc_beat: bool = false
	if event.kind == CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED and event.resolution != null:
		var resolution: CombatSliceOpportunityResult = event.resolution
		npc_beat = not is_player
		var struck: CombatActionDefinition = _struck_move(resolution)
		if resolution.outcome == CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED:
			beats.spend(SPENT_BUSY, 1)
			if actor != null and not actor.busy.is_busy():
				_staggered.erase(actor_id)
			# ES2's busy counts down once a heart beat: a busy round is lost whole.
			if not _beat_rules.busy_in_beats:
				beats.forfeit()
		elif struck != null:
			beats.spend(CombatBeatRules.COST_PLAIN if struck.tag.is_empty() else struck.tag, _beat_rules.cost_of_tag(struck.tag))
			if npc_beat:
				_note_habit_of(actor_id, beat_number, struck.tag)
				if _heavy_spent_at >= 0:
					var after: int = _npc_beats_after_heavy.get(actor_id, 0) + 1
					_npc_beats_after_heavy[actor_id] = after
					if after == 2:
						_tell_combo(actor, bindings)
			elif is_player and struck.tag == CombatMoveTags.HEAVY:
				_heavy_spent_at = beats.beats_taken()
				_npc_beats_after_heavy.clear()
		else:
			beats.spend(SPENT_WAIT, 1)
		var blows: Array = _blows(resolution.forward_result, resolution.chain_result)
		if is_player:
			_note_interrupts(blows, struck != null and struck.tag == CombatMoveTags.FEINT)
			# The order is spent; its tag stays the player's for the ring this round.
			if not _player_choice_tag.is_empty():
				_round_tags[_player_id] = _player_choice_tag
			_player_choice = &""
			_player_choice_tag = &""
		_note_skeleton(resolution, bindings)
		_note_moves_seen(resolution, bindings)
		_hurts(blows, bindings, random_source, boundary)
	else:
		beats.forfeit()
	if boundary != null and not _inspect(boundary, bindings, event):
		return false
	if not npc_beat:
		return true
	# After a beat the NPC acted on (not a busy one, as npc.c chat() runs then too); a busy
	# beat drops the special it announced (Codex on #207).
	if event.resolution.outcome == CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED and _pending_specials.has(actor_id):
		_interrupted[actor_id] = true
		var dropped: CombatSchedulerEvent = _run_pending_special(actor, bindings, random_source, effect_registry)
		if dropped != null:
			_emit(dropped)
	if event.resolution.outcome not in CHAT_AFTER or beats.has_beats() or beats.settled:
		return true
	return _npc_round_end(actor, beats, bindings, random_source, effect_registry, boundary)


## An NPC's last base beat of the round is taken (std/char.c heart_beat() after attack()):
## its announced special runs, its next round's plan is drawn, its chat() runs. Returns false
## when the fight ended in it.
func _npc_round_end(
	actor: CombatSliceCharacterBinding,
	beats: CombatRoundBeats,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	boundary: CombatOpportunityBoundary,
) -> bool:
	beats.settled = true
	# Its announced special runs now, after its attack and before its chat.
	var pending: CombatSchedulerEvent = _run_pending_special(actor, bindings, random_source, effect_registry)
	if pending != null:
		_emit(pending)
		var ran: CombatNpcChatResult = pending.chat
		if ran != null and ran.special() != null:
			_hurts(_report_blows(ran.special()), bindings, random_source, boundary)
		if boundary != null and ran != null and not ran.joins().is_empty():
			boundary.admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(ran.joins()))
		if boundary != null and not _inspect(boundary, bindings, pending):
			return false
	# Its next round's plan, drawn one beat early (npc_telegraph).
	_draw_plan(actor, random_source, bindings)
	var chat: CombatSchedulerEvent = _chat_after(actor, bindings, random_source, effect_registry)
	if chat == null:
		return true
	_emit(chat)
	# 战斗拍数 C: a special its chat() ran on the spot (npc_telegraph off) costs its beats too.
	if chat.chat != null and chat.chat.ran_special() != null:
		_charge_npc_special(actor, chat.chat.ran_special())
	if chat.chat != null and chat.chat.telegraph() != null:
		_pending_specials[chat.actor_id] = chat.chat.telegraph()
		_pending_labels[chat.actor_id] = chat.chat.telegraph_label()
		_interrupted.erase(chat.actor_id)
	# ask_for_help(): the partner's kill_ob() brings it in before anyone acts on.
	var said: CombatNpcChatResult = chat.chat
	if said != null and said.special() != null:
		_hurts(_report_blows(said.special()), bindings, random_source, boundary)
	if boundary != null and said != null and not said.joins().is_empty():
		boundary.admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(said.joins()))
	# go.c: the NPC walked out of the room and out of the fight.
	if boundary != null and said != null and not said.departure_zone_id().is_empty():
		boundary.depart(bindings, chat.actor_id, said.departure_zone_id())
	if boundary != null and not _inspect(boundary, bindings, chat):
		return false
	return true


## The move the beat's forward attack struck with, null when none was (busy, guarding).
static func _struck_move(resolution: CombatSliceOpportunityResult) -> CombatActionDefinition:
	var forward: CombatSingleAttackExecutionResult = resolution.forward_result
	if forward == null or forward.action_selection_result == null:
		return null
	return forward.action_selection_result.selected_action


## 战斗拍数 A: what the beat's blows mean to the fighters' school skeletons — the attacker's
## move and whether it landed (近身, 换招), what each side wins by it (隙 / 压 / 连), and a
## landed move that breaks the victim's charge. The forward attack, then the riposte.
func _note_skeleton(resolution: CombatSliceOpportunityResult, bindings: Array[CombatSliceCharacterBinding]) -> void:
	var forward: CombatSingleAttackExecutionResult = resolution.forward_result
	if forward == null:
		return
	var move: CombatActionDefinition = _struck_move(resolution)
	if move != null and forward.ordinary_attack_result != null and forward.ordinary_attack_result.has_base_result:
		var outcome: CombatAttackResult.Outcome = forward.ordinary_attack_result.base_result.outcome
		_note_blow(forward.attacker_id, forward.victim_id, move, outcome == CombatAttackResult.Outcome.HIT, bindings)
		_note_heavy(forward.attacker_id, forward.victim_id, move, outcome, resolution.outcome in FELLED, bindings)
	var chain: CombatAttackChainResult = resolution.chain_result
	if chain == null or not chain.reverse_execution_reached or forward.riposte_request == null:
		return
	var reverse: CombatActionSelectionResult = chain.reverse_action_selection_result
	if reverse == null or reverse.selected_action == null or chain.reverse_ordinary_result == null or not chain.reverse_ordinary_result.has_base_result:
		return
	_note_blow(forward.riposte_request.attacker_id, forward.riposte_request.victim_id, reverse.selected_action, chain.reverse_ordinary_result.base_result.outcome == CombatAttackResult.Outcome.HIT, bindings)


func _note_blow(attacker_id: StringName, victim_id: StringName, move: CombatActionDefinition, landed: bool, bindings: Array[CombatSliceCharacterBinding]) -> void:
	var attacker: CombatSliceCharacterBinding = _find_binding(bindings, attacker_id)
	var victim: CombatSliceCharacterBinding = _find_binding(bindings, victim_id)
	var mine: CombatSchoolSkeleton = _skeleton_of(attacker)
	var state: CombatSkeletonState = _skeleton_state(attacker_id)
	var was_close: bool = state.close
	var changed: bool = state.note_attack(move.action_id, move.tag, landed, mine != null and mine.tracks_close)
	_round_tags[attacker_id] = move.tag
	if mine != null:
		if mine.earns_on_own_attack(landed, was_close, changed):
			_earn(attacker, mine, bindings)
		if landed and mine.interrupts(move.tag, was_close) and _pending_specials.has(victim_id):
			_interrupted[victim_id] = true
	var theirs: CombatSchoolSkeleton = _skeleton_of(victim)
	if theirs != null and theirs.earns_on_opponent_attack(landed):
		_earn(victim, theirs, bindings)


## 战斗拍数 E: an NPC at the player struck twice since the player's 重 took their last beat —
## the log says so once a round (「趁你收招，连出两手」), after the second blow: the price of a 重
## seen as it is paid. Its beats lost to busy (失衡) do not count.
func _tell_combo(actor: CombatSliceCharacterBinding, bindings: Array[CombatSliceCharacterBinding]) -> void:
	if _one_beat() or _player_id.is_empty() or actor == null or _combo_told.has(actor.character_id):
		return
	if _encounter.current_target_for(actor.character_id) != _player_id or not _round_beats.has(_player_id) or _round_beats[_player_id].has_beats():
		return
	var player: CombatSliceCharacterBinding = _find_binding(bindings, _player_id)
	if player == null or player.life_status != CombatSliceLifeStatus.Value.ACTIVE:
		return
	_combo_told[actor.character_id] = true
	# TRANSLATORS: an enemy struck twice in a row while the player's heavy (重) move took their last move (手) this round: $N the enemy.
	_emit(_note_event(actor.character_id, TranslationServer.translate("$N趁你收招，连出两手！"), ColoredLine.HIR))


## 战斗拍数 E (DECISIONS「战斗拍数 E · 重招」): what a beat's forward blow means beyond itself.
## Any blow at one standing open uses up their 露空; a 重 that lands throws its victim off
## balance (失衡: busy stagger_beats, so their nearest beat is lost; one already busy keeps
## their busy), a 重 dodged or parried leaves its striker open (露空). No draw is taken here.
func _note_heavy(attacker_id: StringName, victim_id: StringName, move: CombatActionDefinition, outcome: CombatAttackResult.Outcome, felled: bool, bindings: Array[CombatSliceCharacterBinding]) -> void:
	if _one_beat():
		return
	_exposed.erase(victim_id)
	# A blow that fells someone (the victim, or the striker on the riposte): no 失衡, no 露空.
	if move.tag != CombatMoveTags.HEAVY or felled:
		return
	if outcome == CombatAttackResult.Outcome.HIT and _beat_rules.stagger_beats > 0:
		var victim: CombatSliceCharacterBinding = _find_binding(bindings, victim_id)
		if victim != null and victim.life_status == CombatSliceLifeStatus.Value.ACTIVE and not victim.busy.is_busy():
			victim.busy.start_busy(_beat_rules.stagger_beats)
			_staggered[victim_id] = true
			# TRANSLATORS: a 重 move landed and threw its victim off balance: $N the one hit, who loses their next beat (手).
			_emit(_note_event(victim_id, TranslationServer.translate("$N被震得失衡，丢了一手！"), ColoredLine.HIR))
	elif outcome in [CombatAttackResult.Outcome.DODGE, CombatAttackResult.Outcome.PARRY] and _beat_rules.exposed_percent > 0:
		var attacker: CombatSliceCharacterBinding = _find_binding(bindings, attacker_id)
		if attacker != null and attacker.life_status == CombatSliceLifeStatus.Value.ACTIVE:
			_exposed[attacker_id] = true
			# TRANSLATORS: a 重 move was dodged or parried and left its striker open: $N the striker; the next blow at them finds them easier to hit.
			_emit(_note_event(attacker_id, TranslationServer.translate("$N一招落空，露出了破绽！"), ColoredLine.HIC))


## `actor` wins a beat this round by its school (within earned_beat_cap), and the log says so.
func _earn(actor: CombatSliceCharacterBinding, skeleton: CombatSchoolSkeleton, bindings: Array[CombatSliceCharacterBinding]) -> void:
	if actor == null or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or not actor.relationship.is_fighting() or actor.busy.is_busy():
		return
	var beats: CombatRoundBeats = _beats_of(actor.character_id, bindings)
	if not beats.earn(skeleton.earn, _beat_rules.earned_beat_cap):
		return
	_earned_counts[actor.character_id] = _earned_counts.get(actor.character_id, 0) + 1
	# TRANSLATORS: a fighter won an extra beat this round: $N its name, {label} how (隙 / 压 / 连).
	var line: String = TranslationServer.translate("$N抢得一手（{label}）！").format({"label": skeleton.label()})
	_emit(_note_event(actor.character_id, line, ColoredLine.HIY))


## A note of the round (a beat won, a changed move) as an NPC_CHAT event with one line.
func _note_event(actor_id: StringName, line: String, color: StringName) -> CombatSchedulerEvent:
	return CombatSchedulerEvent.new(
		_next_event_sequence, _logical_cycle, logical_time_seconds, CombatSchedulerEvent.Kind.NPC_CHAT,
		CombatSchedulerEvent.SkipReason.NONE, actor_id, &"", null, _progression_order.take(),
		CombatNpcChatResult.new([VisionLine.new(line, actor_id, &"", color)]),
	)


func _process_participant(
	participant: CombatParticipant,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	chosen: StringName = &"",
	courage: CombatPredrawnCourage = null,
	ordered: bool = false,
) -> CombatSchedulerEvent:
	var actor: CombatSliceCharacterBinding = _find_binding(
		bindings,
		participant.participant_id,
	)
	if (
		actor == null
		or not actor.exists_in_encounter
		or not actor.combat_available
		or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE
	):
		return _skipped_event(
			participant.participant_id,
			&"",
			CombatSchedulerEvent.SkipReason.PARTICIPANT_UNAVAILABLE,
		)
	if not actor.relationship.is_fighting():
		return _skipped_event(
			actor.character_id,
			&"",
			CombatSchedulerEvent.SkipReason.RELATIONSHIP_INACTIVE,
		)

	var target_id: StringName = _encounter.current_target_for(actor.character_id)
	# The player's chosen move, or the NPC's move drawn a beat early: taken without a draw.
	# DECISIONS「战斗内容」: the player's order is carried out — no courage gate on a chosen move.
	if actor.busy.is_busy():
		return _resolved_event(
			actor.character_id,
			target_id,
			CombatSliceOpportunityExecutor.execute_opportunity(
				actor,
				bindings,
				random_source,
				effect_registry,
				target_id,
				chosen,
				_modifiers,
				courage,
				ordered,
			),
		)
	if not actor.is_user and _eligible_targets(actor, bindings) > 1:
		return _select_opponent(actor, bindings, random_source, effect_registry, chosen, courage)
	if target_id.is_empty() or not _target_is_currently_eligible(actor, target_id, bindings):
		target_id = _first_initial_target(actor, bindings)
		if target_id.is_empty():
			if _encounter.clear_current_target(actor.character_id):
				record_target_change()
			return _skipped_event(
				actor.character_id,
				target_id,
				CombatSchedulerEvent.SkipReason.TARGET_UNAVAILABLE,
			)
		if _encounter.set_current_target(actor.character_id, target_id):
			record_target_change()
	return _resolved_event(
		actor.character_id,
		target_id,
		CombatSliceOpportunityExecutor.execute_opportunity(
			actor,
			bindings,
			random_source,
			effect_registry,
			target_id,
			chosen,
			_modifiers,
			courage,
			ordered,
		),
	)


## 识招: the player, in this fight, watched the NPCs' moves this beat (the attack and, when
## an NPC riposted, its riposte). 战斗拍数 D: an NPC's blow that drew their blood is noted too
## (the doctor reads the wound's school).
func _note_moves_seen(resolution: CombatSliceOpportunityResult, bindings: Array[CombatSliceCharacterBinding]) -> void:
	if _player_id.is_empty() or _decisions.recognise_after <= 0:
		return
	var player: CombatSliceCharacterBinding = _find_binding(bindings, _player_id)
	if player == null or not player.exists_in_encounter:
		return
	var forward: CombatSingleAttackExecutionResult = resolution.forward_result
	if forward != null and forward.attacker_id != _player_id and forward.action_selection_result != null and forward.action_selection_result.selected_action != null:
		MoveRecognition.note(player.state, forward.action_selection_result.selected_action.action_id)
		if forward.victim_id == _player_id and not _blow(forward.ordinary_attack_result).is_empty() and _note_wound.is_valid():
			_note_wound.call(forward.attacker_id)
	var chain: CombatAttackChainResult = resolution.chain_result
	if chain != null and forward != null and forward.victim_id != _player_id and chain.reverse_action_selection_result != null and chain.reverse_action_selection_result.selected_action != null:
		MoveRecognition.note(player.state, chain.reverse_action_selection_result.selected_action.action_id)
		if chain.reverse_victim_id == _player_id and not _blow(chain.reverse_ordinary_result).is_empty() and _note_wound.is_valid():
			_note_wound.call(chain.reverse_attacker_id)


## 战斗拍数 D: an NPC's beat number `beat_number` went on `tag` (perform for a special), told to
## the one watching (configure_insights) in a fight the player is in, under 识招.
func _note_habit_of(actor_id: StringName, beat_number: int, tag: StringName) -> void:
	if _player_id.is_empty() or _decisions.recognise_after <= 0 or not _note_habit.is_valid() or _one_beat():
		return
	_note_habit.call(actor_id, beat_number, tag)


## call_out() runs on the driver's clock: a round of the fight is combat_round_ms of
## it for every timed apply (CharacterTimedApplies). Returns the entries that ended,
## in the bindings' order. powerup's remove_effect() tells only its user (an NPC).
func _wear_timed_applies(bindings: Array[CombatSliceCharacterBinding]) -> Array[EndedEffect]:
	var ended: Array[EndedEffect] = []
	var round_ms: int = roundi(_config.opportunity_interval_seconds * 1000.0)
	for binding: CombatSliceCharacterBinding in bindings:
		for entry: CharacterTimedApplies.Entry in binding.state.timed_applies.advance_entries(round_ms):
			ended.append(EndedEffect.new(binding, entry))
	return ended


## A perform or spell file's remove_effect() for an entry that ended this round
## (fakefault.c's strike, astral_vision.c's line), as an event, or null when it showed
## and did nothing.
func _remove_effect(
	ended: EndedEffect,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	var function: PerformFunction = SpecialFunctions.ending(ended.entry.effect_id)
	var spell: CastFunction = SpecialFunctions.cast_ending(ended.entry.effect_id)
	if function == null and spell == null:
		return null
	var context: SpecialContext = CombatSpecialAttackSource.context_for(ended.binding, bindings, random_source, effect_registry, _modifiers)
	context.target = context.other(ended.entry.target_id)
	if function != null:
		function.remove_effect(context, ended.entry)
	else:
		spell.remove_effect(context, ended.entry)
	var report: SpecialReport = context.report()
	if report.is_empty():
		return null
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.SPECIAL_EFFECT_ENDED,
		CombatSchedulerEvent.SkipReason.NONE,
		ended.binding.character_id,
		ended.entry.target_id,
		null,
		_progression_order.take(),
		null,
		report,
	)


## An NPC's own receive_damage() (NpcHooks: oldman.c) for each of `blows` ([victim, kee
## damage]) that reached a hooked NPC still standing: its lines, its walk out of the fight, a
## pill (CombatNpcChat.hurt()), recorded as they happen. It runs inside the blow in ES2:
## before combatd.c ends a spar on it and before char.c heart_beat() fells anyone, so the
## caller inspects the fight after these.
func _hurts(
	blows: Array,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	boundary: CombatOpportunityBoundary,
) -> Array[CombatSchedulerEvent]:
	var felt: Array[CombatSchedulerEvent] = []
	if _npc_chat == null:
		return felt
	for blow: Array in blows:
		var victim: CombatSliceCharacterBinding = _find_binding(bindings, blow[0])
		if victim == null or victim.life_status != CombatSliceLifeStatus.Value.ACTIVE:
			continue
		var result: CombatNpcChatResult = _npc_chat.hurt(victim, blow[1], random_source)
		if result == null:
			continue
		var hurt := CombatSchedulerEvent.new(
			_next_event_sequence,
			_logical_cycle,
			logical_time_seconds,
			CombatSchedulerEvent.Kind.NPC_CHAT,
			CombatSchedulerEvent.SkipReason.NONE,
			victim.character_id,
			&"",
			null,
			_progression_order.take(),
			result,
		)
		_emit(hurt)
		felt.append(hurt)
		if boundary != null and not result.departure_zone_id().is_empty():
			boundary.depart(bindings, victim.character_id, result.departure_zone_id())
	return felt


## The kee each hit of an attack (and its chain's reverse blow) drew: [victim, damage].
static func _blows(forward: CombatSingleAttackExecutionResult, chain: CombatAttackChainResult) -> Array:
	var blows: Array = []
	if forward != null:
		blows.append(_blow(forward.ordinary_attack_result))
	if chain != null and chain.reverse_execution_reached:
		blows.append(_blow(chain.reverse_ordinary_result))
	return blows.filter(func(blow: Array) -> bool: return not blow.is_empty())


## A special file's attacks' blows, then those it hurt itself (a spell: no kee damage known,
## the pill still checked).
static func _report_blows(report: SpecialReport) -> Array:
	var blows: Array = []
	for attack: SpecialAttack in report.attacks():
		blows.append_array(_blows(attack.forward, attack.chain))
	for character_id: StringName in report.damaged():
		blows.append([character_id, 0])
	return blows


static func _blow(ordinary: CombatOrdinaryAttackResult) -> Array:
	if ordinary == null or not ordinary.has_base_result:
		return []
	var base: CombatAttackResult = ordinary.base_result
	if base.outcome != CombatAttackResult.Outcome.HIT or base.resource_mutation == null or base.resource_mutation.requested_damage <= 0:
		return []
	return [base.defender_id, base.resource_mutation.requested_damage]


## npc.c chat() after the attack of an NPC that is still fighting (CombatNpcChat),
## against its enemies as they are now: those it may still target, in its order.
func _chat_after(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSchedulerEvent:
	if _npc_chat == null or actor == null or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or not actor.relationship.is_fighting():
		return null
	var enemies: Array[CombatSliceCharacterBinding] = []
	for target_id: StringName in actor.relationship.opponent_ids():
		if _target_is_currently_eligible(actor, target_id, bindings):
			enemies.append(_find_binding(bindings, target_id))
	var others: Array[CombatSliceCharacterBinding] = []
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != actor:
			others.append(binding)
	var result: CombatNpcChatResult = _npc_chat.beat(actor, enemies, others, random_source, effect_registry, _can_special(actor))
	if result == null:
		return null
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.NPC_CHAT,
		CombatSchedulerEvent.SkipReason.NONE,
		actor.character_id,
		&"",
		null,
		_progression_order.take(),
		result,
	)


## feature/attack.c attack() for an NPC with several enemies here (the player and the
## soldier they called): select_opponent() takes one of them, random(MAX_OPPONENT) or
## else the first; that one becomes its target. An NPC with one enemy keeps its target
## and draws nothing, as before.
func _select_opponent(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	chosen: StringName = &"",
	courage: CombatPredrawnCourage = null,
) -> CombatSchedulerEvent:
	var resolution: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_opportunity(
		actor, bindings, random_source, effect_registry, &"", chosen, _modifiers, courage,
	)
	var selection: CombatOpponentSelectionResult = resolution.opponent_selection_result
	var target_id: StringName = _encounter.current_target_for(actor.character_id)
	if selection != null and selection.outcome == CombatOpponentSelectionResult.Outcome.SELECTED:
		target_id = selection.selected_opponent_id
		if _encounter.is_hostile(actor.character_id, target_id) and _encounter.set_current_target(actor.character_id, target_id):
			record_target_change()
	return _resolved_event(actor.character_id, target_id, resolution)


func _eligible_targets(actor: CombatSliceCharacterBinding, bindings: Array[CombatSliceCharacterBinding]) -> int:
	var count: int = 0
	for candidate: CombatParticipant in _encounter.participants():
		if _target_is_currently_eligible(actor, candidate.participant_id, bindings):
			count += 1
	return count


func _first_initial_target(
	actor: CombatSliceCharacterBinding,
	bindings: Array[CombatSliceCharacterBinding],
) -> StringName:
	for candidate: CombatParticipant in _encounter.participants():
		if _target_is_currently_eligible(
			actor,
			candidate.participant_id,
			bindings,
		):
			return candidate.participant_id
	return &""


func _target_is_currently_eligible(
	actor: CombatSliceCharacterBinding,
	target_id: StringName,
	bindings: Array[CombatSliceCharacterBinding],
) -> bool:
	var target: CombatSliceCharacterBinding = _find_binding(bindings, target_id)
	return (
		target != null
		and target.exists_in_encounter
		and target.combat_available
		and (target.life_status == CombatSliceLifeStatus.Value.ACTIVE or (
			_encounter.mode == CombatEncounterMode.Value.LETHAL
			and target.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS
			and actor.relationship.has_lethal_target(target_id)
		))
		and target.location_id == actor.location_id
		and _encounter.is_hostile(actor.character_id, target_id)
		and actor.relationship.has_opponent(target_id)
	)


func bindings_match_encounter(
	bindings: Array[CombatSliceCharacterBinding],
) -> bool:
	var participants: Array[CombatParticipant] = _encounter.participants()
	if bindings.size() != participants.size():
		return false
	for index: int in range(participants.size()):
		var participant: CombatParticipant = participants[index]
		var binding: CombatSliceCharacterBinding = bindings[index]
		if (
			binding == null
			or not binding.is_valid()
			or binding.character_id != participant.participant_id
			or binding.state != participant.binding.state
			or binding.relationship != participant.binding.relationship
			or binding.busy != participant.binding.busy
			or binding.armor != participant.binding.armor
		):
			return false
	return true


func _find_binding(
	bindings: Array[CombatSliceCharacterBinding],
	participant_id: StringName,
) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding != null and binding.character_id == participant_id:
			return binding
	return null


func _skipped_event(
	actor_id: StringName,
	target_id: StringName,
	reason: int,
) -> CombatSchedulerEvent:
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.PARTICIPANT_SKIPPED,
		reason,
		actor_id,
		target_id,
		null,
		_progression_order.take(),
	)


func _resolved_event(
	actor_id: StringName,
	target_id: StringName,
	resolution: CombatSliceOpportunityResult,
) -> CombatSchedulerEvent:
	return CombatSchedulerEvent.new(
		_next_event_sequence,
		_logical_cycle,
		logical_time_seconds,
		CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED,
		CombatSchedulerEvent.SkipReason.NONE,
		actor_id,
		target_id,
		resolution,
		_progression_order.take(),
	)
