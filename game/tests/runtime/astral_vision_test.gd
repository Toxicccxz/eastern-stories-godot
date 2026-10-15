extends RefCounted

## 鬼门关 B: 茅山道术's 阴阳眼 (daemon/class/taoist/necromancy/astral_vision.c). 30 mana and 5
## sen; apply/astral_vision for query_skill("spells") seconds, refused while it runs; busy 3 in
## a fight; its end tells the caster. While it runs std/char.c visible() lets the living player
## see ghosts: 乔阴's 孤魂野鬼 is drawn, picked and fought, and its 从寿衣撕下的布条 falls when
## it dies (a ghost leaves no corpse) for the player to study 基本咒文 up to 40. Cast from the
## 武学 page outside a fight, from the battle panel in one. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Choyin := preload("res://tests/runtime/choyin_secrets_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const GHOST: StringName = &"choyin.npc.ghost"
const CLOTH: StringName = &"es2:d/choyin/obj/cloth_piece"
const ASTRAL: StringName = &"astral_vision"
const CAST_LINE: String = "你微一凝神，闭著眼睛念了几句咒语，施展「阴阳眼」法术。"
const ENDED: String = "你的阴阳眼法术失效了。"
const RUNNING: String = "你已经施展过阴阳眼的法术了。"

var _count: int = 0
var _failures: Array[String] = []
var _requests: int = 0


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_spell()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_ghost_hunt(tree, session)
	await _test_in_a_fight(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.skill(&"necromancy").cast_functions.has(ASTRAL), "茅山道术 casts astral_vision")
	var spell: CastFunction = SpecialFunctions.cast(ASTRAL)
	_check(spell is AstralVisionSpell and spell.self_label == "阴阳眼" and spell.label.is_empty() and spell.self_anywhere, "阴阳眼: cast at oneself, in a fight or out of one")
	_check(SpecialFunctions.cast_ending(CharacterState.ASTRAL_VISION) == spell and SpecialFunctions.ending(CharacterState.ASTRAL_VISION) == null, "its timed apply ends through the spell file")
	var cloth: ItemContentDefinition = catalog.item(CLOTH)
	_check(cloth.study != null and cloth.study.skill_id == &"spells" and cloth.study.max_skill == 40, "the 布条 teaches 基本咒文 to 40")
	var ghost: NpcDefinition = catalog.npc(GHOST)
	_check(ghost.is_ghost(), "孤魂野鬼 is a ghost")


## astral_vision.c cast(): its checks, costs and the timed apply; remove_effect()'s line.
func _test_spell() -> void:
	var state := CharacterState.new()
	state.skills.set_raw_level(&"spells", 40)
	state.skills.set_raw_level(&"necromancy", 30)
	state.skills.map_skill(&"spells", &"necromancy")
	state.recovery.mana = CharacterInternalResourceState.new(29, 100)
	state.spirit = CharacterResourceState.new(100, 100, 100)
	var me := SpecialSide.new(&"player", state, ActionBusyState.new(), CombatRelationshipState.new())
	me.is_user = true
	var context := SpecialContext.new(me, [], func(_bound: int) -> int: return 0, GameContent.catalog())
	_check(not CastService.cast(context, ASTRAL, false) and context.report().lines()[0].template == "你的法力不够。" and not state.sees_ghosts(), "29 mana: 你的法力不够。")
	state.recovery.mana.current = 100
	context = SpecialContext.new(me, [], func(_bound: int) -> int: return 0, GameContent.catalog())
	_check(CastService.cast(context, ASTRAL, false), "cast")
	var spells: int = me.query_skill(&"spells")
	var entry: CharacterTimedApplies.Entry = state.timed_applies.entries()[0]
	_check(spells == 50 and entry.effect_id == ASTRAL and entry.remaining_ms == 50000 and entry.applies == ({ASTRAL: 1} as Dictionary[StringName, int]), "apply/astral_vision for query_skill(\"spells\") seconds: %d" % entry.remaining_ms)
	_check(state.recovery.mana.current == 70 and state.spirit.current == 95 and state.sees_ghosts(), "30 mana, 5 sen; ghosts seen")
	var line: VisionLine = context.report().lines()[0]
	_check(line.template == "$N微一凝神，闭著眼睛念了几句咒语，施展「阴阳眼」法术。" and line.color == ColoredLine.HIB and not me.busy.is_busy(), "its HIB line; not busy outside a fight")
	context = SpecialContext.new(me, [], func(_bound: int) -> int: return 0, GameContent.catalog())
	_check(not CastService.cast(context, ASTRAL, false) and context.report().lines()[0].template == RUNNING and state.recovery.mana.current == 70, "again while it runs: refused, nothing spent")
	_check(SpecialFunctions.cast(ASTRAL).self_sen_cost(state) == 0, "no sen to warn of while it runs")
	var ended: Array[CharacterTimedApplies.Entry] = state.timed_applies.advance_entries(50000)
	_check(ended.size() == 1 and not state.sees_ghosts(), "after 50 s it ends")
	context = SpecialContext.new(me, [], func(_bound: int) -> int: return 0, GameContent.catalog())
	SpecialFunctions.cast_ending(ASTRAL).remove_effect(context, ended[0])
	_check(context.report().lines().size() == 1 and context.report().lines()[0].template == ENDED, "remove_effect(): " + ENDED)
	me.is_user = false
	context = SpecialContext.new(me, [], func(_bound: int) -> int: return 0, GameContent.catalog())
	SpecialFunctions.cast_ending(ASTRAL).remove_effect(context, ended[0])
	_check(context.report().is_empty(), "tell_object(): nobody else reads it")
	# call_out(..., 0): with no spells at all it still ends, a moment later.
	var none := CharacterState.new()
	none.recovery.mana = CharacterInternalResourceState.new(100, 100)
	var bare := SpecialSide.new(&"bare", none, ActionBusyState.new(), CombatRelationshipState.new())
	_check(SpecialFunctions.cast(ASTRAL).cast(SpecialContext.new(bare, [], func(_bound: int) -> int: return 0, GameContent.catalog())) and none.sees_ghosts() and none.timed_applies.advance(1) == [ASTRAL], "query_skill 0: on, then off at once")


## A 茅山 player at 乔阴's north gate: the 孤魂野鬼 unseen; 阴阳眼 from the 武学 page (asked
## first when its 5 sen would knock them out); seen, picked and killed; the 布条 falls, is taken
## and studied; world time ends the spell with its line and the ghosts are unseen again.
func _test_ghost_hunt(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var arts: PlayerMartialArts = session.martial_arts()
	_check(session.handoff_to(&"choyin.town", &"choyin.n_gate", &"choyin.n_gate", &"choyin.n_gate.road_arrival").succeeded(), "TEST-ONLY: at 乔阴's north gate")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var ghost: NpcRuntimeState = Choyin.new()._npc(map, GHOST)
	var body: WorldCharacterBody2D = map.runtime_body_for_character(ghost.character_id)
	_check(not body.visible and not map.select_npc(ghost.character_id), "the 孤魂野鬼 unseen")
	_check(arts.self_spells().is_empty(), "no 法术 without 茅山道术")
	_mao_shan(player.state)
	_check(arts.self_spells() == [ASTRAL] and SpecialFunctions.CASTS.has(ASTRAL), "茅山道术 enabled: 阴阳眼 on the 武学 page")
	player.state.spirit.current = 4 # TEST-ONLY: 5 sen would knock them out
	_check(arts.cast_self_knocks_out(ASTRAL), "4 sen: asked first")
	hud.cast_self(ASTRAL)
	_check(hud.questions.is_asking() and not player.state.sees_ghosts(), "the question, nothing cast yet")
	hud.questions.on_prompt_cancelled()
	await tree.physics_frame
	player.state.spirit.current = player.state.spirit.maximum
	_check(not arts.cast_self_knocks_out(ASTRAL), "full sen: no question")
	hud.cast_self(ASTRAL)
	_check(hud.log_lines().has(CAST_LINE) and player.state.sees_ghosts(), "cast: " + CAST_LINE)
	session._process(0.0)
	_check(body.visible and body.input_pickable and map.select_npc(ghost.character_id), "the 孤魂野鬼 drawn and picked")
	_check(not arts.cast_self(ASTRAL) and hud.log_lines()[-1] == RUNNING, "again: " + RUNNING)
	# The fight: the player strong enough, the ghost one blow from death.
	_full(player)
	_check(map.place_player(ghost.world_location().zone_id, MapPlaces.spot(map, ghost.world_location().zone_id, body.global_position, 40.0)), "TEST-ONLY: beside it")
	await tree.physics_frame
	map.select_npc(ghost.character_id)
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "attacked: %s" % started.outcome)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.player_can_target(ghost.character_id), "seen in the fight: a battle target")
	ghost.character_state.vitality.apply_wound(ghost.character_state.vitality.effective - 1) # TEST-ONLY: one blow left
	for _round: int in range(200):
		if ghost.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
			break
		coordinator.advance_scheduler(1.0)
	var cloth: StringName = map.floor_items.floor_item_of(CLOTH, ghost.world_location().zone_id)
	_check(ghost.life_status == CharacterRuntimeLifeStatus.Value.DEAD and not cloth.is_empty(), "killed; its 布条 falls (no corpse)")
	await Choyin.new()._leave_fight(tree, session)
	_check(player.state.sees_ghosts(), "the spell still runs (%d ms left)" % _left(player.state))
	var choyin := Choyin.new()
	_check(await choyin._take_floor(tree, map, CLOTH, ghost.world_location().zone_id), "the 布条 taken")
	var carried: StringName = choyin._carried(session, CLOTH)
	player.state.skills.set_raw_level(SkillIds.LITERATE, 30) # TEST-ONLY: study.c needs literate
	var before: int = player.state.skills.learned_progress(&"spells")
	var read: StudyResult = arts.study(carried)
	_check(read.outcome == StudyResult.Outcome.STUDIED and player.state.skills.learned_progress(&"spells") > before, "studied 基本咒文: %s" % read.outcome)
	player.state.skills.set_raw_level(&"spells", 41) # TEST-ONLY: study.c refuses above max_skill (40 still reads)
	_check(arts.study(carried).outcome == StudyResult.Outcome.TOO_SHALLOW, "above 40: no more from it")
	# The spell runs out on world time.
	var other: NpcRuntimeState = Choyin.new()._npc(map, GHOST)
	session._process(float(_left(player.state)) / 1000.0 + 0.1)
	_check(not player.state.sees_ghosts() and hud.log_lines().has(ENDED), "it ends: " + ENDED)
	_check(other == null or not map.runtime_body_for_character(other.character_id).visible, "the other ghosts unseen again")
	_check(not map.select_npc(ghost.character_id), "nothing ghostly to pick")


## In a fight: the battle panel's 阴阳眼 (cast at oneself), busy 3, and its end in the fight's
## rounds with its line.
func _test_in_a_fight(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var map: WorldMapController = session.active_map() as WorldMapController
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var target: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not npc.definition().is_ghost() and npc.world_location().shares_combat_location(player.world_location()) and not npc.definition().dealings().is_fight_deferred():
			target = npc
			break
	if target == null:
		for npc: NpcRuntimeState in map.resident_npcs():
			if npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not npc.definition().is_ghost() and not npc.definition().dealings().is_fight_deferred():
				target = npc
				break
	_check(target != null, "TEST-ONLY: someone to fight")
	if target == null:
		return
	_check(map.relocate_player(target.world_location().zone_id, target.spawn_point_id), "TEST-ONLY: beside %s" % target.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame
	target.character_state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: lasts the fight
	map.select_npc(target.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a fight")
	var action: StringName = CombatCastTacticalPolicy.action_id_for(ASTRAL, true)
	var offered: Array[StringName] = []
	for info: CombatTacticalActionInfo in coordinator.action_infos():
		offered.append(info.action_id)
	_check(offered.has(action) and not offered.has(CombatCastTacticalPolicy.action_id_for(ASTRAL)), "the battle panel: 阴阳眼 at oneself only")
	var surface: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var spirit: int = player.state.spirit.current
	player.state.spirit.current = 4 # TEST-ONLY: its 5 sen would knock the player out
	var question: PackedStringArray = surface._question_for(action)
	_check(question.size() == 2 and question[0].begins_with("施展阴阳眼要耗去 5 点神") and question[1] == "确定施展", "the battle panel asks first: %s" % [question])
	player.state.spirit.current = spirit
	_check(surface._question_for(action).is_empty(), "with sen to spare it does not")
	player.state.skills.set_raw_level(&"spells", 2) # TEST-ONLY: query_skill("spells") 1 + 30 → 31 s
	_requests += 1
	var result: CombatTacticalResult = coordinator.submit_player_action(CombatTacticalRequest.new(
		StringName("cast:%d" % _requests), coordinator.active_encounter().encounter_id, player.character_id, action, CombatTacticalRequest.Category.SPELL,
	))
	_check(result.code == CombatTacticalResult.Code.ACCEPTED, "queued: %s" % BattleFeedbackReader.reason(result.code))
	var cast: bool = false
	var ended: bool = false
	for _round: int in range(80):
		for event: CombatSchedulerEvent in coordinator.advance_scheduler(1.0).events():
			if event.kind == CombatSchedulerEvent.Kind.SPECIAL_EFFECT_ENDED and event.actor_id == player.character_id and event.special != null:
				for line: VisionLine in event.special.lines():
					ended = ended or line.template == ENDED
		if not cast and player.state.sees_ghosts():
			cast = true
			_check(player.busy.is_busy(), "busy after casting in a fight")
		if ended or not coordinator.has_active_encounter():
			break
	_check(cast and ended and not player.state.sees_ghosts(), "cast in the fight, ended in its rounds: " + ENDED)
	await Choyin.new()._leave_fight(tree, session)


## TEST-ONLY: 茅山道术 30 enabled for spells, mana to spend.
func _mao_shan(state: CharacterState) -> void:
	state.skills.set_raw_level(&"spells", 20)
	state.skills.set_raw_level(&"necromancy", 30)
	state.skills.map_skill(&"spells", &"necromancy")
	state.recovery.mana = CharacterInternalResourceState.new(300, 300)


func _full(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: nobody dies here
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 100000 # TEST-ONLY
	player.state.attributes.courage = 1000 # TEST-ONLY: the player strikes every turn


func _left(state: CharacterState) -> int:
	for entry: CharacterTimedApplies.Entry in state.timed_applies.entries():
		if entry.effect_id == ASTRAL:
			return entry.remaining_ms
	return 0


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("astral_vision: " + message)
