extends RefCounted

## 晚月庄 B (d/latemoon): the women's quarters and the rooms' own commands. The greetings
## by gender and class (阮欣郁 kicks a man out, 龙韶吟 powders him, 虞琼衣 stares, they and
## 苗郁淑 shut the door the player came by, 凤凰 kills a man, 区冥 stares at whoever is no
## dancer), the man asked before the changing room and the bath (owner, plan Q2), the bath,
## 雨梅's tea cup and its hand-back, the closet's skirts and the 海棠's pistils (two a reset),
## the pistil against rose_poison, 缀芳阁's ponder, the skirts only a 女性 wears. bathroom1.c's
## powder on leaving is dead code (replace_program) and stays out (owner). Walks use the move
## actions (MapPlaces); NPC time is driven by hand. TEST-ONLY fixtures are marked.
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const TEACUP: StringName = &"es2:d/latemoon/obj/teacup"
const SKIRT: StringName = &"es2:d/latemoon/obj/skirt"
const PISTIL: StringName = &"es2:d/latemoon/park/npc/obj/flower"
const KICKED_OUT: StringName = &"latemoon.room.flower1.kicked_out"
const ASKED: String = "此处是禁止男性进入！"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_pistil()
	_test_acts()
	var woman: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE)
	await _test_tea(tree, woman)
	await _test_closet(tree, woman)
	await _test_garden(tree, woman)
	await _test_quarters_for_a_woman(tree, woman)
	await _test_tower(tree, woman)
	woman.free()
	await tree.process_frame
	var man: WorldSessionController = await _session(tree, CharacterState.GENDER_MALE)
	await _test_quarters_for_a_man(tree, man)
	man.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("晚客", gender)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	await tree.process_frame
	session.set_process(false)
	# TEST-ONLY: nobody chats or wanders; a random(2) greeting takes its second case.
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	var state: CharacterState = session.player_runtime().state
	# TEST-ONLY: strong enough that the quarters' blows and poisons knock nobody out.
	state.essence = CharacterResourceState.new(500, 500, 500)
	state.vitality = CharacterResourceState.new(500, 500, 500)
	state.spirit = CharacterResourceState.new(500, 500, 500)
	return session


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var shinyu: NpcTalk = catalog.npc(&"latemoon.npc.room.shinyu").talk()
	var for_man: ScriptedAct = shinyu.choose_greeting(CharacterState.GENDER_MALE, &"", Callable())
	var kinds: Array[ScriptedAct.Kind] = []
	for step: ScriptedAct.Step in for_man.steps:
		kinds.append(step.kind)
	_check(shinyu.greeting_by_rule() and kinds == [ScriptedAct.Kind.LINE, ScriptedAct.Kind.LINE, ScriptedAct.Kind.LINE, ScriptedAct.Kind.CLOSE_DOOR, ScriptedAct.Kind.CONDITION, ScriptedAct.Kind.DAMAGE, ScriptedAct.Kind.MOVE], "shinyu.c greeting(): three lines, the door, rose_poison, the blows, out: %s" % [kinds])
	_check(for_man.steps[0].line.color() == ColoredLine.HIY and for_man.steps[1].line.color() == ColoredLine.HIR, "her HIY shout and HIR powder")
	var for_woman: ScriptedAct = shinyu.choose_greeting(CharacterState.GENDER_FEMALE, &"", Callable())
	_check(for_woman.steps.size() == 1 and for_woman.steps[0].kind == ScriptedAct.Kind.CLOSE_DOOR, "a woman: she only shuts the door")
	var statue: NpcTalk = catalog.npc(&"latemoon.npc.upstar.statue").talk()
	_check(statue.choose_greeting(CharacterState.GENDER_FEMALE, &"fighter", Callable()) != null and statue.choose_greeting(CharacterState.GENDER_MALE, &"dancer", Callable()) == null, "区冥 stares at anyone not of the dancers' class")
	_check(catalog.npc(&"latemoon.npc.room.fireangel").talk().choose_greeting(CharacterState.GENDER_FEMALE, &"", Callable()) == null, "凤凰 leaves women be")
	_check(catalog.npc(&"latemoon.npc.room.yushou").talk().choose_greeting(CharacterState.GENDER_FEMALE, &"", Callable()) != null, "苗郁淑 greets anyone")
	for id: StringName in [SKIRT, &"es2:d/latemoon/obj/skirt4", &"es2:d/latemoon/obj/skirt5"]:
		var skirt: ItemContentDefinition = catalog.item(id)
		_check(skirt.female_only and skirt.wear_refusal == "只有女生才可穿哦!你变态呀! \n", "%s: only a 女性 wears it, with wear()'s own line" % id)
	_check(not catalog.item(&"es2:d/latemoon/obj/skirt3").female_only, "skirt3.c has no wear() of its own")
	var cup: ItemContentDefinition = catalog.item(TEACUP)
	_check(cup != null and cup.display_name == "玉瓷茶杯" and cup.value == 20, "the 玉瓷茶杯")
	_check(catalog.item(PISTIL).apply == ItemApplyFunctions.ROSE_PISTIL and ItemApplyFunctions.verb(ItemApplyFunctions.ROSE_PISTIL) == "吃", "the 小花蕊 is eaten")
	for landmark_id: StringName in [&"latemoon.latemoon2.landmark.closet", &"latemoon.park.moonc.landmark.flower"]:
		var landmark: WorldLandmarkDefinition = catalog.landmark(landmark_id)
		_check(landmark.policy == &"take" and landmark.setting("limit") == 2, "%s: two a reset" % landmark_id)
	var bath: ServiceDefinition = catalog.service(&"latemoon.room.bathroom.bath")
	_check(bath.kind == &"act" and bath.act.act_for(CharacterState.GENDER_MALE, &"").ask.contains(ASKED) and bath.act.act_for(CharacterState.GENDER_FEMALE, &"").ask.is_empty(), "the bath asks a man first")
	var ask: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(&"latemoon.room.flower1", &"latemoon.room.bathroom1")
	_check(ask.size() == 1 and ask[0].asks and ask[0].ask.contains(ASKED), "a man walking into the changing room is asked")
	_check(catalog.exit_rules_between(&"latemoon.room.bathroom1", &"latemoon.room.flower1").is_empty(), "no powder on leaving: bathroom1.c's valid_leave() was dropped by replace_program (owner)")
	var tea: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(&"latemoon.latemoon3", &"latemoon.latemoon1")
	_check(tea.size() == 1 and tea[0].condition == ZoneExitRuleDefinition.Condition.TAKES_BACK and tea[0].item_id == TEACUP, "latemoon3.c valid_leave(): the cup goes back")


## flower.c do_eat(): sen back 50; rose_poison 10 less, 0 below 10; nothing for one not poisoned.
func _test_pistil() -> void:
	var state := CharacterState.new()
	state.spirit = CharacterResourceState.new(100, 300, 300)
	state.conditions.add_or_replace_duration(ConditionIds.ROSE_POISON, 25)
	var eaten: ItemApplyFunctions.Result = ItemApplyFunctions.apply(ItemApplyFunctions.ROSE_PISTIL, state, false)
	var left: DurationConditionPayload = state.conditions.get_condition(ConditionIds.ROSE_POISON) as DurationConditionPayload
	_check(eaten.accepted and eaten.used_up and left.remaining == 15 and state.spirit.current == 150, "25 → 15, sen +50")
	_check(eaten.lines == ["你拿出一朵小花蕊，一口给吞了下去。", "只见你脸上泛起一阵红晕，整个人看起来好多了!"], "its two lines: %s" % [eaten.lines])
	state.conditions.add_or_replace_duration(ConditionIds.ROSE_POISON, 6)
	ItemApplyFunctions.apply(ItemApplyFunctions.ROSE_PISTIL, state, false)
	left = state.conditions.get_condition(ConditionIds.ROSE_POISON) as DurationConditionPayload
	_check(left.remaining == 0, "6 → 0: one more bout (apply_condition 0)")
	state.conditions.remove_condition(ConditionIds.ROSE_POISON)
	state.spirit = CharacterResourceState.new(280, 300, 300)
	ItemApplyFunctions.apply(ItemApplyFunctions.ROSE_PISTIL, state, false)
	_check(not state.conditions.has_condition(ConditionIds.ROSE_POISON) and state.spirit.current == 300, "not poisoned: none given (默认); sen only up to its effective")


func _test_acts() -> void:
	var ponder: RoomActDefinition = GameContent.catalog().service(&"latemoon.upstar.uproom3.ponder").act
	var state := CharacterState.new()
	state.spirit = CharacterResourceState.new(60, 100, 100)
	_check(ponder.act_for(CharacterState.GENDER_FEMALE, &"").fainting_costs(state).is_empty(), "60 sen: ponder knocks nobody out")
	state.spirit = CharacterResourceState.new(40, 100, 100)
	_check(ponder.act_for(CharacterState.GENDER_FEMALE, &"").fainting_costs(state) == {"sen": 50}, "40 sen: 50 would knock her out")


## 雨梅's greeting gives the 玉瓷茶杯 once (latemoon/茶); leaving south hands it back.
func _test_tea(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"latemoon.manor", &"latemoon.entrance", &"latemoon.entrance", &"latemoon.entrance.cloud_entry").succeeded(), "on the cobbled path")
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.entrance.door", &"latemoon.entrance")) and map.open_door(&"latemoon.entrance.door"), "the arch opens")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.gate", &"latemoon.front_yard", &"latemoon.latemoon1"]), "into the hall")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.latemoon3"), "the reception room")
	map.npc_life._advance_ambience(1.0)
	var cup: StringName = _carried(session, TEACUP)
	_check(not cup.is_empty() and player.temp_marks.get("latemoon/茶", 0) == 1, "请用茶！: a cup of 金轩茶")
	_check(hud.log_lines().has("这是上等金轩茶!您品尝一下。") and _logged(hud, "请用茶！"), "her lines")
	_check(Work.capture(session) != null, "Save with the cup")
	await _drive_out_and_in(tree, map, &"latemoon.latemoon1", &"latemoon.latemoon3")
	_check(hud.log_lines().has("你将瓷杯交回给雨梅。") and _carried(session, TEACUP).is_empty() and not player.temp_marks.has("latemoon/茶"), "leaving south: the cup goes back to her")
	map.npc_life._advance_ambience(1.0)
	cup = _carried(session, TEACUP)
	_check(not cup.is_empty(), "back in: another cup")
	map.npc_life._advance_ambience(1.0)
	_check(_count_carried(session, TEACUP) == 1, "she gives no second while the first is out")
	player.temp_marks.erase("latemoon/茶") # TEST-ONLY: a Continue forgets the temp
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.latemoon1"), "out with it")
	_check(not _carried(session, TEACUP).is_empty() and not hud.log_lines().slice(-3).has("你将瓷杯交回给雨梅。"), "without the flag the cup stays, without a word")
	map.floor_items.use_up_one(_carried(session, TEACUP), ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor)) # TEST-ONLY
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.latemoon3") and await MapPlaces.drive_to_zone(tree, map, &"latemoon.latemoon1"), "in and out before she greets")
	_check(hud.log_lines()[-1] == "你起身往南离开!" or hud.log_lines().slice(-3).has("你起身往南离开!"), "no cup: 你起身往南离开!")


## latemoon2.c do_take("cloth"): two 布裙 a reset, then 橱子内的衣服好像被拿光了。
func _test_closet(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.latemoonc", &"latemoon.latemoon4"]), "to the 穿堂")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.latemoon4.door", &"latemoon.latemoon4")) and map.open_door(&"latemoon.latemoon4.door"), "the 仪门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.latemoon2"), "the inner hall")
	_check(map.select_landmark(&"latemoon.latemoon2.landmark.closet"), "the 碧纱橱")
	var first: TakeLandmarkPolicy.Result = map.traverse_selected_portal() as TakeLandmarkPolicy.Result
	var second: TakeLandmarkPolicy.Result = map.traverse_selected_portal() as TakeLandmarkPolicy.Result
	_check(first != null and not first.taken_item_id.is_empty() and not second.taken_item_id.is_empty() and hud.log_lines()[-1] == "你从橱子内取出布裙。", "two 布裙")
	var third: TakeLandmarkPolicy.Result = map.traverse_selected_portal() as TakeLandmarkPolicy.Result
	_check(third.empty and hud.log_lines()[-1] == "橱子内的衣服好像被拿光了。", "then none")
	map.reset_room("d/latemoon/latemoon2.c")
	var after_reset: TakeLandmarkPolicy.Result = map.traverse_selected_portal() as TakeLandmarkPolicy.Result
	_check(not after_reset.taken_item_id.is_empty(), "the room's reset fills it again")
	var worn: OldPineArmorInteractionResult = session.wear_player_item(first.taken_item_id)
	_check(worn.outcome != OldPineArmorInteractionResult.Outcome.FEMALE_ONLY and session.player_runtime().armor.is_worn(first.taken_item_id), "a woman wears the 布裙: %s" % [worn.outcome])
	hud.dismiss_current_panel()


## moonc.c do_pick(): two 小花蕊 a reset, then our line (owner); eaten, it cures.
func _test_garden(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.latemoon4", &"latemoon.latemoonc", &"latemoon.latemoon1", &"latemoon.front_yard"]), "back to the front garden")
	_check(await MapPlaces.take_passage(tree, map, &"latemoon.front_yard.south"), "south into the 湘园")
	var garden: WorldMapController = session.active_map() as WorldMapController
	_check(await MapPlaces.drive_through(tree, garden, [&"latemoon.park.flower2", &"latemoon.park.moonc"]), "to 翠嶂")
	_check(garden.select_landmark(&"latemoon.park.moonc.landmark.flower"), "the 西府海棠")
	garden.traverse_selected_portal()
	_check(hud.log_lines()[-1] == "你从西府海棠中摘下一朵小花蕊。", "a 小花蕊")
	garden.traverse_selected_portal()
	var none: TakeLandmarkPolicy.Result = garden.traverse_selected_portal() as TakeLandmarkPolicy.Result
	_check(none.empty and hud.log_lines()[-1] == "西府海棠上的小花蕊已经被摘光了。", "two, then our line")
	var pistil: StringName = _carried(session, PISTIL)
	_check(session.stack_collection().has_stack(pistil) and session.stack_collection().stack_state(pistil).amount == 2, "two pistils in one stack")
	var state: CharacterState = session.player_runtime().state
	state.conditions.add_or_replace_duration(ConditionIds.ROSE_POISON, 30) # TEST-ONLY
	_check(garden.apply_item(pistil), "eat one")
	var left: DurationConditionPayload = state.conditions.get_condition(ConditionIds.ROSE_POISON) as DurationConditionPayload
	_check(left.remaining == 20 and session.stack_collection().stack_state(pistil).amount == 1 and hud.log_lines()[-1] == "只见你脸上泛起一阵红晕，整个人看起来好多了!", "rose_poison 30 → 20, one pistil left")
	state.conditions.remove_condition(ConditionIds.ROSE_POISON)


## A woman behind the 垂花门: each shuts the door she came by; she bathes.
func _test_quarters_for_a_woman(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"latemoon.manor", &"latemoon.room.flower1", &"latemoon.room.flower1", KICKED_OUT).succeeded(), "in the women's passage")
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	map.npc_life._advance_ambience(1.0)
	var before: int = state.spirit.current
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.corridor7.door", &"latemoon.room.flower1")) and map.open_door(&"latemoon.room.corridor7.door"), "the 垂花门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.corridor7"), "north into the 内厅")
	map.npc_life._advance_ambience(1.0)
	_check(not map.door(&"latemoon.room.corridor7.door").is_open() and hud.log_lines().has("虞琼衣将垂花门关上。") and state.spirit.current == before, "虞琼衣 shuts it behind her; a woman keeps her sen")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.corridor7.door", &"latemoon.room.corridor7")) and map.open_door(&"latemoon.room.corridor7.door"), "open again")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.flower1"), "back south")
	map.npc_life._advance_ambience(1.0)
	_check(not map.door(&"latemoon.room.corridor7.door").is_open() and hud.log_lines()[-1] == "龙韶吟将垂花门关上。", "龙韶吟 shuts the door she came by")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.flower1.door", &"latemoon.room.flower1")) and map.open_door(&"latemoon.room.flower1.door"), "the 小帘门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.bathroom1") and not hud.is_asking(), "a woman walks into the changing room unasked")
	map.npc_life._advance_ambience(1.0)
	var location: WorldLocationState = session.player_runtime().world_location()
	_check(location.zone_id == &"latemoon.room.bathroom1" and not map.door(&"latemoon.room.flower1.door").is_open() and hud.log_lines()[-1] == "阮欣郁将小帘门关上。", "阮欣郁 only shuts the door")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.bathroom"), "on to the pool")
	map.npc_life._advance_ambience(1.0)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "凤凰 leaves a woman be")
	var bath: ActService = map.service(&"latemoon.room.bathroom.bath") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"latemoon.room.bathroom.bath")) and bath.in_reach(), "by the pool")
	state.spirit = CharacterResourceState.new(100, 500, 500) # TEST-ONLY: room to heal
	var gin: int = state.essence.current
	bath.interact()
	_check(not hud.is_asking() and hud.log_lines().has("你在池子中尽情沐浴，舒服的泡在池中。") and state.essence.current == gin - 10 and state.spirit.current >= 105 and state.spirit.current <= 109, "she bathes: gin -10, sen +random(5)+5 (%d)" % state.spirit.current)
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.room.bathroom1"]), "back to the changing room")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.flower1.door", &"latemoon.room.bathroom1")) and map.open_door(&"latemoon.room.flower1.door"), "the 小帘门 from inside")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.flower1"), "out")
	_check(not state.conditions.has_condition(ConditionIds.ROSE_POISON), "no powder on leaving (owner: ES2 never ran it)")
	# 苗郁淑 in the rear hall shuts its great door and asks for quiet, from anyone.
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.corridor7.door", &"latemoon.room.flower1")) and map.open_door(&"latemoon.room.corridor7.door"), "the 垂花门 again")
	_check(await MapPlaces.drive_through(tree, map, [&"latemoon.room.corridor7", &"latemoon.room.wroad2", &"latemoon.room.wroad1", &"latemoon.room.lroad3", &"latemoon.room.lcenter"]), "round to the rear hall")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.twoc.door", &"latemoon.room.lcenter")) and map.open_door(&"latemoon.room.twoc.door"), "its great door opens")
	map.npc_life._advance_ambience(1.0)
	var lines: Array[String] = hud.log_lines()
	_check(not map.door(&"latemoon.room.twoc.door").is_open() and lines[-2] == "苗郁淑将后厅大门关上。" and lines[-1].begins_with("阁下! 这里是庄内后厅厢房。"), "苗郁淑 shuts it, then asks for quiet: %s" % [lines.slice(-2)])


## The front tower: 区冥 stares at whoever is no dancer; 缀芳阁's ponder.
func _test_tower(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"latemoon.upper", &"latemoon.upstar.upstar1", &"latemoon.upstar.upstar1", &"latemoon.upstar.upstar1.stairs_arrival").succeeded(), "upstairs")
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	map.npc_life._advance_ambience(1.0)
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.upstar.upcenter"), "to the 前堂楼's middle")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.upstar.upcenter.door", &"latemoon.upstar.upcenter")) and map.open_door(&"latemoon.upstar.upcenter.door"), "the sandalwood door opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.upstar.uproom"), "into the 佛堂")
	var sen: int = state.spirit.current
	map.npc_life._advance_ambience(1.0)
	_check(state.spirit.current == sen - 20 and hud.log_lines()[-1] == "你有一种奇特的感觉，彷佛有人在盯著你看。", "区冥: 20 sen from one who is no dancer")
	state.affiliation.class_id = &"dancer" # TEST-ONLY: D makes the player one
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.upstar.upcenter") and await MapPlaces.drive_to_zone(tree, map, &"latemoon.upstar.uproom"), "out and in again")
	sen = state.spirit.current
	map.npc_life._advance_ambience(1.0)
	_check(state.spirit.current == sen, "a dancer is left be")
	state.affiliation.class_id = &""
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.upstar.upstar3"), "to the 缀芳阁's door")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.upstar.upstar3.door", &"latemoon.upstar.upstar3")) and map.open_door(&"latemoon.upstar.upstar3.door"), "it opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.upstar.uproom3"), "into the 缀芳阁")
	var ponder: ActService = map.service(&"latemoon.upstar.uproom3.ponder") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"latemoon.upstar.uproom3.ponder")) and ponder.in_reach(), "by the censer")
	var original: WorldInteractionRandomSource = map.world_interaction_random_source()
	map.replace_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([5])) # TEST-ONLY: random(kar) = 5
	state.attributes.bellicosity = 100
	state.attributes.karma = 20
	state.spirit = CharacterResourceState.new(200, 200, 200)
	ponder.interact()
	var lines: Array[String] = hud.log_lines()
	_check(state.attributes.bellicosity == 88 and state.spirit.current == 150 and lines[-2] == "你双手合掌，安静的坐在地上。" and lines[-1] == "你彷佛变的较为祥合慈善了!", "ponder: 50 sen, bellicosity -(random(kar) + 7)")
	map.replace_world_interaction_random_source(original)
	state.attributes.bellicosity = 0
	ponder.interact()
	_check(state.attributes.bellicosity == 0 and state.spirit.current == 100, "no bellicosity: only the sen")
	state.spirit = CharacterResourceState.new(30, 200, 200) # TEST-ONLY
	ponder.interact()
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("50 点神"), "it would knock her out: asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(state.spirit.current == 30, "取消: nothing spent")
	_check(Work.capture(session) != null, "Save in the 缀芳阁")


## A man behind the 垂花门: stared at, powdered, asked before the changing room, kicked out;
## asked before the bath; 凤凰 attacks him; the skirt refuses him.
func _test_quarters_for_a_man(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"latemoon.manor", &"latemoon.room.flower1", &"latemoon.room.flower1", KICKED_OUT).succeeded(), "a man in the women's passage")
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	var shaoin: NpcRuntimeState = _npc(map, &"latemoon.npc.room.shaoin")
	var force: int = shaoin.character_state.recovery.inner_force.current
	map.npc_life._advance_ambience(1.0)
	var lines: Array[String] = hud.log_lines()
	_check(lines.slice(-2) == ["韶吟惊慌生气的怒斥： 喂! 兄台不要乱闯!", "她的眼神骤变，隐约中似乎让人神智渐模糊!"], "龙韶吟's two lines: %s" % [lines.slice(-2)])
	_check(state.spirit.current == 480 and _poison(state) == 2 and shaoin.character_state.recovery.inner_force.current == force + 50, "20 sen, rose_poison 2, her force +50")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.corridor7.door", &"latemoon.room.flower1")) and map.open_door(&"latemoon.room.corridor7.door"), "the 垂花门 opens")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.corridor7"), "north")
	var sen: int = state.spirit.current
	map.npc_life._advance_ambience(1.0)
	_check(state.spirit.current == sen - 10 and hud.log_lines()[-1] == "虞琼衣将垂花门关上。" and hud.log_lines().has("说道：请保持安静哦!"), "虞琼衣: 10 sen, and the door")
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.corridor7.door", &"latemoon.room.corridor7")) and map.open_door(&"latemoon.room.corridor7.door"), "open again")
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.flower1"), "south")
	map.npc_life._advance_ambience(1.0)
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.flower1.door", &"latemoon.room.flower1")) and map.open_door(&"latemoon.room.flower1.door"), "the 小帘门 opens")
	await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.bathroom1")
	_check(session.player_runtime().world_location().zone_id == &"latemoon.room.flower1" and hud.is_asking() and hud.confirm_prompt.message.text.contains(ASKED), "a man is stopped and asked: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not hud.is_asking() and session.player_runtime().world_location().zone_id == &"latemoon.room.flower1", "取消: he stays out")
	await tree.physics_frame
	await tree.physics_frame
	await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.bathroom1")
	_check(hud.is_asking(), "asked again")
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(session.player_runtime().world_location().zone_id == &"latemoon.room.bathroom1", "确定进去: in the changing room")
	await tree.physics_frame
	var shinyu: NpcRuntimeState = _npc(map, &"latemoon.npc.room.shinyu")
	_check(shinyu != null and shinyu.world_location().zone_id == &"latemoon.room.bathroom1", "阮欣郁 is there")
	var gin: int = state.essence.current
	var kee: int = state.vitality.current
	sen = state.spirit.current
	map.npc_life._advance_ambience(1.0)
	lines = hud.log_lines()
	_check(lines.has("欣郁大喊： 喂! 兄台! 这不准男人进来!") and lines.has("欣郁从袖里取出一把粉红色细粉泼撒出去。") and lines.has("欣郁一脚往闯入者踢了出去。") and lines.has("阮欣郁将小帘门关上。"), "she shouts, powders, kicks and shuts the curtain: %s" % [lines.slice(-5)])
	_check(state.essence.current == gin - 50 and state.vitality.current == kee - 100 and state.spirit.current == sen - 50 and _poison(state) == 10, "gin 50, kee 100, sen 50, rose_poison 10")
	_check(session.player_runtime().world_location().zone_id == &"latemoon.room.flower1" and not map.door(&"latemoon.room.flower1.door").is_open(), "kicked out to 内厅穿堂, the curtain shut")
	sen = state.spirit.current
	map.npc_life._advance_ambience(1.0)
	_check(state.spirit.current == sen - 20 and _poison(state) == 2, "龙韶吟 greets the one thrown in: apply_condition makes the poison 2")
	await tree.physics_frame
	await tree.physics_frame
	_check(await MapPlaces.drive(tree, map, MapPlaces.door_spot(map, &"latemoon.room.flower1.door", &"latemoon.room.flower1")) and map.open_door(&"latemoon.room.flower1.door"), "the curtain again")
	await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.bathroom1")
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.physics_frame
	await tree.physics_frame
	# Through before she greets (no NPC time passes): on to the pool.
	_check(await MapPlaces.drive_to_zone(tree, map, &"latemoon.room.bathroom"), "past her to the pool")
	var skirt: StringName = map.give_new_item_to_player(SKIRT) # TEST-ONLY
	hud._wear_item(skirt)
	_check(hud.log_lines()[-1] == "只有女生才可穿哦!你变态呀!" and not session.player_runtime().armor.is_worn(skirt), "the 布裙 refuses a man with its own line")
	hud.dismiss_current_panel()
	await tree.physics_frame
	var bath: ActService = map.service(&"latemoon.room.bathroom.bath") as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, &"latemoon.room.bathroom.bath")) and bath.in_reach(), "by the pool")
	bath.interact()
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains(ASKED), "a man bathing is asked first")
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(_poison(state) == 15 and hud.log_lines()[-1] == "你觉得池水好像有种奇特的沁凉！", "确定沐浴: rose_poison 15")
	map.npc_life._advance_ambience(1.0)
	_check(session.combat_encounter_coordinator().has_active_encounter() and hud.log_lines().has("神像眼神骤变，幻化成七彩凤凰，出现金色光芒。") and hud.log_lines().has("看起来凤凰想杀死你！"), "凤凰 rises against a man: a fight to the death")


## Out and back in, the NPCs' init() noting each arrival (no greeting comes due).
func _drive_out_and_in(tree: SceneTree, map: WorldMapController, out: StringName, back: StringName) -> void:
	_check(await MapPlaces.drive_to_zone(tree, map, out), "out to %s" % out)
	map.npc_life._advance_ambience(0.0)
	_check(await MapPlaces.drive_to_zone(tree, map, back), "back to %s" % back)


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


func _logged(hud: SharedGameplayUI, part: String) -> bool:
	for line: String in hud.log_lines():
		if line.contains(part):
			return true
	return false


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npcs.residents:
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _poison(state: CharacterState) -> int:
	var payload: DurationConditionPayload = state.conditions.get_condition(ConditionIds.ROSE_POISON) as DurationConditionPayload
	return 0 if payload == null else payload.remaining


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
