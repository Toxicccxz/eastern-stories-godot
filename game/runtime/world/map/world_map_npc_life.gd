class_name WorldMapNpcLife
extends RefCounted
## What NPCs do on their own: the heart beat (heal_up, waking), chat and act lines,
## greetings, drinking, wandering (random_move), stealing and a master's later answer to
## 拜师. Code moved from WorldMapController as it was; the map is `_map`.

var _map: WorldMapController
var npc_heartbeat: NpcHeartbeat
var ambience: NpcAmbience
## steal.c between main() and compelete_steal(): {item, sp, dp} by thief.
var pending_steals: Dictionary[StringName, Dictionary] = {}
## query("thief") of each thief: how often it was caught (not saved, as NPCs are made anew).
var _times_caught: Dictionary[StringName, int] = {}
var walker: WorldNpcWalker
## The player's place as the NPCs' init() last saw it; another one is an arrival.
var arrival_zone_id: StringName = &""
## Where the player was before that arrival: the door they came in by (close.c's door).
var came_from_zone_id: StringName = &""

# The map's authorities, read as the controller reads them.
var session: WorldSessionController:
	get: return _map.session
var _initialized: bool:
	get: return _map.is_map_initialized()
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()
var _inventory: InventoryState:
	get: return _map.inventory_state()
var _liquids: LiquidCollection:
	get: return _map.liquid_collection()
var _item_index: WorldItemInstanceIndex:
	get: return _map.item_instance_index()


func _init(controller: WorldMapController) -> void:
	_map = controller


## One step of NPC heart_beat time (NpcHeartbeat); the session decides when it flows.
func advance_npc_heartbeat(delta: float) -> void:
	if not _initialized or session == null:
		return
	if npc_heartbeat == null:
		npc_heartbeat = NpcHeartbeat.new(session.npc_recovery_random_source())
	_map.combat_lifecycle.fall_below_zero()
	_map.corpses.advance_pending_dissolves(delta)
	for npc: NpcRuntimeState in npc_heartbeat.advance(delta, _map.npcs.npc_runtimes()):
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		if body != null:
			body.refresh_runtime_state()
		# combatd.c announce("revive"), heard in the same room.
		if player_hears(npc):
			_map.hud().append_log_lines([tr("%s慢慢睁开眼睛，清醒了过来。") % tr(npc.definition().display_name)])
	# What the NPCs' conditions show their room (drunk.c, slumber_drug.c).
	for character_id: StringName in npc_heartbeat.room_lines:
		var seen: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
		if seen == null or not player_hears(seen):
			continue
		var lines: Array[String] = []
		for template: String in npc_heartbeat.room_lines[character_id]:
			lines.append(tr(template).format({"name": tr(seen.definition().display_name)}))
		_map.hud().append_log_lines(lines)
	# zombie.c's heal_up() does more than heal.
	for character_id: StringName in npc_heartbeat.heal_ups:
		var raised: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
		if raised != null and raised.definition().raising() != null:
			_map.spells.raised_heal_up(raised, npc_heartbeat.heal_ups[character_id])
	_advance_ambience(delta)


## npc.c chat() and random_move(), and greetings, on NPC heart_beat time (NpcAmbience).
func _advance_ambience(delta: float) -> void:
	npc_ambience().set_random(session.npc_ambience_random_source())
	_note_bellicosity()
	_map.hostilities.run_pending_player_berserk()
	# A fight began: the world stands still from here.
	if not _map.gameplay_open():
		return
	_note_player_arrival()
	for character_id: StringName in ambience.due_greetings(delta):
		_greet(_map.npcs.find_resident_npc(character_id))
	for character_id: StringName in ambience.due_calls(delta, NpcAmbience.STEAL):
		_steal_step(_map.npcs.find_resident_npc(character_id))
	for character_id: StringName in ambience.due_calls(delta, NpcAmbience.RECRUIT):
		_answer_apprentice(_map.npcs.find_resident_npc(character_id))
	for character_id: StringName in ambience.due_calls(delta, WorldMapSpells.DISPELL):
		_map.spells.dispell(_map.npcs.find_resident_npc(character_id))
	for beat: int in ambience.due_beats(delta):
		if beat > 0:
			# char.c heart_beat() falls before it chats, on each of several beats too.
			_map.combat_lifecycle.fall_below_zero()
		for npc: NpcRuntimeState in _map.npcs.residents.duplicate():
			if _chats(npc):
				_act(npc, ambience.chat(npc.definition().talk()))
	npc_walker().advance(delta)


## The player kept pushing into a standing NPC (owner, polish, A5): a conscious one that
## is not fighting or walking steps aside within its own zone. One that offers something
## from its body (goods, teaching, quests) keeps its place, so it stays within reach.
func step_aside(body: WorldCharacterBody2D) -> bool:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(body.character_id)
	if (
		npc == null or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
		or npc.relationship.is_fighting() or npc_walker().is_walking(npc.character_id)
	):
		return false
	for service: WorldService in _map.service_nodes:
		if service is NpcService and (service as NpcService).npc == npc:
			return false
	return npc_walker().step_aside(npc.character_id, body, _map.physical_zone(npc.world_location().zone_id), _map.player_body.global_position)


## The NPCs' chat, greetings and call_outs, made on first use (a request may come
## before the first beat).
func npc_ambience() -> NpcAmbience:
	if ambience == null:
		ambience = NpcAmbience.new(session.npc_ambience_random_source())
	return ambience


## The player went to another map (a completed handoff): its NPCs' call_outs (a theft, a
## master's answer) would come due while they are away and find nobody (steal_it(),
## recruit.c's present()), so they go now: the map's time stands still until the player is
## back. A deactivation that is rolled back (a failed handoff or Continue) keeps them.
func player_left() -> void:
	if ambience != null:
		ambience.clear_calls()
	pending_steals.clear()


## A master that answers 拜师 later (taolord.c): call_out("do_recruit", seconds).
func start_apprentice_answer(npc: NpcRuntimeState, seconds: float) -> void:
	npc_ambience().start_call(npc.character_id, seconds, NpcAmbience.RECRUIT)


## Its answer is still to come (find_call_out("do_recruit") != -1).
func apprentice_answer_due(npc: NpcRuntimeState) -> bool:
	return ambience != null and ambience.has_call(npc.character_id, NpcAmbience.RECRUIT)


## do_recruit() when its call_out is due: what the master says and its recruit reach the
## player only before it (recruit.c's present(); nobody hears a say), so nothing changes
## otherwise; one lying there unconscious reads nothing. An unconscious master's command()
## does nothing; a dead one's call_out went with it.
func _answer_apprentice(npc: NpcRuntimeState) -> void:
	if npc == null or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not player_shares_zone(npc):
		return
	if _player.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
		return
	for service: WorldService in _map.service_nodes:
		if service is TeacherService and (service as TeacherService).npc == npc:
			(service as TeacherService).answer_apprentice(_player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE)
			return


func npc_walker() -> WorldNpcWalker:
	if walker == null:
		walker = WorldNpcWalker.new(_map)
	return walker


## Owner (水烟阁 C): the first time the player's bellicosity can boil over (a kill, a
## powerup, whatever raised it), they are told once (Berserk.WARNING).
func _note_bellicosity() -> void:
	if _player != null and Berserk.take_warning(_player.state):
		_map.hud().append_log_lines([tr(Berserk.WARNING)], true)


## The NPCs' init() when the player comes into a place: a greeting call_out.
func _note_player_arrival() -> void:
	var zone_id: StringName = &"" if _player == null or not _player.exists_in_world else _player.world_location().zone_id
	if zone_id == arrival_zone_id:
		return
	var left: StringName = arrival_zone_id
	arrival_zone_id = zone_id
	came_from_zone_id = left
	# go.c calls follow_me() when the player walks out by an exit: into a neighbouring
	# room. Being moved (reincarnation, a relocation) takes nobody along.
	if not left.is_empty() and not zone_id.is_empty() and GameContent.catalog().zones_adjacent(left, zone_id):
		_followers_follow(left, zone_id)
	for npc: NpcRuntimeState in _map.npcs.residents:
		if (
			npc.world_location().zone_id == zone_id and npc.exists_in_map
			and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
			and not npc.relationship.is_fighting()
			and npc.definition().talk().has_greeting()
		):
			ambience.start_greeting(npc.character_id)
	var here: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in _map.npcs.residents:
		if npc.world_location().zone_id == zone_id:
			_consider_stealing(npc)
			here.append(npc)
	_map.hostilities.player_init(here)


## go.c's all_inventory(env)->follow_me(me, dir), on this map (owner, polish, A11): who
## follows the player (team.c set_leader()) and stood, conscious, in the room the
## player left walks after them; the player sees go.c's 走了过来。 where it arrives.
## follow_me() waits a second when random(the leader's move skill) beats its own; it goes
## at once here, drawing nothing (a player with move enabled, 火蝠身法, would sometimes be
## followed a second later in ES2). It follows into a neighbouring room however the player
## got there (go.c also runs valid_leave() for it; no follower has a room that refuses it).
func _followers_follow(left_zone_id: StringName, zone_id: StringName) -> void:
	for npc: NpcRuntimeState in _map.npcs.residents.duplicate():
		if (
			not npc.flags().get(NpcDefinition.FLAG_FOLLOWS_PLAYER, false) or not npc.exists_in_map
			or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting()
			or npc.world_location().zone_id != left_zone_id
		):
			continue
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		var location: WorldLocationState = _map.location_for_zone(zone_id)
		if body == null or location == null:
			continue
		var spot: Vector2 = _map.floor_items.at_feet(location, _map.player_body.global_position)
		npc_walker().cancel(npc.character_id)
		# No way through (a door shut behind the player): it stays behind, as go.c's
		# valid_leave() would keep it.
		if not npc_walker().walk_to(npc.character_id, body, _map.physical_zone(left_zone_id), _map.physical_zone(zone_id), spot):
			continue
		npc.set_world_location(location)
		if player_hears(npc):
			# TRANSLATORS: go.c: someone ({name}) comes into the player's room.
			_map.hud().append_log_lines([tr("{name}走了过来。").format({"name": tr(npc.definition().display_name)})])
		# Its init() for the player and the player's for it come with the others of this
		# room (_note_player_arrival() goes on with it there), once.


## keeper.c and waiter.c greeting(): only if the player is still there (present(),
## which finds one lying unconscious too: what it does is done, its lines go unread);
## the waiter picks one of its lines then (switch(random(3))); a draw past the lines
## (switch(random(4)) with fewer cases) says nothing. d/latemoon's greetings act by
## the player's gender and class (ScriptedAct, WorldMapActs).
func _greet(npc: NpcRuntimeState) -> void:
	if npc == null or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not player_shares_zone(npc):
		return
	var act: ScriptedAct = npc.definition().talk().choose_greeting(_player.state.gender, _player.state.affiliation.class_id, ambience.random().legacy_random)
	if act != null:
		_map.acts.run(act, npc, ambience.random().legacy_random)


## interactive(ob) in the NPC's room: an unconscious player still counts.
func player_shares_zone(npc: NpcRuntimeState) -> bool:
	return (
		_player != null and _player.exists_in_world
		and npc.world_location().map_id == _player.world_location().map_id
		and npc.world_location().zone_id == _player.world_location().zone_id
	)


## What the player reads of an NPC: only in its place, and not while unconscious
## (damage.c unconcious() sets block_msg/all).
func player_hears(npc: NpcRuntimeState) -> bool:
	return player_shares_zone(npc) and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE


## init() of an NPC that comes into the player's place (make_inventory(), move()).
func npc_arrived(npc: NpcRuntimeState) -> void:
	if (
		ambience != null and player_shares_zone(npc)
		and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and npc.definition().talk().has_greeting()
	):
		ambience.start_greeting(npc.character_id)
	if ambience != null and player_shares_zone(npc):
		_consider_stealing(npc)
		_map.hostilities.player_init([npc])


## thief.c init(): a player coming into its place (or it into theirs) is robbed one
## second later when random(kar) < chance_below; a fighting thief always tries.
func _consider_stealing(npc: NpcRuntimeState) -> void:
	var steal: NpcSteal = npc.definition().dealings().steal
	if (
		steal == null or ambience == null or ambience.has_call(npc.character_id, NpcAmbience.STEAL) or pending_steals.has(npc.character_id)
		or not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
	):
		return
	if npc.relationship.is_fighting() or steal.starts(_player.state.attributes.karma, ambience.random()):
		ambience.start_call(npc.character_id, NpcSteal.START_DELAY_SECONDS, NpcAmbience.STEAL)


## steal_it() and steal.c main() one second on; compelete_steal() three seconds after.
func _steal_step(npc: NpcRuntimeState) -> void:
	if npc == null:
		return
	var pending: Dictionary = pending_steals.get(npc.character_id, {})
	pending_steals.erase(npc.character_id)
	if pending.is_empty():
		_start_stealing(npc)
	else:
		_complete_stealing(npc, pending)


## steal_it(): only if the player is still there; steal.c main() picks present(what)
## or a random thing the player carries and fixes the odds.
func _start_stealing(npc: NpcRuntimeState) -> void:
	if not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or not player_shares_zone(npc):
		return
	if GameContent.catalog().zone_forbids_fighting(npc.world_location().zone_id):
		return
	var steal: NpcSteal = npc.definition().dealings().steal
	var item_id: StringName = _player_item_with_alias(steal.what)
	if item_id.is_empty():
		var carried: Array[StringName] = _player_carried_item_ids()
		if carried.is_empty():
			return
		item_id = carried[ambience.random().legacy_random(carried.size())]
	var thief_fighting: bool = npc.relationship.is_fighting()
	var sp: int = NpcSteal.thief_odds(
		npc.character_state.skills.effective_level(&"stealing"), npc.character_state.attributes.karma,
		_times_caught.get(npc.character_id, 0), thief_fighting,
	)
	if thief_fighting:
		npc.busy.start_busy(3)
	var dp: int = NpcSteal.victim_odds(
		_player.state.spirit.current, _inventory.subtree_weight(item_id), _player.relationship.is_fighting(),
		_player.state.equipment.has_weapon_instance(item_id) or _player.armor.is_worn(item_id),
	)
	pending_steals[npc.character_id] = {"item": item_id, "sp": sp, "dp": dp}
	ambience.start_call(npc.character_id, NpcSteal.COMPLETE_DELAY_SECONDS, NpcAmbience.STEAL)


## compelete_steal(): the player must still be there; caught, the two fight (fight_ob).
## Taken, ES2 tells the player nothing; deviation (owner, modern fixes): the player
## reads what is gone, not who took it (one knocked out reads it on waking).
func _complete_stealing(npc: NpcRuntimeState, pending: Dictionary) -> void:
	# A thief killed meanwhile is gone (destructed: no `me` to move anything to).
	if not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not player_shares_zone(npc):
		return
	var item_id: StringName = pending["item"]
	if not _player_carried_item_ids().has(item_id):
		return
	var conscious: bool = _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	var outcome: NpcSteal.Outcome = NpcSteal.resolve(pending["sp"], pending["dp"], conscious, ambience.random())
	match outcome:
		NpcSteal.Outcome.TAKEN:
			# ob->move(me); a thing too heavy for the thief stays (its own notice only)
			# and steal.c returns before its last two draws.
			var item_name: String = tr(_item_content(item_id).display_name)
			if not ItemHandlingService.hand_over(npc, item_id, _map.floor_items.item_authorities()):
				return
			NpcSteal.after_taken(pending["sp"], conscious, npc.character_state.attributes.intelligence, ambience.random())
			# TRANSLATORS: a thief took {item} from the player unseen; the player notices it is gone.
			var noticed: String = tr("你忽然觉得身上一轻，{item}不见了！")
			if not conscious:
				# TRANSLATORS: a thief took {item} from the player lying unconscious; read on waking.
				noticed = tr("你昏迷不醒的时候，身上的{item}被人拿走了！")
			_map.hud().append_log_lines([noticed.format({"item": item_name})], true)
			if _map.hud().inventory_is_open():
				_map.hud().show_inventory(session.player_inventory_rows())
		NpcSteal.Outcome.CAUGHT:
			var lines: Array[String] = [
				tr("你一回头，正好发现{npc}的手正抓著你身上的{item}！").format({
					"npc": tr(npc.definition().display_name), "item": tr(_item_content(item_id).display_name),
				}),
				tr("你喝道：「干什麽！」"),
			]
			_times_caught[npc.character_id] = _times_caught.get(npc.character_id, 0) + 1
			var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
			var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_production(
				CombatSliceProjectionBuilder.find_binding(participants, _player.character_id),
				CombatSliceProjectionBuilder.find_binding(participants, npc.character_id),
				CombatTriggerCause.Value.PLAYER_SPAR,
			)
			if started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
				npc.busy.start_busy(5)
				_map.hostilities.announce_fight(lines)
			else:
				_map.hud().append_log_lines(lines)


## The player's own things (all_inventory(me)), in inventory order.
func _player_carried_item_ids() -> Array[StringName]:
	return _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id))


## present(alias, me): the first of the player's own things answering to `alias`.
func _player_item_with_alias(alias: StringName) -> StringName:
	for item_id: StringName in _player_carried_item_ids():
		var content: ItemContentDefinition = _item_content(item_id)
		if content != null and content.aliases().has(String(alias)):
			return item_id
	return &""


func _item_content(item_id: StringName) -> ItemContentDefinition:
	var item: ItemInstance = _item_index.resolve(item_id)
	return null if item == null else GameContent.catalog().item(item.item_definition_id)


## char.c heart_beat() reaches chat() for a conscious NPC that is neither busy nor
## fighting, and beats while the player is in its place. A walking NPC is still
## making its last move. Deviation: an unconscious NPC says nothing (DECISIONS 4D).
## The player need not be conscious; only what they read is (`_player_hears`).
func _chats(npc: NpcRuntimeState) -> bool:
	return (
		npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and not npc.relationship.is_fighting() and not npc.busy.is_busy()
		and npc.definition().talk().has_chat() and player_shares_zone(npc)
		and not npc_walker().is_walking(npc.character_id)
	)


func _act(npc: NpcRuntimeState, entry: Variant) -> void:
	if entry is String:
		if player_hears(npc):
			_map.hud().append_log_lines([NpcTalk.line(entry)])
	elif entry is ColoredLine:
		if player_hears(npc):
			_map.hud().append_colored_lines([ColoredLine.new(NpcTalk.line(entry.text), entry.color)])
	elif entry is StringName and entry == NpcTalk.RANDOM_MOVE:
		random_move(npc)
	elif entry is NpcDrinkAction:
		_drink(npc, entry)
	elif entry is NpcSpecialAction:
		_special(npc, entry)


## npc.c's chat functions outside a fight (安惜迩's exert powerfade): with no enemy
## a perform or a spell refuses; an exert runs. The player in the NPC's place sees
## what it shows.
func _special(npc: NpcRuntimeState, action: NpcSpecialAction) -> void:
	var content: CombatSliceContentProfile = _map.npcs.npc_content(npc)
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, content)
	if binding == null:
		return
	var context := SpecialContext.new(
		CombatNpcChat.side_of(binding, npc), [], ambience.random().legacy_random, GameContent.catalog(), null,
	)
	if not NpcSpecials.run(action, context) or not player_hears(npc):
		return
	var lines: Array[ColoredLine] = []
	for line: VisionLine in context.lines:
		# Out of a fight only exert lines show: $N is the NPC.
		lines.append(ColoredLine.new(tr(line.template).strip_edges().replace("$N", tr(npc.definition().display_name)), line.color))
	_map.hud().append_colored_lines(lines)


## drunk.c do_drink(): it drinks, drops the emptied container where it stands,
## or asks for more.
func _drink(npc: NpcRuntimeState, action: NpcDrinkAction) -> void:
	var location: WorldLocationState = npc.world_location()
	var drank: NpcDrinkService.Result = NpcDrinkService.drink(npc, action, WorldMapFloorItems.floor_endpoint(location), _inventory, _item_index, _liquids)
	if drank.outcome == NpcDrinkService.Outcome.AUTHORITY_FAILURE:
		push_error("%s could not drink: its carried liquid is inconsistent" % npc.character_id)
		return
	if not drank.dropped_item_id.is_empty():
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		_map.floor_items.add_dropped_item_view(drank.dropped_item_id, location, _map.floor_items.at_feet(location, Vector2.ZERO if body == null else body.global_position))
	if player_hears(npc):
		_map.hud().append_log_lines(drank.lines)


## npc.c random_move() through go.c, within the NPC's range (NpcRandomMove). The
## body walks; its place changes now. False when nothing moved.
func random_move(npc: NpcRuntimeState) -> bool:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	var from_zone_id: StringName = npc.world_location().zone_id
	if spawn == null or ambience == null:
		return false
	var move: NpcRandomMove.Move = NpcRandomMove.choose(GameContent.catalog(), from_zone_id, spawn.zone_id, ambience.random(), _door_closed_between)
	if move == null:
		return false
	var seen: bool = player_hears(npc)
	if not npc_walker().walk_into(npc.character_id, _map.npcs.runtime_body_for_character(npc.character_id), _map.physical_zone(from_zone_id), _map.physical_zone(move.to_zone_id), ambience.random()):
		return false
	npc.set_world_location(_map.location_for_zone(move.to_zone_id))
	if seen:
		_map.hud().append_log_lines([move.leave_line(npc.definition().display_name)])
	# The player's init() for one who walks in.
	if player_shares_zone(npc):
		_map.hostilities.player_init([npc])
	return true


## room.c valid_leave(): a closed door between the two zones stops the move.
func _door_closed_between(from_zone_id: StringName, to_zone_id: StringName) -> bool:
	for door: WorldDoor in _map.doors():
		var definition: DoorDefinition = GameContent.catalog().door(door.door_id)
		if definition != null and definition.zone_ids().has(from_zone_id) and definition.zone_ids().has(to_zone_id) and not door.is_open():
			return true
	return false
