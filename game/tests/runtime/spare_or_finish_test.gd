extends RefCounted

## DECISIONS「了结 / 放过」: when one the player's side is killing falls, the side holds its
## blow and the card offers 了结 (the next blow kills, ES2) and 放过 (remove_killer(): it
## lies there and comes to on its own, after the fight, bearing no grudge). The fight goes
## on meanwhile; the held one's revive call_out runs on the fight's clock and, if it comes
## to before the player chose, the fight goes on as ES2's. The player's own summons follow
## the choice; anyone else keeps to ES2. 击倒后 at 直接了结 is ES2 throughout. In 青石村
## (the 工匠, the 采石工s, the old couple); combat draws from a seeded stream, other draws
## scripted. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const Spells := preload("res://tests/runtime/green_spells_test.gd")
const Juechen := preload("res://tests/runtime/green_juechen_test.gd")
const ShellTests := preload("res://tests/application/application_shell_test.gd")
const Zombie := preload("res://tests/runtime/temple_zombie_test.gd")
const WORKER: StringName = &"green.npc.worker1"
const QUARRYMAN: StringName = &"green.npc.worker2"
const SOLDIER: StringName = &"common.npc.heaven_soldier"
const SUMMON: StringName = &"cast.saveme"
const SEED: int = 20261020

var _count: int = 0
var _failures: Array[String] = []
var _requests: int = 0
var _knockout_before: int


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_knockout_before = BattlePace.after_knockout
	_test_settings()
	_test_restore_order()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"green.village", &"green.path6", &"green.path6", &"green.path6.snow_entry").succeeded(), "TEST-ONLY: into the village")
	await tree.physics_frame
	await tree.physics_frame
	_strong(session.player_runtime().state)
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	await _test_finish(tree, session)
	await _test_spare(tree, session)
	await _test_comes_to(tree, session)
	await _test_two_enemies(tree, session)
	await _test_summons(tree, session)
	await _test_es2_setting(tree, session)
	session.free()
	await tree.process_frame
	await _test_sheet(tree)
	BattlePace.after_knockout = _knockout_before
	return {"assertions": _count, "failures": _failures}


## Settings schema 5: 击倒后 is kept (ask / finish), a version 4 file reads as 询问, and an
## unknown value is refused.
func _test_settings() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=4\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\n".to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	_check(old.succeeded() and old.snapshot().after_knockout() == BattlePace.AfterKnockout.ASK and old.snapshot().battle_speed() == BattlePace.Speed.FAST and old.snapshot().ui_scale() == 125, "a version 4 file: 询问, the rest kept")
	var written: ApplicationSettingsResult = repository.write(old.snapshot().with_battle(BattlePace.Speed.FAST, false, BattlePace.AfterKnockout.FINISH))
	var back: ApplicationSettingsResult = repository.load()
	_check(written.succeeded() and back.succeeded() and back.snapshot().version() == 5 and back.snapshot().after_knockout() == BattlePace.AfterKnockout.FINISH, "written and read back: 直接了结")
	_check(files.files[ApplicationSettingsRepository.SETTINGS_PATH].get_string_from_utf8().contains("after_knockout=\"finish\""), "stored as finish")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = files.files[ApplicationSettingsRepository.SETTINGS_PATH].get_string_from_utf8().replace("\"finish\"", "\"spare\"").to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "an unknown 击倒后 is refused")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=5\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "a version 5 file without it is refused")
	ApplicationSettingsService._apply_battle(back.snapshot())
	_check(BattlePace.after_knockout == BattlePace.AfterKnockout.FINISH, "applied")
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	BattlePace.speed = BattlePace.Speed.NORMAL
	BattlePace.hit_flash = true
	_check(ApplicationSettingsSnapshot.defaults().after_knockout() == BattlePace.AfterKnockout.ASK, "询问 by default")


## One holding two who fell gives them back where they stood, whichever is given back
## first; one that was no enemy of it comes back as a kill mark only.
func _test_restore_order() -> void:
	for first: StringName in [&"a", &"b"]:
		var relationship := CombatRelationshipState.new(&"p")
		for id: StringName in [&"a", &"b", &"c"]:
			relationship.mark_lethal_target(id)
		var order: Array = CombatEncounterResolution._merged([], relationship.lethal_target_ids())
		relationship.remove_lethal_relation(&"a")
		order = CombatEncounterResolution._merged(order, relationship.lethal_target_ids())
		relationship.remove_lethal_relation(&"b")
		order = CombatEncounterResolution._merged(order, relationship.lethal_target_ids())
		var second: StringName = &"b" if first == &"a" else &"a"
		for id: StringName in [first, second]:
			var before: Array[StringName] = CombatEncounterResolution._before(order, id)
			relationship.restore_lethal_target(id, before, before)
		_check(relationship.lethal_target_ids() == [&"a", &"b", &"c"] and relationship.opponent_ids() == [&"a", &"b", &"c"], "%s given back first: a, b, c as before: %s" % [first, relationship.lethal_target_ids()])
	var marked := CombatRelationshipState.new(&"p")
	marked.restore_lethal_target(&"a", [], null)
	_check(marked.has_lethal_target(&"a") and not marked.has_opponent(&"a"), "no enemy before: a kill mark only")


## 了结: the 工匠 falls; nobody strikes him while the card asks (its countdown, its two
## buttons, 任务目标 for 朱鸿雪's target); 了结 turns the player on him again and the next
## blows kill him: MKS, bellicosity and the task as ever. No save while he waits.
func _test_finish(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var worker: NpcRuntimeState = _first(session.world_map_of(&"green.house1_house"), WORKER)
	var map: WorldMapController = await _beside(tree, session, worker)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	player.state.quest.assign(QuestDefinition.new(worker.definition().display_name, QuestDefinition.KILL, 600, 40, 30, 4), 10) # TEST-ONLY: 朱鸿雪's task on him
	map.select_npc(worker.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the 工匠")
	var exp_before: int = player.state.progression.combat_experience
	var kills: int = player.state.progression.kills
	var bellicosity: int = player.state.attributes.bellicosity
	_fell(coordinator, worker)
	_check(worker.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and coordinator.held_victims() == [worker.character_id], "he falls and is held")
	_check(not player.relationship.has_lethal_target(worker.character_id) and not player.relationship.has_opponent(worker.character_id), "the player stops killing him (remove_killer())")
	_check(worker.relationship.has_lethal_target(player.character_id), "his own kill_ob() stands")
	_check(not OldPineSaveEligibility.inspect(session).allowed(), "no save while the fight waits")
	var revive: int = worker.revive_in_ms
	_check(revive >= 30000, "his revive call_out: %d ms" % revive)
	for _round: int in 3:
		coordinator.advance_scheduler(1.0)
	_check(coordinator.has_active_encounter() and worker.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and worker.revive_in_ms == revive - 3000, "three rounds: still there, his countdown down by the fight's three seconds")
	_check(not _struck(coordinator, worker.character_id), "and nobody struck him")
	var card: BattleParticipantCard = await _card(tree, session, worker.character_id)
	_check(card != null and card.choice_row.visible and not card.target_button.visible, "his card shows the choice")
	_check(_ui(session).current_projection().current_target_id.is_empty() and not card._title.text.ends_with("当前目标"), "he is nobody's target while held: " + ("" if card == null else card._title.text))
	if card == null:
		return
	_check(card.finish_button.text == "了结（任务目标）" and card.spare_button.text == "放过", "了结（任务目标） / 放过: %s / %s" % [card.finish_button.text, card.spare_button.text])
	_check(card._status.text.ends_with("昏迷 · 约 %d 秒后醒来" % ceili(worker.revive_in_ms / 1000.0)), "the countdown: " + card._status.text)
	_check(card.spare_button.tooltip_text == "放工匠一条生路：你这一方不再出手，工匠昏在原地，到时自己醒来。", "放过 says what it does: " + card.spare_button.tooltip_text)
	await _pseudo(tree, session, card)
	card.finish_button.pressed.emit()
	_check(coordinator.held_victims().is_empty() and player.relationship.has_lethal_target(worker.character_id) and coordinator.active_encounter().current_target_for(player.character_id) == worker.character_id, "了结: the player kills him again, at him")
	_run(coordinator)
	_check(worker.life_status == CharacterRuntimeLifeStatus.Value.DEAD and not coordinator.has_active_encounter(), "the next blows kill him")
	_check(player.state.progression.kills == kills + 1 and player.state.attributes.bellicosity == bellicosity + 1, "MKS and 杀气 as ever")
	_check(not player.state.quest.has_task() and player.state.progression.combat_experience > exp_before, "朱鸿雪's task done")
	_ui(session).refresh_projection()
	await tree.process_frame
	_check(_result_line(session) == "你赢了这场战斗。选择倒下对手的尸体可以查看或搜刮。", "won: his corpse to look at: " + _result_line(session))
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborted")
	await _settle(tree, session)


## 放过: the 采石工 is let be; with nobody else to fight the fight is over. He lies there,
## comes to on world time and bears no grudge: no attack on sight, no fight. Save works
## while he lies there and keeps his countdown.
func _test_spare(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var quarryman: NpcRuntimeState = _first(session.world_map_of(&"green.village"), QUARRYMAN)
	var map: WorldMapController = await _beside(tree, session, quarryman)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	map.select_npc(quarryman.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 采石工")
	var kills: int = player.state.progression.kills
	var bellicosity: int = player.state.attributes.bellicosity
	_fell(coordinator, quarryman)
	var card: BattleParticipantCard = await _card(tree, session, quarryman.character_id)
	_check(card != null and card.finish_button.text == "了结", "no task on him: 了结 alone")
	if card == null:
		return
	card.spare_button.pressed.emit()
	_check(coordinator.held_victims().is_empty(), "放过")
	coordinator.advance_scheduler(0.0)
	var receipt: CombatEncounterCompletionResult = coordinator.last_completion()
	_check(not coordinator.has_active_encounter() and receipt != null and receipt.terminal_result.kind == CombatEncounterResultKind.Value.VICTORY, "nobody else to fight: the fight is over, won")
	_ui(session).refresh_projection()
	await tree.process_frame
	_check(_battle_log(session).contains("你住了手，放了采石工一条生路。"), "the log says so: " + _battle_log(session).right(60))
	_check(_result_line(session) == "你赢了这场战斗。", "won, with no corpse to point at: " + _result_line(session))
	_check(quarryman.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and player.state.progression.kills == kills and player.state.attributes.bellicosity == bellicosity, "he lies there; no kill counted")
	_check(not quarryman.relationship.has_lethal_target(player.character_id) and not quarryman.relationship.is_fighting() and not player.relationship.is_fighting(), "the fight's end forgets them both")
	_check(not quarryman.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER) and not quarryman.definition().attacks_on_sight(quarryman.flags(), player.state), "no grudge: he does not attack on sight")
	_check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open while he lies there")
	var left: int = quarryman.revive_in_ms
	var encoded: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	_check(left > 0 and encoded.contains("\"revive_in_ms\": \"%d\"" % left), "his countdown is saved (%d ms)" % left)
	for _beat: int in range(200):
		if quarryman.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			break
		session._process(1.0)
	_check(quarryman.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "he comes to on world time")
	for _beat: int in 3:
		session._process(0.5)
	_check(not coordinator.has_active_encounter(), "beside the player, he does not fall on them")
	await _settle(tree, session)


## No choice made: the held one's countdown runs out in the fight and he comes to; the
## player kills him again (ES2) and the fight goes on.
func _test_comes_to(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var quarryman: NpcRuntimeState = _first(session.world_map_of(&"green.village"), QUARRYMAN)
	var map: WorldMapController = await _beside(tree, session, quarryman)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	map.select_npc(quarryman.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 采石工 again")
	_fell(coordinator, quarryman)
	quarryman.set_revive_in_ms(2500) # TEST-ONLY: a short call_out
	coordinator.advance_scheduler(1.0)
	coordinator.advance_scheduler(1.0)
	var card: BattleParticipantCard = await _card(tree, session, quarryman.character_id)
	_check(card != null and card._status.text.ends_with("约 1 秒后醒来") and quarryman.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "two rounds: 约 1 秒后醒来")
	var events_from: int = coordinator.active_scheduler().events().size()
	var logged: int = session.shared_ui().log_lines().size()
	coordinator.advance_scheduler(1.0)
	_check(quarryman.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and coordinator.held_victims().is_empty() and coordinator.has_active_encounter(), "the third: he comes to, the fight goes on")
	_check(player.relationship.has_lethal_target(quarryman.character_id) and player.relationship.has_opponent(quarryman.character_id), "the player kills him again")
	var struck: bool = false
	for event: CombatSchedulerEvent in coordinator.active_scheduler().events().slice(events_from):
		struck = struck or (event.actor_id == player.character_id and event.target_id == quarryman.character_id and event.resolution != null)
	_check(struck, "and strikes at him that round")
	_ui(session).refresh_projection()
	await tree.process_frame
	_check(_battle_log(session).contains("采石工慢慢睁开眼睛，清醒了过来。"), "combatd.c announce(revive): " + _battle_log(session).right(80))
	_check(not session.shared_ui().log_lines().slice(logged).has("采石工慢慢睁开眼睛，清醒了过来。"), "told on the battle panel, not twice in the log")
	# He falls again: held again; 了结 this time.
	_fell(coordinator, quarryman)
	_check(coordinator.held_victims() == [quarryman.character_id], "felled again: held again")
	_check(coordinator.finish_downed(quarryman.character_id), "了结")
	_run(coordinator)
	_check(quarryman.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "dead")
	await _settle(tree, session)


## Two enemies (老公公's ask_for_help() brings 老婆婆 at the player, ES2): only the fallen
## one is held, the fight goes on at the other; both down and held, it waits. The player
## falls: nobody can choose, the held blows are back (ES2) and the fight ends.
func _test_two_enemies(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var home: WorldMapController = session.world_map_of(&"green.house2_house")
	var man: NpcRuntimeState = _first(home, &"green.npc.oldman")
	var wife: NpcRuntimeState = _first(home, &"green.npc.oldwoman")
	var map: WorldMapController = await _beside(tree, session, man)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	map.select_npc(man.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 老公公")
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(coordinator.active_encounter())
	var chat := CombatNpcChat.new(coordinator._resident_npc, coordinator._npc_wield, coordinator._respect_of).with_villagers(coordinator._npc_wield_item, coordinator._age_of, coordinator._idle_partner)
	var called: CombatNpcChatResult = chat.beat(_binding(bindings, man.character_id), [], [], Specials.Pattern.new([0, 0]), SkillImprovementEffectRegistry.new())
	_check(called != null and called.joins().size() == 1 and called.joins()[0].target_ids == [player.character_id], "ask_for_help(): 老婆婆 comes at the player")
	if called == null:
		return
	coordinator.resolution().admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(called.joins()))
	player.relationship.mark_lethal_target(wife.character_id) # TEST-ONLY: as if the player had 攻击 her too
	_check(coordinator.active_encounter().participant_for(wife.character_id) != null and wife.relationship.has_lethal_target(player.character_id), "she is in the fight, killing the player")
	_fell(coordinator, wife)
	_check(coordinator.held_victims() == [wife.character_id] and man.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "she fell and is held; he stands")
	var events_from: int = coordinator.active_scheduler().events().size()
	for _round: int in 2:
		coordinator.advance_scheduler(1.0)
	var at_man: bool = false
	var at_wife: bool = false
	for event: CombatSchedulerEvent in coordinator.active_scheduler().events().slice(events_from):
		if event.actor_id == player.character_id and event.resolution != null:
			at_man = at_man or event.target_id == man.character_id
			at_wife = at_wife or event.target_id == wife.character_id
	_check(at_man and not at_wife and coordinator.active_encounter().current_target_for(player.character_id) == man.character_id, "the player fights on at him, not at her")
	_check(not _struck(coordinator, wife.character_id, events_from), "nobody strikes her")
	_fell(coordinator, man)
	_check(coordinator.held_victims() == [man.character_id, wife.character_id] and coordinator.has_active_encounter(), "both down and held: the fight waits on the player")
	player.state.vitality.current = -1 # TEST-ONLY: the player falls
	coordinator.advance_scheduler(0.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and coordinator.held_victims().is_empty(), "the player falls: nobody holds any more")
	_check(not coordinator.has_active_encounter() and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.DEFEAT, "the fight ends as ES2's: nobody stands")
	_check(man.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and wife.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "the old couple live")
	for _beat: int in range(200):
		if player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			break
		session._process(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the player comes to")
	_strong(player.state)
	await _settle(tree, session)


## The player's 天将 follows the choice: held with the player, quiet after 放过; after 了结
## it kills again. One on the player's side the player did not call keeps to ES2.
func _test_summons(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	Spells._learn(player.state)
	player.state.skills.unmap_skill(&"spells")
	_check(session.martial_arts().enable(&"spells", &"magic-array"), "TEST-ONLY: 奇门遁甲 enabled")
	player.state.recovery.mana = CharacterInternalResourceState.new(1000, 1000)
	player.state.spirit = CharacterResourceState.new(1000, 1000, 1000)
	var quarryman: NpcRuntimeState = _first(session.world_map_of(&"green.village"), QUARRYMAN)
	var map: WorldMapController = await _beside(tree, session, quarryman)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	map.select_npc(quarryman.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks a 采石工")
	var soldier: NpcRuntimeState = _summon(session, map)
	_check(soldier != null and soldier.relationship.has_lethal_target(quarryman.character_id), "the player's 天将 kills him too")
	if soldier == null:
		return
	_fell(coordinator, quarryman)
	_check(coordinator.held_victims() == [quarryman.character_id] and not soldier.relationship.has_lethal_target(quarryman.character_id) and not soldier.relationship.has_opponent(quarryman.character_id), "held: the 天将 holds its blow too")
	var events_from: int = coordinator.active_scheduler().events().size()
	coordinator.advance_scheduler(1.0)
	_check(not _struck(coordinator, quarryman.character_id, events_from), "it does not strike him")
	_check(coordinator.finish_downed(quarryman.character_id) and soldier.relationship.has_lethal_target(quarryman.character_id), "了结: the 天将 kills him again")
	_run(coordinator)
	_check(quarryman.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "he dies")
	await _settle(tree, session)
	# 放过 with the 天将 beside: it stops; the fight ends; it leaves.
	quarryman = _first(session.world_map_of(&"green.village"), QUARRYMAN)
	map = await _beside(tree, session, quarryman)
	map.select_npc(quarryman.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks another 采石工")
	soldier = _summon(session, map)
	if soldier == null:
		return
	var soldier_id: StringName = soldier.character_id
	_fell(coordinator, quarryman)
	_check(coordinator.spare_downed(quarryman.character_id), "放过")
	coordinator.advance_scheduler(0.0)
	_check(not coordinator.has_active_encounter() and quarryman.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and map.find_resident_npc(soldier_id) == null, "the fight is over, he lives, the 天将 left")
	await _settle(tree, session)
	# One on the player's side they did not call (TEST-ONLY: the soldier's caller forgotten).
	var other: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == QUARRYMAN and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			other = npc
	_check(other != null, "a third 采石工")
	if other == null:
		return
	map = await _beside(tree, session, other)
	map.select_npc(other.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the third")
	soldier = _summon(session, map)
	if soldier == null:
		return
	map.npcs.summoners.erase(soldier.character_id) # TEST-ONLY: as if it had come on its own
	_fell(coordinator, other)
	_check(coordinator.held_victims() == [other.character_id] and soldier.relationship.has_lethal_target(other.character_id) and not player.relationship.has_lethal_target(other.character_id), "the player holds; the one they did not call kills on (ES2)")
	_run(coordinator)
	_check(other.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "it finishes him")
	await _settle(tree, session)
	# The player only fights back and their 天将 lies down: nobody standing would strike, so
	# nothing is asked (ES2: nobody kills him).
	var last: NpcRuntimeState = _first(session.world_map_of(&"green.village"), QUARRYMAN)
	if last == null:
		_check(false, "a last 采石工")
		return
	map = await _beside(tree, session, last)
	map.select_npc(last.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the last 采石工")
	soldier = _summon(session, map)
	if soldier == null:
		return
	player.relationship.remove_lethal_relation(last.character_id) # TEST-ONLY: as if the player only fought back
	player.relationship.add_opponent(last.character_id)
	_fell(coordinator, soldier)
	_fell(coordinator, last)
	_check(coordinator.held_victims().is_empty() and not coordinator.has_active_encounter() and last.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "the 天将 lies down: nothing asked; nobody standing kills him, the fight is over and he lives")
	_run(coordinator)
	_check(last.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "nobody standing kills him: he lives")
	await _settle(tree, session)


## 击倒后 at 直接了结: no hold, no buttons; the next blow kills (ES2).
func _test_es2_setting(tree: SceneTree, session: WorldSessionController) -> void:
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
	var kid: NpcRuntimeState = null
	for npc: NpcRuntimeState in session.world_map_of(&"green.village").resident_npcs():
		if npc.definition().definition_id == QUARRYMAN and npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			kid = npc
	if kid != null:
		(session.world_map_of(&"green.village") as WorldMapController).npc_life.revive(kid) # TEST-ONLY: one spared, up again
		Spells._whole(kid.character_state)
	_check(kid != null, "a spared 采石工, up again")
	if kid == null:
		BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
		return
	var map: WorldMapController = await _beside(tree, session, kid)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	map.select_npc(kid.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks")
	_fell(coordinator, kid)
	_check(coordinator.held_victims().is_empty() and session.player_runtime().relationship.has_lethal_target(kid.character_id), "直接了结: nobody holds")
	var card: BattleParticipantCard = await _card(tree, session, kid.character_id)
	_check(card != null and not card.choice_row.visible, "no buttons")
	_run(coordinator)
	_check(kid.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "the next blows kill (ES2)")
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	await _settle(tree, session)


## A 僵尸追魂符 (haunt.c): the player stands by while their zombie kills a taoist; he falls:
## the zombie holds its blow (the player called it) and 放过 lets him be. On the temple
## grounds, a session of its own.
func _test_sheet(tree: SceneTree) -> void:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("茅工", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"temple.grounds", &"temple.square", &"temple.square", &"temple.square.gate_arrival").succeeded(), "TEST-ONLY: inside the temple's gate")
	await tree.physics_frame
	await tree.physics_frame
	var zombies := Zombie.new()
	zombies._make_taoist(session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var map: WorldMapController = session.active_map() as WorldMapController
	var xuanhe: NpcRuntimeState = _first(map, Zombie.XUANHE)
	# Another taoist on the grounds, whom a sheet can name (TEST-ONLY: the first such).
	var old: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if old == null and npc != xuanhe and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and npc.definition().definition_id != Zombie.MASTER and GameContent.catalog().item(ItemContentDefinition.haunting_sheet_id(Zombie.PAPER, npc.definition().definition_id)) != null:
			old = npc
	_check(xuanhe != null and old != null, "玄和 and another to send it after")
	if xuanhe == null or old == null:
		session.free()
		return
	map = await _beside(tree, session, xuanhe)
	var corpse: CorpseState = zombies._kill(map, xuanhe, player) # TEST-ONLY: 玄和 dies by the player's hand
	var before: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		before.append(npc.character_id)
	_check(corpse != null and map.select_corpse(corpse.corpse_item_instance_id) and map.animate_selected_corpse(), "驱尸")
	var zombie: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if not before.has(npc.character_id) and SummonedNpc.definition_id_of(npc.character_id) == Zombie.ZOMBIE:
			zombie = npc
	_check(zombie != null and map.summoner_of(zombie.character_id) == player.character_id, "玄和的僵尸, the player's")
	if zombie == null:
		session.free()
		return
	zombies._move(map, old, zombie.world_location().zone_id) # TEST-ONLY: he comes into the zombie's room
	var sheet_definition: StringName = ItemContentDefinition.haunting_sheet_id(Zombie.PAPER, old.definition().definition_id)
	map.give_new_item_to_player(sheet_definition) # TEST-ONLY
	var sheet: StringName = &""
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.item_definition_id == sheet_definition:
			sheet = row.item_instance_id
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(map.attach_sheet(sheet) and coordinator.has_active_encounter() and zombie.relationship.has_lethal_target(old.character_id) and not player.relationship.is_fighting(), "贴符: it goes after %s; the player stands by" % old.definition().display_name)
	_fell(coordinator, old)
	_check(coordinator.held_victims() == [old.character_id] and not zombie.relationship.has_lethal_target(old.character_id), "he falls: the zombie holds its blow")
	var card: BattleParticipantCard = await _card(tree, session, old.character_id)
	_check(card != null and card.choice_row.visible, "his card asks the player")
	_check(coordinator.spare_downed(old.character_id), "放过")
	coordinator.advance_scheduler(0.0)
	_check(not coordinator.has_active_encounter() and old.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and map.find_resident_npc(zombie.character_id) == zombie, "the fight is over; he lives; the zombie stays")
	await _settle(tree, session)
	session.free()
	await tree.process_frame


# --- Helpers ------------------------------------------------------------------------

## TEST-ONLY: a player who lands the blows and lasts.
static func _strong(state: CharacterState) -> void:
	state.progression.combat_experience = 100000
	state.vitality = CharacterResourceState.new(50000, 50000, 50000)
	state.essence = CharacterResourceState.new(5000, 5000, 5000)


## TEST-ONLY: knocked out (char.c heart_beat() at the next look).
func _fell(coordinator: CombatEncounterCoordinator, npc: NpcRuntimeState) -> void:
	npc.character_state.vitality.current = -1
	coordinator.advance_scheduler(0.0)
	_check(npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "%s falls" % npc.definition().display_name)


## Whether anyone struck `victim_id` in the fight since `from` (an event with a resolution at it).
func _struck(coordinator: CombatEncounterCoordinator, victim_id: StringName, from: int = 0) -> bool:
	for event: CombatSchedulerEvent in coordinator.active_scheduler().events().slice(from):
		if event.target_id == victim_id and event.resolution != null and event.resolution.forward_result != null:
			return true
	return false


func _summon(session: WorldSessionController, map: WorldMapController) -> NpcRuntimeState:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var before: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		before.append(npc.character_id)
	session.player_runtime().state.recovery.mana.current = 1000
	# TEST-ONLY: random(spells) at its highest, so the 天将 comes (saveme.c: below 60 nothing does).
	var seeded: CombatRandomSource = session.combat_random_source()
	session.configure_combat_random_source(Juechen.Forced.new())
	_requests += 1
	var result: CombatTacticalResult = coordinator.submit_player_action(CombatTacticalRequest.new(
		StringName("cast:%d" % _requests), coordinator.active_encounter().encounter_id, session.player_runtime().character_id,
		SUMMON, CombatTacticalRequest.Category.SPELL,
	))
	_check(result.code == CombatTacticalResult.Code.ACCEPTED, "召天将 queued: %s" % BattleFeedbackReader.reason(result.code))
	coordinator.advance_scheduler(0.0)
	session.configure_combat_random_source(seeded)
	for npc: NpcRuntimeState in map.npc_runtimes():
		if not before.has(npc.character_id) and SummonedNpc.definition_id_of(npc.character_id) == SOLDIER:
			return npc
	_check(false, "a 天将 came")
	return null


func _run(coordinator: CombatEncounterCoordinator) -> void:
	for _round: int in range(300):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter(), "the fight ends: " + coordinator.last_abort_detail())


## The fight's end told; world time to clear it.
func _settle(tree: SceneTree, session: WorldSessionController) -> void:
	_ui(session).refresh_projection()
	await tree.process_frame
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no fight aborted")


func _card(tree: SceneTree, session: WorldSessionController, character_id: StringName) -> BattleParticipantCard:
	var ui: BattlePresentationController = _ui(session)
	ui.refresh_projection()
	await tree.process_frame
	ui._present_participants()
	var index: int = ui._shown_participants.find(character_id)
	return null if index < 0 else ui._cards[index]


## Every word on the card goes through a translation (pseudo-language).
func _pseudo(tree: SceneTree, session: WorldSessionController, card: BattleParticipantCard) -> void:
	var translation: Translation = PseudoLocale.translation()
	var locale: String = TranslationServer.get_locale()
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(PseudoLocale.CODE)
	_ui(session).refresh_projection()
	await tree.process_frame
	_ui(session)._present_participants()
	var names: PackedStringArray = []
	for npc: NpcRuntimeState in (session.active_map() as WorldMapController).npc_runtimes():
		names.append(npc.definition().display_name)
	_check(VisibleTextScan.untranslated(card.choice_row).is_empty() and PseudoLocale.untranslated(card.spare_button.tooltip_text).is_empty() and PseudoLocale.untranslated(card._status.text).is_empty(), "translated: %s %s %s" % [VisibleTextScan.untranslated(card.choice_row), card.spare_button.tooltip_text, card._status.text])
	var spared := BattleFeedbackReader._announce(CombatLifecycleAnnouncement.new(&"x", CombatLifecycleAnnouncement.SPARED), _ui(session).current_projection())
	var woke := BattleFeedbackReader._announce(CombatLifecycleAnnouncement.new(&"x", CombatLifecycleAnnouncement.REVIVE), _ui(session).current_projection())
	_check(PseudoLocale.untranslated(spared[0].text.replace("x", "")).is_empty() and PseudoLocale.untranslated(woke[0].text.replace("x", "")).is_empty(), "the lines: %s %s" % [spared[0].text, woke[0].text])
	TranslationServer.set_locale(locale)
	TranslationServer.remove_translation(translation)
	_ui(session).refresh_projection()
	_ui(session)._present_participants()


func _ui(session: WorldSessionController) -> BattlePresentationController:
	return session.get_node("BattlePresentationLayer/BattleSurface")


## The last fight's result line in the log (its first line).
func _result_line(session: WorldSessionController) -> String:
	var lines: Array[String] = session.shared_ui().log_lines()
	for index: int in range(lines.size() - 1, -1, -1):
		if lines[index].begins_with("你赢了") or lines[index].begins_with("你输了"):
			return lines[index].get_slice("\n", 0)
	return ""


func _battle_log(session: WorldSessionController) -> String:
	return _ui(session).log_panel._text.get_parsed_text().strip_edges()


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


## TEST-ONLY: the player beside an NPC, on a free spot of its zone, on whichever map it stands.
func _beside(tree: SceneTree, session: WorldSessionController, npc: NpcRuntimeState) -> WorldMapController:
	var zone_id: StringName = npc.world_location().zone_id
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null or map.map_id() != MapPlaces.map_of(zone_id):
		map = MapPlaces.enter(session, zone_id, npc.spawn_point_id)
		_check(map != null, "TEST-ONLY: onto %s's map" % npc.definition().display_name)
		await tree.physics_frame
		await tree.physics_frame
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 80.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame
	map.npc_life._advance_ambience(0.0)
	return map


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("了结/放过: " + label)
