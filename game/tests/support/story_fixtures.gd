class_name StoryFixtures
extends RefCounted

## TEST-ONLY: the state a chapter's suite starts from — the quest ledger keys, marks and
## carried things the chapters before it leave (主线 A; DECISIONS「剧情演出」), written into
## the player's CharacterState as the game writes them (StoryQuestLog's order), without
## playing those chapters. A suite then calls record_journal() and goes on from there, on
## the session as configure_source_entry() made it; no save file is involved.


## 寻剑令 done: the square asked of 冯策, the pass reached, the scene seen, the strip in
## hand (which begins 伪墓 on the next journal beat).
static func prologue_done(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.prologue#started", "main.prologue/waiter", "main.prologue/square/official",
		"main.prologue/pass", "main.prologue/scene", "main.prologue/strip", "main.prologue#done",
	]:
		_write(state, key)
	state.marks["隘口的道士"] = 1
	state.seen_npcs["snow.npc.waiter"] = true
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null and session.player_held_item_ids().get(&"native:oldpine/cloth_strip", false) == false:
		map.give_new_item_to_player(&"native:oldpine/cloth_strip")


## 伪墓 done after 寻剑令: the gate paid, 常老大 asked, the 黑衣道士 spared, the wall read,
## and the bones buried (`buried`) or the 腰牌 taken.
static func chapter1_done(session: WorldSessionController, buried: bool = true) -> void:
	prologue_done(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter1#started", "main.chapter1/trail", "main.chapter1/gate/pay", "main.chapter1/boss/talk",
		"main.chapter1/cave", "main.chapter1/taoist", "main.chapter1/wall",
		"main.chapter1/bones/bury" if buried else "main.chapter1/bones/token", "main.chapter1#done",
	]:
		_write(state, key)
	for mark: String in ["老松寨的小径", "老松寨的过路钱", "放过了黑衣道士", "黑衣道士倒了", "看过石壁", "查明伪墓", "安葬无名人" if buried else "带走腰牌"]:
		state.marks[mark] = 1
	state.milestones["defeat/native.npc.black_taoist"] = true
	var map: WorldMapController = session.active_map() as WorldMapController
	if not buried and map != null and session.player_held_item_ids().get(&"native:waterfog/guild_token", false) == false:
		map.give_new_item_to_player(&"native:waterfog/guild_token")


## 旧案 done after 伪墓 (buried): the letter and the 镖单 in hand, both inscriptions read,
## 南危水's confession, 潘军禅's bait, and the secret kept (`kept`) or told to 颜违.
static func chapter2_done(session: WorldSessionController, kept: bool = true) -> void:
	chapter1_done(session, true)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter2#started", "main.chapter2/liu", "main.chapter2/escort", "main.chapter2/tomb", "main.chapter2/stone",
		"main.chapter2/nan", "main.chapter2/pan", "main.chapter2/choice/keep" if kept else "main.chapter2/choice/tell", "main.chapter2#done",
	]:
		_write(state, key)
	for mark: String in ["柳淳风的引荐信", "看过镖单", "看过葬剑亭碑", "看过石台碑", "南危水承认了", "潘军禅说了鱼饵", "替南危水保密" if kept else "告发了南危水"]:
		state.marks[mark] = 1
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null:
		for item_id: StringName in [&"native:snow/letter_to_pan", &"native:cloud/escort_note"]:
			if session.player_held_item_ids().get(item_id, false) == false:
				map.give_new_item_to_player(item_id)


## 逆灵宫's entrance done after 旧案 (kept): 刘安禄 revealed, spared and asked (`liu`; else 黄霸
## asked in the 土地庙), the turn seen, the crack looked at; the quest stands at its gate step
## (主线 C; the tribute cart and its escort are on the turn's stage from the chapter's start).
static func chapter3_entry_done(session: WorldSessionController, liu: bool = true) -> void:
	chapter2_done(session, true)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3#started", "main.chapter3/lead/liu" if liu else "main.chapter3/lead/hwang", "main.chapter3/cart"]:
		_write(state, key)
	for mark: String in ["刘安禄说了大寨主" if liu else "黄霸说了纳供", "看过裂口"] + (["放过了刘安禄"] if liu else []):
		state.marks[mark] = 1


## 逆灵宫 A done (DECISIONS「逆灵宫 A」): in by the oil-cloth, the yard reached, the chapter at
## `hall` (B goes on from the 殿门).
static func chapter3_yard_done(session: WorldSessionController) -> void:
	chapter3_entry_done(session, true)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/gate", "main.chapter3/way/sneak", "main.chapter3/yard"]:
		_write(state, key)
	for mark: String in ["进了逆灵宫", "跟车进了逆灵宫"]:
		state.marks[mark] = 1


## 逆灵宫 B done (DECISIONS「逆灵宫 B」): the hall, the ledger and the papers read, the passage
## reached; the chapter at `altar` (C plays the 唤首 scene from the 北门).
static func chapter3_dungeon_done(session: WorldSessionController) -> void:
	chapter3_yard_done(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/hall", "main.chapter3/ledger", "main.chapter3/papers", "main.chapter3/dungeon"]:
		_write(state, key)
	for mark: String in ["看过账册", "看过兵部文书", "门房道士打过招呼"]:
		state.marks[mark] = 1


## 逆灵宫 C done by the rescue (DECISIONS「逆灵宫 C」): the scene seen, the ghouls down, 霍铮 and
## 石头 out and home, 黄霸 yielded; the chapter done. 刘安禄 was spared (chapter3_entry_done).
static func chapter3_rescued(session: WorldSessionController) -> void:
	chapter3_dungeon_done(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/altar", "main.chapter3/ghosts", "main.chapter3/choice/rescue", "main.chapter3/home", "main.chapter3#done"]:
		_write(state, key)
	for mark: String in ["见过唤首", "祭坛的鬼卒倒了", "狱卒交了钥匙", "救出了霍铮", "救出了石头", "放了关北民夫", "石头回家了", "霍铮回了寨", "逆灵宫一章"]:
		state.marks[mark] = 1


## 逆灵宫 C done by the chase: the back door taken, 玄冥子 down (spared); the chapter done.
static func chapter3_chased(session: WorldSessionController) -> void:
	chapter3_dungeon_done(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/altar", "main.chapter3/ghosts", "main.chapter3/choice/chase", "main.chapter3/duel", "main.chapter3#done"]:
		_write(state, key)
	for mark: String in ["见过唤首", "祭坛的鬼卒倒了", "追出了后门", "玄冥子倒了", "放过了玄冥子", "逆灵宫一章"]:
		state.marks[mark] = 1


## 宝衣 done after 逆灵宫 by the rescue (DECISIONS「第四章 宝衣」): 潘军禅 asked, 安妮儿 asked, 瑷伦's
## three lashes stood, 斩鬼 answered, the 冰匣 danced open (a woman's own dance), the robe given
## back to 瑷伦, who keeps it to the last day. The manor stands as it was.
static func chapter4_kept(session: WorldSessionController) -> void:
	chapter3_rescued(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter4#started", "main.chapter4/lead/pan", "main.chapter4/manor", "main.chapter4/annie", "main.chapter4/keeper",
		"main.chapter4/lashes", "main.chapter4/question/slay", "main.chapter4/chest", "main.chapter4/choice/keep", "main.chapter4#done",
	]:
		_write(state, key)
	for mark: String in ["潘军禅说了宝衣", "安妮儿说了等", "瑷伦说了三鞭", "接下了瑷伦三鞭", "答瑷伦：斩鬼", "瑷伦说了冰匣", "dance_yu_fong", "冰匣开了", "瑷伦守到决战", "宝衣一章"]:
		state.marks[mark] = 1


## 宝衣 done after 逆灵宫 by the chase: 南危水 asked, 不知道 answered, 芳绫 danced the 冰匣 open for a
## man, the robe carried out of the gate (the night follows on the next visit to the manor).
static func chapter4_taken(session: WorldSessionController) -> void:
	chapter3_chased(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter4#started", "main.chapter4/lead/nan", "main.chapter4/manor", "main.chapter4/annie", "main.chapter4/keeper",
		"main.chapter4/lashes", "main.chapter4/question/unsure", "main.chapter4/chest", "main.chapter4/choice/take", "main.chapter4#done",
	]:
		_write(state, key)
	for mark: String in ["南危水说了宝衣", "安妮儿说了等", "瑷伦说了三鞭", "接下了瑷伦三鞭", "答瑷伦：不知", "瑷伦说了冰匣", "冰匣开了", "芳绫跟你去了", "芳绫替你跳了", "带走了宝衣", "宝衣一章"]:
		state.marks[mark] = 1
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null and session.player_held_item_ids().get(&"native:latemoon/cold_robe", false) == false:
		map.give_new_item_to_player(&"native:latemoon/cold_robe")


## 人证 done after 宝衣 kept (DECISIONS「第五章 人证」): the drum beaten with the 兵部文书, 程不平 asked,
## 陈显祖 shown the seal, the hollow's 鬼卒 down and the 抄本 out of the chest, the 侍卫 asked, 陈显祖
## escorted through 庾家's men to the 大堂 and kept in the 内厅; the letter, the 抄本 and the papers in hand.
static func chapter5_escorted(session: WorldSessionController) -> void:
	chapter4_kept(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter5#started", "main.chapter5/drum", "main.chapter5/hear", "main.chapter5/chen", "main.chapter5/copy",
		"main.chapter5/guard", "main.chapter5/choice/escort", "main.chapter5/trial", "main.chapter5#done",
	]:
		_write(state, key)
	for mark: String in ["击了鼓", "程不平要人证", "陈显祖认了", "树洞的鬼卒倒了", "看过寻剑令抄本", "侍卫说了拒令", "陈显祖跟你走了", "见过庾家拦路", "福林大街的庾家人倒了", "陈显祖进了大堂", "堂审过", "陈显祖作了证", "程不平写了信", "人证一章"]:
		state.marks[mark] = 1
	_chapter5_things(session)


## 人证 done after 宝衣 taken: the chest returned first and the 抄本 from 陈显祖's hand, then 走吧 — he is
## gone with his box; the trial without him (纸能证纸，不能证人), the letter all the same.
static func chapter5_released(session: WorldSessionController) -> void:
	chapter4_taken(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter5#started", "main.chapter5/drum", "main.chapter5/hear", "main.chapter5/chen", "main.chapter5/copy",
		"main.chapter5/guard", "main.chapter5/choice/release", "main.chapter5/trial", "main.chapter5#done",
	]:
		_write(state, key)
	for mark: String in ["击了鼓", "程不平要人证", "陈显祖认了", "树洞的鬼卒倒了", "看过寻剑令抄本", "侍卫说了拒令", "放走了陈显祖", "堂审过", "只留了文书", "程不平写了信", "人证一章"]:
		state.marks[mark] = 1
	_chapter5_things(session)


## What the fifth chapter leaves in the player's hands: the 兵部文书, the 抄本 and 程不平's letter.
static func _chapter5_things(session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return
	for item_id: StringName in [&"native:niling/war_ministry_papers", &"native:choyin/decree_copy", &"native:choyin/magistrate_letter"]:
		if session.player_held_item_ids().get(item_id, false) == false:
			map.give_new_item_to_player(item_id)

## 关北 A and B done after 人证 (escorted): the letter shown at the camp, the mould bought and compared,
## the gate passed by the roll, the notice read, the door knocked open, the letter handed to 程朔 and
## the road chosen — 借兵 (`raid`) with 郭承 following, or 潜入 (not raid).
static func chapter6_planned(session: WorldSessionController, raid: bool = true) -> void:
	chapter5_escorted(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter6#started", "main.chapter6/general", "main.chapter6/adviser", "main.chapter6/seal", "main.chapter6/gate",
		"main.chapter6/guanbei", "main.chapter6/town", "main.chapter6/palace", "main.chapter6/plan/raid" if raid else "main.chapter6/plan/sneak",
	]:
		_write(state, key)
	for mark: String in ["军营", "严廷殷看了信", "赫造基说了拓模", "学过印色", "过了关门", "到了关北", "看过王府告示", "王府放行", "见过重逢", "信递到了", "借了兵" if raid else "约好了潜入"]:
		state.marks[mark] = 1
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null and session.player_held_item_ids().get(&"native:canyon/seal_mould", false) == false:
		map.give_new_item_to_player(&"native:canyon/seal_mould")
	if map != null:
		map.open_found_ways("王府放行") # the knock opened the 王府大门 (a found_by door opens as its mark is written)


## 关北 C done after the road chosen: the 工地 raided with the 王府's riders (`raid`: every 枷 opened, the
## cart's taoists fled) or the night's sneak (four freed, the watch down, 救了一半); the way to the 古冢口
## open, the chapter's last step (卢卡's 会首) still to ask. 郭承 is not placed at the player's side:
## a test that wants him following brings him (his mood going).
static func chapter6_site_done(session: WorldSessionController, raid: bool = true) -> void:
	chapter6_planned(session, raid)
	var state: CharacterState = session.player_runtime().state
	_write(state, "main.chapter6/site")
	_write(state, "main.chapter6/raid" if raid else "main.chapter6/sneak")
	for mark: String in (["郭承跟上了", "工地动过手", "工地的武官倒了", "裴照倒了", "吕隼倒了", "踏平了工地"] if raid else ["守夜的武官倒了", "救了一半"]) + ["进得了古冢口"]:
		state.marks[mark] = 1


static func _write(state: CharacterState, key: String) -> void:
	if not state.quests.has(key):
		state.quests[key] = state.quests.size() + 1


## 关北 done (关北 D): after the 工地 the last step — 卢卡 asked of the ghost and his 会首 — and the
## chapter's mark 关北一章; the seventh chapter opens. Its ledger keys and marks as the chapter writes them.
static func chapter6_done(session: WorldSessionController, raid: bool = true) -> void:
	chapter6_site_done(session, raid)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter6/luca", "main.chapter6#done"]:
		_write(state, key)
	for mark: String in ["卢卡说了鬼", "卢卡说了番坊", "关北一章"]:
		state.marks[mark] = 1


## 番坊 B: in 番坊 after 关北 (`raid`), 卢卡 met at the gate, 安敦 met in his hall and asked of the 铜牒;
## no side taken yet. Its ledger keys and marks as the chapter writes them; the player is not moved.
static func chapter7_told(session: WorldSessionController, raid: bool = true) -> void:
	chapter6_done(session, raid)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter7#started", "main.chapter7/fanfang", "main.chapter7/hall", "main.chapter7/tablet_tale"]:
		_write(state, key)
	for mark: String in ["到了番坊", "卢卡在番坊见到你", "见了安敦", "安敦说了铜牒"]:
		state.marks[mark] = 1


## chapter7_told() and a side taken — the 大秦人's (`rome`: 安敦's 站大秦人) or the 浪人's (早川's 站浪人).
static func chapter7_sided(session: WorldSessionController, rome: bool = true, raid: bool = true) -> void:
	chapter7_told(session, raid)
	var state: CharacterState = session.player_runtime().state
	_write(state, "main.chapter7/side/rome" if rome else "main.chapter7/side/ronin")
	state.marks["站了大秦人" if rome else "站了浪人"] = 1


## 番坊 C: the seventh chapter done on one side — the 大秦人's (`rome`: the tablet from the fire, 冯禄 faced
## at the gate) or the 浪人's (早川's 一刀, the tablet stolen by night, the 大秦人 cleared) — and the 铜牒
## read; the chapter's mark 番坊一章 and the eighth chapter's stub open. Its ledger keys and marks as the
## chapter writes them; the player is not moved and holds no tablet.
static func chapter7_done(session: WorldSessionController, rome: bool = true, raid: bool = true) -> void:
	chapter7_sided(session, rome, raid)
	var state: CharacterState = session.player_runtime().state
	for key: String in (["main.chapter7/rome", "main.chapter7/gate"] if rome else ["main.chapter7/ronin", "main.chapter7/theft"]) + ["main.chapter7/read", "main.chapter7#done"]:
		_write(state, key)
	for mark: String in (["火前说了真话", "铜牒到手", "争地过了", "大秦人留下了"] if rome else ["早川见过你", "过了一刀", "铜牒到手", "大秦人被清走"]) + ["读过铜牒", "番坊一章"]:
		state.marks[mark] = 1


## 第八章 done (第八章 A): down the lake, through the cold and the dragons' hall, the pool, 璃虹's
## three questions and the 封法, 商玦's word — and the choice: `pulled`, the sword drawn (the head
## awake, 璃虹 out of the ice), else the seal looked over and her feather taken; the chapter's mark
## 湖底一章 and the ninth chapter's stub open; on the pull ledger the night after too (第八章 B: the three
## bands of 鬼卒 beaten). Its ledger keys and marks as the chapter writes them; the player is not moved and
## holds neither sword nor feather.
static func chapter8_done(session: WorldSessionController, pulled: bool = true, rome: bool = true, raid: bool = true) -> void:
	chapter7_done(session, rome, raid)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter8/lake", "main.chapter8/cave", "main.chapter8/pool", "main.chapter8/seal", "main.chapter8/choice/pull" if pulled else "main.chapter8/choice/keep"] + (["main.chapter8/night"] if pulled else []) + ["main.chapter8#done"]:
		_write(state, key)
	for mark: String in ["下了湖底", "到了冰龙厅", "看过封坛", "见过璃虹", "璃虹说了封法", "商玦劝过你"] + (["拔了穿灵", "湖畔的鬼卒退了", "村口的鬼卒退了", "稻田的鬼卒退了"] if pulled else ["查清了封物"]) + ["湖底一章"]:
		state.marks[mark] = 1


## 第九章 done (第九章 A–E): in by the 武举, the 养心殿, the 原令 matched — and the choice: `side` expose
## (庾子建下狱, 冯策随你下湖), deal (私了: 宋朴传了话, 私了了庾子建) or uncle (the 手诏 carried: 皇叔入朝); the
## chapter's mark 皇城一章 and the tenth chapter opens. Its ledger keys and marks as the chapter writes them.
static func chapter9_done(session: WorldSessionController, side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true) -> void:
	chapter8_done(session, pulled, rome, raid)
	var state: CharacterState = session.player_runtime().state
	var keys: Array[String] = ["main.chapter9#started", "main.chapter9/way/exam", "main.chapter9/audience", "main.chapter9/decree", "main.chapter9/choice/%s" % side]
	if side == "uncle":
		keys.append("main.chapter9/uncle_road")
	keys.append("main.chapter9#done")
	for key: String in keys:
		_write(state, key)
	var marks: Array[String] = ["中了武状元", "宫门放行", "候了殿试", "殿试过", "进了皇城", "见了福安", "见了皇帝", "翻过樟木匣", "对出了原令", "见过卫沧澜"]
	match side:
		"expose": marks.append_array(["庾子建下狱", "冯策随你下湖", "卫沧澜作证", "卫沧澜出了尚书府"])
		"deal": marks.append_array(["宋朴传了话", "私了了庾子建"])
		"uncle": marks.append_array(["皇叔的通缉解了", "皇叔入朝"])
	marks.append("皇城一章")
	for mark: String in marks:
		state.marks[mark] = 1


## 第十章 done (第十章 A–C): the wind read, 岚翁 asked of 旋芒, and `who` drew it — self (旋芒在你手里: the
## sword not given, the suite gives it), uncle (旋芒在皇叔手里) or xiao (旋芒在萧辟尘手里); 岚城一章, and the
## finale (main.finale) begins on the next journal beat.
static func chapter10_done(session: WorldSessionController, who: String = "self", side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true) -> void:
	chapter9_done(session, side, pulled, rome, raid)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter10#started", "main.chapter10/wind", "main.chapter10/city", "main.chapter10/elder", "main.chapter10/choice/%s" % who, "main.chapter10#done"]:
		_write(state, key)
	var held: Dictionary[String, String] = {"self": "旋芒在你手里", "uncle": "旋芒在皇叔手里", "xiao": "旋芒在萧辟尘手里"}
	for mark: String in ["到了岚城", "见过岚翁", held[who], "岚城一章"]:
		state.marks[mark] = 1


## 势力线 封山 (DECISIONS「封山 A」): taken in by 柳淳风, as apprentice.c's recruit leaves the state
## (NpcApprenticeship._recruit(): 第十四代弟子, class swordsman). The line begins on the next journal beat.
static func fonxan_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.fonxan", 14)
	state.apprenticeship.master_teacher_id = &"common.npc.swordsman.master"
	state.apprenticeship.legacy_master_name = "柳淳风"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"swordsman"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


## 封山 A's 守馆 done: 柳淳风 heard, 罗七 and his two beaten, 逄义 asked, the 腰牌 given back
## (大弟子); 李火狮 waits for the word on the 门房.
static func fonxan_guarded(session: WorldSessionController) -> void:
	fonxan_joined(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.fonxan#started", "faction.fonxan/hear", "faction.fonxan/fakes", "faction.fonxan/pang", "faction.fonxan/report"]:
		_write(state, key)
	for mark: String in ["柳淳风说了冒牌", "说破了冒牌弟子", "冒牌头目倒了", "冒牌帮闲倒了", "逄义认了腰牌", "守馆办完了"]:
		state.marks[mark] = 1
	state.affiliation.family_title = "大弟子"


## 封山 A done to the 门房 (替他瞒 unless `revealed`), and 柳淳风 has said his word on it: the 竹书
## is next (封山 B).
static func fonxan_gated(session: WorldSessionController, revealed: bool = false) -> void:
	fonxan_guarded(session)
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.fonxan/gate/%s" % ("reveal" if revealed else "cover"))
	for mark: String in ["李火狮说了门房", "说破了刘安禄" if revealed else "替刘安禄瞒了", "柳淳风说过门房"]:
		state.marks[mark] = 1


## 封山 B's 竹书 fetched and given, to 柳绘心 (`to_daughter`) or to 柳淳风: the 内院 is next.
static func fonxan_book_given(session: WorldSessionController, to_daughter: bool) -> void:
	fonxan_gated(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.fonxan/bamboo_hear", "faction.fonxan/bamboo", "faction.fonxan/book/%s" % ("daughter" if to_daughter else "father")]:
		_write(state, key)
	for mark: String in ["柳淳风说了推法", "竹书给了柳绘心" if to_daughter else "竹书给了柳淳风"]:
		state.marks[mark] = 1
