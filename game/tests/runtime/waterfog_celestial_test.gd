extends RefCounted

## 水烟阁 C in a running Snow session (the 武馆's 武馆弟子 stand in for anyone): the
## player's 天邪神功 on the 武学 page and the battle panel, 天邪虎啸 (roar.c) pulling
## the room into a spar that then goes on to the death, powerfade's faint in a fight,
## both asked first (owner); the player's own berserk (attack.c init(), combatd.c
## start_berserk(): kill, spar, stare; never at their master), look.c's glare from an
## NPC, the one-time warning and its save. Draws are scripted where a rule rolls.
## TEST-ONLY fixtures, each marked where used: skills, force, bellicosity, cps,
## score, combat experience and resources set directly.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const Master := preload("res://tests/support/snow_master.gd")
const TRAINEE: StringName = &"snow.npc.trainee"

var _count: int = 0
var _failures: Array[String] = []
var _session: OldPineWorldSessionController
var _player: WorldPlayerRuntimeState
var _state: CharacterState
var _hud: SharedGameplayUI
var _ui: BattlePresentationController
var _map: WorldMapController


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _open(tree)
	_test_page()
	await _reopen(tree)
	await _test_roar(tree)
	await _reopen(tree)
	await _test_roar_withstood(tree)
	await _reopen(tree)
	await _test_powerfade(tree)
	await _reopen(tree)
	await _test_berserk(tree)
	await _reopen(tree)
	await _test_look(tree)
	await _reopen(tree)
	await _test_warning(tree)
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _open(tree: SceneTree) -> void:
	_session = Work.create_session(tree)
	await tree.process_frame
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")
	_player = _session.player_runtime()
	_state = _player.state
	_hud = _session.shared_ui()
	_ui = _session.get_node("BattlePresentationLayer/BattleSurface")
	_map = _session.active_map() as WorldMapController
	# TEST-ONLY: a 天邪派 student: force 40 and 天邪神功 40 enabled (query_skill(force) 60).
	_state.skills.set_raw_level(&"force", 40)
	_state.skills.set_raw_level(&"celestial", 40)
	_state.skills.map_skill(&"force", &"celestial")
	_state.recovery.inner_force.maximum = 500
	_state.recovery.inner_force.current = 500
	_state.attributes.composure = 10
	_state.attributes.bellicosity = 300


func _reopen(tree: SceneTree) -> void:
	_session.free()
	await tree.process_frame
	await _open(tree)


func _test_page() -> void:
	var page: MartialArtsPage = _hud.martial_arts_page()
	_hud.open_martial_arts()
	page.refresh()
	_check(page.buttons.has("exert:powerup") and page.buttons.has("exert:powerfade") and not page.buttons.has("exert:roar"), "运功: 提升战斗力 and 压制杀气; 天邪虎啸 only in a fight")
	_check(page.buttons["exert:powerfade"].text == "压制杀气", "doc/skill/celestial's names")
	_check(page.bellicosity_text.text == "杀气 300 · 定力 10", "杀气 and 定力 under 内力: " + page.bellicosity_text.text)
	page.buttons["exert:powerfade"].pressed.emit()
	_check(_state.attributes.bellicosity == 300 - 100 - 20 and _last()[0] == "你微一凝神，运起天邪神功，放慢呼吸，开始收敛自己的杀气 ....", "压制杀气 outside a fight: no question, no faint: " + str(_last()))
	page.refresh()
	_check(page.bellicosity_text.text == "杀气 180 · 定力 10", "the page follows")
	# 100 sen out of 50: below zero, the player falls (std/char.c's next heart beat).
	_state.spirit.current = 50 # TEST-ONLY
	page.buttons["exert:powerfade"].pressed.emit()
	_check(_player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "powerfade's 100 sen from 50: the player falls: %s" % CharacterRuntimeLifeStatus.Value.find_key(_player.life_status))
	_hud.dismiss_current_panel()


## A spar with one 武馆弟子; 天邪虎啸 (asked first) strikes the room: every 武馆弟子 and the
## 拳脚教头 here who does not withstand it comes in to kill; the spar goes on to the death.
func _test_roar(tree: SceneTree) -> void:
	_heal()
	_state.progression.combat_experience = 20000000 # TEST-ONLY: the player outlasts the room.
	_state.vitality.maximum = 20000
	_heal()
	var first: NpcRuntimeState = _npc(&"snow.school2.trainee.1")
	_check(_beside(&"snow.school2", &"snow.school2.trainee.1"), "beside a 武馆弟子")
	await tree.physics_frame
	var here: Array[NpcRuntimeState] = _here(&"snow.school2")
	_check(here.size() >= 3, "several here: %d" % here.size())
	_map.select_npc(first.character_id)
	_check(_map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar starts")
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	_check(coordinator.active_encounter().mode == CombatEncounterMode.Value.SPAR and coordinator.active_encounter().participants().size() == 2, "a spar of two")
	_session.configure_combat_random_source(Specials.Pattern.new([])) # TEST-ONLY: every roll its highest: nobody withstands the roar
	_ui.refresh_projection()
	var panel: BattleActionPanel = _ui.action_panel
	_press(panel, "运功天邪虎啸")
	_check(panel.is_asking() and panel.prompt.message.text.begins_with("天邪虎啸要耗 150 点内力。") and panel.prompt.confirm_button.text == "发出虎啸", "asked first: " + panel.prompt.message.text)
	_check(not panel._actions.visible and panel.prompt.cancel_button.has_focus(), "the question stands in for the buttons; 取消 has the focus")
	panel.prompt.cancel_button.pressed.emit()
	_check(not panel.is_asking() and coordinator.active_encounter().queued_player_action() == null and panel._actions.visible, "取消: nothing queued, the buttons back")
	_press(panel, "运功压制杀气")
	_check(panel.is_asking() and panel.prompt.message.text.contains("约有 5 成会昏倒"), "压制杀气 in a fight: asked, with the odds (cps 10 * 3 / 60): " + panel.prompt.message.text)
	_ui.log_button.grab_focus()
	_ui._focus_battle()
	_check(panel.prompt.cancel_button.has_focus(), "the battle's focus fallback goes back to the question's 取消")
	panel.prompt.cancel_button.pressed.emit()
	_check(_ui._faint_odds(0.96) == "约有 9 成会昏倒" and _ui._faint_odds(1.0) == "一定会昏倒" and _ui._faint_odds(0.04) == "昏倒的可能很小", "the odds in words: never 10 成 short of certain")
	_press(panel, "运功天邪虎啸")
	panel.prompt.confirm_button.pressed.emit()
	_check(coordinator.active_encounter().queued_player_action() != null, "发出虎啸: queued")
	var force_before: int = _state.recovery.inner_force.current
	_advance()
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.LETHAL, "the spar goes on to the death")
	if encounter == null:
		return
	_check(_state.recovery.inner_force.current == force_before - 150, "150 force")
	# The highest roll: 30 + 29 = 59; whoever has cps 30 or more (the 拳脚教头) withstands it.
	var struck: Array[NpcRuntimeState] = []
	var withstood: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in here:
		(withstood if 59 < npc.character_state.attributes.composure * 2 else struck).append(npc)
	_check(not withstood.is_empty() and struck.size() >= 3, "some struck, the 拳脚教头 withstands: %d / %d" % [struck.size(), withstood.size()])
	var joined: int = 0
	for npc: NpcRuntimeState in struck:
		if encounter.participant_for(npc.character_id) != null and npc.relationship.has_lethal_target(_player.character_id):
			joined += 1
	_check(joined == struck.size() and encounter.participants().size() == struck.size() + 1, "everyone struck kills the player now: %d of %d, %d in the fight" % [joined, struck.size(), encounter.participants().size()])
	_check(encounter.participant_for(withstood[0].character_id) == null and withstood[0].character_state.spirit.current == withstood[0].character_state.spirit.maximum, "who withstood is untouched and stays out")
	_check(_ui._warning.text.count("想杀死你") == struck.size(), "a warning for each who turned on the player, none for who withstood")
	_check(_player.relationship.has_opponent(first.character_id) and not _player.relationship.has_lethal_target(here[1].character_id), "the player only fights back")
	_check(_log().contains("你深深地吸一口气，开始发出有如猛虎般的啸声！") and _log().contains("看起来武馆弟子想杀死你！"), "roar's line and kill_ob()'s warnings in the battle log")
	_check(_ui._warning.visible and _ui._warning.text.contains("看起来武馆弟子想杀死你！"), "and pinned: " + _ui._warning.text)
	var hurt: bool = true
	for npc: NpcRuntimeState in struck:
		hurt = hurt and npc.character_state.spirit.current < npc.character_state.spirit.maximum
	_check(hurt, "their sen struck")
	_check(_ui.current_projection().participants().size() == struck.size() + 1, "the panel shows them all")
	for _second: int in range(5):
		_advance()
	_check(coordinator.has_active_encounter() and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the fight goes on with them")
	_end_fight()
	await tree.process_frame


## A spar partner who withstands the roar only spars on; once that pair stops (the
## first blow, as any spar) and those who came in lie unconscious, nobody fights
## anyone any more: the fight ends (it did not before, review of 水烟阁 C).
func _test_roar_withstood(tree: SceneTree) -> void:
	_heal()
	_state.progression.combat_experience = 20000000 # TEST-ONLY
	var first: NpcRuntimeState = _npc(&"snow.school2.trainee.1")
	first.character_state.attributes.composure = 40 # TEST-ONLY: 30 + 29 < 80: withstands
	_check(_beside(&"snow.school2", &"snow.school2.trainee.1"), "beside a 武馆弟子")
	await tree.physics_frame
	_map.select_npc(first.character_id)
	_check(_map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar starts")
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	_session.configure_combat_random_source(Specials.Pattern.new([])) # TEST-ONLY: every roll its highest
	_ui.refresh_projection()
	_press(_ui.action_panel, "运功天邪虎啸")
	_ui.action_panel.prompt.confirm_button.pressed.emit()
	_advance()
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.LETHAL and encounter.participants().size() > 2, "others came in: the fight is to the death")
	if encounter == null:
		return
	_check(not first.relationship.has_lethal_target(_player.character_id) and encounter.participant_for(first.character_id) != null, "the partner withstood: it does not kill, it only spars on (or stopped already)")
	# TEST-ONLY: the spar pair stops (combatd.c's friendly stop), those who came in fall.
	first.relationship.remove_opponent(_player.character_id)
	_player.relationship.remove_opponent(first.character_id)
	for participant: CombatParticipant in encounter.participants():
		if participant.participant_id not in [_player.character_id, first.character_id]:
			participant.binding.state.vitality.current = -1
	for _second: int in range(5):
		if not coordinator.has_active_encounter():
			break
		_advance()
	_check(not coordinator.has_active_encounter(), "nobody fights anyone: the fight ends")
	var completion: CombatEncounterCompletionResult = coordinator.last_completion()
	_check(completion != null and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and first.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "both still standing")
	await tree.process_frame


## powerfade in a spar (asked first): random(60) < cps 10 * 3 knocks the player out;
## the spar ends with them down.
func _test_powerfade(tree: SceneTree) -> void:
	_heal()
	_check(_beside(&"snow.school2", &"snow.school2.trainee.1"), "beside a 武馆弟子")
	await tree.physics_frame
	_map.select_npc(_npc(&"snow.school2.trainee.1").character_id)
	_check(_map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "a spar starts")
	_session.configure_combat_random_source(Specials.Pattern.new([0])) # TEST-ONLY: random(skill) = 0
	_ui.refresh_projection()
	var panel: BattleActionPanel = _ui.action_panel
	_press(panel, "运功压制杀气")
	panel.prompt.confirm_button.pressed.emit()
	_advance()
	_check(_log().contains("你微一凝神，运起天邪神功，放慢呼吸，开始收敛自己的杀气 ...."), "powerfade's line")
	_check(_player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "out cold: %s" % CharacterRuntimeLifeStatus.Value.find_key(_player.life_status))
	_check(not _session.combat_encounter_coordinator().has_active_encounter(), "the spar ends")
	await tree.process_frame


## attack.c init() on arrival among the 武馆弟子: the first whose roll goes over gets
## start_berserk(): kill (bellicosity above score), spar (not above), or a stare
## (force calms it). The player's master is never the one.
func _test_berserk(tree: SceneTree) -> void:
	_heal()
	_state.attributes.bellicosity = 2000 # TEST-ONLY
	_state.recovery.inner_force.current = 0
	var here: Array[NpcRuntimeState] = _here(&"snow.school2")
	# The second one's random(50) goes over cps 10; then start_berserk()'s random(2000).
	var draws: Array[int] = [0, 49]
	for _rest: int in here.size() - 1:
		draws.append(0)
	var source := ScriptedWorldInteractionRandomSource.new(draws)
	var original: WorldInteractionRandomSource = _session.world_interaction_random_source()
	_session.configure_world_interaction_random_source(source)
	_check(_beside(&"snow.school2", &"snow.school2.trainee.1"), "into the 武馆")
	await tree.physics_frame
	_map.npc_life._note_player_arrival()
	_map.run_pending_player_berserk()
	var bounds: Array[int] = source.requested_bounds()
	_check(bounds.slice(0, here.size()) == _repeat(50, here.size()), "random(2000 / 40) for each one here: %s" % [bounds])
	var encounter: CombatEncounter = _session.combat_encounter_coordinator().active_encounter()
	var target: NpcRuntimeState = here[1]
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.LETHAL and encounter.participant_for(target.character_id) != null, "the second one's roll went over: a fight to the death with it")
	_check(_player.relationship.has_lethal_target(target.character_id) and not target.relationship.has_lethal_target(_player.character_id), "the player kills (kill_ob()); it only fights back")
	var self_rude: String = RankWords.query_self_rude(_state.gender, _player.facts.age, _state.affiliation.class_id)
	_check(_hud.log_lines().has("你用一种异样的眼神扫视著在场的每一个人。") and _hud.log_lines().has("你对著武馆弟子喝道：%s看你实在很不顺眼，去死吧。" % self_rude), "start_berserk()'s lines: %s" % [_hud.log_lines().slice(-3)])
	_end_fight()
	# Not above score: a spar the NPC is not asked about.
	_state.progression.score = 5000 # TEST-ONLY
	_map.npc_life.arrival_zone_id = &""
	source = ScriptedWorldInteractionRandomSource.new([49, 0])
	_session.configure_world_interaction_random_source(source)
	_heal()
	_map.npc_life._note_player_arrival()
	_map.run_pending_player_berserk()
	encounter = _session.combat_encounter_coordinator().active_encounter()
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.SPAR, "bellicosity 2000 not above score 5000: a spar")
	_check(_hud.log_lines().back().begins_with("你对著武馆弟子喝道：喂！") and _hud.log_lines().back().ends_with("正想找人打架，陪我玩两手吧！"), "fight_ob()'s line: " + _hud.log_lines().back())
	_end_fight()
	# Force above (random(b) + b) / 2: only the stare.
	_state.recovery.inner_force.current = 2000 # TEST-ONLY
	_map.npc_life.arrival_zone_id = &""
	source = ScriptedWorldInteractionRandomSource.new([49, 0])
	_session.configure_world_interaction_random_source(source)
	_map.npc_life._note_player_arrival()
	_map.run_pending_player_berserk()
	_check(not _session.combat_encounter_coordinator().has_active_encounter() and _hud.log_lines().back() == "你用一种异样的眼神扫视著在场的每一个人。", "calmed: the stare alone")
	# The master: never the one.
	# TEST-ONLY: 柳淳风's apprentice (his generation + 1).
	_state.apprenticeship.master_teacher_id = Master.MASTER_ID
	_state.family.family_id = Master.FAMILY_ID
	_state.family.generation = Master.definition().teaching().family_generation + 1
	_check(PlayerKillerReward.is_own_master(_state, Master.definition()), "TEST-ONLY: his apprentice")
	_state.recovery.inner_force.current = 0
	_check(_beside(&"snow.schoolhall", &"snow.schoolhall.master.1"), "beside 柳淳风")
	await tree.physics_frame
	source = ScriptedWorldInteractionRandomSource.new([49, 0])
	_session.configure_world_interaction_random_source(source)
	_map.npc_life.arrival_zone_id = &""
	_map.npc_life._note_player_arrival()
	_map.run_pending_player_berserk()
	_check(source.call_count() == 0 and not _session.combat_encounter_coordinator().has_active_encounter(), "no roll at one's own master: %s" % [source.requested_bounds()])
	_session.configure_world_interaction_random_source(original)
	await tree.process_frame


## look.c: 观察 a 武馆弟子 full of bellicosity: random(bellicosity / 10) > per: it glares and
## goes berserk at the player (kill_ob(): above its score). Not above: it challenges
## the player to a spar it starts (fight_ob()).
func _test_look(tree: SceneTree) -> void:
	_heal()
	var npc: NpcRuntimeState = _npc(&"snow.school2.trainee.1")
	npc.character_state.attributes.bellicosity = 1000 # TEST-ONLY
	npc.character_state.recovery.inner_force.current = 0
	_check(_beside(&"snow.school2", &"snow.school2.trainee.1"), "beside a 武馆弟子")
	await tree.physics_frame
	var original: WorldInteractionRandomSource = _session.world_interaction_random_source()
	var source := ScriptedWorldInteractionRandomSource.new([99, 0])
	_session.configure_world_interaction_random_source(source)
	_map.select_npc(npc.character_id)
	_check(_map.inspect_selected(), "观察")
	_check(source.requested_bounds() == [100, 1000], "random(1000 / 10), then start_berserk()'s random(1000): %s" % [source.requested_bounds()])
	_check(_hud.log_lines().has("武馆弟子突然转过头来瞪你一眼。") and _hud.log_lines().has("武馆弟子用一种异样的眼神扫视著在场的每一个人。"), "look.c's glare, then the stare")
	var encounter: CombatEncounter = _session.combat_encounter_coordinator().active_encounter()
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.LETHAL and npc.relationship.has_lethal_target(_player.character_id), "it attacks to kill")
	_check(not _player.relationship.has_lethal_target(npc.character_id) and _player.relationship.has_opponent(npc.character_id), "start_berserk()'s kill_ob() is one way: the player only fights back")
	_end_fight()
	_hud.dismiss_current_panel()
	# The spar branch an NPC starts (combatd.c fight_ob()): another, standing.
	_heal()
	npc = _npc(&"snow.school2.trainee.2")
	var lines: Array[String] = []
	_map._npc_berserk(npc, Berserk.Outcome.FIGHT, lines)
	encounter = _session.combat_encounter_coordinator().active_encounter()
	_check(encounter != null and encounter.mode == CombatEncounterMode.Value.SPAR and encounter.accepted_trigger().initiator_id == npc.character_id, "a spar it starts: %s" % [null if encounter == null else encounter.accepted_trigger().initiator_id])
	_check(_hud.log_lines().back().begins_with("武馆弟子对著你喝道：喂！") and _hud.log_lines().back().ends_with("正想找人打架，陪我玩两手吧！"), "its line: " + _hud.log_lines().back())
	_end_fight()
	_session.configure_world_interaction_random_source(original)
	await tree.process_frame


## The one-time warning: told once when bellicosity first reaches 40 * (cps + 2), in
## the log and on the 武学 page when powerup takes it there; saved.
func _test_warning(tree: SceneTree) -> void:
	_state.attributes.bellicosity = 479 # TEST-ONLY: cps 10: the line is 480
	_map.npc_life._note_bellicosity()
	_check(not _state.progression.berserk_warned and not _hud.log_lines().has(Berserk.WARNING), "479: not yet")
	var page: MartialArtsPage = _hud.martial_arts_page()
	_hud.open_martial_arts()
	page.refresh()
	page.buttons["exert:powerup"].pressed.emit()
	_check(_state.attributes.bellicosity == 479 + 130 and _last().back() == Berserk.WARNING and _state.progression.berserk_warned, "powerup takes it over: the warning on the page: " + str(_last()))
	_check(_hud.log_lines().count(Berserk.WARNING) == 1, "and once in the log")
	_hud.dismiss_current_panel()
	_map.npc_life._note_bellicosity()
	_check(_hud.log_lines().count(Berserk.WARNING) == 1, "not again")
	var snapshot: GameSaveSnapshot = Work.capture(_session)
	var text: String = GameSaveJsonCodec.encode(snapshot).text
	_check(text.contains("\"berserk_warned\": true") or text.contains("\"berserk_warned\":true"), "saved")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(text)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.player_runtime().state.progression.berserk_warned, "and restored")
	if restored.succeeded():
		restored.candidate.free()
	await tree.process_frame


## TEST-ONLY: everyone but the player falls (kee below zero), and the fight ends.
func _end_fight() -> void:
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	_heal()
	if coordinator.has_active_encounter():
		for participant: CombatParticipant in coordinator.active_encounter().participants():
			if participant.participant_id != _player.character_id:
				participant.binding.state.vitality.current = -1
	for _second: int in range(60):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter(), "the fight ends")
	_ui.refresh_projection()
	_heal()


func _advance() -> void:
	_session.combat_encounter_coordinator().advance_scheduler(1.0)
	_ui.refresh_projection()


func _press(panel: BattleActionPanel, label: String) -> void:
	for button: Node in panel._actions.get_children():
		if (button as Button).text == label:
			(button as Button).pressed.emit()
			return
	_check(false, "no %s button" % label)


func _log() -> String:
	return _ui.log_panel._text.get_parsed_text()


func _last() -> Array[String]:
	return ColoredLine.texts(_session.martial_arts().last_lines)


func _heal() -> void:
	for resource: CharacterResourceState in [_state.essence, _state.vitality, _state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func _here(zone_id: StringName) -> Array[NpcRuntimeState]:
	var here: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in _map.npc_runtimes():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			here.append(npc)
	return here


func _repeat(value: int, times: int) -> Array[int]:
	var out: Array[int] = []
	for _i: int in times:
		out.append(value)
	return out


func _beside(zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = _map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(_map, zone_id, marker.global_position + offset):
			_map.runtime_player_body().global_position = marker.global_position + offset
			return _player.set_world_location(_map.location_for_zone(zone_id))
	return false


func _npc(point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in _map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("waterfog celestial: " + label)
