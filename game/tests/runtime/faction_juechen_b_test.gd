extends RefCounted

## 势力线第三批 绝尘 B (计划 势力线第三批_计划.md §7 绝尘 B, §3 三十年前, §8 第 8 行与「要改大会的地方」; DECISIONS「绝尘 B」):
## the stub `xuanchen` filled — 了尘「师父」 tells of thirty years ago (the 樵夫 for one who walked 山烟寺 A); 绝尘子「玄尘」
## owns the name (a word for 山烟寺 B's split and for what 龙若 said) and 了尘 goes down on his knees before the Buddha:
## the scene; the big split: 守阵 (了尘 stands again behind his master; 绝尘子 teaches one not of 绝尘派 the 奇门遁甲 and its
## 小天魔道; 绝尘派 comes and votes the old 盟主) or 下山 (了尘 to 流云轩, by the stove or beside the 头陀; he teaches anyone
## the 金刚杖法; he sits 绝尘派's seat and votes 颜违); 执事 for 绝尘派's own; both may hand the vote over (绝尘 听你的: nine
## 派); one who never walked the line keeps the old way (走过八卦阵, 下山).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.juechen"
const FAMILY: StringName = &"family.juechen"
const MASTER: StringName = &"common.npc.juechen.master"
const ELDER: StringName = &"green.npc.oldman2"
const LIAOCHEN: StringName = &"native.npc.juechen_liaochen"
const KNEEL: StringName = &"native.npc.liaochen_kneel"
const SANYEN_LC: StringName = &"native.npc.liaochen_sanyen"
const SEAT_LC: StringName = &"native.npc.assembly_liaochen"
const XUANZHI: StringName = &"common.npc.bonze.master"
const HALL: StringName = &"green.cavehall"
const HALL_POINT: StringName = &"green.cavehall.stoneroom_arrival"
const HOUSE4: StringName = &"green.house4"
const HOUSE4_POINT: StringName = &"green.house4.field0_entry"
const HEAL: StringName = &"sanyen.heal_room"
const HEAL_POINT: StringName = &"sanyen.heal_room.inner_yard_entry"
const TEMPLE: StringName = &"sanyen.temple"
const TEMPLE_POINT: StringName = &"sanyen.temple.road1_entry"
## 绝尘 A walked to its end (the marks its steps write).
const A_MARKS: Array[String] = ["宝衣一章", "村长说了山洞", "洞口的鬼卒倒了", "洞底的鬼卒倒了", "阿牛跟着你", "孩子回了家", "村长说完了那句话", "绝尘子听了山洞", "了尘说了洞里的事"]
## 山烟寺 A and B walked by the 头陀's way, the sutra taken (and 龙若's 玄尘 heard).
const SANYEN_TAKE: Array[String] = ["喂了樵夫药", "头陀进了流云轩", "龙若说了三十年前", "龙若说了玄尘", "龙若说了没点化玄尘", "头陀上了大殿", "山烟寺收了经"]
## 山烟寺 A by the rule, B kept to its own.
const SANYEN_KEEP: Array[String] = ["喂了樵夫药", "守了寺规", "龙若说了三十年前", "头陀上了大殿", "山烟寺守了寺"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_votes()
	for test: Callable in [_test_guard, _test_leave]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_leave else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(-4) == [&"xuanchen", &"name", &"meet", &"split"], "the stub filled, then 玄尘, the scene, the split: %s" % [ids])
	_check(quest.step(&"xuanchen").target.npc_ids.has(LIAOCHEN) and quest.step(&"name").target.npc_ids.has(MASTER) and quest.step(&"meet").target.npc_ids.has(KNEEL), "了尘, then 绝尘子, then the kneeling 了尘")
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == StoryQuestDefinition.WEIGHT_BIG and split.option(&"guard") != null and split.option(&"leave") != null, "the line's one big split: 守阵 or 下山")
	_check(split.options.all(func(option: StoryQuestDefinition.Option) -> bool: return option.reward.rank_title == "执事" and option.reward.rank_family == FAMILY and not option.reward.deed.is_empty()), "执事 for 绝尘派's own either way, a deed")
	for id: StringName in [KNEEL, SANYEN_LC]:
		_check(catalog.npc(id).hooks() != null and catalog.npc(id).hooks().always_kept, "%s can only be knocked down" % id)
	for id: StringName in [KNEEL, SANYEN_LC, SEAT_LC]:
		_check(NpcLifeBook.entry(id) != null, "%s has its life" % id)
	var monk: NpcTeaching = catalog.npc(SANYEN_LC).teaching()
	_check(monk != null and monk.recognize(&"", {}, &"jingang-staff") != null and monk.recognize(&"family.sanyen", {}, &"jingang-staff") != null and monk.recognize(&"", {}, &"juechen-force") == null, "了尘 in 流云轩 teaches the 金刚杖法 to anyone, nothing else")
	var master: NpcTeaching = catalog.npc(MASTER).teaching()
	_check(master.recognize(&"", {"绝尘派守了阵": 1}, &"magic-array") != null and master.recognize(&"", {"绝尘派守了阵": 1}, &"tao-mystery") != null and master.recognize(&"", {"绝尘派守了阵": 1}, &"jingang-staff") == null, "守阵: 绝尘子 teaches one not of 绝尘派 the 奇门遁甲 and its 小天魔道, nothing else")
	_check(master.recognize(&"", {"了尘下了山": 1}, &"magic-array") == null and master.recognize(&"", {}, &"magic-array") == null, "下山 or nothing: not")
	var hall: NpcSpawnDefinition = catalog.spawn(&"native.cavehall.liaochen")
	var kneel: NpcSpawnDefinition = catalog.spawn(&"native.cavehall.liaochen_kneel")
	_check(hall.staged and kneel.staged and catalog.spawn(&"native.cavehall.liaochen_stay").staged, "了尘 in the hall: standing, kneeling, standing again")
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	var cards: Array = ending.cards.filter(func(card: EpilogueDefinition.Card) -> bool: return card.card_id == &"green")
	_check(cards.size() == 1 and (cards[0] as EpilogueDefinition.Card).place == &"green.village" and (cards[0] as EpilogueDefinition.Card).title == "青石村", "a new card: 青石村")
	var names: Array = ending.cards.map(func(card: EpilogueDefinition.Card) -> StringName: return card.card_id)
	_check(names.find(&"green") == names.find(&"sanyen") + 1, "青石村 after 日照山")


## 虹台: the split takes 绝尘's vote (before one sat on the 虹台); both may hand it over; no line, the old way.
func _test_votes() -> void:
	var state: CharacterState = _fresh(["终章"])
	_check(_holds(state, "assembly.juechen.absent") and not _holds(state, "assembly.juechen.stated") and not _holds(state, "assembly.juechen.yan"), "nothing done: 绝尘派 does not come")
	state = _fresh(["终章", "绝尘表了态", "绝尘子肯下山", "绝尘派肯来"])
	_check(_holds(state, "assembly.juechen.old") and not _holds(state, "assembly.juechen.yan"), "走过八卦阵 and 下山: the old way, 旧盟主")
	state = _fresh(["绝尘派肯来", "绝尘的票随了守阵"])
	_check(_holds(state, "assembly.juechen.stated") and _holds(state, "assembly.juechen.old") and not _holds(state, "assembly.juechen.yan") and not _holds(state, "assembly.juechen.absent"), "守阵: 旧盟主")
	state = _fresh(["绝尘派肯来", "绝尘的票随了下山"])
	_check(_holds(state, "assembly.juechen.stated") and _holds(state, "assembly.juechen.yan") and not _holds(state, "assembly.juechen.old"), "下山: 颜违")
	state = _fresh(["绝尘表了态", "绝尘子肯下山", "绝尘派肯来", "绝尘的票随了下山"])
	_check(_holds(state, "assembly.juechen.yan") and not _holds(state, "assembly.juechen.old"), "下山 wins over an earlier 请下山")
	state.marks["入了虹台的席"] = 1 # TEST-ONLY
	state.marks["九派到了"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.juechen.here") and _holds(state, "assembly.day.juechen.yan") and not _holds(state, "assembly.day.juechen.old"), "on the day: 绝尘派 came, 颜违")
	_check(_staged(state, &"native.terrace.liaochen") and not _staged(state, &"native.terrace.juechenzi"), "了尘 in the seat, not 绝尘子")
	state = _fresh(["绝尘派肯来", "绝尘的票随了守阵", "入了虹台的席", "九派到了"])
	_check(_staged(state, &"native.terrace.juechenzi") and not _staged(state, &"native.terrace.liaochen"), "守阵: 绝尘子 in the seat")
	state = _fresh(["终章", "绝尘派肯来", "绝尘的票随了守阵"])
	_check(_heard(state, MASTER, "虹台", "是你陪着推出去的") and state.marks.has("绝尘肯听你的"), "守阵: 绝尘子 would hand the vote over (the split's rules before 请下山's)")
	_check(_heard(state, MASTER, "虹台", "说过了"), "虹台 asked again: short")
	_check(_heard(state, MASTER, "这一票", "你拿去") and _holds(state, "assembly.juechen.self") and not _holds(state, "assembly.juechen.old"), "绝尘听你的")
	_check(not _heard(state, MASTER, "下山", "好。老道走一趟") and not GameContent.catalog().npc(MASTER).talk().confirm_applies("下山", state.marks), "下山 after the split: nothing to ask")
	state = _fresh(["终章", "绝尘派肯来", "绝尘的票随了下山"])
	_check(_heard(state, MASTER, "虹台", "问他") and not state.marks.has("绝尘肯听你的"), "下山: 绝尘子 sends you to 了尘")
	_check(_heard(state, SANYEN_LC, "虹台", "绝尘派投颜违") and state.marks.has("绝尘肯听你的") and state.marks.has("绝尘表了态"), "and 了尘 would hand the vote over")
	_check(_heard(state, SANYEN_LC, "这一票", "听施主的") and _holds(state, "assembly.juechen.self") and not _holds(state, "assembly.juechen.yan"), "绝尘听你的, from 了尘")
	_check(not GameContent.catalog().npc(MASTER).talk().confirm_applies("这一票", state.marks), "not 绝尘子's vote to give for 下山")
	# the split after one sat on the 虹台: the vote stays as it was
	state = _fresh(["了尘跪在了佛前", "入了虹台的席"])
	_check(_heard(state, MASTER, "守阵", "起来") and state.marks.has("绝尘派守了阵") and not state.marks.has("绝尘的票随了守阵") and not state.marks.has("绝尘派肯来") and _holds(state, "assembly.juechen.absent"), "守阵 after 入席: 绝尘派 still does not come")
	state = _fresh(["了尘跪在了佛前", "绝尘子肯下山", "绝尘派肯来", "入了虹台的席"])
	_check(_heard(state, KNEEL, "下山", "出了阵") and state.marks.has("了尘下了山") and not state.marks.has("绝尘的票随了下山") and _holds(state, "assembly.day.juechen.old"), "下山 after 入席: the vote stays 旧盟主, 绝尘子 in the seat")
	var talk: NpcTalk = GameContent.catalog().npc(KNEEL).talk()
	var seated: NpcInquiryRule = NpcInquiryRule.decide(talk.inquiry_rules("下山"), {"了尘跪在了佛前": 1, "入了虹台的席": 1})
	_check(seated != null and not seated.lines.any(func(line: NpcLine) -> bool: return line.text.contains("正月十七")), "and he says nothing of going up on the seventeenth")
	seated = NpcInquiryRule.decide(GameContent.catalog().npc(MASTER).talk().inquiry_rules("守阵"), {"了尘跪在了佛前": 1, "入了虹台的席": 1})
	_check(seated != null and not seated.lines.any(func(line: NpcLine) -> bool: return line.text.contains("正月十七")), "nor 绝尘子 of coming down")
	# 听你的: nine 派 now
	state = _fresh(["终章", "封山表了态", "天邪表了态", "茅山表了态", "晚月庄表了态", "绝尘派肯来", "绝尘的票随了下山"])
	for mark: String in ["封山听你的", "天邪听你的", "茅山听你的", "晚月庄听你的"]:
		state.marks[mark] = 1 # TEST-ONLY
	_check(not _holds(state, "assembly.self_backed"), "four 听你的: short")
	state.marks["绝尘听你的"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.self_backed"), "绝尘派 the fifth")
	state.marks["入了虹台的席"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.juechen.backs") and not _holds(state, "assembly.day.juechen.self"), "on the day: 绝尘派 came and 听你的")
	state.marks["站出来参选"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.juechen.self"), "and votes you when you stand")
	# 颜违 needs five of nine now
	state = _fresh(["绝尘派肯来", "绝尘的票随了下山", "入了虹台的席"])
	for mark: String in ["跟了北宗", "站了颜违"]:
		state.marks[mark] = 1 # TEST-ONLY
	var yan: int = ["fonxan", "celestial", "zhenyuan", "maoshan", "latemoon", "sanyen", "buxuan", "huazi", "juechen"].filter(func(p: String) -> bool: return _holds(state, "assembly.day.%s.yan" % p)).size()
	_check(_holds(state, "assembly.day.yan_wins") == (yan >= 5) and _holds(state, "assembly.day.juechen.yan"), "颜违's count reads 绝尘派 too (%d)" % yan)


## 绝尘子's own (a man), with 山烟寺 A and B walked (the 头陀 healed the 樵夫, the sutra taken, 龙若's 玄尘): 了尘's 师父 tells
## of the 樵夫; 绝尘子's 玄尘 owns the name with a word for 收经 and 龙若; 了尘 kneels: the scene; 守阵: 执事, 了尘 standing
## again, the vote; 村长 after.
func _test_guard(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_join(session)
	for mark: String in A_MARKS + SANYEN_TAKE:
		state.marks[mark] = 1 # TEST-ONLY: 绝尘 A walked; 山烟寺 A and B too
	state.affiliation.family_title = "大弟子" # TEST-ONLY: A's rank
	session.record_journal()
	_check(_step(session) == &"xuanchen", "on to 了尘's 师父")
	var hall: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	var liaochen: NpcRuntimeState = _first(session, HALL, LIAOCHEN)
	_check(liaochen != null and _first(session, HALL, KNEEL) == null, "了尘 standing in the hall")
	var said: Array[String] = _ask(hall, liaochen, "师父")
	_check(_said(said, "小沙弥") and _said(said, "樵夫") and _said(said, "独眼的头陀") and _said(said, "我要回山烟寺去") and state.marks.get("了尘说了玄尘", 0) == 1, "师父: thirty years ago, the 樵夫 (%s)" % [said.slice(-5)])
	session.record_journal()
	_check(state.quests.has("faction.juechen/xuanchen") and _step(session) == &"name", "the stub done; 玄尘 next")
	var master: NpcRuntimeState = _first(session, HALL, MASTER)
	_check(hall.select_npc(master.character_id) and hall.ask_topics_selected().has("玄尘"), "绝尘子: 玄尘 listed")
	said = _ask(hall, master, "玄尘")
	_check(_said(said, "三十年没人叫了") and _said(said, "师兄收了那部经") and _said(said, "他向来这么说") and state.marks.get("绝尘子认了玄尘", 0) == 1, "玄尘: he owns the name; 收经 and 龙若 (%s)" % [said.slice(-6)])
	await _settle(tree)
	_check(_first(session, HALL, LIAOCHEN) == null and _first(session, HALL, KNEEL) != null, "the standing 了尘 off, the kneeling one on, in front of the player")
	var lines: Array[String] = await _scene(tree, session, hall)
	_check(_said(lines, "师父。") and _said(lines, "只有一个头陀") and _said(lines, "你说吧") and not _said(lines, "不算外人") and state.marks.get("了尘跪在了佛前", 0) == 1 and state.marks.get("绝尘子和了尘说完了话", 0) == 1, "the scene, with a word for 收经 (%s)" % [lines.slice(-8)])
	session.record_journal()
	_check(_step(session) == &"split", "then the split")
	master = _first(session, HALL, MASTER)
	var kneel: NpcRuntimeState = _first(session, HALL, KNEEL)
	_check(master.definition().talk().confirm_applies("守阵", state.marks) and kneel.definition().talk().confirm_applies("下山", state.marks), "both ways asked first")
	said = _ask(hall, master, "守阵")
	_check(_said(said, "推到洞口") and state.marks.get("绝尘派守了阵", 0) == 1 and state.marks.get("绝尘的票随了守阵", 0) == 1 and state.marks.get("绝尘派肯来", 0) == 1, "守阵 (%s)" % [said.slice(-4)])
	await _settle(tree)
	_check(_first(session, HALL, KNEEL) == null and _first(session, HALL, LIAOCHEN) != null, "了尘 stands again behind his master")
	session.record_journal()
	_check(state.quests.has("faction.juechen#done") and state.quests.has("faction.juechen/split/guard") and state.affiliation.family_title == "执事", "the line done: 执事")
	_check(_said(_ask(hall, _first(session, HALL, LIAOCHEN), "师父"), "我留下"), "了尘 on staying")
	_check(_said(_ask(hall, _first(session, HALL, MASTER), "玄尘"), "叫过一回"), "绝尘子 on the name after")
	var home: WorldMapController = await _enter(tree, session, HOUSE4, HOUSE4_POINT)
	_check(_said(_ask(home, _first(session, HOUSE4, ELDER), "山洞"), "寒气没了"), "村长: the cold is gone from the cave")
	state.marks["终章"] = 1 # TEST-ONLY
	hall = await _enter(tree, session, HALL, HALL_POINT)
	_check(_said(_ask(hall, _first(session, HALL, MASTER), "虹台"), "投旧盟主") and state.marks.has("绝尘肯听你的") and _holds(state, "assembly.juechen.old"), "虹台: 旧盟主, and the vote his to give")
	await _enter(tree, session, HEAL, HEAL_POINT)
	_check(_first(session, HEAL, SANYEN_LC) == null, "nobody of 绝尘派 in 流云轩")


## A 过阵的客 (a woman), with 山烟寺 A by the rule and 守寺: 了尘's 师父 tells of the 樵夫 and the 方丈's three nights; 玄尘;
## the scene with a word for 守寺; 下山: 了尘 gone from the hall, in 流云轩 by the stove, teaching her the 金刚杖法; no rank
## for her; 玄智 on 了尘; the vote from 了尘.
func _test_leave(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	for mark: String in ["走出了八卦阵", "过阵的客"] + A_MARKS + SANYEN_KEEP:
		state.marks[mark] = 1 # TEST-ONLY: a 过阵的客, 绝尘 A walked; 山烟寺 A by the rule, 守寺
	session.record_journal()
	_check(_step(session) == &"xuanchen", "her line on to 了尘's 师父")
	var hall: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	var said: Array[String] = _ask(hall, _first(session, HALL, LIAOCHEN), "师父")
	_check(_said(said, "樵夫") and _said(said, "方丈守了三天三夜") and not _said(said, "独眼的头陀"), "师父: the 樵夫 and the 方丈 (%s)" % [said.slice(-4)])
	said = _ask(hall, _first(session, HALL, MASTER), "玄尘")
	_check(_said(said, "三十年没人叫了") and _said(said, "守着本寺一脉") and not _said(said, "他向来这么说"), "玄尘: a word for 守寺, none for 龙若 (%s)" % [said.slice(-5)])
	var lama: NpcInquiryRule = NpcInquiryRule.decide(GameContent.catalog().npc(&"fanfang.npc.lama_master").talk().inquiry_rules("玄尘"), {"龙若说了三十年前": 1, "了尘说了玄尘": 1})
	_check(lama != null and lama.mark_asker == "龙若说了没点化玄尘" and lama.lines.any(func(line: NpcLine) -> bool: return line.text.contains("没有点化")), "龙若's denial is what 绝尘子 answers to")
	await _settle(tree)
	var lines: Array[String] = await _scene(tree, session, hall)
	_check(_said(lines, "不算外人") and not _said(lines, "只有一个头陀"), "the scene, with a word for 守寺")
	var kneel: NpcRuntimeState = _first(session, HALL, KNEEL)
	said = _ask(hall, kneel, "下山")
	_check(_said(said, "出了阵，就是世事") and state.marks.get("了尘下了山", 0) == 1 and state.marks.get("绝尘的票随了下山", 0) == 1 and state.marks.get("绝尘派肯来", 0) == 1, "下山 (%s)" % [said.slice(-4)])
	await _settle(tree)
	_check(_first(session, HALL, KNEEL) == null and _first(session, HALL, LIAOCHEN) == null, "了尘 gone from the hall")
	session.record_journal()
	_check(state.quests.has("faction.juechen#done") and state.quests.has("faction.juechen/split/leave") and state.affiliation.family_title != "执事", "the line done; no rank for a guest")
	_check(_said(_ask(hall, _first(session, HALL, MASTER), "了尘"), "出了阵"), "绝尘子 on 了尘")
	_check(GameContent.catalog().npc(MASTER).teaching().recognize(&"", state.marks, &"magic-array") == null, "no 奇门遁甲 for 下山")
	var heal: WorldMapController = await _enter(tree, session, HEAL, HEAL_POINT)
	var monk: NpcRuntimeState = heal.npcs.npc_at_point(&"sanyen.heal_room.liaochen.1")
	var beside: NpcRuntimeState = heal.npcs.npc_at_point(&"sanyen.heal_room.liaochen_toutuo.1")
	_check(monk != null and monk.exists_in_map and (beside == null or not beside.exists_in_map), "守寺: 了尘 by the stove, not beside a 头陀")
	_check(_said(_ask(heal, monk, "流云轩"), "不算外人"), "了尘 in 流云轩: 本寺的人")
	state.progression.potential = 100 # TEST-ONLY
	state.attributes.strength = 50 # TEST-ONLY: jingang-staff.c wants str + max_force / 10 >= 50
	var learned: Array = _learn(SANYEN_LC, state, &"jingang-staff")
	_check((learned[0] as LearnResult).success, "了尘 teaches her the 金刚杖法 (%s)" % [learned[1]])
	_check(not (_learn(SANYEN_LC, state, &"juechen-force")[0] as LearnResult).success, "nothing else")
	var temple: WorldMapController = await _enter(tree, session, TEMPLE, TEMPLE_POINT)
	_check(_said(_ask(temple, _first(session, TEMPLE, XUANZHI), "了尘"), "不算外人"), "玄智 on 了尘")
	state.marks["终章"] = 1 # TEST-ONLY
	heal = await _enter(tree, session, HEAL, HEAL_POINT)
	monk = heal.npcs.npc_at_point(&"sanyen.heal_room.liaochen.1")
	_check(_said(_ask(heal, monk, "虹台"), "绝尘派投颜违") and state.marks.has("绝尘肯听你的") and _holds(state, "assembly.juechen.yan"), "虹台: 颜违, and the vote hers if she asks")
	_check(_said(_ask(heal, monk, "这一票"), "听施主的") and state.marks.has("绝尘听你的"), "the vote hers")


## TEST-ONLY: whether a spawn is on the stage for `state` (its present and until).
func _staged(state: CharacterState, spawn_id: StringName) -> bool:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	if spawn.present != null and not JournalLog.holds(spawn.present, state, temps, held):
		return false
	return spawn.until == null or not JournalLog.holds(spawn.until, state, temps, held)


## TEST-ONLY: `student` learns `skill_id` from `teacher_id` (as sanyen_family_test's _learn).
func _learn(teacher_id: StringName, student: CharacterState, skill_id: StringName) -> Array:
	var catalog: ContentCatalog = GameContent.catalog()
	var definition: NpcDefinition = catalog.npc(teacher_id)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"sanyen.grounds.temple.test", &"sanyen.temple.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
	var random := ScriptedWorldInteractionRandomSource.new([0, 0, 0, 0])
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, false, random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = catalog.skill(skill_id)
	var result: LearnResult = LearnService.learn(student, context, skill, registry.policy_for(skill_id), null, random)
	var respect: String = RankWords.query_respect(student.gender, 14, student.affiliation.class_id)
	return [result, LearnLines.lines(result, definition.display_name, skill, student, context, respect)]


func _join(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	state.attributes.spirituality = 24 # TEST-ONLY
	state.progression.combat_experience = 20000 # TEST-ONLY
	var request := NpcApprenticeship.new()
	_check(request.request(state, catalog.npc(MASTER), catalog.family(FAMILY), 1, "兄弟") == NpcApprenticeship.Outcome.RECRUITED and state.family.family_id == FAMILY, "taken by 绝尘子 (%s)" % [request.lines])
	state.apprenticeship.master_teacher_id = MASTER # TEST-ONLY: as the panel records it


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


func _enter(tree: SceneTree, session: WorldSessionController, zone_id: StringName, point_id: StringName) -> WorldMapController:
	var map: WorldMapController = MapPlaces.enter(session, zone_id, point_id)
	await _settle(tree)
	return map


## TEST-ONLY: a scene under way in front of the player, through to its end.
func _scene(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> Array[String]:
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(map.scene_running(), "a scene starts as 了尘 kneels")
	for second: int in 60:
		if not map.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not map.scene_running(), "the scene is over")
	return _recent(session, 30)


func _step(session: WorldSessionController) -> StringName:
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(session.player_runtime().state, GameContent.catalog().story_quest(QUEST))
	return &"" if step == null else step.step_id


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
	session.configure_source_entry("绝尘派", gender)
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
	for frame: int in 3:
		await tree.process_frame
		await tree.physics_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
