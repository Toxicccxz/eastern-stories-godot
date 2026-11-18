extends RefCounted

## 势力线第三批 步玄 B (计划 势力线第三批_计划.md §5 步玄 B, §8 第 3、5 行; DECISIONS「步玄 B」): 骆云舟 told of the
## 兵部抄本 (the stub `home`) goes to the capital; in the 相国府's hall the brothers meet, 韦执中 sitting by (the scene);
## the split — 作证 with 骆云舟 (骆建章's 供状: one more witness to 第九章's 揭发 while it is open; exiled to 关北 once
## 庾子建 is in prison; the case reopened at 乔阴 after 私了 or the 皇叔's pardon; 步玄 votes the old 盟主) or 回家 with
## 骆建章 (home to the 曼雩台, copying 步玄's scores; 步玄 votes 颜违); 执事 for 步玄's own; either side 这一票; the
## 虹台's 步玄 row; the ending's 乔阴 and 京师 lines.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.buxuan"
const LUO: StringName = &"common.npc.scholar.master"
const LUO_CITY: StringName = &"native.npc.luo_yunzhou_capital"
const BROTHER: StringName = &"native.npc.luo_jianzhang"
const WEI: StringName = &"native.npc.wei_zhizhong"
const CHENG: StringName = &"choyin.npc.judgeman"
const ENTRANCE: StringName = &"choyin.entrance"
const ENTRANCE_POINT: StringName = &"choyin.entrance.grove_return"
const HALL: StringName = &"city.xiangguo_hall"
const HALL_POINT: StringName = &"city.xiangguo_hall.luo_yunzhou.1"
const YARD: StringName = &"city.xiangguo_yard"
const YARD_POINT: StringName = &"city.xiangguo_yard.gate_arrival"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_votes()
	_test_chapter_ends()
	for test: Callable in [_test_testify_open, _test_testify_prison, _test_home]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_home else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"sword", &"letter", &"brother", &"copy", &"home", &"meet", &"split"], "步玄 B's steps after 步玄 A's: %s" % [ids])
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == "big" and split.options.size() == 2, "the split: one big choice, two sides")
	for option: StoryQuestDefinition.Option in split.options:
		_check(option.reward.rank_title == "执事" and option.reward.rank_family == &"family.buxuan" and not option.reward.deed.is_empty(), "%s: 执事 for 步玄's own, a deed" % option.option_id)
	_check(quest.step(&"meet").target.map_id == &"city.xiangguo" and quest.step(&"meet").target.zone_id == HALL, "the brothers meet in the 相国府's hall")
	var luo: NpcDefinition = catalog.npc(LUO_CITY)
	_check(luo != null and luo.display_name == "骆云舟" and luo.hooks().always_kept, "骆云舟 in the capital, only knocked down")
	var testify: String = luo.talk().ask_confirm("作证")
	_check(testify.contains("旧盟主") and testify.contains("流放") and testify.contains("重开") and testify.contains("人证"), "作证 asked first, its cost in full: %s" % testify)
	var home: String = catalog.npc(BROTHER).talk().ask_confirm("回家")
	_check(home.contains("颜违") and home.contains("抄谱") and home.contains("不扣"), "回家 asked first, its cost in full: %s" % home)
	_check(not luo.talk().confirm_applies("作证", {"骆家兄弟见了面": 1, "保住了骆家": 1}) and not catalog.npc(BROTHER).talk().confirm_applies("回家", {"骆家兄弟见了面": 1, "骆建章作了证": 1}), "one side taken: the other not asked")
	# 第九章's 揭发: 骆建章's 供状 one of the witnesses (two needed; three after the 关北 raid), told in both short branches.
	var expose: ServiceDefinition = catalog.service(&"imperial.front_hall.expose")
	var go: ScriptedAct = null
	var told: int = 0
	for act: ScriptedAct in expose.act.acts:
		if act.choice == "朝上揭发":
			go = act
		for step: ScriptedAct.Step in act.steps:
			if step.only_when != null and step.only_when.when == JournalEntryDefinition.When.MARK and step.only_when.key == "骆建章作了证":
				told += 1
	_check(told == 2, "骆建章's 供状 told in both short-of-evidence branches (%d)" % told)
	_check(go != null and not JournalLog.holds(go.when, _fresh(["对出了原令", "陈显祖作了证"]), {}, {}) and JournalLog.holds(go.when, _fresh(["对出了原令", "陈显祖作了证", "骆建章作了证"]), {}, {}), "the 供状 makes two")
	_check(not JournalLog.holds(go.when, _fresh(["对出了原令", "踏平了工地", "陈显祖作了证", "骆建章作了证"]), {}, {}) and JournalLog.holds(go.when, _fresh(["对出了原令", "踏平了工地", "陈显祖作了证", "骆建章作了证", "跟李信揭发"]), {}, {}), "after the raid: three, the 供状 one of them")
	var assembly: StoryQuestDefinition = catalog.story_quest(&"faction.assembly")
	_check(assembly.checklist.any(func(row: StoryQuestDefinition.CheckRow) -> bool: return row.label.contains("步玄派：投旧盟主")), "the 虹台 list has 步玄's old 盟主 row")
	var spawn: NpcSpawnDefinition = catalog.spawn(&"native.xiangguo.luo_yunzhou")
	_check(spawn != null and spawn.npc_definition_id == LUO_CITY, "骆云舟's spawn in the 相国府")
	_check(catalog.spawn(&"native.entrance.luo_jianzhang") != null, "骆建章's spawn on the 曼雩台")


## 虹台的票: 回家 (or no line) 颜违; 作证 before sitting the old 盟主; either side 听你的 by 这一票; one who never walked the
## line keeps 大会 A's way (庾子建 in prison and the 骆家 card at the 相国府); a split after sitting changes nothing.
func _test_votes() -> void:
	var state: CharacterState = _fresh(["终章"])
	_check(_holds(state, "assembly.buxuan.yan") and not _holds(state, "assembly.buxuan.old") and not _holds(state, "assembly.buxuan.stated"), "no line: 颜违, not yet stated (as 大会 A)")
	state = _fresh(["骆建章作了证", "步玄的票随了作证"])
	_check(_holds(state, "assembly.buxuan.old") and not _holds(state, "assembly.buxuan.yan") and _holds(state, "assembly.buxuan.stated"), "作证: the old 盟主, stated")
	state = _fresh(["保住了骆家", "步玄的票随了骆家"])
	_check(_holds(state, "assembly.buxuan.yan") and _holds(state, "assembly.buxuan.stated"), "回家: 颜违, stated")
	state = _fresh(["骆建章作了证"])
	_check(_holds(state, "assembly.buxuan.yan") and not _holds(state, "assembly.buxuan.old"), "作证 after sitting: the vote as it was cast")
	state = _fresh(["终章", "骆建章作了证", "步玄的票随了作证"])
	_check(_heard(state, LUO, "虹台", "旧盟主") and _listed(state, LUO, "这一票") and _heard(state, LUO, "这一票", "步玄听你的") and _holds(state, "assembly.buxuan.self") and not _holds(state, "assembly.buxuan.old"), "作证: 骆云舟 gives the vote")
	state.marks["入了虹台的席"] = 1
	state.marks["九派到了"] = 1
	state.marks["听你的投旧盟主"] = 1
	_check(_holds(state, "assembly.day.buxuan.old") and _holds(state, "assembly.day.buxuan.backs"), "on the day: 听你的, sent to the old 盟主")
	state = _fresh(["入了虹台的席", "九派到了", "骆建章作了证", "步玄的票随了作证"])
	_check(_holds(state, "assembly.day.buxuan.old") and not _holds(state, "assembly.day.buxuan.yan"), "on the day: 作证's old 盟主")
	state = _fresh(["终章", "保住了骆家", "步玄的票随了骆家"])
	_check(_heard(state, LUO, "虹台", "带回来的") and _listed(state, LUO, "这一票") and _heard(state, LUO, "这一票", "步玄听你的") and _holds(state, "assembly.buxuan.self"), "回家: 骆云舟 gives the vote")
	state = _fresh(["终章", "庾子建下狱", "骆家的名帖敲开了相国府"])
	_check(_heard(state, LUO, "虹台", "敲开相国府") and _listed(state, LUO, "这一票"), "no line, 公文路: 大会 A's way")
	state = _fresh(["终章"])
	_check(_heard(state, LUO, "虹台", "我姓骆") and not _listed(state, LUO, "这一票"), "no line otherwise: 颜违, no vote to give")
	# A split taken after sitting writes no vote mark (票就是票了).
	state = _fresh(["骆家兄弟见了面", "入了虹台的席"])
	_check(_heard(state, LUO_CITY, "作证", "按了手印") and state.marks.has("骆建章作了证") and not state.marks.has("步玄的票随了作证"), "作证 after sitting: no vote mark")
	state = _fresh(["骆家兄弟见了面", "入了虹台的席"])
	_check(_heard(state, BROTHER, "回家", "带我回乔阴") and state.marks.has("保住了骆家") and not state.marks.has("步玄的票随了骆家"), "回家 after sitting: no vote mark")
	# The scene cut short (its scene_mark only): both sides still answer.
	state = _fresh(["骆家兄弟见了面"])
	_check(_listed(state, LUO_CITY, "作证") and _listed(state, BROTHER, "回家"), "the scene cut short: both listed")


## 作证 by 第九章's end: open (one more witness), 私了 / 皇叔 (the case reopened at 乔阴: 程不平, the card), 揭发 done (exiled);
## the ending's lines for each.
func _test_chapter_ends() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state: CharacterState = _fresh(["骆家兄弟见了面"])
	_check(_heard(state, LUO_CITY, "作证", "一样人证") and state.marks.has("骆建章作了证") and state.marks.has("步玄的票随了作证") and not state.marks.has("庾子建的案子又开了") and not state.marks.has("骆建章判了流放"), "第九章 open: a witness for 揭发")
	for chapter: String in ["私了了庾子建", "皇叔的通缉解了"]:
		state = _fresh(["骆家兄弟见了面", chapter])
		_check(_heard(state, LUO_CITY, "作证", "重开") and state.marks.has("庾子建的案子又开了") and not state.marks.has("骆建章判了流放"), "%s: the case reopened" % chapter)
		_check(state.marks.has("供状送了乔阴") and not state.marks.has("李信的账送了乔阴"), "%s: the 供状 sent to 乔阴" % chapter)
		state.marks["程不平写了信"] = 1
		_check(_heard(state, CHENG, "捕快", "骆建章的供状") and not _heard(state, CHENG, "捕快", "天驼关的账"), "%s: 程不平 on the 供状 alone" % chapter)
		_check(_card_says(state, &"choyin", "骆建章的一张供状") and not _card_says(state, &"choyin", "天驼关那本账") and _card_says(state, &"choyin", "还是骆云舟一个人"), "%s: the 乔阴 card" % chapter)
		_check(_card_says(state, &"city", "乔阴县衙也有一份") and not _card_says(state, &"city", "收在袖子里") and not _card_says(state, &"city", "流放"), "%s: the 京师 card" % chapter)
	# 官府 B's 李信 heard, then the 皇叔's way (his ledger never sent): only the 供状 goes to 乔阴.
	state = _fresh(["骆家兄弟见了面", "皇叔的通缉解了", "李信说了那三天的账", "程不平写了信"])
	_check(_heard(state, LUO_CITY, "作证", "重开") and _heard(state, CHENG, "捕快", "骆建章的供状") and not _heard(state, CHENG, "捕快", "天驼关的账") and not _card_says(state, &"choyin", "天驼关那本账"), "李信's ledger heard but not sent: 程不平 and the card speak of the 供状 only")
	# Both sent (官府 B's ledger, then the 供状): 程不平 has both, the card says both.
	state = _fresh(["程不平写了信", "庾子建的案子又开了", "李信的账送了乔阴", "供状送了乔阴", "骆建章作了证"])
	_check(_heard(state, CHENG, "捕快", "骆建章的供状") and _heard(state, CHENG, "捕快", "天驼关的账") and _card_says(state, &"choyin", "天驼关那本账") and _card_says(state, &"choyin", "骆建章的一张供状"), "the ledger and the 供状 both at 乔阴")
	# 作证 while 第九章 was open, settled privately after: the 供状 stays with 韦执中.
	state = _fresh(["骆建章作了证", "私了了庾子建"])
	_check(_card_says(state, &"city", "收在袖子里") and not _card_says(state, &"city", "乔阴县衙也有一份") and not _card_says(state, &"choyin", "供状"), "作证 first, 私了 after: the 供状 in 韦执中's sleeve")
	state = _fresh(["骆家兄弟见了面", "庾子建下狱"])
	var rule: NpcInquiryRule = NpcInquiryRule.decide(catalog.npc(LUO_CITY).talk().inquiry_rules("作证"), state.marks)
	_check(rule != null and rule.also_leaves == BROTHER, "揭发 done: 骆建章 taken to the 刑部 at once")
	_check(_heard(state, LUO_CITY, "作证", "流放") and state.marks.has("骆建章判了流放") and not state.marks.has("庾子建的案子又开了"), "揭发 done: exiled")
	_check(_card_says(state, &"city", "流放关北") and not _card_says(state, &"city", "朝上那天"), "揭发 done: the 京师 card")
	state = _fresh(["骆建章作了证", "庾子建下狱"])
	_check(_card_says(state, &"city", "朝上那天") and not _card_says(state, &"city", "流放"), "作证 while open, then 揭发: at the court that day")
	state = _fresh(["保住了骆家", "庾子建下狱"])
	_check(_card_says(state, &"choyin", "多了一张书案") and not _card_says(state, &"city", "骆建章"), "回家: two on the 曼雩台, nothing in the capital")
	state = _fresh(["庾子建的案子又开了", "李信说了那三天的账", "李信的账送了乔阴"])
	_check(_card_says(state, &"choyin", "天驼关那本账") and not _card_says(state, &"choyin", "供状"), "官府 B's reopened case as before")
	_check(_heard(_fresh(["程不平写了信", "李信的账送了乔阴"]), CHENG, "捕快", "天驼关的账"), "程不平 on 官府 B's ledger as before")
	# The 相国府's gate opens for one 骆云舟 sent, with no card.
	var knock: ServiceDefinition = catalog.service(&"city.xiangguo_gate.knock")
	var sent: Array = knock.act.acts.filter(func(act: ScriptedAct) -> bool: return act.mark == "骆云舟听了抄本的事")
	_check(sent.size() == 1 and (sent[0] as ScriptedAct).steps.size() == 4, "the 相国府's gate: 骆二爷吩咐过")


## A 桃林的客, 第九章 still open: 骆云舟 told; to the capital; the scene in the hall; 作证; the 供状 counts for 揭发; 骆建章
## stays at the 相国府, 骆云舟 gone; 虹台 and 这一票; the 声望 page.
func _test_testify_open(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.buxuan_copied(session)
	session.record_journal()
	_check(_step(session) == &"home", "the line at `home`: %s" % _step(session))
	var entrance: WorldMapController = MapPlaces.enter(session, ENTRANCE, ENTRANCE_POINT)
	await _settle(tree)
	var said: Array[String] = _ask(entrance, _first(session, ENTRANCE, LUO), "骆家")
	_check(_said(said, "进京一趟") and state.marks.get("骆云舟听了抄本的事", 0) == 1, "骆云舟 told: %s" % [said])
	session.record_journal()
	_check(_step(session) == &"meet" and _target(session).zone_id == HALL, "next: the 相国府's hall")
	_check(_first(session, ENTRANCE, BROTHER) == null, "no 骆建章 on the 曼雩台")
	var hall: WorldMapController = await _to_hall_scene(tree, session)
	var luo: NpcRuntimeState = _first(session, HALL, LUO_CITY)
	_check(luo != null and hall.select_npc(luo.character_id) and hall.ask_topics_selected().has("作证"), "作证 listed on 骆云舟")
	_check(luo.definition().talk().confirm_applies("作证", state.marks), "作证 is asked first")
	said = _ask(hall, luo, "作证")
	_check(_said(said, "一样人证") and state.marks.get("骆建章作了证", 0) == 1 and state.marks.get("步玄的票随了作证", 0) == 1, "作证: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.buxuan/split/testify") and state.quests.has("faction.buxuan#done") and DeedLog.done(state, "陪骆建章写下了兵部抄本的供状") and state.affiliation.family_title != "执事", "the split: 作证, its deed, the line done; no rank for a guest")
	_check(_first(session, HALL, BROTHER) != null, "骆建章 stays in the hall until one leaves")
	for mark: String in ["对出了原令", "陈显祖作了证"]:
		state.marks[mark] = 1 # TEST-ONLY: 第九章, one witness of its own
	var expose: ServiceDefinition = catalog.service(&"imperial.front_hall.expose")
	var go: Array = expose.act.acts.filter(func(act: ScriptedAct) -> bool: return act.choice == "朝上揭发")
	_check(go.size() == 1 and JournalLog.holds((go[0] as ScriptedAct).when, state, {}, {}), "揭发: 陈显祖 and the 供状 are enough")
	hall = await _reenter_hall(tree, session)
	_check(_first(session, HALL, LUO_CITY) == null and _first(session, HALL, BROTHER) != null, "back in the hall: 骆云舟 gone home, 骆建章 kept here for the 刑部")
	_check(_said(_ask(hall, _first(session, HALL, BROTHER), "抄本"), "从此是我的罪"), "骆建章 on the 抄本")
	_check(_said(_ask(hall, _first(session, HALL, WEI), "骆建章"), "供状"), "韦执中 keeps the 供状")
	state.marks["终章"] = 1 # TEST-ONLY: the main story over
	entrance = MapPlaces.enter(session, ENTRANCE, ENTRANCE_POINT)
	await _settle(tree)
	var master: NpcRuntimeState = _first(session, ENTRANCE, LUO)
	_check(_said(_ask(entrance, master, "骆家"), "门匾"), "骆云舟 at home on the 作证")
	_check(_said(_ask(entrance, master, "虹台"), "旧盟主") and state.marks.get("步玄肯听你的", 0) == 1 and _holds(state, "assembly.buxuan.old"), "虹台: the old 盟主, would 听你的")
	_check(_said(_ask(entrance, master, "这一票"), "步玄听你的") and _holds(state, "assembly.buxuan.self"), "这一票")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	_check(session.shared_ui().standing_page.shown_text().contains("骆建章写了供状"), "the 声望 page says so")


## 骆云舟's own, 庾子建 already in prison: 作证 — 骆建章 taken to the 刑部 at once and exiled; 执事.
func _test_testify_prison(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.buxuan_copied(session, true)
	state.marks["庾子建下狱"] = 1 # TEST-ONLY: 第九章's 揭发
	state.marks["骆云舟听了抄本的事"] = 1 # TEST-ONLY: 骆云舟 told
	StoryFixtures._write(state, "faction.buxuan/home")
	var hall: WorldMapController = await _to_hall_scene(tree, session)
	var said: Array[String] = _ask(hall, _first(session, HALL, LUO_CITY), "作证")
	_check(_said(said, "流放") and state.marks.get("骆建章判了流放", 0) == 1, "揭发 done: he confesses and is exiled (%s)" % [said])
	_check(_first(session, HALL, BROTHER) == null, "taken to the 刑部 at once")
	session.record_journal()
	_check(state.quests.has("faction.buxuan/split/testify") and state.affiliation.family_title == "执事", "步玄's own: 执事 (%s)" % state.affiliation.family_title)
	hall = await _reenter_hall(tree, session)
	_check(_first(session, HALL, BROTHER) == null and _first(session, HALL, LUO_CITY) == null, "neither back in the hall")
	_check(_said(_ask(hall, _first(session, HALL, WEI), "骆建章"), "关北"), "韦执中: gone to 关北")


## A woman, 桃林的客: 回家 — the brothers go home; 骆建章 on the 曼雩台 with his scores; 虹台 and 这一票; the 声望 page.
func _test_home(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.buxuan_copied(session)
	state.marks["骆云舟听了抄本的事"] = 1 # TEST-ONLY: 骆云舟 told
	StoryFixtures._write(state, "faction.buxuan/home")
	var hall: WorldMapController = await _to_hall_scene(tree, session)
	var brother: NpcRuntimeState = _first(session, HALL, BROTHER)
	_check(brother != null and hall.select_npc(brother.character_id) and hall.ask_topics_selected().has("回家"), "回家 listed on 骆建章")
	_check(brother.definition().talk().confirm_applies("回家", state.marks), "回家 is asked first")
	var said: Array[String] = _ask(hall, brother, "回家")
	_check(_said(said, "带我回乔阴") and state.marks.get("保住了骆家", 0) == 1 and state.marks.get("步玄的票随了骆家", 0) == 1, "回家: %s" % [said])
	session.record_journal()
	_check(state.quests.has("faction.buxuan/split/home") and state.quests.has("faction.buxuan#done"), "the split: 回家, the line done")
	_check(not _said(_ask(hall, _first(session, HALL, LUO_CITY), "作证"), "按了手印") and not state.marks.has("骆建章作了证"), "作证 closed")
	hall = await _reenter_hall(tree, session)
	_check(_first(session, HALL, BROTHER) == null and _first(session, HALL, LUO_CITY) == null, "the hall empty of 骆家")
	var entrance: WorldMapController = MapPlaces.enter(session, ENTRANCE, ENTRANCE_POINT)
	await _settle(tree)
	brother = _first(session, ENTRANCE, BROTHER)
	_check(brother != null and entrance.select_npc(brother.character_id) and entrance.ask_topics_selected().has("抄谱") and _said(_ask(entrance, brother, "抄谱"), "一部谱"), "骆建章 on the 曼雩台, copying the scores")
	state.marks["终章"] = 1 # TEST-ONLY: the main story over
	var master: NpcRuntimeState = _first(session, ENTRANCE, LUO)
	_check(_said(_ask(entrance, master, "骆家"), "抄谱"), "骆云舟 on his brother")
	_check(_said(_ask(entrance, master, "虹台"), "颜违") and state.marks.get("步玄肯听你的", 0) == 1 and _holds(state, "assembly.buxuan.yan"), "虹台: 颜违, would 听你的")
	_check(_said(_ask(entrance, master, "这一票"), "步玄听你的") and _holds(state, "assembly.buxuan.self"), "这一票")
	session.shared_ui().standing_page.fill(session.quest_condition_test())
	_check(session.shared_ui().standing_page.shown_text().contains("带大哥回了乔阴"), "the 声望 page says so")


## Into the 相国府's hall from another map (stage people come on as one enters a map): the brothers' scene to its end.
func _to_hall_scene(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var hall: WorldMapController = await _reenter_hall(tree, session)
	_check(_first(session, HALL, LUO_CITY) != null and _first(session, HALL, BROTHER) != null and _first(session, HALL, WEI) != null, "骆云舟, 骆建章 and 韦执中 in the hall")
	var lines: Array[String] = await _scene(tree, session, hall)
	var marks: Dictionary[String, int] = session.player_runtime().state.marks
	_check(_said(lines, "大哥。") and _said(lines, "你上堂") and _said(lines, "跟我回乔阴") and marks.get("骆家兄弟见了面", 0) == 1 and marks.get("骆家兄弟说完了话", 0) == 1, "the scene in the hall, played out: %s" % [lines.slice(-8)])
	session.record_journal()
	_check(_step(session) == &"split", "the split next (%s)" % _step(session))
	return hall


func _reenter_hall(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	MapPlaces.enter(session, ENTRANCE, ENTRANCE_POINT)
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


func _card_says(state: CharacterState, card_id: StringName, part: String) -> bool:
	for card: EpilogueDefinition.Card in GameContent.catalog().epilogue(&"ending").cards:
		if card.card_id != card_id:
			continue
		for line: EpilogueDefinition.Line in card.lines:
			if line.text.contains(part) and (line.condition == null or JournalLog.holds(line.condition, state, {}, {})):
				return true
	return false


func _step(session: WorldSessionController) -> StringName:
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(session.player_runtime().state, GameContent.catalog().story_quest(QUEST))
	return &"" if step == null else step.step_id


func _target(session: WorldSessionController) -> StoryQuestDefinition.Target:
	var state: CharacterState = session.player_runtime().state
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, GameContent.catalog().story_quest(QUEST))
	return null if step == null else step.target_for(state.marks)


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
	session.configure_source_entry("步玄", gender)
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
