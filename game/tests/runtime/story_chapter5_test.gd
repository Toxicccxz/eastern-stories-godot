extends RefCounted

## 第五章 人证 (owner's plan, 2026-10-30; DECISIONS「第五章 人证」), from the two fourth-chapter ledgers
## (StoryFixtures), two sessions:
## - escorted (kept, a woman): the 大皮鼓 refused empty-handed (空口无凭), beaten with the 兵部文书 and
##   confirmed (magistra.c's 是你击鼓申冤吗, 好吧，跟我来), the 衙门大门 found open on both maps; 程不平 wants
##   a witness and names the 武官; 陈显祖 admits the deserter; the hollow's two 鬼卒 and the chest's 翻看
##   (the 抄本); the 带刀侍卫's refused order; 作证: he follows every way; on the 福林大街 庾家's steward
##   speaks, 陈显祖 answers, three men come and fall on the player (fled TEST-ONLY); the 大堂's six lines,
##   the letter in hand, 陈显祖 into the 内厅 as the 人证, the 武官 off the hotel's stage, 供词 有力; the
##   sixth chapter's objective.
## - released (taken, a man): the chest returned first (the 白杨经 as 乔阴 B), the 抄本 from his own hand;
##   走吧 refused while he has no chest, then taken: gone at once; the 大堂's four lines (纸能证纸，不能证人),
##   the letter all the same, 供词 迟疑, 汤掌柜's word.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const PAPERS: StringName = &"native:niling/war_ministry_papers"
const COPY: StringName = &"native:choyin/decree_copy"
const LETTER: StringName = &"native:choyin/magistrate_letter"
const CHEST: StringName = &"es2:d/choyin/obj/chest"
const BOOK: StringName = &"es2:d/choyin/obj/magic_book"
const SERGEANT: StringName = &"choyin.npc.sergeant"
const STEWARD: StringName = &"native.npc.yu_steward"
const HENCHMAN: StringName = &"native.npc.yu_henchman"
const GHOUL: StringName = &"native.npc.hell_runner"
const WITNESS: StringName = &"native.npc.chen_witness"
const GATE: StringName = &"choyin.court1.gate"

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
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter5")
	_check(quest != null and quest.requires == [&"main.chapter4"] and quest.steps.size() == 7 and quest.steps[5].options.size() == 2 and quest.steps[5].options[0].option_id == &"escort" and quest.steps[5].options[1].option_id == &"release", "the chapter: seven steps after the fourth, a two-way choice before the trial")
	var stub: StoryQuestDefinition = catalog.story_quest(&"main.chapter6")
	_check(stub != null and stub.requires == [&"main.chapter5"] and stub.steps.size() == 9 and stub.steps[0].objective.begins_with("带着程不平的信去天驼关军营"), "the sixth chapter follows the fifth, its first step at the camp (关北 A, B)")
	var copy: ItemContentDefinition = catalog.item(COPY)
	var letter: ItemContentDefinition = catalog.item(LETTER)
	_check(copy != null and copy.no_drop and copy.aliases().has("抄本") and letter != null and letter.no_drop and letter.aliases().has("信"), "the 抄本 and the letter: no_drop, answering to 抄本 and 信")
	var gate: DoorDefinition = catalog.door(GATE)
	_check(gate != null and gate.found_by == "击了鼓" and not gate.operable and not gate.closable and not gate.starts_open and gate.zone_ids() == [&"choyin.court1", &"choyin.yamen_yard"], "the 衙门大门: found by the drum, worked by no hand, open ever after, between the gate and the yard")
	_check(catalog.portal(&"choyin.court1.north") != null and catalog.portal(&"choyin.court1.north").destination_zone_id == &"choyin.yamen_yard", "a way in through the gate now")
	var drum: ServiceDefinition = catalog.service(&"choyin.court1.drum")
	_check(drum != null and drum.act != null and drum.act.verb == "击鼓" and drum.act.acts.size() == 3 and drum.act.acts[1].carries == "文书" and not drum.act.acts[1].ask.is_empty(), "the 大皮鼓: an act of three branches, the second for one carrying the 文书, asked first")
	var sergeant: NpcDefinition = catalog.npc(SERGEANT)
	_check(sergeant != null and sergeant.hooks() != null and sergeant.hooks().follows_every_way and sergeant.hooks().moods.has("going") and sergeant.hooks().moods["going"].flags == [NpcDefinition.FLAG_FOLLOWS_PLAYER], "陈显祖 follows every way in his mood 'going'")
	_check(sergeant.talk().inquiry_topics().slice(0, 6) == ["name", "here", "rumors", "箱子", "桃木箱子", "陈显祖"] and sergeant.talk().inquiry_topics().has("作证") and sergeant.talk().inquiry_topics().has("走吧"), "sergeant.c's six topics first, the new ones after: %s" % [sergeant.talk().inquiry_topics()])
	var steward: NpcDefinition = catalog.npc(STEWARD)
	_check(steward != null and steward.hooks() != null and steward.hooks().scene_mark == "见过庾家拦路" and steward.hooks().calls.size() == 3 and steward.hooks().moods["fighting"].flags == [NpcDefinition.FLAG_AGGRESSIVE] and steward.attitude != NpcDefinition.Attitude.AGGRESSIVE, "the steward: a three-call scene, aggressive only in his mood")
	var judge: NpcDefinition = catalog.npc(&"choyin.npc.judgeman")
	_check(judge != null and judge.hooks() != null and judge.hooks().scene_mark == "堂审过" and judge.hooks().calls.size() == 9 and judge.hooks().calls[0].act.present == SERGEANT and judge.hooks().calls[5].act.mark == "放走了陈显祖" and judge.dealings().sentence != null, "程不平: two trials (five calls with 陈显祖, four without), his 乔阴 D sentence untouched")
	var chest: ItemContentDefinition = catalog.item(CHEST)
	_check(chest != null and chest.act != null and chest.act.verb == "翻看" and chest.act.acts.size() == 2 and chest.act.acts[0].mark == "看过寻剑令抄本", "the 桃木箱: 翻看 once")
	var ghouls: NpcSpawnDefinition = catalog.spawn(&"native.tomb3.hell_runners")
	_check(ghouls != null and ghouls.quantity == 2 and ghouls.present != null and ghouls.zone_id == &"choyin.tomb3", "two 鬼卒 in the hollow's sandalwood end while the chapter runs")
	var hotel: NpcSpawnDefinition = catalog.spawn(&"choyin.hotel_house.hotel1.sergeant")
	_check(hotel != null and hotel.until != null and hotel.present == null, "the 武官's spawn leaves the stage once the choice is made")
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.SOURCE_ENTRY_GUANBEI_B_V1, "关北 B's world revision is current")


## A woman from the kept robe: the drum, the magistrate, the deserter, the hollow, the escort, the trial.
func _test_escorted(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter5")
	StoryFixtures.chapter4_kept(session)
	session.record_journal()
	_check(state.quests.has("main.chapter5#started") and StoryQuestLog.objective(state, quests).begins_with("带着逆灵宫那叠"), "the chapter begins as the fourth ends: %s" % [StoryQuestLog.objective(state, quests)])
	# The 衙门口 (TEST-ONLY: straight there): the drum without the papers.
	var town: WorldMapController = MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	_check(town != null, "at the 衙门口")
	await _settle(tree)
	var drum: ActService = town.service(&"choyin.court1.drum") as ActService
	_check(town.place_player(&"choyin.court1", MapPlaces.service_spot(town, &"choyin.court1.drum")), "TEST-ONLY: by the drum")
	await _settle(tree)
	_check(drum != null and drum.in_reach() and drum.verb() == "击鼓", "大皮鼓 · 击鼓 in reach")
	_check(not town.doors_by_id[GATE].is_open() and town.door_shut_between(&"choyin.court1", &"choyin.yamen_yard"), "the 衙门大门 shut")
	drum.interact()
	await _settle(tree)
	_check(not ui.is_asking() and _recent(ui, 4).any(func(line: String) -> bool: return line.contains("空口无凭")) and state.marks.get("击了鼓", 0) == 0 and not town.doors_by_id[GATE].is_open(), "empty-handed: 空口无凭, the gate stays shut: %s" % [_recent(ui, 4)])
	# With the papers (TEST-ONLY: given; the game's lie in the 逆灵宫's 账房): asked, confirmed, the gate found.
	town.give_new_item_to_player(PAPERS)
	drum.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("是你击鼓申冤吗"), "asked first: %s" % ui.confirm_prompt.message.text)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(_recent(ui).any(func(line: String) -> bool: return line.contains("好吧，跟我来")) and state.marks.get("击了鼓", 0) == 1 and town.doors_by_id[GATE].is_open(), "好吧，跟我来....: the mark, the gate open: %s" % [_recent(ui)])
	session.record_journal()
	_check(state.quests.has("main.chapter5/drum") and StoryQuestLog.objective(state, quests).begins_with("进大堂"), "the drum step done; the 大堂 next: %s" % [StoryQuestLog.objective(state, quests)])
	drum.interact()
	await _settle(tree)
	_check(_recent(ui, 3).any(func(line: String) -> bool: return line.contains("鼓已经击过了")), "beaten again: 鼓已经击过了")
	# Through the gate into the yard (walked), the yard's own gate open too, then the 大堂.
	_check(await MapPlaces.take_passage(tree, town, &"choyin.court1.north"), "north through the gate")
	await _settle(tree)
	var yamen: WorldMapController = session.active_map() as WorldMapController
	_check(yamen != null and yamen.map_id() == &"choyin.yamen_compound" and session.player_runtime().world_location().zone_id == &"choyin.yamen_yard" and yamen.doors_by_id[GATE].is_open(), "in the 县衙内院, the gate open from this side too: %s" % [session.player_runtime().world_location().zone_id])
	var judge: NpcRuntimeState = await _beside(tree, session, yamen, &"choyin.yamen.judgeman.1")
	_check(not session.scene_held(), "no trial yet: no 抄本")
	var said: Array[String] = _ask(yamen, judge, "兵部文书")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("纸能证纸，不能证人")) and said.any(func(line: String) -> bool: return line.contains("福林酒楼")) and state.marks.get("程不平要人证", 0) == 1 and state.quests.has("main.chapter5/hear") and StoryQuestLog.objective(state, quests).begins_with("福林酒楼里丢了箱子的武官"), "程不平 wants a witness, names the 武官: %s" % [said])
	_check(_ask(yamen, judge, "供词").any(func(line: String) -> bool: return line.contains("还没有供词")), "no 供词 yet")
	# The 福林酒楼 (TEST-ONLY: straight there): 陈显祖 shown the seal.
	var hotel: WorldMapController = MapPlaces.enter(session, &"choyin.hotel1", &"choyin.hotel1.s_street2_entry")
	_check(hotel != null, "in the 福林酒楼")
	await _settle(tree)
	var chen: NpcRuntimeState = await _beside(tree, session, hotel, &"choyin.hotel1.sergeant.1")
	_check(_ask(hotel, chen, "抄本").any(func(line: String) -> bool: return line.contains("什么抄本")), "before the seal: 什么抄本")
	said = _ask(hotel, chen, "兵部")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("跑了的那个")) and said.any(func(line: String) -> bool: return line.contains("树王坟的树洞")) and state.marks.get("陈显祖认了", 0) == 1 and state.quests.has("main.chapter5/chen") and StoryQuestLog.objective(state, quests).begins_with("寻剑令的抄本在陈显祖的桃木箱里"), "陈显祖 admits the deserter and the 抄本 in the chest: %s" % [said])
	_check(_ask(hotel, chen, "抄本").any(func(line: String) -> bool: return line.contains("在箱子底板的夹层里")), "the 抄本 is in the chest he lost")
	_check(_ask(hotel, chen, "走吧").any(func(line: String) -> bool: return line.contains("箱子还没回到我手里")) and _count_in(session, &"choyin.hotel1", SERGEANT) == 1 and state.marks.get("放走了陈显祖", 0) == 0, "走吧 before the chest is his again: refused, he stays")
	# The hollow (TEST-ONLY: straight into the sandalwood end): two 鬼卒 by the chest, the chest's 翻看.
	var hollow: WorldMapController = MapPlaces.enter(session, &"choyin.tomb1", &"choyin.tomb1.hole_arrival")
	_check(hollow != null and hollow.map_id() == &"choyin.tree_hollow", "in the hollow")
	await _settle(tree)
	_check(_count_in(session, &"choyin.tomb3", GHOUL) == 2 and _count_in(session, &"choyin.tomb1", &"choyin.npc.shadow") == 3, "two 鬼卒 in the sandalwood end; tomb1.c's three 朦胧鬼影 as they were")
	# TEST-ONLY: the 朦胧鬼影 at the foot of the hole fall on the player (乔阴 B's suite is theirs): fled, and out of the way.
	await _flee(tree, session)
	_clear(hollow, &"choyin.npc.shadow")
	var chest_id: StringName = hollow.floor_items.floor_item_of(CHEST, &"choyin.tomb3")
	var chest_view: WorldFloorItemView = null if chest_id.is_empty() else hollow.floor_items.floor_item_view(chest_id)
	_check(chest_view != null and hollow.place_player(&"choyin.tomb3", MapPlaces.spot(hollow, &"choyin.tomb3", chest_view.global_position, 48.0)), "TEST-ONLY: by the 桃木箱")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if session.combat_encounter_coordinator().has_active_encounter():
			break
	_check(session.combat_encounter_coordinator().has_active_encounter(), "the 鬼卒 fall on the player")
	await _flee(tree, session)
	# TEST-ONLY: the 鬼卒 leave as if beaten (the clearing counts them gone).
	_clear(hollow, GHOUL)
	session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	session.record_journal()
	_check(state.marks.get("树洞的鬼卒倒了", 0) == 1, "the 鬼卒 cleared: 树洞的鬼卒倒了")
	_check(hollow.floor_items.select_floor_item(chest_id) and hollow.floor_items.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "the 桃木箱 picked up")
	var chest: StringName = _carried(session, CHEST)
	_check(not chest.is_empty() and hollow.act_with_item(chest), "翻看 the 桃木箱")
	await _settle(tree)
	_check(_recent(ui).any(func(line: String) -> bool: return line.contains("夹层里是一卷发黄的纸")) and not _carried(session, COPY).is_empty() and state.marks.get("看过寻剑令抄本", 0) == 1, "the 抄本 out of the false bottom: %s" % [_recent(ui, 4)])
	session.record_journal()
	_check(state.quests.has("main.chapter5/copy") and StoryQuestLog.objective(state, quests).begins_with("县衙的带刀侍卫"), "the 抄本 in hand; the 侍卫 next: %s" % [StoryQuestLog.objective(state, quests)])
	_check(hollow.act_with_item(chest) and _recent(ui, 3).any(func(line: String) -> bool: return line.contains("夹层空了")), "翻看 again: 夹层空了")
	_check(hollow.drop_item(_carried(session, COPY)).lines.any(func(line: String) -> bool: return line.contains("不能随便丢")), "the 抄本 cannot be dropped")
	# The 带刀侍卫 at the gate: the refused order.
	town = MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	await _settle(tree)
	var guard: NpcRuntimeState = await _beside(tree, session, town, &"choyin.court1.magistra.1")
	said = _ask(town, guard, "兵部的令")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("老王爷拒了")) and state.marks.get("侍卫说了拒令", 0) == 1 and state.quests.has("main.chapter5/guard") and StoryQuestLog.objective(state, quests).begins_with("护送陈显祖进衙门作证"), "the 侍卫: 老王爷拒了; the choice next: %s" % [said])
	_check(_ask(town, guard, "老王爷").any(func(line: String) -> bool: return line.contains("槐阳王程老王爷")), "老王爷: 槐阳王")
	# 作证: he follows.
	hotel = MapPlaces.enter(session, &"choyin.hotel1", &"choyin.hotel1.s_street2_entry")
	await _settle(tree)
	chen = await _beside(tree, session, hotel, &"choyin.hotel1.sergeant.1")
	_check(_ask(hotel, chen, "抄本").any(func(line: String) -> bool: return line.contains("抄本你已经拿了")), "抄本 taken: 你已经拿了")
	_check(_ask(hotel, chen, "走吧").any(func(line: String) -> bool: return line.contains("你先把箱子还我")) and _count_in(session, &"choyin.hotel1", SERGEANT) == 1 and state.marks.get("放走了陈显祖", 0) == 0, "走吧 with his chest still in the player's pack: refused, he stays (Codex review)")
	said = _ask(hotel, chen, "作证")
	_check(said.any(func(line: String) -> bool: return line.contains("我跟你去")) and chen.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) and chen.has_flag(StringName(NpcMood.FLAG_PREFIX + "going")) and state.marks.get("陈显祖跟你走了", 0) == 1, "作证: he follows: %s" % [said])
	_check(_ask(hotel, chen, "走吧").any(func(line: String) -> bool: return line.contains("已经答应跟你去了")), "走吧 now: he keeps his word")
	# Out by the hall's door onto the 福林大街 (walked): 庾家's men.
	_check(await MapPlaces.take_passage(tree, hotel, &"choyin.hotel1.west"), "out of the 福林楼 by its door")
	await _settle(tree)
	town = session.active_map() as WorldMapController
	_check(town != null and town.map_id() == &"choyin.town" and session.player_runtime().world_location().zone_id == &"choyin.s_street2", "on the 福林大街")
	if _count_in(session, &"choyin.s_street2", SERGEANT) == 0:
		_check(session.bring_npc_onto(chen, hotel, town, &"choyin.s_street2"), "TEST-ONLY: 陈显祖 brought along (he follows every way)")
	_check(_count_in(session, &"choyin.s_street2", SERGEANT) == 1 and _count_in(session, &"choyin.s_street2", STEWARD) == 1 and _count_in(session, &"choyin.s_street2", HENCHMAN) == 0, "陈显祖 beside you; the steward on the street, his men not yet")
	for second: int in 10:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if _count_in(session, &"choyin.s_street2", HENCHMAN) == 3 and session.combat_encounter_coordinator().has_active_encounter():
			break
	var lines: Array[String] = _recent(ui, 16)
	_check(lines.any(func(line: String) -> bool: return line.contains("兵部有令拿你")) and lines.any(func(line: String) -> bool: return line.contains("二十年了，还是找来了")) and lines.any(func(line: String) -> bool: return line.contains("冲的是你")), "the steward's word, 陈显祖's answer, 动手: %s" % [lines])
	_check(state.marks.get("见过庾家拦路", 0) == 1 and _count_in(session, &"choyin.s_street2", HENCHMAN) == 3 and session.combat_encounter_coordinator().has_active_encounter(), "three men summoned, the fight on")
	var steward: NpcRuntimeState = MapPlaces.npc_at(session, &"choyin.s_street2.yu_steward.1")
	_check(steward != null and steward.has_flag(NpcDefinition.FLAG_AGGRESSIVE) and steward.has_flag(StringName(NpcMood.FLAG_PREFIX + "fighting")), "the steward turned aggressive (his mood 动手)")
	_check(_count_in(session, &"choyin.s_street2", SERGEANT) == 1 and chen.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "陈显祖 stands untouched: they fight the player")
	await _flee(tree, session)
	# TEST-ONLY: 庾家's men leave as if beaten (the clearing counts them gone).
	_clear(town, HENCHMAN)
	_clear(town, STEWARD)
	session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	session.record_journal()
	_check(state.marks.get("福林大街的庾家人倒了", 0) == 1, "庾家's men down: the mark")
	# The 大堂 (TEST-ONLY: straight there, 陈显祖 brought along): the trial.
	yamen = MapPlaces.enter(session, &"choyin.yamen_yard", &"choyin.yamen_yard.gate_arrival")
	_check(yamen != null, "in the 县衙内院")
	await _settle(tree)
	if _count_in(session, &"choyin.yamen", SERGEANT) == 0:
		_check(session.bring_npc_onto(chen, town, yamen, &"choyin.yamen"), "TEST-ONLY: 陈显祖 brought into the 大堂")
	_check(_count_in(session, &"choyin.yamen", SERGEANT) == 1, "陈显祖 in the 大堂")
	# The scene is judged as the player comes into the hall, 陈显祖 already standing there (TEST-ONLY: placed).
	judge = await _beside(tree, session, yamen, &"choyin.yamen.judgeman.1")
	var log_before: int = ui.log_lines().size()
	for second: int in 22:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if state.marks.get("程不平写了信", 0) == 1:
			break
	lines = _recent(ui, 24)
	_check(lines.any(func(line: String) -> bool: return line.contains("堂下何人")) and lines.any(func(line: String) -> bool: return line.contains("罪人陈显祖")) and lines.any(func(line: String) -> bool: return line.contains("印是兵部的，令不是先帝的。录了")) and lines.any(func(line: String) -> bool: return line.contains("军营的门会开")) and lines.any(func(line: String) -> bool: return line.contains("领着陈显祖进了内厅")), "the trial's six lines: %s" % [lines])
	_check(not _carried(session, LETTER).is_empty() and state.marks.get("陈显祖进了大堂", 0) == 1 and state.marks.get("陈显祖作了证", 0) == 1 and state.marks.get("程不平写了信", 0) == 1 and state.marks.get("堂审过", 0) == 1, "the letter in hand, the marks")
	_check(_count_in(session, &"choyin.yamen", SERGEANT) == 0, "陈显祖 led into the 内厅 (gone from the hall)")
	session.record_journal()
	_check(state.quests.has("main.chapter5/choice/escort") and state.quests.has("main.chapter5/trial") and StoryQuestLog.is_done(state, quest) and DeedLog.done(state, "护送陈显祖上了乔阴县的公堂") and DeedLog.done(state, "把寻剑令的真相递到了乔阴县的公堂上") and state.marks.get("人证一章", 0) == 1, "the chapter done by the escort")
	_check(state.quests.has("main.chapter6#started") and StoryQuestLog.objective(state, quests).begins_with("带着程不平的信去天驼关"), "the sixth chapter's objective shows: %s" % [StoryQuestLog.objective(state, quests)])
	_check(_ask(yamen, judge, "供词").any(func(line: String) -> bool: return line.contains("供词有力")), "供词: 有力")
	_check(_ask(yamen, judge, "人证").any(func(line: String) -> bool: return line.contains("陈显祖在内厅")), "人证: 陈显祖在内厅")
	# Out and in again: the 人证 in the 内厅, the 武官 off the hotel's stage, 汤掌柜's word.
	town = MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	await _settle(tree)
	yamen = MapPlaces.enter(session, &"choyin.yamen", &"choyin.yamen.hall_entry")
	await _settle(tree)
	_check(yamen != null and _count_in(session, &"choyin.yamen_iner", WITNESS) == 1, "陈显祖 the 人证 in the 内厅")
	var witness: NpcRuntimeState = await _beside(tree, session, yamen, &"choyin.yamen_iner.chen_witness.1")
	_check(_ask(yamen, witness, "供词").any(func(line: String) -> bool: return line.contains("原令只一句")), "the witness: 原令只一句")
	hotel = MapPlaces.enter(session, &"choyin.hotel1", &"choyin.hotel1.s_street2_entry")
	await _settle(tree)
	_check(hotel != null and _count_in(session, &"choyin.hotel1", SERGEANT) == 0, "no 武官 at the 福林酒楼 any more")
	var boss: NpcRuntimeState = await _beside(tree, session, hotel, &"choyin.hotel1.boss.1")
	_check(_ask(hotel, boss, "武官").any(func(line: String) -> bool: return line.contains("进了衙门就没再回来")), "汤掌柜: 进了衙门就没再回来")
	var snapshot: GameSaveSnapshot = _capture(session)
	_check(snapshot != null, "Save")


## A man from the taken robe: the chest returned first, the 抄本 from his hand, 走吧, the trial without him.
func _test_released(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter5")
	StoryFixtures.chapter4_taken(session)
	session.record_journal()
	_check(state.quests.has("main.chapter5#started"), "the chapter begins after the taken robe too")
	# The drum with the papers (TEST-ONLY: given), the magistrate.
	var town: WorldMapController = MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	await _settle(tree)
	town.give_new_item_to_player(PAPERS)
	var drum: ActService = town.service(&"choyin.court1.drum") as ActService
	_check(town.place_player(&"choyin.court1", MapPlaces.service_spot(town, &"choyin.court1.drum")), "TEST-ONLY: by the drum")
	await _settle(tree)
	drum.interact()
	await _settle(tree)
	_check(ui.is_asking(), "asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(state.marks.get("击了鼓", 0) == 1 and town.doors_by_id[GATE].is_open(), "the gate found")
	var yamen: WorldMapController = MapPlaces.enter(session, &"choyin.yamen", &"choyin.yamen.hall_entry")
	await _settle(tree)
	var judge: NpcRuntimeState = await _beside(tree, session, yamen, &"choyin.yamen.judgeman.1")
	_ask(yamen, judge, "兵部文书")
	session.record_journal()
	_check(state.marks.get("程不平要人证", 0) == 1, "程不平 wants a witness")
	# The hollow: the chest taken, not searched; the 福林酒楼: returned (乔阴 B), the 抄本 from his hand.
	var hollow: WorldMapController = MapPlaces.enter(session, &"choyin.tomb1", &"choyin.tomb1.hole_arrival")
	await _settle(tree)
	_check(hollow != null and _count_in(session, &"choyin.tomb3", GHOUL) == 2, "two 鬼卒 here too")
	await _flee(tree, session) # TEST-ONLY: the 朦胧鬼影 at the hole's foot
	_clear(hollow, &"choyin.npc.shadow")
	_clear(hollow, GHOUL) # TEST-ONLY: as if beaten
	var chest_id: StringName = hollow.floor_items.floor_item_of(CHEST, &"choyin.tomb3")
	var chest_view: WorldFloorItemView = null if chest_id.is_empty() else hollow.floor_items.floor_item_view(chest_id)
	_check(chest_view != null and hollow.place_player(&"choyin.tomb3", MapPlaces.spot(hollow, &"choyin.tomb3", chest_view.global_position, 48.0)), "TEST-ONLY: by the 桃木箱")
	await _settle(tree)
	_check(hollow.floor_items.select_floor_item(chest_id) and hollow.floor_items.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "the 桃木箱 picked up, unsearched")
	var hotel: WorldMapController = MapPlaces.enter(session, &"choyin.hotel1", &"choyin.hotel1.s_street2_entry")
	await _settle(tree)
	var chen: NpcRuntimeState = await _beside(tree, session, hotel, &"choyin.hotel1.sergeant.1")
	var said: Array[String] = _ask(hotel, chen, "兵部")
	session.record_journal()
	_check(state.marks.get("陈显祖认了", 0) == 1 and state.quests.has("main.chapter5/chen"), "陈显祖 admits it: %s" % [said])
	_check(hotel.select_npc(chen.character_id), "陈显祖 selected")
	var gift: ItemHandlingResult = hotel.give_to_selected(_carried(session, CHEST))
	_check(gift.done() and gift.lines.any(func(line: String) -> bool: return line.contains("就是这个箱子")) and not _carried(session, BOOK).is_empty() and chen.has_flag(&"chest_found"), "the chest returned: the 白杨经 as 乔阴 B: %s" % [gift.lines])
	said = _ask(hotel, chen, "抄本")
	_check(said.any(func(line: String) -> bool: return line.contains("抠开底板")) and said.any(func(line: String) -> bool: return line.contains("武官给你一卷寻剑令抄本")) and not _carried(session, COPY).is_empty() and state.marks.get("看过寻剑令抄本", 0) == 1, "the 抄本 from his own hand: %s" % [said])
	session.record_journal()
	_check(state.quests.has("main.chapter5/copy") and StoryQuestLog.objective(state, quests).begins_with("县衙的带刀侍卫"), "the 抄本 step done by his hand")
	# 走吧: he goes at once, chest and all.
	said = _ask(hotel, chen, "走吧")
	session.record_journal()
	_check(said.any(func(line: String) -> bool: return line.contains("就不用我这张嘴了")) and said.any(func(line: String) -> bool: return line.contains("再没有回头")) and state.marks.get("放走了陈显祖", 0) == 1, "走吧: his thanks, gone: %s" % [said])
	_check(_count_in(session, &"choyin.hotel1", SERGEANT) == 0 and chen.has_flag(NpcDefinition.FLAG_GONE), "陈显祖 gone for good")
	_check(not state.quests.has("main.chapter5/choice/release"), "the choice waits on the 侍卫's step before it (the plan's order)")
	var boss: NpcRuntimeState = await _beside(tree, session, hotel, &"choyin.hotel1.boss.1")
	_check(_ask(hotel, boss, "武官").any(func(line: String) -> bool: return line.contains("抱着他的箱子走了")), "汤掌柜: 抱着他的箱子走了")
	# The 侍卫 (the steps are the plan's; the mark is read when reached), then the 大堂 without him.
	town = MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	await _settle(tree)
	_ask(town, await _beside(tree, session, town, &"choyin.court1.magistra.2"), "兵部的令")
	session.record_journal()
	_check(state.quests.has("main.chapter5/guard") and state.quests.has("main.chapter5/choice/release") and DeedLog.done(state, "放陈显祖带着箱子走了") and StoryQuestLog.objective(state, quests).begins_with("堂审"), "the 侍卫 asked; the release recorded; the trial next: %s" % [StoryQuestLog.objective(state, quests)])
	_check(_count_in(session, &"choyin.s_street2", STEWARD) == 0, "nobody of 庾家's on the street: he never left with you")
	yamen = MapPlaces.enter(session, &"choyin.yamen", &"choyin.yamen.hall_entry")
	await _settle(tree)
	judge = await _beside(tree, session, yamen, &"choyin.yamen.judgeman.1")
	for second: int in 18:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if state.marks.get("程不平写了信", 0) == 1:
			break
	var lines: Array[String] = _recent(ui, 16)
	_check(lines.any(func(line: String) -> bool: return line.contains("人证呢")) and lines.any(func(line: String) -> bool: return line.contains("纸能证纸，不能证人。你放他走了")) and lines.any(func(line: String) -> bool: return line.contains("他信不信，本县不敢说")) and lines.any(func(line: String) -> bool: return line.contains("退堂")), "the trial's four lines without him: %s" % [lines])
	_check(not _carried(session, LETTER).is_empty() and state.marks.get("只留了文书", 0) == 1 and state.marks.get("程不平写了信", 0) == 1 and state.marks.get("陈显祖作了证", 0) == 0, "the letter all the same; no witness")
	session.record_journal()
	_check(StoryQuestLog.is_done(state, quest) and state.quests.has("main.chapter6#started") and StoryQuestLog.objective(state, quests).begins_with("带着程不平的信去天驼关"), "the chapter done by the release; the sixth's objective: %s" % [StoryQuestLog.objective(state, quests)])
	_check(_ask(yamen, judge, "供词").any(func(line: String) -> bool: return line.contains("迟疑了半晌")), "供词: 迟疑")
	town = MapPlaces.enter(session, &"choyin.court1", &"choyin.court1.yamen_return")
	await _settle(tree)
	yamen = MapPlaces.enter(session, &"choyin.yamen", &"choyin.yamen.hall_entry")
	await _settle(tree)
	_check(yamen != null and _count_in(session, &"choyin.yamen_iner", WITNESS) == 0, "no 人证 in the 内厅")
	hotel = MapPlaces.enter(session, &"choyin.hotel1", &"choyin.hotel1.s_street2_entry")
	await _settle(tree)
	_check(hotel != null and _count_in(session, &"choyin.hotel1", SERGEANT) == 0, "the 武官's stool empty (until release)")
	var snapshot: GameSaveSnapshot = _capture(session)
	_check(snapshot != null, "Save")


## TEST-ONLY: the player beside the NPC of `point_id`, a heart beat after (its reaction call or scene).
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, point_id: StringName) -> NpcRuntimeState:
	var npc: NpcRuntimeState = MapPlaces.npc_at(session, point_id)
	var body: Node2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	_check(npc != null and body != null and map.place_player(npc.world_location().zone_id, body.global_position + Vector2(0, 56)), "TEST-ONLY: beside %s" % point_id)
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	return npc


## The log's last lines (the log keeps only MAX_LOG_LINES, so an index taken earlier is no anchor).
func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _flee(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		for info: CombatTacticalActionInfo in coordinator.action_infos():
			if info.action_id == CombatFleeTacticalPolicy.ACTION_ID:
				coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % rounds), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	for _frame: int in range(3):
		await tree.physics_frame


## TEST-ONLY: every standing NPC of `definition_id` on the map leaves for good (as if beaten).
func _clear(map: WorldMapController, definition_id: StringName) -> void:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			map.npcs.leave_for_good(npc)


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
	session.configure_source_entry("人证", gender)
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


func _capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-30T00:00:00Z")
	if result.snapshot == null:
		print("capture rejected: ", result.path, " ", result.detail)
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
