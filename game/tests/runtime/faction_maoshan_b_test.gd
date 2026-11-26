extends RefCounted

## 势力线第三批 茅山 B (计划 势力线第三批_计划.md §4 茅山 B, §8 第 1、2 行; DECISIONS「茅山 B」「话题按印记列出」): the
## 《上清符箓》 given to 林忌; the 尚书府's 花匠 (ES2's) leaves his garden and comes up to 灵心观 (a native one at the door
## of the 大殿, the next time one walks in): the scene; the split — 烧 with 林忌 (the 花匠 back to the garden, 谷衣心法 for
## a friend, 茅山 votes 颜违) or 留 with the 花匠 (he keeps the book upstairs and teaches 茅山道术 with 天师正道 to anyone,
## 茅山 votes the old 盟主); both 护法 for 茅山's own; after the 终章 the 北麓's 余孽 for one who never walked the 卧底 line
## (烧: 林忌's 剿; 留: the 花匠 reads them down by the 绞盘), passed over when they already have somewhere to go; 虹台's
## 茅山 row and its 这一票 on both sides; the ending's 茅山 card.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.maoshan"
const LIN_JI: StringName = &"common.npc.taoist.taolord"
const ES2_GARDENER: StringName = &"city.npc.shangshu.gardener"
const GARDENER: StringName = &"native.npc.maoshan_gardener"
const GARDENER_NORTH: StringName = &"native.npc.maoshan_gardener_north"
const BOOK: StringName = &"native:temple/talisman_book"
const HALL: StringName = &"temple.temple1"
const HALL_POINT: StringName = &"temple.temple1.square_entry"
const UPSTAIRS: StringName = &"temple.book_room2"
const UPSTAIRS_POINT: StringName = &"temple.book_room2.stairs_arrival"
const YARD: StringName = &"city.shangshu.yuan"
const YARD_POINT: StringName = &"city.shangshu.yuan.gate_entry"
const GARDEN: StringName = &"city.shangshu.huayuan"
const WINCH: StringName = &"niling.winch"
const WINCH_POINT: StringName = &"niling.winch.rope_arrival"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_votes()
	_test_remnant_rules()
	for test: Callable in [_test_burn, _test_keep, _test_disciple, _test_placed]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_keep else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"library", &"brother", &"gardener", &"book", &"home", &"meet", &"split", &"crush", &"pardon"], "茅山 B's steps after 茅山 A's: %s" % [ids])
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == "big" and split.options.size() == 2, "the split: one big choice, two sides")
	for option: StoryQuestDefinition.Option in split.options:
		_check(option.reward.rank_title == "护法" and option.reward.rank_family == &"family.maoshan" and not option.reward.deed.is_empty(), "%s: 护法 for 茅山's own, a deed" % option.option_id)
	_check(quest.step(&"crush").only_after == &"burn" and quest.step(&"pardon").only_after == &"keep", "the 余孽: 剿 after 烧, the 花匠 after 留")
	var book: ItemContentDefinition = catalog.item(BOOK)
	_check(book.give_to.has(LIN_JI), "the book may be given to 林忌")
	for id: StringName in [GARDENER, GARDENER_NORTH]:
		var npc: NpcDefinition = catalog.npc(id)
		_check(npc != null and npc.display_name == "花匠" and npc.hooks().always_kept, "%s: the 花匠, only knocked down" % id)
	var lin: NpcTalk = catalog.npc(LIN_JI).talk()
	_check(lin.ask_confirm("烧").contains("谷衣心法") and lin.ask_confirm("烧").contains("颜违"), "烧 asked first, its cost in full")
	var gardener: NpcTalk = catalog.npc(GARDENER).talk()
	_check(gardener.ask_confirm("留").contains("谁都教") and gardener.ask_confirm("留").contains("旧盟主") and gardener.ask_confirm("留").contains("冷一分"), "留 asked first, its cost in full")
	_check(gardener.ask_confirm("北麓").contains("不能再改"), "the 北麓 asked first")
	# 话题按印记列出: listed_any — 林忌's 剿 for one told of the 余孽 (卧底) or who burnt the book, once the story is over.
	_check(not lin.listed_for("剿", {"茅山烧了符箓": 1}) and lin.listed_for("剿", {"茅山烧了符箓": 1, "终章": 1}) and lin.listed_for("剿", {"林忌说了余孽": 1, "终章": 1}) and not lin.listed_for("剿", {"终章": 1}), "剿 listed: 终章 and one of its two marks")
	_check(not lin.listed_for("招安", {"茅山烧了符箓": 1, "终章": 1}), "招安 stays the 卧底's")
	_check(lin.confirm_applies("剿", {"茅山烧了符箓": 1, "终章": 1}) and not lin.confirm_applies("剿", {"茅山烧了符箓": 1, "终章": 1, "余孽有了去处": 1}), "剿 asked first, unless the 余孽 have somewhere to go")
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	var ids_of_cards: Array = ending.cards.map(func(card: EpilogueDefinition.Card) -> StringName: return card.card_id)
	var at: int = ids_of_cards.find(&"temple")
	_check(at == ids_of_cards.find(&"goathill") + 1 and ending.cards[at].title == "茅山" and catalog.map(ending.cards[at].place) != null, "the ending's 茅山 card after 野羊山: %s" % [ids_of_cards])
	var assembly: StoryQuestDefinition = catalog.story_quest(&"faction.assembly")
	_check(assembly.checklist.any(func(row: StoryQuestDefinition.CheckRow) -> bool: return row.label.contains("茅山派：投旧盟主")), "the 虹台 list has 茅山's old 盟主 row")


## 虹台的票: 烧 (or no split) 颜违; 留 before sitting the old 盟主; either side 听你的 by 这一票; a split after sitting changes
## nothing (票就是票了).
func _test_votes() -> void:
	var state: CharacterState = _fresh(["终章"])
	_check(_holds(state, "assembly.maoshan.yan") and not _holds(state, "assembly.maoshan.old") and not _holds(state, "assembly.maoshan.stated"), "no line: 颜违, not yet stated (as 大会 A)")
	state = _fresh(["茅山烧了符箓", "茅山的票随了林忌"])
	_check(_holds(state, "assembly.maoshan.yan") and _holds(state, "assembly.maoshan.stated"), "烧: 颜违, stated")
	state = _fresh(["茅山收了符箓", "茅山的票随了花匠"])
	_check(_holds(state, "assembly.maoshan.old") and not _holds(state, "assembly.maoshan.yan") and _holds(state, "assembly.maoshan.stated"), "留: the old 盟主, stated")
	state = _fresh(["茅山收了符箓"])
	_check(_holds(state, "assembly.maoshan.yan") and not _holds(state, "assembly.maoshan.old"), "留 after sitting: the vote as it was cast")
	state = _fresh(["终章", "茅山收了符箓", "茅山的票随了花匠"])
	_check(not _listed(state, LIN_JI, "这一票") and _heard(state, LIN_JI, "虹台", "去藏经楼问他"), "留: 林忌 sends one to his 师弟 for the vote")
	_check(_heard(state, GARDENER, "虹台", "这一票，你要") and _listed(state, GARDENER, "这一票") and _heard(state, GARDENER, "这一票", "茅山听你的") and _holds(state, "assembly.maoshan.self") and not _holds(state, "assembly.maoshan.old"), "留: the 花匠 gives the vote")
	state.marks["入了虹台的席"] = 1
	state.marks["九派到了"] = 1
	state.marks["听你的投旧盟主"] = 1
	_check(_holds(state, "assembly.day.maoshan.old") and _holds(state, "assembly.day.maoshan.backs"), "on the day: 听你的, sent to the old 盟主")
	state = _fresh(["入了虹台的席", "九派到了", "茅山收了符箓", "茅山的票随了花匠"])
	_check(_holds(state, "assembly.day.maoshan.old") and not _holds(state, "assembly.day.maoshan.yan"), "on the day: 留's old 盟主")
	state = _fresh(["终章", "茅山烧了符箓", "茅山的票随了林忌"])
	_check(_heard(state, LIN_JI, "虹台", "看着烧的") and _listed(state, LIN_JI, "这一票") and _heard(state, LIN_JI, "这一票", "茅山听你的") and _holds(state, "assembly.maoshan.self"), "烧: 林忌 gives the vote")


## The 余孽 already somewhere (the 卧底 line): neither side sends anyone again.
func _test_remnant_rules() -> void:
	var state: CharacterState = _fresh(["终章", "茅山烧了符箓", "招安了余孽", "余孽有了去处"])
	_check(_heard(state, LIN_JI, "剿", "已经下山") and not state.marks.has("余孽交了官府"), "烧, 招安 done on the 卧底 line: 林忌 sends no 官兵")
	state = _fresh(["终章", "茅山收了符箓", "余孽交了官府", "余孽有了去处"])
	_check(not GameContent.catalog().npc(GARDENER).talk().confirm_applies("北麓", state.marks) and _heard(state, GARDENER, "北麓", "官兵已经上了北麓") and not state.marks.has("花匠上了北麓"), "留, 剿 done: the 花匠 stays")
	state = _fresh(["终章", "茅山收了符箓", "林忌要招安"])
	_check(not GameContent.catalog().npc(GARDENER).talk().confirm_applies("北麓", state.marks) and _heard(state, GARDENER, "北麓", "师兄让你去劝") and not state.marks.has("花匠上了北麓"), "留, the 卧底's 招安 under way: the 花匠 leaves it to them")
	# The other way round: the 花匠 gone up, the 卧底 who heard of the 余孽 cannot send the 官兵 or go and say 下山 meanwhile.
	state = _fresh(["终章", "茅山收了符箓", "林忌说了余孽", "花匠上了北麓"])
	var lin: NpcTalk = GameContent.catalog().npc(LIN_JI).talk()
	_check(not lin.confirm_applies("剿", state.marks) and not lin.confirm_applies("招安", state.marks) and _heard(state, LIN_JI, "剿", "师弟已经上了北麓") and not state.marks.has("余孽交了官府"), "the 花匠 on the 北麓: 林忌 lets him finish")
	# The scene by the 绞盘 cut short (its scene_mark written, nothing else): asking him 「北麓」 finishes it.
	state = _fresh(["终章", "茅山收了符箓", "花匠上了北麓", "花匠在北麓念了经"])
	_check(_heard(state, GARDENER_NORTH, "北麓", "教你们认字") and state.marks.has("招安了余孽") and state.marks.has("余孽有了去处"), "the 北麓 scene cut short: finished by asking")
	# A split taken after sitting on the 虹台 writes no vote mark (票就是票了).
	state = _fresh(["师兄弟见了面", "入了虹台的席"])
	_check(_heard(state, GARDENER, "留", "第七函") and state.marks.has("茅山收了符箓") and not state.marks.has("茅山的票随了花匠"), "留 after sitting: no vote mark")
	state = _fresh(["师兄弟见了面", "入了虹台的席"])
	_check(_heard(state, LIN_JI, "烧", "宁可没有") and state.marks.has("茅山烧了符箓") and not state.marks.has("茅山的票随了林忌"), "烧 after sitting: no vote mark")
	state = _fresh(["花匠交了符箓", "茅山的线断了"])
	var rules: Array = GameContent.catalog().npc(LIN_JI).dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == BOOK and rule.accept)
	_check(rules.size() == 1 and (rules[0] as NpcObjectRule).giver_lacks.has("茅山的线断了"), "the line ended: 林忌 takes no book")


## A friend of 茅山 (a man of no family): the book to 林忌; the garden empty; the 花匠 at the door the next time; the scene;
## 烧 (the 花匠 gone at once, back in the garden after); 谷衣心法; after the 终章 林忌's 剿; 虹台 and 这一票.
func _test_burn(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.maoshan_booked(session)
	session.record_journal()
	_check(_step(session) == &"home", "the line at `home`: %s" % _step(session))
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	_check(_first(session, HALL, GARDENER) == null, "no 花匠 yet")
	var lin: NpcRuntimeState = _first(session, HALL, LIN_JI)
	_check(hall.select_npc(lin.character_id), "林忌 selected")
	var given: ItemHandlingResult = hall.give_to_selected(_carried(session, BOOK))
	_check(given != null and given.done() and state.marks.get("林忌看了符箓", 0) == 1 and not session.player_held_item_ids().get(BOOK, false), "the book to 林忌: he keeps it (%s)" % [_recent(session)])
	_check(_said(given.lines, "逆灵宫的字"), "he reads to the back half")
	session.record_journal()
	_check(_step(session) == &"meet" and _said(_ask(hall, lin, "师弟"), "他会来的"), "the 花匠 will come")
	var garden: WorldMapController = await _garden(tree, session)
	await _settle(tree)
	_check(_first(session, GARDEN, ES2_GARDENER) == null and _first(session, GARDEN, GARDENER) == null and state.marks.get("花匠离了花园", 0) == 1, "the garden: nobody (he is up the mountain)")
	await _to_hall_scene(tree, session)
	hall = session.active_map() as WorldMapController
	lin = _first(session, HALL, LIN_JI)
	var gardener: NpcRuntimeState = _first(session, HALL, GARDENER)
	_check(gardener != null and hall.select_npc(gardener.character_id) and hall.ask_topics_selected().has("留"), "留 listed on the 花匠")
	_check(hall.select_npc(lin.character_id) and hall.ask_topics_selected().has("烧"), "烧 listed on 林忌")
	_check(lin.definition().talk().confirm_applies("烧", state.marks), "烧 is asked first")
	var said: Array[String] = _ask(hall, lin, "烧")
	_check(_said(said, "宁可没有这本书") and state.marks.get("茅山烧了符箓", 0) == 1 and state.marks.get("茅山的票随了林忌", 0) == 1, "烧: %s" % [said])
	_check(_first(session, HALL, GARDENER) == null, "the 花匠 goes down the mountain at once")
	_check(not catalog.npc(GARDENER).talk().confirm_applies("留", state.marks) and _said(_ask(hall, lin, "烧"), "灰是青的"), "asked again: done")
	session.record_journal()
	_check(state.quests.has("faction.maoshan/split/burn") and DeedLog.done(state, "看着林忌把《上清符箓》投进了香炉") and state.affiliation.family_title != "护法", "the split: 烧, its deed; no rank for a friend")
	_check(_step(session) == &"crush", "next: the 余孽 (%s)" % _step(session))
	var teaching: NpcTeaching = catalog.npc(LIN_JI).teaching()
	_check(teaching.recognize(&"", state.marks, &"gouyee") != null and teaching.recognize(&"", state.marks, &"necromancy") == null, "林忌 teaches the friend 谷衣心法, nothing else")
	_check(catalog.npc(GARDENER).teaching().recognize(&"", state.marks, &"necromancy") == null, "the 花匠 teaches nobody on this side")
	garden = await _garden(tree, session)
	_check(_first(session, GARDEN, GARDENER) != null and _first(session, GARDEN, ES2_GARDENER) == null, "the 花匠 back in the garden (one of him)")
	_check(_said(_ask(garden, _first(session, GARDEN, GARDENER), "庾清尘"), "还看着她"), "he watches 庾清尘")
	hall = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	lin = _first(session, HALL, LIN_JI)
	_check(hall.select_npc(lin.character_id) and not hall.ask_topics_selected().has("剿"), "剿 not before the 终章")
	state.marks["终章"] = 1 # TEST-ONLY: the main story over
	_check(hall.select_npc(lin.character_id) and hall.ask_topics_selected().has("剿") and not hall.ask_topics_selected().has("招安"), "after the 终章: 剿 (招安 is the 卧底's)")
	_check(_said(_ask(hall, lin, "剿"), "程不平") and state.marks.get("余孽交了官府", 0) == 1 and state.marks.get("余孽有了去处", 0) == 1, "剿: the letter, the 余孽 settled")
	session.record_journal()
	_check(state.quests.has("faction.maoshan/crush/sent") and state.quests.has("faction.maoshan#done") and DeedLog.done(state, "请林忌把逆灵宫的余孽交给官府去剿"), "the line is done, 茅山's own 剿 a deed")
	_check(_said(_ask(hall, lin, "虹台"), "看着烧的") and state.marks.get("茅山肯听你的", 0) == 1, "虹台: 茅山 would 听你的")
	_check(_said(_ask(hall, lin, "这一票"), "茅山听你的") and _holds(state, "assembly.maoshan.self"), "这一票")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	_check(session.shared_ui().standing_page.shown_text().contains("投进了灵心观的香炉"), "the 声望 page says so")


## A woman, friend of 茅山: 留 — the 花匠 upstairs (not at the door any more), 茅山道术 and 天师正道 for her, 林忌 cold;
## after the 终章 his 北麓: away from the 藏经楼, on the 北麓 by the 绞盘 the scene, the 余孽 down; back upstairs.
func _test_keep(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.maoshan_booked(session)
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, HALL, LIN_JI)
	_check(hall.select_npc(lin.character_id) and hall.give_to_selected(_carried(session, BOOK)).done(), "the book to 林忌")
	await _to_hall_scene(tree, session)
	hall = session.active_map() as WorldMapController
	var gardener: NpcRuntimeState = _first(session, HALL, GARDENER)
	_check(catalog.npc(GARDENER).talk().confirm_applies("留", state.marks), "留 is asked first")
	var said: Array[String] = _ask(hall, gardener, "留")
	_check(_said(said, "第七函") and state.marks.get("茅山收了符箓", 0) == 1 and state.marks.get("茅山的票随了花匠", 0) == 1, "留: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.maoshan/split/keep") and _step(session) == &"pardon", "the split: 留; next the 余孽")
	_check(_said(_ask(hall, _first(session, HALL, LIN_JI), "师弟"), "你们说留"), "林忌 is cold")
	hall = await _reenter_hall(tree, session)
	_check(_first(session, HALL, GARDENER) == null, "the door empty: he is upstairs")
	var library: WorldMapController = MapPlaces.enter(session, UPSTAIRS, UPSTAIRS_POINT)
	await _settle(tree)
	gardener = _first(session, UPSTAIRS, GARDENER)
	_check(gardener != null, "the 花匠 keeps the book upstairs")
	var teaching: NpcTeaching = catalog.npc(GARDENER).teaching()
	_check(teaching.recognize(&"", state.marks, &"necromancy") != null and teaching.recognize(&"", state.marks, &"taoism") != null and teaching.recognize(&"", state.marks, &"gouyee") == null, "茅山道术 and 天师正道 for her, nothing else")
	_check(library.select_npc(gardener.character_id) and library.ask_topics_selected().has("道术") and _said(_ask(library, gardener, "道术"), "男的女的都教"), "he says he teaches anyone")
	_check(library.select_npc(gardener.character_id) and not library.ask_topics_selected().has("北麓"), "北麓 not before the 终章")
	state.marks["终章"] = 1 # TEST-ONLY: the main story over
	_check(library.select_npc(gardener.character_id) and library.ask_topics_selected().has("北麓") and _said(_ask(library, gardener, "北麓"), "绞盘边上等你") and state.marks.get("花匠上了北麓", 0) == 1, "北麓: he goes ahead")
	library = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	library = MapPlaces.enter(session, UPSTAIRS, UPSTAIRS_POINT)
	await _settle(tree)
	_check(_first(session, UPSTAIRS, GARDENER) == null, "away from the 藏经楼 while on the 北麓")
	var slope: WorldMapController = MapPlaces.enter(session, WINCH, WINCH_POINT)
	await _settle(tree)
	_check(slope != null and _first(session, WINCH, GARDENER_NORTH) != null, "on the 北麓 by the 绞盘")
	var lines: Array[String] = await _scene(tree, session, slope)
	_check(_said(lines, "木鱼声停了") and _said(lines, "教你们认字") and state.marks.get("招安了余孽", 0) == 1 and state.marks.get("余孽有了去处", 0) == 1, "the scene: the 余孽 come down (%s)" % [lines.slice(-6)])
	session.record_journal()
	_check(state.quests.has("faction.maoshan/pardon/read") and state.quests.has("faction.maoshan#done") and DeedLog.done(state, "请花匠上北麓，把逆灵宫剩下的人念下了山"), "the line is done, the 花匠's reading a deed")
	library = MapPlaces.enter(session, UPSTAIRS, UPSTAIRS_POINT)
	await _settle(tree)
	gardener = _first(session, UPSTAIRS, GARDENER)
	_check(gardener != null, "back upstairs")
	_check(_said(_ask(library, gardener, "虹台"), "这一票，你要") and _said(_ask(library, gardener, "这一票"), "茅山听你的") and _holds(state, "assembly.maoshan.self"), "虹台 and 这一票 from the 花匠")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	var page: String = session.shared_ui().standing_page.shown_text()
	_check(page.contains("锁回了藏经楼") and page.contains("念下了山"), "the 声望 page says so")


## 林忌's own: the split gives 护法 (either side; 烧 here); the garden never visited meanwhile, gardener.c's own stays.
func _test_disciple(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.maoshan_booked(session, true)
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, HALL, LIN_JI)
	_check(hall.select_npc(lin.character_id) and hall.give_to_selected(_carried(session, BOOK)).done(), "the book to 林忌")
	await _to_hall_scene(tree, session)
	hall = session.active_map() as WorldMapController
	_ask(hall, _first(session, HALL, LIN_JI), "烧")
	session.record_journal()
	_check(state.quests.has("faction.maoshan/split/burn") and state.affiliation.family_title == "护法", "茅山's own: 护法 (%s)" % state.affiliation.family_title)
	await _garden(tree, session)
	_check(_first(session, GARDEN, ES2_GARDENER) != null and _first(session, GARDEN, GARDENER) == null and not state.marks.has("花匠离了花园"), "never in the garden while the book was up the mountain: gardener.c's own is there, one of him")


## Somebody whose 余孽 already went somewhere on the 卧底 line: the step after the split passes at once.
func _test_placed(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.maoshan_split(session, false)
	for mark: String in ["终章", "招安了余孽", "余孽有了去处"]:
		state.marks[mark] = 1 # TEST-ONLY: the 卧底 line asked them down
	session.record_journal()
	_check(state.quests.has("faction.maoshan/pardon/pardon_settled") and state.quests.has("faction.maoshan#done"), "the 余孽 already settled: the line is done")
	var library: WorldMapController = MapPlaces.enter(session, UPSTAIRS, UPSTAIRS_POINT)
	await _settle(tree)
	var gardener: NpcRuntimeState = _first(session, UPSTAIRS, GARDENER)
	_check(gardener != null and library.select_npc(gardener.character_id) and library.ask_topics_selected().has("北麓") and not gardener.definition().talk().confirm_applies("北麓", state.marks), "北麓 asks nothing")
	_check(_said(_ask(library, gardener, "北麓"), "都下了山") and not state.marks.has("花匠上了北麓"), "he says they are down already")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	var page: String = session.shared_ui().standing_page.shown_text()
	_check(page.contains("锁回了藏经楼") and not page.contains("念下了山"), "the 声望 page does not say he read them down")


## Out of the hall and back (stage people come on as one enters a map): the 花匠 at the door, his scene to its end.
func _to_hall_scene(tree: SceneTree, session: WorldSessionController) -> void:
	var hall: WorldMapController = await _reenter_hall(tree, session)
	var gardener: NpcRuntimeState = _first(session, HALL, GARDENER)
	_check(gardener != null, "the 花匠 at the door of the 大殿")
	var lines: Array[String] = await _scene(tree, session, hall)
	_check(_said(lines, "师兄。") and _said(lines, "投进香炉") and _said(lines, "锁回藏经楼") and session.player_runtime().state.marks.get("师兄弟见了面", 0) == 1 and session.player_runtime().state.marks.get("师兄弟说完了话", 0) == 1, "the scene in the 大殿, played out: %s" % [lines.slice(-8)])
	session.record_journal()
	_check(_step(session) == &"split", "the split next (%s)" % _step(session))


func _reenter_hall(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	MapPlaces.enter(session, UPSTAIRS, UPSTAIRS_POINT)
	await _settle(tree)
	var hall: WorldMapController = MapPlaces.enter(session, HALL, HALL_POINT)
	await _settle(tree)
	return hall


## TEST-ONLY: a scene as one comes into its room, through to its end.
func _scene(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> Array[String]:
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(map.scene_running(), "the scene starts as the player comes in")
	for second: int in 60:
		if not map.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not map.scene_running(), "the scene is over")
	return _recent(session, 30)


## Into the 尚书府's 花园 from another map (TEST-ONLY: the 门房's leave given; the handoff onto the 花匠's own spot), its
## people's reactions run.
func _garden(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	session.player_runtime().state.marks["尚书"] = 1 # TEST-ONLY: the 门房 paid
	if (session.active_map() as WorldMapController).map_id() == &"city.shangshu":
		MapPlaces.enter(session, UPSTAIRS, UPSTAIRS_POINT)
		await _settle(tree)
	var map: WorldMapController = MapPlaces.enter(session, GARDEN, &"city.shangshu.huayuan.gardener.1")
	await _settle(tree)
	_check(map != null and session.player_runtime().world_location().zone_id == GARDEN, "TEST-ONLY: in the 花园")
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	return map


func _step(session: WorldSessionController) -> StringName:
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(session.player_runtime().state, GameContent.catalog().story_quest(QUEST))
	return &"" if step == null else step.step_id


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return &""
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _fresh(marks: Array) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1
	return state


func _holds(state: CharacterState, condition_id: String) -> bool:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return JournalLog.holds(GameContent.catalog().conditions()[condition_id], state, temps, held)


## Asks `npc` `topic` as the rules decide (TEST-ONLY: the marks the answer sets set on the state).
func _heard(state: CharacterState, npc: StringName, topic: String, part: String) -> bool:
	var talk: NpcTalk = GameContent.catalog().npc(npc).talk()
	var rule: NpcInquiryRule = NpcInquiryRule.decide(talk.inquiry_rules(topic), state.marks)
	if rule == null:
		return false
	if not rule.mark_asker.is_empty():
		state.marks[rule.mark_asker] = 1 # TEST-ONLY
	for mark: String in rule.marks_asker:
		state.marks[mark] = 1 # TEST-ONLY
	return rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains(part))


func _listed(state: CharacterState, npc: StringName, topic: String) -> bool:
	return GameContent.catalog().npc(npc).talk().listed_for(topic, state.marks)


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(session: WorldSessionController, count: int = 6) -> Array[String]:
	var lines: Array[String] = session.shared_ui().log_lines()
	return lines.slice(maxi(0, lines.size() - count))


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
