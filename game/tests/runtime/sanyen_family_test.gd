extends RefCounted

## 山烟寺 B: 山烟寺 the family. 剃度 (daemon/class/bonze/master.c ask_for_join(), do_kneel()):
## asking 剃度 or 出家 marks a man not yet a monk (a temp), a monk and a woman each hear their
## line; 跪下受戒 (asked first) shaves him, names him (a prename at random + the first
## character of his name) and makes him a monk. 玄智 answers a 拜师 two seconds later (慢著
## while it is due): a woman and one not ordained hear their lines, a monk is taken (class
## bonze); an F_MASTER, he teaches his twelve skills to his own. The player's arts: 大乘佛法
## (杀气 100 at most), 诵经, 流云杖法 (str + max_force / 10 at least 50; practised with a staff
## for 60 kee), 莲华心法 (大乘佛法 at least its level; not practised; 疗伤 and 疗伤他人,
## lifeheal.c), 八识神通 (大乘佛法 10 and above it; enabled as 法术; its 神通 are 山烟寺 C).
## Then the real session in the 大雄宝殿: the 打听 panel's 跪下受戒, the refusals, the
## join, learning, 疗伤他人 on the HUD, Save/Continue with the 法名. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.bonze.master"
const LITTLE: StringName = &"sanyen.npc.little_bonze"
const FAMILY: StringName = &"family.sanyen"
const BROOM: StringName = &"es2:d/sanyen/obj/broom"
const SERVICE: StringName = &"sanyen.grounds.temple.master"
const TEMP: String = "pending/join_bonze"
const PREFIXES: String = "空明圆净虚悟方渡慧法"
const KNEEL_SAY: String = "玄智和尚说道：阿弥陀佛！善哉！善哉！施主若真心皈依我佛，请跪下(kneel)受戒。"
const MONK_SAY: String = "玄智和尚说道：阿弥陀佛！你我同是出家人，何故跟老衲开这等玩笑？"
const WOMAN_SAY: String = "玄智和尚说道：阿弥陀佛！女施主，这里是寺庙，请你到尼庵去剃度吧。"
const ASKED: String = "你想要拜玄智和尚为师。"
const NO_WOMEN: String = "玄智和尚说道：阿弥陀佛，女施主不要跟老纳开玩笑。"
const NOT_ORDAINED: String = "玄智和尚说道：阿弥陀佛，施主愿入佛门，请先到小寺剃度出家。"
const TAKES: String = "玄智和尚说道：阿弥陀佛，善哉！善哉！"
const SHAVE: Array[String] = ["你双手合十，恭恭敬敬地跪了下来。", "玄智和尚伸出手掌，在你头顶轻轻地摩挲了几下，将你的头发尽数剃去。"]
const LIFEHEAL: Array[String] = ["你坐了下来运起内功，将手掌贴在小沙弥背心，缓缓地将真气输入小沙弥体内....", "过了不久，你额头上冒出豆大的汗珠，小沙弥吐出一口瘀血，脸色看起来红润多了。"]


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_data()
	_test_ask_for_join()
	_test_dharma_name()
	_test_apprentice_rule()
	_test_learn()
	_test_practice()
	_test_lifeheal()
	_test_reminder_c()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"sanyen.grounds", &"sanyen.front_yard", &"sanyen.front_yard", &"sanyen.front_yard.gate_arrival").succeeded(), "TEST-ONLY: onto the temple grounds")
	await tree.physics_frame
	await tree.physics_frame
	session.player_runtime().state.gender = CharacterState.GENDER_MALE # TEST-ONLY: 雪工 is a man here
	await _test_not_ordained(tree, session)
	await _test_kneel(tree, session)
	await _test_join(tree, session)
	await _test_lifeheal_hud(tree, session)
	await _test_continue(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Data ---------------------------------------------------------------------------

func _test_data() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var rule: NpcTeaching.ApprenticeRule = master.teaching().apprentice
	_check(rule != null and rule.kind == NpcTeaching.Kind.REQUIREMENTS and rule.class_id == &"bonze" and rule.answer_after == 2.0 and rule.busy_say == "慢著，一个一个来。", "玄智: a requirements master who answers two seconds later, class bonze")
	_check(rule.checks.size() == 2 and rule.checks[0].gender == "男性" and rule.checks[0].class_id.is_empty() and rule.checks[1].class_id == &"bonze" and rule.checks[1].gender.is_empty() and rule.accept_say == "阿弥陀佛，善哉！善哉！", "do_recruit(): a man first, then a monk, each with its say")
	_check(master.teaching().family_id == FAMILY and master.teaching().family_generation == 26 and master.teaching().family_title == "住持" and master.teaching().f_master, "山烟寺's twenty-sixth 住持, an F_MASTER")
	var taught: Array[StringName] = NpcTeacher.teachable_skills(master, _catalog)
	_check(taught.size() == 12 and taught.has(&"buddhism") and taught.has(&"chanting") and taught.has(&"cloudstaff") and taught.has(&"lotusforce") and taught.has(&"essencemagic") and taught.has(&"magic"), "he teaches all twelve of his skills: %s" % [taught])
	var ordination: NpcOrdination = master.ordination()
	_check(ordination != null and ordination.temp == TEMP and "".join(ordination.prefixes) == PREFIXES and ordination.color == ColoredLine.HIC and ordination.class_id == &"bonze" and ordination.say == "从今以後你的法名叫做{name}。", "his 剃度: the temp, the ten prenames, HIC, class bonze")
	_check(NpcInquiry.topics(master).has("剃度") and NpcInquiry.topics(master).has("出家"), "剃度 and 出家 among the topics: %s" % [NpcInquiry.topics(master)])
	for id: StringName in [&"sanyen.npc.greeting", &"cloud.npc.monk_guard", LITTLE]:
		_check(_catalog.npc(id).teaching() == null and _catalog.npc(id).ordination() == null, "%s neither teaches nor ordains" % id)
	var lotus: SkillDefinition = _catalog.skill(&"lotusforce")
	_check(lotus.exert_functions == [&"heal", &"lifeheal"] and ExertFunctions.LABELS[&"lifeheal"] == "疗伤他人", "莲华心法: 疗伤 and 疗伤他人 (doc/skill/lotusforce)")
	_check(_catalog.skill(&"buddhism").kind == SkillDefinition.Kind.BASIC and _catalog.skill(&"chanting").kind == SkillDefinition.Kind.BASIC, "大乘佛法 and 诵经: basic knowledges")
	_check(_catalog.skill(&"essencemagic").can_enable_for(&"magic") and _catalog.skill(&"cloudstaff").can_enable_for(&"staff") and _catalog.skill(&"cloudstaff").can_enable_for(&"parry"), "八识神通 as 法术; 流云杖法 as staff and parry")


# --- 剃度 ---------------------------------------------------------------------------

## ask_for_join(): a monk first, then a woman, else the temp and 跪下受戒.
func _test_ask_for_join() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	for topic: String in ["剃度", "出家"]:
		var man: NpcInquiry.Answer = _ask(master, CharacterState.GENDER_MALE, &"", topic)
		_check(man.texts() == ["你向玄智和尚打听有关『%s』的消息。" % topic, KNEEL_SAY] and man.temps == [TEMP] and man.marks.is_empty(), "%s: a man is asked to kneel; a temp, not a mark: %s" % [topic, man.texts()])
		var woman: NpcInquiry.Answer = _ask(master, CharacterState.GENDER_FEMALE, &"", topic)
		_check(woman.texts()[1] == WOMAN_SAY and woman.temps.is_empty(), "%s: a woman is sent to a nunnery (请□ is 请你)" % topic)
		var monk: NpcInquiry.Answer = _ask(master, CharacterState.GENDER_MALE, &"bonze", topic)
		_check(monk.texts()[1] == MONK_SAY and monk.temps.is_empty(), "%s: a monk is asked why he jokes" % topic)
		_check(_ask(master, CharacterState.GENDER_FEMALE, &"bonze", topic).texts()[1] == MONK_SAY, "%s: the class is asked first" % topic)
		_check(_ask(master, CharacterState.GENDER_MALE, &"taoist", topic).temps == [TEMP], "%s: a 道士 is asked to kneel too (only a monk is not)" % topic)


## do_kneel(): prename[random(10)] + name[0..1].
func _test_dharma_name() -> void:
	var ordination: NpcOrdination = _catalog.npc(MASTER).ordination()
	var bounds: Array[int] = []
	var first := func(n: int) -> int:
		bounds.append(n)
		return 0
	var last := func(n: int) -> int:
		bounds.append(n)
		return n - 1
	_check(ordination.dharma_name("雪工", first) == "空雪" and ordination.dharma_name("凌雪", last) == "法凌" and bounds == [10, 10], "random(10): 空雪, 法凌: %s" % [bounds])
	_check(ordination.dharma_name("Lin", first) == "空L", "a name in letters: its first letter")


# --- Joining ------------------------------------------------------------------------

func _test_apprentice_rule() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var family: FamilyDefinition = _catalog.family(FAMILY)
	var man: CharacterState = _fresh(CharacterState.GENDER_MALE)
	var request := NpcApprenticeship.new()
	_check(not request.takes_at_once(man, master), "a commoner would not be taken (no question)")
	_check(request.request(man, master, family, 1, "壮士") == NpcApprenticeship.Outcome.ANSWER_DUE and request.lines == [ASKED], "拜师: only his request so far")
	_check(request.answer(man, master, family, 2, "壮士") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines == [NOT_ORDAINED] and not man.family.has_family(), "not ordained: 请先到小寺剃度出家: %s" % [request.lines])
	var woman: CharacterState = _fresh(CharacterState.GENDER_FEMALE)
	woman.affiliation.class_id = &"bonze" # TEST-ONLY: the woman is checked first
	request = NpcApprenticeship.new()
	request.request(woman, master, family, 1, "小师太")
	_check(request.answer(woman, master, family, 2, "小师太") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines == [NO_WOMEN], "a woman: 女施主不要跟老纳开玩笑, whatever her class")
	var monk: CharacterState = _monk()
	request = NpcApprenticeship.new()
	_check(request.takes_at_once(monk, master), "a monk would be taken (the panel asks first)")
	request.request(monk, master, family, 1, "大师")
	request.cancel()
	_check(request.request(monk, master, family, 2, "大师", NpcApprenticeship.COMMONER_TITLE, "", "", true) == NpcApprenticeship.Outcome.MASTER_BUSY and request.lines == [ASKED, "玄智和尚说道：慢著，一个一个来。"], "asked again while his answer is due: 慢著: %s" % [request.lines])
	_check(request.answer(monk, master, family, 3, "大师") == NpcApprenticeship.Outcome.RECRUITED, "his answer takes the monk")
	_check(request.lines == [TAKES, "玄智和尚决定收你为弟子。", "你跪了下来向玄智和尚恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为山烟寺的第二十七代弟子。"], "善哉, then recruit.c: %s" % [request.lines])
	_check(NpcApprenticeship.is_master_of(monk, master) and monk.family.family_id == FAMILY and monk.family.generation == 27 and monk.affiliation.class_id == &"bonze", "山烟寺's twenty-seventh generation, still a monk")
	_check(NpcApprenticeship.family_title("山烟寺", 27, monk.affiliation.family_title) == "山烟寺第二十七代弟子" and RankWords.query_rank(monk.gender, &"bonze") == "【 僧  人 】", "山烟寺第二十七代弟子, a 僧人")


# --- Learning -----------------------------------------------------------------------

func _test_learn() -> void:
	var stranger: CharacterState = _student(CharacterState.GENDER_MALE)
	stranger.affiliation.class_id = &"bonze" # TEST-ONLY: ordained, not his apprentice
	var refused: Array = _learn(stranger, &"buddhism")
	_check((refused[0] as LearnResult).failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT and _reject_lines("玄智和尚").has(refused[1][0]), "a monk not of 山烟寺 is politely refused: %s" % [refused[1]])
	var disciple: CharacterState = _member()
	for skill: StringName in [&"buddhism", &"chanting", &"staff", &"magic"]:
		_check((_learn(disciple, skill)[0] as LearnResult).success, "he teaches his apprentice %s" % skill)
	# 大乘佛法: 杀气 above 100 stops it.
	var calm: CharacterState = _member()
	calm.attributes.bellicosity = 101 # TEST-ONLY
	_check(_learn(calm, &"buddhism")[1] == ["你的杀气太重，无法修炼大乘佛法。"], "杀气 101: 大乘佛法 refused")
	calm.attributes.bellicosity = 100
	_check((_learn(calm, &"buddhism")[0] as LearnResult).success, "杀气 100: learnt")
	# 莲华心法: query_skill("buddhism") at least query_skill("lotusforce").
	var lotus: CharacterState = _member()
	lotus.skills.set_raw_level(&"lotusforce", 10) # TEST-ONLY: query_skill 5
	lotus.skills.set_raw_level(&"buddhism", 9) # query_skill 4
	_check(_learn(lotus, &"lotusforce")[1] == ["你的大乘佛法修为不够，无法领会更高深的莲华心法。"], "大乘佛法 4 is short of 5")
	lotus.skills.set_raw_level(&"buddhism", 10)
	_check((_learn(lotus, &"lotusforce")[0] as LearnResult).success, "大乘佛法 5: 莲华心法 learnt")
	# 八识神通: query_skill("buddhism") at least 10 and above query_skill("essencemagic").
	var sense: CharacterState = _member()
	sense.skills.set_raw_level(&"buddhism", 19) # TEST-ONLY: query_skill 9
	_check(_learn(sense, &"essencemagic")[1] == ["你的佛法修为还不够高深，无法学习八识神通。"], "大乘佛法 9: refused")
	sense.skills.set_raw_level(&"buddhism", 20)
	_check((_learn(sense, &"essencemagic")[0] as LearnResult).success, "大乘佛法 10: learnt")
	sense.skills.set_raw_level(&"essencemagic", 20) # query_skill 10
	_check(_learn(sense, &"essencemagic")[1] == ["你的佛法修为还不够高深，无法学习八识神通。"], "八识神通 10 is not below 大乘佛法 10")
	# 流云杖法: str + max_force / 10 at least 50.
	var staff: CharacterState = _member()
	staff.attributes.strength = 20 # TEST-ONLY
	staff.recovery.inner_force = CharacterInternalResourceState.new(0, 299)
	_check(_learn(staff, &"cloudstaff")[1] == ["你的膂力还不够，也许该练一练内力来增强力量。"], "str 20 + 29: refused")
	staff.recovery.inner_force = CharacterInternalResourceState.new(0, 300)
	_check((_learn(staff, &"cloudstaff")[0] as LearnResult).success, "str 20 + 30: learnt (no staff needed to learn it)")


func _test_practice() -> void:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var staff: CharacterState = _member()
	staff.attributes.strength = 20 # TEST-ONLY
	staff.recovery.inner_force = CharacterInternalResourceState.new(0, 300)
	staff.skills.set_raw_level(&"staff", 10)
	staff.skills.set_raw_level(&"cloudstaff", 5)
	staff.skills.map_skill(&"staff", &"cloudstaff")
	staff.vitality = CharacterResourceState.new(100, 100, 100)
	_check(_practice(staff, &"staff", registry) == ["你必须先找一根木杖或者是类似的武器，才能练杖法。"], "bare-handed: a staff first")
	staff.equipment.wield(EquippedWeaponRef.new(&"test.broom", _catalog.item(BROOM).weapon_definition()), false) # TEST-ONLY
	staff.vitality = CharacterResourceState.new(59, 100, 100)
	_check(_practice(staff, &"staff", registry) == ["你的体力不够练这门杖法，还是先休息休息吧。"] and staff.vitality.current == 59, "kee 59: its line, nothing paid")
	staff.vitality = CharacterResourceState.new(100, 100, 100)
	var learned: int = staff.skills.learned_progress(&"cloudstaff")
	var done: Array[String] = _practice(staff, &"staff", registry)
	_check(done == ["你的流云杖法进步了！"] and staff.vitality.current == 40 and staff.skills.learned_progress(&"cloudstaff") == learned + 3, "with the broom: 60 kee, staff 10 / 5 + 1: %s" % [done])
	staff.recovery.inner_force = CharacterInternalResourceState.new(0, 299)
	_check(_practice(staff, &"staff", registry) == ["你的膂力还不够，也许该练一练内力来增强力量。"], "valid_learn() first: str 20 + 29")
	var lotus: CharacterState = _member()
	lotus.skills.set_raw_level(&"force", 10)
	lotus.skills.set_raw_level(&"buddhism", 10)
	lotus.skills.set_raw_level(&"lotusforce", 2)
	lotus.skills.map_skill(&"force", &"lotusforce")
	_check(_practice(lotus, &"force", registry) == ["莲华心法只能用学的，或是从运用(exert)中增加熟练度。"], "莲华心法 refuses practice")
	var sense: CharacterState = _member()
	sense.skills.set_raw_level(&"magic", 10)
	sense.skills.set_raw_level(&"buddhism", 20)
	sense.skills.set_raw_level(&"essencemagic", 2)
	_check(SkillEnableService.enable(sense, _catalog.skill(&"essencemagic"), &"magic").applied and sense.skills.mapped_skill(&"magic") == &"essencemagic", "八识神通 enabled as 法术")
	_check(_practice(sense, &"magic", registry) == ["你试著练习八识神通，但是并没有任何进步。"], "practised: essencemagic.c has no practice_skill(): no progress")


# --- 疗伤他人 -----------------------------------------------------------------------

## lifeheal.c: the target named, neither side fighting, 150 force above max_force, the
## target's eff_kee at least a fifth of max_kee; its two HIY lines, eff_kee + 10 +
## query_skill("force") / 3, 150 force, force_factor 0.
func _test_lifeheal() -> void:
	var monk: CharacterState = _lotus()
	_check(ExertService.offered(monk, _catalog) == [&"heal", &"recover", &"refresh", &"regenerate"] and ExertService.offered(monk, _catalog, true) == [&"heal", &"recover", &"refresh", &"regenerate"], "on oneself (the 武学 page, the battle panel) no 疗伤他人: %s" % [ExertService.offered(monk, _catalog)])
	_check(ExertService.offered_at(monk, _catalog) == [&"lifeheal"], "on the one named: 疗伤他人")
	var swordsman: CharacterState = _member()
	swordsman.skills.set_raw_level(&"force", 30)
	swordsman.skills.set_raw_level(&"fonxanforce", 20)
	swordsman.skills.map_skill(&"force", &"fonxanforce")
	_check(ExertService.offered_at(swordsman, _catalog).is_empty() and ExertService.offered_at(CharacterState.new(), _catalog).is_empty(), "another force or none: nothing to use on another")
	var patient: SpecialSide = _patient(20, 100)
	var none: ExertResult = _exert_at(monk, null, false)
	_check(ColoredLine.texts(none.lines) == ["你要用真气为谁疗伤？"], "nobody named: 你要用真气为谁疗伤？")
	_check(ColoredLine.texts(_exert_at(monk, patient, true).lines) == ["战斗中无法运功疗伤！"], "the healer fighting: refused")
	patient.relationship.add_opponent(&"someone") # TEST-ONLY
	_check(ColoredLine.texts(_exert_at(monk, patient, false).lines) == ["战斗中无法运功疗伤！"] and monk.recovery.inner_force.current == 250, "the one named fighting: refused, nothing paid")
	patient = _patient(20, 100)
	monk.recovery.inner_force.current = 249
	_check(ColoredLine.texts(_exert_at(monk, patient, false).lines) == ["你的真气不够。"], "force 249 of 100: 149 above, not 150")
	monk.recovery.inner_force.current = 250
	patient = _patient(19, 100)
	_check(ColoredLine.texts(_exert_at(monk, patient, false).lines) == ["小沙弥已经受伤过重，经受不起你的真气震荡！"] and monk.recovery.inner_force.current == 250, "eff_kee 19 of 100: too badly hurt (震□ is 震荡)")
	patient = _patient(20, 100)
	monk.attributes.force_factor = 5
	var healed: ExertResult = _exert_at(monk, patient, false)
	_check(healed.succeeded() and ColoredLine.texts(healed.lines).slice(0, 2) == LIFEHEAL and healed.lines[0].color == ColoredLine.HIY and healed.lines[1].color == ColoredLine.HIY, "its two lines in HIY: %s" % [ColoredLine.texts(healed.lines)])
	_check(patient.state.vitality.effective == 41 and monk.recovery.inner_force.current == 100 and monk.attributes.force_factor == 0, "eff_kee 20 + 10 + 35 / 3; 150 force; force_factor 0")
	monk.recovery.inner_force.current = 250
	patient = _patient(95, 100)
	_exert_at(monk, patient, false)
	_check(patient.state.vitality.effective == 100, "cured up to max_kee only")
	monk.recovery.inner_force.current = 250
	var used: ExertResult = ExertService.exert(monk, &"lifeheal", _catalog, 35, false, ActionBusyState.new(), func(_n: int) -> int: return 0, SkillImprovementEffectRegistry.new(), &"player", [], Callable(), Callable(), _patient(50, 100), "小沙弥")
	_check(used.skill_improvement != null and used.skill_improvement.skill_id == &"lotusforce", "random(120) 0 < 35: 莲华心法 gains from use")


## The 神通 are 山烟寺 C: until then 八识神通 is learnt and enabled, never used.
func _test_reminder_c() -> void:
	var file: FileAccess = FileAccess.open("res://data/common/skills.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var record: Dictionary = {}
	for skill: Dictionary in (parsed as Dictionary)["skills"]:
		if skill["id"] == "essencemagic":
			record = skill
	_check(not record.is_empty() and not record.has("conjure") and _catalog.skill(&"essencemagic").cast_functions.is_empty(), "REMINDER (山烟寺 C): 八识神通's 空识, 心识 and 游识 come with C; replace this check with their tests")


# --- The session --------------------------------------------------------------------

## A man not yet a monk: 拜师 answers 请先到小寺剃度出家 two seconds later; he withdraws.
func _test_not_ordained(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	await _beside(tree, session, map, master)
	var service: TeacherService = map.service(SERVICE) as TeacherService
	_check(service != null and service.takes_apprentices(), "玄智 takes apprentices")
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and service.last_lines == [ASKED] and map.npc_life.apprentice_answer_due(master), "no question (he would not take a commoner); only the request: %s" % [service.last_lines])
	map.advance_npc_heartbeat(2.0)
	_check(session.shared_ui().log_lines()[-1] == NOT_ORDAINED and ui.apprentice_feedback.text == NOT_ORDAINED and not player.state.family.has_family(), "two seconds: 请先到小寺剃度出家, in the log and on the panel")
	ui.refresh()
	ui.cancel_button.pressed.emit()
	_check(not player.apprenticeship_request.is_pending(), "withdrawn")
	ui.close_panel()


## The 打听 panel: 剃度 brings 跪下受戒 (not to a woman); it asks first (取消 goes back to the
## panel); kneeling shaves and renames him, a monk now; asking again: 你我同是出家人. An
## unconscious 玄智 takes nobody's vows: a button left standing goes when pressed, and a
## question left open is closed. Save/Continue keeps the 法名 and the class.
func _test_kneel(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var master: NpcRuntimeState = _first(map, MASTER)
	await _beside(tree, session, map, master)
	map.select_npc(master.character_id)
	player.state.gender = CharacterState.GENDER_FEMALE # TEST-ONLY
	hud.open_ask()
	_press_topic(hud, "剃度")
	_check(hud.ask_answer_text().ends_with(WOMAN_SAY) and hud.ask_verbs_shown().is_empty() and not player.temp_marks.has(TEMP), "a woman: 请你到尼庵去剃度吧, nothing to kneel for")
	player.state.gender = CharacterState.GENDER_MALE # TEST-ONLY
	hud.open_ask()
	_check(hud.ask_topics_shown().has("剃度") and hud.ask_topics_shown().has("出家") and hud.ask_verbs_shown().is_empty(), "剃度 and 出家 to ask; nothing to kneel for yet")
	_press_topic(hud, "剃度")
	_check(hud.ask_answer_text().ends_with(KNEEL_SAY) and player.temp_marks.get(TEMP, 0) == 1, "跪下(kneel)受戒: the temp is set")
	_check(hud.ask_verbs_shown() == ["跪下受戒"], "the panel offers 跪下受戒: %s" % [hud.ask_verbs_shown()])
	master.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	_check(map.ordination_selected() == null and map.kneel_selected().is_empty() and player.facts.display_name == "雪工", "玄智 lying unconscious: no kneeling (默认)")
	_press_kneel(hud)
	_check(not hud.is_asking() and hud.ask_verbs_shown().is_empty(), "the button left standing goes when pressed, nothing asked")
	master.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	hud.open_ask()
	_press_kneel(hud)
	_check(hud.is_asking(), "awake again: asked first")
	master.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: knocked out while it asks
	hud._presentation_layout.validate_open_panel()
	_check(not hud.is_asking() and player.facts.display_name == "雪工", "the question closes: he can take no vows now")
	master.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	hud.open_ask()
	_press_kneel(hud)
	var question: String = hud.confirm_prompt.message.text
	_check(hud.is_asking() and question.contains("玄智和尚会剃去你的头发") and question.contains("「%s」" % PREFIXES) and question.contains("「雪」（例如「空雪」）") and hud.confirm_prompt.confirm_button.text == "确定受戒", "asked first, naming the 法名's making: %s" % question)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not hud.is_asking() and hud.ask_verbs_shown() == ["跪下受戒"] and player.facts.display_name == "雪工" and player.temp_marks.has(TEMP), "取消: back on the 打听 panel, nothing changed")
	_press_kneel(hud)
	hud.confirm_prompt.confirm_button.pressed.emit()
	var name: String = player.facts.display_name
	_check(name.length() == 2 and PREFIXES.contains(name[0]) and name[1] == "雪", "a 法名: one of the prenames, then 雪: %s" % name)
	var log: Array[String] = hud.log_lines()
	_check(log.slice(-3) == [SHAVE[0], SHAVE[1], "玄智和尚说道：从今以後你的法名叫做%s。" % name], "the shaving and his say: %s" % [log.slice(-3)])
	_check(player.state.affiliation.class_id == &"bonze" and not player.temp_marks.has(TEMP) and not player.state.family.has_family(), "a monk now, the temp gone, no family yet")
	hud.refresh_exploration()
	var label: Label = map.runtime_player_body().get_node_or_null("NameLabel") as Label
	_check(hud.player_name.text == name and (label == null or label.text == name), "the status card and the name over the body: %s" % name)
	map.select_npc(master.character_id)
	hud.open_ask()
	_press_topic(hud, "出家")
	_check(hud.ask_answer_text().ends_with(MONK_SAY) and hud.ask_verbs_shown().is_empty() and not player.temp_marks.has(TEMP), "asked again: 你我同是出家人, nothing to kneel for")
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, Work.capture(session), "山烟寺 B ordained")
	_check(walker._failures.is_empty(), "Save/Continue right after 剃度 (a monk with no family) restores exactly: " + str(walker._failures))


## A monk's 拜师: asked first (a first master), then 善哉 two seconds later; he learns.
func _test_join(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	await _beside(tree, session, map, master)
	var service: TeacherService = map.service(SERVICE) as TeacherService
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("拜玄智和尚为师，便成为山烟寺的弟子"), "a first master: asked first: %s" % ui.confirm_text.text)
	ui.confirm_button.pressed.emit()
	_check(service.last_lines == [ASKED] and not player.state.family.has_family(), "confirmed: his request; no answer yet")
	map.advance_npc_heartbeat(2.0)
	_check(NpcApprenticeship.is_master_of(player.state, master.definition()) and player.shown_title() == "山烟寺第二十七代弟子" and player.state.affiliation.class_id == &"bonze", "his answer takes him: 山烟寺第二十七代弟子, a monk")
	_check(service.last_lines[0] == TAKES and session.shared_ui().log_lines().has("恭喜您成为山烟寺的第二十七代弟子。"), "善哉 and recruit.c's lines: %s" % [service.last_lines])
	player.state.progression.potential = 1000 # TEST-ONLY
	var learned: LearnResult = service.request_learn(&"buddhism")
	_check(_taught(learned) and service.last_lines[0] == "你向玄智和尚请教有关「大乘佛法」的疑问。", "玄智 teaches his apprentice 大乘佛法: %s" % [service.last_lines])
	ui.close_panel()
	await tree.physics_frame


## 疗伤他人 on the HUD with 小沙弥 selected (莲华心法 enabled): his eff_kee rises, 150 force
## goes; with too little force the button still shows and the press says why.
func _test_lifeheal_hud(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var little: NpcRuntimeState = _first(map, LITTLE)
	await _beside(tree, session, map, little)
	map.select_npc(little.character_id)
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(not hud.lifeheal_button.visible, "without 莲华心法 enabled: no 疗伤他人")
	_make_lotus(player.state) # TEST-ONLY
	player.state.recovery.inner_force = CharacterInternalResourceState.new(149, 100)
	# TEST-ONLY: the maxima race/human.c gives that max_force (Continue recomputes them).
	CharacterDerivedValues.refresh_human_player_maxima(player.state, player.facts.age)
	var kee: CharacterResourceState = little.character_state.vitality
	little.character_state.vitality = CharacterResourceState.new(kee.maximum / 2, kee.maximum / 2, kee.maximum) # TEST-ONLY: hurt
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(hud.lifeheal_button.visible and hud.lifeheal_button.text == "疗伤他人", "莲华心法 enabled, 小沙弥 selected: 疗伤他人 on the HUD")
	hud.lifeheal_button.pressed.emit()
	_check(hud.log_lines()[-1] == "你的真气不够。" and little.character_state.vitality.effective == kee.maximum / 2, "force 149 of 100: 你的真气不够")
	player.state.recovery.inner_force.current = 300
	hud.lifeheal_button.pressed.emit()
	var level: int = session.martial_arts().force_level()
	_check(hud.log_lines().has(LIFEHEAL[0]) and hud.log_lines().has(LIFEHEAL[1]) and little.character_state.vitality.effective == mini(kee.maximum, kee.maximum / 2 + 10 + level / 3) and player.state.recovery.inner_force.current == 150, "healed: his eff_kee + 10 + %d / 3, 150 force" % level)
	await tree.physics_frame


## Save/Continue keeps the 法名, the class, the family and the master exactly.
func _test_continue(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	while player.busy.is_busy():
		player.busy.advance()
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "the save captures")
	if snapshot == null:
		return
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_check(encoded.succeeded() and encoded.text.contains(JSON.stringify(player.facts.display_name)) and not encoded.text.contains(JSON.stringify("雪工")), "the save holds the 法名, not the old name")
	_check(not encoded.text.contains(TEMP), "no temp in the save")
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "山烟寺 B")
	_check(walker._failures.is_empty(), "Save/Continue restores the monk exactly: " + str(walker._failures))


# --- Helpers ------------------------------------------------------------------------

func _ask(master: NpcDefinition, gender: StringName, class_id: StringName, topic: String) -> NpcInquiry.Answer:
	var asker := NpcInquiry.Asker.new(gender, 20, class_id, 100, {})
	return NpcInquiry.answer(master, master.gender, 74, true, asker, topic, "大雄宝殿", ScriptedWorldInteractionRandomSource.new([0]))


static func _reject_lines(npc: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in NpcRecognitionPolicy.REJECT_LINES:
		out.append(line % npc)
	return out


static func _taught(result: LearnResult) -> bool:
	return result.failure_reason not in [LearnResult.FailureReason.RECOGNITION_REJECTED, LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT]


static func _fresh(gender: StringName) -> CharacterState:
	return NewPlayerInitializationPolicy.create(gender, "山烟").state


static func _student(gender: StringName) -> CharacterState:
	var state: CharacterState = _fresh(gender)
	state.progression.potential = 100 # TEST-ONLY
	return state


## TEST-ONLY: ordained (class bonze), potential to spend.
static func _monk() -> CharacterState:
	var state: CharacterState = _student(CharacterState.GENDER_MALE)
	state.affiliation.class_id = &"bonze"
	return state


## 玄智's apprentice with potential to spend.
func _member() -> CharacterState:
	var state: CharacterState = _monk()
	var request := NpcApprenticeship.new()
	request.request(state, _catalog.npc(MASTER), _catalog.family(FAMILY), 1, "大师")
	request.answer(state, _catalog.npc(MASTER), _catalog.family(FAMILY), 2, "大师")
	return state


## TEST-ONLY: a member with force 30 and 莲华心法 20 enabled (query_skill("force") 35) and
## 250 force of 100.
func _lotus() -> CharacterState:
	var state: CharacterState = _member()
	_make_lotus(state)
	return state


static func _make_lotus(state: CharacterState) -> void:
	state.skills.set_raw_level(&"force", 30)
	state.skills.set_raw_level(&"buddhism", 40)
	state.skills.set_raw_level(&"lotusforce", 20)
	state.skills.map_skill(&"force", &"lotusforce")
	state.recovery.inner_force = CharacterInternalResourceState.new(250, 100)


## TEST-ONLY: one to heal with eff_kee `effective` of `maximum`.
static func _patient(effective: int, maximum: int) -> SpecialSide:
	var state := CharacterState.new()
	state.vitality = CharacterResourceState.new(effective, effective, maximum)
	return SpecialSide.new(&"little", state, ActionBusyState.new(), CombatRelationshipState.new(&"little"))


func _exert_at(state: CharacterState, target: SpecialSide, fighting: bool) -> ExertResult:
	var level: int = state.skills.effective_level(&"force")
	return ExertService.exert(state, &"lifeheal", _catalog, level, fighting, ActionBusyState.new(), _never, SkillImprovementEffectRegistry.new(), &"player", [], Callable(), Callable(), target, "小沙弥")


## random(n) at its highest: nothing improves.
func _never(n: int) -> int:
	return n - 1


## learn <skill> from 玄智 standing at full sen; [LearnResult, its lines].
func _learn(student: CharacterState, skill_id: StringName) -> Array:
	var definition: NpcDefinition = _catalog.npc(MASTER)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"sanyen.grounds.temple.test", &"sanyen.temple.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
	var random := ScriptedWorldInteractionRandomSource.new([0])
	var context: TeachingContext = NpcTeacher.context(npc, skill_id, true, false, random)
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var skill: SkillDefinition = _catalog.skill(skill_id)
	var result: LearnResult = LearnService.learn(student, context, skill, registry.policy_for(skill_id), null, random)
	var respect: String = RankWords.query_respect(student.gender, 14, student.affiliation.class_id)
	return [result, LearnLines.lines(result, definition.display_name, skill, student, context, respect)]


func _practice(state: CharacterState, use_id: StringName, registry: SkillLearnPolicyRegistry) -> Array[String]:
	var special: StringName = state.skills.mapped_skill(use_id)
	var skill: SkillDefinition = _catalog.skill(special)
	var result: PracticeResult = PracticeService.practice(state, use_id, skill.practice_policy(), registry.policy_for(special), false)
	return ColoredLine.texts(TrainingLines.practice(result, skill))


func _press_topic(hud: SharedGameplayUI, topic: String) -> void:
	for button: Node in hud._ask_topics.get_children():
		if not button.is_queued_for_deletion() and (button as Button).text == topic:
			(button as Button).pressed.emit()
			return
	_check(false, "no topic button %s" % topic)


func _press_kneel(hud: SharedGameplayUI) -> void:
	for button: Node in hud._ask_verbs.get_children():
		if not button.is_queued_for_deletion():
			(button as Button).pressed.emit()
			return
	_check(false, "no 跪下受戒 button")


## TEST-ONLY: the player beside the NPC, where its teaching reaches.
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 60.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("山烟寺 B: " + label)
