extends RefCounted

## 乔阴 C: 步玄派 (daemon/class/scholar). 骆云舟's attempt_apprentice(): one with marks/桃林
## is taken (class scholar; marks/书生 and marks/桃林 cleared), anyone else is sent to the 桃林
## and marked 书生, which opens entrance.c's way east (taolin_steps 3). The 桃林 (taolin.c):
## the 字条 reads one of eleven lines with its way left out; the way it names brings the way
## out a step nearer, any other three further, and the note is drawn anew after each; the
## right way with one step left leads out to the 曼雩台 with marks/桃林. 放弃 wakes the
## player in the Inn (plan default). His teaching (his thirteen skills); the player's 步玄七诀
## (practice 20 kee and 20 sen; valid_learn: 步玄心法 enabled, 音律 at least half), 小步玄剑
## (30 kee and 5 force; 步玄心法 30, max_force 100, a sword), 步玄心法 (learnt only);
## 「玄羽乱舞」 through 行动 or 轻功 (perform move.hasten) on the battle panel; 风泉剑灵's
## chant waits while the player is away and goes into the save (owner, option A).
## TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.scholar.master"
const SOUL: StringName = &"common.npc.scholar.sword_soul"
const SCHOLAR: StringName = &"choyin.npc.scholar"
const FAMILY: StringName = &"family.buxuan"
const NOTE: StringName = &"choyin.taolin.landmark.note"
const GROVE: StringName = &"choyin.taolin.landmark.grove"
const TAOLIN: StringName = &"choyin.taolin"
const ENTRANCE: StringName = &"choyin.entrance"
const STEPS: String = "taolin_steps"
const ASKED: String = "你想要拜骆云舟为师。"
const GO_EAST: String = "骆云舟说道：你还是先走一趟东边的桃林吧。"
const BLOCKED: String = "东行的道路被骆云舟挡住了."
const OUT: String = "你走出了桃林"
const WAYS: Array[String] = ["north", "south", "west", "east", "northwest", "southeast"]
## taolin.c's Note_Msg: the line and its dir_<way>.
const NOTES: Dictionary[String, String] = {
	"欲将愁心附明月,随君直到夜郎--": "west",
	"问君能有几多愁,恰似一江春水向--流": "east",
	"自笑堂堂汉使,得似洋洋河水,依旧只流--": "east",
	"--朝四百八十寺,多少楼台烟雨中": "south",
	"孔雀--飞,五里一徘徊": "southeast",
	"帘卷--风,人比黄花叟": "west",
	"醉别--楼醒不记,春梦秋云,聚散真容易": "west",
	"春草绿色,春水碧波,送君--埔,伤之如何": "south",
	"--望，射天狼": "northwest",
	"--风卷地白草折，胡天八月即飞雪": "north",
	"青山横--郭，白水绕东城": "north",
}


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_data()
	_test_maze_rule()
	_test_apprentice_rule()
	_test_learn()
	_test_practice()
	_test_perform()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"choyin.town", ENTRANCE, ENTRANCE, &"choyin.entrance.grove_return").succeeded(), "TEST-ONLY: on the 曼雩台")
	await tree.physics_frame
	await tree.physics_frame
	await _test_sent_east(tree, session)
	await _test_grove(tree, session)
	await _test_give_up(tree, session)
	await _test_way_out(tree, session)
	await _test_join(tree, session)
	await _test_chant(tree, session)
	await _test_hasten(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Data ---------------------------------------------------------------------------

func _test_data() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var teaching: NpcTeaching = master.teaching()
	var rule: NpcTeaching.ApprenticeRule = teaching.apprentice
	_check(rule != null and rule.kind == NpcTeaching.Kind.REQUIREMENTS and rule.class_id == &"scholar" and rule.answer_after == 0.0, "骆云舟: a requirements master who answers at once, class scholar")
	_check(rule.checks.size() == 1 and rule.checks[0].mark == "桃林" and rule.checks[0].refuse_marks == ["书生"] and rule.checks[0].requires.is_empty() and rule.unmarks == ["书生", "桃林"], "marks/桃林 needed; the refusal marks 书生; whom he takes loses both")
	_check(teaching.family_id == FAMILY and teaching.family_generation == 7 and teaching.family_title == "掌门人" and teaching.f_master, "步玄派's seventh 掌门人, an F_MASTER")
	var taught: Array[StringName] = NpcTeacher.teachable_skills(master, _catalog)
	_check(taught.size() == 13 and taught.has(&"mysterrier") and taught.has(&"mystforce") and taught.has(&"mystsword") and taught.has(&"music") and taught.has(&"instruments") and taught.has(&"move") and taught.has(&"perception") and taught.has(&"literate"), "he teaches all thirteen of his skills: %s" % [taught])
	var steps: SkillDefinition = _catalog.skill(&"mysterrier")
	_check(steps.can_enable_for(&"dodge") and steps.can_enable_for(&"move") and steps.perform_functions == [&"hasten"], "步玄七诀: 轻功 and 行动, 「玄羽乱舞」")
	_check(_catalog.skill(&"mystsword").can_enable_for(&"sword") and _catalog.skill(&"mystsword").can_enable_for(&"parry") and _catalog.skill(&"mystforce").can_enable_for(&"force"), "小步玄剑 sword and parry; 步玄心法 force")
	var note: WorldLandmarkDefinition = _catalog.landmark(NOTE)
	var notes: Dictionary[String, String] = {}
	for each: WorldLandmarkDefinition.MazeNote in note.notes:
		notes[each.text] = String(each.way)
	_check(notes == NOTES, "the eleven notes and their ways, as taolin.c's Note_Msg: %s" % [notes])
	_check(note.policy == &"note_maze" and note.zone_id == TAOLIN and note.enter_portal_id == &"choyin.entrance.east" and note.counter == STEPS and note.mark == "桃林" and note.setting("steps") == 3 and note.portal_id == &"choyin.taolin.out", "the 字条: the way in sets taolin_steps 3, the way out marks 桃林")
	_check(note.description == "这是一张指示路径的字条.似乎可以读(read)它.\n" and note.action_label == "读" and note.message("read") == "你看见:{note}" and note.message("out") == OUT, "its look and its lines verbatim")
	var ways: Array[String] = []
	for portal: PortalDefinition in _catalog.portals_for_map(&"choyin.town"):
		if portal.source_zone_id == TAOLIN and portal.destination_zone_id == TAOLIN:
			ways.append(portal.legacy_command)
	ways.sort()
	var expected: Array[String] = WAYS.duplicate()
	expected.sort()
	_check(ways == expected, "six ways, each back into the grove (taolin.c's exits; northeast and southwest commented out): %s" % [ways])
	_check(_catalog.portal(&"choyin.taolin.out").destination_zone_id == ENTRANCE and _catalog.portal(&"choyin.entrance.east").destination_zone_id == TAOLIN, "out to the 曼雩台; in from it")
	var rule_east: ZoneExitRuleDefinition = _catalog.exit_rules_between(ENTRANCE, TAOLIN)[0]
	_check(rule_east.mark == "书生" and rule_east.lines == [BLOCKED], "the way east needs marks/书生")
	_check(_catalog.landmark(GROVE).action_label == "放弃" and _catalog.portal(_catalog.landmark(GROVE).portal_id).destination_zone_id == &"snow.inn.main_floor", "放弃: the Inn")


## do_go(): the note's way with taolin_steps <= 1 leads out; otherwise one nearer, any other three further.
func _test_maze_rule() -> void:
	var note: WorldLandmarkDefinition = _catalog.landmark(NOTE)
	_check(not note.leads_out(3, true) and note.steps_after(3, true) == 2 and note.steps_after(2, true) == 1, "3 → 2 → 1 the right way")
	_check(note.leads_out(1, true) and note.leads_out(0, true) and not note.leads_out(1, false), "at 1 (or none set) the right way leads out, a wrong one does not")
	_check(note.steps_after(3, false) == 6 and note.steps_after(1, false) == 4, "a wrong way: three further")


# --- Joining ------------------------------------------------------------------------

func _test_apprentice_rule() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var family: FamilyDefinition = _catalog.family(FAMILY)
	var student: CharacterState = _fresh()
	var request := NpcApprenticeship.new()
	_check(not request.takes_at_once(student, master), "without marks/桃林 he would not take the player (no question)")
	_check(request.request(student, master, family, 1, "小兄弟") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and request.lines == [ASKED, GO_EAST], "拜师: 你还是先走一趟东边的桃林吧: %s" % [request.lines])
	_check(student.marks.get("书生", 0) == 1 and not student.family.has_family() and not request.is_pending(), "marks/书生 set; the request over (默认, 山烟寺 C)")
	student.marks["桃林"] = 1 # TEST-ONLY: out of the grove
	_check(request.takes_at_once(student, master), "with marks/桃林 he takes the player")
	_check(request.request(student, master, family, 2, "小兄弟") == NpcApprenticeship.Outcome.RECRUITED, "taken")
	_check(request.lines == [ASKED, "骆云舟说道：很好，小兄弟多加努力，他日必定有成。", "骆云舟决定收你为弟子。", "你跪了下来向骆云舟恭恭敬敬地磕了四个响头，叫道：「师父！」", "恭喜您成为步玄派的第八代弟子。"], "his say, then recruit.c: %s" % [request.lines])
	_check(NpcApprenticeship.is_master_of(student, master) and student.family.family_id == FAMILY and student.family.generation == 8 and student.affiliation.class_id == &"scholar" and not student.marks.has("书生") and not student.marks.has("桃林"), "步玄派's eighth generation, a scholar; both marks gone")
	_check(request.request(student, master, family, 3, "小兄弟") == NpcApprenticeship.Outcome.ACKNOWLEDGED and student.marks.is_empty(), "asked again: 师父！ (apprentice.c), no new mark")
	# One of another family betrays it.
	var swordsman: CharacterState = _fresh()
	swordsman.family = FamilyState.new(&"family.fonxan", 14) # TEST-ONLY: a 封山剑派 member
	swordsman.marks["桃林"] = 1 # TEST-ONLY
	_check(NpcApprenticeship.would_betray(swordsman, master), "a 封山剑派 member would betray it (the panel asks)")
	var betray := NpcApprenticeship.new()
	_check(betray.request(swordsman, master, family, 2, "小兄弟") == NpcApprenticeship.Outcome.RECRUITED and betray.lines.has("你决定背叛师门，改投入骆云舟门下！！") and swordsman.family.family_id == FAMILY and swordsman.apprenticeship.betrayer_count == 1 and swordsman.marks.is_empty(), "the betrayal lines, betrayer + 1, the marks gone")


# --- Learning -----------------------------------------------------------------------

func _test_learn() -> void:
	var stranger: CharacterState = _student()
	var refused: Array = _learn(stranger, &"mystforce")
	_check((refused[0] as LearnResult).failure_reason == LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, "one not his apprentice is refused (F_MASTER): %s" % [refused[1]])
	var disciple: CharacterState = _member()
	for skill: StringName in [&"mystforce", &"music", &"instruments", &"literate", &"move", &"perception", &"dodge", &"sword"]:
		_check((_learn(disciple, skill)[0] as LearnResult).success, "he teaches his apprentice %s" % skill)
	# 步玄七诀: 步玄心法 enabled for force, then 音律 at least half of 步玄七诀.
	var steps: CharacterState = _member()
	_check(_learn(steps, &"mysterrier")[1] == ["步玄七诀必须配合步玄心法使用。"], "步玄心法 not enabled: refused")
	steps.skills.set_raw_level(&"force", 10)
	steps.skills.set_raw_level(&"mystforce", 10)
	steps.skills.map_skill(&"force", &"mystforce")
	steps.skills.set_raw_level(&"mysterrier", 20) # TEST-ONLY: query_skill 10
	steps.skills.set_raw_level(&"music", 9)
	_check(_learn(steps, &"mysterrier")[1] == ["你的音律之学修为不够，无法领悟更高深的步玄七诀。"], "音律 9 below 10 / 2... (query_skill 4 < 5)")
	steps.skills.set_raw_level(&"music", 10)
	_check((_learn(steps, &"mysterrier")[0] as LearnResult).success, "音律 query_skill 5: learnt")
	# 小步玄剑: 步玄心法 30 (raw), max_force 100, a sword in hand.
	var sword: CharacterState = _member()
	sword.skills.set_raw_level(&"mystforce", 29)
	sword.recovery.inner_force = CharacterInternalResourceState.new(0, 100)
	sword.equipment.wield(Martial.sword(), false) # TEST-ONLY
	_check(_learn(sword, &"mystsword")[1] == ["你的步玄心法火候还不够。"], "步玄心法 29: refused")
	sword.skills.set_raw_level(&"mystforce", 30)
	sword.recovery.inner_force = CharacterInternalResourceState.new(0, 99)
	_check(_learn(sword, &"mystsword")[1] == ["你的内力不够，没有办法练小步玄剑。"], "max_force 99: refused")
	sword.recovery.inner_force = CharacterInternalResourceState.new(0, 100)
	_check((_learn(sword, &"mystsword")[0] as LearnResult).success, "步玄心法 30, max_force 100, a sword: learnt")
	var bare: CharacterState = _member()
	bare.skills.set_raw_level(&"mystforce", 30)
	bare.recovery.inner_force = CharacterInternalResourceState.new(0, 100)
	_check(_learn(bare, &"mystsword")[1] == ["你必须先找一把剑才能练剑法。"], "bare-handed: a sword first")


func _test_practice() -> void:
	var registry := SkillLearnPolicyRegistry.new()
	registry.register_known_legacy_policies()
	var steps: CharacterState = _member()
	steps.skills.set_raw_level(&"force", 10)
	steps.skills.set_raw_level(&"mystforce", 10)
	steps.skills.map_skill(&"force", &"mystforce")
	steps.skills.set_raw_level(&"music", 20)
	steps.skills.set_raw_level(&"dodge", 10)
	steps.skills.set_raw_level(&"mysterrier", 5)
	steps.skills.map_skill(&"dodge", &"mysterrier")
	steps.vitality = CharacterResourceState.new(19, 100, 100)
	steps.spirit = CharacterResourceState.new(100, 100, 100)
	_check(_practice(steps, &"dodge", registry) == ["你的气或神不够，不能练步玄七诀。"] and steps.vitality.current == 19 and steps.spirit.current == 100, "kee 19: its line, nothing paid")
	steps.vitality = CharacterResourceState.new(100, 100, 100)
	steps.spirit = CharacterResourceState.new(19, 100, 100)
	_check(_practice(steps, &"dodge", registry) == ["你的气或神不够，不能练步玄七诀。"], "sen 19: the same line")
	steps.spirit = CharacterResourceState.new(100, 100, 100)
	var progress: int = steps.skills.learned_progress(&"mysterrier")
	var done: Array[String] = _practice(steps, &"dodge", registry)
	_check(steps.vitality.current == 80 and steps.spirit.current == 80 and steps.skills.learned_progress(&"mysterrier") > progress, "20 kee and 20 sen, progress: %s" % [done])
	steps.skills.unmap_skill(&"force")
	_check(_practice(steps, &"dodge", registry) == ["步玄七诀必须配合步玄心法使用。"], "valid_learn() first: 步玄心法 not enabled")
	var sword: CharacterState = _member()
	sword.skills.set_raw_level(&"mystforce", 30)
	sword.recovery.inner_force = CharacterInternalResourceState.new(10, 100)
	sword.skills.set_raw_level(&"sword", 10)
	sword.skills.set_raw_level(&"mystsword", 5)
	sword.skills.map_skill(&"sword", &"mystsword")
	sword.vitality = CharacterResourceState.new(100, 100, 100)
	_check(_practice(sword, &"sword", registry) == ["你必须先找一把剑才能练剑法。"], "bare-handed: a sword first")
	sword.equipment.wield(Martial.sword(), false) # TEST-ONLY
	sword.recovery.inner_force.current = 4
	_check(_practice(sword, &"sword", registry) == ["你的内力或气不够，没有办法练习小步玄剑。"], "force 4: refused")
	sword.recovery.inner_force.current = 10
	var lines: Array[String] = _practice(sword, &"sword", registry)
	_check(lines.size() >= 1 and lines[0] == "你按著所学练了一遍小步玄剑。" and sword.vitality.current == 70 and sword.recovery.inner_force.current == 5, "30 kee and 5 force, its line: %s" % [lines])
	var force: CharacterState = _member()
	force.skills.set_raw_level(&"force", 10)
	force.skills.set_raw_level(&"mystforce", 5)
	force.skills.map_skill(&"force", &"mystforce")
	_check(_practice(force, &"force", registry) == ["步玄心法只能学，或是从运用(exert)中增加熟练度。"], "步玄心法 refuses practice")
	_check(ExertService.offered(force, _catalog).has(&"recover"), "步玄心法 enabled: the basic force's 恢复气 (its own exert files are commented out)")


## perform.c's <martial>. form: 「玄羽乱舞」 through 轻功 or 行动, whatever is in hand; the
## weapon arts still only with what is in hand.
func _test_perform() -> void:
	var state: CharacterState = _hasty()
	_check(PerformService.offered(state, _catalog) == [&"hasten"] and PerformService.martial_for(state, _catalog, &"hasten") == &"dodge", "bare-handed, 步玄七诀 as 轻功: 「玄羽乱舞」 (perform dodge.hasten)")
	state.skills.map_skill(&"move", &"mysterrier")
	_check(PerformService.martial_for(state, _catalog, &"hasten") == &"move", "as 行动 too: perform move.hasten, as 骆云舟 says it")
	state.equipment.wield(Martial.sword(), false) # TEST-ONLY
	state.skills.set_raw_level(&"mystsword", 50)
	state.skills.map_skill(&"sword", &"mystsword")
	_check(PerformService.offered(state, _catalog) == [&"hasten"], "with a sword and 小步玄剑 (no files of its own): still 「玄羽乱舞」")
	state.skills.unmap_skill(&"dodge")
	state.skills.unmap_skill(&"move")
	_check(PerformService.offered(state, _catalog).is_empty(), "步玄七诀 not enabled: nothing")
	var fonxan := CharacterState.new()
	fonxan.skills.set_raw_level(&"fonxansword", 50)
	fonxan.skills.map_skill(&"sword", &"fonxansword")
	fonxan.skills.map_skill(&"parry", &"fonxansword")
	_check(PerformService.offered(fonxan, _catalog).is_empty(), "封山剑法 bare-handed (enabled as 招架 too): no 字诀, as before")
	# The file through the dodge use, with its practice.
	var me: SpecialSide = _side(&"player", _hasty(), &"npc")
	me.is_user = true
	var npc: SpecialSide = _side(&"npc", CharacterState.new(), &"player")
	me.state.recovery.inner_force = CharacterInternalResourceState.new(170, 100)
	var context := SpecialContext.new(me, [npc], Specials.Pattern.new([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]).legacy_random, _catalog, SkillImprovementEffectRegistry.new(), [npc])
	context.target = npc
	var fights := ChoyinNpcsFights.new()
	fights.enemy = &"npc"
	context.attack_source = fights
	var progress: int = me.state.skills.learned_progress(&"mysterrier")
	_check(PerformService.perform(context, &"hasten"), "perform dodge.hasten runs")
	_check(context.lines[0].template == "$N使出步玄七诀第一式「玄羽乱舞」，身法陡然加快！" and context.lines[0].color == ColoredLine.HIY, "its HIY line")
	_check(me.state.recovery.inner_force.current == 170 - 10 * 3 and me.state.vitality.current == 200 - 10 * 3 and me.busy.busy_value == 3, "query_skill(\"mysterrier\") 40 / 2 = 20: three rounds of 10 kee and 10 force; busy 3 (%d)" % me.state.recovery.inner_force.current)
	_check(me.state.skills.learned_progress(&"mysterrier") == progress + 1, "random(120) 0 < query_skill(mysterrier): practised (weak mode)")


# --- The session --------------------------------------------------------------------

## 拜师 without marks/桃林: no question, his say, marks/书生; the way east opens.
func _test_sent_east(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var master: NpcRuntimeState = _first(map, MASTER)
	_check(not await MapPlaces.take_same_map_passage(tree, map, &"choyin.entrance.east", 240) and player.world_location().zone_id == ENTRANCE and hud.log_lines().has(BLOCKED), "east: 东行的道路被骆云舟挡住了.")
	await _beside(tree, session, map, master)
	var service: TeacherService = _teacher(map, master)
	_check(service != null and service.takes_apprentices(), "骆云舟 takes apprentices")
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(not ui.is_confirming() and service.last_lines == [ASKED, GO_EAST] and player.state.marks.get("书生", 0) == 1, "no question; 你还是先走一趟东边的桃林吧, marks/书生: %s" % [service.last_lines])
	ui.close_panel()
	await tree.physics_frame
	await tree.physics_frame


## The way in sets taolin_steps 3; the note reads; a wrong way puts the way out three further
## and leads back into the grove; Save/Continue keeps the steps.
func _test_grove(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.take_same_map_passage(tree, map, &"choyin.entrance.east"), "east into the peach woods")
	_check(player.world_location().zone_id == TAOLIN and player.state.counters.get(STEPS, 0) == 3 and hud.log_lines().has("你来到桃林。"), "in the 桃林, taolin_steps 3")
	var note: WorldLandmarkDefinition = _catalog.landmark(NOTE)
	_check(map.select_landmark(NOTE), "the 字条 selected")
	map.traverse_selected_portal()
	var shown: WorldLandmarkDefinition.MazeNote = map.mazes.note(note)
	_check(hud.log_lines()[-1] == "你看见:" + shown.text and player.world_location().zone_id == TAOLIN, "读: 你看见:%s" % shown.text)
	var wrong: String = WAYS[0] if String(shown.way) != WAYS[0] else WAYS[1]
	_check(await MapPlaces.take_same_map_passage(tree, map, StringName("choyin.taolin." + wrong)), "a wrong way (%s)" % wrong)
	_check(player.world_location().zone_id == TAOLIN and player.state.counters.get(STEPS, 0) == 6 and hud.log_lines().has("你来到桃林。"), "back in the grove, the way out three further: %d" % player.state.counters.get(STEPS, 0))
	await tree.physics_frame
	await tree.physics_frame
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_check(encoded.succeeded() and encoded.text.contains("\"counters\"") and encoded.text.contains("\"taolin_steps\""), "the save holds taolin_steps")
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "乔阴 C in the 桃林")
	_check(walker._failures.is_empty(), "Save/Continue in the 桃林 restores exactly: " + str(walker._failures))


## 放弃 (plan default): the Inn.
func _test_give_up(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(map.select_landmark(GROVE), "the grove selected")
	map.traverse_selected_portal()
	await tree.physics_frame
	await tree.physics_frame
	_check(player.world_location().zone_id == &"snow.inn.main_floor" and hud.log_lines().has("你在桃林里苦等良久，终于昏昏沉沉地睡了过去……醒来时，你已经躺在雪亭镇的饮风客栈里。"), "放弃: the Inn")
	_check(session.handoff_to(&"choyin.town", ENTRANCE, ENTRANCE, &"choyin.entrance.grove_return").succeeded(), "TEST-ONLY: back on the 曼雩台")
	await tree.physics_frame
	await tree.physics_frame


## Into the grove again (taolin_steps 3 anew), then the way each note names until the last
## leads out: 你走出了桃林, marks/桃林, the steps gone, on the 曼雩台.
func _test_way_out(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var note: WorldLandmarkDefinition = _catalog.landmark(NOTE)
	_check(await MapPlaces.take_same_map_passage(tree, map, &"choyin.entrance.east") and player.state.counters.get(STEPS, 0) == 3, "in again: taolin_steps 3 anew")
	var taken: Array[String] = []
	for step: int in range(3):
		var way: String = String(map.mazes.note(note).way)
		taken.append(way)
		if not await MapPlaces.take_same_map_passage(tree, map, StringName("choyin.taolin." + way)):
			_check(false, "could not take the way %s" % way)
			return
		if step < 2:
			_check(player.world_location().zone_id == TAOLIN and player.state.counters.get(STEPS, 0) == 2 - step, "the right way (%s): %d left" % [way, 2 - step])
	_check(player.world_location().zone_id == ENTRANCE and hud.log_lines().has(OUT) and player.state.marks.get("桃林", 0) == 1 and not player.state.counters.has(STEPS), "three right ways (%s): 你走出了桃林, on the 曼雩台, marks/桃林" % [taken])
	var log: Array[String] = hud.log_lines()
	var out_at: int = log.rfind(OUT)
	_check(out_at >= 0 and out_at + 1 < log.size() and log[out_at + 1] == "你来到曼雩台。", "you walk out, then the 曼雩台: %s" % [log.slice(out_at)])


## 拜师 with marks/桃林: asked first (a first master), then his say and the recruit; both marks
## go, so the way east is shut again; he teaches.
func _test_join(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var master: NpcRuntimeState = _first(map, MASTER)
	await _beside(tree, session, map, master)
	var service: TeacherService = _teacher(map, master)
	service.ui.interact()
	var ui: TeacherPanel = service.ui
	ui.apprentice_button.pressed.emit()
	_check(ui.is_confirming() and ui.confirm_text.text.begins_with("拜骆云舟为师，便成为步玄派的弟子"), "a first master: asked first: %s" % ui.confirm_text.text)
	ui.confirm_button.pressed.emit()
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, &"")
	_check(service.last_lines.slice(0, 2) == [ASKED, "骆云舟说道：很好，%s多加努力，他日必定有成。" % respect] and service.last_lines.has("恭喜您成为步玄派的第八代弟子。"), "很好，%s多加努力: %s" % [respect, service.last_lines])
	_check(NpcApprenticeship.is_master_of(player.state, master.definition()) and player.state.affiliation.class_id == &"scholar" and player.shown_title() == "步玄派第八代弟子" and not player.state.marks.has("书生") and not player.state.marks.has("桃林"), "步玄派第八代弟子, a scholar; the marks gone")
	player.state.progression.potential = 1000 # TEST-ONLY
	var learned: LearnResult = service.request_learn(&"mystforce")
	_check(learned != null and learned.failure_reason not in [LearnResult.FailureReason.RECOGNITION_REJECTED, LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT] and service.last_lines[0] == "你向骆云舟请教有关「步玄心法」的疑问。", "he teaches his apprentice 步玄心法: %s" % [service.last_lines])
	ui.close_panel()
	await tree.physics_frame
	await tree.physics_frame
	_check(not await MapPlaces.take_same_map_passage(tree, map, &"choyin.entrance.east", 240) and player.world_location().zone_id == ENTRANCE, "the way east is shut again (marks/书生 gone, as ES2)")


## Owner, option A: the 剑灵's chant keeps its place (stage and seconds left) while the player
## is on another map, goes into the save, and goes on after Continue where it stopped.
func _test_chant(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var soul: NpcRuntimeState = map.npcs.summon_one(&"choyin.town.entrance.sword_soul") # TEST-ONLY: as 骆云舟's death brings it
	_check(soul != null, "TEST-ONLY: 风泉剑灵 on the 曼雩台")
	if soul == null:
		return
	map.npc_life.start_chant(soul)
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(20.0)
	_check(hud.log_lines()[-1] == "风泉剑灵说道：剑气指天 ..." and soul.chant_stage == 1 and is_equal_approx(soul.chant_left, 20.0), "剑气指天 ...; the next in 20 s")
	map.npc_life._advance_ambience(12.0)
	_check(is_equal_approx(soul.chant_left, 8.0), "12 s on: 8 s left")
	var said: int = hud.log_lines().size()
	_check(session.handoff_to(&"choyin.temple_altar", &"choyin.altar", &"choyin.altar", &"choyin.altar.stairs_arrival").succeeded(), "TEST-ONLY: the player goes to another map")
	await tree.physics_frame
	session.advance_npc_heartbeat(120.0)
	_check(soul.chant_stage == 1 and is_equal_approx(soul.chant_left, 8.0), "away: the chant waits (8 s left)")
	_check(session.handoff_to(&"choyin.town", ENTRANCE, ENTRANCE, &"choyin.entrance.grove_return").succeeded(), "TEST-ONLY: back on the 曼雩台")
	await tree.physics_frame
	await tree.physics_frame
	map = session.active_map() as WorldMapController
	map.npc_life._advance_ambience(0.0)
	map.npc_life._advance_ambience(5.0)
	_check(soul.chant_stage == 1 and is_equal_approx(soul.chant_left, 3.0) and not hud.log_lines().slice(said).has("风泉剑灵说道：剑心内敛 ..."), "back: on from where it stopped (3 s left)")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var kept: Array[String] = []
	for record: GameSaveValueTypes.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
		if record.npc_definition_id == SOUL:
			kept.append("%d/%d" % [record.chant_stage, record.chant_left_ms])
	_check(encoded.succeeded() and encoded.text.contains("\"chant\"") and kept == ["1/3000"], "the save holds its stage and the 3 s left: %s" % [kept])
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "乔阴 C chanting")
	_check(walker._failures.is_empty(), "Save/Continue with the chant under way restores exactly: " + str(walker._failures))
	# Continue: the chant goes on where it stopped, the time out of the game not counted.
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue")
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	fresh.set_process(false)
	var town: WorldMapController = fresh.active_map() as WorldMapController
	var again: NpcRuntimeState = _first(town, SOUL)
	_check(again != null and again.chant_stage == 1 and is_equal_approx(again.chant_left, 3.0), "the 剑灵 again, its chant 3 s from 剑心内敛")
	if again != null:
		town.npc_life._advance_ambience(0.0)
		town.npc_life._advance_ambience(3.0)
		_check(fresh.shared_ui().log_lines().has("风泉剑灵说道：剑心内敛 ...") and again.chant_stage == 2, "剑心内敛 ... three seconds after Continue")
	fresh.free()
	await tree.process_frame
	soul.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD) # TEST-ONLY: out of the way
	map.npc_life._advance_ambience(0.0)
	_check(soul.chant_stage < 0, "a dead chanter's chant goes with it")


## 「玄羽乱舞」 on the battle panel with 步玄七诀 enabled as 轻功, against a 书生.
func _test_hasten(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(await MapPlaces.drive_through(tree, map, [&"choyin.bridge5", &"choyin.bridge4", &"choyin.bridge3", &"choyin.bridge2"]), "back over the bridge to the 书生")
	var scholar: NpcRuntimeState = _first(map, SCHOLAR)
	await _beside(tree, session, map, scholar)
	# TEST-ONLY: 步玄七诀 enabled, force above max_force, a sturdy 书生.
	var state: CharacterState = player.state
	state.skills.set_raw_level(&"force", 10)
	state.skills.set_raw_level(&"mystforce", 10)
	state.skills.map_skill(&"force", &"mystforce")
	state.skills.set_raw_level(&"dodge", 40)
	state.skills.set_raw_level(&"mysterrier", 40)
	state.skills.map_skill(&"dodge", &"mysterrier")
	state.recovery.inner_force = CharacterInternalResourceState.new(300, 100)
	state.vitality = CharacterResourceState.new(state.vitality.maximum, state.vitality.maximum, state.vitality.maximum)
	scholar.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	map.select_npc(scholar.character_id)
	session.configure_combat_random_source(Specials.Pattern.new())
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the 书生")
	var offered: Array[StringName] = []
	for info: CombatTacticalActionInfo in coordinator.action_infos():
		if info.category == CombatTacticalRequest.Category.MARTIAL_SPECIAL:
			offered.append(info.action_id)
	_check(offered == [&"perform.hasten"] and BattleActionPresentationCatalog.new().label_for(&"perform.hasten") == "使出「玄羽乱舞」", "the battle panel: 使出「玄羽乱舞」: %s" % [offered])
	var encounter: CombatEncounter = coordinator.active_encounter()
	var code: int = coordinator.submit_player_action(CombatTacticalRequest.new(&"school-test:1", encounter.encounter_id, player.character_id, &"perform.hasten", CombatTacticalRequest.Category.MARTIAL_SPECIAL)).code
	_check(code == CombatTacticalResult.Code.ACCEPTED, "queued")
	coordinator.advance_scheduler(0.0)
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	ui.refresh_projection()
	var text: String = ui.log_panel._text.get_parsed_text()
	_check(text.contains("你使出步玄七诀第一式「玄羽乱舞」，身法陡然加快！") and text.contains("你迅捷无伦地在书生身旁绕了一圈 ..."), "its lines in the battle log")
	_check(state.recovery.inner_force.current == 300 - 30 and player.busy.busy_value == 3, "three rounds (query_skill 20 / 20 + 2): 30 force; busy 3 (%d)" % state.recovery.inner_force.current)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "nothing aborted: " + coordinator.last_abort_detail())


# --- Helpers ------------------------------------------------------------------------

## hasten.c's fight()s as choyin_npcs_test records them: a blow each round.
class ChoyinNpcsFights:
	extends SpecialAttackSource
	var enemy: StringName = &""

	func fight(attacker_id: StringName, victim_id: StringName) -> SpecialAttack:
		return SpecialAttack.new(attacker_id, victim_id, CombatSingleAttackExecutionResult.new(), null)

	func select_opponent(_attacker_id: StringName, _random: Callable) -> StringName:
		return enemy


static func _fresh() -> CharacterState:
	return NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "云舟").state


static func _student() -> CharacterState:
	var state: CharacterState = _fresh()
	state.progression.potential = 100 # TEST-ONLY
	return state


## 骆云舟's apprentice with potential to spend.
func _member() -> CharacterState:
	var state: CharacterState = _student()
	state.marks["桃林"] = 1 # TEST-ONLY: out of the grove
	NpcApprenticeship.new().request(state, _catalog.npc(MASTER), _catalog.family(FAMILY), 1, "小兄弟")
	return state


## TEST-ONLY: 步玄七诀 40 enabled as 轻功 (步玄心法 for force), 200 kee.
static func _hasty() -> CharacterState:
	var state := CharacterState.new()
	state.progression.combat_experience = 1000
	state.skills.set_raw_level(&"dodge", 40)
	state.skills.set_raw_level(&"mysterrier", 40)
	state.skills.map_skill(&"dodge", &"mysterrier")
	state.skills.set_raw_level(&"mystforce", 10)
	state.skills.map_skill(&"force", &"mystforce")
	state.essence = CharacterResourceState.new(200, 200, 200)
	state.vitality = CharacterResourceState.new(200, 200, 200)
	state.spirit = CharacterResourceState.new(200, 200, 200)
	return state


func _side(id: StringName, state: CharacterState, opponent: StringName) -> SpecialSide:
	var relationship := CombatRelationshipState.new(id)
	relationship.add_opponent(opponent)
	var side := SpecialSide.new(id, state, ActionBusyState.new(), relationship,
		func(key: StringName) -> int: return state.timed_applies.value(key))
	side.location_id = &"here"
	return side


## learn <skill> from 骆云舟 standing at full sen; [LearnResult, its lines].
func _learn(student: CharacterState, skill_id: StringName) -> Array:
	var definition: NpcDefinition = _catalog.npc(MASTER)
	var body := CharacterState.new()
	body.attributes.intelligence = definition.base_attribute_overrides().intelligence()
	body.spirit = CharacterResourceState.new(300, 300, 300)
	for skill: NpcSkillLevelDefinition in definition.skill_levels():
		body.skills.set_raw_level(skill.skill_id, skill.raw_level)
	var npc := NpcRuntimeState.new(&"test.teacher", definition, &"choyin.town.entrance.test", &"choyin.entrance.test.1", body, CombatRelationshipState.new(&"test.teacher"), ActionBusyState.new(), ArmorState.new())
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


func _teacher(map: WorldMapController, npc: NpcRuntimeState) -> TeacherService:
	for service: WorldService in map.service_nodes:
		if service is TeacherService and npc != null and (service as TeacherService).npc.character_id == npc.character_id:
			return service as TeacherService
	return null


## TEST-ONLY: the player beside the NPC, where its teaching reaches.
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 60.0)
	if at == Vector2.INF:
		at = MapPlaces.spot(map, zone_id, body.global_position, 140.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("choyin school: " + label)
