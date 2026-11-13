class_name ChapterStart
extends RefCounted

## Dev only, opt-in (tests/ never reaches a release; nothing here is an autoload): a New Game
## session set up as the main story leaves a player at the start of a chapter, for the owner's
## playtest of that chapter without playing the ones before it (ROADMAP「After the grey box」
## step 1; BUILD.md「试玩一轮」). apply() writes, on the session New Game made:
## - the main story's state up to the chapter, by the chapter fixtures the story suites use
##   (tests/support/story_fixtures.gd: ledger keys, marks, milestones, people met, and the things
##   they leave in hand), on the branch chosen where it changes what is there (Spec);
## - the things the chapters before it put in hand that the fixtures leave out (CARRIED);
## - the character grown to the chapter's arrival exp (tests/support/story_arrival.gd, the story's
##   历练) by the game's own rules (tests/support/grown_character.gd: 封山剑法 with a sword in hand,
##   or 柳家拳 bare-handed), with what that exp was paid for written down as paid (no first visit
##   or quest pays twice), and a little silver for the road;
## - the player at the chapter's first step (START: its place, beside its person), and the journal
##   told, so the chapter opens as it would.
## Then the normal game goes on: a save made afterwards is an ordinary save. No save file is read:
## the world revision changes too often for a kept one. The F6 scene (tests/dev/chapter_start.tscn)
## and the command line (tests/dev/chapter_start/run_chapter_start.gd) both start a New Game with it;
## tests/runtime/chapter_start_test.gd proves every start.

const Fixtures := preload("res://tests/support/story_fixtures.gd")
const Grown := preload("res://tests/support/grown_character.gd")
const Arrival := preload("res://tests/support/story_arrival.gd")
const Places := preload("res://tests/support/map_places.gd")

## The sword of the sword build (as the fight sim and the 试战台 hold it).
const SWORD: StringName = &"es2:obj/longsword"
## Pocket money for a chapter start: fares and a meal, not a rule of the game.
const SILVER: int = 30

## The chapters in story order: the quest, the key the command line takes, and where its first step
## is played from — `zone` (a free spot in it), beside `near` (one of the step's people) when given.
## The place is the step's own target, except where arriving there would already do the step or skip
## its point: 第六章 starts outside the 军营 (getting into it is the step), 第十章 just through the
## 石林's mirror (reading the wind is the step), 终章 on the road beside the lake (reaching it is the step).
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
]

## What the chapters before a start put in hand that their fixtures do not give (the fixtures stop at
## the ledger; these are what quest_items_test knows the later steps ask to carry): per chapter, the
## items, and per branch.
## - 兵部文书: picked up in 逆灵宫's 账房 (第三章), beaten on the drum in 第五章 (its fixture gives it
##   only once 第五章 is done).
## - 穿灵 drawn, or 璃虹的羽 given for looking (第八章): the 封坛's 三器 in 终章.
## - 旋芒 from the 云台 (第十章, when the player drew it).
const PAPERS: StringName = &"native:niling/war_ministry_papers"
const IMPALER: StringName = &"native:village/soul_impaler"
const FEATHER: StringName = &"native:village/lihong_feather"
const XUANMANG: StringName = &"native:lancheng/xuanmang"


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
	## 第八章: the sword drawn (璃虹 out of the ice, the night's 鬼卒), else the seal looked over. From 第九章.
	var pulled: bool = false
	## 第九章's choice: expose, deal or uncle. From 第十章.
	var side: String = "expose"
	## 第十章: who drew 旋芒 — self, uncle or xiao. For 终章.
	var who: String = "self"

	func describe() -> String:
		var parts: Array[String] = [ChapterStart.title(quest), "剑" if sword else "拳"]
		var at: int = ChapterStart.index_of(quest)
		if at >= ChapterStart.index_of(&"main.chapter4"):
			parts.append("第三章追宫主" if chased else "第三章救人")
		if at >= ChapterStart.index_of(&"main.chapter9"):
			parts.append("拔了穿灵" if pulled else "没拔穿灵")
		if at >= ChapterStart.index_of(&"main.chapter10"):
			parts.append({"expose": "揭发", "deal": "私了", "uncle": "皇叔"}.get(side, side))
		if at >= ChapterStart.index_of(&"main.finale"):
			parts.append({"self": "旋芒在你手里", "uncle": "旋芒在皇叔手里", "xiao": "旋芒在萧辟尘手里"}.get(who, who))
		return "，".join(parts)


static func index_of(quest_id: StringName) -> int:
	for at: int in START.size():
		if START[at]["quest"] == quest_id:
			return at
	return -1


## The quest of a command-line key ("prologue", "1" … "10", "finale"; "chapter7" too).
static func quest_of(key: String) -> StringName:
	var bare: String = key.trim_prefix("chapter").trim_prefix("main.")
	for entry: Dictionary in START:
		if entry["key"] == bare or String(entry["quest"]) == "main." + bare:
			return entry["quest"]
	return &""


## 「第七章 番坊」 as the journal names it.
static func title(quest_id: StringName) -> String:
	var at: int = index_of(quest_id)
	var number: String = "序章" if at == 0 else "终章" if quest_id == &"main.finale" else "第%s章" % ChineseNumber.of(at)
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(quest_id)
	return number if quest == null else "%s %s" % [number, quest.title]


## The arrival exp of the spec's chapter.
static func arrival_exp(spec: Spec) -> int:
	return Arrival.exploring(spec.quest) if spec.exploring else Arrival.main_story(spec.quest)


## The items CARRIED says a start of the spec holds (beyond its fixture's).
static func carried(spec: Spec) -> Array[StringName]:
	var at: int = index_of(spec.quest)
	var out: Array[StringName] = []
	if at == index_of(&"main.chapter4") or at == index_of(&"main.chapter5"):
		out.append(PAPERS)
	if at >= index_of(&"main.chapter9"):
		out.append(IMPALER if spec.pulled else FEATHER)
	if at == index_of(&"main.finale") and spec.who == "self":
		out.append(XUANMANG)
	return out


## Sets `session` (a New Game's, initialized, the player standing) up as `spec`'s chapter begins.
## Returns "" when done, else what failed (the session is then left as far as it got).
static func apply(session: WorldSessionController, spec: Spec) -> String:
	var at: int = index_of(spec.quest)
	if at < 0:
		return "no chapter %s" % spec.quest
	if session == null or not session.is_initialized() or session.player_runtime() == null:
		return "no session"
	if at == 0:
		return "" # 序章 is the New Game itself.
	_write_story(session, spec)
	var state: CharacterState = session.player_runtime().state
	Grown.grow(state, arrival_exp(spec), 50, spec.sword)
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return "no map"
	for item_id: StringName in carried(spec):
		if session.player_held_item_ids().get(item_id, false) == false and map.give_new_item_to_player(item_id).is_empty():
			return "could not give %s" % item_id
	var silver: ItemContentDefinition = GameContent.catalog().currency_item(CurrencyDenomination.Value.SILVER)
	for coin: int in SILVER:
		map.give_new_item_to_player(silver.item_definition_id)
	if spec.sword:
		var sword_id: StringName = map.give_new_item_to_player(SWORD)
		if sword_id.is_empty() or not session.wield_player_item(sword_id).succeeded:
			return "could not wield the sword"
	var placed: String = place(session, START[at]["zone"], START[at].get("near", &""))
	if not placed.is_empty():
		return placed
	_paid(session, spec.quest)
	session.record_journal()
	return ""


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


## The ledger the chapters before `spec`'s leave, by the story fixtures (each writes all before it).
static func _write_story(session: WorldSessionController, spec: Spec) -> void:
	match spec.quest:
		&"main.chapter1": Fixtures.prologue_done(session)
		&"main.chapter2": Fixtures.chapter1_done(session)
		&"main.chapter3": Fixtures.chapter2_done(session)
		&"main.chapter4":
			if spec.chased:
				Fixtures.chapter3_chased(session)
			else:
				Fixtures.chapter3_rescued(session)
		&"main.chapter5":
			if spec.chased:
				Fixtures.chapter4_taken(session)
			else:
				Fixtures.chapter4_kept(session)
		&"main.chapter6":
			if spec.chased:
				Fixtures.chapter5_released(session)
			else:
				Fixtures.chapter5_escorted(session)
		&"main.chapter7": Fixtures.chapter6_done(session, true, spec.chased)
		&"main.chapter8": Fixtures.chapter7_done(session, true, true, spec.chased)
		&"main.chapter9": Fixtures.chapter8_done(session, spec.pulled, true, true, spec.chased)
		&"main.chapter10": Fixtures.chapter9_done(session, spec.side, spec.pulled, true, true, spec.chased)
		&"main.finale": Fixtures.chapter10_done(session, spec.who, spec.side, spec.pulled, true, true, spec.chased)


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
	if not point.is_finite():
		point = Places.zone_spot(map, zone_id)
	if not point.is_finite() or not map.place_player(zone_id, point):
		return "no room in %s" % zone_id
	return ""


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
