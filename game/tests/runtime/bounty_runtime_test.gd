extends RefCounted

## A2 经验节奏 PR B in the world (DECISIONS「经验节奏」): the 武馆's 木人 (spar only), the
## 雪亭驿 board (看榜, 揭榜, one at a time), the outlaw coming out in its place, paid when
## killed (杀气 + 1) or spared (taken away, no 杀气), 放弃, the slot's refresh, a save with
## the outlaw standing; with the classic knobs neither board nor 木人.

const OUTLAW_1: StringName = &"native.npc.outlaw.1"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_dummies(tree, session)
	await _test_board(tree, session)
	await _test_kill(tree, session)
	await _test_spare(tree, session)
	await _test_give_up_and_save(tree, session)
	session.free()
	await tree.process_frame
	var previous: PacingDefinition = Es2Pacing.use()
	var classic: WorldSessionController = await _session(tree)
	_test_classic(classic)
	classic.free()
	Es2Pacing.restore(previous)
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_dummies(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"snow.school_compound", &"snow.school2", &"snow.school2", &"snow.school2.trainee.2").succeeded(), "to the 教练场")
	await _settle(tree)
	var map: WorldMapController = session.active_map() as WorldMapController
	var dummies: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().spar_only():
			dummies.append(npc)
	_check(dummies.size() == 5, "five 木人 stand in the 教练场: %d" % dummies.size())
	if dummies.is_empty():
		return
	var state: CharacterState = session.player_runtime().state
	state.progression.combat_experience = 100 # TEST-ONLY
	map.runtime_player_body().global_position = map.runtime_body_for_character(dummies[0].character_id).global_position + Vector2(0, 40)
	await _settle(tree)
	map.select_npc(dummies[0].character_id)
	var before: int = session.shared_ui().log_lines().size()
	_check(map.attack_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED, "攻击 on a 木人 is refused")
	_check(session.shared_ui().log_lines().slice(before).has(WorldMapSelection.SPAR_ONLY), "and says why")
	_check(map.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "切磋 is taken at once (even at less than 90%)")
	_run(session)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the spar ends")


func _test_board(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.progression.combat_experience = 200 # TEST-ONLY
	_check(session.handoff_to(&"snow.outdoor", &"snow.mstreet4", &"snow.mstreet4", &"snow.mstreet4.postoffice_return").succeeded(), "on the street by 雪亭驿")
	await _settle(tree)
	var map: WorldMapController = session.active_map() as WorldMapController
	var board: BountyService = null
	for node: Node in map.service_nodes:
		if node is BountyService:
			board = node
	_check(board != null, "the board is a service on the street")
	if board == null:
		return
	map.runtime_player_body().global_position = board.point.global_position + Vector2(40, 0)
	await _settle(tree)
	_check(board.in_reach() and board.verb() == "看榜", "看榜 within reach")
	board.refresh()
	var takes: Array[Node] = board.rows.find_children("Take", "Button", true, false)
	_check(takes.size() == 3, "three postings to take: %d" % takes.size())
	var first: Label = board.rows.get_child(0).get_node("Text")
	_check(first.text.begins_with("流窜毛贼 · 出没于老松岭") and first.text.ends_with("赏银五两"), "a posting: " + first.text)
	_check(board.take(0), "揭榜")
	_check(state.marks.has(WorldBounties.MARK_TAKEN) and board.rows.find_children("GiveUp", "Button", true, false).size() == 1, "taken: the mark, a 放弃 button")
	_check(board.rows.find_children("Take", "Button", true, false).all(func(b: Button) -> bool: return b.disabled), "the others are greyed: one at a time")
	session.record_journal()
	_check(state.journal.has("native.bounty/taken"), "the 任务 page: 官府悬赏")


## Taken, the outlaw comes out in its place; the player's blow kills it: paid, 杀气 + 1.
func _test_kill(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var posting: WorldBounties.Posting = session.bounties().taken()
	_check(posting != null and posting.place.zone_id == &"oldpine.outdoor.central_clearing", "the bounty taken is in 老松岭's clearing")
	if posting == null:
		return
	var outlaw: NpcRuntimeState = await _meet(tree, session, posting)
	_check(outlaw != null, "walking in, the 流窜毛贼 comes out")
	if outlaw == null:
		return
	state.progression.combat_experience = 400 # TEST-ONLY: 400 against 300, not far weaker
	state.skills.set_raw_level(&"unarmed", 60) # TEST-ONLY: the player wins
	var silver_before: int = _silver(session)
	var belli: int = state.attributes.bellicosity
	var exp_before: int = state.progression.combat_experience
	var before: int = session.shared_ui().log_lines().size()
	if not session.combat_encounter_coordinator().has_active_encounter():
		(session.active_map() as WorldMapController).select_npc(outlaw.character_id)
		(session.active_map() as WorldMapController).attack_selected()
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
	_run(session)
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()
	var lines: Array[String] = session.shared_ui().log_lines().slice(before)
	_check(outlaw.life_status == CharacterRuntimeLifeStatus.Value.DEAD, "the outlaw is killed")
	_check(lines.any(func(l: String) -> bool: return l.begins_with("【历练】你完成了官府悬赏「流窜毛贼」：实战经验 +")), "paid: %s" % [lines])
	_check(lines.has("雪亭驿付给你五两银子的赏银。") and _silver(session) == silver_before + 5, "and five taels of silver")
	_check(state.attributes.bellicosity == belli + 1 and state.progression.combat_experience > exp_before, "killed: 杀气 + 1")
	_check(session.bounties().taken() == null and state.bounty.refill_ms.has(600000), "done: nothing taken, the slot empty for 600 s")


## 放过 the outlaw lying down: paid, no 杀气, taken away after the fight.
func _test_spare(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var postings: Array[WorldBounties.Posting] = session.bounties().postings()
	_check(not postings.is_empty() and session.bounties().take(postings[0].slot), "another bounty taken")
	var posting: WorldBounties.Posting = session.bounties().taken()
	if posting == null:
		return
	var outlaw: NpcRuntimeState = await _meet(tree, session, posting)
	_check(outlaw != null, "its outlaw comes out at %s" % posting.place.zone_id)
	if outlaw == null:
		return
	state.skills.set_raw_level(&"unarmed", 25) # TEST-ONLY: strong enough to fell it, not to kill it outright
	outlaw.character_state.vitality.current = 3 # TEST-ONLY: the next blow fells it
	var belli: int = state.attributes.bellicosity
	var kills: int = state.progression.kills
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if not coordinator.has_active_encounter():
		(session.active_map() as WorldMapController).select_npc(outlaw.character_id)
		(session.active_map() as WorldMapController).attack_selected()
	var held: bool = false
	_check(coordinator.has_active_encounter(), "the fight with it is on")
	for round: int in 300:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		if outlaw.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			held = coordinator.spare_downed(outlaw.character_id)
			break
	_check(held, "it falls and the player spares it (%s)" % CharacterRuntimeLifeStatus.Value.find_key(outlaw.life_status))
	_run(session)
	CombatEncounterCoordinator.take_aborted_total()
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()
	session.record_journal()
	_check(state.attributes.bellicosity == belli and state.progression.kills == kills, "spared: no 杀气, no kill")
	_check(session.shared_ui().log_lines().has("你把%s捆了个结实，托路过的官差押往雪亭驿。" % outlaw.definition().display_name), "taken to the 驿站")
	_check(session.resident_npc(outlaw.character_id) == null, "and gone from the place")
	_check(state.journal.has("native.bounty/done"), "the 任务 page: the first bounty done")


## 放弃 sends a standing outlaw away; a save with an outlaw standing leaves it out.
func _test_give_up_and_save(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	session.bounties().advance(600.0)
	var postings: Array[WorldBounties.Posting] = session.bounties().postings()
	_check(postings.size() == 3, "after 600 s of play the board is full again: %d" % postings.size())
	if postings.is_empty() or not session.bounties().take(postings[0].slot):
		return
	var posting: WorldBounties.Posting = session.bounties().taken()
	state.vitality = CharacterResourceState.new(5000, 5000, 5000) # TEST-ONLY: outlives the ambush
	var outlaw: NpcRuntimeState = await _meet(tree, session, posting)
	_check(outlaw != null, "its outlaw comes out")
	if outlaw == null:
		return
	CombatEncounterCoordinator.take_aborted_total()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if coordinator.has_active_encounter():
		# The ambush: the player walks off (flee is a fight's own; here the fight is ended for the test).
		for round: int in 3:
			coordinator.advance_scheduler(1.0)
	var eligible: OldPineSaveEligibilityResult = OldPineSaveEligibility.inspect(session) if not coordinator.has_active_encounter() else null
	if eligible != null:
		_check(eligible.allowed(), "a save with the outlaw standing is allowed (it is left out)")
	_check(session.bounties().give_up(), "放弃")
	await _settle(tree)
	session.record_journal()
	if not coordinator.has_active_encounter():
		_check(session.resident_npc(outlaw.character_id) == null, "the outlaw slips away")
	_check(session.bounties().taken() == null and state.bounty.refill_ms.has(600000), "given up: its slot waits 600 s")


func _test_classic(session: WorldSessionController) -> void:
	_check(not session.bounties().enabled() and session.bounties().postings().is_empty(), "classic: no board")
	var map: WorldMapController = session.world_map_of(&"snow.school_compound")
	var dummies: int = 0
	if map != null:
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().spar_only():
				dummies += 1
	_check(dummies == 0, "classic: no 木人")


func _meet(tree: SceneTree, session: WorldSessionController, posting: WorldBounties.Posting) -> NpcRuntimeState:
	var map_definition: MapDefinition = GameContent.catalog().map(posting.place.map_id)
	var entry: StringName = map_definition.entry_spawn_id
	session.handoff_to(posting.place.map_id, posting.place.zone_id, posting.place.zone_id, entry)
	await _settle(tree)
	var map: WorldMapController = session.active_map() as WorldMapController
	var location: WorldLocationState = session.player_runtime().world_location()
	if location.zone_id != posting.place.zone_id:
		# TEST-ONLY: into the place's zone itself.
		var zone_spot: Vector2 = MapPlaces.spot(map, posting.place.zone_id, map.runtime_player_body().global_position)
		map.runtime_player_body().global_position = zone_spot
		session.player_runtime().set_world_location(map.location_for_zone(posting.place.zone_id))
		await _settle(tree)
	session.record_journal()
	await _settle(tree)
	for npc: NpcRuntimeState in session.world_npcs():
		if npc.definition().definition_id == posting.tier.npc_id and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			return npc
	return null


func _silver(session: WorldSessionController) -> int:
	var total: int = 0
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if GameContent.catalog().denomination_of(row.item_definition_id) == CurrencyDenomination.Value.SILVER:
			total += row.amount
	return total


func _run(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	CombatEncounterCoordinator.take_aborted_total()


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("悬赏", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
