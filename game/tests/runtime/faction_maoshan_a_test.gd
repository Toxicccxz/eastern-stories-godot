extends RefCounted

## 势力线第三批 茅山 A (计划 势力线第三批_计划.md §4 茅山 A; DECISIONS「茅山 A」「门规例外」): the line shows for 林忌's own
## and for a friend of 茅山 — one who heard the 尚书府 花匠 call 林忌 his 师兄, or wore the 黑冠 for 林忌 — made one by
## asking 林忌 「师弟」, which also lets them past 藏经楼's invisible wall. Upstairs one 函 of the 镇教秘籍 is missing and
## a note lies on the red cloth; 林忌 tells of his 师弟 (侍者 for 茅山's own); the 花匠 tells his twenty years and hands
## over the 《上清符箓》; the stub `home` points back at 林忌 (茅山 B fills it). A stranger hears nothing.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.maoshan"
const LIN_JI: StringName = &"common.npc.taoist.taolord"
const GARDENER: StringName = &"city.npc.shangshu.gardener"
const BOOK: StringName = &"native:temple/talisman_book"
const SCRIPTURES: StringName = &"temple.book_room2.landmark.scriptures"
const HALL: StringName = &"temple.temple1"
const HALL_POINT: StringName = &"temple.temple1.square_entry"
const UPSTAIRS: StringName = &"temple.book_room2"
const UPSTAIRS_POINT: StringName = &"temple.book_room2.stairs_arrival"
const YARD: StringName = &"city.shangshu.yuan"
const YARD_POINT: StringName = &"city.shangshu.yuan.gate_entry"
const GARDEN: StringName = &"city.shangshu.huayuan"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_wall()
	for test: Callable in [_test_stranger, _test_friend, _test_disciple]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_stranger else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.title == "茅山派", "faction.maoshan: a 势力 line")
	if quest == null:
		return
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(0, 5) == [&"library", &"brother", &"gardener", &"book", &"home"], "its steps begin with 茅山 A's (the rest are 茅山 B's): %s" % [ids])
	_check(quest.steps.all(func(step: StoryQuestDefinition.Step) -> bool: return not step.is_branch()), "no choice in 茅山 A: the split is 茅山 B's")
	var brother: StoryQuestDefinition.Step = quest.step(&"brother")
	_check(brother.reward.rank_title == "侍者" and brother.reward.rank_family == &"family.maoshan" and not brother.reward.deed.is_empty(), "林忌 tells of his 师弟: 侍者 for 茅山's own, a deed")
	_check(quest.step(&"gardener").objective.contains("门房"), "the 尚书府's gate is said")
	_check(quest.step(&"home").target.map_id == &"temple.temple1_house" and quest.step(&"home").objective.contains("林忌"), "the stub points back at 林忌")
	var book: ItemContentDefinition = catalog.item(BOOK)
	_check(book != null and book.quest_item, "the 《上清符箓》 is a quest item")
	var gardener: NpcDefinition = catalog.npc(GARDENER)
	_check(gardener.talk().listed_for("师兄", {}) == false and gardener.talk().listed_for("师兄", {"林忌说了师弟": 1}), "师兄 listed once 林忌 told of him")
	_check(gardener.talk().listed_for("符箓", {"花匠说了来历": 1}) and not gardener.talk().listed_for("符箓", {"林忌说了师弟": 1}), "符箓 listed once he told his years")


## 门规例外: 茅山's own pass the invisible wall; another only with 林忌's leave.
func _test_wall() -> void:
	var rule: ZoneExitRuleDefinition = null
	for candidate: ZoneExitRuleDefinition in GameContent.catalog().exit_rules():
		if candidate.rule_id == &"temple.road2.wall":
			rule = candidate
	_check(rule != null and rule.unless_mark == "林忌许你上藏经楼", "the wall knows 林忌's leave")
	if rule == null:
		return
	var stranger := ZoneExitRuleDefinition.Leaver.new()
	_check(rule.refuses(stranger, false), "a stranger walks into the wall")
	var own := ZoneExitRuleDefinition.Leaver.new(false, 0, &"", &"family.maoshan")
	_check(not rule.refuses(own, false), "茅山's own go in")
	var friend := ZoneExitRuleDefinition.Leaver.new()
	friend.marks = {"林忌许你上藏经楼": 1}
	_check(not rule.refuses(friend, false), "a friend with 林忌's leave goes in")


## A woman of no family who never met the 花匠: no line; 林忌 keeps 茅山's business; the 花匠 says ES2's words.
func _test_stranger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	session.record_journal()
	_check(not state.quests.has("faction.maoshan#started"), "a stranger: no line")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, HALL, LIN_JI)
	_check(_said(_ask(hall, lin, "师弟"), "茅山的家事。") and not state.marks.has("茅山的朋友"), "林忌: 茅山's business")
	session.record_journal()
	_check(not state.quests.has("faction.maoshan#started"), "still no line")


## A man of no family: the 花匠's 林忌 (ES2's line) makes him one who met him; 林忌's 师弟 makes him a friend of 茅山 and
## the line begins; the note upstairs; 林忌's story (no rank: not 茅山's own); the 花匠's years and the book; the stub.
func _test_friend(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var garden: WorldMapController = await _garden(tree, session)
	var gardener: NpcRuntimeState = _first(session, GARDEN, GARDENER)
	_check(_said(_ask(garden, gardener, "林忌"), "你问我师兄") and state.marks.get("花匠说了师兄", 0) == 1, "the 花匠's 林忌: ES2's line, and he is one who met him")
	_check(garden.select_npc(gardener.character_id) and not garden.ask_topics_selected().has("师兄"), "师兄 not listed yet")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, HALL, LIN_JI)
	var said: Array[String] = _ask(hall, lin, "师弟")
	_check(_said(said, "他还叫我师兄") and _said(said, "镇教秘籍") and state.marks.get("茅山的朋友", 0) == 1 and state.marks.get("林忌许你上藏经楼", 0) == 1, "林忌: a friend of 茅山, upstairs once: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.maoshan#started") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"library", "the line begins at the 藏经楼")
	_check(_said(_ask(hall, lin, "师弟"), "你数过没有") and not state.marks.has("林忌说了师弟"), "asked again before the note: the hint")
	var library: WorldMapController = MapPlaces.enter(session, UPSTAIRS, UPSTAIRS_POINT)
	await _settle(tree)
	_check(library != null and library.select_landmark(SCRIPTURES) and library.inspect_selected() and state.marks.get("看过师弟的字条", 0) == 1, "the 镇教秘籍: six 函 and the note")
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	lin = _first(session, HALL, LIN_JI)
	said = _ask(hall, lin, "师弟")
	_check(_said(said, "上清符箓") and _said(said, "镇宅") and state.marks.get("林忌说了师弟", 0) == 1, "林忌 tells of his 师弟: %s" % [said])
	session.record_journal()
	_check(DeedLog.done(state, "数出藏经楼的镇教秘籍少了一函") and state.affiliation.family_title != "侍者", "the deed; no rank for a friend")
	garden = await _garden(tree, session)
	gardener = _first(session, GARDEN, GARDENER)
	_check(garden.select_npc(gardener.character_id) and garden.ask_topics_selected().has("师兄") and not garden.ask_topics_selected().has("符箓"), "师兄 listed now, 符箓 not yet")
	said = _ask(garden, gardener, "师兄")
	_check(_said(said, "老松岭") and _said(said, "清尘") and _said(said, "小屋") and state.marks.get("花匠说了来历", 0) == 1, "the 花匠's twenty years: %s" % [said])
	said = _ask(garden, gardener, "符箓")
	_check(_said(said, "上清符箓") and session.player_held_item_ids().get(BOOK, false) == true and state.marks.get("花匠交了符箓", 0) == 1, "the book in hand")
	var again: bool = session.player_held_item_ids().get(BOOK, false)
	_check(_said(_ask(garden, gardener, "符箓"), "书在你那里") and again, "asked again: no second book")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"home" and DeedLog.done(state, "从尚书府的花匠手里接过了《上清符箓》"), "the stub: back to 林忌")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	var page: String = session.shared_ui().standing_page.shown_text()
	_check(page.contains("茅山的朋友") and page.contains("上清符箓"), "the 声望 page says so")


## 林忌's own: the line from 拜师; his 师弟 to his own is a hint, then the story and 侍者; one who leaves 茅山 ends it.
func _test_disciple(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.maoshan_joined(session)
	session.record_journal()
	_check(state.quests.has("faction.maoshan#started"), "茅山's own: the line from 拜师")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, HALL, LIN_JI)
	_check(_said(_ask(hall, lin, "师弟"), "你数过没有") and not state.marks.has("茅山的朋友"), "his own: the hint, no friend's mark")
	state.marks["看过师弟的字条"] = 1 # TEST-ONLY: the note read (as _test_friend)
	_check(_said(_ask(hall, lin, "师弟"), "上清符箓"), "the story")
	session.record_journal()
	_check(state.quests.has("faction.maoshan/brother") and state.affiliation.family_title == "侍者", "侍者 (%s)" % state.affiliation.family_title)
	state.family = FamilyState.new(&"", 0) # TEST-ONLY: left 茅山
	session.record_journal()
	_check(state.marks.get("茅山的线断了", 0) == 1, "left 茅山: the line ends (%s)" % [state.marks.keys().filter(func(m: String) -> bool: return m.contains("茅山"))])
	_check(_said(_ask(hall, lin, "师弟"), "不劳你了"), "林忌 says no more")


## Into the 尚书府 past its 门房 (TEST-ONLY: his leave as 门房 gives it) and into the 花园.
func _garden(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	session.player_runtime().state.marks["尚书"] = 1 # TEST-ONLY: the 门房 paid
	var map: WorldMapController = MapPlaces.enter(session, YARD, YARD_POINT)
	await _settle(tree)
	_check(map != null and map.place_player(GARDEN, MapPlaces.zone_spot(map, GARDEN)), "TEST-ONLY: in the 花园")
	await _settle(tree)
	return map


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("茅山", gender)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
