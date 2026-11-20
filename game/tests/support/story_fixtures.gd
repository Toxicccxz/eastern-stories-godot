class_name StoryFixtures
extends RefCounted

const Reads := preload("res://tests/support/story_reads.gd")

## TEST-ONLY: the state a chapter's suite starts from — the quest ledger keys, marks and
## carried things the chapters before it leave (主线 A; DECISIONS「剧情演出」), written into
## the player's CharacterState as the game writes them (StoryQuestLog's order), without
## playing those chapters. Every mark, ledger key and thing goes through _mark, _write, _give and _take, so
## record() can tell what a fixture writes (the hand-over checks, the dev starts). A suite then calls record_journal() and goes on from there, on
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
	for mark: String in ["隘口的道士", "布条落了地", "拿回了荐信"]:
		_mark(state, mark)
	state.seen_npcs["snow.npc.waiter"] = true
	_give(session, &"native:oldpine/cloth_strip")
	_give(session, &"native:snow/old_letter")


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
		_mark(state, mark)
	state.milestones["defeat/native.npc.black_taoist"] = true
	if not buried:
		_give(session, &"native:waterfog/guild_token")


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
		_mark(state, mark)
	for item_id: StringName in [&"native:snow/letter_to_pan", &"native:cloud/escort_note"]:
		_give(session, item_id)


## 逆灵宫's entrance done after 旧案 (kept): 刘安禄 revealed, spared and asked (`liu`; else 黄霸
## asked in the 土地庙), the turn seen, the crack looked at; the quest stands at its gate step
## (主线 C; the tribute cart and its escort are on the turn's stage from the chapter's start).
static func chapter3_entry_done(session: WorldSessionController, liu: bool = true) -> void:
	chapter2_done(session, true)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3#started", "main.chapter3/lead/liu" if liu else "main.chapter3/lead/hwang", "main.chapter3/cart"]:
		_write(state, key)
	for mark: String in ["刘安禄说了大寨主" if liu else "黄霸说了纳供", "看过裂口"] + (["放过了刘安禄"] if liu else []):
		_mark(state, mark)


## 逆灵宫 A done (DECISIONS「逆灵宫 A」): in by the oil-cloth, the yard reached (the 门房道士's word
## for the newcomer heard on the way), the chapter at `hall` (B goes on from the 殿门).
static func chapter3_yard_done(session: WorldSessionController) -> void:
	chapter3_entry_done(session, true)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/gate", "main.chapter3/way/sneak", "main.chapter3/yard"]:
		_write(state, key)
	for mark: String in ["进了逆灵宫", "跟车进了逆灵宫", "门房道士打过招呼"]:
		_mark(state, mark)


## 逆灵宫 B done (DECISIONS「逆灵宫 B」): the hall, the ledger and the papers read, the passage
## reached; the chapter at `altar` (C plays the 唤首 scene from the 北门).
static func chapter3_dungeon_done(session: WorldSessionController) -> void:
	chapter3_yard_done(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/hall", "main.chapter3/ledger", "main.chapter3/papers", "main.chapter3/dungeon"]:
		_write(state, key)
	for mark: String in ["看过账册", "看过兵部文书"]:
		_mark(state, mark)
	for item_id: StringName in [&"native:niling/tribute_ledger", &"native:niling/war_ministry_papers", &"native:niling/cell_key"]:
		_give(session, item_id)


## 逆灵宫 C done by the rescue (DECISIONS「逆灵宫 C」): the scene seen, the ghouls down, 霍铮 and
## 石头 out and home, 黄霸 yielded; the chapter done. 刘安禄 was spared (chapter3_entry_done).
static func chapter3_rescued(session: WorldSessionController) -> void:
	chapter3_dungeon_done(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/altar", "main.chapter3/ghosts", "main.chapter3/choice/rescue", "main.chapter3/home", "main.chapter3#done"]:
		_write(state, key)
	for mark: String in ["见过唤首", "祭坛的鬼卒倒了", "狱卒交了钥匙", "救出了霍铮", "救出了石头", "放了关北民夫", "石头回家了", "霍铮回了寨", "逆灵宫一章"]:
		_mark(state, mark)


## 逆灵宫 C done by the chase: the back door taken, 玄冥子 down (spared); the chapter done.
static func chapter3_chased(session: WorldSessionController) -> void:
	chapter3_dungeon_done(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter3/altar", "main.chapter3/ghosts", "main.chapter3/choice/chase", "main.chapter3/duel", "main.chapter3#done"]:
		_write(state, key)
	for mark: String in ["见过唤首", "祭坛的鬼卒倒了", "追出了后门", "玄冥子倒了", "放过了玄冥子", "逆灵宫一章"]:
		_mark(state, mark)
	_take(session, &"native:niling/cell_key")


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
		_mark(state, mark)


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
	for mark: String in ["南危水说了宝衣", "安妮儿说了等", "瑷伦说了三鞭", "接下了瑷伦三鞭", "答瑷伦：不知", "瑷伦说了冰匣", "冰匣开了", "芳绫跟你去了", "芳绫替你跳了", "带走了宝衣", "宝衣一章", "瑷伦叹过", "神教杀手倒了", "放过了神教杀手", "老妇说了拦", "安妮儿记下了"]:
		_mark(state, mark)
	_give(session, &"native:latemoon/cold_robe")


## 人证 done after 宝衣 kept (DECISIONS「第五章 人证」): the drum beaten with the 兵部文书, 程不平 asked,
## 陈显祖 shown the seal, the hollow's 鬼卒 down and the 抄本 out of the chest, the 侍卫 asked, 陈显祖
## escorted through 庾家's men to the 大堂 and kept in the 内厅; the letter, the 抄本 and the papers in hand.
static func chapter5_escorted(session: WorldSessionController, letter: bool = true) -> void:
	chapter4_kept(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter5#started", "main.chapter5/drum", "main.chapter5/hear", "main.chapter5/chen", "main.chapter5/copy",
		"main.chapter5/guard", "main.chapter5/choice/escort", "main.chapter5/trial", "main.chapter5#done",
	]:
		_write(state, key)
	for mark: String in ["击了鼓", "程不平要人证", "陈显祖认了", "树洞的鬼卒倒了", "看过寻剑令抄本", "侍卫说了拒令", "陈显祖跟你走了", "见过庾家拦路", "福林大街的庾家人倒了", "陈显祖进了大堂", "堂审过", "陈显祖作了证", "程不平写了信", "人证一章", "程不平提过三叔", "程不平给了信"]:
		_mark(state, mark)
	_give(session, &"es2:d/choyin/obj/chest")
	_chapter5_things(session, letter)


## 人证 done after 宝衣 taken: the chest returned first and the 抄本 from 陈显祖's hand, then 走吧 — he is
## gone with his box; the trial without him (纸能证纸，不能证人), the letter all the same.
static func chapter5_released(session: WorldSessionController, letter: bool = true) -> void:
	chapter4_taken(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter5#started", "main.chapter5/drum", "main.chapter5/hear", "main.chapter5/chen", "main.chapter5/copy",
		"main.chapter5/guard", "main.chapter5/choice/release", "main.chapter5/trial", "main.chapter5#done",
	]:
		_write(state, key)
	for mark: String in ["击了鼓", "程不平要人证", "陈显祖认了", "树洞的鬼卒倒了", "看过寻剑令抄本", "侍卫说了拒令", "放走了陈显祖", "堂审过", "只留了文书", "程不平写了信", "人证一章", "程不平提过三叔", "程不平给了信"]:
		_mark(state, mark)
	_chapter5_things(session, letter)


## What the fifth chapter leaves in the player's hands: the 兵部文书, the 抄本 and 程不平's letter (`letter`;
## 关北 hands it to 程朔, so a later chapter's ledger holds it no more).
static func _chapter5_things(session: WorldSessionController, letter: bool = true) -> void:
	var things: Array[StringName] = [&"native:niling/war_ministry_papers", &"native:choyin/decree_copy"]
	if letter:
		things.append(&"native:choyin/magistrate_letter")
	for item_id: StringName in things:
		_give(session, item_id)

## 关北 A and B done after 人证 (escorted): the letter shown at the camp, the mould bought and compared,
## the gate passed by the roll, the notice read, the door knocked open, the letter handed to 程朔 and
## the road chosen — 借兵 (`raid`) with 郭承 following, or 潜入 (not raid). With `chased` the ledger before it
## is 逆灵宫's chase (chapter5_released: 宝衣 taken, 陈显祖 let go), else the rescue (chapter5_escorted); every
## later fixture passes `chased` on, so a chapter can be set up on either line.
static func chapter6_planned(session: WorldSessionController, raid: bool = true, chased: bool = false) -> void:
	if chased:
		chapter5_released(session, false)
	else:
		chapter5_escorted(session, false)
	var state: CharacterState = session.player_runtime().state
	for key: String in [
		"main.chapter6#started", "main.chapter6/general", "main.chapter6/adviser", "main.chapter6/seal", "main.chapter6/gate",
		"main.chapter6/guanbei", "main.chapter6/town", "main.chapter6/palace", "main.chapter6/plan/raid" if raid else "main.chapter6/plan/sneak",
	]:
		_write(state, key)
	for mark: String in ["军营", "严廷殷看了信", "赫造基说了拓模", "学过印色", "过了关门", "到了关北", "看过王府告示", "王府放行", "见过重逢", "信递到了", "借了兵" if raid else "约好了潜入"]:
		_mark(state, mark)
	_give(session, &"native:canyon/seal_mould")
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null:
		map.open_found_ways("王府放行") # the knock opened the 王府大门 (a found_by door opens as its mark is written)


## 关北 C done after the road chosen: the 工地 raided with the 王府's riders (`raid`: every 枷 opened, the
## cart's taoists fled) or the night's sneak (four freed, the watch down, 救了一半); the way to the 古冢口
## open, the chapter's last step (卢卡's 会首) still to ask. 郭承 is not placed at the player's side:
## a test that wants him following brings him (his mood going).
static func chapter6_site_done(session: WorldSessionController, raid: bool = true, chased: bool = false) -> void:
	chapter6_planned(session, raid, chased)
	var state: CharacterState = session.player_runtime().state
	_write(state, "main.chapter6/site")
	_write(state, "main.chapter6/raid" if raid else "main.chapter6/sneak")
	# The raid's 枷锁 (guanbei/world.json guanbei.sheds.shackles) writes its four marks; the sneak's 走！ (郭承's
	# reaction, guanbei/npcs.json) its three. 关北的骑兵欠你一阵 / 王府干净 ring 关北's bell (第十章).
	for mark: String in (["郭承跟上了", "工地动过手", "工地打起来了", "工地的武官倒了", "裴照倒了", "吕隼倒了", "踏平了工地", "关北的骑兵欠你一阵", "关北背了反名"] if raid else ["守夜的武官倒了", "救了一半", "王府干净"]) + ["进得了古冢口", "郭承提过霍铮"]:
		_mark(state, mark)


## TEST-ONLY check (章与章之间的衔接), both ways. What a chapter's suite played out must hold what the next
## chapter's fixture writes — so a fixture that drifts from the game turns its chapter red. Calls
## `fixture` (a StoryFixtures function bound to its arguments, the session first) on the played
## session and returns what it added: ledger keys, marks, milestones, NPCs met and carried
## things the play did not leave. And the other way, for the main story's fixtures (those that write the story
## from 寻剑令 on, as the dev starts at a chapter use them): every mark the play left that some later condition
## reads (StoryReads) and the fixture does not write ("unwritten mark"), and every quest item the play left in
## hand that something later reads or takes and neither the fixture nor `carried` gives ("not carried": `carried`
## is what ChapterStart.carried adds for the chapter the fixture opens). Empty: in step. The fixture's writes
## stay; call it last. Marks in `ignoring` are the suite's own (a ledger it builds TEST-ONLY, a talk the
## fixture leaves out on purpose), not compared either way; HANDOFF_ONCE are left out of the second direction.
static func missing_after_play(session: WorldSessionController, fixture: Callable, ignoring: Array = [], carried: Array = []) -> Array[String]:
	var state: CharacterState = session.player_runtime().state
	var quests: Array[String] = state.quests.keys()
	var marks: Array[String] = state.marks.keys()
	var milestones: Array[String] = state.milestones.keys()
	var seen: Array[String] = state.seen_npcs.keys()
	var held: Array[StringName] = session.player_held_item_ids().keys()
	var written: Dictionary = record(fixture.bind(session))
	var missing: Array[String] = []
	for key: String in state.quests:
		if not quests.has(key):
			missing.append("ledger " + key)
	for mark: String in state.marks:
		if not marks.has(mark) and not ignoring.has(mark):
			missing.append("mark " + mark)
	for milestone: String in state.milestones:
		if not milestones.has(milestone):
			missing.append("milestone " + milestone)
	for npc: String in state.seen_npcs:
		if not seen.has(npc):
			missing.append("met " + npc)
	for item_id: StringName in session.player_held_item_ids():
		if not held.has(item_id):
			missing.append("carried " + String(item_id))
	if not written["quests"].has("main.prologue#started"):
		return missing
	for mark: String in marks:
		if not written["marks"].has(mark) and not ignoring.has(mark) and not HANDOFF_ONCE.has(mark) and Reads.mark_read(mark):
			missing.append("unwritten mark " + mark)
	for item_id: StringName in held:
		var item: ItemContentDefinition = GameContent.catalog().item(item_id)
		if item == null or not item.quest_item or written["given"].has(item_id) or written["taken"].has(item_id) or carried.has(item_id):
			continue
		if Reads.item_read(item_id):
			missing.append("not carried " + String(item_id))
	return missing


## Marks a playthrough leaves that the chapter fixtures leave out on purpose, and why: talk that is said once and
## only keeps its NPC from saying it again (a start that has not heard it hears it the first time).
const HANDOFF_ONCE: Dictionary[String, String] = {}


## What `fixture` (a StoryFixtures function bound to all its arguments) writes and gives: {"quests", "marks":
## Dictionary[String, bool], "given", "taken": Dictionary[StringName, bool]} — every mark and ledger key it writes
## (whether there already or not) and every thing it gives (whether carried already or not) or takes.
static func record(fixture: Callable) -> Dictionary:
	var outer: Dictionary = _recorded
	_recorded = {"quests": {}, "marks": {}, "given": {}, "taken": {}}
	fixture.call()
	var out: Dictionary = _recorded
	_recorded = outer
	if not outer.is_empty():
		for part: String in out:
			(outer[part] as Dictionary).merge(out[part])
	return out


static var _recorded: Dictionary = {}


static func _write(state: CharacterState, key: String) -> void:
	if not _recorded.is_empty():
		_recorded["quests"][key] = true
	if not state.quests.has(key):
		state.quests[key] = state.quests.size() + 1


static func _mark(state: CharacterState, mark: String) -> void:
	if not _recorded.is_empty():
		_recorded["marks"][mark] = true
	state.marks[mark] = 1


## One of `item_id` into the player's hands unless they carry one already (on a session with a map).
static func _give(session: WorldSessionController, item_id: StringName) -> void:
	if not _recorded.is_empty():
		_recorded["given"][item_id] = true
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null and session.player_held_item_ids().get(item_id, false) == false:
		map.give_new_item_to_player(item_id)


## One `item_id` the player carries taken (given away, burnt).
static func _take(session: WorldSessionController, item_id: StringName) -> void:
	if not _recorded.is_empty():
		_recorded["taken"][item_id] = true
	var map: WorldMapController = session.active_map() as WorldMapController
	if map != null:
		map.acts.take_from_player(item_id)


## 关北 done (关北 D): after the 工地 the last step — 卢卡 asked of the ghost and his 会首 — and the
## chapter's mark 关北一章; the seventh chapter opens. Its ledger keys and marks as the chapter writes them.
static func chapter6_done(session: WorldSessionController, raid: bool = true, chased: bool = false) -> void:
	chapter6_site_done(session, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter6/luca", "main.chapter6#done"]:
		_write(state, key)
	for mark: String in ["卢卡说了鬼", "卢卡说了番坊", "关北一章"]:
		_mark(state, mark)


## 番坊 B: in 番坊 after 关北 (`raid`), 卢卡 met at the gate, 安敦 met in his hall and asked of the 铜牒;
## no side taken yet. Its ledger keys and marks as the chapter writes them; the player is not moved.
static func chapter7_told(session: WorldSessionController, raid: bool = true, chased: bool = false) -> void:
	chapter6_done(session, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter7#started", "main.chapter7/fanfang", "main.chapter7/hall", "main.chapter7/tablet_tale"]:
		_write(state, key)
	for mark: String in ["到了番坊", "卢卡在番坊见到你", "见了安敦", "安敦说了铜牒", "安敦提过关北"]:
		_mark(state, mark)


## chapter7_told() and a side taken — the 大秦人's (`rome`: 安敦's 站大秦人) or the 浪人's (早川's 站浪人).
static func chapter7_sided(session: WorldSessionController, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter7_told(session, raid, chased)
	var state: CharacterState = session.player_runtime().state
	_write(state, "main.chapter7/side/rome" if rome else "main.chapter7/side/ronin")
	_mark(state, "站了大秦人" if rome else "站了浪人")


## 番坊 C: the seventh chapter done on one side — the 大秦人's (`rome`: the tablet from the fire, 冯禄 faced
## at the gate) or the 浪人's (早川's 一刀, the tablet stolen by night, the 大秦人 cleared) — and the 铜牒
## read; the chapter's mark 番坊一章 and the eighth chapter's stub open. Its ledger keys and marks as the
## chapter writes them; the player is not moved and holds no tablet.
static func chapter7_done(session: WorldSessionController, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter7_sided(session, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in (["main.chapter7/rome", "main.chapter7/gate"] if rome else ["main.chapter7/ronin", "main.chapter7/theft"]) + ["main.chapter7/read", "main.chapter7#done"]:
		_write(state, key)
	# Not 早川见过你: his "过我一刀" comes on a beat the player may not wait for (the blow taken at once).
	for mark: String in (["火前说了真话", "铜牒到手", "印色对上了", "争地过了", "大秦人留下了", "早川拒了你"] if rome else ["过了一刀", "铜牒到手", "大秦人被清走", "安敦在码头见过你", "卢卡恨了你"]) + ["读过铜牒", "番坊一章"]:
		_mark(state, mark)


## 第八章 done (第八章 A): down the lake, through the cold and the dragons' hall, the pool, 璃虹's
## three questions and the 封法, 商玦's word — and the choice: `pulled`, the sword drawn (the head
## awake, 璃虹 out of the ice), else the seal looked over and her feather taken; the chapter's mark
## 湖底一章 and the ninth chapter's stub open; on the pull ledger the night after too (第八章 B: the three
## bands of 鬼卒 beaten). Its ledger keys and marks as the chapter writes them; the player is not moved and
## holds neither sword nor feather.
static func chapter8_done(session: WorldSessionController, pulled: bool = true, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter7_done(session, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter8/lake", "main.chapter8/cave", "main.chapter8/pool", "main.chapter8/seal", "main.chapter8/choice/pull" if pulled else "main.chapter8/choice/keep"] + (["main.chapter8/night"] if pulled else []) + ["main.chapter8#done"]:
		_write(state, key)
	for mark: String in ["下了湖底", "到了冰龙厅", "看过封坛", "见过璃虹", "璃虹说了封法", "商玦劝过你"] + (["拔了穿灵", "湖畔的鬼卒退了", "村口的鬼卒退了", "稻田的鬼卒退了", "璃虹上岸见过你", "农妇谢过", "农妇问过你"] if pulled else ["查清了封物"]) + ["湖底一章"]:
		_mark(state, mark)


## 第九章 A done (or B, by the well) after 第八章: the way in taken — `way` exam (the 校武场's three bouts, the
## 殿试, the 御前侍卫腰牌 in hand), memorial (骆云舟's 名帖, the 相国's 奏本, the 早朝) — and 福安's word: the
## 养心殿 next (C). Its ledger keys and marks as the chapter writes them.
static func chapter9_entered(session: WorldSessionController, way: String = "exam", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter8_done(session, pulled, rome, raid, chased)
	_chapter9_entered(session, way)


static func _chapter9_entered(session: WorldSessionController, way: String) -> void:
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter9#started", "main.chapter9/way/%s" % way]:
		_write(state, key)
	var marks: Array[String] = []
	match way:
		"exam": marks.assign(["报了武举", "胜了第一场", "胜了第二场", "中了武状元", "葛升说了殿试", "宫门放行", "候了殿试", "进了皇城", "殿试过", "见了福安"])
		"memorial": marks.assign(["骆云舟给了名帖", "相国府开了门", "骆家的名帖敲开了相国府", "相国见了名帖", "相国写了奏本", "随相国上朝", "宫门放行", "进了皇城", "早朝过", "见了福安"])
	for mark: String in marks:
		_mark(state, mark)
	if way == "exam":
		_give(session, &"native:imperial/guard_token")


## 第九章 C done after the 武举 (chapter9_entered): the 养心殿 (见了皇帝), the 樟木匣 and the two decrees compared
## (对出了原令: the 原令, the 兵部抄本 and the woodcutter's page in hand), 卫沧澜 met in the 尚书府 — and, with
## `witness`, his 白衣武官 heard (卫沧澜作证) and his 走 (卫沧澜出了尚书府). The choice (D) next.
static func chapter9_compared(session: WorldSessionController, witness: bool = true, pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter9_entered(session, "exam", pulled, rome, raid, chased)
	_chapter9_compared(session.player_runtime().state, witness)
	_chapter9_things(session)


## What 第九章 C puts in hand: the 樟木匣's 原令, 兵部抄本 and 樵夫的旧记载 (imperial/world.json), 清尘's 迷魂符.
static func _chapter9_things(session: WorldSessionController) -> void:
	for item_id: StringName in [&"native:imperial/original_decree", &"native:imperial/war_ministry_copy", &"native:imperial/woodcutter_record", &"native:city/blinding_charm"]:
		_give(session, item_id)


static func _chapter9_compared(state: CharacterState, witness: bool) -> void:
	for key: String in ["main.chapter9/audience", "main.chapter9/decree"]:
		_write(state, key)
	for mark: String in ["见了皇帝", "皇帝说了槐阳王", "翻过樟木匣", "钟嬷嬷认过字", "对出了原令", "见过卫沧澜", "见过清尘", "小屋的信使倒了"] + (["卫沧澜作证", "卫沧澜出了尚书府"] if witness else []):
		_mark(state, mark)


## 第九章 done (第九章 A–E): in by the 武举, the 养心殿, the 原令 matched — and the choice: `side` expose
## (卫沧澜's witness, 庾子建下狱, 冯策随你下湖), deal (私了: 宋朴传了话, 私了了庾子建) or uncle (the 手诏 carried:
## 皇叔入朝); the chapter's mark 皇城一章 and the tenth chapter opens. Its ledger keys and marks as the chapter
## writes them; the things as the choice leaves them: C's (_chapter9_things), the 原令 burnt for the 先帝的解读 on 私了
## (city/npcs.json 庾子建), the 手诏 given to the 皇叔 on his road (common/npcs.json).
static func chapter9_done(session: WorldSessionController, side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter9_entered(session, "exam", pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	_chapter9_compared(state, side == "expose")
	var keys: Array[String] = ["main.chapter9/choice/%s" % side]
	if side == "uncle":
		keys.append("main.chapter9/uncle_road")
	keys.append("main.chapter9#done")
	for key: String in keys:
		_write(state, key)
	var marks: Array[String] = []
	match side:
		"expose": marks.assign(["要在朝上揭发", "揭发过", "庾子建下狱", "冯策随你下湖"])
		"deal": marks.assign(["宋朴传了话", "私了了庾子建"])
		"uncle": marks.assign(["皇叔的通缉解了", "三选一定了", "皇叔入朝"])
	marks.append("皇城一章")
	for mark: String in marks:
		_mark(state, mark)
	_chapter9_things(session)
	match side:
		"deal":
			_take(session, &"native:imperial/original_decree")
			_give(session, &"native:imperial/late_emperor_reading")
		"uncle":
			_give(session, &"native:imperial/edict_for_uncle")
			_take(session, &"native:imperial/edict_for_uncle")


## 第十章 A done after 第九章 (`side`): the wind read, 伏地 in the hollow it stops in — 到了岚城, up into the
## town at the 白石门; the 风铃阁 next (B). Which route the wind drew is the world's (a suite draws one).
static func chapter10_arrived(session: WorldSessionController, side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter9_done(session, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter10#started", "main.chapter10/wind"]:
		_write(state, key)
	_mark(state, "到了岚城")


## 第十章 B done: up the 白石街 into the 风铃阁, 岚翁's greeting under the bells and 旋芒 asked of him; the
## 云台 next (C).
static func chapter10_asked(session: WorldSessionController, side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter10_arrived(session, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter10/city", "main.chapter10/elder"]:
		_write(state, key)
	_mark(state, "见过岚翁")


## 第十章 done (第十章 A–C): the wind read, 岚翁 asked of 旋芒, and `who` drew it — self (旋芒在你手里: the
## sword not given, the suite gives it), uncle (旋芒在皇叔手里) or xiao (旋芒在萧辟尘手里); 岚城一章, and the
## finale (main.finale) begins on the next journal beat.
static func chapter10_done(session: WorldSessionController, who: String = "self", side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter10_asked(session, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.chapter10/choice/%s" % who, "main.chapter10#done"]:
		_write(state, key)
	var held: Dictionary[String, String] = {"self": "旋芒在你手里", "uncle": "旋芒在皇叔手里", "xiao": "旋芒在萧辟尘手里"}
	for mark: String in [held[who], "岚城一章"] + (["要自己拔旋芒", "接下了接风三刃"] if who == "self" else []):
		_mark(state, mark)


## 终章 A done after 第十章 (`who`, `side`): at the lakeside the 点将 seen, 等到天黑 taken (the 决战前 save
## asked for: 下了决战), out on the boat and the dive (终章下了湖底); the 冰龙厅 next (B). Whether 能灭它 was
## said is the ledger's (a suite's choices); the swords are not given (a suite gives them as its ledger has them).
static func finale_dived(session: WorldSessionController, who: String = "self", side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	chapter10_done(session, who, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.finale#started", "main.finale/lake", "main.finale/gather", "main.finale/shore"]:
		_write(state, key)
	for mark: String in ["点过将", "下了决战", "终章下了湖底"]:
		_mark(state, mark)


## 终章 B fought after the dive: 商玦 down in the 冰龙厅, the pool down to the 封坛 (回到了湖底), 侮天鬼 taken shape
## and down; the last stroke (the end step) next.
static func finale_fought(session: WorldSessionController, who: String = "self", side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	finale_dived(session, who, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.finale/hall", "main.finale/depths", "main.finale/demon"]:
		_write(state, key)
	for mark: String in ["商玦说过", "商玦倒了", "回到了湖底", "侮天鬼成形", "侮天鬼倒了"]:
		_mark(state, mark)


## 终章 B done: the last stroke — `end` slay (侮天鬼灭了) or a seal (seal_elon: 瑷伦留在了冰里, 再封了侮天鬼) — and up
## the pool to the lakeside (终章上了岸); home (C) next.
static func finale_ended(session: WorldSessionController, end: String = "slay", who: String = "self", side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	finale_fought(session, who, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	_write(state, "main.finale/end/%s" % end)
	var stayed: Dictionary[String, String] = {"seal_elon": "瑷伦留在了冰里", "seal_lihong": "璃虹留在了冰里", "seal_nan": "南危水留在了冰里", "seal_xiao": "萧辟尘留在了冰里"}
	for mark: String in (["侮天鬼灭了"] if end == "slay" else [stayed[end], "再封了侮天鬼"]) + (["叫来了瑷伦"] if end == "seal_elon" else []) + ["终章上了岸"]:
		_mark(state, mark)


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
		_mark(state, mark)
	state.affiliation.family_title = "大弟子"


## 封山 A done to the 门房 (替他瞒 unless `revealed`): 柳淳风's word on it (柳淳风说过门房, his reaction
## once 李火狮 has told him) is 封山 B's first beat.
static func fonxan_gated(session: WorldSessionController, revealed: bool = false) -> void:
	fonxan_guarded(session)
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.fonxan/gate/%s" % ("reveal" if revealed else "cover"))
	for mark: String in ["李火狮说了门房", "说破了刘安禄" if revealed else "替刘安禄瞒了"]:
		_mark(state, mark)


## 封山 B's 竹书 fetched and given, to 柳绘心 (`to_daughter`) or to 柳淳风, after his word on the 门房:
## the 内院 is next.
static func fonxan_book_given(session: WorldSessionController, to_daughter: bool) -> void:
	fonxan_gated(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.fonxan/bamboo_hear", "faction.fonxan/bamboo", "faction.fonxan/book/%s" % ("daughter" if to_daughter else "father")]:
		_write(state, key)
	for mark: String in ["柳淳风说过门房", "柳淳风说了推法", "竹书给了柳绘心" if to_daughter else "竹书给了柳淳风"]:
		_mark(state, mark)


## 天邪 A (势力线第一批; DECISIONS「天邪 A」): sworn to 萧辟尘 — 天邪派's seventeenth generation, no class
## (the fighter masters give none).
static func celestial_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.celestial", 17)
	state.apprenticeship.master_teacher_id = &"common.npc.fighter.master"
	state.apprenticeship.legacy_master_name = "萧辟尘"
	var affiliation := CharacterAffiliationState.new()
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


## 天邪 A's 守山 done (`caught`: the spy taken, else gone while the wrong man was held), and told to
## 潘军禅 (大弟子): the 镖单 is next.
static func celestial_watched(session: WorldSessionController, caught: bool = true) -> void:
	celestial_joined(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.celestial#started", "faction.celestial/hear", "faction.celestial/watch", "faction.celestial/report"]:
		_write(state, key)
	for mark: String in ["潘军禅说了山门", "值守回了话"] + (["认出了探子", "拿下了探子"] if caught else ["探子跑了"]):
		_mark(state, mark)
	state.affiliation.family_title = "大弟子"


## 天邪 A's 镖单 settled (`to_chen`: taken to 陈天星, who found the route; else locked in 潘军禅's 刑堂):
## 天邪 B's 盟主的下落 is next.
static func celestial_escorted(session: WorldSessionController, caught: bool = true, to_chen: bool = false) -> void:
	celestial_watched(session, caught)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.celestial/escort/chen", "faction.celestial/trace"] if to_chen else ["faction.celestial/escort/pan"]:
		_write(state, key)
	for mark: String in ["潘军禅说了镖单", "看过镖单"] + (["镖单给了陈天星", "镖路查清了"] if to_chen else ["镖单锁进了刑堂"]):
		_mark(state, mark)


## 天邪 B (势力线第一批; DECISIONS「天邪 B」): the 正厅's split made (`yan`: for 颜违, else for 潘军禅), 执事
## either way. What the main story did (卫沧澜 out of the 尚书府, or the 京师 chapter over) is the caller's.
static func celestial_split(session: WorldSessionController, yan: bool, caught: bool = true, to_chen: bool = false) -> void:
	celestial_escorted(session, caught, to_chen)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.celestial/leader", "faction.celestial/rescue", "faction.celestial/chair", "faction.celestial/split/%s" % ("side_yan" if yan else "side_pan"), "faction.celestial#done"]:
		_write(state, key)
	for mark: String in ["潘军禅说了盟主的下落", "正厅撞见了", "正厅的话说完了", "站了颜违" if yan else "站了潘军禅"]:
		_mark(state, mark)
	state.affiliation.family_title = "执事"


## 卧底 A (势力线第一批; DECISIONS「卧底 A」): 第三章 done and the yes to 林忌 (or 霍铮) given, through the door
## `door`: "xuan" (the chase, the 残卷 back to 玄冥子), "lin" (the chase, the 残卷 burnt by 林忌: 残卷没回宫) or
## "night" (the rescue: 那一夜丢了人, said by 霍铮). The 管事 is next. Crown and 残卷 are the caller's.
static func niling_entered(session: WorldSessionController, door: String) -> void:
	if door == "night":
		chapter3_rescued(session)
	else:
		chapter3_chased(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.niling#started", "faction.niling/gate/%s" % door]:
		_write(state, key)
	var marks: Dictionary = {
		"xuan": ["林忌说了逆灵宫", "答应了做眼线", "残卷给了玄冥子"],
		"lin": ["林忌说了逆灵宫", "答应了做眼线", "林忌烧了残卷", "残卷没回宫"],
		"night": ["答应了做眼线", "林忌请你再进去", "那一夜丢了人"],
	}
	for mark: String in marks[door]:
		_mark(state, mark)


## 卧底 A done (through `door`, niling_entered()): the three chores and the 通铺, `caught` times taken by the 巡殿
## (0–2, each a 疑点), listened at the 北门, the 名单 copied and handed out; the line at its stub `next`
## (逆灵宫 B: the 地牢).
static func niling_delivered(session: WorldSessionController, door: String, caught: int = 0) -> void:
	niling_entered(session, door)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.niling/hire", "faction.niling/chores", "faction.niling/listen", "faction.niling/copy", "faction.niling/deliver"]:
		_write(state, key)
	for mark: String in ["管事派了活", "添过炭", "点过箱", "跟诵过", "管事许你留宿", "后殿外听到了", "抄了名单", "名单递出去了"]:
		_mark(state, mark)
	for mark: String in ["子时在后殿外被撞见", "子时在后殿外又被撞见"].slice(0, clampi(caught, 0, 2)):
		_mark(state, mark)


## 卧底 B (势力线第一批; DECISIONS「卧底 B」): 卧底 A delivered (niling_delivered()), 林忌's word on the dungeon, and the
## three new captives let out (the key however it came; none is left carried). The 名册 is next.
static func niling_cells_emptied(session: WorldSessionController, door: String, caught: int = 0) -> void:
	niling_delivered(session, door, caught)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.niling/word", "faction.niling/cells"]:
		_write(state, key)
	for mark: String in ["林忌说了地牢", "放了槐阳的妇人", "放了货郎", "放了采药人"]:
		_mark(state, mark)


## 卧底 B's 名册 settled: `take`n from the 账房's iron box (名册不见了, a 疑点; the book itself is the caller's) or left
## there and told to 林忌. The 天书 (玄冥子's, where he lives) is next.
static func niling_ledger(session: WorldSessionController, door: String, take: bool, caught: int = 0) -> void:
	niling_cells_emptied(session, door, caught)
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.niling/ledger/%s" % ("take" if take else "leave"))
	_mark(state, "看过名册的原本")
	for mark: String in (["带走了名册", "名册不见了"] if take else ["名册留在了匣里"]):
		_mark(state, mark)


## 卧底 B done (势力线第一批; DECISIONS「卧底 B」「卧底 C」): the 名册 settled (niling_ledger()), then the 天书 — where 玄冥子
## lives on the cliff (the chase: door xuan or lin) fetched for him, his 剑谱 the caller's to give; the rescue routed past.
## 后山的事了了 either way: 收网 is next (逆灵宫 C), once 第十章 is over.
static func niling_scripture(session: WorldSessionController, door: String, take: bool, caught: int = 0) -> void:
	niling_ledger(session, door, take, caught)
	var state: CharacterState = session.player_runtime().state
	var lives: bool = door != "night"
	_write(state, "faction.niling/scripture/%s" % ("book" if lives else "none"))
	for mark: String in (["玄冥子托你取天书", "天书给了玄冥子", "玄冥子要取代商玦", "后山的事了了"] if lives else ["后山的事了了"]):
		_mark(state, mark)


## 东方神教 A (势力线第一批; DECISIONS「东方神教 A」): 朱鸿雪's order taken (令牌 asked, 接令 said yes to); the 西厢
## is next. Whatever came before (a 杀手令牌 carried, 第四章) is the caller's.
static func dongfang_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.dongfang#started")
	for mark: String in ["朱鸿雪说了令牌", "接了朱鸿雪的令"]:
		_mark(state, mark)


## 东方神教 A: 安妮儿 asked what she waits for, and told to 朱鸿雪 as it is (`truth`) or kept for her; the 黑木令 next.
static func dongfang_reported(session: WorldSessionController, truth: bool = true) -> void:
	dongfang_joined(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.dongfang/west", "faction.dongfang/report/%s" % ("truth" if truth else "cover")]:
		_write(state, key)
	for mark: String in ["安妮儿说了等谁", "如实回报了" if truth else "替安妮儿瞒了"]:
		_mark(state, mark)


## 东方神教 A done: the dead man's 黑木令 from the reeds, shown 朱鸿雪 and carried (持黑木令); the line at its stub
## `names` (东方神教 B: 三个名字).
static func dongfang_held(session: WorldSessionController, truth: bool = true) -> void:
	dongfang_reported(session, truth)
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.dongfang/token")
	for mark: String in ["芦苇丛的鬼卒退了", "取了黑木令", "持黑木令"]:
		_mark(state, mark)
	_give(session, &"es2:d/latemoon/room/npc/obj/token")


## 东方神教 B: 朱鸿雪 asked「差事」: the three names (朱鸿雪说了三个名字).
static func dongfang_named(session: WorldSessionController, truth: bool = true) -> void:
	dongfang_held(session, truth)
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.dongfang/names")
	_mark(state, "朱鸿雪说了三个名字")


## 东方神教 B: the three names done (the 道士 and the 画吏 beaten; the old ice cutter `killed`, or talked into
## leaving) and 交差: the 黑木令 taken back for the 赤铜令 (持赤铜令). The 场院's last name next.
static func dongfang_coppered(session: WorldSessionController, truth: bool = true, killed: bool = true) -> void:
	dongfang_named(session, truth)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.dongfang/three", "faction.dongfang/icer/%s" % ("do" if killed else "spare"), "faction.dongfang/copper"]:
		_write(state, key)
	for mark: String in ["量水的道士倒了", "兵部画吏倒了", "杀了老冰匠" if killed else "劝老冰匠搬走了", "持赤铜令"]:
		_mark(state, mark)
	_take(session, &"es2:d/latemoon/room/npc/obj/token")
	_give(session, &"native:cloud/copper_token")


## 东方神教 B done: the 场院's scene seen and one side taken (`annie`: 站了安妮儿, else 站了朱鸿雪); the 黄金令牌
## for the 赤铜令.
static func dongfang_split(session: WorldSessionController, annie: bool, truth: bool = true, killed: bool = true) -> void:
	dongfang_coppered(session, truth, killed)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.dongfang/list", "faction.dongfang/split/%s" % ("side_annie" if annie else "side_zhu"), "faction.dongfang#done"]:
		_write(state, key)
	for mark: String in ["场院里两位教主", "场院的话说完了", "站了安妮儿" if annie else "站了朱鸿雪"]:
		_mark(state, mark)
	if not truth and not killed:
		_mark(state, "朱鸿雪揭穿了冰凿")
	_take(session, &"native:cloud/copper_token")
	_give(session, &"es2:d/latemoon/room/npc/obj/gold_token")


## 终章 done (终章 C): after 终章 B's `end` (finale_ended) home to the 雪亭镇 inn — 宣过诏 and 终章; the main story is over
## and 大会's `invite` (the 店小二's 请柬) is next.
static func finale_done(session: WorldSessionController, end: String = "slay", who: String = "self", side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	finale_ended(session, end, who, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["main.finale/home", "main.finale#done"]:
		_write(state, key)
	for mark: String in ["宣过诏", "终章"]:
		_mark(state, mark)


## 大会 B (DECISIONS「大会 B」): the main story over (finale_done), the 虹台 invitation in hand (拿了虹台请柬) and the
## 大会 quest on to its canvass; `marks` the lines' and the canvass' marks as a suite wants them. 入席 next.
static func assembly_invited(session: WorldSessionController, end: String = "slay", marks: Array = [], who: String = "self", side: String = "expose", pulled: bool = false, rome: bool = true, raid: bool = true, chased: bool = false) -> void:
	finale_done(session, end, who, side, pulled, rome, raid, chased)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.assembly#started", "faction.assembly/wait", "faction.assembly/invite"]:
		_write(state, key)
	for mark: String in ["拿了虹台请柬"] + marks:
		_mark(state, mark)
	_give(session, &"native:waterfog/assembly_invitation")


## 振远 A (势力线第二批; DECISIONS「振远 A」): 拜了陈天星 (陈剑秋's letter given): 振远镖局第一代弟子.
static func zhenyuan_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.zhenyuan", 1)
	state.apprenticeship.master_teacher_id = &"city.npc.chen"
	state.apprenticeship.legacy_master_name = "陈天星"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"guardman"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


static func _zhenyuan(state: CharacterState) -> bool:
	return state.family != null and state.family.family_id == &"family.zhenyuan"


## 振远 A: the line begun (the 镖单 seen, or 振远's own) and 陈剑秋's 镖 taken;
## 老周 and his barrow wait in the 绮云 镖局 for「上路」.
static func zhenyuan_taken(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	if not _zhenyuan(state):
		_mark(state, "看过镖单")
	for key: String in ["faction.zhenyuan#started", "faction.zhenyuan/take"]:
		_write(state, key)
	for mark: String in ["陈剑秋说了走镖", "接了振远的镖"]:
		_mark(state, mark)
	if _zhenyuan(state):
		_mark(state, "以本局弟子走镖")


## 振远 A: the 镖 in 京师 — the robber on the 碎石小路 beaten and handed to the 官府 (`free` false) or let go with
## his father's letter (`free`); 振远's card in hand, 镖头 for 振远's own. The letter (free) is still the player's
## unless `letter` is false (振远 B: it went to 陈天星).
static func zhenyuan_delivered(session: WorldSessionController, free: bool = false, letter: bool = true) -> void:
	zhenyuan_taken(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.zhenyuan/road", "faction.zhenyuan/robber/%s" % ("free" if free else "hand"), "faction.zhenyuan/deliver"]:
		_write(state, key)
	for mark: String in ["镖车上了路", "见过劫镖", "劫镖的后生倒了", "放走了劫镖的" if free else "劫镖的交了官", "有振远的名帖", "镖交到了总局"]:
		_mark(state, mark)
	if _zhenyuan(state):
		state.affiliation.family_title = "镖头"
	_give(session, &"native:city/zhenyuan_card")
	if free and letter:
		_give(session, &"native:city/he_letter")


## 振远 B (势力线第二批; DECISIONS「振远 B」): the 镖 delivered (`free`: the letter given to 陈天星, 镖路查清了),
## 陈天星's 旧账 and 陈剑秋's answer heard, the split made — 到此为止 (`stop`) or 查到底 (the 镖路 known by it); the line done.
static func zhenyuan_settled(session: WorldSessionController, stop: bool = true, free: bool = false) -> void:
	zhenyuan_delivered(session, free, false)
	var state: CharacterState = session.player_runtime().state
	var keys: Array[String] = []
	var marks: Array[String] = []
	if free:
		keys.append("faction.zhenyuan/letter")
		marks.append_array(["家信给了陈天星", "镖路查清了"])
	keys.append_array(["faction.zhenyuan/ledger", "faction.zhenyuan/uncle", "faction.zhenyuan/books/%s" % ("stop" if stop else "dig"), "faction.zhenyuan#done"])
	marks.append_array(["陈天星说了旧账", "陈剑秋说了抚恤银", "振远旧账到此为止" if stop else "振远旧账查到底"])
	if not stop:
		marks.append("镖路查清了")
	for key: String in keys:
		_write(state, key)
	for mark: String in marks:
		_mark(state, mark)


## 晚月 A (势力线第二批; DECISIONS「晚月 A」): 拜了蓝止萍: 晚月庄第二代弟子.
## 茅山 A (TEST-ONLY): 拜了林忌 (茅山第六代弟子).
static func maoshan_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.maoshan", 6)
	state.apprenticeship.master_teacher_id = &"common.npc.taoist.taolord"
	state.apprenticeship.legacy_master_name = "林忌"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"taoist"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


## 茅山 A (势力线第三批; DECISIONS「茅山 A」): the line walked to the 《上清符箓》 in hand — 林忌's own (侍者, maoshan_joined
## first) or a friend of 茅山 (the 花匠's 林忌 heard). 茅山 B's `home` next: the book given to 林忌.
static func maoshan_booked(session: WorldSessionController, disciple: bool = false) -> void:
	var state: CharacterState = session.player_runtime().state
	if disciple:
		maoshan_joined(session)
		state.affiliation.family_title = "侍者"
	var marks: Array[String] = ["看过师弟的字条", "林忌说了师弟", "花匠说了来历", "花匠交了符箓"]
	if not disciple:
		marks.append_array(["花匠说了师兄", "茅山的朋友", "林忌许你上藏经楼"])
	for mark: String in marks:
		_mark(state, mark)
	for key: String in ["faction.maoshan#started", "faction.maoshan/library", "faction.maoshan/brother", "faction.maoshan/gardener", "faction.maoshan/book"]:
		_write(state, key)
	_give(session, &"native:temple/talisman_book")


## 茅山 B (势力线第三批; DECISIONS「茅山 B」): the book given to 林忌, the 花匠 come up and the scene in the 大殿 seen, the
## split taken before one sat on the 虹台 (`burn` with 林忌, else 留 with the 花匠); the 北麓's 余孽 next, after the 终章.
static func maoshan_split(session: WorldSessionController, burn: bool = true, disciple: bool = false) -> void:
	var state: CharacterState = session.player_runtime().state
	if disciple:
		maoshan_joined(session)
	for mark: String in ["看过师弟的字条", "林忌说了师弟", "花匠说了来历", "花匠交了符箓", "林忌看了符箓", "师兄弟见了面", "师兄弟说完了话"]:
		_mark(state, mark)
	if not disciple:
		for mark: String in ["花匠说了师兄", "茅山的朋友", "林忌许你上藏经楼"]:
			_mark(state, mark)
	for mark: String in (["茅山烧了符箓", "茅山的票随了林忌"] if burn else ["茅山收了符箓", "茅山的票随了花匠"]):
		_mark(state, mark)
	for key: String in ["faction.maoshan#started", "faction.maoshan/library", "faction.maoshan/brother", "faction.maoshan/gardener", "faction.maoshan/book", "faction.maoshan/home", "faction.maoshan/meet", "faction.maoshan/split/%s" % ("burn" if burn else "keep")]:
		_write(state, key)
	if disciple:
		state.affiliation.family_title = "护法"


## 步玄 (势力线第三批): 骆云舟's own — knelt to him (弟子; 大弟子 after the 问剑).
static func buxuan_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.buxuan", 8)
	state.apprenticeship.master_teacher_id = &"common.npc.scholar.master"
	state.apprenticeship.legacy_master_name = "骆云舟"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"scholar"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


## 步玄 A (DECISIONS「步玄 A」): the line walked to 骆建章's word on the 兵部抄本 — 骆云舟's own (大弟子, buxuan_joined first)
## or a 桃林的客; 第九章 begun (湖底一章), its outcome left to the caller. 步玄 B's `home` next: tell 骆云舟.
static func buxuan_copied(session: WorldSessionController, disciple: bool = false) -> void:
	var state: CharacterState = session.player_runtime().state
	if disciple:
		buxuan_joined(session)
		state.affiliation.family_title = "大弟子"
	else:
		for mark: String in ["桃林", "桃林的客"]:
			_mark(state, mark)
	for mark: String in ["湖底一章", "骆云舟说了风泉", "骆云舟插了剑", "问剑过了", "骆云舟托了家书", "骆建章读了家书", "骆建章说了抄本"]:
		_mark(state, mark)
	for key: String in ["faction.buxuan#started", "faction.buxuan/sword", "faction.buxuan/letter", "faction.buxuan/brother", "faction.buxuan/copy"]:
		_write(state, key)


## 步玄 B (DECISIONS「步玄 B」): buxuan_copied, 骆云舟 told, the brothers met in the 相国府, and the split taken before one
## sat on the 虹台 — 作证 (`testify`: the 供状; what else it wrote by 第九章's end is the caller's) or 回家 (骆家 kept).
static func buxuan_split(session: WorldSessionController, testify: bool = true, disciple: bool = false) -> void:
	buxuan_copied(session, disciple)
	var state: CharacterState = session.player_runtime().state
	for mark: String in ["骆云舟听了抄本的事", "骆家兄弟见了面", "骆家兄弟说完了话"]:
		_mark(state, mark)
	for mark: String in (["骆建章作了证", "步玄的票随了作证"] if testify else ["保住了骆家", "步玄的票随了骆家"]):
		_mark(state, mark)
	for key: String in ["faction.buxuan/home", "faction.buxuan/meet", "faction.buxuan/split/%s" % ("testify" if testify else "home")]:
		_write(state, key)
	if disciple:
		state.affiliation.family_title = "执事"

static func latemoon_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.latemoon", 2)
	state.apprenticeship.master_teacher_id = &"common.npc.dancer.master"
	state.apprenticeship.legacy_master_name = "蓝止萍"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"dancer"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


## 晚月 A: one not of 晚月庄 who stood 瑷伦's three lashes and saw the 宝衣 through (第四章, done by the caller)
## asked 蓝止萍「护法」: 晚月庄护法.
static func latemoon_guardian(session: WorldSessionController) -> void:
	_mark(session.player_runtime().state, "晚月庄护法")
	(session.player_runtime() as WorldPlayerRuntimeState).take_title("晚月庄护法")


## 晚月 A: the line begun (晚月庄's own, or a 护法), 蓝止萍's 庄里的事 heard, the 图 seen and the 谱 in hand, 沧海龙吟
## danced before 区冥 (大弟子 for 晚月庄's own); the 宝衣 next.
static func latemoon_danced(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.latemoon#started", "faction.latemoon/lost", "faction.latemoon/score", "faction.latemoon/shrine"]:
		_write(state, key)
	for mark: String in ["蓝止萍说了沧海龙吟", "看过沧海龙吟图", "沧海龙吟的步子", "跳成了沧海龙吟"]:
		_mark(state, mark)
	if state.family != null and state.family.family_id == &"family.latemoon":
		state.affiliation.family_title = "大弟子"
	_give(session, &"es2:d/latemoon/obj/book")


## 晚月 A: after the dance, the 宝衣 settled as 第四章 left it (chapter4_kept / chapter4_taken, called first): left
## with 瑷伦 (kept), or carried out and brought home (`home`) or kept on the player; the 老妇's 心事 next (晚月 B).
static func latemoon_robe_settled(session: WorldSessionController, home: bool = true) -> void:
	latemoon_danced(session)
	var state: CharacterState = session.player_runtime().state
	_mark(state, "该问老妇心事")
	if state.marks.has("瑷伦守到决战"):
		_write(state, "faction.latemoon/robe_way/kept")
		return
	_write(state, "faction.latemoon/robe_way/carried")
	_write(state, "faction.latemoon/robe/%s" % ("home" if home else "keep"))
	for mark: String in ["该问瑷伦还衣", "宝衣回了庄" if home else "宝衣留在了身上"]:
		_mark(state, mark)
	if home:
		_take(session, &"native:latemoon/cold_robe")


## 晚月 B: after the 宝衣 (latemoon_robe_settled, called first), the 老妇's 心事 heard and her daughter found — in the
## 内书房 with no night, in the bamboo grove after it — and her story told; her 令牌 in hand.
static func latemoon_told(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var night: bool = not state.marks.has("瑷伦守到决战")
	for key: String in ["faction.latemoon/heart", "faction.latemoon/where/%s" % ("grove" if night else "study"), "faction.latemoon/find_%s" % ("grove" if night else "study")]:
		_write(state, key)
	for mark: String in ["老妇说了女儿", "她说了来历"]:
		_mark(state, mark)
	_give(session, &"es2:d/latemoon/room/npc/obj/token")


## 晚月 B: her 令牌 given to her mother (`mother`: the thanks too, once) or returned to 朱鸿雪 (latemoon_told first).
static func latemoon_token(session: WorldSessionController, mother: bool = true) -> void:
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.latemoon/token/%s" % ("mother" if mother else "cult"))
	for mark: String in (["令牌给了老妇", "老妇谢过令牌"] if mother else ["令牌还了神教"]):
		_mark(state, mark)
	_take(session, &"es2:d/latemoon/room/npc/obj/token")


## 晚月 B: the split in the 大厅 (latemoon_token first): 庄规 (`rule`) or her mother's daughter; 执事 for 晚月庄's own;
## the line done.
static func latemoon_settled(session: WorldSessionController, rule: bool = true) -> void:
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.latemoon/split/%s" % ("by_rule" if rule else "brought_home"), "faction.latemoon#done"]:
		_write(state, key)
	for mark: String in ["大厅说起了庄规"] + (["晚月庄依了庄规", "晚月庄的票随了庄规"] if rule else ["她回了晚月庄", "晚月庄的票随了她"]):
		_mark(state, mark)
	if state.family != null and state.family.family_id == &"family.latemoon":
		state.affiliation.family_title = "执事"


## 花紫会 A (势力线第二批; DECISIONS「花紫会 A」): 拜了陆得财: 花紫会第五代弟子.
static func huazi_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.family = FamilyState.new(&"family.huazi", 5)
	state.apprenticeship.master_teacher_id = &"common.npc.beggar.master"
	state.apprenticeship.legacy_master_name = "陆得财"
	var affiliation := CharacterAffiliationState.new()
	affiliation.class_id = &"beggar"
	affiliation.has_family_rank = true
	affiliation.family_title = "弟子"
	affiliation.entry_time_status = CharacterAffiliationState.EntryTime.RECORDED
	state.affiliation = affiliation


static func _huazi(state: CharacterState) -> bool:
	return state.family != null and state.family.family_id == &"family.huazi"


## 花紫会 A: the line begun (the 县衙's drum beaten, or 花紫会's own), 陆得财's 差事 asked, the 卖身契 stolen and handed
## to him (五结弟子 for 花紫会's own); he said he is a stand-in. The 雪亭 one next.
static func huazi_returned(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	if not _huazi(state):
		_mark(state, "击了鼓")
	for key: String in ["faction.huazi#started", "faction.huazi/errand", "faction.huazi/steal", "faction.huazi/deeds"]:
		_write(state, key)
	for mark: String in ["陆得财说了差事", "卖身契还了", "陆得财说了替身"]:
		_mark(state, mark)
	if _huazi(state):
		state.affiliation.family_title = "五结弟子"


## 花紫会 A: the knots counted (huazi_returned first): 雪亭's, 绮云's and the 真龙头 below the 尚书府's back wall,
## who asked for the 密信. The letter next.
static func huazi_found(session: WorldSessionController) -> void:
	huazi_returned(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.huazi/snow", "faction.huazi/cloud", "faction.huazi/head"]:
		_write(state, key)
	for mark: String in ["雪亭的替身指了路", "绮云的替身指了路", "见了真龙头", "真龙头要密信"]:
		_mark(state, mark)


## 花紫会 A: the 小屋's 密信 given to the 真龙头 (huazi_found first; the letter is no longer the player's). The stub
## `rescue` next (花紫会 B).
static func huazi_letter(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.huazi/letter/huazi")
	_mark(state, "密信给了花紫会")
	_take(session, &"native:city/courier_letter")


## 花紫会 B (势力线第二批; DECISIONS「花紫会 B」): 卫沧澜 out of the 尚书府 (huazi_letter first): stolen through the 狗洞 by
## night (`stolen`), or already out by another way and the 真龙头 told (a word). The split on 福林大街 next.
static func huazi_rescued(session: WorldSessionController, stolen: bool = true) -> void:
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.huazi/rescue/%s" % ("stolen" if stolen else "out"))
	var marks: Array[String] = ["卫沧澜出了尚书府"]
	if stolen:
		marks.append_array(["真龙头说了狗洞", "钻了尚书府的狗洞", "见过卫沧澜", "花紫会偷出了卫沧澜"])
	else:
		marks.append("真龙头说了盟主")
	for mark: String in marks:
		_mark(state, mark)


## 花紫会 B: the split on 福林大街 (huazi_rescued first; taken before the 虹台): 认了二十三个结 (`knots`: the caught
## steals wiped) or 认了管事的陆得财; 九结弟子 for 花紫会's own; the line done.
static func huazi_settled(session: WorldSessionController, knots: bool = true) -> void:
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.huazi/split/%s" % ("knots" if knots else "manager"), "faction.huazi#done"]:
		_write(state, key)
	var marks: Array[String] = ["福林大街碰了面", "两个陆得财说完了话"]
	marks.append_array(["认了二十三个结", "花紫会的票随了真龙头"] if knots else ["认了管事的陆得财", "花紫会的票随了陆得财"])
	for mark: String in marks:
		_mark(state, mark)
	if knots:
		CrimeRecord.add_thief(state, -CrimeRecord.thief(state))
	if _huazi(state):
		state.affiliation.family_title = "九结弟子"


## 官府 A (势力线第二批; DECISIONS「官府 A」): 程不平 wrote his letter (第五章) and made the player his 捕快 — asked
## 「捕快」, the 腰牌 in hand. The two men collecting the toll next.
static func court_joined(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_mark(state, "程不平写了信")
	for key: String in ["faction.court#started", "faction.court/badge"]:
		_write(state, key)
	_mark(state, "做了乔阴捕快")
	_give(session, &"native:choyin/constable_badge")


## 官府 A: both men beaten (court_joined first), each dropping a 叠 of 路引 — picked up, one carried here. 程不平's
## 「路引」 next.
static func court_tolls(session: WorldSessionController) -> void:
	court_joined(session)
	var state: CharacterState = session.player_runtime().state
	for key: String in ["faction.court/toll_snow", "faction.court/toll_cloud"]:
		_write(state, key)
	for mark: String in ["雪亭路口收钱的倒了", "绮云镇口收钱的倒了"]:
		_mark(state, mark)
	_give(session, &"native:canyon/road_passes")


## 官府 A: 程不平 read the 路引 (court_tolls first): 天驼关's seal. The stub `seal` next (官府 B).
static func court_reported(session: WorldSessionController) -> void:
	court_tolls(session)
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.court/passes")
	_mark(state, "程不平看了路引")


## 官府 B (势力线第二批; DECISIONS「官府 B」): 严廷殷 owned the seal on the 路引, 李信 told his ledger of the three days
## and 赫造基 owned the stamping (court_reported first; 第六章's way into the camp, the letter and the 拓模 written too).
## The split next.
static func court_admitted(session: WorldSessionController) -> void:
	court_reported(session)
	var state: CharacterState = session.player_runtime().state
	for mark: String in ["军营", "严廷殷看了信", "赫造基说了拓模"]:
		_mark(state, mark)
	for key: String in ["faction.court/seal", "faction.court/ledger", "faction.court/adviser"]:
		_write(state, key)
	for mark: String in ["严廷殷认了路引", "李信说了那三天的账", "赫造基认了盖印"]:
		_mark(state, mark)


## 官府 B: the split at 天驼关 (court_admitted first): 整肃 with 严廷殷 (`purge`: the 军师 taken in the camp too, the
## 铁卫营 a band at the lake) or 揭发 with 李信. The 卫沧澜 route next.
static func court_split(session: WorldSessionController, purge: bool = true) -> void:
	var state: CharacterState = session.player_runtime().state
	_write(state, "faction.court/split/%s" % ("purge" if purge else "expose"))
	if purge:
		_write(state, "faction.court/arrest")
		for mark: String in ["跟严廷殷整肃", "赫造基被拿下了"]:
			_mark(state, mark)
	else:
		_mark(state, "跟李信揭发")


## 山烟寺 A (势力线第三批; DECISIONS「山烟寺 A」): one not of 山烟寺 asked by the 药僧 to help in the 流云轩 (流云轩的帮手:
## the line begins on the next journal beat). The 方子 is next.
static func sanyen_helper(session: WorldSessionController) -> void:
	_mark(session.player_runtime().state, "流云轩的帮手")


## 山烟寺 A done: the 方子, the three herbs (附子, 麝香, the 树王坟's 鬼臼), the 药 brewed and fed, the 头陀's word on the
## sick man, and the choice — `heal` (头陀进了流云轩, the rule broken) or 照寺规 (守了寺规); 听说了番坊的经 either way.
## 山烟寺 B's `west` (龙若 in 番坊) next.
static func sanyen_treated(session: WorldSessionController, heal: bool = true) -> void:
	var state: CharacterState = session.player_runtime().state
	if state.family == null or state.family.family_id != &"family.sanyen":
		sanyen_helper(session)
	for key: String in ["faction.sanyen#started", "faction.sanyen/rx", "faction.sanyen/field", "faction.sanyen/shop", "faction.sanyen/tomb", "faction.sanyen/brew", "faction.sanyen/feed", "faction.sanyen/monk/%s" % ("heal" if heal else "rule")]:
		_write(state, key)
	for mark: String in ["玄智开了方子", "采了附子", "杨掌柜给了麝香", "采了鬼臼", "药僧煎好了药", "喂了樵夫药", "头陀说了病人"] + (["头陀跟你去了流云轩", "头陀进了流云轩", "不守寺规", "老葛谢过你"] if heal else ["守了寺规"]) + ["听说了番坊的经"]:
		_mark(state, mark)


## 绝尘 A (势力线第三批; DECISIONS「绝尘 A」): out of the 八卦阵 and owned by 绝尘子 as a guest (过阵的客): the line begins
## on the next journal beat (the 村长's 山洞 once 第四章 is done).
static func juechen_guest(session: WorldSessionController) -> void:
	for mark: String in ["走出了八卦阵", "过阵的客"]:
		_mark(session.player_runtime().state, mark)
