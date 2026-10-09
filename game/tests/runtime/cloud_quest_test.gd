extends RefCounted

## 朱鸿雪's quests (package 3C): u/cloud/npc/god.c give_quest() picks a qlist entry by
## combat_exp and tfinished, cmds/usr/quest.c shows it, and combatd.c killer_reward()
## rewards the kill within the time (exp, potential, score, quest_factor, tfinished).
## The same killer_reward() counts MKS and bellicosity, marks a vendetta and makes a
## master's killer leave the family (owner: as a betrayal). surrender.c costs 50 score. Draws come from
## scripted sources; TEST-ONLY fixtures are marked where used.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Master := preload("res://tests/support/snow_master.gd")
const GOD: StringName = &"cloud.npc.god"
const GARRISON: StringName = &"common.npc.garrison"
const BEGGAR: StringName = &"snow.npc.beggar"
const DOG: StringName = &"snow.npc.dog"
const TRAINEE: StringName = &"snow.school2.trainee.1.character"
const LEVELS: Array[int] = [1000, 1500, 2000, 3000, 5000, 8000, 10000, 13000, 17000, 22000, 40000, 50000, 60000, 80000, 100000]
const INSULT: String = "朱鸿雪奇怪的眼神盯着你,说:\n就凭你这种小角色也想? 还不快滚!"
const SCOLD: String = "朱鸿雪向你一甩袍袖，说道：\n真没用！不过看在你还回来见我的份上，就在给你一次机会．"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_give()
	_test_tiers()
	_test_status()
	_test_reward()
	_test_vendetta_and_death()
	_test_master_killed()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_in_town(tree, session)
	session.free()
	await tree.process_frame
	await _test_surrender(tree)
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var tiers: Array[QuestTier] = catalog.quest_tiers()
	var levels: Array[int] = []
	var entries: int = 0
	for tier: QuestTier in tiers:
		levels.append(tier.min_exp)
		entries += tier.quests.size()
	_check(levels == LEVELS and entries == 220, "god.c's 15 levels, 220 qlist entries (33 are commented out): %s %d" % [levels, entries])
	var tier10000: Array[String] = []
	for quest: QuestDefinition in tiers[6].quests:
		tier10000.append(quest.target)
	_check(tier10000 == ["卧龙岗强盗", "郑屠夫", "彩衣少女", "飞贼", "兵器贩子", "刘安禄", "旅客", "土匪爪牙", "巨岩蛭", "袭人", "圆春"], "qlist10000.c without its commented-out entries: " + str(tier10000))
	var first: QuestDefinition = tiers[0].quests[0]
	_check(tiers[0].legacy_source == "quest/qlist1000.c" and first.target == "乞丐" and first.type == "杀" and first.time_seconds == 200 and first.exp_bonus == 30 and first.pot_bonus == 20 and first.score == 6, "qlist1000.c's first: 乞丐, 杀, 200 s, 30/20/6")
	_check(catalog.npc(GOD).dealings().quest_giver and catalog.npc(GARRISON).dealings().vendetta_mark == "authority", "朱鸿雪 gives quests; garrison.c's vendetta_mark")
	_check(catalog.quest_target_available("乞丐") and catalog.quest_target_available("县城官兵"), "placed, fightable targets are available")
	_check(not catalog.quest_target_available("化缘和尚") and not catalog.quest_target_available("知客僧"), "not 化缘和尚 (not fightable yet) nor 知客僧 (山烟寺)")
	_check(catalog.quest_target_available("朱鸿雪"), "a placed, fightable name counts whether or not a qlist names it (朱鸿雪, fightable since 晚月庄 A)")


## give_quest(): too weak, a task still running, a new one, one that ran out.
func _test_give() -> void:
	var state := _fresh()
	state.progression.combat_experience = 1000
	var draws := ScriptedWorldInteractionRandomSource.new([])
	var result: QuestGiver.Result = _give(state, draws)
	_check(result.outcome == QuestGiver.Outcome.TOO_WEAK and ColoredLine.texts(result.lines) == [INSULT] and not state.quest.has_task() and draws.call_count() == 0, "combat_exp 1000 is a 小角色: " + str(ColoredLine.texts(result.lines)))
	state.progression.combat_experience = 1001
	var beggar: int = _available(0).find("乞丐")
	draws = ScriptedWorldInteractionRandomSource.new([beggar])
	result = _give(state, draws)
	_check(result.outcome == QuestGiver.Outcome.GIVEN and draws.requested_bounds() == [_available(0).size()], "1001: one draw among the first tier's available quests %s" % [draws.requested_bounds()])
	_check(result.lines.size() == 1 and result.lines[0].text == "朱鸿雪沉思了一会儿，说道：\n请在三分二十秒内替我杀了『乞丐』。" and result.lines[0].color == ColoredLine.HIW, "time_period() and the task in HIW: " + str(ColoredLine.texts(result.lines)))
	_check(state.quest.current.target == "乞丐" and state.quest.remaining_ms == 200000 and state.quest.factor == 10 and state.quest.finished == 0, "the task, 200 s, quest_factor 10")
	draws = ScriptedWorldInteractionRandomSource.new([])
	result = _give(state, draws)
	_check(result.outcome == QuestGiver.Outcome.HAS_TASK and result.lines.is_empty() and draws.call_count() == 0 and state.quest.remaining_ms == 200000, "a task still running: she returns 0 (quest.c shows it)")
	state.quest.remaining_ms = 1
	_check(_give(state, draws).outcome == QuestGiver.Outcome.HAS_TASK, "a millisecond left still runs")
	state.quest.remaining_ms = 0
	state.quest.finished = 5
	state.vitality = CharacterResourceState.new(81, 90, 100)
	var li: int = _available(0).find("李师师")
	draws = ScriptedWorldInteractionRandomSource.new([li])
	result = _give(state, draws)
	_check(result.outcome == QuestGiver.Outcome.GIVEN and ColoredLine.texts(result.lines) == [SCOLD, "朱鸿雪沉思了一会儿，说道：\n请在一分四十秒内替我杀了『李师师』。"] and result.lines[0].color == ColoredLine.PLAIN, "run out: 真没用, then another task: " + str(ColoredLine.texts(result.lines)))
	_check(state.vitality.current == 41 and state.quest.finished == 0 and state.quest.current.target == "李师师" and state.quest.remaining_ms == 100000, "kee 81 / 2 + 1 = 41; tfinished starts again from 0")
	state.quest.remaining_ms = -1
	state.quest.finished = -12
	draws = ScriptedWorldInteractionRandomSource.new([0])
	_give(state, draws)
	_check(state.quest.finished == -13, "tfinished -12 sinks to -13 (<= -10)")
	state.quest.remaining_ms = -1
	var never := func(_target: String) -> bool: return false
	var before: int = state.vitality.current
	result = QuestGiver.give(state, GameContent.catalog().quest_tiers(), never, ScriptedWorldInteractionRandomSource.new([]).legacy_random)
	_check(result.outcome == QuestGiver.Outcome.NONE_AVAILABLE and result.lines.is_empty() and state.vitality.current == before and state.quest.finished == -13 and state.quest.has_task(), "no quest in the game at all: nothing happens (she returns 0)")


## The tier: the highest god.c level combat_exp reaches, tfinished / 3 up or down,
## and (deviation) the next lower tier when none of the tier's targets is in the game.
func _test_tiers() -> void:
	var cases: Array[Array] = [
		# combat_exp, tfinished, the tier drawn from
		[1001, 0, 0], [1499, 0, 0], [1500, 0, 1], [99999, 0, 13], [100000, 0, 14], [5000000, 0, 14],
		[1001, 2, 0], [1001, 3, 1], [1001, 9, 3], [80000, 9, 14], [100000, -12, 10], [2000, -10, 0],
	]
	for case: Array in cases:
		var state := _fresh()
		state.progression.combat_experience = case[0]
		state.quest.finished = case[1]
		var draws := ScriptedWorldInteractionRandomSource.new([0])
		var result: QuestGiver.Result = _give(state, draws)
		_check(result.outcome == QuestGiver.Outcome.GIVEN and draws.requested_bounds() == [_available(case[2]).size()] and state.quest.current.target == _available(case[2])[0], "exp %d, tfinished %d: tier %d (%s)" % [case[0], case[1], LEVELS[case[2]], draws.requested_bounds()])
	_check(_available(12) == ["芙云", "梦玉楼", "清云", "清玄"] and _available(11).has("趟子手"), "qlist60000.c: 晚月庄's 芙云 and 梦玉楼, 茅山's 清云 and 清玄; qlist50000.c has 趟子手")
	var state := _fresh()
	state.progression.combat_experience = 60000
	var draws := ScriptedWorldInteractionRandomSource.new([0])
	var only := func(target: String) -> bool: return target == "趟子手" # TEST-ONLY: nothing of qlist60000.c in the game
	var fallback: QuestGiver.Result = QuestGiver.give(state, GameContent.catalog().quest_tiers(), only, draws.legacy_random)
	_check(fallback.outcome == QuestGiver.Outcome.GIVEN and draws.requested_bounds() == [1] and state.quest.current.target == "趟子手" and state.quest.current.time_seconds == 100 and state.quest.factor == 10, "60000 with none of its tier in the game falls back to qlist50000.c's entry (deviation)")


func _test_status() -> void:
	var quest := CharacterQuestState.new()
	_check(QuestStatus.lines(quest) == ["你现在没有任何任务！"], "quest.c without a task")
	quest.assign(GameContent.catalog().quest_tiers()[0].quests[0], 10)
	_check(QuestStatus.lines(quest) == ["你现在的任务是杀『乞丐』。", "你还有三分二十秒去完成它。"], "quest.c with 200 s left: " + str(QuestStatus.lines(quest)))
	quest.advance(199999)
	_check(QuestStatus.lines(quest)[1] == "你还有一秒去完成它。", "a part of a second left shows as one")
	quest.advance(1)
	_check(quest.remaining_ms == 0 and quest.kill_counts() and quest.is_expired() and QuestStatus.lines(quest)[1] == "但是你已经没有足够的时间来完成它了。", "at task_time: a kill still counts, she sees it run out")
	quest.advance(5000)
	_check(quest.remaining_ms == -1 and not quest.kill_counts(), "after it: the time left stops at -1")
	var periods: Dictionary[int, String] = {0: "零秒", 40: "四十秒", 300: "五分零秒", 540: "九分零秒", 3600: "一小时零秒", 3661: "一小时一分一秒", 86400: "一天零秒", 90061: "一天一小时一分一秒"}
	for seconds: int in periods:
		_check(QuestStatus.period(seconds) == periods[seconds], "time_period(%d): %s" % [seconds, QuestStatus.period(seconds)])


## killer_reward(): MKS, the task done within its time, bellicosity.
func _test_reward() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state := _fresh()
	state.progression.combat_experience = 1500
	state.quest.assign(catalog.quest_tiers()[0].quests[0], 10)
	var draws := ScriptedWorldInteractionRandomSource.new([7, 3, 1])
	var result: PlayerKillerReward.Result = PlayerKillerReward.apply(state, catalog.npc(BEGGAR), draws.legacy_random)
	_check(ColoredLine.texts(result.lines) == ["恭喜你！你又完成了一项任务！", "你被奖励了：\n二十二点实战经验\n十三点潜能\n四点综合评价"] and result.lines[1].color == ColoredLine.HIW, "the reward lines: " + str(ColoredLine.texts(result.lines)))
	_check(draws.requested_bounds() == [15, 10, 3], "random(exp_bonus / 2), random(pot_bonus / 2), random(score / 2)")
	_check(state.progression.combat_experience == 1522 and state.progression.potential == 100 and state.progression.score == 4, "exp + 22; unspent potential 99 + 13 ends at 100; score + 4")
	_check(not state.quest.has_task() and state.quest.finished == 1 and state.quest.factor == 10 and state.progression.kills == 1 and state.attributes.bellicosity == 1, "the task is done, tfinished 1, MKS 1, bellicosity 1")
	state.quest.assign(catalog.quest_tiers()[0].quests[0], 10)
	result = PlayerKillerReward.apply(state, catalog.npc(DOG), ScriptedWorldInteractionRandomSource.new([]).legacy_random)
	_check(result.lines.is_empty() and state.quest.has_task() and state.progression.kills == 2 and state.attributes.bellicosity == 2, "another name: no reward, still MKS and bellicosity")
	state.quest.remaining_ms = -1
	_check(PlayerKillerReward.apply(state, catalog.npc(BEGGAR), ScriptedWorldInteractionRandomSource.new([]).legacy_random).lines.is_empty() and state.quest.has_task(), "after task_time: no reward")
	state.quest.remaining_ms = 0
	_check(PlayerKillerReward.apply(state, catalog.npc(BEGGAR), ScriptedWorldInteractionRandomSource.new([0, 0, 0]).legacy_random).quest_done, "at task_time: done")
	var cases: Array[Array] = [
		# finished before, after; factor; score before; [exp, pot, score] gains
		[10, 0, 10, 0, [15, 10, 3]], [9, 10, 10, 0, [15, 10, 3]], [-11, 1, 10, 0, [15, 10, 3]], [-10, -9, 10, 0, [15, 10, 3]],
		[0, 1, 15, 0, [22, 15, 4]], [0, 1, 0, 0, [15, 10, 3]], [0, 1, 10, -5, [15, 10, -3]],
	]
	for case: Array in cases:
		state = _fresh()
		state.quest.assign(catalog.quest_tiers()[0].quests[0], 10)
		state.quest.finished = case[0]
		state.quest.factor = case[2] # TEST-ONLY: god.c only gives 10 (or 0)
		state.progression.score = case[3]
		result = PlayerKillerReward.apply(state, catalog.npc(BEGGAR), ScriptedWorldInteractionRandomSource.new([0, 0, 0]).legacy_random)
		_check(state.quest.finished == case[1] and [result.exp_gain, result.pot_gain, result.score_gain] == case[4] and state.progression.score == case[3] + case[4][2], "tfinished %d -> %d, factor %d, score %d: %s" % [case[0], case[1], case[2], case[3], [result.exp_gain, result.pot_gain, result.score_gain]])
	state = _fresh()
	state.progression.potential = 300
	state.progression.potential_spent = 100
	state.quest.assign(catalog.quest_tiers()[0].quests[0], 10)
	PlayerKillerReward.apply(state, catalog.npc(BEGGAR), ScriptedWorldInteractionRandomSource.new([0, 0, 0]).legacy_random)
	_check(state.progression.potential == 300, "200 unspent potential stays 200: the cap stops the gain only (deviation; killer_reward() would leave 100)")
	state = _fresh()
	state.progression.potential = 95
	state.quest.assign(catalog.quest_tiers()[0].quests[0], 10)
	PlayerKillerReward.apply(state, catalog.npc(BEGGAR), ScriptedWorldInteractionRandomSource.new([0, 0, 0]).legacy_random)
	_check(state.progression.potential == 100, "95 + 10 ends at 100")


func _test_vendetta_and_death() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var garrison: NpcDefinition = catalog.npc(GARRISON)
	var state := _fresh()
	_check(not garrison.attacks_on_sight({}, state), "a garrison leaves a player without a vendetta alone")
	PlayerKillerReward.apply(state, garrison, ScriptedWorldInteractionRandomSource.new([]).legacy_random)
	_check(state.vendetta == {"authority": 1} and garrison.attacks_on_sight({}, state), "a garrison's killer: vendetta/authority 1, and its kind attacks on sight")
	PlayerKillerReward.apply(state, garrison, ScriptedWorldInteractionRandomSource.new([]).legacy_random)
	_check(state.vendetta == {"authority": 2} and not catalog.npc(DOG).attacks_on_sight({}, state), "two; a dog has no vendetta_mark")
	PlayerDeathRules.die(state, false)
	_check(state.vendetta == {"authority": 2}, "a death nobody caused keeps it (killer_reward() never runs)")
	state.vitality = CharacterResourceState.new(100, 100, 100)
	PlayerDeathRules.die(state, true)
	_check(state.vendetta.is_empty(), "killer_reward() deletes the dead player's vendetta")


## killer_reward()'s rebel part: the master one generation up. Owner's deviation:
## it counts as betraying the family (betrayer + 1, score 0), where ES2 lowers betrayer.
func _test_master_killed() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state := _fresh()
	Master.recruit(state, 1789420000)
	var fist_trainer: NpcDefinition = catalog.npc(&"snow.npc.fist_trainer")
	PlayerKillerReward.apply(state, fist_trainer, ScriptedWorldInteractionRandomSource.new([]).legacy_random)
	_check(state.family.has_family() and state.apprenticeship.master_teacher_id == Master.definition().definition_id, "another of the family: nothing")
	state.family.generation = 15 # TEST-ONLY
	PlayerKillerReward.apply(state, Master.definition(), ScriptedWorldInteractionRandomSource.new([]).legacy_random)
	_check(state.family.has_family() and state.apprenticeship.betrayer_count == 0, "the master two generations up: nothing")
	state.family.generation = 14
	state.progression.score = 9
	var result: PlayerKillerReward.Result = PlayerKillerReward.apply(state, Master.definition(), ScriptedWorldInteractionRandomSource.new([]).legacy_random)
	_check(result.left_family and state.apprenticeship.betrayer_count == 1 and state.progression.score == 0 and PlayerKillerReward.REBEL_TITLE == "普通百姓", "柳淳风's killer: a betrayal (betrayer 1, score 0); the title is to be 普通百姓")
	_check(ColoredLine.texts(result.lines) == ["你亲手杀了自己的师父，被逐出了封山剑派！", "弑师等同背叛师门：综合评价清零，背叛师门的次数变成 1 次。"] and result.lines[0].color == ColoredLine.HIR, "the player is told: " + str(ColoredLine.texts(result.lines)))
	_check(not state.family.has_family() and not state.apprenticeship.has_master() and state.apprenticeship.legacy_master_name.is_empty(), "family 0: no family, no master")
	_check(not state.affiliation.has_family_rank and state.affiliation.family_title.is_empty() and state.affiliation.entry_time_status == CharacterAffiliationState.EntryTime.ABSENT and state.affiliation.class_id == &"swordsman" and state.affiliation.is_valid(), "no rank or entry time; the class stays")
	var again := NpcApprenticeship.new()
	_check(Master.recruit(state, 1789430000, again) == NpcApprenticeship.Outcome.RECRUITED and state.apprenticeship.betrayer_count == 1 and not again.lines.has("你决定背叛师门，改投入柳淳风门下！！"), "joining again from no family is no further betrayal; the one counted stays")


## 朱鸿雪 in god2: her 任务 beside her body, the task on the character sheet, the
## time running in play, the kill in a real fight, Save/Continue.
func _test_in_town(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.duchang", &"cloud.duchang", &"cloud.duchang.stairs_return").succeeded(), "in the town (TEST-ONLY: by the 赌场's stairs)")
	await tree.physics_frame
	var zhu: NpcRuntimeState = _npc(map, &"cloud.god2.god.1")
	_check(zhu != null and _beside(map, player, &"cloud.god2", &"cloud.god2.god.1"), "beside 朱鸿雪 in god2")
	await tree.physics_frame
	var service: QuestService = map.service(zhu.spawn_id) as QuestService
	_check(service != null and service.in_reach() and service.context_title() == "朱鸿雪 · 任务", "her 任务: " + ("" if service == null else service.context_title()))
	player.state.progression.combat_experience = 500 # TEST-ONLY
	var before: int = hud.log_lines().size()
	_check(service.request_quest() == QuestGiver.Outcome.TOO_WEAK and hud.log_lines().slice(before) == [INSULT, "你现在没有任何任务！"], "500 exp: sent away, then quest.c: " + str(hud.log_lines().slice(before)))
	player.state.progression.combat_experience = 1200 # TEST-ONLY
	var world_random: WorldInteractionRandomSource = map.world_interaction_random_source()
	map.replace_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([_available(0).find("宝官")])) # TEST-ONLY
	# pacing.json quest_time_percent 150: god.c's 500 s for 宝官 becomes 750 s.
	_check(GameContent.catalog().pacing().quest_time_percent == 150 and service.request_quest() == QuestGiver.Outcome.GIVEN and ColoredLine.texts(service.last_lines) == ["朱鸿雪沉思了一会儿，说道：\n请在十二分三十秒内替我杀了『宝官』。"], "a task: kill 宝官 within 500 s x 1.5: " + str(ColoredLine.texts(service.last_lines)))
	map.replace_world_interaction_random_source(world_random)
	_check(service.request_quest() == QuestGiver.Outcome.HAS_TASK and ColoredLine.texts(service.last_lines) == ["你现在的任务是杀『宝官』。", "你还有十二分三十秒去完成它。"], "asking again shows quest.c")
	session.advance_quest_time(1.5)
	_check(player.state.quest.remaining_ms == 748500, "play time runs the task's time: %d" % player.state.quest.remaining_ms)
	hud.open_character()
	var sheet: String = hud._presentation_layout.character.sheet.text
	_check(sheet.contains("杀气 0 · 综合评价 0\n总共杀过 0 个人。") and sheet.contains("你现在的任务是杀『宝官』。\n你还有十二分二十九秒去完成它。"), "the character sheet: score.c's lines and quest.c: " + sheet)
	hud.dismiss_current_panel()
	await tree.physics_frame
	var left: int = player.state.quest.remaining_ms
	var encoded: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	_check(encoded.contains("\"remaining_ms\": \"%d\"" % left) and encoded.contains("\"target\": \"宝官\""), "the task is saved with the time left")
	var work: RefCounted = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "a task from 朱鸿雪")
	_check(work._failures.is_empty(), "Save/Continue: " + str(work._failures))
	_test_codec(JSON.parse_string(encoded))
	var judge: NpcRuntimeState = _npc(map, &"cloud.duchang.judge.1")
	_check(judge != null and _beside(map, player, &"cloud.duchang", &"cloud.duchang.judge.1"), "beside 宝官")
	await tree.physics_frame
	player.state.progression.combat_experience = 100000 # TEST-ONLY: a player who lands the blows
	var kee: CharacterResourceState = player.state.vitality
	player.state.vitality = CharacterResourceState.new(50000, 50000, 50000) # TEST-ONLY
	var exp_before: int = player.state.progression.combat_experience
	map.select_npc(judge.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 宝官")
	judge.character_state.vitality.current = -1 # TEST-ONLY
	before = hud.log_lines().size()
	_run(session)
	_check(judge.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "宝官 is killed")
	var gained: int = player.state.progression.combat_experience - exp_before
	_check(hud.log_lines().slice(before).find("恭喜你！你又完成了一项任务！") < 0, "the reward waits for the fight's result")
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	ui.refresh_projection()
	var lines: Array[String] = hud.log_lines().slice(before)
	var won: int = -1
	for index: int in lines.size():
		if lines[index].begins_with("你赢了这场战斗。"):
			won = index
	var done: int = lines.find("恭喜你！你又完成了一项任务！")
	_check(won >= 0 and done == won + 1 and done + 2 == lines.size() and lines[done + 1].begins_with("你被奖励了：\n%s点实战经验\n" % ChineseNumber.of(gained)), "the reward in the log after the fight's result: " + str(lines))
	_check(hud.toasts().latest_text() == lines.back().replace("\n", " "), "the HUD's last toast shows the whole reward: " + hud.toasts().latest_text())
	_check(gained >= 20 and gained <= 39 and player.state.progression.score >= 2 and player.state.progression.score <= 3 and player.state.progression.potential == 100, "qlist1000.c's 宝官: 40/30/4 halved plus a draw: exp %d, score %d" % [gained, player.state.progression.score])
	_check(not player.state.quest.has_task() and player.state.quest.finished == 1 and player.state.progression.kills == 1 and player.state.attributes.bellicosity == 1, "the task done, tfinished 1, MKS 1, bellicosity 1")
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "the fight never aborts")
	player.state.vitality = kee # Continue recomputes max kee (race/human.c)
	var garrison: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == GARRISON:
			garrison = npc
	player.state.vendetta = {"authority": 1} # TEST-ONLY: as a garrison's killer
	_check(garrison != null and garrison.definition().attacks_on_sight(garrison.flags(), player.state), "the town's garrison attacks a garrison's killer on sight")
	encoded = GameSaveJsonCodec.encode(Work.capture(session)).text
	_check(encoded.contains("\"vendetta\": {") and encoded.contains("\"kills\": \"1\"") and encoded.contains("\"finished\": \"1\""), "vendetta, MKS and tfinished are saved")
	work = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "after the task, with a vendetta")
	_check(work._failures.is_empty(), "Save/Continue after the kill: " + str(work._failures))
	player.state.vendetta.clear()
	_check(_beside(map, player, &"cloud.god2", &"cloud.god2.god.1"), "back to 朱鸿雪")
	await tree.physics_frame
	player.state.quest.assign(GameContent.catalog().quest_tiers()[0].quests[0], 10) # TEST-ONLY: a task that ran out
	player.state.quest.remaining_ms = -1
	player.state.vitality = CharacterResourceState.new(80, 100, 100)
	_check(service.request_quest() == QuestGiver.Outcome.GIVEN and service.last_lines[0].text == SCOLD and player.state.vitality.current == 41 and player.state.quest.finished == 0 and player.state.quest.remaining_ms > 0, "the time ran out: 真没用, kee halved, another task")
	var header: NpcRuntimeState = _npc(map, &"cloud.biaoju.b_header.1")
	_check(player.request_apprenticeship(header.definition(), GameContent.catalog().family(&"family.zhenyuan"), 1789420000) == NpcApprenticeship.Outcome.RECRUITED and player.shown_title() == "振远镖局第二代弟子", "TEST-ONLY: 陈剑秋's apprentice")
	map.combat_lifecycle._player_killer_reward(header) # TEST-ONLY: as if the fight had ended in his death
	_check(not player.state.family.has_family() and player.state.apprenticeship.betrayer_count == 1 and player.state.progression.score == 0 and player.facts.title == "普通百姓" and player.shown_title() == "普通百姓", "his killer betrays the family, leaves it and is 普通百姓 again: " + player.shown_title())
	player.state.vitality = CharacterResourceState.new(player.state.vitality.maximum, player.state.vitality.maximum, player.state.vitality.maximum)
	work = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "a master's killer, betrayer 1")
	_check(work._failures.is_empty(), "Save/Continue after leaving the family: " + str(work._failures))


## A saved task, vendetta and MKS that 朱鸿雪 could not have given are refused.
func _test_codec(root: Dictionary) -> void:
	var character: Dictionary = root["player"]["character"]
	var cases: Array[Array] = [
		["quest", {"factor": "0", "finished": "0"}, "an all-default quest block"],
		["quest", {"factor": "10", "finished": "0", "task": {"target": "宝官", "type": "抢", "time": "500", "exp_bonus": "40", "pot_bonus": "30", "score": "4", "remaining_ms": "1"}}, "an unknown quest_type"],
		["quest", {"factor": "10", "finished": "0", "task": {"target": "宝官", "type": "杀", "time": "500", "exp_bonus": "40", "pot_bonus": "30", "score": "4", "remaining_ms": "500001"}}, "more time left than given"],
		["quest", {"factor": "10", "finished": "0", "task": {"target": "宝官", "type": "杀", "time": "500", "exp_bonus": "40", "pot_bonus": "30", "score": "4", "remaining_ms": "-2"}}, "time left below -1"],
		["vendetta", {}, "an empty vendetta"],
		["vendetta", {"authority": "0"}, "a vendetta of 0"],
	]
	for case: Array in cases:
		var broken: Dictionary = root.duplicate(true)
		broken["player"]["character"][case[0]] = case[1]
		_check(not GameSaveJsonCodec.decode(JSON.stringify(broken)).succeeded(), "refused: " + case[2])
	var kills: Dictionary = root.duplicate(true)
	kills["player"]["character"]["progression"]["kills"] = "0"
	_check(not GameSaveJsonCodec.decode(JSON.stringify(kills)).succeeded(), "refused: kills 0 (never written)")
	_check(character.has("quest") and not character.has("vendetta") and not (character["progression"] as Dictionary).has("kills"), "only what is set is written")


## surrender.c from the battle panel: a spar ends and costs 50 score; a killer
## refuses; with every killer down the player disengages.
func _test_surrender(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "out on the square")
	for frame: int in range(5):
		await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	map.relocate_player(&"snow.school2", &"snow.school2.trainee.6")
	map.select_npc(TRAINEE)
	player.state.progression.score = 60 # TEST-ONLY
	map.spar_selected()
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.SPAR, "a spar with a 武馆弟子")
	ui.refresh_projection()
	var labels: Array[String] = []
	for info: CombatTacticalActionInfo in coordinator.action_infos():
		labels.append(ui.action_panel.catalog.label_for(info.action_id))
	_check(labels.slice(0, 2) == ["逃跑", "投降"], "投降 beside 逃跑: " + str(labels))
	var intent := BattleIntentAdapter.new(coordinator, player.character_id)
	_check(intent.submit(CombatSurrenderTacticalPolicy.ACTION_ID).accepted(), "投降 is queued")
	coordinator.advance_scheduler(1.0)
	ui.refresh_projection()
	_check(not coordinator.has_active_encounter() and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.SPAR_CONCLUDED, "the spar is over")
	_check(player.state.progression.score == 10 and ui.log_panel._text.get_parsed_text().contains("你说道：「不打了，不打了，我投降....。」"), "50 score lost; the line: " + ui.log_panel._text.get_parsed_text().right(160))
	player.state.progression.score = 30 # TEST-ONLY
	map.select_npc(TRAINEE)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "now to the death")
	ui.refresh_projection()
	_check(player.relationship.last_opponent_id.is_empty() and intent.submit(CombatSurrenderTacticalPolicy.ACTION_ID).accepted(), "投降 before any blow")
	coordinator.advance_scheduler(1.0) # the surrender, then a round: the trainee is the player's last_opponent
	ui.refresh_projection()
	_check(coordinator.has_active_encounter() and player.state.progression.score == 30 and ui.log_panel._text.get_parsed_text().contains("你向武馆弟子求饶，但是武馆弟子大声说道："), "a standing killer refuses even before the first blow (deviation): " + ui.log_panel._text.get_parsed_text().right(200))
	ui.refresh_projection()
	_check(player.relationship.last_opponent_id == TRAINEE, "the 武馆弟子 is the last opponent")
	_check(intent.submit(CombatSurrenderTacticalPolicy.ACTION_ID).accepted(), "投降 again")
	coordinator.advance_scheduler(1.0)
	ui.refresh_projection()
	var rude: String = RankWords.query_rude(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	_check(coordinator.has_active_encounter() and player.state.progression.score == 30 and ui.log_panel._text.get_parsed_text().contains("你向武馆弟子求饶，但是武馆弟子大声说道：%s废话少说，纳命来！" % rude), "a killer will not have it: " + ui.log_panel._text.get_parsed_text().right(200))
	trainee.character_state.vitality.current = 0 # TEST-ONLY: knocked out
	trainee.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	_check(intent.submit(CombatSurrenderTacticalPolicy.ACTION_ID).accepted(), "投降 over a knocked-out killer")
	coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter() and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.FLED and player.state.progression.score == 0, "nobody standing fights: the player disengages, score 30 - 50 ends at 0")
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborts")
	session.free()
	await tree.process_frame


func _give(state: CharacterState, draws: ScriptedWorldInteractionRandomSource) -> QuestGiver.Result:
	var catalog: ContentCatalog = GameContent.catalog()
	return QuestGiver.give(state, catalog.quest_tiers(), catalog.quest_target_available, draws.legacy_random)


## The targets of a tier's entries that can be done now, in qlist order.
func _available(tier: int) -> Array[String]:
	var catalog: ContentCatalog = GameContent.catalog()
	var out: Array[String] = []
	for quest: QuestDefinition in catalog.quest_tiers()[tier].quests:
		if catalog.quest_target_available(quest.target):
			out.append(quest.target)
	return out


static func _fresh() -> CharacterState:
	return NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "杀手").state


func _run(session: WorldSessionController) -> int:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1.0)
		rounds += 1
		if advanced.cycles_processed == 0 and coordinator.has_active_encounter():
			_check(false, "the fight stalled after %d rounds" % rounds)
			break
	return rounds


func _beside(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return player.set_world_location(map.location_for_zone(zone_id))
	return false


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("quest: " + label)
