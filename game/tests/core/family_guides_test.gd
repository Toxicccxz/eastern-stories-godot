extends RefCounted

## 战斗拍数 D (DECISIONS「战斗拍数 D」): the data of the guides and the town's hearsay — each
## guide an NPC that speaks and has the school, its master one who takes apprentices, its
## lines and verdicts there; each line of hearsay hung first on a speaking NPC's topic, the
## master's conditions filled in; the two schools' style_line; the 见识录's keys (hearsay heard,
## a guide's teaching, the lesson's verdict, the beat habits read of an NPC, the wound's
## school); a family record refused without its lesson's parts.

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_data()
	_test_hearsay_on_talk()
	_test_insights()
	_test_records()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var family: FamilyDefinition = catalog.family(&"family.fonxan")
	_check(family != null and family.guides.size() == 2 and family.hearsay.size() == 11 and family.origin.begins_with("native"), "封山剑派: two guides, eleven lines of hearsay, their origin named")
	var fists: FamilyDefinition.SchoolGuide = catalog.guide_for(&"liuh-ken")
	var sword: FamilyDefinition.SchoolGuide = catalog.guide_for(&"fonxansword")
	_check(fists != null and fists.npc_id == &"snow.npc.fist_trainer" and fists.master_id == &"common.npc.swordsman.master" and fists.teach.size() == 4 and fists.rounds.size() == 3 and fists.teach_topic == "打法", "柳家拳's guide is 李火狮, four lines, three rounds, the topic 打法")
	_check(sword != null and sword.npc_id == &"snow.npc.girl" and sword.rounds.size() == 3 and not sword.earned.is_empty() and not sword.not_earned.is_empty() and not sword.player_earned.is_empty(), "封山剑法's guide is 柳绘心, with her three verdicts")
	_check(catalog.guide_of_npc(&"snow.npc.girl") == sword and catalog.guide_of_npc(&"snow.npc.waiter") == null and catalog.guide_for(&"dodge") == null, "the guide by its NPC; nobody else guides")
	for skill_id: StringName in [&"liuh-ken", &"fonxansword"]:
		var lines: Array[FamilyDefinition.Hearsay] = catalog.hearsay_for(skill_id)
		_check(lines.size() == 5 and lines[4].npc_id == &"snow.npc.herbalist" and lines[4].asker_marks == ["wounded_by/" + String(skill_id)] and lines[4].key == "hearsay/%s/5" % skill_id, "%s: five lines, the doctor's last and asking for the wound's mark: %s" % [skill_id, lines.map(func(line: FamilyDefinition.Hearsay) -> String: return String(line.npc_id))])
		var skill: SkillDefinition = catalog.skill(skill_id)
		_check(skill.skeleton != null and not skill.skeleton.style_line.is_empty() and not skill.skeleton.style_line.contains("拍"), "%s has its way in one plain sentence, no system word: %s" % [skill_id, skill.skeleton.style_line])
	for line: FamilyDefinition.Hearsay in family.hearsay:
		_check(not line.say.contains("拍") and not line.say.contains("骨架"), "no system word in the hearsay: " + line.say)
	for guide: FamilyDefinition.SchoolGuide in family.guides:
		for said: String in guide.teach + guide.rounds + [guide.earned, guide.not_earned, guide.player_earned]:
			_check(not said.contains("骨架") and not said.contains("标签"), "no system word in the guide's lines: " + said)
	var master: NpcDefinition = catalog.npc(&"common.npc.swordsman.master")
	_check(CombatInsights.requires_text(master) == "胆识 20、定力 20" and CombatInsights.fill("他只看{requires}。", master) == "他只看胆识 20、定力 20。", "the master's conditions in a line of talk: " + CombatInsights.requires_text(master))


## Each line of hearsay is a rule put first on the NPC's topic, with its key; the guide's
## teaching its own topic; the doctor's three lines of 伤口 pick by the wound's mark.
func _test_hearsay_on_talk() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var waiter: NpcDefinition = catalog.npc(&"snow.npc.waiter")
	_check(NpcInquiry.topics(waiter).has("封山剑法") and waiter.talk().inquiry_rules("封山剑法").size() == 1 and waiter.talk().inquiry_rules("封山剑法")[0].hearsay == "hearsay/fonxansword/1", "the waiter can be asked 封山剑法, one rule with its key: %s" % [NpcInquiry.topics(waiter)])
	var trainer: NpcDefinition = catalog.npc(&"snow.npc.fist_trainer")
	var teach: Array[NpcInquiryRule] = trainer.talk().inquiry_rules("打法")
	_check(teach.size() == 1 and teach[0].hearsay == "taught/liuh-ken" and teach[0].lines.size() == 4 and teach[0].lines[3].text.contains("胆识 20、定力 20"), "李火狮 answers 打法 with his four lines, the master's conditions filled in: %s" % (teach[0].lines[3].text if not teach.is_empty() else "-"))
	_check(NpcInquiry.topics(trainer).has("柳家拳法") and NpcInquiry.topics(trainer).has("打法"), "his own ES2 topic stays beside it: %s" % [NpcInquiry.topics(trainer)])
	var doctor: NpcDefinition = catalog.npc(&"snow.npc.herbalist")
	var wound: Array[NpcInquiryRule] = doctor.talk().inquiry_rules("伤口")
	_check(wound.size() == 3 and wound[0].hearsay == "hearsay/fonxansword/5" and wound[1].hearsay == "hearsay/liuh-ken/5" and wound[2].hearsay.is_empty() and wound[2].asker_marks.is_empty(), "the doctor's 伤口: the sword's wound, the fist's, then no wound (no school): %s" % [wound.map(func(rule: NpcInquiryRule) -> String: return rule.hearsay)])
	var random := WorldInteractionRandomSource.new()
	var asker := NpcInquiry.Asker.new(CharacterState.GENDER_MALE, 20, &"", 100, {"wounded_by/liuh-ken": 1})
	var answer: NpcInquiry.Answer = NpcInquiry.answer(doctor, CharacterState.GENDER_MALE, 54, true, asker, "伤口", "桑邻药铺", random)
	_check(answer.answered and answer.hearsay == "hearsay/liuh-ken/5" and answer.texts().size() == 2 and answer.texts()[1].contains("拳伤") and not answer.texts()[1].contains("$RESPECT"), "wounded by 柳家拳: the fist's line, $RESPECT filled: %s" % [answer.texts()])
	var whole: NpcInquiry.Answer = NpcInquiry.answer(doctor, CharacterState.GENDER_MALE, 54, true, NpcInquiry.Asker.new(CharacterState.GENDER_MALE, 20, &"", 100, {}), "伤口", "桑邻药铺", random)
	_check(whole.answered and whole.hearsay.is_empty() and whole.texts()[1].contains("没什么新伤"), "unhurt: no wound to read, no key: %s" % [whole.texts()])
	var sword_answer: NpcInquiry.Answer = NpcInquiry.answer(doctor, CharacterState.GENDER_MALE, 54, true, NpcInquiry.Asker.new(CharacterState.GENDER_FEMALE, 20, &"", 100, {"wounded_by/fonxansword": 1}), "伤口", "桑邻药铺", random)
	_check(sword_answer.hearsay == "hearsay/fonxansword/5" and sword_answer.texts()[1].contains("剑伤"), "wounded by 封山剑法: the sword's line")
	var guard: NpcDefinition = catalog.npc(&"snow.npc.guard")
	var told: NpcInquiry.Answer = NpcInquiry.answer(guard, CharacterState.GENDER_MALE, 40, true, asker, "封山剑法", "淳风武馆大门", random)
	_check(told.hearsay == "hearsay/fonxansword/2" and told.texts()[1].contains("胆识 20、定力 20"), "刘安禄's line names the master's conditions: %s" % [told.texts()])


func _test_insights() -> void:
	var state := CharacterState.new()
	_check(not CombatInsights.has_heard(state, "hearsay/liuh-ken/1") and not CombatInsights.taught(state, &"liuh-ken") and not CombatInsights.took_lesson(state, &"liuh-ken") and CombatInsights.wounded_by(state).is_empty(), "nothing yet")
	CombatInsights.heard(state, "hearsay/liuh-ken/3")
	CombatInsights.heard(state, "hearsay/liuh-ken/1")
	CombatInsights.heard(state, "")
	CombatInsights.heard(state, "taught/liuh-ken")
	_check(CombatInsights.hearsay_keys_heard(state, &"liuh-ken") == ["hearsay/liuh-ken/1", "hearsay/liuh-ken/3"] and CombatInsights.hearsay_keys_heard(state, &"fonxansword").is_empty() and CombatInsights.taught(state, &"liuh-ken") and state.insights.size() == 3, "heard in the data's order, the empty key ignored: %s" % [state.insights])
	CombatInsights.lesson_taken(state, &"liuh-ken", CombatInsights.VERDICT_GUIDE_EARNED)
	_check(CombatInsights.took_lesson(state, &"liuh-ken") and CombatInsights.lesson_verdict(state, &"liuh-ken") == CombatInsights.VERDICT_GUIDE_EARNED and not CombatInsights.took_lesson(state, &"fonxansword"), "the lesson taken with its verdict")
	var guide: FamilyDefinition.SchoolGuide = GameContent.catalog().guide_for(&"liuh-ken")
	_check(CombatInsights.verdict_line(guide, CombatInsights.VERDICT_GUIDE_EARNED) == guide.earned and CombatInsights.verdict_line(guide, CombatInsights.VERDICT_NOTHING_EARNED) == guide.not_earned and CombatInsights.verdict_line(guide, CombatInsights.VERDICT_PLAYER_EARNED) == guide.player_earned and CombatInsights.verdict_line(null, 1).is_empty(), "the verdict's line")
	# Beat habits: told once three beats of that number were watched and one tag took two thirds.
	for _n: int in 2:
		CombatInsights.note_habit(state, &"snow.npc.fist_trainer", &"liuh-ken", 2, CombatMoveTags.HEAVY)
	_check(CombatInsights.habits_of_school(state, &"liuh-ken").is_empty(), "two beats watched: nothing told yet")
	CombatInsights.note_habit(state, &"snow.npc.fist_trainer", &"liuh-ken", 2, CombatMoveTags.QUICK)
	_check(CombatInsights.habits_of_school(state, &"liuh-ken").size() == 1 and CombatInsights.habits_of_school(state, &"liuh-ken")[0].tag == CombatMoveTags.HEAVY and CombatInsights.habits_of_school(state, &"liuh-ken")[0].beat == 2 and not CombatInsights.habits_of_school(state, &"liuh-ken")[0].always(), "three watched, two 重: his second beat is mostly 重")
	CombatInsights.note_habit(state, &"snow.npc.fist_trainer", &"liuh-ken", 2, CombatMoveTags.QUICK)
	_check(CombatInsights.habits_of_school(state, &"liuh-ken").is_empty(), "two of four: no habit")
	for _n: int in 3:
		CombatInsights.note_habit(state, &"snow.npc.girl", &"fonxansword", 1, &"perform")
	var hers: Array[CombatInsights.Habit] = CombatInsights.habits_of_school(state, &"fonxansword")
	_check(hers.size() == 1 and hers[0].npc_id == &"snow.npc.girl" and hers[0].tag == &"perform" and hers[0].always() and hers[0].total == 3, "柳绘心's first beat always a special; kept under her school")
	CombatInsights.note_habit(state, &"", &"x", 1, &"quick")
	CombatInsights.note_habit(state, &"a", &"x", 0, &"quick")
	_check(state.insights.keys().filter(func(key: String) -> bool: return key.begins_with("habit/")).size() == 3, "no NPC or no beat number: nothing noted: %s" % [state.insights.keys()])
	CombatInsights.set_wounded_by(state, &"fonxansword")
	CombatInsights.set_wounded_by(state, &"liuh-ken")
	_check(CombatInsights.wounded_by(state) == &"liuh-ken" and state.marks == {"wounded_by/liuh-ken": 1}, "the wound carries the last school only: %s" % [state.marks])
	CombatInsights.set_wounded_by(state, &"")
	_check(CombatInsights.wounded_by(state) == &"liuh-ken", "no school: the mark stays")
	# The 见识录 entry of 柳家拳 grows from what was heard and shown, no moves watched needed.
	var catalog: ContentCatalog = GameContent.catalog()
	var entry: CodexContent.Entry = null
	for candidate: CodexContent.Entry in CodexContent.entries(CodexContent.Section.ARTS, state, catalog):
		if candidate.key == "moves/liuh-ken":
			entry = candidate
	_check(entry != null and entry.text().contains("樵夫说过：") and entry.text().contains("农夫说过：") and not entry.text().contains("王铁匠") and entry.text().contains("李火狮讲过：") and entry.text().contains("李火狮拆过招，说：") and not entry.text().contains("打法 ·") and not entry.text().contains("古松挂月"), "柳家拳's entry: two lines heard, the guide's teaching and verdict, no way yet, no move: %s" % ("-" if entry == null else entry.text()))
	var hers_entry: CodexContent.Entry = null
	for candidate: CodexContent.Entry in CodexContent.entries(CodexContent.Section.ARTS, state, catalog):
		if candidate.key == "moves/fonxansword":
			hers_entry = candidate
	_check(hers_entry != null and hers_entry.text().contains("柳绘心的第 1 手总是绝招招") == false and hers_entry.text().contains("柳绘心的第 1 手总是绝招"), "封山剑法's entry from her habit alone: %s" % ("-" if hers_entry == null else hers_entry.text()))


func _test_records() -> void:
	var errors: Array[String] = []
	var record: Dictionary = {"id": "family.t", "name": "试派", "guides": [{"skill": "liuh-ken", "npc": "snow.npc.fist_trainer", "master": "common.npc.swordsman.master", "teach": ["一"], "lesson": {"rounds": ["a"], "earned": "b"}}]}
	FamilyDefinition.from_record(ContentRecordReader.new(record, "t", errors))
	_check(errors.size() == 1 and errors[0].contains("not_earned"), "a lesson without its verdicts is refused: %s" % [errors])
	errors.clear()
	var twice: Dictionary = {"id": "family.t", "name": "试派", "guides": [{"skill": "liuh-ken", "npc": "a", "master": "m", "teach": ["一"]}, {"skill": "liuh-ken", "npc": "b", "master": "m", "teach": ["二"]}]}
	FamilyDefinition.from_record(ContentRecordReader.new(twice, "t", errors))
	_check(errors.size() == 1 and errors[0].contains("already has a guide"), "one guide per school: %s" % [errors])
	errors.clear()
	var plain: FamilyDefinition = FamilyDefinition.from_record(ContentRecordReader.new({"id": "family.t", "name": "试派", "hearsay": [{"npc": "a", "topic": "x", "say": "y"}, {"skill": "s", "npc": "a", "topic": "x", "say": "z"}]}, "t", errors))
	_check(errors.is_empty() and plain.hearsay.size() == 2 and plain.hearsay[0].key.is_empty() and plain.hearsay[1].key == "hearsay/s/1", "a line of no school has no key; the others count per school: %s" % [errors])


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("family guides: " + label)
