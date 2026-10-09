extends RefCounted

## 青石村 D: the player's spells. cast.c (busy, no_magic, the enabled spells skill, a
## spell it has not), dun.c at oneself (80 mana, 30 sen, random(spells) < 30 fails, else
## one of five lights and away to Snow's temple) and its 你失败了 for a player, the
## battle panel's 施法 buttons; then the real session: enable and practice, 困 holding
## 工匠, 召天将 in a spar (asked first; the soldier on the player's side kills 工匠, who
## kills it back and picks between the two, and finishes him once he falls; the player
## is credited with its kill: killer_reward() follows `possessed`), the old couple's helper
## and an NPC's own soldier turning on the player's soldier, a no_magic room, and 遁 ending
## a fight in Snow's temple with the soldiers left behind unheard. TEST-ONLY fixtures are
## marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const Juechen := preload("res://tests/runtime/green_juechen_test.gd")
const WORKER: StringName = &"green.npc.worker1"
const QUARRYMAN: StringName = &"green.npc.worker2"
const SOLDIER: StringName = &"common.npc.heaven_soldier"
const VANISH: StringName = &"cast.dun.self"
const TRAP: StringName = &"cast.dun"
const SUMMON: StringName = &"cast.saveme"

var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog
var _original_random: CombatRandomSource
var _requests: int = 0


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_vanish_rules()
	_test_cast_rules()
	_test_labels()
	_test_labels_of_taught_spells()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	_original_random = session.combat_random_source()
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"green.village", &"green.path6", &"green.path6", &"green.path6.snow_entry").succeeded(), "TEST-ONLY: into the village")
	await tree.physics_frame
	await tree.physics_frame
	_test_enable(session)
	await _test_trap(tree, session)
	await _test_summon_in_spar(tree, session)
	await _test_old_couple(tree, session)
	await _test_no_magic(tree, session)
	await _test_vanish(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- Spells -------------------------------------------------------------------------

## dun.c at oneself: 80 mana and 30 sen; random(spells) < 30 fails (你失败了, the caster
## alone); else the chant and one of five lights, and the caster is gone to the temple.
func _test_vanish_rules() -> void:
	var pair: Array[SpecialSide] = _pair()
	var context: SpecialContext = _context(pair, Specials.Pattern.new([30, 4]))
	context.target = pair[0]
	_check(pair[0].query_skill(&"spells") == 130, "the player's spells: 100 / 2 + 奇门遁甲 80")
	_check(SpecialFunctions.cast(&"dun").cast(context), "遁 at oneself is cast")
	_check(pair[0].state.recovery.mana.current == 920 and pair[0].state.spirit.current == 270, "80 mana and 30 sen")
	_check(context.departure == DunSpell.DESTINATION and DunSpell.DESTINATION == &"es2:d/snow/temple", "away to /d/snow/temple")
	_check(context.lines.size() == 2 and context.lines[0].template == DunSpell.CHANT and context.lines[1].template == "只见$N化作一团大雾，然后消失得无影无踪！" and context.lines[1].color == ColoredLine.HIW and context.lines[0].target_id.is_empty(), "the chant and the great fog (random(5) 4), in HIW")
	pair = _pair()
	context = _context(pair, Specials.Pattern.new([29]))
	context.target = pair[0]
	_check(SpecialFunctions.cast(&"dun").cast(context) and context.departure.is_empty() and context.lines.size() == 1 and context.lines[0].template == "你失败了。" and pair[0].state.recovery.mana.current == 920, "random(spells) 29: 你失败了 for the player, the cost spent")
	pair = _pair()
	pair[0].is_user = false # TEST-ONLY: an NPC caster
	context = _context(pair, Specials.Pattern.new([29]))
	context.target = pair[0]
	_check(SpecialFunctions.cast(&"dun").cast(context) and context.lines.is_empty(), "an NPC's write() reaches nobody")
	pair = _pair()
	pair[0].state.recovery.mana = CharacterInternalResourceState.new(79, 1000)
	context = _context(pair, Specials.Pattern.new())
	context.target = pair[0]
	_check(not SpecialFunctions.cast(&"dun").cast(context) and context.fail_line.template == "你的法力不够！" and pair[0].state.recovery.mana.current == 79, "79 mana: 你的法力不够")
	pair = _pair()
	pair[0].state.spirit = CharacterResourceState.new(29, 300, 300)
	context = _context(pair, Specials.Pattern.new())
	context.target = pair[0]
	_check(not SpecialFunctions.cast(&"dun").cast(context) and context.fail_line.template == "你的精神没有办法有效集中！", "29 sen: 你的精神没有办法有效集中")
	pair = _pair()
	pair[0].relationship.remove_opponent(&"npc")
	context = SpecialContext.new(pair[0], [], Specials.Pattern.new().legacy_random, _catalog)
	context.target = pair[0]
	_check(not SpecialFunctions.cast(&"dun").cast(context) and context.fail_line.template == "这个法术只能在战斗中使用！", "only in a fight")
	# At an enemy the player reads its 你失败了 too.
	pair = _pair()
	context = _context(pair, Specials.Pattern.new([39]))
	context.target = pair[1]
	_check(SpecialFunctions.cast(&"dun").cast(context) and context.lines.size() == 1 and context.lines[0].template == "你失败了。" and pair[0].state.recovery.mana.current == 800 and not pair[1].busy.is_busy(), "困, random(spells) 39: 你失败了, 200 mana spent")


## cast.c: busy, no_magic, an enabled spells skill, a spell that skill has.
func _test_cast_rules() -> void:
	var pair: Array[SpecialSide] = _pair()
	pair[0].busy.start_busy(1)
	var context: SpecialContext = _context(pair, Specials.Pattern.new())
	_check(not CastService.cast(context, &"saveme", false) and context.fail_line.template == "( 你上一个动作还没有完成，不能念咒文。)", "busy: 你上一个动作还没有完成")
	pair = _pair()
	context = _context(pair, Specials.Pattern.new())
	_check(not CastService.cast(context, &"saveme", true) and context.fail_line.template == "这里不准念咒文。" and pair[0].state.recovery.mana.current == 1000, "a no_magic room: 这里不准念咒文")
	context = _context(pair, Specials.Pattern.new())
	_check(not CastService.cast(context, &"netherbolt", false) and context.fail_line.template == "你所选用的咒文系中没有这种咒文。", "a spell 奇门遁甲 has not")
	pair[0].state.skills.unmap_skill(&"spells")
	context = _context(pair, Specials.Pattern.new())
	_check(not CastService.cast(context, &"saveme", false) and context.fail_line.template == "你请先用 enable 指令选择你要使用的咒文系。", "no spells enabled")
	_check(CastService.offered(pair[0].state, _catalog).is_empty(), "nothing offered without it")
	pair = _pair()
	_check(CastService.offered(pair[0].state, _catalog) == [&"dun", &"saveme"], "奇门遁甲 offers 遁 and 召天将")
	context = _context(pair, Specials.Pattern.new([60]))
	_check(CastService.cast(context, &"saveme", false) and context.summons == [SOLDIER] and pair[0].busy.busy_value == 0, "召天将 through cast.c; casting adds no busy")
	_check(pair[0].state.skills.raw_level(&"magic-array") == 80 and pair[0].state.skills.raw_level(&"spells") == 100, "casting improves nothing")
	var errors: Array[String] = []
	var room: RoomDefinition = RoomDefinition.from_record(ContentRecordReader.new({"id": "es2:d/test/room", "short": "房间", "long": "x\n", "no_magic": true}, "test", errors))
	_check(errors.is_empty() and room.no_magic and not room.no_fight, "a room may be no_magic")


## The battle panel's 施法 buttons and their names.
func _test_labels() -> void:
	var catalog := BattleActionPresentationCatalog.new()
	_check(catalog.label_for(VANISH) == "施法「遁」" and catalog.label_for(TRAP) == "施法「困」" and catalog.label_for(SUMMON) == "施法「召天将」", "施法「遁」, 施法「困」, 施法「召天将」")
	_check(CombatCastTacticalPolicy.function_for(VANISH) == &"dun" and CombatCastTacticalPolicy.is_self(VANISH) and not CombatCastTacticalPolicy.is_self(TRAP), "cast.dun.self is dun at oneself")


## Every spell of a skill some NPC teaches has a name on the battle panel or, cast outside a
## fight, on the HUD (林忌 and his disciples teach 茅山道术: its bolts, 召护法 and 驱尸).
func _test_labels_of_taught_spells() -> void:
	var unnamed: Array[String] = []
	for npc: NpcDefinition in _catalog.npcs():
		if npc.teaching() == null:
			continue
		for skill_id: StringName in NpcTeacher.teachable_skills(npc, _catalog):
			for function_id: StringName in _catalog.skill(skill_id).cast_functions:
				var spell: CastFunction = SpecialFunctions.cast(function_id)
				if spell.label.is_empty() and spell.self_label.is_empty() and spell.world_label.is_empty():
					unnamed.append("%s/%s" % [skill_id, function_id])
	_check(unnamed.is_empty(), "every spell a teacher gives has a 施法 name: %s" % [unnamed])


## TEST-ONLY: a player with spells 100 and 奇门遁甲 80 enabled, 1000 mana, 300 sen,
## fighting an NPC of 100 combat_exp and no mana.
func _pair() -> Array[SpecialSide]:
	var state := CharacterState.new()
	_learn(state)
	state.recovery.mana = CharacterInternalResourceState.new(1000, 1000)
	state.spirit = CharacterResourceState.new(300, 300, 300)
	var npc := CharacterState.new()
	npc.progression.combat_experience = 100
	var me_relationship := CombatRelationshipState.new(&"player")
	me_relationship.add_opponent(&"npc")
	var npc_relationship := CombatRelationshipState.new(&"npc")
	npc_relationship.add_opponent(&"player")
	var me := SpecialSide.new(&"player", state, ActionBusyState.new(), me_relationship)
	me.is_user = true
	return [me, SpecialSide.new(&"npc", npc, ActionBusyState.new(), npc_relationship)]


func _context(pair: Array[SpecialSide], random: CombatRandomSource) -> SpecialContext:
	return SpecialContext.new(pair[0], [pair[1]], random.legacy_random, _catalog, SkillImprovementEffectRegistry.new(), [pair[1]])


## TEST-ONLY: spells 100 and 奇门遁甲 80 (小天魔道 90 above it), enabled for spells.
static func _learn(state: CharacterState) -> void:
	state.skills.set_raw_level(&"spells", 100)
	state.skills.set_raw_level(&"tao-mystery", 90)
	state.skills.set_raw_level(&"magic-array", 80)
	state.skills.map_skill(&"spells", &"magic-array")


# --- In the village -------------------------------------------------------------------

## enable spells 奇门遁甲 (mana starts again from 0); practice refuses, as magic-array.c.
func _test_enable(session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(not _offered(coordinator).has(SUMMON), "no 施法 before any spells")
	_learn(player.state)
	player.state.skills.unmap_skill(&"spells")
	player.state.recovery.mana = CharacterInternalResourceState.new(500, 1000)
	_check(session.martial_arts().enable(&"spells", &"magic-array") and player.state.recovery.mana.current == 0, "enable spells 奇门遁甲: mana from 0")
	var said: Array[String] = []
	for line: ColoredLine in session.martial_arts().last_lines:
		said.append(line.text)
	_check(said.has("你改用另一种咒文系，法力必须重新修炼。"), "enable.c's line: %s" % [said])
	_check(_offered(coordinator) == [VANISH, TRAP, SUMMON], "the panel offers 遁, 困 and 召天将: %s" % [_offered(coordinator)])
	session.martial_arts().practice(&"spells")
	_check(session.martial_arts().last_lines.any(func(line: ColoredLine) -> bool: return line.text == "法术类技能必须用学的或是从实战中获取经验。"), "practice spells: 法术类技能必须用学的")
	# TEST-ONLY: whole, mana and kee to spare.
	player.state.recovery.mana = CharacterInternalResourceState.new(1000, 1000)
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000)
	player.state.spirit = CharacterResourceState.new(1000, 1000, 1000)


## 困 on 工匠 in a spar: busy (mana / 200 less his max_mana / 100, plus 2); 你失败了; 正自顾不暇.
func _test_trap(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var worker: NpcRuntimeState = _first(map, WORKER)
	await _beside(tree, map, session, worker)
	session.configure_combat_random_source(Juechen.Forced.new()) # TEST-ONLY: every draw at its highest
	map.select_npc(worker.character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player spars 工匠")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_submit(session, TRAP)
	coordinator.advance_scheduler(0.0)
	_refresh(session)
	@warning_ignore("integer_division")
	var held: int = 800 / 200 - worker.character_state.recovery.mana.maximum / 100 + 2
	_check(worker.busy.busy_value == held and player.state.recovery.mana.current == 800, "工匠 busy %d: %d" % [held, worker.busy.busy_value])
	_check(_battle_log(session).contains("你口中喃喃地念著咒文，忽然大喝一声“疾！”") and _battle_log(session).contains("只见空中落下无数大木，正把工匠困在中央！"), "the chant and the falling trees: %s" % _battle_log(session).right(120))
	_submit(session, TRAP)
	coordinator.advance_scheduler(0.0)
	_refresh(session)
	_check(_battle_log(session).contains("工匠正自顾不暇，放胆进攻吧。") and player.state.recovery.mana.current == 800, "a busy target: 正自顾不暇, nothing spent")
	while worker.busy.is_busy():
		worker.busy.advance() # TEST-ONLY: free again
	var forced := Juechen.Forced.new()
	forced.queues[130] = [39]
	session.configure_combat_random_source(forced) # TEST-ONLY
	_submit(session, TRAP)
	coordinator.advance_scheduler(0.0)
	_refresh(session)
	_check(_battle_log(session).ends_with("你失败了。") and player.state.recovery.mana.current == 600 and not worker.busy.is_busy(), "random(spells) 39: 你失败了: %s" % _battle_log(session).right(40))
	await _flee(tree, session)


## 召天将 in a spar: asked first; the soldier comes on the player's side and kills 工匠, who
## kills it back, picks between the two (random(4)), and is finished once he falls.
func _test_summon_in_spar(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var worker: NpcRuntimeState = _first(map, WORKER)
	_whole(worker.character_state) # TEST-ONLY: healthy enough to accept
	player.state.recovery.mana.current = 1000
	player.state.spirit.current = player.state.spirit.effective
	await _beside(tree, map, session, worker)
	session.configure_combat_random_source(Juechen.Forced.new()) # TEST-ONLY
	map.select_npc(worker.character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player spars 工匠 again")
	_refresh(session)
	var question: PackedStringArray = _ui(session)._question_for(SUMMON)
	_check(question.size() == 2 and question[0] == BattlePresentationController.SAVEME_QUESTION and question[1] == "召唤天将", "in a spar 召天将 is asked first")
	_check(_ui(session)._question_for(TRAP).is_empty() and _ui(session)._question_for(VANISH).is_empty(), "遁 and 困 are not")
	var kills: int = player.state.progression.kills
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var before: Array[StringName] = _npc_ids(map)
	_submit(session, SUMMON)
	coordinator.advance_scheduler(0.0)
	_refresh(session)
	var soldier_id: StringName = &""
	for id: StringName in _npc_ids(map):
		if not before.has(id):
			soldier_id = id
	var soldier: NpcRuntimeState = map.find_resident_npc(soldier_id)
	_check(soldier != null and SummonedNpc.definition_id_of(soldier_id) == SOLDIER and player.state.recovery.mana.current == 900, "a 天X神兵 came for 100 mana")
	if soldier == null:
		await _flee(tree, session)
		return
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter.participant_for(soldier_id) != null and encounter.participant_for(soldier_id).side_id == encounter.participant_for(player.character_id).side_id, "it stands on the player's side")
	_check(soldier.relationship.has_lethal_target(worker.character_id) and worker.relationship.has_lethal_target(soldier_id) and not soldier.relationship.has_opponent(player.character_id), "it kills 工匠, who kills it back")
	_check(not player.relationship.has_lethal_target(worker.character_id) and not worker.relationship.has_lethal_target(player.character_id) and encounter.mode == CombatEncounterMode.Value.LETHAL, "the player and 工匠 still only spar; the fight is to the death now")
	var name: String = soldier.definition().display_name
	var log: String = _battle_log(session)
	_check(log.contains("你喃喃地念了几句咒语。") and log.contains("一道金光由天而降，金光中走出一个身穿金色战袍的将官。") and log.contains("%s说道：末将奉法主召唤，特来护法！" % name), "the incantation and its coming: %s" % log.right(120))
	var cards: Array[BattleParticipantProjection] = _ui(session).current_projection().participants()
	var card: BattleParticipantProjection = null
	for value: BattleParticipantProjection in cards:
		if value.participant_id == soldier_id:
			card = value
	_check(card != null and not card.hostile_to_player and _ui(session)._cards[1]._title.text == "%s · 参战" % name, "its card stands next to the player's")
	# 工匠 has two enemies: random(4) 1 takes the soldier (select_opponent()).
	var forced := Juechen.Forced.new()
	forced.queues[4] = [1]
	session.configure_combat_random_source(forced) # TEST-ONLY
	var events_from: int = coordinator.active_scheduler().events().size()
	coordinator.advance_scheduler(1.0)
	var at_soldier: bool = false
	var soldier_hits: bool = false
	if coordinator.active_scheduler() != null:
		for event: CombatSchedulerEvent in coordinator.active_scheduler().events().slice(events_from):
			at_soldier = at_soldier or (event.actor_id == worker.character_id and event.target_id == soldier_id and event.resolution != null)
			soldier_hits = soldier_hits or (event.actor_id == soldier_id and event.target_id == worker.character_id and event.resolution != null)
	_check(at_soldier and soldier_hits, "工匠 turns on the soldier (random(4) 1) and the soldier strikes him")
	# He falls (TEST-ONLY: knocked out); the fight goes on and the soldier finishes him.
	session.configure_combat_random_source(_original_random)
	if worker.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
		worker.character_state.vitality.current = -1
	coordinator.advance_scheduler(0.0) # the lifecycle check alone: char.c heart_beat()
	var fell: bool = worker.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and coordinator.has_active_encounter()
	for _round: int in range(400):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_refresh(session)
	await tree.process_frame
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight ends: " + coordinator.last_abort_detail())
	_check(fell and worker.life_status == CharacterRuntimeLifeStatus.Value.DEAD and map.corpse_states().any(func(corpse: CorpseState) -> bool: return corpse.victim_character_id == worker.character_id), "工匠 fell, the fight went on and the soldier killed him (the player only spars): his corpse lies here")
	_check(player.state.progression.kills == kills + 1, "the soldier's kill is the player's (killer_reward() passes to `possessed`): MKS %d" % player.state.progression.kills)
	_check(map.find_resident_npc(soldier_id) == null, "the soldier left")
	var hud_log: Array[String] = session.shared_ui().log_lines()
	_check(hud_log.has("%s说道：末将奉法主召唤，现在已经完成护法任务，就此告辞！" % name), "with its lines: %s" % [hud_log.slice(-3)])
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open again")


## 老公公 kill_ob()s the player's soldier as it comes: ask_for_help() then sends 老婆婆 at
## the soldier (query_temp("killer"), his last kill_ob()), not at the player.
func _test_old_couple(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var man: NpcRuntimeState = _first(map, &"green.npc.oldman")
	var wife: NpcRuntimeState = _first(map, &"green.npc.oldwoman")
	await _beside(tree, map, session, man)
	player.state.recovery.mana.current = 1000
	session.configure_combat_random_source(Juechen.Forced.new()) # TEST-ONLY
	map.select_npc(man.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 老公公")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var before: Array[StringName] = _npc_ids(map)
	_submit(session, SUMMON)
	coordinator.advance_scheduler(0.0)
	var soldier_id: StringName = &""
	for id: StringName in _npc_ids(map):
		if not before.has(id):
			soldier_id = id
	_check(not soldier_id.is_empty() and man.relationship.lethal_target_ids().back() == soldier_id, "a soldier came; he kills it back, last")
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var me: CombatSliceCharacterBinding = _binding(bindings, man.character_id)
	var chat := CombatNpcChat.new(coordinator._resident_npc, coordinator._npc_wield, coordinator._respect_of).with_villagers(coordinator._npc_wield_item, coordinator._age_of, coordinator._idle_partner)
	var called: CombatNpcChatResult = chat.beat(me, [], [], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new())
	_check(called != null and called.joins().size() == 1 and called.joins()[0].joiner_id == wife.character_id and called.joins()[0].target_ids == [soldier_id], "ask_for_help(): 老婆婆 comes for the soldier")
	if called == null:
		await _flee(tree, session)
		return
	coordinator.resolution().admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(called.joins()))
	var soldier: NpcRuntimeState = map.find_resident_npc(soldier_id)
	_check(coordinator.active_encounter().participant_for(wife.character_id) != null and wife.relationship.has_lethal_target(soldier_id) and not wife.relationship.has_opponent(player.character_id), "she is in the fight, killing the soldier, not the player")
	_check(soldier.relationship.has_opponent(wife.character_id) and not soldier.relationship.has_lethal_target(wife.character_id), "it only fights her back (kill_ob() asks nothing of it)")
	await _flee(tree, session)
	_check(map.find_resident_npc(soldier_id) == null and man.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "after the flight the soldier is gone")


## A no_magic room (cast.c): the spell is refused and costs nothing.
func _test_no_magic(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var forbidden: Array[StringName] = []
	for zone: ZoneDefinition in _catalog.zones():
		if _catalog.zone_forbids_magic(zone.zone_id):
			forbidden.append(zone.zone_id)
	_check(forbidden.is_empty(), "no room placed yet is no_magic (Snow's bank has it commented out): %s" % [forbidden])
	var quarryman: NpcRuntimeState = _first(map, QUARRYMAN)
	await _beside(tree, map, session, quarryman)
	player.state.recovery.mana.current = 1000
	map.select_npc(quarryman.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 采石工")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	var policy := CombatCastTacticalPolicy.new(&"saveme", false, func(_id: StringName) -> bool: return true) # TEST-ONLY: as if the room were no_magic
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	var context := CombatTacticalContext.new(encounter.participant_for(player.character_id).binding, null, encounter.mode, SkillImprovementEffectRegistry.new(), bindings)
	var result: CombatTacticalExecutionResult = policy.execute(context, Juechen.Forced.new())
	_check(result.outcome == CombatTacticalExecutionResult.Outcome.FAILED and result.special.lines()[0].template == "这里不准念咒文。" and player.state.recovery.mana.current == 1000 and result.allies.is_empty(), "这里不准念咒文, nothing spent")


## 遁 at oneself in a fight: 你失败了 once, then away to Snow's temple; the fight is over
## for the player, the soldier they had called is left behind unheard.
func _test_vanish(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter(), "still fighting the 采石工")
	session.configure_combat_random_source(Juechen.Forced.new()) # TEST-ONLY
	var before: Array[StringName] = _npc_ids(map)
	_submit(session, SUMMON)
	coordinator.advance_scheduler(0.0)
	var soldier_id: StringName = &""
	for id: StringName in _npc_ids(map):
		if not before.has(id):
			soldier_id = id
	_check(not soldier_id.is_empty(), "a soldier came")
	var encounter: CombatEncounter = coordinator.active_encounter()
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	var quarryman: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == QUARRYMAN and encounter.participant_for(npc.character_id) != null:
			quarryman = npc
	var context: SpecialContext = CombatSpecialAttackSource.context_for(_binding(bindings, quarryman.character_id), bindings, Juechen.Forced.new(), SkillImprovementEffectRegistry.new())
	context.summons.append(SOLDIER) # TEST-ONLY: as if the 采石工 had cast saveme
	var chat := CombatNpcChat.new(coordinator._resident_npc).with_summons(coordinator._summon_beside)
	var joins: Array[CombatJoin] = chat._summon(_binding(bindings, quarryman.character_id), context)
	_check(joins.size() == 1 and joins[0].target_ids == [soldier_id, player.character_id] and joins[0].killed_back, "his soldier's invocation(): his living enemies from the last, the player's soldier first")
	if joins.size() == 1:
		var theirs: StringName = joins[0].joiner_id
		coordinator.resolution().admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(joins))
		var their_soldier: NpcRuntimeState = map.find_resident_npc(theirs)
		var mine: NpcRuntimeState = map.find_resident_npc(soldier_id)
		_check(encounter.participant_for(theirs) != null and encounter.participant_for(theirs).side_id == encounter.participant_for(quarryman.character_id).side_id, "his soldier fights on his side")
		_check(their_soldier.relationship.has_lethal_target(soldier_id) and their_soldier.relationship.has_lethal_target(player.character_id) and mine.relationship.has_lethal_target(theirs), "it kills both; the player's soldier kills it back")
		_check(player.relationship.has_opponent(theirs) and not player.relationship.has_lethal_target(theirs), "the player only fights it back")
		_check(coordinator.opening_warnings(encounter.encounter_id).has("看起来%s想杀死你！" % their_soldier.definition().display_name), "看起来…想杀死你！")
	var forced := Juechen.Forced.new()
	forced.queues[130] = [29]
	session.configure_combat_random_source(forced) # TEST-ONLY
	var mana: int = player.state.recovery.mana.current
	_submit(session, VANISH)
	coordinator.advance_scheduler(0.0)
	_refresh(session)
	_check(coordinator.has_active_encounter() and player.state.recovery.mana.current == mana - 80 and _battle_log(session).ends_with("你失败了。"), "random(spells) 29: 你失败了, 80 mana, still fighting")
	session.configure_combat_random_source(Juechen.Forced.new()) # TEST-ONLY: random(5) 4, the fog
	_submit(session, VANISH)
	coordinator.advance_scheduler(0.0)
	var receipt: CombatEncounterCompletionResult = coordinator.last_completion()
	_check(not coordinator.has_active_encounter() and receipt != null and receipt.terminal_result.kind == CombatEncounterResultKind.Value.FLED and coordinator.departed(receipt.encounter_id), "遁 ends the fight for the player")
	var left_behind: int = 0
	for npc: NpcRuntimeState in map.npc_runtimes():
		if SummonedNpc.is_summoned(npc.character_id):
			left_behind += 1
	_check(left_behind == 0, "both soldiers are gone")
	session.advance_departure()
	_check(session.active_map_id() == &"green.village" and coordinator.pending_departure() == DunSpell.DESTINATION, "the move waits a frame: the fight's end is told first")
	map.select_npc(_first(map, QUARRYMAN).character_id)
	_check(map.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED and not coordinator.has_active_encounter(), "no fight starts before the move")
	_check(OldPineSaveEligibility.inspect(session).outcome == OldPineSaveEligibilityResult.Outcome.MAP_HANDOFF_ACTIVE, "nor a save: the move is still to come")
	session.advance_departure()
	await tree.physics_frame
	await tree.physics_frame
	var location: WorldLocationState = player.world_location()
	_check(session.active_map_id() == SnowWorldDefinitions.OUTDOOR_MAP_ID and location.zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "the player is in Snow's temple: %s %s" % [session.active_map_id(), location.zone_id])
	_ui(session).refresh_projection()
	await tree.process_frame
	var hud_log: Array[String] = session.shared_ui().log_lines()
	for index: int in range(hud_log.size() - 1, -1, -1):
		if hud_log[index].begins_with("你对著采石工喝道"):
			hud_log = hud_log.slice(index) # From this fight's start on.
			break
	var all: String = "\n".join(hud_log)
	_check(all.contains("你口中喃喃地念著咒文，忽然大喝一声“疾！”") and all.contains("只见你化作一团大雾，然后消失得无影无踪！") and all.contains("你借遁术脱离了战斗。"), "the chant, the fog and the fight's end: %s" % [hud_log.slice(-4)])
	_check(not all.contains("现在已经完成护法任务"), "the soldier's going is not heard: %s" % [hud_log])
	_check(BattleFeedbackReader.completion_text(receipt, CharacterRuntimeLifeStatus.Value.ACTIVE, false) == "你逃离了战斗。走远一些才能摆脱危险。", "a plain flight still says so")
	session.advance_departure()
	session.advance_departure()
	_check(coordinator.pending_departure().is_empty() and session.active_map_id() == SnowWorldDefinitions.OUTDOOR_MAP_ID and player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "the move was made once")
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open in the temple")


# --- Helpers ------------------------------------------------------------------------

func _offered(coordinator: CombatEncounterCoordinator) -> Array[StringName]:
	var ids: Array[StringName] = []
	for info: CombatTacticalActionInfo in coordinator.action_infos():
		if String(info.action_id).begins_with(CombatCastTacticalPolicy.PREFIX):
			ids.append(info.action_id)
	return ids


func _submit(session: WorldSessionController, action_id: StringName) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_requests += 1
	var result: CombatTacticalResult = coordinator.submit_player_action(CombatTacticalRequest.new(
		StringName("cast:%d" % _requests), coordinator.active_encounter().encounter_id, session.player_runtime().character_id,
		action_id, CombatTacticalRequest.Category.SPELL,
	))
	_check(result.code == CombatTacticalResult.Code.ACCEPTED, "%s queued: %s" % [action_id, BattleFeedbackReader.reason(result.code)])


func _flee(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	session.configure_combat_random_source(Juechen.Forced.new()) # TEST-ONLY: no more chat
	for attempt: int in range(400):
		if not coordinator.has_active_encounter():
			break
		if coordinator.active_encounter().queued_player_action() == null:
			coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % attempt), coordinator.active_encounter().encounter_id, player.character_id, CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE))
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "fled: " + coordinator.last_abort_detail())
	_refresh(session)
	await tree.process_frame


func _refresh(session: WorldSessionController) -> void:
	_ui(session).refresh_projection()


func _ui(session: WorldSessionController) -> BattlePresentationController:
	return session.get_node("BattlePresentationLayer/BattleSurface")


func _battle_log(session: WorldSessionController) -> String:
	return _ui(session).log_panel._text.get_parsed_text().strip_edges()


func _npc_ids(map: WorldMapController) -> Array[StringName]:
	var ids: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		ids.append(npc.character_id)
	return ids


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			return npc
	return null


func _binding(bindings: Array[CombatSliceCharacterBinding], character_id: StringName) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in bindings:
		if binding.character_id == character_id:
			return binding
	return null


static func _whole(state: CharacterState) -> void:
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


## TEST-ONLY: the player beside an NPC, on a free spot of its zone.
func _beside(tree: SceneTree, map: WorldMapController, session: WorldSessionController, npc: NpcRuntimeState) -> void:
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var zone_id: StringName = npc.world_location().zone_id
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 80.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("青石村 D: " + label)
