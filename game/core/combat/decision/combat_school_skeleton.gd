class_name CombatSchoolSkeleton
extends RefCounted

## 战斗拍数 A (DECISIONS「战斗拍数」): how a school wins its third beat and what it locks —
## data on skills.json (`skeleton`), read by one engine; a school without one has only the
## round's base beats. Vocabulary v1:
## - earn: how a fighter of this school wins a beat (up to the round's earned_beat_cap):
##   opponent_missed (an enemy's move at it missed: 隙), own_hit_while_close (its own move
##   landed while it was close: 压), chain_changed_move (it changed its move from the last
##   beat of the round: 连). `earn_label` is the one-character word the beat wears.
## - state: `close` — the fighter starts pulled apart, is close once a move of its lands,
##   apart again once one misses (CombatSkeletonState).
## - lock: [{move, unless}] — the move cannot be chosen unless the fighter is in that state
##   (够不着). The 经典 round never locks (DECISIONS: ES2's moves are always available).
## - npc_if: {when, do, else_cooldown?, else_pool?} — the one line an NPC of this school plays
##   by: when `when` holds (player_last_heavy_missed: its target's last move was 重 and missed;
##   own_last_landed: its own last move landed) it does `do` (a move, or perform/<id>);
##   a perform resting goes to `else_cooldown` instead; when `when` does not hold, it draws
##   from `else_pool` (the whole set when none).
## - interrupts_charge: {tag, state} — a landed move of that tag, in that state, breaks the
##   victim's announced special (as the player's 虚招 does).

const EARN_OPPONENT_MISSED: StringName = &"opponent_missed"
const EARN_OWN_HIT_WHILE_CLOSE: StringName = &"own_hit_while_close"
const EARN_CHAIN_CHANGED_MOVE: StringName = &"chain_changed_move"
const EARNS: Array[StringName] = [EARN_OPPONENT_MISSED, EARN_OWN_HIT_WHILE_CLOSE, EARN_CHAIN_CHANGED_MOVE]
const STATE_CLOSE: StringName = &"close"
const WHEN_PLAYER_LAST_HEAVY_MISSED: StringName = &"player_last_heavy_missed"
const WHEN_OWN_LAST_LANDED: StringName = &"own_last_landed"
const WHENS: Array[StringName] = [WHEN_PLAYER_LAST_HEAVY_MISSED, WHEN_OWN_LAST_LANDED]
## TRANSLATORS: the one-character word of a beat won each way: 隙 an opening the enemy gave, 压 pressing a landed hit, 连 a chained change of move.
const EARN_LABELS: Dictionary[StringName, String] = {EARN_OPPONENT_MISSED: "隙", EARN_OWN_HIT_WHILE_CLOSE: "压", EARN_CHAIN_CHANGED_MOVE: "连"}
## 战斗界面第二轮: how each way wins a beat, in the player's words, written under the battle
## panel's dashed slot (DECISIONS「战斗界面 · 节拍条」).
## TRANSLATORS: under the battle panel's dashed slot: how the player's school wins one more move this round (隙 / 压 / 连).
const EARN_HINTS: Dictionary[StringName, String] = {
	EARN_OPPONENT_MISSED: "对方打空得 1 手", EARN_OWN_HIT_WHILE_CLOSE: "近身打中得 1 手", EARN_CHAIN_CHANGED_MOVE: "换招连打得 1 手",
}
## TRANSLATORS: why a locked move cannot be chosen now: 够不着 the fighter is not close enough.
const LOCK_REASONS: Dictionary[StringName, String] = {STATE_CLOSE: "够不着"}


class Lock:
	extends RefCounted
	var move: StringName
	var unless_state: StringName

	func _init(p_move: StringName = &"", p_unless: StringName = &"") -> void:
		move = p_move
		unless_state = p_unless


var skill_id: StringName
var earn: StringName = &""
var earn_label: String = ""
## 战斗拍数 B: the word for how this school plays (封山剑法 候隙, 柳家拳 抢压), shown after an
## enemy's name once the player's 见识录 knows it; "" for none.
var style_word: String = ""
## 战斗拍数 D: the school's way in one plain sentence (the 拜师 page's row once the guide's
## lesson was taken, the 见识录's 打法 line once the style word is known); "" for none.
var style_line: String = ""
var tracks_close: bool = false
var locks: Array[Lock] = []
var npc_when: StringName = &""
## A move's full action ID, or perform/<id> (CombatBeatRules.perform_of()).
var npc_do: StringName = &""
var npc_else_cooldown: StringName = &""
var npc_else_pool: Array[StringName] = []
var interrupts_tag: StringName = &""
var interrupts_state: StringName = &""


func _init(p_skill_id: StringName = &"") -> void:
	skill_id = p_skill_id


func has_npc_line() -> bool:
	return not npc_when.is_empty() and not npc_do.is_empty()


## The label of a beat this school wins (data, or the vocabulary's).
func label() -> String:
	if not earn_label.is_empty():
		return TranslationServer.translate(earn_label)
	return TranslationServer.translate(EARN_LABELS.get(earn, ""))


## Whether a move of this fighter's that `landed` (while it was `was_close`, having `changed`
## its move from the round's last) wins it a beat.
func earns_on_own_attack(landed: bool, was_close: bool, changed: bool) -> bool:
	match earn:
		EARN_OWN_HIT_WHILE_CLOSE:
			return landed and was_close
		EARN_CHAIN_CHANGED_MOVE:
			return changed
	return false


## Whether an enemy's move at this fighter that `landed` (or not) wins it a beat.
func earns_on_opponent_attack(landed: bool) -> bool:
	return earn == EARN_OPPONENT_MISSED and not landed


## Why `action_id` cannot be chosen now (the lock's reason, player text), "" when it can.
func lock_reason(action_id: StringName, state: CombatSkeletonState) -> String:
	for lock: Lock in locks:
		if lock.move == action_id and not _in_state(lock.unless_state, state):
			return TranslationServer.translate(LOCK_REASONS.get(lock.unless_state, ""))
	return ""


func is_locked(action_id: StringName, state: CombatSkeletonState) -> bool:
	for lock: Lock in locks:
		if lock.move == action_id and not _in_state(lock.unless_state, state):
			return true
	return false


## Whether the NPC line's `when` holds for `me` against `target` (its target's facts).
func npc_fires(me: CombatSkeletonState, target: CombatSkeletonState) -> bool:
	match npc_when:
		WHEN_PLAYER_LAST_HEAVY_MISSED:
			return target != null and target.attacked and target.last_tag == CombatMoveTags.HEAVY and not target.last_landed
		WHEN_OWN_LAST_LANDED:
			return me != null and me.attacked and me.last_landed
	return false


## Whether a landed move of `tag`, by a fighter who `was_close`, breaks the victim's charge.
func interrupts(tag: StringName, was_close: bool) -> bool:
	if interrupts_tag.is_empty() or tag != interrupts_tag:
		return false
	return interrupts_state.is_empty() or (interrupts_state == STATE_CLOSE and was_close)


static func _in_state(state_id: StringName, state: CombatSkeletonState) -> bool:
	if state_id == STATE_CLOSE:
		return state != null and state.close
	return state_id.is_empty()


## {earn?, earn_label?, state?, lock?: [{move, unless}], npc_if?: {when, do, else_cooldown?,
## else_pool?}, interrupts_charge?: {tag, state?}}. Move names are the skill's short action
## IDs (`id_prefix` + name) and must be among `action_ids`; perform/<id> names a perform.
static func from_record(reader: ContentRecordReader, skill_id: StringName, id_prefix: String, action_ids: Array[StringName]) -> CombatSchoolSkeleton:
	var skeleton := CombatSchoolSkeleton.new(skill_id)
	skeleton.earn = StringName(reader.text("earn"))
	if not skeleton.earn.is_empty() and not EARNS.has(skeleton.earn):
		reader.fail("earn", "expected one of %s" % ", ".join(EARNS))
	skeleton.earn_label = reader.text("earn_label")
	skeleton.style_word = reader.text("style_word")
	skeleton.style_line = reader.text("style_line")
	var state: String = reader.text("state")
	skeleton.tracks_close = state == String(STATE_CLOSE)
	if not state.is_empty() and not skeleton.tracks_close:
		reader.fail("state", "the only state is close")
	for lock: ContentRecordReader in reader.children("lock"):
		var move: StringName = _move(lock, "move", id_prefix, action_ids)
		var unless: StringName = StringName(lock.required_text("unless"))
		if unless != STATE_CLOSE:
			lock.fail("unless", "the only state is close")
		if not skeleton.tracks_close:
			lock.fail("unless", "a lock on close needs state: close")
		skeleton.locks.append(Lock.new(move, unless))
		lock.finish()
	var line: ContentRecordReader = reader.child("npc_if")
	if line != null:
		skeleton.npc_when = StringName(line.required_text("when"))
		if not WHENS.has(skeleton.npc_when):
			line.fail("when", "expected one of %s" % ", ".join(WHENS))
		var do_text: String = line.required_text("do")
		if do_text.begins_with(CombatBeatRules.PERFORM_PREFIX):
			var function_id: StringName = CombatBeatRules.perform_of(StringName(do_text))
			if SpecialFunctions.perform(function_id) == null:
				line.fail("do", "no perform action %s" % function_id)
			skeleton.npc_do = StringName(do_text)
		else:
			skeleton.npc_do = _move(line, "do", id_prefix, action_ids)
		if line.has("else_cooldown"):
			skeleton.npc_else_cooldown = _move(line, "else_cooldown", id_prefix, action_ids)
		for name: String in line.text_list("else_pool"):
			var move_id: StringName = StringName(id_prefix + name)
			if not action_ids.has(move_id):
				line.fail("else_pool", "'%s' is not a move of this skill" % name)
			skeleton.npc_else_pool.append(move_id)
		line.finish()
	var charge: ContentRecordReader = reader.child("interrupts_charge")
	if charge != null:
		skeleton.interrupts_tag = StringName(charge.required_text("tag"))
		if not CombatMoveTags.ALL.has(skeleton.interrupts_tag):
			charge.fail("tag", "a move tag (quick, heavy, feint, guard)")
		skeleton.interrupts_state = StringName(charge.text("state"))
		if not skeleton.interrupts_state.is_empty() and skeleton.interrupts_state != STATE_CLOSE:
			charge.fail("state", "the only state is close")
		charge.finish()
	reader.finish()
	return skeleton


static func _move(reader: ContentRecordReader, key: String, id_prefix: String, action_ids: Array[StringName]) -> StringName:
	var name: String = reader.required_text(key)
	var move_id: StringName = StringName(id_prefix + name)
	if not action_ids.has(move_id):
		reader.fail(key, "'%s' is not a move of this skill" % name)
	return move_id
