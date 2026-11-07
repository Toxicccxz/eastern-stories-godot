extends RefCounted

## 第八章 湖底封物, package A (owner's plan build/plans/第八章_计划.md, 2026-11-06「按推荐，开工 A」; DECISIONS
## 「第八章 A」「寒气」「冰龙守者」), from the seventh chapter's two ledgers (StoryFixtures.chapter7_done):
## - keep (the 大秦人's side): from the lake's boat the dive (asked first; 下了湖底); the 玄冰岩洞's cold
##   (the native hazard: 内力 holds it off, then kee goes; the 寒於宝衣 worn spares it; 经典 has none);
##   the 冰壁刻字 read by one who read the 铜牒; into the dragons' hall — the guardians look and coil
##   back (到了冰龙厅), no fight; the pool's light, the dive down (asked first; 看过封坛); the 封坛, the
##   walls; 璃虹's three lines from her pillar, 商玦 come down after her (his two beats); the 铜牒
##   recited to her — a wrong answer refused, the three true ones and her 封法 (璃虹说了封法); 封坛 ·
##   看清了: her feather, 商玦 gone in smoke, the chapter done and the ninth's stub open; 潭口 · 游上去
##   back to the hall.
## - pull (the 浪人's side): the same way down, then 穿灵 · 拔出来 refused before the 封法, asked first
##   after; the sword in hand (no drop), the head awake (the 封坛's second look), 璃虹 gone from her
##   pillar and fallen beside the 封坛 (the summoned 璃虹), 商玦 gone; the chapter not yet done (the night
##   waits); a save; 璃虹 up the pool with the player and gone to the village. Then (B) the night: the
##   fishermen gone and one dead on the shore, 湖畔 · 等到天黑 (asked first) and the three bands of 鬼卒
##   up out of the lake as night falls — the lakeside's on the player at once, the village's mouth and
##   the paddies walked to — each fought out and its mark; the chapter done, the ninth's stub; 等到天亮
##   and the burnt things on the stage (the charred roof, the burnt boats and willows: the intact ones
##   off), 璃虹 in 田老财's 东房 with her word, the farmwife's 你拔的？; a save.

const StoryFixtures := preload("res://tests/support/story_fixtures.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const ROBE: StringName = &"native:latemoon/cold_robe"
const SWORD: StringName = &"native:village/soul_impaler"
const FEATHER: StringName = &"native:village/lihong_feather"
const LIHONG: StringName = &"native.npc.lihong"
const LIHONG_WEAK: StringName = &"native.npc.lihong_weak"
const SHANG_JUE: StringName = &"native.npc.shang_jue_lake"
const LIHONG_ASHORE: StringName = &"native.npc.lihong_ashore"
const HELL_RUNNER: StringName = &"native.npc.hell_runner"
const BODY: StringName = &"native:village/body_fisher"
const COLD_LINE: String = "寒气刺骨！"
const HELD_LINE: String = "寒气从冰里渗上来。你运起内力顶住了。"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var keep: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_keep(tree, keep)
	keep.free()
	await tree.process_frame
	var pull: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_pull(tree, pull)
	pull.free()
	await tree.process_frame
	var valley: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_valley_way(tree, valley)
	valley.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## The other way down (a review on #261): from 忘情谷 down the ice stair into the dragons' hall, never
## through the lake — the chapter's first two steps are done by the stair's mark alone, the pool next.
func _test_valley_way(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter8")
	StoryFixtures.chapter7_done(session, true, true)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"lake", "valley: the chapter open at the lake step")
	var map: WorldMapController = MapPlaces.enter(session, &"village.valley1", &"village.valley1.cave_return") # TEST-ONLY: outside 忘情谷
	await _settle(tree)
	_check(map != null and await MapPlaces.take_passage(tree, map, &"village.valley1.eastdown"), "valley: east down the ice stair")
	var cave: WorldMapController = session.active_map() as WorldMapController
	_check(cave.map_id() == &"village.icecave" and session.player_runtime().world_location().zone_id == &"village.lakebottom2" and state.marks.get("到了冰龙厅", 0) == 1 and state.marks.get("下了湖底", 0) == 0, "valley: in the dragons' hall by the stair, the lake never dived")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"pool" and StoryQuestLog.objective(state, quests).contains("水潭"), "valley: the lake and the hall both done by the stair; next, the pool")


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.map(&"village.seal_chamber") != null and catalog.zone(&"village.seal_altar") != null and catalog.zone(&"village.seal_altar").indoors and catalog.room(&"native:village/seal_altar") != null and catalog.room(&"native:village/seal_altar").short == "冰下封坛", "the 冰下封坛: one native room on its own map, indoors")
	for id: StringName in [&"village.lakebottom1.landmark.carving", &"village.seal_altar.landmark.altar", &"village.seal_altar.landmark.walls"]:
		var landmark: WorldLandmarkDefinition = catalog.landmark(id)
		_check(landmark != null and landmark.policy == &"look" and landmark.looks().size() == 1, "landmark %s: looked at, one look by marks" % id)
	var altar: WorldLandmarkDefinition = catalog.landmark(&"village.seal_altar.landmark.altar")
	_check(altar.description_for({}).contains("剑柄露在冰外") and altar.description_for({"拔了穿灵": 1}).contains("剑孔"), "the 封坛 before and after the sword")
	var carving: WorldLandmarkDefinition = catalog.landmark(&"village.lakebottom1.landmark.carving")
	_check(not carving.description_for({}).contains("笔迹") and carving.description_for({"读过铜牒": 1}).contains("「钉」字刻得最深"), "the 刻字: one who read the 铜牒 knows the hand")
	for zone_id: StringName in [&"village.lakebottom1", &"village.lakebottom2"]:
		var cold: RoomHazardDefinition = catalog.hazard_in(zone_id)
		_check(cold != null and cold.native and cold.unless_wearing() == [ROBE] and cold.first_ms == 3000 and cold.every_ms == 6000 and cold.acts().size() == 2 and cold.acts()[0].at_least.get("force", 0) == 12 and cold.acts()[0].steps[1].kind == ScriptedAct.Kind.DRAIN_FORCE and cold.acts()[1].steps[1].kind == ScriptedAct.Kind.DAMAGE and cold.acts()[1].steps[1].amounts.get("kee", 0) == 24, "%s: the cold, native, spared by the 宝衣; 内力 first, then kee" % zone_id)
	_check(catalog.hazard_in(&"village.seal_altar") == null, "the 封坛 is not cold: 璃虹's light")
	var pacing: PacingDefinition = catalog.pacing()
	_check(pacing.native_hazards and pacing.story_parley and not PacePresets.of(pacing, CharacterState.PACE_CLASSIC).native_hazards and PacePresets.of(pacing, CharacterState.PACE_MODERN).native_hazards, "the game's pacing runs the native hazards; 经典 turns them off")
	var errors: Array[String] = []
	var es2: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "pacing", errors))
	_check(errors.is_empty() and not es2.native_hazards and PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "native_hazards": true}, "pacing", errors)).copy().native_hazards, "left out: none (ES2); set, and kept by copy()")
	var dive: ServiceDefinition = catalog.service(&"village.lake.dive")
	_check(dive != null and dive.act.acts[0].steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.MARK and step.flag == "下了湖底"), "the lake's dive marks 下了湖底")
	var pool: ServiceDefinition = catalog.service(&"village.lakebottom2.pool")
	_check(pool != null and pool.act.verb == "潜下去" and not pool.act.acts[0].ask.is_empty() and pool.act.acts[0].steps[-1].kind == ScriptedAct.Kind.MOVE and pool.act.acts[0].steps[-1].zone_id == &"village.seal_altar", "水潭 · 潜下去: asked first, down to the 封坛")
	_check(catalog.service(&"village.seal_altar.pool").act.acts[0].steps[-1].point_id == &"village.lakebottom2.pool_return", "潭口 · 游上去: back beside the pool")
	var recite: ServiceDefinition = catalog.service(&"village.seal_altar.recite")
	var asked: ScriptedAct = recite.act.acts[1]
	_check(recite.act.acts.size() == 3 and asked.present == LIHONG and asked.steps[-1].kind == ScriptedAct.Kind.QUESTIONS and asked.steps[-1].questions.size() == 3 and asked.steps[-1].questions.all(func(question: ScriptedAct.Question) -> bool: return question.answers.size() == 2 and question.answers[0].mark == "读过铜牒" and question.answers[1].mark == "信了商玦"), "璃虹's three questions: the 铜牒's words true, 商玦's telling false")
	_check(asked.steps[-1].when_true.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.MARK and step.flag == "璃虹说了封法") and asked.steps[-1].when_false.size() == 2, "all true: the 封法; a wrong one: 再念")
	var pull: ServiceDefinition = catalog.service(&"village.seal_altar.pull")
	_check(pull != null and pull.act.acts.size() == 4 and pull.act.acts[2].not_mark == "璃虹说了封法" and not pull.act.acts[3].ask.is_empty() and pull.act.acts[3].steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.GIVE and step.item_id == SWORD) and pull.act.acts[3].steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.SUMMON and step.spawn_id == &"native.seal_altar.lihong_weak"), "穿灵 · 拔出来: after the 封法, asked first; the sword, the fallen 璃虹")
	var keep: ServiceDefinition = catalog.service(&"village.seal_altar.keep")
	_check(keep != null and keep.act.acts.size() == 4 and keep.act.acts[3].steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.GIVE and step.item_id == FEATHER), "封坛 · 看清了: her feather")
	var sword: ItemContentDefinition = catalog.item(SWORD)
	var feather: ItemContentDefinition = catalog.item(FEATHER)
	_check(sword != null and sword.quest_item and sword.no_drop and sword.weapon_damage > catalog.item(&"es2:daemon/class/fighter/soulimpaler").weapon_damage and feather != null and feather.quest_item and feather.no_drop, "穿灵 above the 水烟阁's copy, 璃虹的羽: quest things nobody drops")
	var lihong: NpcDefinition = catalog.npc(LIHONG)
	_check(lihong != null and lihong.gender == CharacterState.GENDER_FEMALE and lihong.age == 23 and lihong.dealings().is_fight_deferred() and lihong.hooks().calls.size() == 1 and lihong.hooks().calls[0].reaction and lihong.hooks().calls[0].act.npc_in == &"village.seal_altar" and lihong.talk().inquiry_topics().has("封法") and lihong.talk().inquiry_topics().has("留下"), "璃虹: a woman of 23 in the ice, not to be fought, meets whoever comes down, answers seven topics")
	var shang: NpcDefinition = catalog.npc(SHANG_JUE)
	_check(shang != null and shang.hooks().scene_mark == "商玦劝过你" and shang.hooks().calls.size() == 2 and shang.dealings().is_fight_deferred(), "商玦 at the 封坛: his two beats, not to be fought")
	var dragon: NpcDefinition = catalog.npc(&"village.npc.dragon")
	_check(dragon.dealings().guardian and dragon.hooks().calls.size() == 1 and dragon.hooks().calls[0].act.npc_in == &"village.lakebottom2" and catalog.spawn(&"village.icecave.lakebottom2.dragons").cleared_mark == "冰龙倒了", "the dragons: guardians, their look as the player comes in, 冰龙倒了 once felled")
	var staged: NpcSpawnDefinition = catalog.spawn(&"native.seal_altar.shang_jue")
	_check(staged != null and staged.present.key == "看过封坛" and staged.until.key == "湖底一章" and catalog.spawn(&"native.seal_altar.lihong_weak").summoned, "商玦 on the stage from the dive to the chapter's end; the fallen 璃虹 summoned")
	_check(catalog.portal(&"village.valley1.eastdown").set_mark == "到了冰龙厅", "the valley's way down marks the hall too")
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter8")
	_check(quest != null and quest.steps.size() == 6 and quest.steps[0].condition.parts.size() == 2 and quest.steps[0].condition.parts[0].key == "下了湖底" and quest.steps[0].condition.parts[1].key == "到了冰龙厅" and quest.steps[1].condition.key == "到了冰龙厅" and quest.steps[2].condition.key == "看过封坛" and quest.steps[3].condition.key == "璃虹说了封法" and quest.steps[4].options.size() == 2 and quest.steps[4].options[0].condition.key == "拔了穿灵" and quest.steps[4].options[1].condition.key == "查清了封物" and quest.steps[5].only_after == &"pull" and quest.steps[5].condition.parts.size() == 3 and quest.reward.milestone and quest.reward.marks == ["湖底一章"], "the chapter: the lake (either way down), the hall, the pool, the 封法, the choice, the night after the sword; the milestone")
	for id: StringName in [&"native.lakeside.hell_runners", &"native.road1.hell_runners", &"native.field.hell_runners"]:
		var band: NpcSpawnDefinition = catalog.spawn(id)
		_check(band != null and band.spawn_point_ids().size() == 3 and band.present != null and band.present.parts.size() == 2 and band.until != null and band.until.key == band.cleared_mark and band.cleared_mark.ends_with("的鬼卒退了"), "%s: three 鬼卒 the night after the sword, until beaten" % id)
	_check(catalog.spawn(&"village.main.lakeside.fishers").until != null and catalog.spawn(&"village.main.lakeside.fishers").until.key == "拔了穿灵" and catalog.item_spawn(&"native.lakeside.body_fisher") != null and catalog.item(BODY) != null and catalog.item(BODY).no_get, "the fishermen gone once the sword is out, one dead on the shore")
	_check(catalog.spawn(&"native.lordhouse2.lihong") != null and catalog.spawn(&"native.lordhouse2.lihong").present.key == "拔了穿灵" and catalog.npc(LIHONG_ASHORE) != null and catalog.npc(LIHONG_ASHORE).hooks().calls[0].act.npc_in == &"village.lordhouse2", "璃虹 ashore in 田老财's 东房 from the sword on")
	var wait: ServiceDefinition = catalog.service(&"village.lakeside.wait")
	_check(wait != null and wait.act.verb == "等到天黑" and wait.act.acts.size() == 5 and wait.act.acts[0].not_mark == "拔了穿灵" and wait.act.acts[1].marks.size() == 3 and wait.act.acts[1].phase == [&"night", &"midnight"] and wait.act.acts[4].steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.UNTIL_PHASE and step.phases == [&"night"]), "湖畔 · 等到天黑: nothing before the sword; 等到天亮 after the night; the wait to night")
	var luca: NpcDefinition = catalog.npc(&"native.npc.luca")
	_check(luca != null and luca.hooks().calls.size() == 4 and luca.hooks().calls[2].act.npc_in == &"village.lakeside" and luca.hooks().calls[2].act.steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.UNFOLLOW) and luca.hooks().calls[3].act.mark == "拔了穿灵", "卢卡 stops at the lakeside (大秦人不会水) and takes up his sword the night the 鬼卒 come")
	var ninth: StoryQuestDefinition = catalog.story_quest(&"main.chapter9")
	_check(ninth != null and ninth.requires == [&"main.chapter8"] and ninth.steps.size() >= 1 and ninth.steps[0].target.zone_id == &"city.wumen", "the ninth chapter: 皇城, by the 午门 (第九章 A grew the stub)")
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.SOURCE_ENTRY_IMPERIAL_C_V1, "第九章 C's world revision is current")


## Down to the 封坛 from the lake: the dive, the cold (`robe`: worn through the cave, nothing felt),
## the carving, the hall's guardians, the pool. Leaves the player in the 封坛 with 璃虹 met and
## 商玦 arrived.
func _way_down(tree: SceneTree, session: WorldSessionController, ledger: String, robe: bool) -> WorldMapController:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter8")
	session.record_journal()
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.current_step(state, quest).step_id == &"lake" and StoryQuestLog.target(state, quests).zone_id == &"village.lakeside", "%s: the chapter open, the lake its target" % ledger)
	var lake: WorldMapController = MapPlaces.enter(session, &"village.lake", &"village.lake.boat_arrival") # TEST-ONLY: on the boat
	await _settle(tree)
	var dive: ActService = lake.service(&"village.lake.dive") as ActService
	_check(dive != null and await MapPlaces.drive(tree, lake, MapPlaces.service_spot(lake, &"village.lake.dive")) and dive.in_reach(), "%s: at the boat's side" % ledger)
	dive.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("冰龙盘踞"), "%s: the dive asked first" % ledger)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	await _settle(tree)
	var cave: WorldMapController = session.active_map() as WorldMapController
	_check(cave.map_id() == &"village.icecave" and session.player_runtime().world_location().zone_id == &"village.lakebottom1" and state.marks.get("下了湖底", 0) == 1, "%s: in the 玄冰岩洞 (下了湖底)" % ledger)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"cave" and StoryQuestLog.objective(state, quests).begins_with("玄冰上站不住人"), "%s: next, the cold and the hall" % ledger)
	# The cold: nothing for three seconds, then 内力 holds it off; without 内力, kee.
	var force: CharacterInternalResourceState = state.recovery.inner_force
	force.maximum = maxi(force.maximum, 200) # TEST-ONLY: a fresh character stands in for an eighth-chapter one
	force.current = 100
	state.vitality = CharacterResourceState.new(800, 800, 800) # TEST-ONLY
	var kee: CharacterResourceState = state.vitality
	if robe:
		var robe_id: StringName = cave.give_new_item_to_player(ROBE) # TEST-ONLY: the 宝衣 of 晚月庄
		for slot: StringName in session.player_runtime().armor.occupied_slots():
			var before: EquippedArmorRef = session.player_runtime().armor.equipped_ref_in_slot(slot)
			if before != null and before.armor_type == &"cloth":
				session.remove_player_item(before.item_instance_id)
		_check(session.wear_player_item(robe_id).succeeded and session.player_worn_item_ids().get(ROBE, false), "%s: the 寒於宝衣 worn" % ledger)
	_check(session.npc_world_time_allowed(), "%s: world time runs in the cave" % ledger)
	session.advance_room_hazards(2.9)
	_check(force.current == 100 and kee.current == 800, "%s: nothing for three seconds" % ledger)
	session.advance_room_hazards(0.2)
	if robe:
		_check(force.current == 100 and kee.current == 800 and not ui.log_lines().has(HELD_LINE) and not ui.log_lines().has(COLD_LINE), "%s: the 宝衣 keeps the cold off" % ledger)
		session.advance_room_hazards(6.0)
		_check(force.current == 100 and kee.current == 800, "%s: and keeps it off" % ledger)
	else:
		_check(force.current == 88 and kee.current == 800 and ui.log_lines().has(HELD_LINE), "%s: 内力 holds the first cold off: %d" % [ledger, force.current])
		session.advance_room_hazards(5.8)
		_check(force.current == 88, "%s: the next in six seconds" % ledger)
		force.current = 5 # TEST-ONLY: 内力 spent
		session.advance_room_hazards(0.3)
		_check(force.current == 5 and kee.current == 776 and ui.log_lines().has(COLD_LINE), "%s: without 内力 the cold takes kee: %d" % [ledger, kee.current])
		# 经典: ES2 only spoke of the cold.
		GameContent.catalog().pacing().with_native_hazards(false) # TEST-ONLY
		session.advance_room_hazards(6.1)
		_check(kee.current == 776 and force.current == 5, "%s: 经典 (native_hazards off): nothing" % ledger)
		GameContent.catalog().pacing().with_native_hazards(true) # TEST-ONLY
	# The 刻字 on the far wall: the 铜牒's hand.
	_check(cave.select_landmark(&"village.lakebottom1.landmark.carving") and cave.inspect_selected() and ui.inspection_text.text.contains("「钉」字刻得最深"), "%s: the 刻字, known by the 铜牒's hand" % ledger)
	ui.dismiss_current_panel()
	await _settle(tree)
	# Into the hall: the guardians look and coil back.
	_check(await MapPlaces.drive_to_zone(tree, cave, &"village.lakebottom2"), "%s: into the dragons' hall" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	for _frame: int in range(4):
		await tree.physics_frame
		cave.hostilities.process_pending_aggression()
	_check(not session.combat_encounter_coordinator().has_active_encounter() and state.marks.get("到了冰龙厅", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("又盘了回去")), "%s: six guardians look and coil back (到了冰龙厅)" % ledger)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"pool" and StoryQuestLog.objective(state, quests).contains("水潭"), "%s: next, the pool" % ledger)
	var pool: ActService = cave.service(&"village.lakebottom2.pool") as ActService
	_check(pool != null and await MapPlaces.drive(tree, cave, MapPlaces.service_spot(cave, &"village.lakebottom2.pool")) and pool.in_reach() and pool.verb() == "潜下去", "%s: 水潭 · 潜下去" % ledger)
	pool.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("不是鱼"), "%s: asked first" % ledger)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	await _settle(tree)
	var chamber: WorldMapController = session.active_map() as WorldMapController
	_check(chamber.map_id() == &"village.seal_chamber" and session.player_runtime().world_location().zone_id == &"village.seal_altar" and state.marks.get("看过封坛", 0) == 1, "%s: in the 冰下封坛 (看过封坛)" % ledger)
	var kee_below: int = kee.current
	session.advance_room_hazards(6.5)
	_check(GameContent.catalog().hazard_in(&"village.seal_altar") == null and session.room_hazards().elapsed_ms() == 0.0 and kee.current == kee_below, "%s: not cold here" % ledger)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"seal" and StoryQuestLog.objective(state, quests).contains("念给冰柱里的人听"), "%s: next, the 封法" % ledger)
	_check(_count_in(session, &"village.seal_altar", LIHONG) == 1 and _count_in(session, &"village.seal_altar", SHANG_JUE) == 1 and _count_in(session, &"village.seal_altar", LIHONG_WEAK) == 0, "%s: 璃虹 in her pillar, 商玦 come down a step ahead" % ledger)
	# 璃虹's three lines, then 商玦's two beats (8 and 13 seconds in).
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("见过璃虹", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("念给我听")), "%s: 璃虹: 你念过那片铜。念给我听" % ledger)
	for second: int in 14:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("商玦劝过你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("它在长")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("他要的是鬼成形")), "%s: 商玦: 拔了它……它在长; 璃虹: 他要的是鬼成形" % ledger)
	_check(chamber.select_landmark(&"village.seal_altar.landmark.altar") and chamber.inspect_selected() and ui.inspection_text.text.contains("剑柄露在冰外"), "%s: the 封坛 looked at: the hilt out of the ice" % ledger)
	ui.dismiss_current_panel()
	await _settle(tree)
	return chamber


## The 铜牒 recited at her pillar: a wrong answer refused, the three true ones and her 封法.
func _recite(tree: SceneTree, session: WorldSessionController, chamber: WorldMapController, ledger: String) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter8")
	var recite: ActService = chamber.service(&"village.seal_altar.recite") as ActService
	_check(recite != null and await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.recite")) and recite.in_reach() and recite.verb() == "把铜牒念给她听", "%s: 冰柱 · 把铜牒念给她听" % ledger)
	recite.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("头在哪里") and ui.confirm_prompt.choice_buttons.size() >= 2 and ui.confirm_prompt.choice_buttons[0].text.begins_with("头在湖底冰下"), "%s: the first question" % ledger)
	ui.confirm_prompt.choice_buttons[1].pressed.emit() # 商玦's telling: wrong
	await _settle(tree)
	ui.confirm_prompt.choice_buttons[0].pressed.emit()
	await _settle(tree)
	ui.confirm_prompt.choice_buttons[0].pressed.emit()
	await _settle(tree)
	_check(not ui.is_asking() and state.marks.get("璃虹说了封法", 0) == 0 and ui.log_lines().any(func(line: String) -> bool: return line.contains("那不是铜上的话")), "%s: a wrong answer: 再念" % ledger)
	recite.interact()
	await _settle(tree)
	for answer: int in 3:
		_check(ui.is_asking(), "%s: question %d" % [ledger, answer + 1])
		ui.confirm_prompt.choice_buttons[0].pressed.emit()
		await _settle(tree)
	_check(not ui.is_asking() and state.marks.get("璃虹说了封法", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("三器齐")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("须有人留下")), "%s: all true: the 封法 (璃虹说了封法)" % ledger)
	session.record_journal()
	_check(StoryQuestLog.current_step(state, quest).step_id == &"choice" and StoryQuestLog.objective(state, quests).begins_with("商玦劝你拔剑"), "%s: the choice" % ledger)
	recite.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("要再听，问我「封法」")), "%s: recited again: 我说过了" % ledger)
	_check(chamber.select_npc(MapPlaces.npc_at(session, &"village.seal_altar.lihong.1").character_id) and chamber.ask_selected("封法").any(func(line: String) -> bool: return line.contains("三器齐")), "%s: 问 封法: her three lines again" % ledger)
	_check(chamber.select_landmark(&"village.seal_altar.landmark.walls") and chamber.inspect_selected() and ui.inspection_text.text.contains("刻了三百遍"), "%s: the walls: her name three hundred times" % ledger)
	ui.dismiss_current_panel()
	await _settle(tree)


func _test_keep(tree: SceneTree, session: WorldSessionController) -> void:
	var ledger: String = "keep"
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter8")
	StoryFixtures.chapter7_done(session, true, true)
	var chamber: WorldMapController = await _way_down(tree, session, ledger, true)
	var keep: ActService = chamber.service(&"village.seal_altar.keep") as ActService
	_check(keep != null and await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.keep")) and keep.in_reach() and keep.verb() == "看清了", "%s: 封坛 · 看清了" % ledger)
	keep.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("先把铜上的话念给冰柱里的人听")), "%s: before the 封法: 先听她说" % ledger)
	await _recite(tree, session, chamber, ledger)
	_check(await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.keep")) and keep.in_reach(), "%s: back at the 封坛's south side" % ledger)
	keep.interact()
	await _settle(tree)
	await _settle(tree)
	_check(state.marks.get("查清了封物", 0) == 1 and session.player_held_item_ids().get(FEATHER, false) and ui.log_lines().any(func(line: String) -> bool: return line.contains("把它放回坛上")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("等它自己出来")), "%s: looked over, her feather, 商玦's sneer" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(_count_in(session, &"village.seal_altar", SHANG_JUE) == 0 and _count_in(session, &"village.seal_altar", LIHONG) == 1, "%s: 商玦 gone in smoke, 璃虹 in her pillar" % ledger)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, quest) and state.marks.get("湖底一章", 0) == 1 and state.milestones.size() >= 1 and StoryQuestLog.took(state, quest, &"keep") and state.deeds.any(func(deed: DeedLog.Deed) -> bool: return deed.did.contains("没有动它")), "%s: the chapter done, 湖底一章, the deed" % ledger)
	var ninth: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter9")
	_check(StoryQuestLog.is_active(state, ninth) and StoryQuestLog.objective(state, quests).begins_with("进皇城") and StoryQuestLog.target(state, quests).zone_id == &"city.wumen", "%s: the ninth chapter: 皇城, by the 午门" % ledger)
	var pull: ActService = chamber.service(&"village.seal_altar.pull") as ActService
	_check(pull != null and await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.pull")) and pull.in_reach(), "%s: at the sword" % ledger)
	pull.interact()
	await _settle(tree)
	_check(not ui.is_asking() and not session.player_held_item_ids().get(SWORD, false) and ui.log_lines().any(func(line: String) -> bool: return line.contains("等三器齐了再拔")), "%s: the sword left for the 终章" % ledger)
	_check(chamber.drop_item(_held(session, FEATHER)).lines.any(func(line: String) -> bool: return line.contains("不能丢")), "%s: the feather is not dropped" % ledger)
	var up: ActService = chamber.service(&"village.seal_altar.pool") as ActService
	_check(up != null and await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.pool")) and up.in_reach() and up.verb() == "游上去", "%s: 潭口 · 游上去" % ledger)
	up.interact()
	await _settle(tree)
	await _settle(tree)
	_check(session.active_map().map_id() == &"village.icecave" and session.player_runtime().world_location().zone_id == &"village.lakebottom2", "%s: back in the hall" % ledger)
	_check(Work.capture(session) != null, "%s: a save with the feather" % ledger)


func _test_pull(tree: SceneTree, session: WorldSessionController) -> void:
	var ledger: String = "pull"
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter8")
	StoryFixtures.chapter7_done(session, false, false)
	var chamber: WorldMapController = await _way_down(tree, session, ledger, false)
	var pull: ActService = chamber.service(&"village.seal_altar.pull") as ActService
	_check(pull != null and await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.pull")) and pull.in_reach() and pull.verb() == "拔出来", "%s: 穿灵 · 拔出来" % ledger)
	pull.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("先把铜上的话念给我听")), "%s: before the 封法: her voice from the ice" % ledger)
	await _recite(tree, session, chamber, ledger)
	_check(await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.pull")) and pull.in_reach(), "%s: at the sword again" % ledger)
	pull.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("拔了就回不去") and ui.confirm_prompt.confirm_button.text == "拔出来", "%s: asked first: 拔了就回不去" % ledger)
	ui.confirm_prompt.cancel_button.pressed.emit()
	await _settle(tree)
	_check(not session.player_held_item_ids().get(SWORD, false) and state.marks.get("拔了穿灵", 0) == 0, "%s: 取消: the sword stays" % ledger)
	pull.interact()
	await _settle(tree)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	await _settle(tree)
	_check(state.marks.get("拔了穿灵", 0) == 1 and session.player_held_item_ids().get(SWORD, false) and ui.log_lines().any(func(line: String) -> bool: return line.contains("剑出来了")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("睁开了眼")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("它记得路")) and ui.log_lines().any(func(line: String) -> bool: return line.contains("站不住了")), "%s: the sword out, the head awake, 商玦's laugh, 璃虹 fallen" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(_count_in(session, &"village.seal_altar", SHANG_JUE) == 0 and _count_in(session, &"village.seal_altar", LIHONG) == 0 and _count_in(session, &"village.seal_altar", LIHONG_WEAK) == 1, "%s: 商玦 gone, the pillar empty, 璃虹 beside the 封坛" % ledger)
	_check(chamber.select_landmark(&"village.seal_altar.landmark.altar") and chamber.inspect_selected() and ui.inspection_text.text.contains("剑孔"), "%s: the 封坛 after: the empty 剑孔" % ledger)
	ui.dismiss_current_panel()
	await _settle(tree)
	var weak: NpcRuntimeState = MapPlaces.npc_at(session, &"village.seal_altar.lihong_weak.1")
	_check(weak != null and chamber.select_npc(weak.character_id) and chamber.ask_selected("上岸").any(func(line: String) -> bool: return line.contains("带我上岸")), "%s: 璃虹: 带我上岸" % ledger)
	_check(chamber.drop_item(_held(session, SWORD)).lines.any(func(line: String) -> bool: return line.contains("不能丢")), "%s: 穿灵 is not dropped" % ledger)
	session.record_journal()
	_check(not StoryQuestLog.is_done(state, quest) and StoryQuestLog.took(state, quest, &"pull") and state.deeds.any(func(deed: DeedLog.Deed) -> bool: return deed.did.contains("拔出了穿灵")) and StoryQuestLog.current_step(state, quest).step_id == &"night", "%s: the deed; the chapter waits for the night (B)" % ledger)
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "%s: a save with the sword" % ledger)
	# Up the pool with 璃虹, who goes ashore ahead (B: to 田老财's 东房).
	var up: ActService = chamber.service(&"village.seal_altar.pool") as ActService
	_check(up != null and await MapPlaces.drive(tree, chamber, MapPlaces.service_spot(chamber, &"village.seal_altar.pool")) and up.in_reach(), "%s: 潭口" % ledger)
	up.interact()
	await _settle(tree)
	await _settle(tree)
	var cave: WorldMapController = session.active_map() as WorldMapController
	_check(cave.map_id() == &"village.icecave" and ui.log_lines().any(func(line: String) -> bool: return line.contains("到人家里去")) and _count_in(session, &"village.seal_altar", LIHONG_WEAK) == 0, "%s: back in the hall, 璃虹 gone ashore ahead" % ledger)
	await _test_night(tree, session, ledger)


## 第八章 B: the night after the sword, from the lakeside (TEST-ONLY: the player set down on the shore).
func _test_night(tree: SceneTree, session: WorldSessionController, ledger: String) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter8")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	session.record_journal()
	_check(not StoryQuestLog.is_done(state, quest) and StoryQuestLog.current_step(state, quest).step_id == &"night" and StoryQuestLog.objective(state, quests).contains("守住村子"), "%s: the night waits: 守住村子" % ledger)
	session.day_clock().set_day_seconds(36000) # TEST-ONLY: morning
	var village: WorldMapController = MapPlaces.enter(session, &"village.lakeside", &"village.lakeside.boat_return") # TEST-ONLY: ashore
	await _settle(tree)
	_check(village != null and village.map_id() == &"village.main", "%s: ashore" % ledger)
	_check(_count_in(session, &"village.lakeside", &"village.npc.fisher") == 0 and not village.floor_item_of(BODY, &"village.lakeside").is_empty(), "%s: the fishermen gone, one dead on the shore" % ledger)
	_check(_count_in(session, &"village.lakeside", HELL_RUNNER) == 0 and _count_in(session, &"village.road1", HELL_RUNNER) == 0 and _count_in(session, &"village.field", HELL_RUNNER) == 0, "%s: by day no 鬼卒" % ledger)
	_check(_staged(village, "skiff", true) == 2 and _staged(village, "skiff", false) == 0 and _staged(village, "tree", false) == 0, "%s: the boats whole, the willows green (the burnt ones off the stage)" % ledger)
	var wait: ActService = village.service(&"village.lakeside.wait") as ActService
	_check(wait != null and await MapPlaces.drive(tree, village, MapPlaces.service_spot(village, &"village.lakeside.wait")) and wait.in_reach() and wait.verb() == "等到天黑", "%s: 湖畔 · 等到天黑" % ledger)
	state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	for skill_id: StringName in [&"sword", &"parry", &"dodge", &"unarmed"]:
		state.skills.set_raw_level(skill_id, 150) # TEST-ONLY: an eighth-chapter hand
	state.applies["damage"] = 600 # TEST-ONLY: a blow that fells a 鬼卒, so three bands fall inside one night (the clock runs with the fight)
	state.applies["attack"] = 300 # TEST-ONLY
	_check(session.wield_player_item(_held(session, SWORD)).succeeded, "%s: 穿灵 in hand" % ledger)
	wait.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.confirm_button.text == "等到天黑", "%s: asked first" % ledger)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.day_phase_id() in [&"night", &"midnight"] and ui.log_lines().any(func(line: String) -> bool: return line.contains("鬼卒从湖里爬上来了")), "%s: night falls: 鬼卒从湖里爬上来了 (%s)" % [ledger, session.day_phase_id()])
	_check(_count_in(session, &"village.lakeside", HELL_RUNNER) == 3 and _count_in(session, &"village.road1", HELL_RUNNER) == 3 and _count_in(session, &"village.field", HELL_RUNNER) == 3, "%s: three bands up out of the lake as the phase turns" % ledger)
	for zone_id: StringName in [&"village.lakeside", &"village.road1", &"village.field"]:
		var band: NpcRuntimeState = null
		for npc: NpcRuntimeState in village.npc_runtimes():
			if npc.definition().definition_id == HELL_RUNNER and npc.exists_in_map and npc.world_location().zone_id == zone_id:
				band = npc
				break
		var beside: bool = band != null
		if beside and zone_id == &"village.road1":
			beside = village.place_player(&"village.road1", Vector2(2008, 684)) # TEST-ONLY: set down at the village's mouth (the walk from the shore is the whole village long)
			await _settle(tree)
		if beside and zone_id != &"village.lakeside":
			beside = await MapPlaces.drive(tree, village, MapPlaces.spot(village, zone_id, village.runtime_body_for_character(band.character_id).global_position + Vector2(-80, 0), 96.0))
		# The band notices the player (its presence circle, the alert's beat) — or the player strikes first.
		for _tick: int in range(20):
			await tree.physics_frame
			session.advance_npc_heartbeat(0.1)
			village.hostilities.process_pending_aggression()
			if coordinator.has_active_encounter():
				break
		if not coordinator.has_active_encounter() and band != null and village.select_npc(band.character_id):
			village.attack_selected()
			for _frame: int in range(6):
				await tree.physics_frame
				village.hostilities.process_pending_aggression()
				if coordinator.has_active_encounter():
					break
		if not beside:
			print("%s: the walk up to the band at %s gave up; it notices the player anyway" % [ledger, zone_id])
		_check(coordinator.has_active_encounter(), "%s: the band at %s falls on the player (%s, %d there)" % [ledger, zone_id, session.day_phase_id(), _count_in(session, zone_id, HELL_RUNNER)])
		coordinator.set_manual_turns(false) # TEST-ONLY: the fight runs on without the player's hand
		var rounds: int = 0
		while coordinator.has_active_encounter() and rounds < 6000:
			coordinator.advance_scheduler(1.0)
			rounds += 1
		ui.dismiss_current_panel()
		await _settle(tree)
		_check(not coordinator.has_active_encounter() and _count_in(session, zone_id, HELL_RUNNER) == 0, "%s: the band at %s fought out in %d rounds (%s)" % [ledger, zone_id, rounds, session.day_phase_id()])
	session.record_journal()
	_check(state.marks.get("湖畔的鬼卒退了", 0) == 1 and state.marks.get("村口的鬼卒退了", 0) == 1 and state.marks.get("稻田的鬼卒退了", 0) == 1, "%s: the three marks" % ledger)
	_check(StoryQuestLog.is_done(state, quest) and state.marks.get("湖底一章", 0) == 1 and StoryQuestLog.took(state, quest, &"pull") and state.deeds.any(func(deed: DeedLog.Deed) -> bool: return deed.did.contains("拔出了穿灵")), "%s: the chapter done after the night, the deed" % ledger)
	_check(StoryQuestLog.is_active(state, GameContent.catalog().story_quest(&"main.chapter9")), "%s: the ninth chapter's stub open" % ledger)
	# Dawn: the burnt things on the stage.
	_check(await MapPlaces.drive(tree, village, MapPlaces.service_spot(village, &"village.lakeside.wait")) and wait.in_reach(), "%s: back at the shore" % ledger)
	wait.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.confirm_button.text == "等到天亮", "%s: 等到天亮 asked first" % ledger)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.day_phase_id() == &"dawn" and ui.log_lines().any(func(line: String) -> bool: return line.contains("它每一夜都在长")), "%s: dawn: 它每一夜都在长" % ledger)
	_check(_staged(village, "skiff", true) == 0 and _staged(village, "skiff", false) == 2 and _staged(village, "tree", false) == 2 and _staged(village, "tree", true) == 0, "%s: the burnt boats and willows on the stage, the whole ones off" % ledger)
	wait.interact()
	await _settle(tree)
	_check(not ui.is_asking() and ui.log_lines().any(func(line: String) -> bool: return line.contains("村子烧了一半")), "%s: nothing more to wait for" % ledger)
	# 璃虹 in 田老财's 东房, the farmwife's word.
	var lord: WorldMapController = MapPlaces.enter(session, &"village.lordhouse2", &"village.lordhouse2.lihong.1") # TEST-ONLY: into the 东房
	await _settle(tree)
	_check(lord != null and _count_in(session, &"village.lordhouse2", LIHONG_ASHORE) == 1, "%s: 璃虹 in the 东房" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("璃虹上岸见过你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("别回头看我")), "%s: 璃虹: 别回头看我" % ledger)
	var ashore: NpcRuntimeState = MapPlaces.npc_at(session, &"village.lordhouse2.lihong.1")
	_check(ashore != null and lord.select_npc(ashore.character_id) and lord.ask_selected("它在长").any(func(line: String) -> bool: return line.contains("它在等头")), "%s: 问 它在长" % ledger)
	var farm: WorldMapController = MapPlaces.enter(session, &"village.farmhouse1", &"village.farmhouse1.road4_entry") # TEST-ONLY: into the farmhouse
	await _settle(tree)
	_check(farm != null and await MapPlaces.drive_to_zone(tree, farm, &"village.fmhousback"), "%s: through to the yard" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(farm != null and state.marks.get("农妇问过你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("你拔的")), "%s: the farmwife: 你拔的？" % ledger)
	var woman: NpcRuntimeState = MapPlaces.npc_at(session, &"village.fmhousback.woman1.1")
	_check(woman != null and farm.select_npc(woman.character_id) and farm.ask_selected("鬼卒").any(func(line: String) -> bool: return line.contains("钢叉")), "%s: 问 鬼卒" % ledger)
	_check(Work.capture(session) != null, "%s: a save after the night" % ledger)


## The scene's staged furnishings of `kind` now on (`on` true) or off the stage.
func _staged(map: WorldMapController, kind: String, whole: bool) -> int:
	var found: int = 0
	var furnishings: Node = map.get_node_or_null("Furnishings")
	if furnishings == null:
		return 0
	for node: Node in furnishings.get_children():
		var look: Dictionary = node.get_meta("look", {})
		if String(look.get("kind", "")) != kind or not WorldStoryPresence.is_staged_look(look):
			continue
		var intact: bool = not look.get("burnt", false) and not look.get("charred", false)
		if intact == whole and not node.get_meta("staged_off", false):
			found += 1
	return found

func _held(session: WorldSessionController, definition_id: StringName) -> StringName:
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.item_definition_id == definition_id:
			return row.item_instance_id
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
	session.configure_source_entry("番坊", gender)
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
