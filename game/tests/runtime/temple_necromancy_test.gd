extends RefCounted

## 茅山 C: the player's 茅山道术 in a fight and its practice, in the real session on the
## temple grounds. Practising conjures a 观想虫 (necromancy.c practice_skill()): it comes
## beside the player with combat_exp from their raw spells and their bellicosity, and
## kill_ob()s them, who fight back; knocked out, it stays (no leave at the fight's end),
## keeps its hatred, refuses the next practice and is left out of a save (Continue starts
## without it); killed by the player it teaches spells (mind_bug.c die()). A 观想兽
## (spells 20, random(20) 10) killed by the 阴鬼卒 of the player's 召护法 (asked first
## against one's own 观想虫) knocks the player out. In a spar 召护法 is asked first.
## TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.taoist.taolord"
const TFIGHTER: StringName = &"temple.npc.tfighter"
const FAMILY: StringName = &"family.maoshan"
const BUG: StringName = &"common.npc.mind_bug"
const BEAST: StringName = &"common.npc.mind_beast"
const GUARD: StringName = &"common.npc.hell_guard"
const DONE: String = "你闭目凝神，神游物外，开始修习茅山道术中的法术...."


## Draws by bound: each bound's queue first, then the highest value.
class Forced extends CombatRandomSource:
	var queues: Dictionary[int, Array] = {}
	func next_below(bound: int) -> int:
		var queue: Array = queues.get(bound, [])
		if not queue.is_empty():
			return clampi(queue.pop_front(), 0, bound - 1)
		return bound - 1


## The world-interaction stream with draws by bound: each bound's queue first, then the
## highest value.
class ForcedWorld extends WorldInteractionRandomSource:
	var queues: Dictionary[int, Array] = {}
	func next_below(bound: int) -> int:
		var queue: Array = queues.get(bound, [])
		if not queue.is_empty():
			return clampi(queue.pop_front(), 0, bound - 1)
		return bound - 1


var _count: int = 0
var _failures: Array[String] = []
var _requests: int = 0
var _original_combat: CombatRandomSource
var _original_world: WorldInteractionRandomSource


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("茅工", CharacterState.GENDER_MALE) # 林忌 takes men only
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	await tree.process_frame
	session.set_process(false)
	_original_combat = session.combat_random_source()
	_original_world = session.world_interaction_random_source()
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"temple.grounds", &"temple.square", &"temple.square", &"temple.square.gate_arrival").succeeded(), "TEST-ONLY: inside the gate")
	await tree.physics_frame
	await tree.physics_frame
	_make_taoist(session)
	await _away_from_gate(tree, session)
	_test_hint(session)
	var bug: NpcRuntimeState = await _test_conjure(tree, session)
	if bug != null:
		await _test_bug_stays(tree, session, bug)
		await _test_hatred(tree, session, bug)
		await _test_kill_it(tree, session, bug)
	await _test_beast_killed_by_guard(tree, session)
	await _test_spar_question(tree, session)
	await _test_save_leaves_it_out(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## TEST-ONLY: 林忌's apprentice with spells and 茅山道术 10 enabled, 天师正道 20, 1000 mana
## (max sen follows, as Continue recomputes it), full sen and spi 20.
func _make_taoist(session: WorldSessionController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state: CharacterState = session.player_runtime().state
	var request := NpcApprenticeship.new()
	request.request(state, catalog.npc(MASTER), catalog.family(FAMILY), 1, "壮士")
	request.answer(state, catalog.npc(MASTER), catalog.family(FAMILY), 2, "壮士")
	state.skills.set_raw_level(&"taoism", 20)
	state.skills.set_raw_level(&"spells", 10)
	state.skills.set_raw_level(&"necromancy", 10)
	state.skills.map_skill(&"spells", &"necromancy")
	state.recovery.mana = CharacterInternalResourceState.new(1000, 1000)
	CharacterDerivedValues.refresh_human_player_maxima(state, session.player_runtime().facts.age)
	state.spirit = CharacterResourceState.new(state.spirit.maximum, state.spirit.maximum, state.spirit.maximum)
	state.attributes.spirituality = 20
	state.attributes.bellicosity = 37
	_check(state.family.family_id == FAMILY, "TEST-ONLY: a member of 茅山派")


## The 武学 page's 练习 hover for 茅山道术 tells of the 观想虫 (owner, 茅山 A).
func _test_hint(session: WorldSessionController) -> void:
	var hint: String = session.martial_arts().practice_hint(&"spells")
	_check(hint == "每次练习耗 10 点法力、30 点神。心神一乱会变出观想虫或观想兽，它会立刻攻击你，活着时不能再练。亲手杀了它，基本咒文会有长进；被别人杀了，你会昏倒。", "the hover: %s" % hint)
	_check(session.martial_arts().practice_hint(&"force").is_empty(), "no hover for a practice that conjures nothing")


## practice spells: random(sen left) 4 and random(10) 3 conjure a 观想虫 that kills the
## player, who fights back.
func _test_conjure(tree: SceneTree, session: WorldSessionController) -> NpcRuntimeState:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var sen: int = player.state.spirit.current
	var forced := ForcedWorld.new()
	forced.queues[sen - 30] = [4]
	forced.queues[10] = [3]
	session.configure_world_interaction_random_source(forced) # TEST-ONLY
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no chat
	var result: PracticeResult = session.martial_arts().practice(&"spells")
	session.configure_world_interaction_random_source(_original_world)
	_check(result != null and result.failure_reason == PracticeResult.FailureReason.PRACTICE_CONJURED and result.conjured_npc_id == BUG, "a 观想虫 is conjured")
	var bug: NpcRuntimeState = map.find_resident_npc(player.conjured_npc_id)
	_check(bug != null and SummonedNpc.definition_id_of(bug.character_id) == BUG, "it stands here, made by no room: %s" % player.conjured_npc_id)
	if bug == null:
		return null
	_check(bug.character_state.progression.combat_experience == 5000 and bug.character_state.attributes.bellicosity == 37 and bug.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER), "create(): combat_exp spells 10 x 500, the player's bellicosity; kill_ob() kept")
	_check(player.state.recovery.mana.current == 990 and player.state.spirit.current == sen - 30, "10 mana and 30 sen paid")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.LETHAL, "a fight to the death began")
	_check(bug.relationship.has_lethal_target(player.character_id) and not player.relationship.has_lethal_target(bug.character_id), "it kills the player, who only fights back (me->fight(bug))")
	var log: Array[String] = session.shared_ui().log_lines()
	_check(log.slice(-4) == [DONE, "可是你心思一乱，变出了一只面目狰狞的观想虫！", "你的魂魄正被观想虫缠住，快把它除掉吧！", "看起来观想虫想杀死你！"], "its lines open the fight: %s" % [log.slice(-4)])
	_refresh(session)
	var question: PackedStringArray = _ui(session)._question_for(CombatCastTacticalPolicy.action_id_for(&"invocation"))
	_check(question.size() == 2 and question[0] == "来相助的护法会替你杀观想虫。观想虫不是你亲手杀的，你会昏倒，也悟不到咒术的道理。\n确定要召唤吗？" and question[1] == "召护法", "召护法 against one's own 观想虫 is asked first: %s" % [question])
	_check(_ui(session)._question_for(CombatCastTacticalPolicy.action_id_for(&"drainerbolt")).is_empty(), "a bolt is not")
	return bug


## Knocked out, the fight ends and it stays (dismiss_summoned() keeps it); it still hates
## the player; practice refuses while it stands.
func _test_bug_stays(tree: SceneTree, session: WorldSessionController, bug: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	bug.character_state.vitality.current = -1 # TEST-ONLY: knocked out
	coordinator.advance_scheduler(0.0)
	for _round: int in range(50):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_refresh(session)
	await tree.process_frame
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "it falls and the fight is over: " + coordinator.last_abort_detail())
	_check(map.find_resident_npc(bug.character_id) == bug and bug.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and player.conjured_npc_id == bug.character_id, "it lies there: a conjured NPC does not leave with the fight")
	_check(bug.definition().attacks_on_sight(bug.flags(), player.state) and not GameContent.catalog().npc(BUG).attacks_on_sight({}, player.state), "its hatred attacks the player on sight (attack.c init())")
	_settle(player)
	var mana: int = player.state.recovery.mana.current
	var result: PracticeResult = session.martial_arts().practice(&"spells")
	_check(result.failure_reason == PracticeResult.FailureReason.PRACTICE_CONJURED_STANDING and session.shared_ui().log_lines().back() == "你的魂魄还没有全部收回，赶快杀死你的观想虫吧！" and player.state.recovery.mana.current == mana, "practice refuses while it stands, nothing paid")


## Come to, it meets the player again (the player in its reach anew): combatd.c
## start_hatred()'s catch_hunt_msg (random(7) 1) and kill_ob(): it alone kills, so knocked
## out again it lies there, as before.
func _test_hatred(tree: SceneTree, session: WorldSessionController, bug: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	session.advance_npc_heartbeat(200.0) # TEST-ONLY: past random(100 - con) + 30 s
	_check(bug.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "it comes to")
	var forced := ForcedWorld.new()
	forced.queues[7] = [1]
	session.configure_world_interaction_random_source(forced) # TEST-ONLY
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no chat
	map.hostilities.aggression.enter_player_presence(bug, player, true) # TEST-ONLY: the player comes into its reach
	map.hostilities.process_pending_aggression()
	session.configure_world_interaction_random_source(_original_world)
	_check(coordinator.has_active_encounter() and bug.relationship.has_lethal_target(player.character_id) and not player.relationship.has_lethal_target(bug.character_id), "its hatred attacks; the player only fights back")
	_check(session.shared_ui().log_lines().slice(-2) == ["观想虫对著你大喝：「可恶，又是你！」", "看起来观想虫想杀死你！"], "catch_hunt_msg, then kill_ob()'s warning: %s" % [session.shared_ui().log_lines().slice(-2)])
	bug.character_state.vitality.current = -1 # TEST-ONLY: knocked out
	coordinator.advance_scheduler(0.0)
	for _round: int in range(50):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_refresh(session)
	await tree.process_frame
	_settle(player)
	session.configure_combat_random_source(_original_combat)
	_check(not coordinator.has_active_encounter() and bug.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "knocked out again, it lies there")


## 攻击 the 观想虫 lying there: it dies by the player's hand, who learns spells
## (random(spi / 2) + 1: random(10) 6 is 7 points) and may practise again.
func _test_kill_it(tree: SceneTree, session: WorldSessionController, bug: NpcRuntimeState) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	await _beside(tree, session, map, bug, Vector2(0, -56))
	var learned: int = player.state.skills.learned_progress(&"spells")
	var forced := ForcedWorld.new()
	forced.queues[10] = [6]
	session.configure_world_interaction_random_source(forced) # TEST-ONLY
	_check(map.select_npc(bug.character_id), "selected")
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks it: %s" % CombatSliceInitiationResult.Outcome.find_key(started.outcome))
	for _round: int in range(50):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	session.configure_world_interaction_random_source(_original_world)
	_refresh(session)
	await tree.process_frame
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight is over: " + coordinator.last_abort_detail())
	_check(bug.life_status == CharacterRuntimeLifeStatus.Value.DEAD and map.corpse_states().any(func(corpse: CorpseState) -> bool: return corpse.victim_character_id == bug.character_id), "it died; its corpse lies here")
	_check(player.state.skills.learned_progress(&"spells") == learned + 7 and player.conjured_npc_id.is_empty(), "spells learned 7 more (random(10) 6 + 1); the link is gone")
	_check(session.shared_ui().log_lines().has("你杀死了你的观想虫，并且从中悟到了一些咒术的道理。"), "its line: %s" % [session.shared_ui().log_lines().slice(-4)])
	_check(map.find_resident_npc(bug.character_id) == null, "the dead one is forgotten")
	_settle(player)
	var forced_again := ForcedWorld.new() # TEST-ONLY: random(sen) at its highest keeps the mind clear
	session.configure_world_interaction_random_source(forced_again)
	var result: PracticeResult = session.martial_arts().practice(&"spells")
	session.configure_world_interaction_random_source(_original_world)
	_check(result.success, "it is dead: practice goes on")


## spells 20, random(20) 10: a 观想兽 (combat_exp 40000); 召护法 brings a 阴鬼卒 (random(3)
## 2), which finishes it once it falls: the player reads die()'s lines and faints.
func _test_beast_killed_by_guard(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	player.state.skills.set_raw_level(&"spells", 20) # TEST-ONLY
	player.state.spirit.current = player.state.spirit.effective
	var sen_after: int = player.state.spirit.current - 30
	var forced := ForcedWorld.new()
	forced.queues[sen_after] = [0]
	forced.queues[20] = [10]
	session.configure_world_interaction_random_source(forced) # TEST-ONLY
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no chat; 召护法 succeeds, a 阴鬼卒
	var result: PracticeResult = session.martial_arts().practice(&"spells")
	session.configure_world_interaction_random_source(_original_world)
	var beast: NpcRuntimeState = map.find_resident_npc(player.conjured_npc_id)
	_check(result.conjured_npc_id == BEAST and beast != null and beast.character_state.progression.combat_experience == 40000, "a 观想兽 of combat_exp 40000")
	if beast == null:
		return
	_refresh(session)
	var before: Array[StringName] = _npc_ids(map)
	_submit(session, CombatCastTacticalPolicy.action_id_for(&"invocation"))
	coordinator.advance_scheduler(0.0)
	var guard: NpcRuntimeState = null
	for id: StringName in _npc_ids(map):
		if not before.has(id):
			guard = map.find_resident_npc(id)
	_check(guard != null and SummonedNpc.definition_id_of(guard.character_id) == GUARD and guard.relationship.has_lethal_target(beast.character_id), "a 阴鬼卒 came and kills it")
	session.configure_combat_random_source(_original_combat)
	beast.character_state.vitality.current = -1 # TEST-ONLY: knocked out; the guard finishes it
	coordinator.advance_scheduler(0.0)
	for _round: int in range(400):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_refresh(session)
	await tree.process_frame
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "the fight is over: " + coordinator.last_abort_detail())
	_check(beast.life_status == CharacterRuntimeLifeStatus.Value.DEAD and player.conjured_npc_id.is_empty(), "the 阴鬼卒 killed it")
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "not the player's hand: the player falls unconscious")
	var log: Array[String] = session.shared_ui().log_lines()
	_check(log.has("你的观想兽被人杀死了！") and log.has("你觉得一阵天旋地转...."), "die()'s lines: %s" % [log.slice(-5)])
	_check(guard == null or map.find_resident_npc(guard.character_id) == null, "the 阴鬼卒 left with the fight")
	session._advance_life_flow(140.0)
	await tree.process_frame
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the player wakes")


## In a spar with 僵尸护法 (茅山派 only), 召护法 is asked first.
func _test_spar_question(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_settle(player)
	player.state.recovery.mana.current = 1000
	player.state.spirit.current = player.state.spirit.effective
	var tfighter: NpcRuntimeState = _first(map, TFIGHTER)
	_check(tfighter != null, "僵尸护法 stands in the hall")
	if tfighter == null:
		return
	await _beside(tree, session, map, tfighter)
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no chat
	map.select_npc(tfighter.character_id)
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "僵尸护法 spars with a member")
	_refresh(session)
	var question: PackedStringArray = _ui(session)._question_for(CombatCastTacticalPolicy.action_id_for(&"invocation"))
	_check(question.size() == 2 and question[0] == BattlePresentationController.INVOCATION_QUESTION and question[1] == "召护法", "in a spar 召护法 is asked first: %s" % [question])
	player.state.recovery.mana.current = 99
	_check(_ui(session)._question_for(CombatCastTacticalPolicy.action_id_for(&"invocation")).is_empty(), "not when it would refuse (mana 99)")
	await _flee(tree, session)
	session.configure_combat_random_source(_original_combat)


## A 观想虫 knocked out and lying there: a save is open; it leaves the 观想虫 out, and
## Continue starts without it and without the player's set_temp("mind_bug"). Last: the
## restore's activation retires this session.
func _test_save_leaves_it_out(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	player.state.skills.set_raw_level(&"spells", 10) # TEST-ONLY
	var forced := ForcedWorld.new()
	forced.queues[player.state.spirit.current - 30] = [0]
	session.configure_world_interaction_random_source(forced) # TEST-ONLY
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no chat
	session.martial_arts().practice(&"spells")
	session.configure_world_interaction_random_source(_original_world)
	var bug: NpcRuntimeState = map.find_resident_npc(player.conjured_npc_id)
	_check(bug != null and coordinator.has_active_encounter(), "another 观想虫")
	if bug == null:
		return
	bug.character_state.vitality.current = -1 # TEST-ONLY: knocked out
	coordinator.advance_scheduler(0.0)
	for _round: int in range(50):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_refresh(session)
	await tree.process_frame
	_settle(player)
	session.configure_combat_random_source(_original_combat)
	_check(not coordinator.has_active_encounter() and bug.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "it lies there")
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open while the 观想虫 stands")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "the save captures")
	if snapshot == null:
		return
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text).snapshot, tree.root)
	_check(restored.succeeded(), "Continue restores: " + restored.path)
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	_check(fresh.activate_restore_candidate(), "activation")
	var conjured: Array[StringName] = []
	for npc: NpcRuntimeState in fresh.world_npcs():
		if npc.definition().conjuring() != null:
			conjured.append(npc.character_id)
	_check(conjured.is_empty() and fresh.player_runtime().conjured_npc_id.is_empty(), "Continue starts without the 观想虫 and without the link: %s" % [conjured])
	_check(GameSaveJsonCodec.encode(Work.capture(fresh)).text == GameSaveJsonCodec.encode(snapshot).text, "Save/Continue is exact without it")
	fresh.free()
	await tree.process_frame


# --- Helpers ------------------------------------------------------------------------

## TEST-ONLY: the fight's busy over.
static func _settle(player: WorldPlayerRuntimeState) -> void:
	player.busy.advance()
	while player.busy.is_busy():
		player.busy.advance()


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


## TEST-ONLY: the player in the middle of the square, well away from the 山门 (its portal
## would take a player pushed onto it out of the grounds).
func _away_from_gate(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var at: Vector2 = MapPlaces.spot(map, &"temple.square", map.physical_zone(&"temple.square").global_rect().get_center(), 120.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF, "TEST-ONLY: in the middle of the square")
	await tree.physics_frame
	await tree.physics_frame


## TEST-ONLY: the player beside an NPC (`offset` from it), on a free spot of its zone.
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState, offset: Vector2 = Vector2(0, 56)) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + offset, 80.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("茅山 C: " + label)
