extends RefCounted

## 玉螺湖村 B (d/village/melonfarm.c, npc/meloner.c): the 瓜地's pick. random(kar) > random(30)
## finds a melon; with a 瓜农 standing in the 瓜棚, random(kar) > random(10) brings the first of
## them over to fight the thief to the death (both marked melon/catch_thief), each roll drawn
## once and only when reached. Asked first while he is clearly stronger (owner A10). While he
## stands in the 瓜地, both ways out say 你的去路被瓜农拦住了。; down, dead or gone, they open
## (owner's modern fix). In the fight he says 你要不还我瓜钱… on half his beats; 还瓜钱 (battle
## panel and HUD) pays the 西瓜's 60 文 as buying does (你的钱不够。: the fight goes on), and he
## says 好，咱俩的账就算结了。 and goes home. The marks are saved. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const PICK: StringName = &"village.melonfarm.pick"
const MELONER: StringName = &"village.npc.meloner"
const MELON: StringName = &"es2:d/village/obj/melon"
## The 瓜棚 is its own map since the remap (its door onto the 瓜地 and the road).
const SHED: StringName = &"village.melonguard_house"
const FLAG: String = "melon/catch_thief"
const SETTLE: StringName = &"combat.settle.village.npc.meloner"
const HELD: String = "你的去路被瓜农拦住了。"
const FOUND: String = "你找来找去，终于找到了一个熟透了的大西瓜抱在怀中。"
const SETTLED: String = "瓜农说道：好，咱俩的账就算结了。"
## Rolls (kar 20): random(20) > random(30), then random(20) > random(10).
const MISS: Array[int] = [5, 10]
const DOZING: Array[int] = [15, 3, 2, 5]
const CAUGHT: Array[int] = [15, 3, 9, 5]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_rolls()
	_test_rules()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.attributes.karma = 20 # TEST-ONLY: the rolls' kar
	player.state.progression.combat_experience = 10000 # TEST-ONLY: the 瓜农 is no stronger
	await _test_pick(tree, session)
	await _test_caught(tree, session)
	await _test_held(tree, session)
	await _test_second_catch(tree, session)
	await _test_lifted(tree, session)
	await _test_death(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var service: ServiceDefinition = catalog.service(PICK)
	_check(service != null and service.zone_id == &"village.melonfarm" and service.act.verb == "摘西瓜", "瓜地 · 摘西瓜")
	_check(service.act.draws() and service.act.acts.size() == 4 and service.act.acts[0].kar_above == [30, 10] and service.act.acts[1].kar_above == [30] and service.act.acts[3].kar_above.is_empty(), "four branches: caught, dozing, lucky, nothing")
	_check(service.act.stronger_npc_id == MELONER and service.act.stronger_zone_id == &"village.melonguard", "asked first about the 瓜棚's 瓜农 (A10)")
	var settle: NpcSettle = catalog.npc(MELONER).dealings().settle
	_check(settle != null and settle.temp == FLAG and settle.price(catalog) == 60 and settle.label == "还瓜钱", "还瓜钱: the 西瓜's 60 文")
	var chat: Array = catalog.npc(MELONER).talk().combat_chat_entries()
	_check(catalog.npc(MELONER).talk().combat_chat_chance == 50 and chat.size() == 1 and chat[0] is NpcFightChat.SayWhileFlag and chat[0].flag == StringName(FLAG), "catch_thief(): chat_chance_combat 50, said only while he is catching")
	_check(NpcTalk.line(chat[0].say) == "你要不还我瓜钱，咱俩就没完！", "its hint and stray ） gone")


## The rolls: each drawn once, in order, and only when reached (melonfarm.c's nested ifs).
func _test_rolls() -> void:
	_check(_rolls(MISS, true) == [3, [20, 30]], "random(kar) <= random(30): nothing, one roll: %s" % [_rolls(MISS, true)])
	_check(_rolls([15, 3], false) == [2, [20, 30]], "found, nobody in the 瓜棚: 你真幸运, no second roll: %s" % [_rolls([15, 3], false)])
	_check(_rolls(DOZING, true) == [1, [20, 30, 20, 10]], "found, the 瓜农 dozing: %s" % [_rolls(DOZING, true)])
	_check(_rolls(CAUGHT, true) == [0, [20, 30, 20, 10]], "found and caught: %s" % [_rolls(CAUGHT, true)])
	_check(_rolls([0], true, 0) == [3, [30]], "kar 0: random(0) is 0 without a draw: %s" % [_rolls([0], true, 0)])
	var facts := ScriptedAct.Facts.new()
	facts.standing_in = func(_npc: StringName, _zone: StringName) -> bool: return true
	_check(GameContent.catalog().service(PICK).act.act_for(&"", &"", facts) != null, "without a draw (the button) a branch is there")


## [the branch chosen, the bounds drawn].
func _rolls(draws: Array[int], present: bool, kar: int = 20) -> Array:
	var source := ScriptedWorldInteractionRandomSource.new(draws)
	var facts := ScriptedAct.Facts.new()
	facts.kar = kar
	facts.draw = source.legacy_random
	facts.standing_in = func(_npc: StringName, _zone: StringName) -> bool: return present
	var act: RoomActDefinition = GameContent.catalog().service(PICK).act
	return [act.acts.find(act.act_for(&"", &"", facts)), source.requested_bounds()]


func _test_rules() -> void:
	for to: StringName in [&"village.road4", &"village.melonguard"]:
		var rules: Array[ZoneExitRuleDefinition] = GameContent.catalog().exit_rules_between(&"village.melonfarm", to)
		var rule: ZoneExitRuleDefinition = null if rules.is_empty() else rules[0]
		var thief := ZoneExitRuleDefinition.Leaver.new()
		thief.temps = {FLAG: 1}
		_check(rule != null and rule.condition == ZoneExitRuleDefinition.Condition.HELD and rule.lines == [HELD], "%s: held" % to)
		_check(rule.refuses(thief, true) and not rule.refuses(thief, false) and not rule.refuses(ZoneExitRuleDefinition.Leaver.new(), true), "%s: only the thief, only while he stands there" % to)


## Into the 瓜地 by the 青石小路; nothing found, the 瓜农 dozing, nobody in the 瓜棚.
func _test_pick(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"village.main", &"village.road1", &"village.road1", &"village.road1.canyon_arrival").succeeded(), "TEST-ONLY: on the 黄土大道")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	_check(await MapPlaces.drive_through(tree, map, [&"village.road2", &"village.road3", &"village.road4", &"village.melonfarm"]), "down into the 瓜地")
	var pick: ActService = map.service(PICK) as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, PICK)) and pick.in_reach() and pick.verb() == "摘西瓜", "瓜地 · 摘西瓜")
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	_pin(session, MISS)
	pick.interact()
	_check(hud.log_lines()[-1] == "你找来找去，终于还是没找到熟透的西瓜。" and _melons(session) == 0, "nothing found: %s" % [hud.log_lines().slice(-2)])
	_pin(session, DOZING)
	pick.interact()
	_check(hud.log_lines().slice(-2) == [FOUND, "瓜农似乎正在打瞌睡，没有发现你的小动作。"] and _melons(session) == 1, "a melon, the 瓜农 dozing: %s" % [hud.log_lines().slice(-2)])
	var shed: Array[NpcRuntimeState] = _meloners(session, &"village.melonguard")
	_check(shed.size() == 3, "three 瓜农 in the 瓜棚")
	for npc: NpcRuntimeState in shed:
		npc.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: nobody watching
	_pin(session, [15, 3])
	pick.interact()
	_check(hud.log_lines().slice(-2) == [FOUND, "你真幸运，瓜农没有在瓜棚看瓜。"] and _melons(session) == 2, "nobody in the 瓜棚: %s" % [hud.log_lines().slice(-2)])
	for npc: NpcRuntimeState in shed:
		npc.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_check(not session.combat_encounter_coordinator().has_active_encounter() and int(session.player_runtime().temp_marks.get(FLAG, 0)) == 0, "no fight, no mark")
	session.configure_world_interaction_random_source(original)


## Asked first while he is clearly stronger; caught: he comes, both are marked, the fight to the
## death; his line while he catches; 还瓜钱 short of money, then paid: he walks home.
func _test_caught(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var pick: ActService = map.service(PICK) as ActService
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	player.state.progression.combat_experience = 0 # TEST-ONLY: the 瓜农 (8000) is clearly stronger
	var source: ScriptedWorldInteractionRandomSource = _pin(session, CAUGHT)
	pick.interact()
	await tree.physics_frame
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("瓜农比你强得多"), "asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	await tree.physics_frame
	_check(source.call_count() == 0 and _melons(session) == 2, "取消: nothing drawn, nothing picked")
	var catcher: NpcRuntimeState = _meloners(session, &"village.melonguard")[0]
	pick.interact()
	await tree.physics_frame
	hud.confirm_prompt.confirm_button.pressed.emit()
	await tree.physics_frame
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(_melons(session) == 3 and source.requested_bounds() == [20, 30, 20, 10], "found (the melon is the thief's either way)")
	_check(catcher.world_location().zone_id == &"village.melonfarm" and _meloners(session, &"village.melonguard").size() == 2, "the first of them came over")
	_check(map.find_resident_npc(catcher.character_id) == catcher and session.world_map_of(SHED).find_resident_npc(catcher.character_id) == null and map.runtime_body_for_character(catcher.character_id) != null, "out of his 瓜棚 (its own map) onto the 瓜地's, body and all")
	_check(catcher.has_flag(StringName(FLAG)) and int(player.temp_marks.get(FLAG, 0)) == 1, "both marked melon/catch_thief")
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.LETHAL, "a fight to the death")
	_check(hud.log_lines().has("糟糕，瓜农发现了你偷瓜，向这边冲过来！") and hud.log_lines().has(FOUND), "糟糕，瓜农发现了你偷瓜…")
	session.configure_world_interaction_random_source(original)
	player.state.progression.combat_experience = 10000 # TEST-ONLY
	var kept: CharacterResourceState = player.state.vitality
	var his: CharacterResourceState = catcher.character_state.vitality
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: the fight lasts
	catcher.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	# catch_thief(): his line on about half his beats, while he is catching.
	var said: int = 0
	var beats: int = 0
	for _cycle: int in range(40):
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1.0)
		for event: CombatSchedulerEvent in advanced.events():
			if event.chat != null and event.actor_id == catcher.character_id:
				beats += 1
				if event.chat.lines().any(func(line: VisionLine) -> bool: return line.template == "瓜农说道：你要不还我瓜钱，咱俩就没完！"):
					said += 1
	_check(said > 0 and coordinator.has_active_encounter(), "你要不还我瓜钱，咱俩就没完！ (%d of %d chats)" % [said, beats])
	var info: CombatTacticalActionInfo = _info(coordinator, SETTLE)
	_check(info != null and BattleActionPresentationCatalog.new().label_for(SETTLE) == "还瓜钱", "还瓜钱 on the battle panel")
	var money: MoneyInventoryContext = Finance.session_context(session)
	_spend_all(money) # TEST-ONLY: penniless
	coordinator.submit_player_action(CombatTacticalRequest.new(&"settle.poor", coordinator.active_encounter().encounter_id, player.character_id, SETTLE, info.category))
	coordinator.advance_scheduler(0.0)
	_check(map.debts.last_lines == ["你的钱不够。"] and coordinator.has_active_encounter() and catcher.has_flag(StringName(FLAG)), "你的钱不够。: the fight goes on")
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 1, &"000-test-melon-silver") # TEST-ONLY
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 100, &"000-test-melon-coin")
	coordinator.submit_player_action(CombatTacticalRequest.new(&"settle.paid", coordinator.active_encounter().encounter_id, player.character_id, SETTLE, info.category))
	coordinator.advance_scheduler(0.0)
	_check(map.debts.last_lines == [SETTLED] and not coordinator.has_active_encounter(), "好，咱俩的账就算结了。: the fight is over")
	_check(Finance.amount(money, CurrencyDenomination.Value.COIN) == 40 and Finance.amount(money, CurrencyDenomination.Value.SILVER) == 1, "60 文 paid")
	_check(not catcher.has_flag(StringName(FLAG)) and int(player.temp_marks.get(FLAG, 0)) == 0, "both marks gone")
	_check(catcher.world_location().zone_id == &"village.melonguard" and session.world_map_of(SHED).find_resident_npc(catcher.character_id) == catcher and map.find_resident_npc(catcher.character_id) == null, "he went home (into the 瓜棚's own map): %s" % catcher.world_location().zone_id)
	hud.dismiss_current_panel()
	for _frame: int in range(3):
		await tree.physics_frame
	player.state.vitality = kept
	catcher.character_state.vitality = his
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.road4") and await MapPlaces.drive_to_zone(tree, map, &"village.melonfarm"), "the way out is open again")


## Caught and fled: he stands in the 瓜地 and both ways out are refused; the marks are saved;
## 还瓜钱 on the HUD pays him off where he stands.
func _test_held(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var catcher: NpcRuntimeState = await _caught_and_fled(tree, session)
	if catcher == null:
		return
	_check(not await MapPlaces.drive_to_zone(tree, map, &"village.road4") and player.world_location().zone_id == &"village.melonfarm" and hud.log_lines().has(HELD), "north: 你的去路被瓜农拦住了。")
	_check(not await MapPlaces.take_passage(tree, map, &"village.melonfarm.south", 240) and session.active_map() == map and player.world_location().zone_id == &"village.melonfarm", "south (the 瓜棚's door, its own map): held too")
	var pick: ActService = map.service(PICK) as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, PICK)), "by the melons, held")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null and GameSaveJsonCodec.encode(snapshot).text.count(FLAG) >= 2, "fled and held: Save keeps both marks")
	var work: Work = Work.new()
	await work.round_trip(tree, session, snapshot, "held")
	for failure: String in work._failures:
		_failures.append("village melon: " + failure)
	await _beside(tree, map, catcher)
	hud.refresh_live_state()
	hud.refresh_exploration()
	var name: String = catcher.definition().short_name()
	_check(hud.nearby.actions_of(name).has("还瓜钱"), "还瓜钱 on the HUD: %s" % [hud.nearby.actions_of(name)])
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 100, &"000-test-melon-0coin") # TEST-ONLY: buy.c pays 60 from the first coin stack
	var coins: int = Finance.amount(money, CurrencyDenomination.Value.COIN)
	_check(hud.nearby.press(name, "还瓜钱") and hud.log_lines()[-1] == SETTLED, "paid on the HUD: %s" % [hud.log_lines().slice(-2)])
	_check(Finance.amount(money, CurrencyDenomination.Value.COIN) == coins - 60 and not catcher.has_flag(StringName(FLAG)) and catcher.world_location().zone_id == &"village.melonguard", "60 文, and home he goes")
	hud.refresh_exploration()
	_check(not hud.nearby.actions_of(name).has("还瓜钱"), "no 还瓜钱 once settled")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.road4") and await MapPlaces.drive_to_zone(tree, map, &"village.melonfarm"), "the way out is open")
	_check(not pick.context_title().is_empty(), "the melons again")


## Fled from one catcher, caught by a second while the first still stands there: 还瓜钱 on the
## battle panel pays the one fighting (Codex, #116), and clears the first one's claim too.
func _test_second_catch(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var first: NpcRuntimeState = await _caught_and_fled(tree, session)
	if first == null:
		return
	var second: NpcRuntimeState = _meloners(session, &"village.melonguard")[0]
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	_pin(session, CAUGHT)
	(map.service(PICK) as ActService).interact()
	session.configure_world_interaction_random_source(original)
	_check(coordinator.has_active_encounter() and second.has_flag(StringName(FLAG)) and second.relationship.has_opponent(player.character_id) and not first.relationship.has_opponent(player.character_id), "a second 瓜农 fights; the first stands by, flagged")
	var info: CombatTacticalActionInfo = _info(coordinator, SETTLE)
	_check(info != null, "还瓜钱 on the battle panel for the one fighting")
	if info == null:
		return
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 100, &"000-test-melon-00coin") # TEST-ONLY: buy.c pays 60 from the first coin stack
	coordinator.submit_player_action(CombatTacticalRequest.new(&"settle.second", coordinator.active_encounter().encounter_id, player.character_id, SETTLE, info.category))
	coordinator.advance_scheduler(0.0)
	_check(not coordinator.has_active_encounter() and second.world_location().zone_id == &"village.melonguard", "the one fighting was paid and went home")
	_check(not first.has_flag(StringName(FLAG)) and not second.has_flag(StringName(FLAG)) and int(player.temp_marks.get(FLAG, 0)) == 0, "no claim left on either")
	map.debts.send_home(first) # TEST-ONLY: the later tests want the shed full again
	session.shared_ui().dismiss_current_panel()
	for _frame: int in range(3):
		await tree.physics_frame
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.road4") and await MapPlaces.drive_to_zone(tree, map, &"village.melonfarm"), "the way out is open")


## The block lifts while the one who caught the player is down, gone or dead.
func _test_lifted(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var shed: WorldMapController = session.world_map_of(SHED)
	var catcher: NpcRuntimeState = _meloners(session, &"village.melonguard")[0]
	# TEST-ONLY: as a catch leaves it (the fight's own part is _test_caught's): out of the 瓜棚's map.
	_check(session.bring_npc_onto(catcher, shed, map, &"village.melonfarm") and map.npcs.bring_beside_player(catcher), "he came over")
	catcher.set_flag(StringName(FLAG), true)
	player.temp_marks[FLAG] = 1
	await tree.physics_frame
	var other: NpcRuntimeState = _meloners(session, &"village.melonguard")[0]
	_check(session.bring_npc_onto(other, shed, map, &"village.melonfarm") and map.npcs.bring_beside_player(other), "TEST-ONLY: another 瓜农 stands by, unmarked")
	await tree.physics_frame
	_check(not await MapPlaces.drive_to_zone(tree, map, &"village.road4"), "held while he stands")
	catcher.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.road4"), "he is down: the way opens though another 瓜农 stands there")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.melonfarm"), "back in")
	catcher.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_check(not await MapPlaces.drive_to_zone(tree, map, &"village.road4"), "awake again: held")
	_check(session.bring_npc_onto(catcher, map, shed, &"village.melonguard"), "TEST-ONLY: gone (into the 瓜棚, its own map)")
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.road4") and await MapPlaces.drive_to_zone(tree, map, &"village.melonfarm"), "he is gone: open")
	_check(session.bring_npc_onto(catcher, shed, map, &"village.melonfarm"), "TEST-ONLY: back in the 瓜地")
	catcher.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD) # TEST-ONLY
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.road4"), "he is dead: open (ES2 kept the thief in for good)")


## Killed by the 瓜农 who caught them, the dead owe nothing (默认): both marks go.
func _test_death(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(await MapPlaces.drive_to_zone(tree, map, &"village.melonfarm") and await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, PICK)), "by the melons once more")
	var catcher: NpcRuntimeState = _meloners(session, &"village.melonguard")[0]
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	_pin(session, CAUGHT)
	(map.service(PICK) as ActService).interact()
	session.configure_world_interaction_random_source(original)
	_check(coordinator.has_active_encounter() and catcher.has_flag(StringName(FLAG)), "caught once more")
	player.state.progression.combat_experience = 0 # TEST-ONLY: no match for him
	player.state.vitality = CharacterResourceState.new(1, 1, player.state.vitality.maximum)
	for _cycle: int in range(600):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "killed: %s" % CharacterRuntimeLifeStatus.Value.find_key(player.life_status))
	_check(int(player.temp_marks.get(FLAG, 0)) == 0 and not catcher.has_flag(StringName(FLAG)), "both marks gone with the death")


## The next pick catches the player (a 瓜农 comes); they flee. The catcher, or null.
func _caught_and_fled(tree: SceneTree, session: WorldSessionController) -> NpcRuntimeState:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var pick: ActService = map.service(PICK) as ActService
	_check(await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, PICK)), "by the melons")
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	var catcher: NpcRuntimeState = _meloners(session, &"village.melonguard")[0]
	_pin(session, CAUGHT)
	pick.interact()
	session.configure_world_interaction_random_source(original)
	if not coordinator.has_active_encounter():
		_check(false, "caught again")
		return null
	var kept: CharacterResourceState = player.state.vitality
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: the fight lasts
	var his: CharacterResourceState = catcher.character_state.vitality
	catcher.character_state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		var flee: CombatTacticalActionInfo = _info(coordinator, CombatFleeTacticalPolicy.ACTION_ID)
		coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % rounds), coordinator.active_encounter().encounter_id, player.character_id, flee.action_id, flee.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	_check(not coordinator.has_active_encounter() and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.FLED, "fled the fight")
	session.shared_ui().dismiss_current_panel()
	player.state.vitality = kept
	catcher.character_state.vitality = his
	for _frame: int in range(3):
		await tree.physics_frame
	_check(catcher.world_location().zone_id == &"village.melonfarm" and catcher.has_flag(StringName(FLAG)) and int(player.temp_marks.get(FLAG, 0)) == 1, "he stands in the 瓜地, both marked")
	return catcher


func _pin(session: WorldSessionController, draws: Array[int]) -> ScriptedWorldInteractionRandomSource:
	var source := ScriptedWorldInteractionRandomSource.new(draws) # TEST-ONLY: the rolls
	session.configure_world_interaction_random_source(source)
	return source


func _info(coordinator: CombatEncounterCoordinator, action_id: StringName) -> CombatTacticalActionInfo:
	for info: CombatTacticalActionInfo in coordinator.action_infos():
		if info.action_id == action_id:
			return info
	return null


func _spend_all(money: MoneyInventoryContext) -> void:
	for denomination: CurrencyDenomination.Value in [CurrencyDenomination.Value.GOLD, CurrencyDenomination.Value.SILVER, CurrencyDenomination.Value.COIN]:
		for _stack: int in range(6):
			var selected: CurrencyStackSelection = money.select(denomination)
			if selected.item_id.is_empty() or selected.amount == 0:
				break
			money.set_amount(selected.item_id, 0)


func _melons(session: WorldSessionController) -> int:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var count: int = 0
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == MELON:
			count += 1
	return count


## The 瓜农 standing in `zone_id`, in spawn order, on whichever map the zone lies (the 瓜棚's own).
func _meloners(session: WorldSessionController, zone_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in session.world_map_of(MapPlaces.map_of(zone_id)).resident_npcs():
		if npc.definition().definition_id == MELONER and npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.world_location().zone_id == zone_id:
			found.append(npc)
	return found


func _beside(tree: SceneTree, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 48), 40.0) # within the HUD's reach (96)
	if at == Vector2.INF:
		at = MapPlaces.spot(map, zone_id, body.global_position, 140.0)
	_check(at != Vector2.INF and map.place_player(zone_id, at), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("village melon: " + message)
