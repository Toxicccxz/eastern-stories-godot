extends RefCounted

## 势力线第三批 山烟寺 B (计划 势力线第三批_计划.md §6 山烟寺 B, §3 三十年前, §8 第 6 行与「要改大会的地方」; DECISIONS
## 「山烟寺 B」): the stub `west` filled — 龙若法王「头陀」 tells of thirty years ago and gives a 贝叶 (again if lost),
## 「玄尘」 the one who went with him; the 贝叶 shown to the 独眼头陀 at the 金门 (「经」; he reads his master's hand even
## for one who kept the rule) takes him up to the 大雄宝殿 for good; the scene there (玄智, the 头陀, you; a word for one
## who broke the rule); the big split: 收经 (the 头陀 ordained, in 流云轩, teaching the 婆萝蜜多心经 to anyone and nothing
## else; 山烟寺 votes the old 盟主) or 守寺 (the 头陀 gone; 玄智 teaches one not of 山烟寺 the 莲华心法 and its 大乘佛法;
## 颜违); 首座 for 山烟寺's own; both may hand 玄智's vote over (山烟寺 听你的); one who walked 绝尘 B (了尘说了玄尘)
## hears one more line either way; one who never walked the line keeps the old way (站了安妮儿, 改投).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const QUEST: StringName = &"faction.sanyen"
const XUANZHI: StringName = &"common.npc.bonze.master"
const MONK: StringName = &"sanyen.npc.monk"
const DRUG: StringName = &"sanyen.npc.drug_bonze"
const LAMA: StringName = &"fanfang.npc.lama_master"
const HALL_MONK: StringName = &"native.npc.toutuo_hall"
const LIUYUN: StringName = &"native.npc.toutuo_liuyun"
const LEAF: StringName = &"native:fanfang/sutra_leaf"
const SKILL: StringName = &"bolomiduo"
const HEAL: StringName = &"sanyen.heal_room"
const HEAL_POINT: StringName = &"sanyen.heal_room.inner_yard_entry"
const HALL: StringName = &"sanyen.temple"
const HALL_POINT: StringName = &"sanyen.temple.road1_entry"
const ROAD1: StringName = &"sanyen.road1"
const ROAD1_POINT: StringName = &"sanyen.road1.temple_return"
const YARD: StringName = &"fanfang.temple_yard"
const YARD_POINT: StringName = &"fanfang.temple_yard.slope_arrival"
## 山烟寺 A walked to its end, by the 头陀's way or the rule's (the marks its steps write).
const A_MARKS: Array[String] = ["宝衣一章", "玄智开了方子", "采了附子", "杨掌柜给了麝香", "采了鬼臼", "药僧煎好了药", "喂了樵夫药", "头陀说了病人"]
const HEAL_MARKS: Array[String] = ["头陀跟你去了流云轩", "头陀进了流云轩", "不守寺规", "听说了番坊的经"]
const RULE_MARKS: Array[String] = ["守了寺规", "听说了番坊的经"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_votes()
	for test: Callable in [_test_take, _test_guard]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if test == _test_guard else CharacterState.GENDER_MALE)
		await test.call(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids.slice(-4) == [&"west", &"leaf", &"meet", &"split"], "the stub filled, then the 贝叶, the hall, the split: %s" % [ids])
	_check(quest.step(&"leaf").target.npc_ids.has(MONK) and quest.step(&"meet").target.npc_ids.has(HALL_MONK), "the 贝叶 to the 头陀 at the 金门, then the hall")
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == StoryQuestDefinition.WEIGHT_BIG and split.option(&"take") != null and split.option(&"guard") != null, "the line's one big split: 收经 or 守寺")
	_check(split.options.all(func(option: StoryQuestDefinition.Option) -> bool: return option.reward.rank_title == "首座" and option.reward.rank_family == &"family.sanyen" and not option.reward.deed.is_empty()), "首座 for 山烟寺's own either way, a deed")
	var leaf: ItemContentDefinition = catalog.item(LEAF)
	_check(leaf != null and leaf.quest_item and leaf.no_drop, "the 贝叶: a quest item, kept")
	var skill: SkillDefinition = catalog.skill(SKILL)
	_check(skill != null and skill.display_name == "婆萝蜜多心经" and skill.can_enable_for(&"force") and skill.exert_functions.is_empty() and skill.standard_force_hit, "婆萝蜜多心经: a 内功 (enabled as force, FORCE's hit), no 运功")
	var hall: NpcDefinition = catalog.npc(HALL_MONK)
	var liuyun: NpcDefinition = catalog.npc(LIUYUN)
	_check(hall != null and hall.hooks().always_kept and liuyun != null and liuyun.hooks().always_kept, "the 头陀 in the hall and in 流云轩: only knocked down")
	var teaching: NpcTeaching = liuyun.teaching()
	_check(teaching != null and teaching.recognize(&"", {}, SKILL) != null and teaching.recognize(&"family.sanyen", {}, SKILL) != null and teaching.recognize(&"", {}, &"lotusforce") == null, "the 头陀 in 流云轩 teaches the 婆萝蜜多心经 to anyone, nothing else")
	var master: NpcTeaching = catalog.npc(XUANZHI).teaching()
	_check(master.recognize(&"", {"山烟寺守了寺": 1}, &"lotusforce") != null and master.recognize(&"", {"山烟寺守了寺": 1}, &"buddhism") != null and master.recognize(&"", {"山烟寺守了寺": 1}, &"staff") == null, "守寺: 玄智 teaches one not of 山烟寺 the 莲华心法 and its 大乘佛法, nothing else")
	_check(master.recognize(&"", {"山烟寺收了经": 1}, &"lotusforce") == null and master.recognize(&"", {}, &"lotusforce") == null, "收经 or nothing: not")
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	var cards: Array = ending.cards.filter(func(card: EpilogueDefinition.Card) -> bool: return card.card_id == &"sanyen")
	_check(cards.size() == 1 and (cards[0] as EpilogueDefinition.Card).place == &"sanyen.grounds" and (cards[0] as EpilogueDefinition.Card).title == "日照山", "a new card: 日照山")


## 虹台: the split takes 山烟寺's vote (before one sat on the 虹台); both may hand it over; no line, the old way.
func _test_votes() -> void:
	var state: CharacterState = _fresh(["终章"])
	_check(_holds(state, "assembly.sanyen.yan") and not _holds(state, "assembly.sanyen.stated"), "nothing done: 颜违, not said yet")
	state = _fresh(["终章", "站了安妮儿", "山烟寺表了态", "山烟寺肯改投", "山烟寺改投旧盟主"])
	_check(_holds(state, "assembly.sanyen.old") and not _holds(state, "assembly.sanyen.yan"), "站了安妮儿 and 改投: the old way, 旧盟主")
	state = _fresh(["山烟寺的票随了收经"])
	_check(_holds(state, "assembly.sanyen.stated") and _holds(state, "assembly.sanyen.old") and not _holds(state, "assembly.sanyen.yan") and not _holds(state, "assembly.sanyen.self"), "收经: 旧盟主")
	state = _fresh(["山烟寺的票随了守寺"])
	_check(_holds(state, "assembly.sanyen.stated") and _holds(state, "assembly.sanyen.yan") and not _holds(state, "assembly.sanyen.old"), "守寺: 颜违")
	state = _fresh(["山烟寺的票随了守寺", "山烟寺改投旧盟主"])
	_check(_holds(state, "assembly.sanyen.yan") and not _holds(state, "assembly.sanyen.old"), "守寺 wins over an earlier 改投")
	state.marks["终章"] = 1 # TEST-ONLY
	_check(_heard(state, XUANZHI, "虹台", "守清规") and state.marks.has("山烟寺肯听你的"), "and 玄智 says so (the split's rules before 改投's)")
	var gate: Array[NpcInquiryRule] = GameContent.catalog().npc(MONK).talk().inquiry_rules("经")
	_check(gate.any(func(rule: NpcInquiryRule) -> bool: return rule.asker_marks == ["龙若说了三十年前", "守了寺规"] and rule.asker_carries.is_empty() and rule.lines.any(func(line: NpcLine) -> bool: return line.text.contains("不理你"))), "the rule kept and no leaf in hand: the 头陀 turns away, as in A")
	state = _fresh(["终章", "山烟寺的票随了收经"])
	_check(_heard(state, XUANZHI, "虹台", "容得下西来的经") and state.marks.has("山烟寺肯听你的"), "收经: 玄智 would hand the vote over")
	_check(_heard(state, XUANZHI, "这一票", "听施主的") and _holds(state, "assembly.sanyen.self") and not _holds(state, "assembly.sanyen.old") and not _holds(state, "assembly.sanyen.yan"), "山烟寺听你的")
	_check(_heard(state, XUANZHI, "改投", "本来就投旧盟主") and not state.marks.has("山烟寺改投旧盟主"), "改投 after the split: nothing to turn")
	state = _fresh(["终章", "山烟寺的票随了守寺"])
	_check(_heard(state, XUANZHI, "虹台", "守清规") and state.marks.has("山烟寺肯听你的"), "守寺: 玄智 would hand the vote over too")
	# the split after one sat on the 虹台: the vote stays as it was
	state = _fresh(["头陀上殿见了玄智", "入了虹台的席"])
	_check(_heard(state, XUANZHI, "收经", "收。") and state.marks.has("山烟寺收了经") and not state.marks.has("山烟寺的票随了收经") and _holds(state, "assembly.sanyen.yan"), "收经 after 入席: the vote stays 颜违")
	# 听你的: eight 派 now
	state = _fresh(["终章"])
	for mark: String in ["封山听你的", "天邪听你的", "茅山听你的", "晚月庄听你的"]:
		state.marks[mark] = 1 # TEST-ONLY
	_check(not _holds(state, "assembly.self_backed"), "four 听你的: short")
	state.marks["山烟寺听你的"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.self_backed"), "山烟寺 the fifth")
	state.marks["入了虹台的席"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.sanyen.backs") and not _holds(state, "assembly.day.sanyen.self"), "on the day: 山烟寺 came and 听你的")
	state.marks["站出来参选"] = 1 # TEST-ONLY
	_check(_holds(state, "assembly.day.sanyen.self"), "and votes you when you stand")
	# the one who walked 绝尘 B hears one more line either way
	state = _fresh(["头陀上殿见了玄智", "了尘说了玄尘"])
	_check(_heard(state, XUANZHI, "收经", "玄尘要是知道"), "收经: 玄尘要是知道")
	state = _fresh(["头陀上殿见了玄智", "了尘说了玄尘"])
	_check(_heard(state, XUANZHI, "守寺", "他还好"), "守寺: 他还好？")
	state = _fresh(["头陀上殿见了玄智"])
	_check(not _heard(state, XUANZHI, "收经", "玄尘要是知道"), "not for one who did not")


## 玄智's own, the 头陀's way in A: 龙若's tale and 贝叶; the 头陀 up to the hall; the scene (破过一回寺规); 收经: 首座,
## the 头陀 in 流云轩 teaching the 婆萝蜜多心经; the vote.
func _test_take(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_join(session)
	for mark: String in A_MARKS + HEAL_MARKS:
		state.marks[mark] = 1 # TEST-ONLY: 山烟寺 A walked, the 头陀 led into 流云轩
	state.affiliation.family_title = "知客" # TEST-ONLY: A's rank
	session.record_journal()
	_check(_step(session) == &"west", "on to 番坊")
	var yard: WorldMapController = await _enter(tree, session, YARD, YARD_POINT)
	var lama: NpcRuntimeState = _first(session, YARD, LAMA)
	_check(yard.select_npc(lama.character_id) and yard.ask_topics_selected().has("头陀") and not yard.ask_topics_selected().has("玄尘"), "龙若: 头陀 listed, not yet 玄尘")
	var said: Array[String] = _ask(yard, lama, "头陀")
	_check(_said(said, "三十年前") and _said(said, "玄尘") and _said(said, "练坏了一只眼") and state.marks.get("龙若说了三十年前", 0) == 1 and _carried(session, LEAF) != &"", "龙若: thirty years ago, and a 贝叶 (%s)" % [said.slice(-4)])
	session.record_journal()
	_check(state.quests.has("faction.sanyen/west") and _step(session) == &"leaf", "the stub done; the 贝叶 to the 头陀")
	_check(_said(_ask(yard, lama, "头陀"), "拿给他看") and _count_carried(session, LEAF) == 1, "asked again: no second leaf while one is carried")
	said = _ask(yard, lama, "玄尘")
	_check(_said(said, "不拣经") and _said(said, "青石村后山") and state.marks.get("龙若说了玄尘", 0) == 1, "玄尘: he went north (%s)" % [said.slice(-3)])
	var grounds: WorldMapController = await _enter(tree, session, ROAD1, ROAD1_POINT)
	var monk: NpcRuntimeState = _first(session, ROAD1, MONK)
	_check(monk != null and grounds.select_npc(monk.character_id) and grounds.ask_topics_selected().has("经"), "the 头陀 at the 金门: 经 listed")
	_check(not grounds.give_to_selected(_carried(session, LEAF)).done() and _carried(session, LEAF) != &"", "given, he does not take it: ask him")
	said = _ask(grounds, monk, "经")
	_check(_said(said, "师父的字") and state.marks.get("头陀上了大殿", 0) == 1 and _carried(session, LEAF) == &"" and _first(session, ROAD1, MONK) == null, "经: he takes the 贝叶 and goes up, for good (%s)" % [said.slice(-3)])
	session.record_journal()
	_check(_step(session) == &"meet", "to the hall")
	var hall: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	_check(_first(session, HALL, HALL_MONK) != null, "the 头陀 before the Buddha")
	var lines: Array[String] = await _scene(tree, session, hall)
	_check(_said(lines, "收，还是不收") and _said(lines, "施主破过一回寺规") and state.marks.get("头陀上殿见了玄智", 0) == 1 and state.marks.get("玄智和头陀说完了话", 0) == 1, "the scene, with a word for one who broke the rule (%s)" % [lines.slice(-6)])
	session.record_journal()
	_check(_step(session) == &"split", "then the split")
	var xuanzhi: NpcRuntimeState = _first(session, HALL, XUANZHI)
	_check(xuanzhi.definition().talk().confirm_applies("收经", state.marks) and xuanzhi.definition().talk().confirm_applies("守寺", state.marks), "both ways asked first")
	said = _ask(hall, xuanzhi, "收经")
	_check(_said(said, "发就留着") and state.marks.get("山烟寺收了经", 0) == 1 and state.marks.get("山烟寺的票随了收经", 0) == 1 and not _said(said, "玄尘要是知道"), "收经 (%s)" % [said.slice(-4)])
	_check(_first(session, HALL, HALL_MONK) == null, "the 头陀 went to 流云轩")
	session.record_journal()
	_check(state.quests.has("faction.sanyen#done") and state.quests.has("faction.sanyen/split/take") and state.affiliation.family_title == "首座", "the line done: 首座")
	_check(_said(_ask(hall, xuanzhi, "守寺"), "经已经收了") and not state.marks.has("山烟寺守了寺"), "守寺 no more")
	_check(_said(_ask(hall, xuanzhi, "头陀"), "早十年"), "玄智 on the 头陀")
	var heal: WorldMapController = await _enter(tree, session, HEAL, HEAL_POINT)
	var liuyun: NpcRuntimeState = _first(session, HEAL, LIUYUN)
	_check(liuyun != null and _said(_ask(heal, liuyun, "婆萝蜜多心经"), "我教"), "the 头陀 in 流云轩, teaching")
	_check(_said(_ask(heal, _first(session, HEAL, DRUG), "病人"), "治得了"), "流云轩 cures the 鬼卒's cold now")
	var student: CharacterState = NewPlayerInitializationPolicy.create(CharacterState.GENDER_FEMALE, "流云").state
	student.progression.potential = 100 # TEST-ONLY
	var learned: Array = _learn(LIUYUN, student, SKILL)
	_check((learned[0] as LearnResult).success, "one of no family learns the 婆萝蜜多心经 (%s)" % [learned[1]])
	_check(not (_learn(LIUYUN, student, &"lotusforce")[0] as LearnResult).success, "nothing else of his")
	yard = await _enter(tree, session, YARD, YARD_POINT)
	_check(_said(_ask(yard, _first(session, YARD, LAMA), "头陀"), "总算进了那道门"), "龙若 hears it")


## A 流云轩的帮手 (a woman), the rule's way in A: the 头陀 who turned away reads the 贝叶; 守寺 (with 绝尘 B walked):
## the 头陀 gone, no 首座 for her, 玄智 teaches her the 莲华心法; the vote; the 贝叶 again if lost (the rule).
func _test_guard(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.marks["流云轩的帮手"] = 1 # TEST-ONLY
	for mark: String in A_MARKS + RULE_MARKS:
		state.marks[mark] = 1 # TEST-ONLY: 山烟寺 A walked, the rule kept
	session.record_journal()
	_check(_step(session) == &"west", "her line on to 番坊")
	var yard: WorldMapController = await _enter(tree, session, YARD, YARD_POINT)
	var lama: NpcRuntimeState = _first(session, YARD, LAMA)
	_check(_said(_ask(yard, lama, "头陀"), "他不理人，这一页他会看"), "龙若: show him the leaf")
	var rules: Array[NpcInquiryRule] = GameContent.catalog().npc(LAMA).talk().inquiry_rules("头陀")
	_check(rules.any(func(rule: NpcInquiryRule) -> bool: return rule.asker_not_carries == "贝叶" and rule.gives == LEAF and rule.asker_marks == ["龙若说了三十年前"]), "lost: 龙若 writes another")
	var grounds: WorldMapController = await _enter(tree, session, ROAD1, ROAD1_POINT)
	var monk: NpcRuntimeState = _first(session, ROAD1, MONK)
	_check(_said(_ask(grounds, monk, "病人"), "不理你"), "the 头陀 still turns away from her")
	var said: Array[String] = _ask(grounds, monk, "经")
	_check(_said(said, "他转回来了") and state.marks.get("头陀上了大殿", 0) == 1, "but reads his master's hand (%s)" % [said.slice(-4)])
	var hall: WorldMapController = await _enter(tree, session, HALL, HALL_POINT)
	var lines: Array[String] = await _scene(tree, session, hall)
	_check(_said(lines, "收，还是不收") and not _said(lines, "施主破过一回寺规"), "the scene; no word of a broken rule")
	state.marks["了尘说了玄尘"] = 1 # TEST-ONLY: 绝尘 B walked
	said = _ask(hall, _first(session, HALL, XUANZHI), "守寺")
	_check(_said(said, "他还好") and _said(said, "空了") and state.marks.get("山烟寺守了寺", 0) == 1 and state.marks.get("山烟寺的票随了守寺", 0) == 1, "守寺 (%s)" % [said.slice(-5)])
	_check(_first(session, HALL, HALL_MONK) == null, "the 头陀 gone")
	session.record_journal()
	_check(state.quests.has("faction.sanyen#done") and state.quests.has("faction.sanyen/split/guard") and state.affiliation.family_title != "首座", "the line done; no rank for a 帮手")
	var heal: WorldMapController = await _enter(tree, session, HEAL, HEAL_POINT)
	_check(_first(session, HEAL, LIUYUN) == null and _said(_ask(heal, _first(session, HEAL, DRUG), "病人"), "还是治不了"), "nobody in 流云轩 cures the cold")
	state.progression.potential = 100 # TEST-ONLY
	var learned: Array = _learn(XUANZHI, state, &"buddhism")
	_check((learned[0] as LearnResult).success, "玄智 teaches her 大乘佛法 (%s)" % [learned[1]])
	learned = _learn(XUANZHI, state, &"lotusforce")
	_check((learned[0] as LearnResult).success, "and the 莲华心法 (%s)" % [learned[1]])
	_check(not (_learn(XUANZHI, state, &"staff")[0] as LearnResult).success, "nothing else")
	state.marks["终章"] = 1 # TEST-ONLY
	hall = await _enter(tree, session, HALL, HALL_POINT)
	_check(_said(_ask(hall, _first(session, HALL, XUANZHI), "虹台"), "颜施主") and state.marks.has("山烟寺肯听你的") and _holds(state, "assembly.sanyen.yan"), "虹台: 颜违, and the vote hers if she asks")
	yard = await _enter(tree, session, YARD, YARD_POINT)
	_check(_said(_ask(yard, _first(session, YARD, LAMA), "头陀"), "往西去了"), "龙若: the leaf came back, the man went on west")


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
	state.family = FamilyState.new(&"family.sanyen", 26) # TEST-ONLY: shaved and knelt to 玄智
	state.apprenticeship.master_teacher_id = XUANZHI
	state.apprenticeship.legacy_master_name = "玄智"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"bonze"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


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


## TEST-ONLY: a scene as one comes into its room, through to its end.
func _scene(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> Array[String]:
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(map.scene_running(), "a scene starts as the player comes in")
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


func _count_carried(session: WorldSessionController, definition_id: StringName) -> int:
	var map: WorldMapController = session.active_map() as WorldMapController
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	var count: int = 0
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			count += 1
	return count


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
	session.configure_source_entry("山烟寺", gender)
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
