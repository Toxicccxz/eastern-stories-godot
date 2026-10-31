extends RefCounted

## 第六章 关北, 关北 A (owner's plan, 2026-10-30; DECISIONS「关北 A」), from the two fifth-chapter
## ledgers (StoryFixtures), two sessions:
## - escorted (kept, rescued): the letter shown to 严廷殷 in his tent (the camp's roll held),
##   赫造基's secret for eight taels (seven kept, no secret), the 印模 in hand, the 后备兵 on the
##   印色, 比印 against the 兵部文书 (学过印色); at the valley's east gate the listed are let
##   through by the soldier's word (军营), the letter answered 说过了; through the gate (到了关北),
##   the boundary stone, the city's notice (看过王府告示), the 王府 objective; 卢卡's tale of the
##   headless ghost and his 会首 in 番坊, his sword for twenty taels; 老秦 in the 酒肆 knows the
##   one who opened his cell (the rescue ledger), 秦婆子 says he is back. B: the 王府大门 shut, knocked
##   open with the letter; the reunion scene as the player walks into the hall (南危水 beside his
##   brother on the 保密 ledger, gone from the 水烟阁); the letter handed to 程朔 (信递到了); 借兵
##   confirmed, 郭承 at the drill yard takes the word and follows, 潜入 refused after.
## - released (taken, chased): the letter opens the gate (过了关门 by 信), then — TEST-ONLY, the
##   mark erased — four taels refused and five taken; the 酒肆 without 老秦, 秦婆子 still waiting. B:
##   no 南危水 in the hall (he stays at the 水烟阁), 程朔's word on the 告发; 潜入 agreed with 郭承 (he
##   follows), 借兵 refused after.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const PAPERS: StringName = &"native:niling/war_ministry_papers"
const LETTER: StringName = &"native:choyin/magistrate_letter"
const MOULD: StringName = &"native:canyon/seal_mould"
const GLADIUS: StringName = &"native:guanbei/gladius"
const SOLDIER: StringName = &"native.npc.pass_gate_soldier"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var escorted: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_escorted(tree, escorted)
	escorted.free()
	await tree.process_frame
	var released: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_released(tree, released)
	released.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter6")
	_check(quest != null and quest.requires == [&"main.chapter5"] and quest.steps.size() == 9 and quest.region == "关北" and quest.steps[7].options.size() == 2 and quest.steps[7].options[0].option_id == &"raid" and quest.steps[7].options[1].option_id == &"sneak", "the chapter: nine steps after the fifth, the choice before the 工地 (B)")
	var ids: Array[String] = []
	for step: StoryQuestDefinition.Step in quest.steps:
		ids.append(String(step.step_id))
	_check(ids == ["general", "adviser", "seal", "gate", "guanbei", "town", "palace", "plan", "site"], "the steps in order: %s" % [ids])
	var gate: DoorDefinition = catalog.door(&"guanbei.palace.gate")
	_check(gate != null and gate.found_by == "王府放行" and not gate.operable and not gate.closable and gate.zone_ids() == [&"guanbei.palace_front", &"guanbei.palace_yard"], "the 王府大门: found by the knock, worked by no hand, open ever after")
	var cheng: NpcDefinition = catalog.npc(&"native.npc.cheng_shuo")
	_check(cheng != null and cheng.age == 66 and cheng.dealings().object_rules.size() == 4 and cheng.talk().inquiry_topics().has("借兵"), "程朔: 66, takes the letter, asked for his men")
	var guo: NpcDefinition = catalog.npc(&"native.npc.guo_cheng")
	_check(guo != null and guo.hooks() != null and guo.hooks().follows_every_way and guo.hooks().moods["going"].flags == [NpcDefinition.FLAG_FOLLOWS_PLAYER] and guo.hooks().calls.size() == 1 and guo.hooks().calls[0].act.mark == "借了兵", "郭承 follows every way in his mood going; the word of 借兵 reaches him at the drill yard")
	var nan: NpcDefinition = catalog.npc(&"native.npc.nan_weishui_guest")
	_check(nan != null and nan.hooks() != null and nan.hooks().scene_mark == "见过重逢" and nan.hooks().calls.size() == 3 and nan.skill_map().get(&"sword") == &"fonxansword", "南危水 the guest: elder5.c's arts, a three-beat scene")
	var guest: NpcSpawnDefinition = catalog.spawn(&"guanbei.palace_hall.nan_weishui")
	var home: NpcSpawnDefinition = catalog.spawn(&"waterfog.upstairs.forehall.elder5")
	_check(guest != null and guest.present != null and home != null and home.until != null, "南危水 on one stage or the other: the hall on the 保密 ledger once the chapter starts, else the 水烟阁")
	var general: NpcDefinition = catalog.npc(&"canyon.npc.general")
	_check(general.talk().inquiry_topics().slice(0, 4) == ["黄石隘口", "后备兵", "兵器库", "印鉴"] and general.talk().inquiry_topics().has("信"), "general.c's four topics first, the letter's after")
	var adviser: NpcDefinition = catalog.npc(&"canyon.npc.adviser")
	_check(adviser.dealings().object_rules.size() == 5 and adviser.dealings().object_rules[1].gives == MOULD and adviser.dealings().object_rules[1].value_at_least == 800 and adviser.dealings().object_rules[3].value_at_least == 800, "赫造基: the mould for eight taels to one 严廷殷 heard, the swear secret after (adviser.c's rules kept)")
	_check(catalog.npc(&"canyon.npc.seller").talk().inquiry_topics() == ["印色"], "the 后备兵 on the 印色")
	var luca: NpcDefinition = catalog.npc(&"native.npc.luca")
	_check(luca != null and luca.gender == &"男性" and luca.age == 34 and luca.dealings().object_rules[1].gives == GLADIUS and luca.dealings().object_rules[1].value_at_least == 2000, "卢卡: a man of 34, his sword for twenty taels")
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.SOURCE_ENTRY_GUANBEI_B_V1, "关北 B's world revision is current")


## A woman from the escort: the camp, the mould, the 印色, the gate by the roll, the city, 卢卡, 老秦.
func _test_escorted(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter6")
	StoryFixtures.chapter5_escorted(session)
	session.record_journal()
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests).begins_with("带着程不平的信去天驼关军营"), "the chapter open at the camp: %s" % [StoryQuestLog.objective(state, quests)])
	state.marks["军营"] = 1 # TEST-ONLY: listed with the 大队长 (canyon_test pays)
	Finance.add_money(Finance.session_context(session), CurrencyDenomination.Value.SILVER, 60, &"test.toll") # TEST-ONLY
	# 严廷殷 in his tent.
	var camp: WorldMapController = MapPlaces.enter(session, &"canyon.camp8", &"canyon.camp8.general.1")
	_check(camp != null, "in the 将军营帐")
	await _settle(tree)
	var general: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp8.general.1")
	var said: Array[String] = _ask(camp, general, "信")
	_check(said.any(func(line: String) -> bool: return line.contains("程不平")) and state.marks.get("严廷殷看了信", 0) == 1, "严廷殷 reads the letter: %s" % [said])
	_check(_ask(camp, general, "信").any(func(line: String) -> bool: return line.contains("信我看过了")), "asked again: 信我看过了")
	_check(_ask(camp, general, "印鉴丢过").any(func(line: String) -> bool: return line.contains("军师知道")), "the seal lost three days: 军师知道")
	session.record_journal()
	_check(state.quests.has("main.chapter6/general") and StoryQuestLog.objective(state, quests).begins_with("军师赫造基"), "the general step done, the adviser next: %s" % [StoryQuestLog.objective(state, quests)])
	# 赫造基: seven taels kept without a word, eight buy the mould.
	var adviser: NpcRuntimeState = await _beside(tree, session, camp, &"canyon.camp8.adviser.1")
	_check(_ask(camp, adviser, "印鉴").any(func(line: String) -> bool: return line.contains("八两银子")), "赫造基 names his price")
	var seven: ItemHandlingResult = camp.give_to_selected(&"test.toll", 7)
	_check(seven.done() and seven.lines.any(func(line: String) -> bool: return line.contains("钱太少了吧")) and not session.player_held_item_ids().has(MOULD), "seven taels: 钱太少了吧！没收 (adviser.c), no mould: %s" % [seven.lines])
	var eight: ItemHandlingResult = camp.give_to_selected(&"test.toll", 8)
	_check(eight.done() and eight.lines.any(func(line: String) -> bool: return line.contains("拓了个模子")) and session.player_held_item_ids().has(MOULD) and state.marks.get("赫造基说了拓模", 0) == 1, "eight taels: the secret and the 印模: %s" % [eight.lines])
	_check(_ask(camp, adviser, "拓模").any(func(line: String) -> bool: return line.contains("自己去比")), "asked of the mould after: 自己去比")
	var again: ItemHandlingResult = camp.give_to_selected(&"test.toll", 8)
	_check(again.done() and again.lines.any(func(line: String) -> bool: return line.contains("光滑的山壁")), "eight more taels after the mould: adviser.c's own secret (the swear), as before")
	session.record_journal()
	_check(state.quests.has("main.chapter6/adviser") and StoryQuestLog.objective(state, quests).begins_with("拿印模比一比"), "the adviser step done, the 比印 next")
	# The 后备兵 on the 印色; the mould compared with the 文书.
	var armory: WorldMapController = MapPlaces.enter(session, &"canyon.blackmarket", &"canyon.blackmarket.swear_arrival")
	_check(armory != null, "TEST-ONLY: in the 兵器库")
	await _settle(tree)
	var seller: NpcRuntimeState = await _beside(tree, session, armory, &"canyon.blackmarket.seller.1")
	_check(_ask(armory, seller, "印色").any(func(line: String) -> bool: return line.contains("泛黄光")), "the 后备兵: the real one 泛黄光")
	var mould: StringName = _carried(session, MOULD)
	_check(not mould.is_empty() and armory.act_with_item(mould), "比印")
	await _settle(tree)
	_check(state.marks.get("学过印色", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("只差一个颜色")), "the 印色 learned: 只差一个颜色: %s" % [ui.log_lines().slice(-3)])
	session.record_journal()
	_check(state.quests.has("main.chapter6/seal") and StoryQuestLog.objective(state, quests).begins_with("出关"), "the seal step done, the gate next: %s" % [StoryQuestLog.objective(state, quests)])
	# The east gate: listed with the 大队长, the soldier lets the player through on sight.
	var valley: WorldMapController = MapPlaces.enter(session, &"canyon.canyon7", &"canyon.canyon7.village_return")
	_check(valley != null, "in the valley")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("过了关门", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("名册上有你")), "the 关门兵 reads the roll: 名册上有你: %s" % [ui.log_lines().slice(-3)])
	var soldier: NpcRuntimeState = await _beside(tree, session, valley, &"canyon.canyon7.gate_soldier.1")
	_check(_ask(valley, soldier, "信").any(func(line: String) -> bool: return line.contains("说过了")), "the letter after the roll: 说过了，过去吧")
	_check(_ask(valley, soldier, "关北").any(func(line: String) -> bool: return line.contains("王法")), "关北: 那边是王法，不是朝法")
	session.record_journal()
	_check(state.quests.has("main.chapter6/gate") and StoryQuestLog.objective(state, quests).begins_with("顺着军道往北"), "the gate step done: %s" % [StoryQuestLog.objective(state, quests)])
	var gorge: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.gate_road")
	_check(gorge != null and gorge.map_id() == &"guanbei.gorge" and state.marks.get("到了关北", 0) == 1, "through the gate: 到了关北")
	session.record_journal()
	_check(state.quests.has("main.chapter6/guanbei") and StoryQuestLog.objective(state, quests).begins_with("进槐阳城"), "the 关北 step done, the city next: %s" % [StoryQuestLog.objective(state, quests)])
	var town: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.gate")
	_check(town != null and town.map_id() == &"guanbei.town", "at 槐阳城's gate")
	var notice: ActService = town.service(&"guanbei.gate.notice") as ActService
	_check(notice != null and await MapPlaces.drive(tree, town, MapPlaces.service_spot(town, &"guanbei.gate.notice")) and notice.in_reach(), "up to the notice")
	notice.interact()
	await _settle(tree)
	session.record_journal()
	_check(state.marks.get("看过王府告示", 0) == 1 and state.quests.has("main.chapter6/town") and StoryQuestLog.objective(state, quests).begins_with("王府在大街北头"), "the notice read, the 王府 next (关北 B): %s" % [StoryQuestLog.objective(state, quests)])
	_check(StoryQuestLog.is_active(state, quest) and not StoryQuestLog.is_done(state, quest), "the chapter waits at the 王府's door")
	# 卢卡 in the 马市: the ghost, the head, the 会首 in 番坊; his sword.
	var market: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.market")
	_check(market != null, "in the 马市")
	var luca: NpcRuntimeState = await _beside(tree, session, market, &"guanbei.market.luca.1")
	_check(_ask(market, luca, "会首").any(func(line: String) -> bool: return line.contains("先问鬼")), "the 会首 before the ghost: 先问鬼")
	_check(_ask(market, luca, "鬼").any(func(line: String) -> bool: return line.contains("找自己的头")) and state.marks.get("卢卡说了鬼", 0) == 1, "the headless ghost of his old soldiers' tale")
	_check(_ask(market, luca, "会首").any(func(line: String) -> bool: return line.contains("番坊")) and state.marks.get("卢卡说了番坊", 0) == 1, "会首安敦, in 番坊 (第七章's door)")
	var cheap: ItemHandlingResult = market.give_to_selected(&"test.toll", 10)
	_check(cheap.lines.any(func(line: String) -> bool: return line.contains("二十两")) and cheap.lines.any(func(line: String) -> bool: return line.contains("没有收下")) and not session.player_held_item_ids().has(GLADIUS), "ten taels refused and handed back: 二十两。少了，不卖: %s" % [cheap.lines])
	var sold: ItemHandlingResult = market.give_to_selected(&"test.toll", 20)
	_check(sold.done() and session.player_held_item_ids().has(GLADIUS) and state.marks.get("买了卢卡的剑", 0) == 1, "twenty taels: the 大秦短剑 is the player's: %s" % [sold.lines])
	_check(_ask(market, luca, "剑").any(func(line: String) -> bool: return line.contains("剑在你手里")), "asked of the sword after: 剑在你手里了")
	var balang: NpcRuntimeState = await _beside(tree, session, market, &"guanbei.market.balang.1")
	_check(_ask(market, balang, "卢卡").any(func(line: String) -> bool: return line.contains("大秦来的")), "巴朗 on the 高鼻子")
	# 老秦 in the 酒肆's corner (the rescue ledger) knows who opened his cell.
	var inn: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.inn_hall")
	_check(inn != null and _count_in(session, &"guanbei.inn_hall", &"native.npc.lao_qin") == 1, "老秦 sits in the 酒肆 on the rescue ledger")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("老秦认出你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("开牢门的是你")), "he knows the player: 开牢门的是你: %s" % [ui.log_lines().slice(-3)])
	var lao_qin: NpcRuntimeState = await _beside(tree, session, inn, &"guanbei.inn_hall.lao_qin.1")
	_check(_ask(inn, lao_qin, "工地").any(func(line: String) -> bool: return line.contains("道士的车接走")), "老秦 on the 工地: 挖不动的人，就让道士的车接走")
	var popo: NpcRuntimeState = await _beside(tree, session, inn, &"guanbei.inn_hall.qin_popo.1")
	_check(_ask(inn, popo, "老秦").any(func(line: String) -> bool: return line.contains("回来了")), "秦婆子: 回来了")
	# B: the 王府. The door shut; knocked open with the letter.
	town = await MapPlaces.go_to(tree, session, &"guanbei.palace_front")
	_check(town != null and not town.door(&"guanbei.palace.gate").is_open(), "the 王府大门 shut to a stranger")
	var guard: NpcRuntimeState = await _beside(tree, session, town, &"guanbei.palace_front.gate_guard.1", Vector2(0, 60))
	_check(_ask(town, guard, "信").any(func(line: String) -> bool: return line.contains("去叩门")), "the door guard: 拿着信去叩门")
	var knock: ActService = town.service(&"guanbei.palace_front.knock") as ActService
	_check(knock != null and await MapPlaces.drive(tree, town, MapPlaces.service_spot(town, &"guanbei.palace_front.knock")) and knock.in_reach() and knock.verb() == "叩门", "王府大门 · 叩门")
	knock.interact()
	await _settle(tree)
	_check(state.marks.get("王府放行", 0) == 1 and town.door(&"guanbei.palace.gate").is_open() and ui.log_lines().any(func(line: String) -> bool: return line.contains("朱门开了")), "the letter opens the door: 王府放行: %s" % [ui.log_lines().slice(-3)])
	# The hall: the reunion plays as the player walks in (the 保密 ledger).
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.palace_hall")
	_check(hall != null and hall.map_id() == &"guanbei.palace", "through the court into the 正厅")
	_check(_count_in(session, &"guanbei.palace_hall", &"native.npc.nan_weishui_guest") == 1, "南危水 stands by his brother's chair (保密)")
	for second: int in 12:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not hall.scene_running() and state.marks.get("见过重逢", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("二十年")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("守了二十年的口")), "危水。二十年。— the three beats, the player named: %s" % [ui.log_lines().slice(-6)])
	# The 水烟阁's forehall without him now.
	var forehall: WorldMapController = MapPlaces.enter(session, &"waterfog.forehall", &"waterfog.forehall.elder5.1")
	_check(forehall != null and _count_in(session, &"waterfog.forehall", &"waterfog.npc.elder5") == 0, "南危水 is gone from the 水烟阁's forehall (he went home to 关北)")
	# The letter to 程朔; the road chosen: 借兵.
	hall = MapPlaces.enter(session, &"guanbei.palace_hall", &"guanbei.palace_hall.yard_entry")
	await _settle(tree)
	var cheng: NpcRuntimeState = await _beside(tree, session, hall, &"guanbei.palace_hall.cheng_shuo.1")
	var letter: StringName = _carried(session, LETTER)
	_check(not letter.is_empty() and hall.select_npc(cheng.character_id), "the letter in hand, 程朔 selected")
	var given: ItemHandlingResult = hall.give_to_selected(letter)
	_check(given.done() and given.lines.any(func(line: String) -> bool: return line.contains("不平的字")) and state.marks.get("信递到了", 0) == 1 and not session.player_held_item_ids().has(LETTER), "程朔 reads the letter and keeps it: %s" % [given.lines.slice(0, 2)])
	session.record_journal()
	_check(state.quests.has("main.chapter6/palace") and StoryQuestLog.objective(state, quests).begins_with("借槐阳王的兵踏平工地"), "the palace step done, the choice next: %s" % [StoryQuestLog.objective(state, quests)])
	_check(_ask(hall, cheng, "南危水").any(func(line: String) -> bool: return line.contains("守了口")), "程朔 on his brother: 替他守了口")
	_check(_ask(hall, cheng, "工地").any(func(line: String) -> bool: return line.contains("古冢")), "程朔 on the 工地: 一座古冢")
	_check(_ask(hall, cheng, "借兵").any(func(line: String) -> bool: return line.contains("六骑")) and state.marks.get("借了兵", 0) == 1, "借兵 confirmed: 郭承，六骑，听他的")
	session.record_journal()
	_check(state.quests.has("main.chapter6/plan/raid") and StoryQuestLog.objective(state, quests).begins_with("去草原东边兵部的工地"), "the raid chosen, the 工地 next (C): %s" % [StoryQuestLog.objective(state, quests)])
	_check(_ask(hall, cheng, "潜入").any(func(line: String) -> bool: return line.contains("兵都借了")), "潜入 after 借兵: 兵都借了，还潜什么")
	# 郭承 at the drill yard takes the word and follows.
	var court: WorldMapController = MapPlaces.enter(session, &"guanbei.palace_yard", &"guanbei.palace_yard.hall_return")
	_check(court != null and await MapPlaces.drive_to_zone(tree, court, &"guanbei.drill"), "out to the drill yard")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var guo: NpcRuntimeState = MapPlaces.npc_at(session, &"guanbei.drill.guo_cheng.1")
	_check(guo != null and state.marks.get("郭承跟上了", 0) == 1 and guo.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and ui.log_lines().any(func(line: String) -> bool: return line.contains("六骑听你的")), "郭承: 王爷的话到了 — he follows: %s" % [ui.log_lines().slice(-3)])
	_check(_ask(court, guo, "潜入").any(func(line: String) -> bool: return line.contains("白天踏过去")), "潜入 of 郭承 after 借兵: 不用潜")


## A man from the release: the letter opens the gate; (TEST-ONLY) four taels refused, five taken;
## the 酒肆 without 老秦.
func _test_released(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	StoryFixtures.chapter5_released(session)
	# TEST-ONLY: the 告发 ledger (StoryFixtures' chase inherits the kept secret): 颜违 was told.
	state.quests.erase("main.chapter2/choice/keep")
	state.quests["main.chapter2/choice/tell"] = state.quests.size() + 1
	state.marks.erase("替南危水保密")
	state.marks["告发了南危水"] = 1
	session.record_journal()
	Finance.add_money(Finance.session_context(session), CurrencyDenomination.Value.SILVER, 12, &"test.toll") # TEST-ONLY
	var valley: WorldMapController = MapPlaces.enter(session, &"canyon.canyon7", &"canyon.canyon7.village_return")
	_check(valley != null, "in the valley, unlisted")
	await _settle(tree)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(not state.marks.has("过了关门"), "unlisted: the soldier says nothing")
	var refused: bool = await MapPlaces.take_passage(tree, valley, &"canyon.canyon7.east", 240)
	_check(not refused and session.active_map_id() == &"canyon.pass" and ui.log_lines().any(func(line: String) -> bool: return line.contains("过路钱")), "the gate refuses: 留下过路钱: %s" % [ui.log_lines().slice(-2)])
	var soldier: NpcRuntimeState = await _beside(tree, session, valley, &"canyon.canyon7.gate_soldier.2")
	_check(_ask(valley, soldier, "过路钱").any(func(line: String) -> bool: return line.contains("五两")), "过路钱: 五两")
	_check(_ask(valley, soldier, "信").any(func(line: String) -> bool: return line.contains("程县令的信")) and state.marks.get("过了关门", 0) == 1, "程不平's letter opens the gate: 过了关门")
	state.marks.erase("过了关门") # TEST-ONLY: the toll's way, as one without the letter
	var four: ItemHandlingResult = valley.give_to_selected(&"test.toll", 4)
	_check(four.lines.any(func(line: String) -> bool: return line.contains("少一个子儿不开门")) and four.lines.any(func(line: String) -> bool: return line.contains("没有收下")) and not state.marks.has("过了关门"), "four taels refused and handed back: 五两。少一个子儿不开门: %s" % [four.lines])
	var five: ItemHandlingResult = valley.give_to_selected(&"test.toll", 5)
	_check(five.done() and five.lines.any(func(line: String) -> bool: return line.contains("过路钱")) and state.marks.get("过了关门", 0) == 1, "five taels: 过了关门: %s" % [five.lines])
	var more: ItemHandlingResult = valley.give_to_selected(&"test.toll", 1)
	_check(more.done() and more.lines.any(func(line: String) -> bool: return line.contains("不嫌多")), "paid, another tael is kept: 钱老子不嫌多")
	var gorge: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.gate_road")
	_check(gorge != null and gorge.map_id() == &"guanbei.gorge", "through the gate")
	session.record_journal()
	_check(state.marks.get("到了关北", 0) == 1 and not state.quests.has("main.chapter6/gate") and StoryQuestLog.objective(state, quests).begins_with("带着程不平的信去天驼关军营"), "out before the camp: 到了关北 marked, but the chapter's steps wait in order at the camp (默认): %s" % [StoryQuestLog.objective(state, quests)])
	var inn: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.inn_hall")
	_check(inn != null and _count_in(session, &"guanbei.inn_hall", &"native.npc.lao_qin") == 0, "no 老秦 in the 酒肆 on the chase ledger")
	var popo: NpcRuntimeState = await _beside(tree, session, inn, &"guanbei.inn_hall.qin_popo.1")
	_check(_ask(inn, popo, "老秦").any(func(line: String) -> bool: return line.contains("没回来")), "秦婆子 still waits: 到今天没回来")
	# B: the 王府 on the 告发 ledger — no 南危水, 程朔's word; 潜入 agreed with 郭承.
	var town: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.palace_front")
	var knock: ActService = null if town == null else town.service(&"guanbei.palace_front.knock") as ActService
	_check(knock != null and await MapPlaces.drive(tree, town, MapPlaces.service_spot(town, &"guanbei.palace_front.knock")), "at the 王府's door")
	knock.interact()
	await _settle(tree)
	_check(state.marks.get("王府放行", 0) == 1, "knocked open with the letter")
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"guanbei.palace_hall")
	_check(hall != null and _count_in(session, &"guanbei.palace_hall", &"native.npc.nan_weishui_guest") == 0 and not hall.scene_running(), "no 南危水 in the hall on the 告发 ledger, no scene")
	var forehall: WorldMapController = MapPlaces.enter(session, &"waterfog.forehall", &"waterfog.forehall.elder5.1")
	_check(forehall != null and _count_in(session, &"waterfog.forehall", &"waterfog.npc.elder5") == 1, "南危水 stays at the 水烟阁")
	hall = MapPlaces.enter(session, &"guanbei.palace_hall", &"guanbei.palace_hall.yard_entry")
	await _settle(tree)
	var cheng: NpcRuntimeState = await _beside(tree, session, hall, &"guanbei.palace_hall.cheng_shuo.1")
	var letter: StringName = _carried(session, LETTER)
	_check(not letter.is_empty() and hall.select_npc(cheng.character_id) and hall.give_to_selected(letter).done() and state.marks.get("信递到了", 0) == 1, "the letter handed over")
	_check(_ask(hall, cheng, "南危水").any(func(line: String) -> bool: return line.contains("长老会")), "程朔 on the 告发: 告到长老会去了")
	var court: WorldMapController = MapPlaces.enter(session, &"guanbei.palace_yard", &"guanbei.palace_yard.hall_return")
	_check(court != null and await MapPlaces.drive_to_zone(tree, court, &"guanbei.drill"), "out to the drill yard")
	var guo: NpcRuntimeState = await _beside(tree, session, court, &"guanbei.drill.guo_cheng.1", Vector2(0, 60))
	_check(_ask(court, guo, "潜入").any(func(line: String) -> bool: return line.contains("夜里")) and state.marks.get("约好了潜入", 0) == 1 and guo.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER), "潜入 agreed: 郭承 follows")
	_check(_ask(court, guo, "借兵").any(func(line: String) -> bool: return line.contains("两头都空")), "借兵 of 郭承 after 潜入: 两头都要的人两头都空")
	hall = MapPlaces.enter(session, &"guanbei.palace_hall", &"guanbei.palace_hall.yard_entry")
	await _settle(tree)
	cheng = await _beside(tree, session, hall, &"guanbei.palace_hall.cheng_shuo.1")
	_check(_ask(hall, cheng, "借兵").any(func(line: String) -> bool: return line.contains("兵不动")) and not state.marks.has("借了兵"), "借兵 after 潜入: 那就夜里去——兵不动")


func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, point_id: StringName, offset: Vector2 = Vector2(0, 56)) -> NpcRuntimeState:
	var npc: NpcRuntimeState = MapPlaces.npc_at(session, point_id)
	var body: Node2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	_check(npc != null and body != null and map.place_player(npc.world_location().zone_id, body.global_position + offset), "TEST-ONLY: beside %s" % point_id)
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	return npc


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


## The instance id of the first of `definition_id` the player carries ("" when none).
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
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("关北", gender)
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


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
