class_name WorldMapHostilities
extends RefCounted
## How fights start on this map: presence and the aggression queue, toll-takers,
## complete_set rooms, berserk (an NPC's and the player's), the opening lines and the
## lethal start. Code moved from WorldMapController as it was; the map is `_map`.

var _map: WorldMapController
var _last_player_berserk := CombatSliceInitiationResult.new()
## combatd.c catch_hunt_msg: start_hatred()'s message_vision(), $N the hunter, $n its prey.
const CATCH_HUNT: Array[String] = [
	"$N和$n仇人相见分外眼红，立刻打了起来！",
	"$N对著$n大喝：「可恶，又是你！」",
	"$N和$n一碰面，二话不说就打了起来！",
	"$N一眼瞥见$n，「哼」的一声冲了过来！",
	"$N一见到$n，愣了一愣，大叫：「我宰了你！」",
	"$N喝道：「$n，我们的帐还没算完，看招！」",
	"$N喝道：「$n，看招！」",
]
## The NPC whose arrival made the player's init() roll go over: combatd.c
## auto_fight() call_out()s start_berserk(), run on the next world tick (after the
## room's description). Empty when none waits (looking_for_trouble).
var pending_player_berserk: StringName = &""
var aggression: NpcAggressionAdapter = NpcAggressionAdapter.new()
var _last_aggression_decisions: Array[NpcAggressionDecision] = []
var _last_aggression_initiations: Array[CombatSliceInitiationResult] = []
## Aggressive NPCs of a complete-set zone whose current contact already started
## an encounter; contact must break before it can start another.
var complete_set_consumed_contacts: Array[StringName] = []
## Seconds each toll-taker (NpcDealings.toll_attack_delay_ms) has been touching the
## player without a break; its greeting attacks once that reaches the delay.
var toll_contact_seconds: Dictionary[StringName, float] = {}
## Toll-takers put back in the pair queue while their greeting waits.
var toll_waiting: Dictionary[StringName, bool] = {}

# The map's authorities, read as the controller reads them.
var session: WorldSessionController:
	get: return _map.session
var player_body: WorldCharacterBody2D:
	get: return _map.player_body
var map: StringName:
	get: return _map.map
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()
var _inventory: InventoryState:
	get: return _map.inventory_state()
var _item_index: WorldItemInstanceIndex:
	get: return _map.item_instance_index()
var _combat_random: CombatRandomSource:
	get: return _map.combat_random_source()
var _world_interaction_random: WorldInteractionRandomSource:
	get: return _map.world_interaction_random_source()


func _init(controller: WorldMapController) -> void:
	_map = controller


static func zone_entry(location: WorldLocationState) -> StringName:
	var zone: ZoneDefinition = null if location == null else GameContent.catalog().zone(location.zone_id)
	return &"" if zone == null else zone.combat_entry


## combatd.c start_aggressive/hatred/vendetta return in a no_fight room; an
## NPC's own zone counts too, since presence can reach across a zone edge.
func _combat_allowed(npc: NpcRuntimeState = null) -> bool:
	var location: WorldLocationState = _player.world_location()
	if location == null or location.map_id != map:
		return false
	var catalog: ContentCatalog = GameContent.catalog()
	if catalog.zone_forbids_fighting(location.zone_id):
		return false
	return npc == null or not catalog.zone_forbids_fighting(npc.world_location().zone_id)


## A complete-set zone polls exact contact instead of queueing pair entries.
func on_presence_entered(body: Node2D, character_id: StringName) -> void:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
	if _map.gameplay_open() and body == player_body and npc != null and zone_entry(npc.world_location()) != &"complete_set":
		aggression.enter_player_presence(npc, _player, _combat_allowed(npc))


func on_presence_exited(body: Node2D, character_id: StringName) -> void:
	if body == player_body and not complete_entry_contact(character_id):
		complete_set_consumed_contacts.erase(character_id)
	if _map.gameplay_open() and body == player_body:
		aggression.leave_player_presence(character_id)
		toll_waiting.erase(character_id)


func aggression_adapter() -> NpcAggressionAdapter:
	return aggression


func last_aggression_decisions() -> Array[NpcAggressionDecision]:
	return _last_aggression_decisions.duplicate()


func last_aggression_initiations() -> Array[CombatSliceInitiationResult]:
	return _last_aggression_initiations.duplicate()


func process_pending_aggression() -> Array[CombatSliceInitiationResult]:
	if not _map.gameplay_open() or session == null:
		return []
	_last_aggression_initiations.clear()
	if zone_entry(_player.world_location()) == &"complete_set":
		if collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION).size() > 1:
			var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION)
			if started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
				announce_fight([])
			_last_aggression_initiations.append(started)
		return _last_aggression_initiations.duplicate()
	_last_aggression_decisions = aggression.resolve_pending(_map.npcs.residents, _player, _combat_allowed())
	for decision: NpcAggressionDecision in _last_aggression_decisions:
		var npc: NpcRuntimeState = _map.npcs.find_resident_npc(decision.npc_id)
		if decision.outcome != NpcAggressionDecision.Outcome.READY or npc == null:
			continue
		if not npc.definition().attacks_on_sight(npc.flags(), _player.state):
			# Paid while its greeting waited: attack.c init() rolled berserk on arrival, not now.
			if not toll_waiting.erase(npc.character_id):
				_go_berserk(npc)
			continue
		if not _toll_due(npc):
			# Its greeting has not come yet: wait while the player stays in reach.
			toll_waiting[npc.character_id] = true
			aggression.enter_player_presence(npc, _player, _combat_allowed(npc))
			continue
		toll_waiting.erase(npc.character_id)
		if npc.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER):
			# combatd.c start_hatred(): one of catch_hunt_msg, then kill_ob(): the player fights back.
			var line: String = CATCH_HUNT[clampi(_world_interaction_random.legacy_random(CATCH_HUNT.size()), 0, CATCH_HUNT.size() - 1)]
			_last_aggression_initiations.append(npc_kills(npc, [tr(line).replace("$N", tr(npc.definition().display_name)).replace("$n", tr("你"))]))
			continue
		# combatd.c start_aggressive() says nothing itself; its kill_ob() warns the player.
		_last_aggression_initiations.append(initiate_lethal_combat(npc.character_id, _player.character_id, []))
	return _last_aggression_initiations.duplicate()


## gangster.c init(): call_out("greeting", 1). The toll-taker's greeting attacks a
## player still in reach when its delay has passed; one who walked on meets nobody.
## Owner (pacing knobs): walking past makes no grudge either (ES2's greeting
## kill_ob()s a passer-by who has left, and it attacks at once next time).
func advance_toll_contacts(delta: float) -> void:
	for npc: NpcRuntimeState in _map.npcs.residents:
		if npc.definition().dealings().toll_attack_delay_ms > 0 and complete_entry_contact(npc.character_id):
			toll_contact_seconds[npc.character_id] = toll_contact_seconds.get(npc.character_id, 0.0) + delta
		else:
			toll_contact_seconds.erase(npc.character_id)


func _toll_due(npc: NpcRuntimeState) -> bool:
	var delay_ms: int = npc.definition().toll_attack_delay_ms(npc.flags(), _player.state)
	return delay_ms <= 0 or toll_contact_seconds.get(npc.character_id, 0.0) * 1000.0 >= delay_ms


## gangster.c kill_passenger() sets attitude "aggressive", and attack.c's hatred
## follows whoever it fights: a toll-taker that fights the player (its aggression, a
## refused toll, the player's 攻击 or 切磋) attacks on sight from then on, mark or not,
## until a reset makes it anew. An object variable, saved with the NPC's memory.
func _note_toll_fights() -> void:
	for npc: NpcRuntimeState in _map.npcs.residents:
		if not npc.definition().dealings().attack_unless_mark.is_empty() and npc.relationship.is_fighting():
			npc.set_flag(NpcDefinition.FLAG_FOUGHT_PLAYER, true)


## attack.c init()'s berserk case for an NPC (Berserk.roll()), then start_berserk().
func _go_berserk(npc: NpcRuntimeState) -> void:
	var outcome: Berserk.Outcome = Berserk.roll(npc.character_state, npc.definition().score, _world_interaction_random)
	if outcome != Berserk.Outcome.NONE:
		_last_aggression_initiations.append(_npc_berserk(npc, outcome, []))


## combatd.c start_berserk(npc, player) once it decided (`outcome`); `lines` come
## first (look.c's 瞪你一眼). It stares at everyone, then attacks to kill
## (kill_ob(): only it kills, the player fights back) or challenges the player to a
## spar (fight_ob()). The fight is the two of them, in a room where aggressive NPCs
## fight together too.
func _npc_berserk(npc: NpcRuntimeState, outcome: Berserk.Outcome, lines: Array[String]) -> CombatSliceInitiationResult:
	var name: String = tr(npc.definition().display_name)
	lines.append(tr("%s用一种异样的眼神扫视著在场的每一个人。") % name)
	if outcome == Berserk.Outcome.STARE:
		_map.hud().append_log_lines(lines)
		return CombatSliceInitiationResult.new()
	var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
	var npc_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, npc.character_id)
	var player_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, _player.character_id)
	var self_rude: String = tr(RankWords.query_self_rude(npc.character_state.gender, npc.age, npc.definition().class_id))
	if outcome == Berserk.Outcome.KILL:
		# TRANSLATORS: combatd.c start_berserk(): {self} is how the NPC calls itself (老子).
		var kill_line: String = tr("{npc}对著你喝道：{self}看你实在很不顺眼，去死吧。").format({"npc": name, "self": self_rude})
		return _berserk_fight(session.combat_encounter_coordinator().start_production(
			npc_binding, player_binding, CombatTriggerCause.Value.NPC_AGGRESSION, true,
		), npc, lines, kill_line, false)
	# TRANSLATORS: combatd.c start_berserk(): {rude} is how the NPC insults the player (臭贼), {self} how it calls itself (老子).
	var fight_line: String = tr("{npc}对著你喝道：喂！{rude}，{self}正想找人打架，陪我玩两手吧！").format({
		"npc": name, "self": self_rude,
		"rude": tr(RankWords.query_rude(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id)),
	})
	return _berserk_fight(session.combat_encounter_coordinator().start_production(
		npc_binding, player_binding, CombatTriggerCause.Value.NPC_SPAR,
	), npc, lines, fight_line, true)


## kill_ob(player) by `npc` outside a fight (juechen/master.c's answer to a traitor's
## 拜师, the 观想虫 a practice conjured): it hunts the player, who only fights back.
## `lines` open the fight. False when no fight could begin.
func npc_kills_player(npc: NpcRuntimeState, lines: Array[String] = []) -> bool:
	return npc_kills(npc, lines).outcome == CombatSliceInitiationResult.Outcome.COMPLETED


## `colored`, when given, is how the log shows `lines` (shinyu.c's HIY say()).
func npc_kills(npc: NpcRuntimeState, lines: Array[String], colored: Array[ColoredLine] = []) -> CombatSliceInitiationResult:
	if npc == null or _player == null or session == null:
		return CombatSliceInitiationResult.new()
	var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
	var npc_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, npc.character_id)
	var player_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, _player.character_id)
	if npc_binding == null or player_binding == null:
		return CombatSliceInitiationResult.new()
	var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_production(
		npc_binding, player_binding, CombatTriggerCause.Value.NPC_AGGRESSION, true,
	)
	if started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		announce_fight(lines, npc.character_id, colored)
	return started


## A berserk's fight began: its shout and the opening (a spar with a blade has the
## armed spar's hint). One that could not begin says no shout: nothing happens.
func _berserk_fight(started: CombatSliceInitiationResult, npc: NpcRuntimeState, lines: Array[String], shout: String, spar: bool) -> CombatSliceInitiationResult:
	if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		_map.hud().append_log_lines(lines)
		return started
	lines.append(shout)
	if spar and _map.selection.spar_is_armed(npc):
		lines.append(tr("刀剑无眼，持兵刃比试可能真的受伤。"))
	announce_fight(lines, npc.character_id)
	return started


## The player's own feature/attack.c init() for each living NPC in `others` (who
## came into the player's place, or into whose place the player came): its berserk
## case, random(bellicosity / 40) > cps, drawn for each; the first that goes over
## gets combatd.c start_berserk() on the next world tick (auto_fight()'s call_out();
## looking_for_trouble lets one through). Not while
## the player fights or lies unconscious. Owner (水烟阁 C): never at the player's own
## master; an NPC whose fight is not ported is not there for it either.
func player_init(others: Array[NpcRuntimeState]) -> void:
	if (
		not _map.gameplay_open() or session == null or _player == null or not _player.exists_in_world
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.relationship.is_fighting()
		or session.combat_encounter_coordinator().has_active_encounter()
	):
		return
	var chosen: NpcRuntimeState = null
	for npc: NpcRuntimeState in others:
		if (
			not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not _map.npc_life.player_shares_zone(npc)
			or npc.definition().dealings().is_fight_deferred() or PlayerKillerReward.is_own_master(_player.state, npc.definition())
		):
			continue
		if Berserk.init_roll(_player.state, _world_interaction_random) and chosen == null:
			chosen = npc
	if chosen != null and pending_player_berserk.is_empty():
		pending_player_berserk = chosen.character_id


## auto_fight()'s call_out(start_berserk): the player's berserk whose roll went over,
## if the player and that NPC are still both here and free (start_berserk()'s checks).
func run_pending_player_berserk() -> void:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(pending_player_berserk)
	pending_player_berserk = &""
	if (
		npc == null or not _map.gameplay_open() or session == null or _player == null or not npc.exists_in_map
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not _map.npc_life.player_shares_zone(npc)
		or _player.relationship.is_fighting() or session.combat_encounter_coordinator().has_active_encounter()
	):
		return
	_player_berserk(npc)


## combatd.c start_berserk(player, npc): nothing in a room where fighting is
## forbidden; the player stares at everyone, calms down when their force beats
## (random(bellicosity) + bellicosity) / 2, else, with bellicosity above their
## score, attacks the NPC to kill (kill_ob(): the NPC only fights back), or
## challenges it to a spar (fight_ob(): it is not asked). Nobody asks the player
## first: the player did not choose it.
func _player_berserk(npc: NpcRuntimeState) -> void:
	if not _combat_allowed(npc):
		return
	_map.hud().describe_arrival()
	var outcome: Berserk.Outcome = Berserk.start(_player.state, _player.state.progression.score, _world_interaction_random)
	var name: String = tr(npc.definition().display_name)
	var lines: Array[String] = [tr("你用一种异样的眼神扫视著在场的每一个人。")]
	if outcome == Berserk.Outcome.STARE:
		_map.hud().append_log_lines(lines)
		_last_player_berserk = CombatSliceInitiationResult.new()
		return
	var self_rude: String = tr(RankWords.query_self_rude(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id))
	var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
	var player_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, _player.character_id)
	var npc_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, npc.character_id)
	if outcome == Berserk.Outcome.KILL:
		# The two of them, in any room: the player kills, the NPC only fights back.
		# TRANSLATORS: combatd.c start_berserk() for the player: {self} is how the player calls themself (老子).
		var kill_line: String = tr("你对著{npc}喝道：{self}看你实在很不顺眼，去死吧。").format({"npc": name, "self": self_rude})
		_last_player_berserk = _berserk_fight(session.combat_encounter_coordinator().start_production(
			player_binding, npc_binding, CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, true,
		), npc, lines, kill_line, false)
		return
	# TRANSLATORS: combatd.c start_berserk() for the player: {rude} is how the player insults the NPC (臭贼), {self} how they call themself (老子).
	var fight_line: String = tr("你对著{npc}喝道：喂！{rude}，{self}正想找人打架，陪我玩两手吧！").format({
		"npc": name, "rude": tr(RankWords.query_rude(npc.character_state.gender, npc.age, npc.definition().class_id)), "self": self_rude,
	})
	_last_player_berserk = _berserk_fight(session.combat_encounter_coordinator().start_production(
		player_binding, npc_binding, CombatTriggerCause.Value.PLAYER_SPAR,
	), npc, lines, fight_line, true)


## cmds/std/look.c on a living NPC here: when random(its bellicosity / 10) beats the
## player's per, it turns to glare and goes berserk at them (auto_fight(),
## start_berserk(): nothing more while it already fights them or fighting is
## forbidden here).
func look_berserk(npc: NpcRuntimeState) -> void:
	if (
		npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player == null
		or not npc.world_location().shares_combat_location(_player.world_location())
		or not Berserk.look_roll(npc.character_state, _player.state.attributes.personality, _world_interaction_random)
	):
		return
	var lines: Array[String] = [tr("%s突然转过头来瞪你一眼。") % tr(npc.definition().display_name)]
	if (
		npc.relationship.has_opponent(_player.character_id) or not _combat_allowed(npc)
		or npc.definition().dealings().is_fight_deferred() or session.combat_encounter_coordinator().has_active_encounter()
	):
		_map.hud().append_log_lines(lines)
		return
	_npc_berserk(npc, Berserk.start(npc.character_state, npc.definition().score, _world_interaction_random), lines)


## The fight the player's last berserk started (or tried to), for tests.
func last_player_berserk() -> CombatSliceInitiationResult:
	return _last_player_berserk


## Owner decision P2A-M: every eligible aggressive enemy in current physical
## contact, plus a manual target, enters one encounter in stable ID order.
func collect_complete_combat_entry(cause: int, requested_target: StringName = &"") -> Array[CombatSliceCharacterBinding]:
	if not _map.gameplay_open() or session == null or session.active_map() != _map:
		return []
	if cause not in [CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatTriggerCause.Value.NPC_AGGRESSION]:
		return []
	var manual: bool = cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK
	if (manual and _map.npcs.find_resident_npc(requested_target) == null) or (not manual and not requested_target.is_empty()):
		return []
	if player_body._player != _player:
		return []
	var ids: Array[StringName] = []
	var fresh_contact: bool = false
	var waiting: Array[StringName] = []
	for npc: NpcRuntimeState in _map.npcs.residents:
		if npc.exists_in_map:
			var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
			if not is_instance_valid(body) or body._npc != npc or _map.npcs.map_characters.find_npc(npc.character_id) != npc:
				return []
		var contact: bool = complete_entry_contact(npc.character_id)
		if not contact:
			complete_set_consumed_contacts.erase(npc.character_id)
		var decision: NpcAggressionDecision = aggression._evaluate(npc, _player, _combat_allowed(npc))
		var on_sight: bool = (
			contact and decision.outcome in [NpcAggressionDecision.Outcome.READY, NpcAggressionDecision.Outcome.NPC_ALREADY_FIGHTING]
			and npc.definition().attacks_on_sight(npc.flags(), _player.state)
		)
		var aggressive: bool = on_sight and _toll_due(npc)
		if on_sight and not aggressive:
			waiting.append(npc.character_id)
		if aggressive or (manual and npc.character_id == requested_target):
			if ids.has(npc.character_id):
				return []
			ids.append(npc.character_id)
			fresh_contact = fresh_contact or (aggressive and not complete_set_consumed_contacts.has(npc.character_id))
	if ids.is_empty() or (not manual and not fresh_contact):
		return []
	# gangster.c: every robber's greeting comes from the same arrival (each init()), so the
	# toll-takers still waiting in reach join the fight that starts here.
	for id: StringName in waiting:
		if not ids.has(id):
			ids.append(id)
	ids.sort_custom(func(first: StringName, second: StringName) -> bool: return String(first) < String(second))
	ids.push_front(_player.character_id)
	var available: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
	var result: Array[CombatSliceCharacterBinding] = []
	for id: StringName in ids:
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(available, id)
		# kill.c: the one the player's 攻击 names may lie unconscious.
		if binding == null or not session.encounter_participant_is_available(id, manual and id == requested_target):
			return []
		result.append(binding)
	return result


## Exact current shapes, not cached Area overlap lists or deferred signal order.
func complete_entry_contact(id: StringName) -> bool:
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(id)
	if not is_instance_valid(body) or not body.is_inside_tree():
		return false
	var area: Area2D = _map.npcs.npc_presence.get(id)
	if not is_instance_valid(area) or not area.monitoring or not area.is_inside_tree():
		return false
	var player_shape: CollisionShape2D = player_body.get_node_or_null("CollisionShape2D")
	if player_shape == null or player_shape.disabled or player_shape.shape == null:
		return false
	for child: Node in area.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			if child.shape.collide(child.global_transform, player_shape.shape, player_shape.global_transform):
				return true
	return false


func consume_complete_entry_contacts(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		if complete_entry_contact(id) and not complete_set_consumed_contacts.has(id):
			complete_set_consumed_contacts.append(id)


func initiate_lethal_combat(initiator_id: StringName, target_id: StringName, lines: Array[String]) -> CombatSliceInitiationResult:
	if not _map.gameplay_open() or session == null:
		return CombatSliceInitiationResult.new()
	var cause: int = CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK if initiator_id == _player.character_id else CombatTriggerCause.Value.NPC_AGGRESSION
	var result: CombatSliceInitiationResult
	if zone_entry(_player.world_location()) == &"complete_set":
		result = session.combat_encounter_coordinator().start_complete_production(cause, target_id if cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK else &"")
	else:
		var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
		result = session.combat_encounter_coordinator().start_production(
			CombatSliceProjectionBuilder.find_binding(participants, initiator_id),
			CombatSliceProjectionBuilder.find_binding(participants, target_id),
			cause,
		)
	if result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		var said: Array[String] = lines.duplicate()
		if cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK:
			said.append_array(_accept_kill(target_id))
		announce_fight(said, target_id if cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK else initiator_id)
	return result


## The attacked NPC's accept_kill() (NpcAcceptKill; owner, 乔阴 A: as its author meant,
## though no mudlib code calls it): its line and exert, the others of its kind here
## join against the player (help_hotel_guard()), then the report and the vendetta marks
## with the native hint. The lines, in order, for the fight's opening.
func _accept_kill(target_id: StringName) -> Array[String]:
	var lines: Array[String] = []
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(target_id)
	var rule: NpcAcceptKill = null if npc == null else npc.definition().dealings().accept_kill
	if rule == null:
		return lines
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	if encounter == null:
		return lines
	var name: String = tr(npc.definition().display_name)
	if not rule.say.is_empty():
		lines.append(tr("{npc}说道：{line}").format({"npc": name, "line": tr(rule.say)}))
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	if not rule.exert.is_empty():
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, target_id)
		if binding != null:
			var context: SpecialContext = CombatSpecialAttackSource.context_for(
				binding, bindings, session.combat_random_source(), session.encounter_skill_effect_registry(),
			)
			if NpcSpecials.run(NpcSpecialAction.new(NpcSpecialAction.Kind.EXERT, &"", rule.exert), context):
				for line: VisionLine in context.lines:
					# An exert's lines: $N is the NPC.
					var text: String = tr(line.template).strip_edges()
					if not line.slots.is_empty():
						var slots: Dictionary = {}
						for key: String in line.slots:
							slots[key] = tr(line.slots[key])
						text = text.format(slots)
					lines.append(text.replace("$N", name))
	var joins: Array[CombatJoin] = []
	if rule.fellows:
		var here: WorldLocationState = npc.world_location()
		for other: NpcRuntimeState in _map.npcs.residents:
			if (
				other == npc or other.definition().definition_id != npc.definition().definition_id
				or other.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not other.exists_in_map
				or not other.world_location().shares_combat_location(here) or other.relationship.is_fighting()
			):
				continue
			if not rule.fellow_say.is_empty():
				lines.append(tr("{npc}说道：{line}").format({"npc": tr(other.definition().display_name), "line": tr(rule.fellow_say)}))
			joins.append(CombatJoin.new(other.character_id, [_player.character_id]))
		if not joins.is_empty():
			coordinator.resolution().admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(joins))
	var marked: bool = false
	if not joins.is_empty() and not rule.report_say.is_empty():
		lines.append(tr("{npc}说道：{line}").format({"npc": name, "line": tr(rule.report_say)}))
		if not rule.report_vendetta.is_empty():
			_player.state.vendetta[rule.report_vendetta] = 1
			marked = true
	if not rule.grudge.is_empty():
		_player.state.vendetta[rule.grudge] = 1
		marked = true
	if marked:
		lines.append(tr(rule.hint))
	return lines


## A fight the player is in has just begun: `lines` (what was said) go to the log,
## then feature/attack.c kill_ob()'s warning, in HIR bright red, from every NPC
## that now fights the player to the death (kill.c's obj->kill_ob(me),
## combatd.c start_aggressive(), annihir.c accept_fight()). The battle log opens
## with the same lines and keeps the warnings pinned while the panel covers the log.
## `first_id`: the NPC whose kill_ob() came first (kill.c's target), when one did.
## `colored` (optional): the same lines in their colours, for the log.
func announce_fight(lines: Array[String], first_id: StringName = &"", colored: Array[ColoredLine] = []) -> void:
	_note_toll_fights()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var encounter: CombatEncounter = coordinator.active_encounter()
	var warnings: Array[String] = []
	if encounter != null:
		for participant: CombatParticipant in encounter.participants():
			var npc: NpcRuntimeState = _map.npcs.find_resident_npc(participant.participant_id)
			if npc != null and participant.binding.relationship.has_lethal_target(_player.character_id):
				var warning: String = tr("看起来%s想杀死你！") % tr(npc.definition().display_name)
				if participant.participant_id == first_id:
					warnings.push_front(warning)
				else:
					warnings.append(warning)
	if not colored.is_empty():
		_map.hud().append_colored_lines(colored)
	elif not lines.is_empty():
		_map.hud().append_log_lines(lines)
	if not warnings.is_empty():
		_map.hud().append_log_lines(warnings, true)
	coordinator.note_opening(lines, warnings)


## combatd.c do_attack(npc, player, the npc's weapon) called straight outside any fight
## (champion.c's accept test): TYPE_REGULAR, as a special file's direct attack, with
## the encounter random source and skill_improved() effects. A kee below zero falls
## only on the heart beat after (player_fall_below_zero()). Null when either cannot
## take part (not here, not conscious, already fighting).
func attack_player_outside_fight(npc: NpcRuntimeState) -> CombatSliceOpportunityResult:
	if (
		npc == null or _player == null or not npc.exists_in_map or not _player.exists_in_world
		or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
		or npc.relationship.is_fighting() or _player.relationship.is_fighting()
	):
		return null
	_map.combat_lifecycle.player_content_resolution = _map.combat_lifecycle.weapon_resolver.resolve(_player, _inventory, _item_index)
	var player_binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_player(
		_player,
		_map.combat_lifecycle.player_content_resolution.content_profile if _map.combat_lifecycle.player_content_resolution.succeeded else null,
	)
	var npc_binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, _map.npcs.npc_content(npc))
	if player_binding == null or npc_binding == null:
		return null
	if _map.combat_lifecycle.post_actions == null:
		_map.combat_lifecycle.post_actions = CombatSlicePostActions.new(_map.combat_lifecycle.run_post_action)
	player_binding.post_actions = _map.combat_lifecycle.post_actions
	npc_binding.post_actions = _map.combat_lifecycle.post_actions
	var participants: Array[CombatSliceCharacterBinding] = [player_binding, npc_binding]
	var result: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_direct_attack(npc_binding, player_binding, participants, _combat_random, _map.combat_lifecycle.effects)
	return null if result.forward_result == null else result
