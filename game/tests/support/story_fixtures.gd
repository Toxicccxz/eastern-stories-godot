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
