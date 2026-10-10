extends RefCounted

## 晚月庄 C (d/latemoon): the manor's secrets. 蓝筱薇 makes a 竹子 into a 竹蜻蜓 over ten
## seconds (a second 竹子 goes back, 默认); 芳绫 trades it for the secret, and the 碧纱橱
## gives the 玛瑙手镯, whose pray takes the player to Snow's temple; 莫欣芳's 舞曲谱 answer
## lets the 密室's bed give the 舞曲谱 (音律 to 60, 「春宫怨」 to the hall); the 丝罗巾 teaches
## 基本行动; the 杀手令牌 buys 无名老妇's force (a 晚月庄 member below 160) or her 寒雪鞭法; the
## 火摺 shows 芙云's 密函. The temps go with Continue, the dance-book mark stays. NPC time is
## driven by hand; TEST-ONLY fixtures are marked.
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const BAMBOO: StringName = &"es2:d/latemoon/obj/bamboo"
const DRAGONFLY: StringName = &"es2:d/latemoon/obj/dragonfly"
const BRACELET: StringName = &"es2:d/latemoon/obj/bracelet"
const BOOK: StringName = &"es2:d/latemoon/obj/book"
const HANKIE: StringName = &"es2:d/latemoon/obj/hankie"
const TOKEN: StringName = &"es2:d/latemoon/room/npc/obj/token"
const WHIP_BOOK: StringName = &"es2:d/latemoon/room/npc/obj/whip_book"
const LETTER: StringName = &"es2:d/latemoon/room/npc/obj/letter"
const FIRE: StringName = &"es2:d/latemoon/room/npc/obj/fire"
const SKIRT: StringName = &"es2:d/latemoon/obj/skirt"
const MAKING: Array[String] = [
	"筱薇微笑的看著你说：你要作竹蜻蜓呀!",
	"筱薇将你给她的竹子仔细的看了一下。说道：不错是根玉竹!",
	"筱薇将竹子周围的叶子弄掉，灵巧的削凿著。",
	"经过不久，筱薇把竹蜻蜓做好了。",
	"筱薇将做好的竹蜻蜓递给你，微笑说道：嗯! 做好了!",
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_passed_force()
	var session: WorldSessionController = await _session(tree)
	await _test_bamboo(tree, session)
	await _test_bracelet(tree, session)
	await _test_dance_book(tree, session)
	await _test_hankie(tree, session)
	await _test_token(tree, session)
	await _test_letter(tree, session)
	await _test_continue(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("晚客", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	await tree.process_frame
	session.set_process(false)
	# TEST-ONLY: nobody chats or wanders; a random(2) greeting takes its second case.
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	var state: CharacterState = session.player_runtime().state
	# TEST-ONLY: strong enough for the costs below; literate and exp enough to read.
	state.essence = CharacterResourceState.new(500, 500, 500)
	state.vitality = CharacterResourceState.new(500, 500, 500)
	state.spirit = CharacterResourceState.new(500, 500, 500)
	state.skills.set_raw_level(SkillIds.LITERATE, 50)
	state.progression.combat_experience = 10000
	return session


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var bracelet: ItemContentDefinition = catalog.item(BRACELET)
	_check(bracelet.no_drop and bracelet.armor_definition() != null and bracelet.act.verb == "祈祷", "the 玛瑙手镯: worn on the wrist, kept (no_drop), prayed with")
	var pray: ScriptedAct = bracelet.act.act_for(CharacterState.GENDER_FEMALE, &"")
	_check(pray.steps.size() == 3 and pray.steps[1].amounts == {"sen": 50} and pray.steps[2].zone_id == &"snow.temple" and pray.steps[2].point_id == SnowWorldDefinitions.REVIVE_SPAWN_ID, "pray start: its line, 50 sen, Snow's temple (bracelet.c moves to /d/snow/temple)")
	var book: ItemContentDefinition = catalog.item(BOOK)
	_check(book.no_drop and book.study.skill_id == &"music" and book.study.max_skill == 60 and book.study.exp_required == 5000 and book.act.verb == "跳「春宫怨」", "obj/book.c: 音律 to 60 from 5000 exp; dancing home")
	_check(catalog.item(HANKIE).study.skill_id == &"move" and catalog.item(HANKIE).study.max_skill == 50, "the 丝罗巾: 基本行动 to 50")
	_check(catalog.item(WHIP_BOOK).study.skill_id == &"snowwhip" and catalog.item(WHIP_BOOK).study.max_skill == 20, "the 寒雪鞭法 book: snowwhip to 20")
	_check(catalog.skill(&"music").display_name == "音律" and catalog.skill(&"music").skill_type == SkillDefinition.Type.KNOWLEDGE and catalog.skill(&"move").display_name == "基本行动", "the skills read 音律 and 基本行动")
	var letter: ItemContentDefinition = catalog.item(LETTER)
	_check(letter.act.verb == "用火烧" and letter.act.acts[0].carries == "fire" and catalog.item(FIRE).aliases().has("fire"), "the 密函 burns with what answers to fire (the 火摺)")
	for npc_id: StringName in [&"latemoon.npc.room.killer", &"latemoon.npc.room.tguest"]:
		var carried: bool = catalog.npc(npc_id).loadout_entries().any(func(entry: NpcLoadoutEntry) -> bool: return entry.item_definition_id == TOKEN)
		_check(carried, "%s carries a 杀手令牌" % npc_id)
	_check(catalog.npc(&"latemoon.npc.room.guest").loadout_entries().any(func(entry: NpcLoadoutEntry) -> bool: return entry.item_definition_id == LETTER), "芙云 carries the 密函")
	var old: NpcTalk = catalog.npc(&"latemoon.npc.room.old").talk()
	_check(old.inquiry_topics().has("心事") and not old.inquiry_topics().has("trouble") and old.inquiry_topics().has("令牌"), "无名老妇's trouble is asked as 心事 (默认)")
	var making: NpcMaking = catalog.npc(&"latemoon.npc.shaowei").dealings().object_rules[1].make
	_check(making != null and making.every == 2.0 and making.lines.size() == 5 and making.lines.all(func(line: NpcLine) -> bool: return line.color() == ColoredLine.HIY) and making.gives == DRAGONFLY, "make_stage(): five HIY lines two seconds apart, then the 竹蜻蜓")
	var search: RoomActDefinition = catalog.service(&"latemoon.latemoon2.search").act
	var facts := ScriptedAct.Facts.new()
	_check(search.act_for(CharacterState.GENDER_FEMALE, &"", facts).steps[0].line.text.begins_with("你盲目的找著"), "without 芳绫's secret: nothing")
	facts.temps["moon/问题二"] = 1
	_check(search.act_for(CharacterState.GENDER_FEMALE, &"", facts).steps[0].kind == ScriptedAct.Kind.GIVE, "with it: the bracelet")
	facts.temps["latemoon/手镯"] = 1
	_check(search.act_for(CharacterState.GENDER_FEMALE, &"", facts).steps[0].line.text.begins_with("你翻箱倒柜"), "once found: nothing more")


## old.c: random(50) when more than 50 short of 160, else random(what is short), at most
## 20, times kar / 30.
func _test_passed_force() -> void:
	var draws: Array[int] = []
	var thirty: Callable = func(n: int) -> int:
		draws.append(n)
		return mini(30, n - 1)
	_check(NpcObjectRule.passed_force(100, 25, thirty) == 16 and draws == [50], "60 short: random(50) = 30, at most 20, * 25 / 30 = 16")
	draws.clear()
	_check(NpcObjectRule.passed_force(150, 30, thirty) == 9 and draws == [10], "10 short: random(10) = 9, * 30 / 30")
	_check(NpcObjectRule.passed_force(159, 60, thirty) == 0, "1 short: random(1) is 0")


## shaowei.c: a 竹子 becomes a 竹蜻蜓 two seconds a stage; a second goes back (默认).
func _test_bamboo(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"latemoon.secret", &"latemoon.miroom2", &"latemoon.miroom2", &"latemoon.miroom2.flower_arrival").succeeded(), "in the secret 内厅")
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var wei: NpcRuntimeState = _beside(map, session, &"latemoon.npc.shaowei")
	map.npc_life._advance_ambience(1.0)
	_check(map.select_npc(wei.character_id), "蓝筱薇 selected")
	var skirt: StringName = _new_item(session, SKIRT)
	var thanked: ItemHandlingResult = map.give_to_selected(skirt)
	_check(thanked.done() and thanked.lines == ["蓝筱薇说道：这要送给我啊?! 怎么好意思!谢谢你。", "你给蓝筱薇一件布裙。"] and thanked.line_colors.get(0) == ColoredLine.HIY, "anything else: thanked for in HIY and kept: %s" % [thanked.lines])
	var bamboo: StringName = _new_item(session, BAMBOO)
	var given: ItemHandlingResult = map.give_to_selected(bamboo)
	_check(given.done() and given.lines == ["你给蓝筱薇一根竹子。"] and player.temp_marks.get("moon/竹子", 0) == 1, "the 竹子: taken (moon/竹子)")
	var start: int = hud.log_lines().size()
	map.npc_life._advance_ambience(1.0)
	_check(hud.log_lines().size() == start, "nothing before two seconds")
	for stage: int in range(MAKING.size()):
		map.npc_life._advance_ambience(1.0 if stage == 0 else 2.0)
		_check(hud.log_lines()[-1] == MAKING[stage], "stage %d: %s" % [stage, hud.log_lines()[-1]])
		_check(_carried(session, DRAGONFLY).is_empty() == (stage < MAKING.size() - 1), "the 竹蜻蜓 only with the last line")
	var second: ItemHandlingResult = map.give_to_selected(_new_item(session, BAMBOO))
	_check(not second.done() and second.lines == ["蓝筱薇说道：我已经帮你做一个竹蜻蜓了呀!", "蓝筱薇没有收下。"] and not _carried(session, BAMBOO).is_empty(), "a second 竹子 goes back (默认; ES2 kept it): %s" % [second.lines])
	map.npc_life._advance_ambience(10.0)
	_check(_count_carried(session, DRAGONFLY) == 1, "no second 竹蜻蜓")
	# Killed while she is at it, she takes her call_out along (destruct).
	player.temp_marks.erase("moon/竹子") # TEST-ONLY: as if she had never made one
	_check(map.give_to_selected(_new_item(session, BAMBOO)).done(), "a 竹子 again")
	map.npc_life._advance_ambience(2.0)
	wei.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD) # TEST-ONLY: as a fight would leave her
	var lines_before: int = hud.log_lines().size()
	map.npc_life._advance_ambience(10.0)
	_check(hud.log_lines().size() == lines_before and _count_carried(session, DRAGONFLY) == 1 and not map.npc_life.makings.has(wei.character_id), "dead, she makes nothing more")
	wei.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE) # TEST-ONLY
	# The player leaves the map while she is at it: the rest at once (DECISIONS 晚月庄 C).
	player.temp_marks.erase("moon/竹子") # TEST-ONLY
	_check(map.give_to_selected(_carried(session, BAMBOO)).done(), "another 竹子")
	map.npc_life._advance_ambience(2.0)
	_check(hud.log_lines()[-1] == MAKING[0], "one stage told")
	var before_leaving: int = hud.log_lines().size()
	_check(session.handoff_to(&"latemoon.hills", &"latemoon.bamboo", &"latemoon.bamboo", &"latemoon.bamboo.dance_arrival").succeeded(), "out to the bamboo grove")
	var told: Array[String] = hud.log_lines().slice(before_leaving)
	_check(told.find(MAKING[1]) >= 0 and told.find(MAKING[4]) > told.find(MAKING[1]) and _count_carried(session, DRAGONFLY) == 2, "the rest told at once and the 竹蜻蜓 given there: %s" % [told])
	var dropped: ItemHandlingResult = (session.active_map() as WorldMapController).drop_item(_carried(session, DRAGONFLY))
	_check(dropped.done(), "TEST-ONLY: one 竹蜻蜓 is enough")


## funlin.c: the 竹蜻蜓 for the secret; latemoon2.c's search; bracelet.c's pray.
func _test_bracelet(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"latemoon.manor", &"latemoon.entrance", &"latemoon.entrance", &"latemoon.entrance.cloud_entry").succeeded(), "back at the manor")
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	_place(map, player, &"latemoon.latemoon2", MapPlaces.service_spot(map, &"latemoon.latemoon2.search"))
	map.npc_life._advance_ambience(1.0)
	var search: ActService = map.service(&"latemoon.latemoon2.search") as ActService
	_check(search.in_reach() and map.interaction_title().contains("翻找"), "at the 碧纱橱: %s" % map.interaction_title())
	search.interact()
	_check(hud.log_lines()[-1] == "你盲目的找著，但无发现什么!" and _carried(session, BRACELET).is_empty(), "before 芳绫's secret: nothing")
	var funlin: NpcRuntimeState = _beside(map, session, &"latemoon.npc.funlin")
	map.npc_life._advance_ambience(1.0)
	_check(map.select_npc(funlin.character_id), "芳绫 selected")
	var traded: ItemHandlingResult = map.give_to_selected(_carried(session, DRAGONFLY))
	_check(traded.done() and traded.lines == ["芳绫很开心的拿起竹蜻蜓把玩!", "满怀感激的谢谢你! 她小声的在你耳边说：", "『 庄内前厅某处藏有一宝物手镯哦!』", "你可以找找看! (search bracelet)", "你给芳绫一个竹蜻蜓。"], "her four lines: %s" % [traded.lines])
	_check(player.temp_marks.get("moon/问题二", 0) == 1 and player.temp_marks.get("moon/竹蜻蜓", 0) == 1, "moon/问题二 and moon/竹蜻蜓")
	var again: ItemHandlingResult = map.give_to_selected(_new_item(session, DRAGONFLY))
	_check(again.done() and again.lines == ["芳绫说道：谢谢!我已经告诉你秘密了呀!去找呀!", "你给芳绫一个竹蜻蜓。"], "a second one: she says so and keeps it: %s" % [again.lines])
	_place(map, player, &"latemoon.latemoon2", MapPlaces.service_spot(map, &"latemoon.latemoon2.search"))
	map.npc_life._advance_ambience(1.0)
	search.interact()
	var bracelet: StringName = _carried(session, BRACELET)
	_check(not bracelet.is_empty() and hud.log_lines()[-1] == "你从橱子内取出玛瑙手镯。" and player.temp_marks.get("latemoon/手镯", 0) == 1, "the 玛瑙手镯")
	search.interact()
	_check(hud.log_lines()[-1] == "你翻箱倒柜想找出手镯，但似乎毫无所获。" and _count_carried(session, BRACELET) == 1, "only one")
	_check(not map.drop_item(bracelet).done(), "no_drop: it stays")
	var worn: OldPineArmorInteractionResult = session.wear_player_item(bracelet)
	_check(player.armor.is_worn(bracelet), "worn on the wrist: %s" % [worn.outcome])
	state.spirit = CharacterResourceState.new(40, 500, 500) # TEST-ONLY
	_check(map.act_with_item(bracelet) and hud.is_asking() and hud.confirm_prompt.message.text.contains("50 点神") and hud.confirm_prompt.message.text.contains("祈祷"), "40 sen: asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(state.spirit.current == 40 and session.active_map_id() == &"latemoon.manor" and not hud.is_asking(), "取消: nothing spent, still here (back in the 背包: the windowed walk)")
	hud.dismiss_current_panel()
	state.spirit = CharacterResourceState.new(300, 500, 500) # TEST-ONLY
	_check(map.act_with_item(bracelet) and not hud.is_asking(), "pray start")
	var location: WorldLocationState = player.world_location()
	_check(session.active_map_id() == SnowWorldDefinitions.OUTDOOR_MAP_ID and location.zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID and state.spirit.current == 250, "in Snow's temple, 50 sen spent")
	_check(hud.log_lines().has("你双手合掌，虔诚的祈祷。\n手上的镯子嗡嗡作响。 突然一阵烟雾...."), "its line")
	# From another map with too little sen: 确定, and the player falls where they arrive.
	_check(session.handoff_to(&"latemoon.manor", &"latemoon.entrance", &"latemoon.entrance", &"latemoon.entrance.cloud_entry").succeeded(), "TEST-ONLY: back at the manor")
	state.spirit = CharacterResourceState.new(30, 500, 500) # TEST-ONLY
	_check((session.active_map() as WorldMapController).act_with_item(bracelet) and hud.is_asking(), "30 sen: asked")
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID and player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "确定: prayed, and fallen in the temple")
	await _wake(tree, session)


## shinfun.c's 舞曲谱 marks the asker; latemoon8.c's bed gives the book once (the mark goes);
## study.c reads 音律 from it; book.c dances 「春宫怨」 back to the hall.
func _test_dance_book(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"latemoon.upper", &"latemoon.upstar.upstar1", &"latemoon.upstar.upstar1", &"latemoon.upstar.upstar1.stairs_arrival").succeeded(), "up the front tower")
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	var shinfun: NpcRuntimeState = _beside(map, session, &"latemoon.npc.upstar.shinfun")
	map.npc_life._advance_ambience(1.0)
	_check(map.select_npc(shinfun.character_id), "莫欣芳 selected")
	var answer: Array[String] = map.ask_selected("舞曲谱")
	_check(answer.size() == 2 and answer[1].begins_with("莫欣芳说道：舞曲谱啊，师姐她们练习舞步的时候才用的着") and state.marks.get("dance-book", 0) == 1, "her answer marks the asker: %s" % [answer])
	_check(session.handoff_to(&"latemoon.manor", &"latemoon.entrance", &"latemoon.entrance", &"latemoon.entrance.cloud_entry").succeeded(), "down at the manor")
	map = session.active_map() as WorldMapController
	_place(map, player, &"latemoon.latemoon8", MapPlaces.service_spot(map, &"latemoon.latemoon8.bed"))
	map.npc_life._advance_ambience(1.0)
	var bed: ActService = map.service(&"latemoon.latemoon8.bed") as ActService
	_check(bed.in_reach() and map.interaction_title().contains("石床"), "by the marble bed: %s" % map.interaction_title())
	bed.interact()
	var book: StringName = _carried(session, BOOK)
	_check(not book.is_empty() and hud.log_lines()[-1] == "你在石床后面找到了一本舞曲谱！" and not state.marks.has("dance-book"), "the 舞曲谱; the mark goes")
	bed.interact()
	_check(hud.log_lines()[-1] == "你在石床附近找了很久，结果一无所获。" and _count_carried(session, BOOK) == 1, "then nothing")
	var read: StudyResult = session.martial_arts().study(book)
	_check(read != null and read.outcome == StudyResult.Outcome.STUDIED and state.skills.raw_level(&"music") >= 0 and hud.log_lines()[-1] == "你研读有关音律的技巧，似乎有点心得。", "study: 音律: %s" % hud.log_lines()[-1])
	state.skills.set_raw_level(&"music", 61) # TEST-ONLY
	read = session.martial_arts().study(book)
	_check(read.outcome == StudyResult.Outcome.TOO_SHALLOW, "past 60 it teaches nothing")
	state.skills.set_raw_level(&"music", 0) # TEST-ONLY
	state.spirit = CharacterResourceState.new(300, 500, 500) # TEST-ONLY
	_check(map.act_with_item(book) and player.world_location().zone_id == &"latemoon.latemoon1" and state.spirit.current == 250, "「春宫怨」: to the hall, 50 sen")
	_check(hud.log_lines().has("你双手合掌，脚步轻盈。一曲『 春宫怨 』......"), "its line")
	_check(session.handoff_to(SnowWorldDefinitions.OUTDOOR_MAP_ID, SnowWorldDefinitions.TEMPLE_ZONE_ID, SnowWorldDefinitions.TEMPLE_ZONE_ID, SnowWorldDefinitions.REVIVE_SPAWN_ID).succeeded(), "TEST-ONLY: back to Snow")
	var snow: WorldMapController = session.active_map() as WorldMapController
	_check(snow.act_with_item(book) and session.active_map_id() == &"latemoon.manor" and player.world_location().zone_id == &"latemoon.latemoon1", "from Snow too: it dances anywhere")
	state.spirit = CharacterResourceState.new(20, 500, 500) # TEST-ONLY
	map = session.active_map() as WorldMapController
	_check(map.act_with_item(book) and hud.is_asking(), "20 sen: asked first")
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and player.world_location().zone_id == &"latemoon.latemoon1", "确定: danced, and fallen where she arrived")
	await _wake(tree, session)


## The 丝罗巾 in the second 密室 teaches 基本行动 (move.c).
func _test_hankie(tree: SceneTree, session: WorldSessionController) -> void:
	var hankie: StringName = _new_item(session, HANKIE)
	var state: CharacterState = session.player_runtime().state
	state.spirit = CharacterResourceState.new(300, 500, 500) # TEST-ONLY
	var read: StudyResult = session.martial_arts().study(hankie)
	_check(read.outcome == StudyResult.Outcome.STUDIED and session.shared_ui().log_lines()[-1] == "你研读有关基本行动的技巧，似乎有点心得。", "study: 基本行动")
	state.skills.set_raw_level(&"move", 51) # TEST-ONLY
	_check(session.martial_arts().study(hankie).outcome == StudyResult.Outcome.TOO_SHALLOW, "past 50 nothing")
	await tree.process_frame


## old.c: the 杀手令牌 for a 晚月庄 member's force below 160, else the 寒雪鞭法 book.
func _test_token(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var state: CharacterState = player.state
	var old: NpcRuntimeState = _beside(map, session, &"latemoon.npc.room.old")
	map.npc_life._advance_ambience(1.0)
	_check(map.select_npc(old.character_id), "无名老妇 selected")
	var told: Array[String] = map.ask_selected("心事")
	_check(told.size() == 2 and told[0] == "你向无名老妇打听有关『心事』的消息。" and told[1].begins_with("无名老妇说道：实不相瞒，这杀手是我的私生女"), "her trouble: %s" % [told])
	var refused: ItemHandlingResult = map.give_to_selected(_new_item(session, SKIRT))
	_check(not refused.done() and refused.lines == ["无名老妇没有收下。"], "anything but the token: accept_object() returns 0")
	var book: ItemHandlingResult = map.give_to_selected(_new_item(session, TOKEN))
	_check(book.done() and book.lines == ["无名老妇说道：作为感谢，我给你一本寒雪鞭法密笈。", "你给无名老妇一个杀手令牌。"] and not _carried(session, WHIP_BOOK).is_empty(), "not of 晚月庄: the 寒雪鞭法: %s" % [book.lines])
	state.family.family_id = &"family.latemoon" # TEST-ONLY: D makes the player one
	state.recovery.inner_force.maximum = 100
	state.recovery.inner_force.current = 80
	state.attributes.karma = 25
	var original: WorldInteractionRandomSource = map.world_interaction_random_source()
	map.replace_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([30])) # TEST-ONLY: random(50) = 30
	var force: ItemHandlingResult = map.give_to_selected(_new_item(session, TOKEN))
	map.replace_world_interaction_random_source(original)
	_check(force.done() and force.lines == ["无名老妇说道：作为感谢，我传你一些内力。", "无名老妇手抵在你的后心，头上冒出丝丝白气。", "你感觉到一股热气传了过来。", "你给无名老妇一个杀手令牌。"], "a member below 160: her force: %s" % [force.lines])
	_check(state.recovery.inner_force.maximum == 116 and state.recovery.inner_force.current == 0, "max_force 100 + 20 * 25 / 30 = 116, force 0: %d" % state.recovery.inner_force.maximum)
	_check(state.vitality.maximum == CharacterDerivedValues.human_maximum_vitality(player.facts.age, 116), "max kee follows at once (A7)")
	state.recovery.inner_force.maximum = 160
	var at_160: ItemHandlingResult = map.give_to_selected(_new_item(session, TOKEN))
	_check(at_160.done() and at_160.lines[0] == "无名老妇说道：作为感谢，我给你一本寒雪鞭法密笈。" and state.recovery.inner_force.maximum == 160, "at 160: the book")
	state.family.family_id = &""
	await tree.process_frame


## letter.c fire: with a 火摺 the letter's hidden lines, without 你身上没有火没法烧。
func _test_letter(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var letter: StringName = _new_item(session, LETTER)
	_check(map.act_with_item(letter) and hud.log_lines()[-1] == "你身上没有火没法烧。", "no fire")
	_new_item(session, FIRE)
	_check(map.act_with_item(letter), "with the 火摺")
	var lines: Array[String] = hud.log_lines()
	_check(lines[-2] == "你看见密函上出现几行字 :" and lines[-1].begins_with("师父:") and lines[-1].contains("原来晚月庄主是同性恋") and lines[-1].ends_with("的力量在里头。"), "the letter's lines, word for word: %s" % [lines.slice(-2)])
	_check(not _carried(session, LETTER).is_empty() and not _carried(session, FIRE).is_empty(), "neither is used up")
	await tree.process_frame


## The chain's set_temp() flags and marks/dance-book survive Continue (owner, after 乔阴 B).
func _test_continue(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.marks["dance-book"] = 1
	# TEST-ONLY: Continue recomputes max gin, kee and sen (race/human.c); the strong fixture
	# above set them by hand.
	CharacterDerivedValues.refresh_human_player_maxima(player.state, player.facts.age)
	for resource: CharacterResourceState in [player.state.essence, player.state.vitality, player.state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	_check(player.temp_marks.has("moon/问题二") and player.temp_marks.has("latemoon/手镯"), "temps before the save")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "Save")
	if snapshot == null:
		return
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(restored.succeeded(), "Continue: %s" % restored.path)
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), "activated")
	# Owner (after 乔阴 B): the set_temp() flags are saved too; 芳绫's secret survives Continue.
	_check(fresh.player_runtime().temp_marks.has("moon/问题二") and fresh.player_runtime().temp_marks.has("latemoon/手镯") and fresh.player_runtime().state.marks.get("dance-book", 0) == 1, "the temps and the mark stay")
	fresh.free()
	await tree.process_frame
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "晚月庄 C")
	_check(walker._failures.is_empty(), "Save/Continue exact: " + str(walker._failures))


func _wake(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(500, 500, 500)
	(session.active_map() as WorldMapController).runtime_player_body().refresh_runtime_state()
	await tree.process_frame


func _beside(map: WorldMapController, session: WorldSessionController, definition_id: StringName) -> NpcRuntimeState:
	var npc: NpcRuntimeState = null
	for candidate: NpcRuntimeState in map.npc_runtimes():
		if candidate.definition().definition_id == definition_id:
			npc = candidate
	var body: WorldCharacterBody2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = Vector2.INF if body == null else MapPlaces.spot(map, npc.world_location().zone_id, body.global_position, 90.0)
	_check(at != Vector2.INF and _place(map, session.player_runtime(), npc.world_location().zone_id, at), "TEST-ONLY: beside %s" % definition_id)
	return npc


func _place(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, at: Vector2) -> bool:
	map.runtime_player_body().global_position = at
	return player.set_world_location(map.location_for_zone(zone_id))


## TEST-ONLY: a new item in the player's hands, as an NPC's give would make it.
func _new_item(session: WorldSessionController, definition_id: StringName) -> StringName:
	var id: StringName = (session.active_map() as WorldMapController).give_new_item_to_player(definition_id)
	return id if session.inventory_state().is_registered(id) else _carried(session, definition_id)


func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in session.inventory_state().direct_children(carried):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _count_carried(session: WorldSessionController, definition_id: StringName) -> int:
	var count: int = 0
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in session.inventory_state().direct_children(carried):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
