class_name ChapterStart
extends RefCounted

## Dev only, opt-in (tests/ never reaches a release; nothing here is an autoload): a New Game
## session set up as the main story leaves a player at the start of a chapter, for the owner's
## playtest of that chapter without playing the ones before it (ROADMAP「After the grey box」
## step 1; BUILD.md「试玩一轮」) — or after the finale, and at a step of a faction line. apply() writes,
## on the session New Game made:
## - the main story's state up to the chapter, by the chapter fixtures the story suites use
##   (tests/support/story_fixtures.gd: ledger keys, marks, milestones, people met, and the things
##   they leave in hand), on the branch chosen where it changes what is there (Spec); a faction line's
##   state up to its step by the line's fixtures, when one is chosen (LINES);
## - the things the chapters before it put in hand that the fixtures leave out (carried());
## - the world as those chapters leave it: people the story knocked down or sent away gone, quest
##   things already picked up gone from where they lay (clear_stage(), from the data: StoryReads);
## - the character grown to the chapter's arrival exp (tests/support/story_arrival.gd, the story's
##   历练) by the game's own rules (tests/support/grown_character.gd: 封山剑法 with a sword in hand,
##   or 柳家拳 bare-handed), with what that exp was paid for written down as paid (no first visit
##   or quest pays twice), and a little silver for the road;
## - the player at the chapter's first step (START: its place, beside its person) — or at the faction
##   line's next step — and the journal told, so the chapter opens as it would.
## Only states a player can reach are made (Spec.problems(): 旋芒 in the 皇叔's hands only after he came to court, drawn
## yourself only with six bells ringing, a faction step only from its chapter; the panel corrects a pick and says so,
## the command line refuses). Then the normal game goes on: a save made afterwards is an ordinary save. No
## save file is read: the world revision changes too often for a kept one. The F6 scene
## (tests/dev/chapter_start.tscn) and the command line (tests/dev/chapter_start/run_chapter_start.gd)
## both start a New Game with it; tests/runtime/chapter_start_test.gd and its siblings prove every start.

const Fixtures := preload("res://tests/support/story_fixtures.gd")
const Grown := preload("res://tests/support/grown_character.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const Places := preload("res://tests/support/map_places.gd")
const Reads := preload("res://tests/support/story_reads.gd")

## The sword of the sword build (as the fight sim and the 试战台 hold it).
const SWORD: StringName = &"es2:obj/longsword"
## Pocket money for a chapter start: fares and a meal, not a rule of the game.
const SILVER: int = 30

## The chapters in story order: the quest, the key the command line takes, and where its first step
## is played from — `zone` (a free spot in it), beside `near` (one of the step's people) when given.
## The place is the step's own target, except where arriving there would already do the step or skip
## its point: 第六章 starts outside the 军营 (getting into it is the step), 第十章 just through the
## 石林's mirror (reading the wind is the step), 终章 on the road beside the lake (reaching it is the step).
## The last, 终章之后 (`after`), is the main story over: the 虹台大会's quest at its `step` (the 店小二's 请柬),
## where every faction line's last steps are played from.
const START: Array[Dictionary] = [
	{"quest": &"main.prologue", "key": "prologue"},
	{"quest": &"main.chapter1", "key": "1", "zone": &"oldpine.outdoor.pine_entrance"},
	{"quest": &"main.chapter2", "key": "2", "zone": &"snow.schoolhall", "near": &"common.npc.swordsman.master"},
	{"quest": &"main.chapter3", "key": "3", "zone": &"goathill.temple1", "near": &"goathill.npc.bandit_hwang"},
	{"quest": &"main.chapter4", "key": "4", "zone": &"waterfog.forehall", "near": &"waterfog.npc.elder5"},
	{"quest": &"main.chapter5", "key": "5", "zone": &"choyin.court1"},
	{"quest": &"main.chapter6", "key": "6", "zone": &"canyon.canyon4"},
	{"quest": &"main.chapter7", "key": "7", "zone": &"village.valley1"},
	{"quest": &"main.chapter8", "key": "8", "zone": &"village.lakeside"},
	{"quest": &"main.chapter9", "key": "9", "zone": &"city.wumen"},
	{"quest": &"main.chapter10", "key": "10", "zone": &"lancheng.huanying"},
	{"quest": &"main.finale", "key": "finale", "zone": &"village.road7"},
	{"quest": &"faction.assembly", "key": "after", "title": "终章之后", "after": true, "step": &"invite", "zone": &"snow.inn.main_floor", "near": &"snow.npc.waiter"},
]

## The faction lines a start can stand in (one at a time): the line's quest and, per stage, what has been
## played (the line's fixture in tests/support/story_fixtures.gd, _write_line), its step next (`next`), and
## the first start it can be had from (`from`: the main story the stage needs). Each STATUS 待试玩 row of a
## line names the stage its first beat is played from.
const LINES: Array[Dictionary] = [
	{"key": "fonxan", "quest": &"faction.fonxan", "title": "封山", "stages": [
		{"key": "join", "title": "刚拜柳淳风（守馆）", "next": &"hear", "from": &"main.chapter1"},
		{"key": "gate", "title": "门房说过了（竹书）", "next": &"bamboo_hear", "from": &"main.chapter1"},
	]},
	{"key": "celestial", "quest": &"faction.celestial", "title": "天邪", "stages": [
		{"key": "join", "title": "刚拜萧辟尘（守山）", "next": &"hear", "from": &"main.chapter1"},
		{"key": "escort", "title": "镖单锁进刑堂（盟主的下落）", "next": &"leader", "from": &"main.chapter3"},
	]},
	{"key": "dongfang", "quest": &"faction.dongfang", "title": "东方神教", "stages": [
		{"key": "join", "title": "接了朱鸿雪的令（西厢）", "next": &"west", "from": &"main.chapter5"},
		{"key": "names", "title": "黑木令在手（三个名字）", "next": &"names", "from": &"main.chapter5"},
	]},
	{"key": "niling", "quest": &"faction.niling", "title": "卧底", "stages": [
		{"key": "enter", "title": "答应了做眼线（管事）", "next": &"hire", "from": &"main.chapter4"},
		{"key": "word", "title": "名单递出去了（地牢）", "next": &"word", "from": &"main.chapter4"},
		{"key": "net", "title": "后山的事了了（收网）", "next": &"hour", "from": &"faction.assembly"},
	]},
	{"key": "zhenyuan", "quest": &"faction.zhenyuan", "title": "振远", "stages": [
		{"key": "take", "title": "接了镖（上路）", "next": &"road", "from": &"main.chapter3"},
		{"key": "deliver", "title": "镖交到了总局（旧账）", "next": &"ledger", "from": &"main.chapter3"},
	]},
	{"key": "latemoon", "quest": &"faction.latemoon", "title": "晚月", "stages": [
		{"key": "guard", "title": "做了护法（庄里的事）", "next": &"lost", "from": &"main.chapter5"},
		{"key": "robe", "title": "宝衣了了（老妇的心事）", "next": &"heart", "from": &"main.chapter5"},
	]},
	{"key": "huazi", "quest": &"faction.huazi", "title": "花紫会", "stages": [
		{"key": "drum", "title": "击过鼓（陆得财的差事）", "next": &"errand", "from": &"main.chapter6"},
		{"key": "letter", "title": "密信给了真龙头（卫沧澜）", "next": &"rescue", "from": &"main.chapter6"},
	]},
	{"key": "court", "quest": &"faction.court", "title": "官府", "stages": [
		{"key": "badge", "title": "做了捕快（收钱的两个人）", "next": &"toll_snow", "from": &"main.chapter6"},
		{"key": "seal", "title": "程不平看了路引（天驼关的印）", "next": &"seal", "from": &"main.chapter6"},
	]},
	{"key": "maoshan", "quest": &"faction.maoshan", "title": "茅山", "stages": [
		{"key": "book", "title": "符箓到手（交给林忌）", "next": &"home", "from": &"main.chapter4"},
	]},
	{"key": "buxuan", "quest": &"faction.buxuan", "title": "步玄", "stages": [
		{"key": "guest", "title": "桃林的客（问剑）", "next": &"sword", "from": &"main.chapter6"},
		{"key": "copy", "title": "骆建章认了抄本（告诉骆云舟）", "next": &"home", "from": &"main.chapter9"},
	]},
	{"key": "sanyen", "quest": &"faction.sanyen", "title": "山烟寺", "stages": [
		{"key": "help", "title": "流云轩的帮手（方子）", "next": &"rx", "from": &"main.chapter6"},
		{"key": "west", "title": "樵夫治过了（番坊的经）", "next": &"west", "from": &"main.chapter8"},
	]},
	{"key": "juechen", "quest": &"faction.juechen", "title": "绝尘", "stages": [
		{"key": "guest", "title": "过了八卦阵（村长的山洞）", "next": &"elder", "from": &"main.chapter5"},
	]},
]

## Quest things the chapters before a start leave in hand that their fixtures do not give (the fixtures give what each
## chapter's own play leaves: 第三章's 账册, 兵部文书 and key, 第五章's papers and 桃木箱, 第九章's 原令 / 抄本 / 记载 as the
## choice leaves them; StoryFixtures.missing_after_play checks them against the played suites both ways):
## - 穿灵 drawn, or 璃虹的羽 given for looking (第八章): the 封坛's 三器 in 终章 (the suites give them as their ledger has them).
## - 密信: the 尚书府 小屋's (第九章 C; its courier down on the way, 小屋的信使倒了), the third proof a 揭发 needs on the chase's
##   road after 踏平了工地 (卫沧澜 and the 账册 are two; 陈显祖 was let go); the 揭发 reads it and leaves it.
## - 旋芒 from the 云台 (第十章, when the player drew it).
const PAPERS: StringName = &"native:niling/war_ministry_papers"
const IMPALER: StringName = &"native:village/soul_impaler"
const FEATHER: StringName = &"native:village/lihong_feather"
const XUANMANG: StringName = &"native:lancheng/xuanmang"
const ORIGINAL: StringName = &"native:imperial/original_decree"
const COPY: StringName = &"native:imperial/war_ministry_copy"
const RECORD: StringName = &"native:imperial/woodcutter_record"
const READING: StringName = &"native:imperial/late_emperor_reading"
const LETTER: StringName = &"native:city/courier_letter"
## The 黑冠 林忌 gives the 卧底 (common/npcs.json): worn, 逆灵宫's people take one for their own.
const CROWN: StringName = &"native:niling/black_crown"


## The choices a start is made with. Each applies only from the chapter it changes on.
class Spec:
	extends RefCounted
	## The chapter: a quest id from START.
	var quest: StringName = &"main.chapter1"
	## 封山剑法 with a sword in hand, else 柳家拳 bare-handed (GrownCharacter's two builds).
	var sword: bool = true
	## The arrival exp of a player who explores on the side (StoryArrival.exploring), else of one
	## who follows the main story alone.
	var exploring: bool = false
	var gender: StringName = CharacterState.GENDER_FEMALE
	## 第三章 ended by the chase (玄冥子 down; then 宝衣 taken, 陈显祖 let go), else by the rescue. From 第四章.
	var chased: bool = false
	## 第六章: the 工地 taken with the 王府's riders (借兵), else by night (潜入). From 第七章.
	var raid: bool = true
	## 第七章: the 大秦人's side, else the 浪人's. From 第八章.
	var rome: bool = true
	## 第八章: the sword drawn (璃虹 out of the ice, the night's 鬼卒), else the seal looked over. From 第九章.
	var pulled: bool = false
	## 第九章's choice: expose, deal or uncle. From 第十章.
	var side: String = "expose"
	## 第十章: who drew 旋芒 — self, uncle or xiao. For 终章.
	var who: String = "self"
	## A faction line (LINES' key; "" none) and the stage it stands at (its stages' key).
	var line: String = ""
	var stage: String = ""
	## What apply() sent away and took off the floor (clear_stage), for the log and the suites.
	var cleared: Array[String] = []

	func describe() -> String:
		var parts: Array[String] = [ChapterStart.title(quest), "剑" if sword else "拳"]
		var at: int = ChapterStart.index_of(quest)
		if at >= ChapterStart.index_of(&"main.chapter4"):
			parts.append("第三章追宫主" if chased else "第三章救人")
		if at >= ChapterStart.index_of(&"main.chapter7"):
			parts.append("借兵" if raid else "潜入")
		if at >= ChapterStart.index_of(&"main.chapter8"):
			parts.append("站大秦人" if rome else "站浪人")
		if at >= ChapterStart.index_of(&"main.chapter9"):
			parts.append("拔了穿灵" if pulled else "没拔穿灵")
		if at >= ChapterStart.index_of(&"main.chapter10"):
			parts.append({"expose": "揭发", "deal": "私了", "uncle": "皇叔"}.get(side, side))
		if at >= ChapterStart.index_of(&"main.finale"):
			parts.append({"self": "旋芒在你手里", "uncle": "旋芒在皇叔手里", "xiao": "旋芒在萧辟尘手里"}.get(who, who))
		if ChapterStart.is_after(quest):
			parts.append("灭了侮天鬼" if ChapterStart.ending(self) == "slay" else "再封了侮天鬼（南危水留在冰里）")
		var stage_entry: Dictionary = ChapterStart.stage_of(line, stage)
		if not stage_entry.is_empty():
			parts.append("势力线 %s：%s" % [ChapterStart.line_of(line)["title"], stage_entry["title"]])
		return "，".join(parts)

	## Why no player can stand where these choices say (empty: one can). Each reason in the owner's words.
	func problems() -> Array[String]:
		var out: Array[String] = []
		var at: int = ChapterStart.index_of(quest)
		if at < 0:
			return ["没有这一章：%s" % quest]
		if at >= ChapterStart.index_of(&"main.finale"):
			if who == "uncle" and side != "uncle":
				out.append("旋芒在皇叔手里：要皇叔已经入朝（第九章选皇叔）")
			var bells: int = ChapterStart.bells(self)
			if who == "self" and bells < 6:
				out.append("自己拔旋芒：十铃里要响六口，这条路只响%d口" % bells)
		if not line.is_empty():
			var stage_entry: Dictionary = ChapterStart.stage_of(line, stage)
			if stage_entry.is_empty():
				out.append("没有这一步：势力线 %s %s" % [line, stage])
			elif at < ChapterStart.index_of(stage_entry["from"]):
				out.append("势力线 %s「%s」要从「%s」起" % [ChapterStart.line_of(line)["title"], stage_entry["title"], ChapterStart.title(stage_entry["from"])])
		return out

	## The choices made legal, the later choice giving way to the earlier (第十章's to 第九章's, a faction step to the chapter);
	## what changed, in the owner's words (empty: nothing).
	func corrected() -> Array[String]:
		var out: Array[String] = []
		var at: int = ChapterStart.index_of(quest)
		if at >= ChapterStart.index_of(&"main.finale"):
			if who == "uncle" and side != "uncle":
				who = "self" if ChapterStart.bells(self) >= 6 else "xiao"
				out.append("旋芒改在%s手里（皇叔没有入朝）" % ("你" if who == "self" else "萧辟尘"))
			if who == "self" and ChapterStart.bells(self) < 6:
				who = "uncle" if side == "uncle" else "xiao"
				out.append("旋芒改在%s手里（只响%d口铃，自己拔不了）" % ["皇叔" if who == "uncle" else "萧辟尘", ChapterStart.bells(self)])
		if not line.is_empty():
			var stage_entry: Dictionary = ChapterStart.stage_of(line, stage)
			if stage_entry.is_empty() or at < ChapterStart.index_of(stage_entry["from"]):
				var reachable: Array = (ChapterStart.line_of(line).get("stages", []) as Array).filter(func(entry: Dictionary) -> bool: return at >= ChapterStart.index_of(entry["from"]))
				if reachable.is_empty():
					out.append("不选势力线（%s 在这一章还走不到）" % ChapterStart.line_of(line).get("title", line))
					line = ""
					stage = ""
				else:
					stage = reachable[reachable.size() - 1]["key"]
					out.append("势力线 %s 改到「%s」" % [ChapterStart.line_of(line)["title"], reachable[reachable.size() - 1]["title"]])
		return out


static func index_of(quest_id: StringName) -> int:
	for at: int in START.size():
		if START[at]["quest"] == quest_id:
			return at
	return -1


## The quest of a command-line key ("prologue", "1" … "10", "finale", "after"; "chapter7" too).
static func quest_of(key: String) -> StringName:
	var bare: String = key.trim_prefix("chapter").trim_prefix("main.")
	for entry: Dictionary in START:
		if entry["key"] == bare or String(entry["quest"]) == "main." + bare:
			return entry["quest"]
	return &""


## 「第七章 番坊」 as the journal names it (终章之后 by its own title).
static func title(quest_id: StringName) -> String:
	var at: int = index_of(quest_id)
	if at >= 0 and START[at].has("title"):
		return START[at]["title"]
	var number: String = "序章" if at == 0 else "终章" if quest_id == &"main.finale" else "第%s章" % ChineseNumber.of(at)
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(quest_id)
	return number if quest == null else "%s %s" % [number, quest.title]


static func is_after(quest_id: StringName) -> bool:
	var at: int = index_of(quest_id)
	return at >= 0 and START[at].get("after", false)


static func line_of(key: String) -> Dictionary:
	for entry: Dictionary in LINES:
		if entry["key"] == key:
			return entry
	return {}


static func stage_of(line_key: String, stage_key: String) -> Dictionary:
	for entry: Dictionary in line_of(line_key).get("stages", []):
		if entry["key"] == stage_key:
			return entry
	return {}


## A spec of `quest_id` with `values` set (Spec's fields by name).
static func spec(quest_id: StringName, values: Dictionary = {}) -> Spec:
	var out := Spec.new()
	out.quest = quest_id
	for key: String in values:
		out.set(key, values[key])
	return out


## The arrival exp of the spec's chapter (终章之后: the whole story's 历练).
static func arrival_exp(of: Spec) -> int:
	var from: int = Arrival.EXPLORING_START if of.exploring else Arrival.MAIN_START
	return Arrival.arrival(&"" if is_after(of.quest) else of.quest, from)


## How many of the 风铃阁's ten bells ring for a player the spec's 第一章 to 第九章 stand for (第十章's 自己拔
## wants six; lancheng/world.json lancheng.whirl.self): 雪亭 (刘安禄 spared), 老松岭 (the bones buried) and 水烟阁
## (南危水's secret kept) on every road the starts write; 野羊山 (霍铮 home), 晚月庄 (瑷伦 keeps the 宝衣) and 乔阴
## (陈显祖's witness) on the rescue's; 关北 either way (骑兵 or 王府干净); 番坊 on the 大秦人's side; 玉螺湖村 either way;
## 京师 for 揭发 (冯策) or 皇叔 (入朝). chapter_start_branches_test.gd checks it against the data on every road.
static func bells(of: Spec) -> int:
	return 3 + (0 if of.chased else 3) + 1 + (1 if of.rome else 0) + 1 + (1 if of.side in ["expose", "uncle"] else 0)


## How many of 终章's helping bands come (finale.helpers in story/conditions.json, three for 能灭它) on the spec's
## road, no faction line played: 霍铮 (rescue), 郭承's riders (借兵), the 大秦人 (their side), the 冰龙 not beaten
## (always, before 终章 B), 冯策 (揭发), 水烟阁 (南危水's secret kept). Checked as bells() is.
static func roll_call(of: Spec) -> int:
	return (0 if of.chased else 1) + (1 if of.raid else 0) + (1 if of.rome else 0) + 1 + (1 if of.side == "expose" else 0) + 1


## How 终章 B ended for 终章之后: 灭 (slay) where 能灭它 could be said — three bands at least (finale.helpers; the 三器
## are there on every road: 穿灵 drawn or pulled at the 封坛, 旋芒 in one of three hands, the 宝衣 carried or 瑷伦 called)
## — else 再封 by 南危水 (seal_nan: 替南危水保密 is on every road the starts write; village.seal_altar.nail).
static func ending(of: Spec) -> String:
	return "slay" if roll_call(of) >= 3 else "seal_nan"


## The things carried() says a start of the spec holds (beyond its fixtures').
static func carried(of: Spec) -> Array[StringName]:
	var at: int = index_of(of.quest)
	var out: Array[StringName] = []
	if at >= index_of(&"main.chapter9") and not is_after(of.quest):
		out.append(IMPALER if of.pulled else FEATHER)
	if at >= index_of(&"main.chapter10") and of.side == "expose" and of.raid and of.chased:
		out.append(LETTER)
	if of.quest == &"main.finale" and of.who == "self":
		out.append(XUANMANG)
	return out


## Sets `session` (a New Game's, initialized, the player standing) up as `of`'s chapter begins.
## Returns "" when done, else what failed (the session is then left as far as it got).
static func apply(session: WorldSessionController, of: Spec) -> String:
	var at: int = index_of(of.quest)
	if at < 0:
		return "no chapter %s" % of.quest
	var problems: Array[String] = of.problems()
	if not problems.is_empty():
		return "；".join(problems)
	if session == null or not session.is_initialized() or session.player_runtime() == null:
		return "no session"
	if at == 0:
		return "" # 序章 is the New Game itself.
	var written: Dictionary = Fixtures.record(func() -> void:
		_write_story(session, of)
		_write_line(session, of))
	var state: CharacterState = session.player_runtime().state
	Grown.grow(state, arrival_exp(of), 50, of.sword)
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return "no map"
	for item_id: StringName in carried(of):
		if session.player_held_item_ids().get(item_id, false) == false and map.give_new_item_to_player(item_id).is_empty():
			return "could not give %s" % item_id
	var given: Dictionary = (written["given"] as Dictionary).merged(written["taken"])
	for item_id: StringName in carried(of):
		given[item_id] = true
	of.cleared = clear_stage(session, written["marks"], given)
	var silver: ItemContentDefinition = GameContent.catalog().currency_item(CurrencyDenomination.Value.SILVER)
	for coin: int in SILVER:
		map.give_new_item_to_player(silver.item_definition_id)
	if of.sword:
		var sword_id: StringName = map.give_new_item_to_player(SWORD)
		if sword_id.is_empty() or not session.wield_player_item(sword_id).succeeded:
			return "could not wield the sword"
	if session.player_held_item_ids().get(CROWN, false) and not session.player_worn_item_ids().get(CROWN, false):
		for item_id: StringName in _carried_ids(session, CROWN):
			session.wear_player_item(item_id)
	var placed: String = place(session, START[at]["zone"], START[at].get("near", &""))
	if not placed.is_empty():
		return placed
	_paid(session, of.quest)
	session.record_journal()
	if of.line.is_empty():
		return ""
	return _place_on_line(session, of)


## The ids of the things of definition `definition_id` the player carries directly.
static func _carried_ids(session: WorldSessionController, definition_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var map: WorldMapController = session.active_map() as WorldMapController
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(carried):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			out.append(item_id)
	return out


## The player to the faction line's next step (its target's place, beside its first person); the journal told again.
static func _place_on_line(session: WorldSessionController, of: Spec) -> String:
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(line_of(of.line)["quest"])
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(session.player_runtime().state, quest)
	if step == null:
		return "the line %s has not begun" % of.line
	var target: StoryQuestDefinition.Target = step.target_for(session.player_runtime().state.marks)
	if target == null or target.zone_id.is_empty():
		return ""
	var placed: String = place(session, target.zone_id, target.npc_ids[0] if not target.npc_ids.is_empty() else &"")
	var location: WorldLocationState = session.player_runtime().world_location()
	if placed.is_empty() and (location == null or location.zone_id != target.zone_id):
		# The person stands at the zone's edge (a spot beside them fell outside it): anywhere in the zone.
		placed = place(session, target.zone_id)
	session.record_journal()
	return placed


## The world as the story `marks` stand for leaves it (a fixture writes marks, not the world): the people of every
## spawn whose `cleared_mark` is written (knocked down in the story; one a room's reset would remake stays, and so does
## one a step still to play looks for on that map: 玄冥子 on the cliff, spared, whom 卧底's 天书 goes to), and the
## people every list of steps that ran sent away (its `leave`s: the 工地's officers and freed men, the 守夜 pair, the
## 浪人 at the 番坊 gate), gone for good — a list ran when every mark it writes is written, or it called in a spawn so
## cleared; those it sent away are the ones standing on the map its scene plays on (beside its NPC, or in its zone),
## and never one the story itself puts on its stage now (a spawn's `present` holding: 石头 home at the farm). Each
## thing in `given` (handed to the player before, by the story or the start) is taken off the floor where its spawn
## laid it. Returns what went.
static func clear_stage(session: WorldSessionController, marks: Dictionary, given: Dictionary) -> Array[String]:
	var catalog: ContentCatalog = GameContent.catalog()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var held: Dictionary[StringName, bool] = session.player_held_item_ids()
	var cleared_spawns: Dictionary[StringName, bool] = {}
	var maps_of: Dictionary[StringName, Dictionary] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		if not spawn.cleared_mark.is_empty() and marks.has(spawn.cleared_mark):
			cleared_spawns[spawn.spawn_id] = true
		if not maps_of.has(spawn.npc_definition_id):
			maps_of[spawn.npc_definition_id] = {}
		maps_of[spawn.npc_definition_id][spawn.map_id] = true
	# Who a step not yet played looks for, and on which map ("<npc>@<map>").
	var sought: Dictionary[String, bool] = {}
	var ledger: Array = player.state.quests.keys()
	for quest: StoryQuestDefinition in catalog.story_quests():
		for step: StoryQuestDefinition.Step in quest.steps:
			var key: String = "%s/%s" % [quest.quest_id, step.step_id]
			if ledger.any(func(written: String) -> bool: return written == key or written.begins_with(key + "/")):
				continue
			for target: StoryQuestDefinition.Target in [step.target, step.target_after]:
				if target != null:
					for npc_id: StringName in target.npc_ids:
						sought["%s@%s" % [npc_id, target.map_id]] = true
	# Per map (&"": wherever), per NPC definition, how many to send away.
	var leaving: Dictionary = {}
	for list: Dictionary in Reads.step_lists():
		var writes: Array = list["writes"]
		var ran: bool = (not writes.is_empty() and writes.all(func(mark: String) -> bool: return marks.has(mark))) or (list["summons"] as Array).any(func(spawn_id: StringName) -> bool: return cleared_spawns.has(spawn_id))
		if not ran:
			continue
		var scene_maps: Array = [&""]
		if not StringName(list["zone"]).is_empty() and catalog.zone(list["zone"]) != null:
			scene_maps = [catalog.zone(list["zone"]).map_id]
		elif maps_of.has(list["npc"]):
			scene_maps = maps_of[list["npc"]].keys()
		for map_id: StringName in scene_maps:
			if not leaving.has(map_id):
				leaving[map_id] = {}
			for npc_id: StringName in list["leaves"]:
				leaving[map_id][npc_id] = int(leaving[map_id].get(npc_id, 0)) + 1
	var out: Array[String] = []
	# Two passes: on the scene's own map first; then whoever is still owed goes wherever the person still stands
	# (the copy a follower left on its own map: 霍铮 and 石头 in 逆灵宫's cells after the rescue).
	for pass_at: int in 2:
		if pass_at == 1:
			var anywhere: Dictionary = {}
			for map_id: StringName in leaving:
				for npc_id: StringName in leaving[map_id]:
					anywhere[npc_id] = int(anywhere.get(npc_id, 0)) + maxi(int(leaving[map_id][npc_id]), 0)
			leaving = {&"": anywhere}
		for map: WorldMapController in session.world_maps():
			for npc: NpcRuntimeState in map.npc_runtimes().duplicate():
				# Off the stage now (not on its marker) counts too: the stage would bring it on as the player comes.
				if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.has_flag(NpcDefinition.FLAG_GONE):
					continue
				var spawn: NpcSpawnDefinition = catalog.spawn(npc.spawn_id) if not npc.spawn_id.is_empty() else null
				var definition_id: StringName = npc.definition().definition_id
				var by_spawn: bool = pass_at == 0 and cleared_spawns.has(npc.spawn_id) and spawn != null and not spawn.remade_by_reset() and not sought.has("%s@%s" % [definition_id, map.map_id()])
				if not by_spawn and spawn != null and spawn.present != null and JournalLog.holds(spawn.present, player.state, player.temp_marks, held) and (spawn.until == null or not JournalLog.holds(spawn.until, player.state, player.temp_marks, held)):
					continue
				var count_on: StringName = &"-"
				for map_id: StringName in [map.map_id(), &""]:
					if int(leaving.get(map_id, {}).get(definition_id, 0)) > 0:
						count_on = map_id
						break
				if not by_spawn and count_on == &"-":
					continue
				if not by_spawn:
					leaving[count_on][definition_id] = int(leaving[count_on][definition_id]) - 1
				map.npcs.leave_for_good(npc)
				out.append("%s@%s" % [definition_id, map.map_id()])
	for spawn: ItemSpawnDefinition in catalog.item_spawns():
		if not given.has(spawn.item_definition_id):
			continue
		var map: WorldMapController = session.world_map_of(spawn.map_id)
		var item_id: StringName = &"" if map == null else map.floor_items.floor_item_of(spawn.item_definition_id, spawn.zone_id)
		if not item_id.is_empty() and map.floor_items.destroy_floor_item(item_id):
			out.append("%s@%s" % [spawn.item_definition_id, spawn.zone_id])
	return out


## The 历练 the arrival exp already holds, written down as paid (as WorldProgressionRewards writes a
## milestone), so the journal's next beat pays none of it again: the regions the chapters before
## `quest_id` lead into and the 名胜 it counts there (StoryArrival.ROUTE), the quests done, the journal chains the story so far sees
## through (its 见闻 recorded here first, untold) and the 打坐 steps the grown max_force has passed (the
## first two hours' part of the arrival). What the chapter's own road pays — its new region, the 名胜
## it starts at — still pays on arrival.
static func _paid(session: WorldSessionController, quest_id: StringName) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	var keys: Array[String] = []
	for chapter: Array in Arrival.ROUTE:
		if chapter[0] == quest_id:
			break
		for reward: Array in chapter[1]:
			if reward[0] == &"region":
				keys.append(MilestoneRewards.key_of(ProgressionRules.Kind.REGION, reward[1]))
			elif reward[0] == &"place":
				# ROUTE names a 名胜 by its region: every 名胜 there counts as seen (the story's road
				# passes them; one off it pays nothing on a later visit).
				for zone_id: StringName in catalog.progression().places:
					var region: RegionDefinition = WorldProgressionRewards.region_of_zone(zone_id)
					if region != null and region.region_id == reward[1]:
						keys.append(MilestoneRewards.key_of(ProgressionRules.Kind.PLACE, zone_id))
	for quest: StoryQuestDefinition in catalog.story_quests():
		if StoryQuestLog.is_done(state, quest):
			keys.append(MilestoneRewards.key_of(ProgressionRules.Kind.QUEST, quest.quest_id))
	for threshold: int in catalog.progression().force_milestones:
		if state.recovery.inner_force.maximum >= threshold:
			keys.append(MilestoneRewards.key_of(ProgressionRules.Kind.FORCE, StringName(str(threshold))))
	_write_paid(state, keys)
	# The 见闻 the story so far wrote (some wait on the milestones above: 雪亭镇的头几天 ends at 绮云镇).
	var location: WorldLocationState = player.world_location()
	JournalLog.record_entries(state, player.temp_marks, session.player_held_item_ids(), catalog.journal_chains(), &"" if location == null else location.zone_id, session.player_worn_item_ids(), session.day_phase_id())
	keys.clear()
	for chain: JournalChainDefinition in JournalLog.finished_chains(state, catalog.journal_chains()):
		keys.append(MilestoneRewards.key_of(ProgressionRules.Kind.CHAIN, chain.chain_id))
	_write_paid(state, keys)


static func _write_paid(state: CharacterState, keys: Array[String]) -> void:
	for key: String in keys:
		if not state.milestones.has(key):
			state.milestones[key] = state.milestones.size() + 1


## The ledger the chapters before `of`'s leave, by the story fixtures (each writes all before it).
static func _write_story(session: WorldSessionController, of: Spec) -> void:
	match of.quest:
		&"main.chapter1": Fixtures.prologue_done(session)
		&"main.chapter2": Fixtures.chapter1_done(session)
		&"main.chapter3": Fixtures.chapter2_done(session)
		&"main.chapter4":
			if of.chased:
				Fixtures.chapter3_chased(session)
			else:
				Fixtures.chapter3_rescued(session)
		&"main.chapter5":
			if of.chased:
				Fixtures.chapter4_taken(session)
			else:
				Fixtures.chapter4_kept(session)
		&"main.chapter6":
			if of.chased:
				Fixtures.chapter5_released(session)
			else:
				Fixtures.chapter5_escorted(session)
		&"main.chapter7": Fixtures.chapter6_done(session, of.raid, of.chased)
		&"main.chapter8": Fixtures.chapter7_done(session, of.rome, of.raid, of.chased)
		&"main.chapter9": Fixtures.chapter8_done(session, of.pulled, of.rome, of.raid, of.chased)
		&"main.chapter10": Fixtures.chapter9_done(session, of.side, of.pulled, of.rome, of.raid, of.chased)
		&"main.finale": Fixtures.chapter10_done(session, of.who, of.side, of.pulled, of.rome, of.raid, of.chased)
		&"faction.assembly": Fixtures.finale_done(session, ending(of), of.who, of.side, of.pulled, of.rome, of.raid, of.chased)


## The faction line's state up to its stage, by the line's fixtures (on top of the main story's).
static func _write_line(session: WorldSessionController, of: Spec) -> void:
	match "%s/%s" % [of.line, of.stage]:
		"fonxan/join": Fixtures.fonxan_joined(session)
		"fonxan/gate": Fixtures.fonxan_gated(session)
		"celestial/join": Fixtures.celestial_joined(session)
		"celestial/escort": Fixtures.celestial_escorted(session)
		"dongfang/join": Fixtures.dongfang_joined(session)
		"dongfang/names": Fixtures.dongfang_held(session)
		"niling/enter":
			Fixtures.niling_entered(session, "xuan" if of.chased else "night")
			Fixtures._give(session, CROWN) # 林忌's 黑冠 (common/npcs.json), worn to go in: apply() puts it on
		"niling/word":
			Fixtures.niling_delivered(session, "xuan" if of.chased else "night")
			Fixtures._give(session, CROWN)
		"niling/net":
			Fixtures.niling_scripture(session, "xuan" if of.chased else "night", false)
			Fixtures._give(session, CROWN)
		"zhenyuan/take": Fixtures.zhenyuan_taken(session)
		"zhenyuan/deliver": Fixtures.zhenyuan_delivered(session)
		"latemoon/guard":
			Fixtures.latemoon_guardian(session)
		"latemoon/robe":
			Fixtures.latemoon_guardian(session)
			Fixtures.latemoon_robe_settled(session)
		"huazi/drum": pass # 击了鼓 is 第五章's: the line begins with it.
		"huazi/letter":
			Fixtures.huazi_found(session)
			Fixtures._give(session, &"native:city/courier_letter")
			Fixtures.huazi_letter(session)
		"court/badge": Fixtures.court_joined(session)
		"court/seal": Fixtures.court_reported(session)
		"maoshan/book": Fixtures.maoshan_booked(session)
		"buxuan/guest":
			for mark: String in ["桃林", "桃林的客", "骆云舟说了风泉"]:
				Fixtures._mark(session.player_runtime().state, mark)
		"buxuan/copy": Fixtures.buxuan_copied(session)
		"sanyen/help": Fixtures.sanyen_helper(session)
		"sanyen/west": Fixtures.sanyen_treated(session)
		"juechen/guest": Fixtures.juechen_guest(session)


## The player into `zone_id` wherever it lies (handed off to its map through a way in that the data
## names, as a door would), at a free spot — beside the first of `near` standing there, if given.
## "" when done, else why not.
static func place(session: WorldSessionController, zone_id: StringName, near: StringName = &"") -> String:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	if zone == null:
		return "no zone %s" % zone_id
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null or map.map_id() != zone.map_id:
		var way: PortalDefinition = _way_onto(zone.map_id, zone_id)
		if way == null:
			return "no way onto %s" % zone.map_id
		var moved: OldPineMapHandoffResult = session.handoff_to(zone.map_id, way.destination_zone_id, way.destination_zone_id, way.destination_spawn_point_id)
		if not moved.succeeded():
			return "handoff to %s refused (%d)" % [zone.map_id, moved.outcome]
		map = session.active_map() as WorldMapController
	var point: Vector2 = Vector2.INF
	var person: NpcRuntimeState = standing(session, near, zone.map_id)
	if person != null:
		var body: Node2D = map.runtime_body_for_character(person.character_id)
		if body != null:
			point = Places.spot(map, zone_id, body.global_position + Vector2(0, 56), 160.0)
	if not point.is_finite() or _by_a_passage(map, point):
		# Not on a way out (a spot beside a person by the door would walk the player through it).
		point = Places.zone_spot(map, zone_id)
	if not point.is_finite() or not map.place_player(zone_id, point):
		return "no room in %s" % zone_id
	return ""


## Whether `point` lies within a body's reach of one of the map's passages (its ways out).
static func _by_a_passage(map: WorldMapController, point: Vector2) -> bool:
	for node: Node in map.find_children("*", "Area2D", true, false):
		if node is WorldPassageArea2D and (node as Node2D).global_position.distance_to(point) < 96.0:
			return true
	return false


## The way onto `map_id` from another map that lands in `zone_id`, else any that lands on the map.
static func _way_onto(map_id: StringName, zone_id: StringName) -> PortalDefinition:
	var any: PortalDefinition = null
	for portal: PortalDefinition in GameContent.catalog().portals():
		if portal.destination_map_id != map_id or portal.source_map_id == map_id:
			continue
		if portal.destination_zone_id == zone_id:
			return portal
		if any == null:
			any = portal
	return any


## The first NPC of definition `npc_id` standing on `map_id` (null when none, or none asked).
static func standing(session: WorldSessionController, npc_id: StringName, map_id: StringName) -> NpcRuntimeState:
	if npc_id.is_empty():
		return null
	for npc: NpcRuntimeState in session.world_npcs():
		var location: WorldLocationState = npc.world_location()
		if npc.definition().definition_id == npc_id and npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and location != null and location.map_id == map_id:
			return npc
	return null
