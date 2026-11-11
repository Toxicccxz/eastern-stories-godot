extends RefCounted

## 势力线第一批 封山 B (计划 build/plans/势力线第一批_计划.md §3; DECISIONS「封山 B」): the 竹书 — 柳淳风's
## way with the 大黄石 (the mark opens it), the one book given to the father or to
## the daughter; the 内院 scene (the children, the 铁盾会's boy where 大秦人留下了, 柳淳风 walking in);
## the split — 本宗 (掌门传人, 柳绘心 to 绮云镇's gate) or 北宗 (the branch family, no betrayal) — each
## with the 「点」字诀; 封山守渡口 as the finale's eighth band, the ending's 雪亭 lines; and the line
## cut short for one who left the family.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const MASTER: StringName = &"common.npc.swordsman.master"
const GIRL: StringName = &"snow.npc.girl"
const BOY: StringName = &"native.npc.north_pupil_boy"
const LITTLE: StringName = &"native.npc.north_pupil_girl"
const YOUTH: StringName = &"native.npc.shield_youth"
const NORTH_GIRL: StringName = &"native.npc.liu_huixin_north"
const BOOK: StringName = &"es2:d/canyon/bamboo/obj/parry_book"
const SLIPCASE: StringName = &"es2:d/canyon/bamboo/obj/slipcase"
const STONE: StringName = &"canyon.bamboo3.stone"
const GAP: StringName = &"canyon.bamboo3.gap"
const BOOKCASE: StringName = &"canyon.train.bookcase"
const QUEST: StringName = &"faction.fonxan"
const POINT: StringName = &"powerfocus"

var _count: int = 0
var _failures: Array[String] = []
## The performs' practice rolls (random(120)); the 「点」字诀 itself draws nothing.
var _random := GodotCombatRandomSource.new(7, true)


## The attack a perform makes, noted with the apply/damage its performer held as it struck.
class Strikes:
	extends SpecialAttackSource
	var damage_held: Array[int] = []
	var performer: CharacterState

	func attack(_attacker_id: StringName, _victim_id: StringName) -> SpecialAttack:
		damage_held.append(performer.timed_applies.value(&"damage"))
		return null


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_rules()
	_test_point()
	_test_lapse()
	var session: WorldSessionController = await _session(tree)
	await _test_book(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_north(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_orthodox(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	var book: StoryQuestDefinition.Step = quest.step(&"book")
	_check(book.is_branch() and book.weight == StoryQuestDefinition.WEIGHT_SMALL and book.options.size() == 2 and book.objective.contains("想读，先读") and book.objective.contains("书只有一本"), "the 竹书 is the second small choice, and says to read it first")
	var split: StoryQuestDefinition.Step = quest.step(&"split")
	_check(split.is_branch() and split.weight == StoryQuestDefinition.WEIGHT_BIG and split.options.size() == 2, "the 南北宗 is the line's one big choice")
	_check(split.objective.contains("掌门传人") and split.objective.contains("柳绘心离开武馆") and split.objective.contains("转入北宗") and split.objective.contains("柳淳风不再教你"), "what either side costs is said before the choice")
	var orthodox: StoryQuestDefinition.Reward = split.options[0].reward
	var north: StoryQuestDefinition.Reward = split.options[1].reward
	_check(orthodox.rank_family == &"family.fonxan" and orthodox.rank_title == "掌门传人" and orthodox.branch_to.is_empty(), "本宗: 掌门传人")
	_check(north.branch_from == &"family.fonxan" and north.branch_to == &"family.fonxan_north" and north.branch_title == "弟子" and north.rank_title.is_empty(), "北宗: the branch family")
	_check(quest.lapses != null and quest.lapsed_text.contains("不是封山的人") and quest.lapsed_mark == "封山的线断了", "the line lapses for one who left the family, and marks them")
	# What the line's people do for one walking it, they do not for one who walked out of it (or came back: the line does not begin twice).
	var master: NpcDefinition = catalog.npc(MASTER)
	var books: Array = master.dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == BOOK)
	_check(books.size() == 3 and (books[0] as NpcObjectRule).giver_mark == "竹书给了柳绘心" and not (books[0] as NpcObjectRule).accept and (books[1] as NpcObjectRule).accept and (books[1] as NpcObjectRule).unless_giver_mark == "封山的线断了" and (books[1] as NpcObjectRule).giver_family == &"family.fonxan", "柳淳风 takes the book of a 封山 disciple still in the line, and not one already given to his daughter")
	var gone: Dictionary[String, int] = {"内院撞见了": 1, "柳淳风说过门房": 1, "封山的线断了": 1}
	var no_flags: Dictionary[StringName, bool] = {}
	var nothing_carried: Array[String] = []
	for topic: String in ["本宗", "竹书"]:
		var answer: NpcInquiryRule = NpcInquiryRule.decide(master.talk().inquiry_rules(topic), gone, null, &"", &"", 0, no_flags, nothing_carried, &"family.fonxan")
		_check(answer != null and answer.mark_asker.is_empty() and answer.marks_asker.is_empty(), "柳淳风's 「%s」 to one who left and came back: a word, and nothing given" % topic)
	_check(not master.talk().confirm_applies("本宗", gone), "and no confirm of a choice that is not theirs")
	var comes: Array = catalog.npc(BOY).hooks().calls.filter(func(call: NpcHooks.Call) -> bool: return call.act.steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.COMES))
	_check(comes.size() == 1 and (comes[0] as NpcHooks.Call).act.steps[1].kind == ScriptedAct.Kind.BY and catalog.npc(BOY).hooks().calls.all(func(call: NpcHooks.Call) -> bool: return call.act.when != null), "柳淳风 speaks for himself once he has come in (nobody says his lines if he cannot); every call of the scene asks that the line still runs")
	# The 「点」字诀: listed by the skill, asked of whoever would use it, its numbers the skill's.
	var sword: SkillDefinition = catalog.skill(&"fonxansword")
	_check(sword.perform_functions.has(POINT) and sword.perform_when.has(POINT) and sword.perform_number(POINT, "force") == 30 and sword.perform_number(POINT, "slip_busy") == 2, "封山剑法 has the 「点」字诀, with a condition and its numbers")
	_check(SpecialFunctions.perform(POINT).label == "「点」字诀" and catalog.pacing().beat_rules().cost_of_action(CombatBeatRules.perform_key(POINT)) == 2, "「点」字诀 costs two moves")
	# Who stands where.
	var inner: NpcSpawnDefinition = catalog.spawn(&"native.innerhall.liu_huixin")
	_check(inner != null and inner.npc_definition_id == GIRL and inner.same_person == &"snow.school_compound.nyard.girl" and inner.zone_id == &"snow.innerhall", "柳绘心 in the 内院 is the one of the 书房 (same_person)")
	_check(catalog.spawn(&"native.entrance.liu_huixin").zone_id == &"cloud.entrance" and catalog.npc(NORTH_GIRL).description.contains("封山剑派北宗"), "柳绘心 at 绮云镇's gate, under her board")
	var girl: NpcDefinition = catalog.npc(GIRL)
	_check(girl.teaching().family_id == &"family.fonxan_north" and girl.teaching().family_privileges == -1, "柳绘心 is of the 北宗 (girl.c) with every privilege: learn.c lets her teach her own")
	var ask: Array = girl.dealings().object_rules.filter(func(rule: NpcObjectRule) -> bool: return rule.item == BOOK and rule.accept)
	_check(ask.size() == 1 and (ask[0] as NpcObjectRule).ask.contains("给出去就读不到了") and (ask[0] as NpcObjectRule).mark_giver == "竹书给了柳绘心", "the gift to 柳绘心 is asked first, and says the book is gone with it")
	var gather: StoryQuestDefinition.Step = catalog.story_quest(&"main.finale").step(&"gather")
	_check(gather.checklist.any(func(row: StoryQuestDefinition.CheckRow) -> bool: return row.label == "封山（柳淳风）守渡口") and gather.checklist.any(func(row: StoryQuestDefinition.CheckRow) -> bool: return row.label == "北宗（柳绘心）守渡口"), "点将 has a row for either 封山")


## The stone and the bookcase, branch by branch.
func _test_rules() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var stone: RoomActDefinition = catalog.service(STONE).act
	_check(stone.acts.size() == 3 and stone.acts[0].at_least.get("force", 0) == 560 and stone.acts[1].mark == "柳淳风说了推法" and stone.acts[1].when == null and stone.acts[1].at_least.is_empty(), "the 大黄石: ES2's 560 first, then 柳淳风's way, then the refusal")
	var taught := ScriptedAct.Facts.new()
	taught.marks = {"柳淳风说了推法": 1}
	_check(stone.act_for(&"男性", &"", taught) == stone.acts[1], "taught, with no force at all: the stone opens")
	var untaught := ScriptedAct.Facts.new()
	_check(stone.act_for(&"男性", &"", untaught) == stone.acts[2], "one 柳淳风 never told: as ES2")
	var bookcase: RoomActDefinition = catalog.service(BOOKCASE).act
	var given := ScriptedAct.Facts.new()
	given.item_exists = func(_id: StringName) -> bool: return false
	given.holds = func(_condition: JournalEntryDefinition) -> bool: return true
	_check(bookcase.acts.size() == 3 and bookcase.act_for(&"男性", &"", given) == bookcase.acts[1] and bookcase.acts[1].steps.size() == 1, "the book once given is not found again, even if it left the world")


## 「点」字诀: only for one taught; one thrust the harder, or a slip.
func _test_point() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state := CharacterState.new()
	state.skills.set_raw_level(&"sword", 40)
	state.skills.set_raw_level(&"fonxansword", 40)
	state.skills.map_skill(&"sword", &"fonxansword")
	state.equipment.wield(Martial.sword(), false) # TEST-ONLY
	_check(PerformService.offered(state, catalog) == [&"counterattack", &"swordjab", &"fakefault"], "untaught: the three ES2 wrote: %s" % [PerformService.offered(state, catalog)])
	state.marks["学了点字诀"] = 1
	_check(PerformService.offered(state, catalog).has(POINT), "taught: the 「点」字诀 is offered")
	state.recovery.inner_force = CharacterInternalResourceState.new(100, 100)
	state.progression.combat_experience = 1000
	var foe := CharacterState.new()
	var me: SpecialSide = _side(&"player", state, &"npc")
	var them: SpecialSide = _side(&"npc", foe, &"player")
	var strikes := Strikes.new()
	strikes.performer = state
	var context := SpecialContext.new(me, [them], _random.legacy_random, catalog, SkillImprovementEffectRegistry.new(), [them])
	context.attack_source = strikes
	_check(PerformService.perform(context, POINT), "performed")
	_check(state.recovery.inner_force.current == 70 and strikes.damage_held.size() == 1 and strikes.damage_held[0] == 12 + state.skills.effective_level(&"fonxansword", 0) * 25 / 100 and state.timed_applies.value(&"damage") == 0, "30 force for one thrust at damage + %s, nothing kept after" % [strikes.damage_held])
	_check(context.lines.size() == 1 and context.lines[0].template.contains("劲力尽数聚在剑尖") and not me.busy.is_busy(), "its line; no busy")
	state.recovery.inner_force.current = 20
	context = SpecialContext.new(me, [them], _random.legacy_random, catalog, SkillImprovementEffectRegistry.new(), [them])
	context.attack_source = strikes
	_check(PerformService.perform(context, POINT) and strikes.damage_held.size() == 1, "short of force: performed, and no thrust")
	_check(state.recovery.inner_force.current == 0 and me.busy.is_busy() and context.lines[0].template.contains("险些脱手"), "the force is gone, the sword all but leaves the hand: busy")
	state.marks.erase("学了点字诀")
	me.busy = ActionBusyState.new()
	context = SpecialContext.new(me, [them], _random.legacy_random, catalog, SkillImprovementEffectRegistry.new(), [them])
	_check(not PerformService.perform(context, POINT) and context.fail_line != null and context.fail_line.template.contains("没有这种功能"), "untaught: perform.c's own refusal")
	_check(BattleActionPresentationCatalog.new().tooltip_for(CombatPerformTacticalPolicy.action_id_for(POINT)).contains("用 30 点内力"), "its button says what it costs: %s" % BattleActionPresentationCatalog.new().tooltip_for(CombatPerformTacticalPolicy.action_id_for(POINT)))


## The line is cut short for one who left 封山: recorded once, no longer active, never done.
func _test_lapse() -> void:
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(QUEST)
	var state := CharacterState.new()
	var no_temps: Dictionary[String, int] = {}
	var nothing: Dictionary[StringName, bool] = {}
	state.family = FamilyState.new(&"family.fonxan", 14)
	StoryQuestLog.record(state, no_temps, nothing, &"", quests)
	_check(StoryQuestLog.is_active(state, quest), "a 封山 disciple: the line runs")
	state.family = FamilyState.new(&"family.fonxan_north", 14)
	_check(StoryQuestLog.record(state, no_temps, nothing, &"", quests).filter(func(fresh: StoryQuestLog.Fresh) -> bool: return fresh.kind == StoryQuestLog.Kind.LAPSED).is_empty(), "the 北宗 is still 封山: it runs on")
	state.family = FamilyState.new(&"family.celestial", 3)
	var told: Array[StoryQuestLog.Fresh] = StoryQuestLog.record(state, no_temps, nothing, &"", quests).filter(func(fresh: StoryQuestLog.Fresh) -> bool: return fresh.quest == quest)
	_check(told.size() == 1 and told[0].kind == StoryQuestLog.Kind.LAPSED and told[0].reward() == null, "another family: the line lapses, and gives nothing")
	_check(StoryQuestLog.is_lapsed(state, quest) and not StoryQuestLog.is_active(state, quest) and not StoryQuestLog.is_done(state, quest) and state.marks.get("封山的线断了", 0) == 1, "over, not done, and marked")
	_check(StoryQuestLog.told_lines(told[0], true, state)[0].text.contains("【任务中止】封山剑派"), "told once")
	_check(StoryQuestLog.record(state, no_temps, nothing, &"", quests).filter(func(fresh: StoryQuestLog.Fresh) -> bool: return fresh.quest == quest).is_empty(), "and only once")
	var shown: Array[StoryQuestLog.Shown] = StoryQuestLog.shown(state, quests, StoryQuestDefinition.LINE_FACTION)
	_check(shown.size() == 1 and shown[0].lapsed and shown[0].objective.is_empty() and shown[0].entries[-1].contains("到此为止"), "the 任务 page keeps it, with its last word and nothing to do")
	_check(StoryQuestLog.tracked(state, quests) != quest, "it is not followed any more")


## 柳淳风's word, the stone his way, the book out of the bookcase, and to him.
func _test_book(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.fonxan_gated(session)
	state.marks.erase("柳淳风说过门房") # TEST-ONLY: he has not said his word yet
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"bamboo_hear", "after the 门房: ask 柳淳风 of the 竹书")
	var hall: WorldMapController = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	await _settle(tree)
	var master: NpcRuntimeState = _first(session, &"snow.schoolhall", MASTER)
	_check(hall.select_npc(master.character_id) and not hall.ask_topics_selected().has("竹书") and not hall.ask_topics_selected().has("本宗"), "before his word on the 门房, the 竹书 is not on the list")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("柳淳风说过门房", 0) == 1 and hall.ask_topics_selected().has("竹书") and not hall.ask_topics_selected().has("本宗"), "he says it, and speaks of the book: now it is listed")
	_check(_said(_ask(hall, master, "竹书"), "青苔印") and state.marks.get("柳淳风说了推法", 0) == 1, "柳淳风 tells of the book and how the stone is pushed")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/bamboo_hear") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"bamboo", "step bamboo_hear done; next the 竹林道")
	# The stone: a fresh character's force, 柳淳风's way.
	var bamboo: WorldMapController = MapPlaces.enter(session, &"canyon.bamboo3", &"canyon.bamboo3.stoneroom_return")
	await _settle(tree)
	var stone: ActService = bamboo.service(STONE) as ActService
	_check(bamboo.place_player(&"canyon.bamboo3", MapPlaces.service_spot(bamboo, STONE)), "TEST-ONLY: at the stone")
	await _settle(tree)
	_resources(player, 100, 100, 100)
	stone.interact()
	await tree.physics_frame
	_check(ui.log_lines()[-1].contains("照柳淳风教的法子") and session.room_states().has_flag(&"canyon.bamboo3", "exits/enter"), "taught: the stone moves: %s" % ui.log_lines()[-1])
	_check(player.state.vitality.current == 40 and player.state.recovery.inner_force.current < 560, "it costs what ES2's push costs (60 kee), and asks no force")
	(bamboo.service(GAP) as ActService).interact()
	await _settle(tree)
	var room: WorldMapController = session.active_map() as WorldMapController
	_check(room != null and room.map_id() == &"canyon.stoneroom", "into the 洞内石室")
	_check(room.place_player(&"canyon.train", MapPlaces.service_spot(room, BOOKCASE)), "TEST-ONLY: at the bookcase")
	await _settle(tree)
	(room.service(BOOKCASE) as ActService).interact()
	await tree.physics_frame
	_check(not _carried(session, SLIPCASE).is_empty() and session.player_held_item_ids().has(BOOK), "the 书匣, the book in it")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/bamboo") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"book", "step bamboo done with the book still in its 书匣; next: whose it is")
	# TEST-ONLY: the book taken out of the 书匣 (the 背包's 取出), as canyon_bamboo_test does it by the button.
	var inventory: InventoryState = session.inventory_state()
	var inside: Array[StringName] = inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, _carried(session, SLIPCASE)))
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)
	_check(inside.size() == 1 and InventoryTransferService.new().transfer(inventory, inside[0], InventoryTransferDestination.new(carried, true, true, 1000000)).succeeded, "TEST-ONLY: the book in the pack")
	# 柳绘心 will not have it before her father has been seen… he has; a stranger's book is handed back.
	hall = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	await _settle(tree)
	master = _first(session, &"snow.schoolhall", MASTER)
	state.marks.erase("柳淳风说过门房") # TEST-ONLY: as one who brought the book before the line came to it
	_check(hall.select_npc(master.character_id), "柳淳风 selected")
	hall.give_to_selected(_carried(session, BOOK))
	_check(not _carried(session, BOOK).is_empty() and not state.marks.has("竹书给了柳淳风"), "before the line is there, he hands it back")
	state.marks["柳淳风说过门房"] = 1
	var given: ItemHandlingResult = hall.give_to_selected(_carried(session, BOOK))
	_check(_carried(session, BOOK).is_empty() and state.marks.get("竹书给了柳淳风", 0) == 1 and given != null and given.lines.any(func(line: String) -> bool: return line.contains("年轻时的糊涂话")), "given to 柳淳风: 年轻时的糊涂话")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/book/father") and DeedLog.done(state, "把《悟疾风劲竹书》带回来交给了柳淳风") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"yard", "the choice and its deed; next the 内院")
	_check(_said(_ask(hall, master, "竹书"), "书在匣里"), "he keeps it in its case")
	# The stage is set as the player next comes to the 武馆: she is in the 内院 with those she teaches.
	_check(_count_in(session, &"snow.nyard", GIRL) == 1 and _count_in(session, &"snow.innerhall", BOY) == 0, "nothing changes in front of the player")
	MapPlaces.enter(session, &"snow.school1", &"snow.school1.gate_return")
	await _settle(tree)
	var study: WorldMapController = MapPlaces.enter(session, &"snow.nyard", &"snow.nyard.girl.1")
	await _settle(tree)
	_check(_count_in(session, &"snow.nyard", GIRL) == 0 and _count_in(session, &"snow.innerhall", GIRL) == 1, "柳绘心 has left the 书房 for the 内院 (%d, %d)" % [_count_in(session, &"snow.nyard", GIRL), _count_in(session, &"snow.innerhall", GIRL)])
	_check(study != null and _count_in(session, &"snow.innerhall", BOY) == 1 and _count_in(session, &"snow.innerhall", LITTLE) == 1 and _count_in(session, &"snow.innerhall", YOUTH) == 0, "two children with her; no 铁盾会 boy where the 大秦人 did not stay")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("在柳淳风的匣里"), "the 声望 page says where the book is")
	# 章与章之间的衔接: what this chapter played out holds what the next suite's fixture writes.
	var handoff: Array[String] = StoryFixtures.missing_after_play(session, StoryFixtures.fonxan_book_given.bind(false))
	_check(handoff.is_empty(), "竹书 played (to 柳淳风) leaves what fonxan_book_given(father) writes: %s" % [handoff])


## The book to the daughter, the scene with the 铁盾会's boy, and the 北宗.
func _test_north(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.fonxan_book_given(session, true)
	state.marks["大秦人留下了"] = 1 # TEST-ONLY: 番坊 C, the 大秦人's side
	state.progression.score = 321 # TEST-ONLY
	session.record_journal()
	var inner: WorldMapController = MapPlaces.enter(session, &"snow.innerhall", &"snow.innerhall.liu_huixin.1")
	await _settle(tree)
	_check(_count_in(session, &"snow.innerhall", GIRL) == 1 and _count_in(session, &"snow.innerhall", BOY) == 1 and _count_in(session, &"snow.innerhall", LITTLE) == 1 and _count_in(session, &"snow.innerhall", YOUTH) == 1, "柳绘心, two children and the 铁盾会's boy in the 内院")
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(session.scene_held() and inner.scene_running() and state.marks.get("内院撞见了", 0) == 1, "the scene holds the player as they come in, and is marked seen")
	session.record_journal()
	_check(not state.quests.has("faction.fonxan/yard"), "what was seen is not written down before it has been seen")
	var counter: Array[WorldWait] = inner.npc_life.waits()
	_check(counter.size() == 1 and counter[0].text.ends_with("/ 10 句"), "the counter counts the ten calls told to this player, not the one for the other holder of the book: %s" % [counter.map(func(wait: WorldWait) -> String: return wait.text)])
	var log_before: int = ui.log_lines().size()
	for second: int in 60:
		if not inner.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not inner.scene_running() and not session.scene_held(), "the scene is over")
	var lines: Array[String] = ui.log_lines().slice(log_before)
	_check(_said(lines, "剑尖别抬") and _said(lines, "我不收钱") and _said(lines, "我们的盾，换你们的剑"), "柳绘心 teaching, and 安敦's boy: %s" % [lines.slice(0, 4)])
	_check(_said(lines, "绘心。") and _said(lines, "并回去的条件只有一条") and _count_in(session, &"snow.innerhall", MASTER) == 1, "柳淳风 walks in and says the rule")
	_check(_said(lines, "这是你二十岁自己写的") and not _said(lines, "没有根的东西"), "the book is hers: she has the line of it")
	_check(_said(lines, "本宗的规矩，你守不守") and _said(lines, "你要是觉得我没有错"), "both ask the player")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/yard") and StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"split", "step yard done; the split is next")
	var master: NpcRuntimeState = _first(session, &"snow.innerhall", MASTER)
	var girl: NpcRuntimeState = _first(session, &"snow.innerhall", GIRL)
	_check(inner.select_npc(master.character_id) and inner.ask_topics_selected().has("本宗") and inner.select_npc(girl.character_id) and inner.ask_topics_selected().has("北宗"), "now 本宗 and 北宗 can be asked")
	_check(catalog.npc(GIRL).talk().ask_confirm("北宗").contains("这不算叛师") and catalog.npc(GIRL).talk().ask_confirm("北宗").contains("柳淳风不再教你") and catalog.npc(GIRL).talk().confirm_applies("北宗", state.marks), "her confirm says what it costs and that it is no betrayal")
	_check(_said(_ask(inner, girl, "北宗"), "北宗就有两个人了") and state.marks.get("跟了北宗", 0) == 1 and state.marks.get("学了点字诀", 0) == 1, "北宗: taken in, and the 「点」字诀 taught")
	_check(_said(_ask(inner, master, "本宗"), "不能再教了") and not state.marks.has("跟了本宗"), "the other side is closed")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/split/north") and StoryQuestLog.is_done(state, catalog.story_quest(QUEST)) and DeedLog.done(state, "和柳绘心立了封山剑派北宗"), "the choice, its deed, and the line ends")
	_check(state.family.family_id == &"family.fonxan_north" and state.family.generation == 14 and state.affiliation.family_title == "弟子" and not state.apprenticeship.has_master(), "of the 北宗 now, in the generation they had, with no master")
	_check(state.apprenticeship.betrayer_count == 0 and state.progression.score == 321, "no betrayal: nothing counted, the score kept")
	_check(player.shown_title() == "封山剑派北宗第十四代弟子" and player.facts.title == "封山剑派北宗第十四代弟子", "the title shown and kept: %s" % player.shown_title())
	_check(_said(_recent(ui, 14), "【分宗】"), "the move is told: %s" % [_recent(ui, 6)])
	_check(not NpcApprenticeship.is_master_of(state, catalog.npc(MASTER)) and state.family.family_id != catalog.npc(MASTER).teaching().family_id and state.family.family_id == catalog.npc(GIRL).teaching().family_id, "柳淳风 teaches them no more; 柳绘心 does (learn.c's same family)")
	# Save and Continue keep the branch: the family, the title, no master, the marks, the line done.
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(Work.capture(session))
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue as one of the 北宗")
	if restored.succeeded():
		var fresh: WorldSessionController = restored.candidate
		fresh.set_process(false)
		var kept: CharacterState = fresh.player_runtime().state
		_check(kept.family.family_id == &"family.fonxan_north" and kept.family.generation == 14 and kept.affiliation.family_title == "弟子" and not kept.apprenticeship.has_master() and fresh.player_runtime().shown_title() == "封山剑派北宗第十四代弟子", "the branch is kept: %s" % fresh.player_runtime().shown_title())
		_check(kept.marks.get("学了点字诀", 0) == 1 and StoryQuestLog.is_done(kept, catalog.story_quest(QUEST)), "and the 「点」字诀's mark, and the line done")
		fresh.free()
		await tree.process_frame
	state.skills.set_raw_level(&"fonxansword", 30)
	state.skills.map_skill(&"sword", &"fonxansword")
	state.equipment.wield(Martial.sword(&"b.sword"), false) # TEST-ONLY
	_check(PerformService.offered(state, catalog).has(POINT), "with a sword in hand the 「点」字诀 is theirs")
	# She and the children stay; nobody at 绮云镇's gate.
	MapPlaces.enter(session, &"snow.school1", &"snow.school1.gate_return")
	await _settle(tree)
	MapPlaces.enter(session, &"snow.innerhall", &"snow.innerhall.liu_huixin.1")
	await _settle(tree)
	_check(_count_in(session, &"snow.innerhall", GIRL) == 1 and _count_in(session, &"snow.innerhall", BOY) == 1, "the 北宗 stays in the 内院")
	_check(not WorldStoryPresence.on_stage(catalog.spawn(&"native.entrance.liu_huixin").present, catalog.spawn(&"native.entrance.liu_huixin").until, player, session.player_held_item_ids()), "nobody under a board at 绮云镇's gate")
	# 柳淳风 says his word on it the next time the player comes to where he is.
	var where: StringName = &"snow.innerhall" if _first(session, &"snow.innerhall", MASTER) != null else &"snow.schoolhall"
	MapPlaces.enter(session, &"snow.school2", &"snow.school2.gate_entry")
	await _settle(tree)
	MapPlaces.enter(session, where, &"snow.innerhall.liu_huixin.1" if where == &"snow.innerhall" else &"snow.schoolhall.master.1")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("柳淳风说过分宗", 0) == 1 and _said(_recent(ui, 10), "她一个人，我不放心"), "柳淳风 says it once (in the %s): %s" % [where, _recent(ui, 4)])
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("你是封山剑派北宗的人") and ui.standing_page.shown_text().contains("立了北宗") and not ui.standing_page.shown_text().contains("师父是柳淳风"), "the 声望 page: of the 北宗: %s" % ui.standing_page.shown_text())
	_check(_ending_lines(session, &"snow").any(func(line: String) -> bool: return line.contains("开了一道侧门")), "the ending's 雪亭 card: the side gate")
	var shut: NpcTeaching.RequirementCheck = NpcApprenticeship.refusal(state, catalog.npc(MASTER).teaching().apprentice)
	_check(shut != null and shut.not_mark == "跟了北宗" and shut.refuse_say.contains("本宗的门"), "选了不能改: 柳淳风 does not take one of the 北宗 back as his apprentice")
	_check(catalog.npc(GIRL).fight_rules()[0].family_id == &"family.fonxan_north", "柳绘心 has a word for her one fellow who asks to spar")
	var refusal: NpcTeaching.RecognizeRule = catalog.npc(MASTER).teaching().recognize(state.family.family_id, state.marks)
	_check(refusal != null and not refusal.accept and refusal.lines.size() == 1, "and says why (his recognize_apprentice())")
	# 封山守渡口, the eighth band: with two others, 能灭它's helpers hold.
	var helpers: JournalEntryDefinition = catalog.conditions()["finale.helpers"]
	state.marks["冰龙倒了"] = 1 # TEST-ONLY: the 冰龙 is no band
	_check(not bool(session.quest_condition_test().call(helpers)), "the 北宗 and the 大秦人 are two bands, not three")
	state.marks["霍铮回了寨"] = 1 # TEST-ONLY
	_check(bool(session.quest_condition_test().call(helpers)), "野羊寨, the 铁盾会 and the 北宗: three bands")
	state.quests["main.finale#started"] = state.quests.size() + 1 # TEST-ONLY: the finale begun
	MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.finale.fonxan_north")
	await _settle(tree)
	_check(_count_in(session, &"village.lakeside", &"native.npc.liu_huixin_lake") == 1 and _count_in(session, &"village.lakeside", &"native.npc.liu_chunfeng_lake") == 0, "柳绘心 by the boats on the night; not her father")


## The book with the father, the scene without the boy, and 本宗.
func _test_orthodox(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.fonxan_book_given(session, false)
	session.record_journal()
	var inner: WorldMapController = MapPlaces.enter(session, &"snow.innerhall", &"snow.innerhall.liu_huixin.1")
	await _settle(tree)
	_check(_count_in(session, &"snow.innerhall", YOUTH) == 0 and _count_in(session, &"snow.innerhall", BOY) == 1, "no 铁盾会 boy here")
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	var log_before: int = ui.log_lines().size()
	for second: int in 60:
		if not inner.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var lines: Array[String] = ui.log_lines().slice(log_before)
	_check(not inner.scene_running() and not _said(lines, "我们的盾") and _said(lines, "没有根的东西") and not _said(lines, "这是你二十岁自己写的"), "the scene without the boy; the book is his, he has the line of it")
	_check(_said(lines, "你要是觉得我没有错") and state.marks.get("内院的话说完了", 0) == 1, "柳绘心 has the last word, and the scene is marked told")
	# A scene cut short (a Continue in the middle) is not played again: the two can still be asked, and the step closes with the choice.
	state.marks.erase("内院的话说完了") # TEST-ONLY: as if it had been cut short
	session.record_journal()
	_check(not state.quests.has("faction.fonxan/yard"), "cut short: the step stays open")
	var master: NpcRuntimeState = _first(session, &"snow.innerhall", MASTER)
	_check(master != null and catalog.npc(MASTER).talk().ask_confirm("本宗").contains("柳绘心会离开武馆") and catalog.npc(MASTER).talk().ask_confirm("本宗").contains("选了不能改"), "his confirm says what it costs")
	_check(_said(_ask(inner, master, "本宗"), "「点」字诀归你") and state.marks.get("跟了本宗", 0) == 1 and state.marks.get("学了点字诀", 0) == 1, "本宗: the 「点」字诀 from 柳淳风")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/yard") and state.quests.has("faction.fonxan/split/orthodox") and StoryQuestLog.is_done(state, catalog.story_quest(QUEST)) and DeedLog.done(state, "在封山的南北之争里守了本宗"), "the choice, its deed, and the line ends")
	_check(state.family.family_id == &"family.fonxan" and state.affiliation.family_title == "掌门传人" and player.shown_title() == "封山剑派第十四代掌门传人" and NpcApprenticeship.is_master_of(state, catalog.npc(MASTER)), "掌门传人, still 柳淳风's: %s" % player.shown_title())
	_check(_said(_recent(ui, 14), "【晋阶】"), "the rise is told")
	# She leaves the 武馆 with the children, for 绮云镇's gate.
	MapPlaces.enter(session, &"snow.school1", &"snow.school1.gate_return")
	await _settle(tree)
	MapPlaces.enter(session, &"snow.innerhall", &"snow.innerhall.liu_huixin.1")
	await _settle(tree)
	_check(_count_in(session, &"snow.innerhall", GIRL) == 0 and _count_in(session, &"snow.nyard", GIRL) == 0 and _count_in(session, &"snow.innerhall", BOY) == 0 and _count_in(session, &"snow.innerhall", LITTLE) == 0, "柳绘心 and the children are gone from the 武馆")
	var gate: WorldMapController = MapPlaces.enter(session, &"cloud.entrance", &"cloud.entrance.liu_huixin.1")
	await _settle(tree)
	var north: NpcRuntimeState = MapPlaces.npc_at(session, &"cloud.entrance.liu_huixin.1")
	_check(north != null and north.exists_in_map and north.definition().definition_id == NORTH_GIRL, "she stands at 绮云镇's gate")
	_check(_said(_ask(gate, north, "北宗"), "封山剑派北宗所在的雪亭镇"), "under the notice that still names the 北宗 (entrance.c)")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text().contains("掌门传人") and ui.standing_page.shown_text().contains("北宗的牌子挂在绮云镇口"), "the 声望 page: the heir")
	_check(_ending_lines(session, &"snow").any(func(line: String) -> bool: return line.contains("从没叫人摘")), "the ending's 雪亭 card: the board he never had taken down")
	state.quests["main.finale#started"] = state.quests.size() + 1 # TEST-ONLY: the finale begun
	MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.finale.fonxan")
	await _settle(tree)
	_check(_count_in(session, &"village.lakeside", &"native.npc.liu_chunfeng_lake") == 1 and _count_in(session, &"village.lakeside", &"native.npc.liu_huixin_lake") == 0, "柳淳风 by the boats on the night")


## The lines the ending's card `card_id` would show now.
func _ending_lines(session: WorldSessionController, card_id: StringName) -> Array[String]:
	var ending: EpilogueDefinition = GameContent.catalog().epilogue(&"ending")
	for card: EpilogueDefinition.Card in ending.cards:
		if card.card_id == card_id:
			return card.shown(session.quest_condition_test())
	return []


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _side(id: StringName, state: CharacterState, opponent: StringName) -> SpecialSide:
	var relationship := CombatRelationshipState.new(id)
	relationship.add_opponent(opponent)
	var side := SpecialSide.new(id, state, ActionBusyState.new(), relationship)
	side.is_user = id == &"player"
	return side


## TEST-ONLY: the player's gin, kee and sen at these, their maxima 100.
func _resources(player: WorldPlayerRuntimeState, gin: int, kee: int, sen: int) -> void:
	player.state.essence = CharacterResourceState.new(gin, 100, 100)
	player.state.vitality = CharacterResourceState.new(kee, 100, 100)
	player.state.spirit = CharacterResourceState.new(sen, 100, 100)


## The instance id of the first of `definition_id` the player carries directly ("" when none).
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


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return 0
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			found += 1
	return found


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("封山", CharacterState.GENDER_MALE)
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
