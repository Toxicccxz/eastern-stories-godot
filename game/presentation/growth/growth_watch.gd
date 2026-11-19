class_name GrowthWatch
extends RefCounted

## 成长时刻 (DECISIONS「练功演出」): what the player gained since the last look, read off their own
## state — a skill's level, a skill first learned, a maximum of 内力 / 法力 / 灵力 raised, a master
## taken, a quest ended, a story's thing first come by. It asks no rule and no command what
## happened: whatever raised the number (a master's lesson, a blow in a fight, a book, a
## quest's reward) is seen the same way, and nothing has to remember to tell it.
## The first look only takes the state in (a journey begun or loaded gains nothing by it); a
## loss (a death's penalty) is taken in without a word. More than `bulk` of one kind at once is
## a set-up (a test's, a tool's), not a gain: none of that kind is told.
## Pure: it keeps what it saw and changes nothing.

const SKILL_LEVEL: StringName = &"skill_level"
const SKILL_LEARNED: StringName = &"skill_learned"
const MAXIMUM_UP: StringName = &"maximum_up"
const APPRENTICED: StringName = &"apprenticed"
const QUEST_DONE: StringName = &"quest_done"
const KEY_ITEM: StringName = &"key_item"
## Every kind, in the order one look tells them.
const KINDS: Array[StringName] = [APPRENTICED, SKILL_LEARNED, SKILL_LEVEL, MAXIMUM_UP, QUEST_DONE, KEY_ITEM]
## The maxima watched (MAXIMUM_UP's subject).
const INNER_FORCE: StringName = &"inner_force"
const MANA: StringName = &"mana"
const ATMAN: StringName = &"atman"
## A done quest's key in CharacterState.quests (StoryQuestLog.key_done()).
const DONE_SUFFIX: String = "#done"


## One gain: what it is, whose (the skill's id, the maximum's name, the master's teacher id, the
## quest's id, the item's definition id), and its number now (the level, the maximum; else 0).
class Moment:
	extends RefCounted
	var kind: StringName
	var subject: StringName
	var value: int = 0
	## APPRENTICED: the family now (&"" none) and the master's name as the state keeps it.
	var family_id: StringName = &""
	var master_name: String = ""

	func _init(p_kind: StringName, p_subject: StringName, p_value: int = 0) -> void:
		kind = p_kind
		subject = p_subject
		value = p_value


var _seen: bool = false
var _levels: Dictionary[StringName, int] = {}
var _maxima: Dictionary[StringName, int] = {}
var _master: StringName = &""
var _quests: Dictionary[StringName, bool] = {}
var _quest_keys: int = -1
## Each story's thing held at some look since reset(): put down and picked up, it is no gain.
var _items: Dictionary[StringName, bool] = {}


## What was seen is forgotten: the next look only takes the state in.
func reset() -> void:
	_seen = false
	_levels.clear()
	_maxima.clear()
	_master = &""
	_quests.clear()
	_quest_keys = -1
	_items.clear()


## The gains since the last look, in KINDS' order. `key_items`: the definition ids of the
## story's things the player holds now.
func look(state: CharacterState, key_items: Array[StringName] = [], bulk: int = 3) -> Array[Moment]:
	var found: Array[Moment] = []
	if state == null:
		return found
	var first: bool = not _seen
	_seen = true
	# A master taken (or changed): the id the state keeps.
	var master: StringName = state.apprenticeship.master_teacher_id
	if master != _master and not master.is_empty():
		var taken := Moment.new(APPRENTICED, master)
		taken.family_id = state.family.family_id
		taken.master_name = state.apprenticeship.legacy_master_name
		found.append(taken)
	_master = master
	# Skills: one not seen before was learned; a level above the one seen was gained.
	var levels: Dictionary[StringName, int] = {}
	for skill_id: StringName in state.skills.raw_skill_ids():
		var level: int = state.skills.raw_level(skill_id)
		levels[skill_id] = level
		if not _levels.has(skill_id):
			found.append(Moment.new(SKILL_LEARNED, skill_id, level))
		elif level > _levels[skill_id]:
			found.append(Moment.new(SKILL_LEVEL, skill_id, level))
	_levels = levels
	var maxima: Dictionary[StringName, int] = {
		INNER_FORCE: state.recovery.inner_force.maximum, MANA: state.recovery.mana.maximum, ATMAN: state.recovery.atman.maximum,
	}
	for power: StringName in maxima:
		if maxima[power] > int(_maxima.get(power, maxima[power])):
			found.append(Moment.new(MAXIMUM_UP, power, maxima[power]))
	_maxima = maxima
	# Quests: the ledger's done keys, read again only when the ledger grew or shrank.
	if state.quests.size() != _quest_keys:
		_quest_keys = state.quests.size()
		for key: Variant in state.quests:
			var text: String = String(key)
			if text.ends_with(DONE_SUFFIX):
				var quest_id := StringName(text.trim_suffix(DONE_SUFFIX))
				if not _quests.has(quest_id):
					_quests[quest_id] = true
					found.append(Moment.new(QUEST_DONE, quest_id))
	for item_id: StringName in key_items:
		if not _items.has(item_id):
			_items[item_id] = true
			found.append(Moment.new(KEY_ITEM, item_id))
	if first:
		return []
	var counts: Dictionary[StringName, int] = {}
	for moment: Moment in found:
		counts[moment.kind] = int(counts.get(moment.kind, 0)) + 1
	var told: Array[Moment] = []
	for kind: StringName in KINDS:
		if int(counts.get(kind, 0)) > bulk:
			continue
		for moment: Moment in found:
			if moment.kind == kind:
				told.append(moment)
	return told
