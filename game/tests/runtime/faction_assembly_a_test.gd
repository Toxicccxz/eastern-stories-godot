extends RefCounted

## 势力线第一批 大会 A (计划 build/plans/势力线第一批_计划.md §7 大会 A 与「九派的票」, §6「主线打完才进来的人」, §11 Q2 Q3;
## DECISIONS「大会 A」「虹台的票」): the quest 正月十七 · 虹台大会 shows once any 势力 line begins or the main story is
## over, pinned above every other line; its rows say 已表态 x／9 and, a row for each 派, what it votes and why. Once the
## main story is over 饮风客栈's 店小二 hands over the invitation, once. Each of the nine heads has 「虹台」: his vote and
## why; where the plan's table lets it turn, a confirmed word turns it. The 虹台 map up the stair south of 葬剑亭 walks
## through, in and out. After the 终章 the 卧底's 余孽 are 剿 (林忌's letter) or 招安 (「下山」 in the 道观).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const StoryFixtures := preload("res://tests/support/story_fixtures.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const QUEST: StringName = &"faction.assembly"
const INVITE: StringName = &"native:waterfog/assembly_invitation"
const WAITER: StringName = &"snow.npc.waiter"
const INN: StringName = &"snow.inn.main_floor"
const INN_POINT: StringName = &"snow.inn.main_floor.player_birth"
const LIN: StringName = &"common.npc.taoist.taolord"
const TEMPLE: StringName = &"temple.temple1"
const TEMPLE_POINT: StringName = &"temple.temple1.taolord.1"
const FRONT: StringName = &"niling.front"
const FRONT_POINT: StringName = &"niling.front.lead_chanter.1"
const CHANTER: StringName = &"native.npc.niling_lead_chanter"
const CROWN: StringName = &"native:niling/black_crown"
const TOMB: StringName = &"waterfog.swordtomb"
const TOMB_POINT: StringName = &"waterfog.swordtomb.terrace_return"
const SECTS: Array[StringName] = [&"fonxan", &"celestial", &"zhenyuan", &"maoshan", &"latemoon", &"sanyen", &"buxuan", &"huazi", &"juechen"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_votes()
	for test: Callable in [_test_appears, _test_appears_after, _test_counts, _test_invitation, _test_terrace, _test_remnant_crushed, _test_remnant_pardoned]:
		var session: WorldSessionController = await _session(tree)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.pinned and quest.pin_rank == 2, "a 势力 quest, pinned above the other pinned")
	_check(catalog.story_quest(&"faction.niling").pin_rank == 1, "the 卧底's 疑点 pinned below it")
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"wait", &"invite", &"canvass", &"day"], "its steps: %s" % [ids])
	_check(quest.step(&"canvass").target.map_id == &"waterfog.terrace" and quest.step(&"canvass").objective.contains("骆云舟"), "the last step leads to the 虹台 and says where the nine are")
	_check(quest.checklist.size() == 3 + 9 + 23 and quest.checklist[0].counts and quest.checklist[0].condition.amount == 9, "已表态 x／9, 颜违's and yours, then a row for each 派's vote (振远 B: 振远 听你的 too; 花紫会 B: 花紫会 颜违 and 听你的)")
	var conditions: Dictionary[String, JournalEntryDefinition] = catalog.conditions()
	for sect: StringName in SECTS:
		_check(conditions.has("assembly.%s.stated" % sect), "%s: 表态 named" % sect)
	_check(conditions.has("assembly.yan_wins") and conditions["assembly.yan_wins"].amount == 5 and conditions.has("assembly.self_backed"), "换盟主要过半: five")
	var niling: StoryQuestDefinition = catalog.story_quest(&"faction.niling")
	var after: StoryQuestDefinition.Step = niling.step(&"aftermath")
	_check(after.is_branch() and after.weight == StoryQuestDefinition.WEIGHT_BIG and after.only_after == &"remnant" and after.option(&"crush") != null and after.option(&"pardon") != null, "卧底's stub grown: 剿 or 招安, the remnant way's split")
	_check(catalog.item(INVITE) != null, "the invitation is an item")


## Each 派's default and the one way to turn it (the heads' rules, the named votes).
func _test_votes() -> void:
	# 封山
	var state := _fresh(["终章"])
	_check(_heard(state, &"common.npc.swordsman.master", "虹台", "等盟主回来") and _holds(state, "assembly.fonxan.stated") and _holds(state, "assembly.fonxan.old"), "封山 with no line: 等盟主回来")
	_check(not _listed(state, &"common.npc.swordsman.master", "这一票"), "封山 with no line: nothing to ask")
	state = _fresh(["终章", "跟了本宗"])
	_check(_holds(state, "assembly.fonxan.stated") and _holds(state, "assembly.fonxan.old"), "本宗: stated by the split, 等盟主回来")
	_check(_heard(state, &"common.npc.swordsman.master", "虹台", "你开口") and _confirms(state, &"common.npc.swordsman.master", "这一票"), "本宗: 柳淳风 leaves the door open, asked first")
	_heard(state, &"common.npc.swordsman.master", "这一票", "封山听你的")
	_check(_holds(state, "assembly.fonxan.self") and not _holds(state, "assembly.fonxan.old"), "本宗: 封山听你的")
	state = _fresh(["终章", "跟了本宗", "封山肯听你的"])
	_check(not _confirms(state, &"snow.npc.girl", "这一票") and _heard(state, &"snow.npc.girl", "这一票", "爹爹手里") and not state.marks.has("封山听你的"), "本宗: not 柳绘心's to give")
	state = _fresh(["终章", "跟了北宗"])
	_check(_holds(state, "assembly.fonxan.yan"), "北宗: 颜违's seat, his vote")
	_check(_heard(state, &"common.npc.swordsman.master", "虹台", "问绘心") or _heard(state, &"common.npc.swordsman.master", "虹台", "同绘心说"), "北宗: 柳淳风 sends one to 柳绘心")
	_check(_heard(state, &"snow.npc.girl", "虹台", "这一票我给你"), "北宗: 柳绘心 would give it")
	_check(not _confirms(state, &"common.npc.swordsman.master", "这一票") and _heard(state, &"common.npc.swordsman.master", "这一票", "不在我手里") and not state.marks.has("封山听你的"), "北宗: not 柳淳风's to give, nothing asked first")
	_heard(state, &"snow.npc.girl", "这一票", "听你的")
	_check(_holds(state, "assembly.fonxan.self") and not _holds(state, "assembly.fonxan.yan"), "北宗: 封山听你的")
	# 天邪
	state = _fresh(["终章"])
	_check(_heard(state, &"common.npc.fighter.executioner", "虹台", "投他") and _holds(state, "assembly.celestial.yan"), "天邪 with no line, 卫沧澜 not back: 颜违")
	state = _fresh(["终章", "卫沧澜出了尚书府"])
	_check(_heard(state, &"common.npc.fighter.executioner", "虹台", "坐在厅里") and _holds(state, "assembly.celestial.old"), "天邪 with no line, 卫沧澜 back: him")
	state = _fresh(["终章", "站了潘军禅"])
	_check(_holds(state, "assembly.celestial.old") and _heard(state, &"common.npc.fighter.executioner", "虹台", "你开口"), "站了潘军禅: 等盟主回来, the door open")
	_heard(state, &"common.npc.fighter.executioner", "这一票", "执事说了算")
	_check(_holds(state, "assembly.celestial.self"), "站了潘军禅: 天邪听你的")
	state = _fresh(["站了颜违"])
	_check(_holds(state, "assembly.celestial.stated") and _holds(state, "assembly.celestial.yan"), "站了颜违, before the 终章: stated, 颜违")
	# 振远
	state = _fresh(["终章"])
	_check(_heard(state, &"cloud.npc.b_header", "虹台", "旧案到此为止") and _holds(state, "assembly.zhenyuan.yan") and not _listed(state, &"cloud.npc.b_header", "改投"), "振远: 颜违, nothing to turn")
	state = _fresh(["终章", "镖路查清了"])
	_check(_heard(state, &"cloud.npc.b_header", "虹台", "旧案查到底") and _confirms(state, &"cloud.npc.b_header", "改投"), "镖路查清了: 陈剑秋 would turn, asked first")
	_heard(state, &"cloud.npc.b_header", "改投", "查到底")
	_check(_holds(state, "assembly.zhenyuan.old") and not _holds(state, "assembly.zhenyuan.yan"), "振远: 旧盟主")
	# 茅山
	state = _fresh(["终章"])
	_check(_heard(state, LIN, "虹台", "主剿") and _holds(state, "assembly.maoshan.yan") and not _listed(state, LIN, "这一票"), "茅山: 颜违, 主剿")
	for mark: String in ["林忌烧了残卷", "名单递出去了"]:
		state = _fresh(["终章", mark])
		_check(_heard(state, LIN, "虹台", "茅山欠你一回"), "%s: 林忌 owes one" % mark)
		_heard(state, LIN, "这一票", "茅山听你的")
		_check(_holds(state, "assembly.maoshan.self"), "%s: 茅山听你的" % mark)
	# 晚月庄
	state = _fresh(["终章"])
	_check(_heard(state, &"common.npc.dancer.master", "虹台", "封地照旧") and _holds(state, "assembly.latemoon.old"), "晚月庄: 旧盟主")
	for mark: String in ["宝衣烧了", "宝衣给了安妮儿"]:
		state = _fresh(["终章", mark])
		_check(_heard(state, &"common.npc.dancer.master", "虹台", "逐神教") and _listed(state, &"common.npc.dancer.master", "改投") and not _listed(state, &"common.npc.dancer.master", "这一票"), "%s: 改投颜违 offered" % mark)
		_heard(state, &"common.npc.dancer.master", "改投", "投颜违")
		_check(_holds(state, "assembly.latemoon.yan") and not _holds(state, "assembly.latemoon.old"), "%s: 逐神教" % mark)
	state = _fresh(["终章", "瑷伦守到决战"])
	_check(_heard(state, &"common.npc.dancer.master", "虹台", "替晚月庄守住") and _listed(state, &"common.npc.dancer.master", "这一票"), "宝衣 with 瑷伦: 听你的 offered")
	_heard(state, &"common.npc.dancer.master", "这一票", "听你的")
	_check(_holds(state, "assembly.latemoon.self"), "宝衣 with 瑷伦: 晚月庄听你的")
	state = _fresh(["终章", "瑷伦守到决战", "瑷伦留在了冰里", "再封了侮天鬼"])
	_check(_heard(state, &"common.npc.dancer.master", "虹台", "封地照旧") and _holds(state, "assembly.latemoon.old"), "瑷伦 in the ice: no one to thank, 旧盟主")
	# 山烟寺
	state = _fresh(["终章"])
	_check(_heard(state, &"common.npc.bonze.master", "虹台", "投颜施主") and _holds(state, "assembly.sanyen.yan"), "山烟寺: 颜违, 逐神教")
	state = _fresh(["终章", "站了安妮儿"])
	_check(_heard(state, &"common.npc.bonze.master", "虹台", "容他们") and _confirms(state, &"common.npc.bonze.master", "改投"), "站了安妮儿: 玄智 would turn")
	_heard(state, &"common.npc.bonze.master", "改投", "便依施主")
	_check(_holds(state, "assembly.sanyen.old"), "山烟寺: 旧盟主")
	# 步玄
	state = _fresh(["终章", "庾子建下狱"])
	_check(_heard(state, &"common.npc.scholar.master", "虹台", "京城的意思") and _holds(state, "assembly.buxuan.yan"), "步玄 without the 名帖 used: 颜违")
	state = _fresh(["终章", "庾子建下狱", "相国府开了门", "振远的名帖敲开了相国府"])
	_check(not _heard(state, &"common.npc.scholar.master", "虹台", "骆家欠你一份情"), "the 相国府 opened by 振远's card: 骆家 owes nothing")
	state = _fresh(["终章", "庾子建下狱", "相国府开了门", "骆家的名帖敲开了相国府"])
	_check(_heard(state, &"common.npc.scholar.master", "虹台", "骆家欠你一份情"), "庾子建下狱 and the 名帖 used: 骆云舟 owes one")
	_heard(state, &"common.npc.scholar.master", "这一票", "步玄听你的")
	_check(_holds(state, "assembly.buxuan.self"), "步玄听你的")
	# 花紫会
	state = _fresh(["终章"])
	_check(_heard(state, &"common.npc.beggar.master", "虹台", "叫花子最怕官") and _holds(state, "assembly.huazi.old") and _holds(state, "assembly.huazi.stated"), "花紫会: 旧盟主, 怕官")
	# 绝尘
	state = _fresh(["终章"])
	_check(_heard(state, &"common.npc.juechen.master", "虹台", "不问世事") and _holds(state, "assembly.juechen.absent") and not _holds(state, "assembly.juechen.old"), "绝尘: 不来")
	state = _fresh(["终章", "八卦阵"])
	_check(_heard(state, &"common.npc.juechen.master", "虹台", "八卦阵") and _confirms(state, &"common.npc.juechen.master", "下山"), "走过八卦阵: 绝尘子 would come")
	_heard(state, &"common.npc.juechen.master", "下山", "老道走一趟")
	_check(_holds(state, "assembly.juechen.old") and not _holds(state, "assembly.juechen.absent"), "绝尘: 下山来, 旧盟主")
	# before the 终章 nobody talks of it
	state = _fresh([])
	_check(not _listed(state, &"cloud.npc.b_header", "虹台") and _heard(state, &"cloud.npc.b_header", "虹台", "早了") and not _holds(state, "assembly.zhenyuan.stated"), "before the 终章: 「虹台」 not listed, nothing said")
	# the count: five to change the 盟主
	state = _fresh(["终章"])
	_check(_count_of(state, "assembly.yan_wins") == 5 and _holds(state, "assembly.yan_wins"), "nothing done: 天邪, 振远, 茅山, 山烟寺, 步玄 — five for 颜违, he has it")
	state = _fresh(["终章", "跟了北宗", "站了颜违"])
	_check(_count_of(state, "assembly.yan_wins") == 6, "北宗 and 站了颜违: six")
	state = _fresh(["终章", "跟了本宗", "站了潘军禅", "振远改投旧盟主", "山烟寺改投旧盟主"])
	_check(_count_of(state, "assembly.yan_wins") == 2 and not _holds(state, "assembly.yan_wins"), "two for 颜违: the chair stays")
	state = _fresh(["终章", "跟了本宗", "站了潘军禅", "振远改投旧盟主"])
	_check(_count_of(state, "assembly.yan_wins") == 3 and not _holds(state, "assembly.yan_wins"), "three: short of five")
	for mark: String in ["封山听你的", "天邪听你的", "茅山听你的", "晚月庄听你的"]:
		state.marks[mark] = 1 # TEST-ONLY
	_check(not _holds(state, "assembly.self_backed"), "four 听你的: short")
	state.marks["步玄听你的"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.self_backed") and _count_of(state, "assembly.yan_wins") == 1, "five 听你的: only 山烟寺 left for 颜违")


## The quest shows from any line begun or the 终章, and stands first in its column.
func _test_appears(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	session.record_journal()
	_check(not StoryQuestLog.is_started(state, quest), "not there at the start")
	state.quests[StoryQuestLog.key_started(catalog.story_quest(&"faction.niling"))] = 900 # TEST-ONLY: the 卧底 line begun
	session.record_journal()
	_check(StoryQuestLog.is_started(state, quest), "there once a 势力 line begins")
	state.quests[StoryQuestLog.key_started(catalog.story_quest(&"faction.fonxan"))] = 990000 # TEST-ONLY: newer news
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, catalog.story_quests(), StoryQuestDefinition.LINE_FACTION, session.quest_condition_test())
	_check(shown.size() >= 3 and shown[0].quest.quest_id == QUEST and shown[1].quest.quest_id == &"faction.niling", "pinned first, above the 卧底's, above the newest: %s" % [shown.map(func(view: StoryQuestLog.Shown) -> StringName: return view.quest.quest_id)])
	_check(StoryQuestLog.current_step(state, quest).step_id == &"wait", "it waits on the 终章")
	var niling: StoryQuestDefinition = catalog.story_quest(&"faction.niling")
	_check(StoryQuestLog.tracked(state, [quest, niling] as Array[StoryQuestDefinition]) == niling, "the HUD keeps the line's step, not the 大会 that waits")


## With no line begun, the 终章 brings it, at the invitation.
func _test_appears_after(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	state.marks["终章"] = 1 # TEST-ONLY: the main story over, no line
	session.record_journal()
	_check(StoryQuestLog.is_started(state, quest) and StoryQuestLog.current_step(state, quest).step_id == &"invite", "after the 终章 with no line: there, at the invitation")


## 已表态 x／9 and the rows in a few states.
func _test_counts(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	for mark: String in ["跟了本宗", "站了潘军禅"]:
		state.marks[mark] = 1 # TEST-ONLY: both lines split, before the 终章
	for line: StringName in [&"faction.fonxan", &"faction.celestial"]:
		state.quests[StoryQuestLog.key_started(GameContent.catalog().story_quest(line))] = 900 # TEST-ONLY: the lines begun
	session.record_journal()
	var view: StoryQuestLog.Shown = _view(session)
	_check(view != null and _row(view, "已表态") != null and _row(view, "已表态").have == 2 and _row(view, "已表态").want == 9, "two lines split: 2／9")
	_check(_row(view, "封山剑派：等盟主回来") != null and _row(view, "天邪派：等盟主回来") != null and _row(view, "振远镖局：还没表态") != null and _row(view, "绝尘派：还没表态") != null, "封山 and 天邪 said, the rest not yet")
	_check(_row(view, "投颜违") != null and _row(view, "投颜违").have == 0 and _row(view, "投颜违").want == 5, "颜违: none said for him yet, of five")
	var text: String = _shown(session)
	_check(text.contains("已表态") and text.contains("封山剑派：等盟主回来"), "the 任务 page shows them")
	for mark: String in ["终章", "振远表了态", "茅山表了态", "晚月庄表了态"]:
		state.marks[mark] = 1 # TEST-ONLY: three heads asked
	session.record_journal()
	view = _view(session)
	_check(_row(view, "已表态").have == 5 and _row(view, "振远镖局：投颜违——旧案到此为止") != null and _row(view, "茅山派：投颜违——主剿") != null and _row(view, "晚月庄：投旧盟主——封地照旧") != null, "five said: what each votes")
	_check(_row(view, "投颜违").have == 2, "two said for 颜违")
	for mark: String in ["山烟寺表了态", "步玄表了态", "花紫会表了态", "绝尘表了态", "八卦阵", "绝尘子肯下山", "绝尘派肯来"]:
		state.marks[mark] = 1 # TEST-ONLY: all asked, 绝尘子 coming
	session.record_journal()
	view = _view(session)
	_check(_row(view, "已表态").have == 9 and _row(view, "绝尘派：下山来，投旧盟主") != null and _row(view, "绝尘派：不问世事，不来") == null, "9／9, 绝尘 coming")
	_check(_rows_for(view, "振远镖局：") == 1 and _rows_for(view, "封山剑派：") == 1, "one row a 派")


## 饮风客栈's 店小二: the invitation, once.
func _test_invitation(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	var before: WorldMapController = MapPlaces.enter(session, INN, INN_POINT)
	await _settle(tree)
	var waiter: NpcRuntimeState = _first(session, INN, WAITER)
	_check(waiter != null and before.select_npc(waiter.character_id) and not before.ask_topics_selected().has("请柬"), "before the 终章: no invitation")
	state.marks["终章"] = 1 # TEST-ONLY: the main story over
	session.record_journal()
	MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry")
	await _settle(tree)
	var inn: WorldMapController = MapPlaces.enter(session, INN, INN_POINT)
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("拿了虹台请柬", 0) == 1 and _invitations(session) == 1, "back in the inn: the 店小二 hands it over")
	waiter = _first(session, INN, WAITER)
	_check(_said(_ask(inn, waiter, "请柬"), "早给您了") and _invitations(session) == 1, "asked again: only once")
	MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry")
	await _settle(tree)
	MapPlaces.enter(session, INN, INN_POINT)
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(_invitations(session) == 1, "back again: no second")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"canvass", "the quest on to the nine")


## The 虹台: up the stair south of 葬剑亭, round the platform to the lip over 虹谷, and back.
func _test_terrace(tree: SceneTree, session: WorldSessionController) -> void:
	var tomb: WorldMapController = MapPlaces.enter(session, TOMB, TOMB_POINT)
	await _settle(tree)
	_check(await MapPlaces.take_passage(tree, tomb, &"waterfog.swordtomb.south") and session.active_map().map_id() == &"waterfog.terrace", "south from 葬剑亭: the stair to the 虹台")
	var terrace: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	_check(await MapPlaces.drive_through(tree, terrace, [&"waterfog.terrace_stair", &"waterfog.terrace_top", &"waterfog.terrace_edge", &"waterfog.terrace_top"] as Array[StringName]), "up the stair, onto the platform, out to the lip")
	_check(_count_on(session, &"waterfog.terrace_top") == 0, "empty but on the day")
	_check(await MapPlaces.take_passage(tree, terrace, &"waterfog.terrace_stair.north") and session.active_map().map_id() == &"waterfog.mountain", "down the stair to 葬剑亭")


## After the 终章 the 余孽: 剿 by 林忌's letter.
func _test_remnant_crushed(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var niling: StoryQuestDefinition = GameContent.catalog().story_quest(&"faction.niling")
	_remnant(session)
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_check(_said(_ask(temple, lin, "逆灵宫"), "问我「剿」") and state.marks.get("林忌说了余孽", 0) == 1, "林忌 asks for a 了断")
	_check(temple.select_npc(lin.character_id) and temple.ask_topics_selected().has("剿") and temple.ask_topics_selected().has("招安"), "剿 and 招安 to choose")
	_check(lin.definition().talk().confirm_applies("剿", state.marks), "剿 asked first")
	_check(_said(_ask(temple, lin, "剿"), "程不平") and state.marks.has("余孽交了官府") and state.marks.has("余孽有了去处"), "剿: the letter to 程不平")
	_check(not lin.definition().talk().confirm_applies("招安", state.marks) and _said(_ask(temple, lin, "招安"), "来不及了") and not state.marks.has("林忌要招安"), "no 招安 after")
	_check(not _confirms(state, &"native.npc.niling_lead_chanter", "下山") and _heard(state, &"native.npc.niling_lead_chanter", "下山", "送死") and not state.marks.has("招安了余孽"), "no 下山 after the 官兵")
	session.record_journal()
	_check(StoryQuestLog.took(state, niling, &"crush") and StoryQuestLog.is_done(state, niling), "the 卧底 line ends: 剿")


## After the 终章 the 余孽: 招安, the word 「下山」 to the 领诵 where 玄冥子 does not live.
func _test_remnant_pardoned(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var niling: StoryQuestDefinition = GameContent.catalog().story_quest(&"faction.niling")
	_remnant(session)
	var temple: WorldMapController = MapPlaces.enter(session, TEMPLE, TEMPLE_POINT)
	await _settle(tree)
	var lin: NpcRuntimeState = _first(session, TEMPLE, LIN)
	_ask(temple, lin, "逆灵宫")
	_check(_said(_ask(temple, lin, "招安"), "下山") and state.marks.has("林忌要招安") and not state.marks.has("余孽有了去处"), "招安: go and say 下山")
	_check(not lin.definition().talk().confirm_applies("剿", state.marks) and _said(_ask(temple, lin, "剿"), "回北麓去") and not state.marks.has("余孽交了官府"), "no 剿 once 招安 is under way")
	var map: WorldMapController = MapPlaces.enter(session, FRONT, FRONT_POINT)
	session.wear_player_item(map.give_new_item_to_player(CROWN)) # TEST-ONLY: still in the crown
	await _settle(tree)
	var chanter: NpcRuntimeState = _first(session, FRONT, CHANTER)
	_check(chanter != null and map.select_npc(chanter.character_id) and map.ask_topics_selected().has("下山"), "the 领诵 hears 下山")
	_check(_said(_ask(map, chanter, "下山"), "下山就下山") and state.marks.has("招安了余孽") and state.marks.has("余孽有了去处"), "招安: they come down")
	session.record_journal()
	_check(StoryQuestLog.took(state, niling, &"pardon") and StoryQuestLog.is_done(state, niling), "the 卧底 line ends: 招安")


func _remnant(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.niling_scripture(session, "night", false)
	for mark: String in ["岚城一章", "下了决战", "商玦倒了", "终章"]:
		state.marks[mark] = 1 # TEST-ONLY: the main story over
	session.record_journal()


## A state with only these marks (the rules and the named votes read nothing else).
func _fresh(marks: Array) -> CharacterState:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY
	return state


func _holds(state: CharacterState, condition_id: String) -> bool:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	return JournalLog.holds(GameContent.catalog().conditions()[condition_id], state, temps, held)


## How many of an at_least's parts hold.
func _count_of(state: CharacterState, condition_id: String) -> int:
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	var found: int = 0
	for part: JournalEntryDefinition in GameContent.catalog().conditions()[condition_id].parts:
		if JournalLog.holds(part, state, temps, held):
			found += 1
	return found


## Asks `npc` `topic` as the rules decide (TEST-ONLY: the marks the answer sets set on the state);
## whether what it says holds `part`.
func _heard(state: CharacterState, npc: StringName, topic: String, part: String) -> bool:
	var talk: NpcTalk = GameContent.catalog().npc(npc).talk()
	var rule: NpcInquiryRule = NpcInquiryRule.decide(talk.inquiry_rules(topic), state.marks)
	if rule == null:
		return false
	if not rule.mark_asker.is_empty():
		state.marks[rule.mark_asker] = 1 # TEST-ONLY: as the ask records it
	for mark: String in rule.marks_asker:
		state.marks[mark] = 1 # TEST-ONLY
	return rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains(part))


func _listed(state: CharacterState, npc: StringName, topic: String) -> bool:
	return GameContent.catalog().npc(npc).talk().listed_for(topic, state.marks)


func _confirms(state: CharacterState, npc: StringName, topic: String) -> bool:
	var talk: NpcTalk = GameContent.catalog().npc(npc).talk()
	return talk.listed_for(topic, state.marks) and talk.confirm_applies(topic, state.marks) and not talk.ask_confirm(topic).is_empty()


func _view(session: WorldSessionController) -> StoryQuestLog.Shown:
	var state: CharacterState = session.player_runtime().state
	for view: StoryQuestLog.Shown in StoryQuestLog.shown(state, GameContent.catalog().story_quests(), StoryQuestDefinition.LINE_FACTION, session.quest_condition_test()):
		if view.quest.quest_id == QUEST:
			return view
	return null


func _row(view: StoryQuestLog.Shown, label: String) -> StoryQuestLog.Checked:
	if view == null:
		return null
	for row: StoryQuestLog.Checked in view.checklist:
		if row.row.label == label:
			return row
	return null


func _rows_for(view: StoryQuestLog.Shown, prefix: String) -> int:
	return view.checklist.filter(func(row: StoryQuestLog.Checked) -> bool: return row.row.label.begins_with(prefix)).size()


func _invitations(session: WorldSessionController) -> int:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var found: int = 0
	for id: StringName in context.inventory.direct_children(context.endpoint()):
		var item: ItemInstance = context.index.resolve(id)
		if item != null and item.item_definition_id == INVITE:
			found += 1
	return found


func _shown(session: WorldSessionController) -> String:
	var ui: SharedGameplayUI = session.shared_ui()
	ui.quest_page.fill(session.player_runtime().state, "小兄弟", "", session.quest_condition_test())
	return ui.quest_page.shown_text()


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _count_on(session: WorldSessionController, zone_id: StringName) -> int:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return 0
	return map.resident_npcs().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map and npc.world_location().zone_id == zone_id).size()


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE) and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("虹台", CharacterState.GENDER_MALE)
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
