class_name CombatInsights
extends RefCounted

## 战斗拍数 D (DECISIONS「战斗拍数 D」): what the player learns of a school besides watching
## its moves (MoveRecognition), kept in `CharacterState.insights` (saved) under plain keys:
## - hearsay/<skill>/<n>: a line of the town's hearsay heard (FamilyDefinition.Hearsay.key);
## - lesson/<skill>: the guide's three harmless rounds taken, with which verdict (1 the guide
##   won a beat its way, 2 it never did, 3 the player won one the same way);
## - habit/<npc>/<skill>/<beat>/<tag>: how often that NPC spent its beat number <beat> of a
##   round on a move of <tag> (perform for a special), in fights the player was in;
## - wounded_by/<skill> is a mark (CharacterState.marks), not an insight: the last school whose
##   move drew the player's blood, which the doctor's hearsay asks for.
## The 百科's 见识录 grows only from these and the moves watched: nothing unmet is listed.

const HEARSAY: String = "hearsay/"
## taught/<skill>: the guide's 打法 heard (请教打法).
const TAUGHT: String = "taught/"
const LESSON: String = "lesson/"
const HABIT: String = "habit/"
const WOUNDED_BY: String = "wounded_by/"
## The verdicts a lesson ends with.
const VERDICT_GUIDE_EARNED: int = 1
const VERDICT_NOTHING_EARNED: int = 2
const VERDICT_PLAYER_EARNED: int = 3
## A habit is told once that many beats of that number were watched, and the one tag took at
## least two thirds of them.
const HABIT_SAMPLES: int = 3


## A beat habit read of one NPC: its beat number `beat` (1 the first) mostly goes on `tag`.
class Habit:
	extends RefCounted
	var npc_id: StringName
	var skill_id: StringName
	var beat: int
	var tag: StringName
	var count: int
	var total: int

	func _init(p_npc_id: StringName = &"", p_skill_id: StringName = &"", p_beat: int = 1, p_tag: StringName = &"", p_count: int = 0, p_total: int = 0) -> void:
		npc_id = p_npc_id
		skill_id = p_skill_id
		beat = p_beat
		tag = p_tag
		count = p_count
		total = p_total

	func always() -> bool:
		return count == total


## The player heard what an answer carries (`key`: hearsay/<skill>/<n>, taught/<skill>).
static func heard(state: CharacterState, key: String) -> void:
	if state != null and not key.is_empty():
		state.insights[key] = 1


static func has_heard(state: CharacterState, key: String) -> bool:
	return state != null and state.insights.get(key, 0) != 0


static func taught(state: CharacterState, skill_id: StringName) -> bool:
	return has_heard(state, TAUGHT + String(skill_id))


## The hearsay keys of `skill_id` the player has heard, in the data's order.
static func hearsay_keys_heard(state: CharacterState, skill_id: StringName) -> Array[String]:
	var keys: Array[String] = []
	if state == null:
		return keys
	for key: String in state.insights:
		if key.begins_with(HEARSAY + String(skill_id) + "/"):
			keys.append(key)
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a.get_slice("/", 2)) < int(b.get_slice("/", 2)))
	return keys


static func lesson_taken(state: CharacterState, skill_id: StringName, verdict: int) -> void:
	if state != null and not skill_id.is_empty():
		state.insights[LESSON + String(skill_id)] = verdict


## The verdict the guide's lesson of `skill_id` ended with, 0 when never taken.
static func lesson_verdict(state: CharacterState, skill_id: StringName) -> int:
	return 0 if state == null else state.insights.get(LESSON + String(skill_id), 0)


static func took_lesson(state: CharacterState, skill_id: StringName) -> bool:
	return lesson_verdict(state, skill_id) != 0


## One beat of `npc_id` (its definition) watched: its beat number `beat` of the round went on `tag`.
static func note_habit(state: CharacterState, npc_id: StringName, skill_id: StringName, beat: int, tag: StringName) -> void:
	if state == null or npc_id.is_empty() or beat < 1:
		return
	var key: String = "%s%s/%s/%d/%s" % [HABIT, npc_id, skill_id, beat, tag if not tag.is_empty() else CombatBeatRules.COST_PLAIN]
	state.insights[key] = state.insights.get(key, 0) + 1


## The habits read of the NPCs who fight with `skill_id`: per NPC and beat number, the tag that
## took HABIT_SHARE of at least HABIT_SAMPLES beats watched; by NPC then beat.
static func habits_of_school(state: CharacterState, skill_id: StringName) -> Array[Habit]:
	var totals: Dictionary[String, int] = {}
	var best: Dictionary[String, Array] = {}
	if state == null:
		return []
	var prefix: String = HABIT
	for key: String in state.insights:
		if not key.begins_with(prefix):
			continue
		var parts: PackedStringArray = key.trim_prefix(prefix).split("/")
		if parts.size() != 4 or StringName(parts[1]) != skill_id:
			continue
		var who: String = "%s/%s" % [parts[0], parts[2]]
		var count: int = state.insights[key]
		totals[who] = totals.get(who, 0) + count
		if not best.has(who) or count > best[who][1]:
			best[who] = [parts[3], count]
	var habits: Array[Habit] = []
	for who: String in totals:
		var total: int = totals[who]
		var count: int = best[who][1]
		if total < HABIT_SAMPLES or count * 3 < total * 2:
			continue
		habits.append(Habit.new(StringName(who.get_slice("/", 0)), skill_id, int(who.get_slice("/", 1)), StringName(best[who][0]), count, total))
	habits.sort_custom(func(a: Habit, b: Habit) -> bool: return a.beat < b.beat if a.npc_id == b.npc_id else a.npc_id < b.npc_id)
	return habits


## The last school whose move drew the player's blood becomes their wound's mark (one at a time).
static func set_wounded_by(state: CharacterState, skill_id: StringName) -> void:
	if state == null or skill_id.is_empty():
		return
	for key: String in state.marks.keys():
		if key.begins_with(WOUNDED_BY):
			state.marks.erase(key)
	state.marks[WOUNDED_BY + String(skill_id)] = 1


static func wounded_by(state: CharacterState) -> StringName:
	if state == null:
		return &""
	for key: String in state.marks:
		if key.begins_with(WOUNDED_BY) and state.marks[key] != 0:
			return StringName(key.trim_prefix(WOUNDED_BY))
	return &""


## The guide's one line for `verdict` (VERDICT_*), raw.
static func verdict_line(guide: FamilyDefinition.SchoolGuide, verdict: int) -> String:
	if guide == null:
		return ""
	match verdict:
		VERDICT_PLAYER_EARNED:
			return guide.player_earned if not guide.player_earned.is_empty() else guide.earned
		VERDICT_GUIDE_EARNED:
			return guide.earned
	return guide.not_earned


## The master's conditions in a line of talk ("胆识 20、定力 20"), for {requires} in a guide's or
## the town's lines; "" when he names none.
static func requires_text(master: NpcDefinition) -> String:
	if master == null or master.teaching() == null or master.teaching().apprentice == null:
		return ""
	var parts: Array[String] = []
	for key: StringName in master.teaching().apprentice.requires:
		var what: String = ApprenticeConditions.ATTRIBUTES.get(key, String(key))
		parts.append("%s %d" % [TranslationServer.translate(what), master.teaching().apprentice.requires[key]])
	# TRANSLATORS: joins a master's conditions in a line of talk (胆识 20、定力 20).
	return TranslationServer.translate("、").join(parts)


## `text` with {requires} filled from `master`.
static func fill(text: String, master: NpcDefinition) -> String:
	return TranslationServer.translate(text).format({"requires": requires_text(master)})
