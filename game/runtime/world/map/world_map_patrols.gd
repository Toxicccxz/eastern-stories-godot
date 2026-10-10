class_name WorldMapPatrols
extends RefCounted
## The constables of this map and the court they bring thieves to (d/choyin/npc/yamen_po.c and
## judgeman.c, repaired: owner, DECISIONS 乔阴 A Q1). A constable (NpcPatrol) walks its beat a
## zone each time its chat calls patrol(), wherever the player is (ES2's heart beat stopped away
## from players; the beat needs it). One that meets a player with a caught steal on record
## while it patrols may catch them (NpcArrest): it leads them back along its beat, a zone at a
## time, their own walking refused, and at the beat's start takes them into the court; on the
## way they may bribe it (bribe()) or fight it. In the court the magistrate (NpcSentence) passes
## sentence `after` seconds later and puts them out. The custody is the player's
## (WorldPlayerRuntimeState.led_by, awaiting_sentence): not saved, so Save waits for its end.

## yamen_po.c's `direction` (GO 0, BACK 1), an object variable: saved with the NPC's memory.
const FLAG_BACK: StringName = &"patrol_back"
## The magistrate's call_out("settle_lawsuit", 2, crime) (NpcAmbience kind).
const SENTENCE: StringName = &"sentence"
## do_go()'s line is read at most this often while the player keeps pushing.
const ESCAPE_REPEAT_MS: int = 2000

var _map: WorldMapController
var _last_escape_ms: int = -ESCAPE_REPEAT_MS
## What the last bribe() printed (the 行贿 panel shows a refusal under its rows).
var last_lines: Array[String] = []
## The last fight end hold_player() looked at (a flee frees the one led).
var _seen_completion: StringName = &""

var session: WorldSessionController:
	get: return _map.session
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


## patrol(): one step along `npc`'s beat, turning at either end; the one leading the player
## walks back toward the beat's start with them, and at it takes them in (_deliver()).
func step(npc: NpcRuntimeState) -> void:
	var patrol: NpcPatrol = null if npc == null else npc.definition().dealings().patrol
	if (
		patrol == null or session == null or session.active_map() != _map or not npc.exists_in_map
		or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting()
	):
		return
	if _player != null and _player.led_by == npc.character_id:
		_lead_step(npc, patrol)
		return
	var here: StringName = npc.world_location().zone_id
	var back: bool = npc.has_flag(FLAG_BACK)
	var next: StringName = patrol.next_zone(here, back)
	if next.is_empty():
		back = not back
		_set_back(npc, back)
		next = patrol.next_zone(here, back)
	# Off its beat (BigWay's amulet branch, broken in ES2): its room's reset brings it home.
	if not next.is_empty():
		_walk(npc, here, next)


## yamen_po.c init() for the player, who came into its place or into whose place it came: a
## patrolling one, not fighting, meeting a conscious player with thief on record catches them
## when random(10) < 7.
func meet(npc: NpcRuntimeState) -> void:
	var patrol: NpcPatrol = null if npc == null else npc.definition().dealings().patrol
	if (
		patrol == null or _player == null or not _map.gameplay_open() or not npc.exists_in_map
		or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting()
		or not _map.npc_life.player_shares_zone(npc) or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
		or _player.relationship.is_fighting() or _player.in_custody() or CrimeRecord.thief(_player.state) <= 0
	):
		return
	if patrol.arrest.catches(session.npc_ambience_random_source().legacy_random):
		_catch(npc, patrol.arrest)


## The thief branch of init() and catchyou(): its say (say() left the thief out of it; owner Q1:
## they read it), crime_lv + crime and thief - 1, and they are led; it is selected, so its 行贿
## is at hand, and a native hint tells what can be done.
func _catch(npc: NpcRuntimeState, arrest: NpcArrest) -> void:
	CrimeRecord.add_crime(_player.state, arrest.crime)
	CrimeRecord.add_thief(_player.state, -1)
	_player.led_by = npc.character_id
	_set_back(npc, true)
	var name: String = tr(npc.definition().display_name)
	_map.hud().append_colored_lines([
		ColoredLine.new(tr(arrest.catch_say).format({"name": tr("你")}).strip_edges(), ColoredLine.HIR),
		# TRANSLATORS: native hint after a constable ({npc}) catches the player for stealing (yamen_po.c catchyou()).
		ColoredLine.new(tr("（{npc}要把你押到县衙受审：被押着走不开；可以向他行贿，也可以拒捕跟他动手。）").format({"npc": name})),
	])
	_map.select_npc(npc.character_id)


## A step of the one leading the player: they must still be with it (one who fled the fight
## got away; one lying unconscious waits for it). At the beat's start it takes them in.
func _lead_step(npc: NpcRuntimeState, patrol: NpcPatrol) -> void:
	if _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.relationship.is_fighting():
		return
	# Still being walked after it (they started farther off): it waits for them.
	if _map.npc_life.npc_walker().is_walking(_player.character_id):
		return
	if not _map.npc_life.player_shares_zone(npc):
		release(npc)
		return
	var here: StringName = npc.world_location().zone_id
	var next: StringName = patrol.next_zone(here, true)
	if next.is_empty():
		_deliver(npc, patrol.arrest)
		return
	if not _walk(npc, here, next):
		return
	# set_leader(): the player follows it, walked after it to where it stops.
	var walker: WorldNpcWalker = _map.npc_life.npc_walker()
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
	var location: WorldLocationState = _map.location_for_zone(next)
	var spot: Vector2 = _map.floor_items.at_feet(location, walker.rest_position(npc.character_id, body))
	if not walker.walk_to(_player.character_id, _map.player_body, _map.physical_zone(here), _map.physical_zone(next), spot):
		_map.place_player(next, spot)


## catchyou()'s end (BigWay's 0): into the court with the thief, deliver_say, and back to its
## beat. A handoff that cannot happen now (the world frozen) is tried at its next step.
func _deliver(npc: NpcRuntimeState, arrest: NpcArrest) -> void:
	var court: ZoneDefinition = GameContent.catalog().zone(arrest.court_zone_id)
	if court == null or session == null:
		return
	_map.npc_life.npc_walker().cancel(_player.character_id)
	if not session.handoff_to(court.map_id, court.zone_id, court.combat_location_id, arrest.court_point_id).succeeded():
		return
	_player.led_by = &""
	_player.awaiting_sentence = true
	_set_back(npc, false)
	var arrived: WorldMapController = session.active_map() as WorldMapController
	if arrived == null:
		return
	arrived.hud().describe_arrival()
	arrived.hud().append_log_lines([tr(arrest.deliver_say).strip_edges()])
	arrived.patrols.await_sentence()


## The court's magistrate takes the player delivered here (judgeman.c: call_out("settle_lawsuit",
## 2, crime)). With none to pass sentence (killed), they are simply free.
func await_sentence() -> void:
	for npc: NpcRuntimeState in _map.npcs.residents:
		var sentence: NpcSentence = npc.definition().dealings().sentence
		if sentence != null and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			_map.npc_life.npc_ambience().start_call(npc.character_id, sentence.after, SENTENCE)
			return
	_player.awaiting_sentence = false


## settle_lawsuit(): the boards by crime_lv (NpcSentence.beat()), the lines, the crime cleared
## (owner Q1), out at the 衙门口; knocked out by the beating they wake there.
func pass_sentence(judge: NpcRuntimeState) -> void:
	if judge == null or _player == null or not _player.awaiting_sentence:
		return
	var sentence: NpcSentence = judge.definition().dealings().sentence
	if sentence == null:
		return
	var state: CharacterState = _player.state
	var level: int = CrimeRecord.crime(state)
	var you: String = tr("你")
	var lines: Array[ColoredLine] = []
	var fainted: bool = false
	if level > 0:
		lines.append(ColoredLine.new(tr(sentence.beat_line).replace("$N", you).format({"boards": ChineseNumber.of(level * 10)}), ColoredLine.HIR))
		fainted = NpcSentence.beat(state, level).fainted
		if fainted:
			for index: int in range(sentence.faint_lines.size()):
				lines.append(ColoredLine.new(tr(sentence.faint_lines[index]).replace("$N", you), ColoredLine.HIR if index == 0 else ColoredLine.PLAIN))
		lines.append(ColoredLine.new(tr(sentence.warn_line).replace("$N", tr(judge.definition().display_name)).replace("$n", you), ColoredLine.HIR))
		CrimeRecord.clear_crime(state)
	else:
		lines.append(ColoredLine.new(tr(sentence.sorry_line)))
	_map.hud().append_colored_lines(lines)
	_player.awaiting_sentence = false
	var out: ZoneDefinition = GameContent.catalog().zone(sentence.out_zone_id)
	var here: WorldMapController = _map
	if out != null and session != null and session.handoff_to(out.map_id, out.zone_id, out.combat_location_id, sentence.out_point_id).succeeded():
		here = session.active_map() as WorldMapController
		here.hud().describe_arrival()
	# heart_beat(): a value below 0 knocks out; unconcious() for one the strokes left at 1.
	if fainted:
		state.fall_unconscious()
	here.player_fall_below_zero()


## The constable leading the player, both awake (accept_bribery()'s being_caught; it is with the
## one it leads, set_leader(), though a step ahead of them while they are walked after it).
func can_bribe(npc: NpcRuntimeState) -> bool:
	return (
		npc != null and _player != null and _player.led_by == npc.character_id and _map.gameplay_open()
		and npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)


## accept_bribery(): `amount` of the money stack `item_id` the player carries, worth base_value
## * amount. Enough (bribe_at) frees them: its lines, the money its, crime_lv - pardon, and it
## goes back to its beat; less is refused (its line, crime_lv + bribe_crime). False when no
## bribe could be offered.
func bribe(item_id: StringName, amount: int) -> bool:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(&"" if _player == null else _player.led_by)
	if not can_bribe(npc) or amount < 1:
		return false
	var arrest: NpcArrest = npc.definition().dealings().patrol.arrest
	var item: ItemInstance = _map.item_instance_index().resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var held: int = _map.stack_collection().stack_state(item_id).amount if _map.stack_collection().has_stack(item_id) else 0
	if content == null or content.currency_base_value <= 0 or amount > held:
		return false
	var lines: Array[String] = []
	last_lines = lines
	if arrest.takes_bribe(content.currency_base_value * amount):
		var npc_owner := ItemLifecycleOwnerContext.new(npc.character_id, npc.character_state.equipment, npc.armor)
		# The money becomes its (new(base_name(money_ob)), set_amount(); the player's stack less).
		if ItemHandlingService.npc_hands_over(item_id, amount, npc_owner, npc.maximum_encumbrance, _map.floor_items.item_authorities()).is_empty():
			return false
		for line: String in arrest.taken_lines:
			lines.append(tr(line))
		CrimeRecord.add_crime(_player.state, -arrest.pardon)
		_free()
		_set_back(npc, false)
	else:
		lines.append(tr(arrest.refused_line))
		CrimeRecord.add_crime(_player.state, arrest.bribe_crime)
	_map.hud().append_log_lines(lines)
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return true


## yamen_po.c die(): its killer gets crime_lv + killed_crime (and being_caught deleted); the one
## it led is free either way.
func died(victim: NpcRuntimeState, killed_by_player: bool) -> void:
	var patrol: NpcPatrol = null if victim == null else victim.definition().dealings().patrol
	if patrol == null or _player == null:
		return
	if killed_by_player:
		CrimeRecord.add_crime(_player.state, patrol.arrest.killed_crime)
	if _player.led_by == victim.character_id:
		_free()


## The player went to another map (a completed handoff): whoever led them here is left behind
## (go.c's set_leader() holds only in one room), and a court here sentences nobody it no longer
## holds. The delivery's own handoff sets the sentence anew after this.
func player_left() -> void:
	if _player == null:
		return
	if not _player.led_by.is_empty() and _map.npcs.find_resident_npc(_player.led_by) != null:
		_free()
	_player.awaiting_sentence = false
	_map.player_body.held = false


## The one leading the player let go of them (they got away from it).
func release(npc: NpcRuntimeState) -> void:
	if _player != null and npc != null and _player.led_by == npc.character_id:
		_free()


## The custody's end: no leader, and no walk after it left to finish.
func _free() -> void:
	_player.led_by = &""
	_map.npc_life.npc_walker().cancel(_player.character_id)


## Every physics frame: the player in custody does not walk (catchyou()'s set_leader()); one
## led who pushes to go reads do_go()'s line now and then.
func hold_player() -> void:
	var body: WorldCharacterBody2D = _map.player_body
	if body == null or _player == null:
		return
	# A leader gone or knocked out holds nobody (ES2 left them stuck behind its do_go()).
	if not _player.led_by.is_empty():
		var leader: NpcRuntimeState = _map.npcs.find_resident_npc(_player.led_by)
		if leader == null or not leader.exists_in_map or leader.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			_free()
	# A fight the player fled: go.c's do_flee() took them out of the room, away from the one
	# leading them (its do_go() blocks only the go command).
	var done: CombatEncounterCompletionResult = null if session == null else session.combat_encounter_coordinator().last_completion()
	if done != null and done.encounter_id != _seen_completion:
		_seen_completion = done.encounter_id
		if done.terminal_result != null and done.terminal_result.kind == CombatEncounterResultKind.Value.FLED and not _player.led_by.is_empty():
			_free()
	body.held = _player.in_custody()
	if not body.held or _player.led_by.is_empty() or not body.movement_input_is_pressed():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_escape_ms < ESCAPE_REPEAT_MS:
		return
	_last_escape_ms = now
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(_player.led_by)
	var patrol: NpcPatrol = null if npc == null else npc.definition().dealings().patrol
	if patrol != null:
		_map.hud().append_log_lines([tr(patrol.arrest.escape_line)])


## The beat keeps its constables: a room's reset does not send one home that is on it (or
## leading someone).
func keeps_out(npc: NpcRuntimeState) -> bool:
	var patrol: NpcPatrol = npc.definition().dealings().patrol
	return patrol != null and (patrol.route.has(npc.world_location().zone_id) or (_player != null and _player.led_by == npc.character_id))


## mygo(dir): the body walks into the next zone; go.c's lines where the player sees them, and
## the init()s of one who walks into the player's place.
func _walk(npc: NpcRuntimeState, from_zone_id: StringName, to_zone_id: StringName) -> bool:
	var seen: bool = _map.npc_life.player_hears(npc)
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
	if not _map.npc_life.npc_walker().walk_into(npc.character_id, body, _map.physical_zone(from_zone_id), _map.physical_zone(to_zone_id), session.npc_ambience_random_source()):
		return false
	npc.set_world_location(_map.location_for_zone(to_zone_id))
	var move: NpcRandomMove.Move = NpcRandomMove.toward(GameContent.catalog(), from_zone_id, to_zone_id)
	if seen and move != null and not (_player != null and _player.led_by == npc.character_id):
		_map.hud().append_log_lines([move.leave_line(npc.definition().display_name)])
	if _map.npc_life.player_hears(npc) and not (_player != null and _player.led_by == npc.character_id):
		# TRANSLATORS: go.c: someone ({name}) comes into the player's room.
		_map.hud().append_log_lines([tr("{name}走了过来。").format({"name": tr(npc.definition().display_name)})])
	if _map.npc_life.player_shares_zone(npc):
		_map.npc_life.npc_walked_in(npc)
	return true


func _set_back(npc: NpcRuntimeState, back: bool) -> void:
	if back:
		npc.set_flag(FLAG_BACK, true)
	else:
		npc.clear_flag(FLAG_BACK)
