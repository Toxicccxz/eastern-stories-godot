extends RefCounted

## 修补 Z (DECISIONS「改投提示」): changing family names the 势力 lines it ends for good
## (StoryQuestLog.family_change()) in the question asked first (TeacherPanel.family_change_warning(),
## the 背包's letter and the accept test read the same lines): a 捕快 joining 陆得财 ends 官府; a 封山
## disciple at the eighth step leaving ends 封山; joining 山烟寺 shuts 东方神教 before it began.

const BEGGAR_MASTER: StringName = &"common.npc.beggar.master"

var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog


func run_all() -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_constable_joins_huazi()
	_test_fonxan_disciple_leaves()
	_test_sanyen_shuts_dongfang()
	_test_nothing_to_tell()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test(state: CharacterState) -> Callable:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, temps, held)


func _quest(quest_id: StringName) -> StoryQuestDefinition:
	return _catalog.story_quest(quest_id)


## The line begun, its first `steps` steps done (TEST-ONLY: written as the ledger would).
func _begin(state: CharacterState, quest_id: StringName, steps: int) -> void:
	var quest: StoryQuestDefinition = _quest(quest_id)
	state.quests[StoryQuestLog.key_started(quest)] = state.quests.size() + 1
	for index: int in steps:
		var step: StoryQuestDefinition.Step = quest.steps[index]
		var option: StoryQuestDefinition.Option = null if step.options.is_empty() else step.options[0]
		state.quests[StoryQuestLog.key_step(quest, step, option)] = state.quests.size() + 1


func _master_of(family_id: StringName) -> NpcDefinition:
	for npc: NpcDefinition in _catalog.npcs():
		var teaching: NpcTeaching = npc.teaching()
		if teaching != null and teaching.apprentice != null and teaching.family_id == family_id:
			return npc
	return null


func _player(state: CharacterState, title: String) -> WorldPlayerRuntimeState:
	return WorldPlayerRuntimeState.new(&"player", state, null, null, null, null, CharacterRuntimeLifeStatus.Value.ACTIVE, true, true, null, PlayerIdentityFacts.new("阿青", title, 18))


func _ids(quests: Array[StoryQuestDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for quest: StoryQuestDefinition in quests:
		ids.append(quest.quest_id)
	return ids


func _test_constable_joins_huazi() -> void:
	var state := CharacterState.new()
	_begin(state, &"faction.court", 1) # TEST-ONLY: a 捕快 of 乔阴 under way
	var test: Callable = _test(state)
	var change: StoryQuestLog.FamilyChange = StoryQuestLog.family_change(state, &"family.huazi", _catalog.story_quests(), test)
	_check(_ids(change.ends) == [&"faction.court"] and change.closes.is_empty(), "a 捕快 joining 花紫会 ends 官府: %s %s" % [_ids(change.ends), _ids(change.closes)])
	var other: StoryQuestLog.FamilyChange = StoryQuestLog.family_change(state, &"family.fonxan", _catalog.story_quests(), test)
	_check(other.ends.is_empty(), "joining 封山剑派 leaves 官府 running")
	var master: NpcDefinition = _catalog.npc(BEGGAR_MASTER)
	var text: String = TeacherPanel.family_change_warning(_player(state, NpcApprenticeship.COMMONER_TITLE), master, "花紫会", test)
	_check(text.begins_with("拜陆得财为师") and text.contains("· 「官府」这条线就此中止，以后再也接不上。\n确定要拜师吗？"), "the question names the line: %s" % text)
	_check(not TeacherPanel.family_change_warning(_player(state, NpcApprenticeship.COMMONER_TITLE), master, "花紫会").contains("官府"), "without a test, no line is named")


func _test_fonxan_disciple_leaves() -> void:
	var state := CharacterState.new()
	state.family = FamilyState.new(&"family.fonxan", 14) # TEST-ONLY
	state.apprenticeship.master_teacher_id = &"common.npc.swordsman.master"
	_begin(state, &"faction.fonxan", 7) # TEST-ONLY: at the eighth step
	var fonxan: StoryQuestDefinition = _quest(&"faction.fonxan")
	_check(StoryQuestLog.current_step(state, fonxan) == fonxan.steps[7], "at the eighth step")
	var master: NpcDefinition = _catalog.npc(BEGGAR_MASTER)
	var test: Callable = _test(state)
	var change: StoryQuestLog.FamilyChange = StoryQuestLog.family_change(state, &"family.huazi", _catalog.story_quests(), test)
	_check(_ids(change.ends) == [&"faction.fonxan"], "leaving 封山剑派 ends its line: %s" % [_ids(change.ends)])
	var text: String = TeacherPanel.family_change_warning(_player(state, "封山剑派第十四代弟子"), master, "花紫会", test)
	_check(text.contains("就是背叛师门") and text.contains("· 「封山剑派」这条线就此中止，以后再也接不上。\n确定要改投吗？"), "the betrayal's question names it: %s" % text)
	var north: StoryQuestLog.FamilyChange = StoryQuestLog.family_change(state, &"family.fonxan_north", _catalog.story_quests(), test)
	_check(north.ends.is_empty(), "北宗 keeps the line (its lapses read either)")


func _test_sanyen_shuts_dongfang() -> void:
	var state := CharacterState.new()
	var change: StoryQuestLog.FamilyChange = StoryQuestLog.family_change(state, &"family.sanyen", _catalog.story_quests(), _test(state))
	_check(change.ends.is_empty() and _ids(change.closes).has(&"faction.dongfang"), "joining 山烟寺 begins its line, which shuts 东方神教: %s" % [_ids(change.closes)])
	var master: NpcDefinition = _master_of(&"family.sanyen")
	_check(master != null, "山烟寺 has a master")
	if master != null:
		var text: String = TeacherPanel.family_change_warning(_player(state, NpcApprenticeship.COMMONER_TITLE), master, "山烟寺", _test(state))
		_check(text.contains("· 「东方神教」这条线从此不会再出现。"), "named: %s" % text)
	_begin(state, &"faction.dongfang", 0) # TEST-ONLY: took 朱鸿雪's order
	change = StoryQuestLog.family_change(state, &"family.sanyen", _catalog.story_quests(), _test(state))
	_check(change.ends.is_empty() and change.closes.is_empty() and _ids(change.blocked) == [&"faction.sanyen"], "one already in 东方神教: nothing running ends; 山烟寺's own line never begins, and the question says so (势力线复查): %s" % [_ids(change.blocked)])
	if master != null:
		var blocked: String = TeacherPanel.family_change_warning(_player(state, NpcApprenticeship.COMMONER_TITLE), master, "山烟寺", _test(state))
		_check(blocked.contains("· 「山烟寺」这条线不会出现：你走过的另一条线同它不能并存。"), "named: %s" % blocked)
	# A line cut short once does not begin again for one who comes back to the family.
	var back := CharacterState.new()
	var fonxan: StoryQuestDefinition = _quest(&"faction.fonxan")
	back.quests[StoryQuestLog.key_started(fonxan)] = 1 # TEST-ONLY
	back.quests[StoryQuestLog.key_lapsed(fonxan)] = 2 # TEST-ONLY: left 封山 with the line under way
	change = StoryQuestLog.family_change(back, &"family.fonxan", _catalog.story_quests(), _test(back))
	_check(_ids(change.gone) == [&"faction.fonxan"] and change.blocked.is_empty(), "back to 封山: its line was cut short once (%s)" % [_ids(change.gone)])


func _test_nothing_to_tell() -> void:
	var state := CharacterState.new()
	state.family = FamilyState.new(&"family.fonxan", 14) # TEST-ONLY
	_begin(state, &"faction.fonxan", 2)
	_check(StoryQuestLog.family_change(state, &"family.fonxan", _catalog.story_quests(), _test(state)).is_empty(), "the same family: nothing")
	_check(StoryQuestLog.family_change(state, &"family.huazi", _catalog.story_quests(), Callable()).is_empty(), "no test: nothing")
	state.quests[StoryQuestLog.key_lapsed(_quest(&"faction.fonxan"))] = 99 # TEST-ONLY
	_check(StoryQuestLog.family_change(state, &"family.huazi", _catalog.story_quests(), _test(state)).ends.is_empty(), "a line already cut short is not named again")


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
