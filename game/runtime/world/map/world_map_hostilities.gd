class_name WorldMapHostilities
extends RefCounted
## How fights start on this map: presence and the aggression queue, toll-takers, the
## gang that falls on the player together (DECISIONS「进门一起上」), berserk (an NPC's and
## the player's), the opening lines and the lethal start. The map is `_map`.

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
## NPCs that fought the player since the player came into their zone (DECISIONS「进门一起上」):
## they start no fight until the player has left their zone (ES2: init() runs on coming
## into the room); a fight someone fresh starts takes them along.
var spent: Dictionary[StringName, bool] = {}
## The gang's NPC that noticed the player first (the nearest of the fresh ones in reach):
## its kill_ob() warning comes first. Set by collect_complete_combat_entry().
var gang_noticer: StringName = &""
## The fresh ones in reach the last collection found (`gang_fresh`), and those this tick's
## start holds as noticed while the queue it read is resolved (`_noticed`).
var gang_fresh: Array[StringName] = []
var _noticed: Array[StringName] = []
## The gang's alert beat (pacing hostile_alert_ms; DECISIONS「进门一起上」): the zone it
## noticed the player in, its members, the seconds left, and the lines its shout drew
## (a hunter's catch_hunt_msg, not said again when the fight opens). Not saved.
var _alert_zone: StringName = &""
var _alert_members: Array[StringName] = []
var _alert_left: float = 0.0
var _alert_drawn: Dictionary[StringName, String] = {}
## Seconds each toll-taker (NpcDealings.toll_attack_delay_ms) has been touching the
## player without a break; its greeting attacks once that reaches the delay.
var toll_contact_seconds: Dictionary[StringName, float] = {}
## Toll-takers that shouted at the player since they came into its place (once a visit).
var toll_shouted: Dictionary[StringName, bool] = {}
## Indoors (ZoneDefinition.indoors) the NPCs in the player's room: each arrival there, the
## player's or the NPC's, is one presence (refresh_room_presence()).
var room_present: Dictionary[StringName, bool] = {}

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


## Whether an NPC notices by its room: it stands indoors (a building's room, a cave, a
## dungeon), where ES2's init() met whoever was in the room; outdoors its presence circle
## stands in for the room (DECISIONS「室内察觉」).
static func notices_room(npc: NpcRuntimeState) -> bool:
	var zone: ZoneDefinition = null if npc == null else GameContent.catalog().zone(npc.world_location().zone_id)
	return zone != null and zone.indoors


## Whether an NPC that notices by its room shares it with the player now.
func shares_room(npc: NpcRuntimeState) -> bool:
	return (
		npc != null and npc.exists_in_map and _player != null
		and _player.world_location().map_id == map and npc.world_location().zone_id == _player.world_location().zone_id
	)


## Indoors, presence is the room: the NPCs that came to share it with the player since the
## last look enter presence (queued for their berserk roll), those that no longer do leave it.
## Run each world tick, so the player's arrival (walking in, a door, stairs, a handoff) and
## an NPC's (wandering in, called over) count alike.
func refresh_room_presence() -> void:
	for npc: NpcRuntimeState in _map.npcs.residents:
		var id: StringName = npc.character_id
		var here: bool = notices_room(npc) and shares_room(npc)
		if here and not room_present.has(id):
			room_present[id] = true
			aggression.enter_player_presence(npc, _player, _combat_allowed(npc))
		elif not here and room_present.erase(id):
			aggression.leave_player_presence(id)


## Those that fought the player and are no longer in the player's zone (the player left, or
## they walked out) may start a fight again: as ES2's init() on coming into the room.
func forget_spent() -> void:
	var location: WorldLocationState = null if _player == null else _player.world_location()
	for id: StringName in spent.keys():
		var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
		if (
			npc == null or not npc.exists_in_map or location == null or location.map_id != map
			or not npc.world_location().shares_combat_location(location)
		):
			spent.erase(id)


## A fight is over (its encounter still names who was in it): indoors the NPCs in the
## player's room that took no part were never let at the player (the fight's start
## dropped their turn): they notice the player anew. Those that fought are `spent`: they
## wait for the player to leave their zone and come back (a flight stands where it was:
## DECISIONS「室内察觉」「进门一起上」).
func after_fight() -> void:
	var encounter: CombatEncounter = null if session == null else session.combat_encounter_coordinator().active_encounter()
	if encounter == null:
		return
	for id: StringName in room_present.keys():
		if encounter.participant_for(id) == null:
			room_present.erase(id)
	for participant: CombatParticipant in encounter.participants():
		var npc: NpcRuntimeState = _map.npcs.find_resident_npc(participant.participant_id)
		if npc == null:
			continue
		spent[participant.participant_id] = true
		# One spared with `spared.leave` (NpcHooks) flees as the fight ends: gone for good.
		if npc.has_flag(NpcDefinition.FLAG_LEAVES_WHEN_FREE) and npc.exists_in_map:
			var hooks: NpcHooks = npc.definition().hooks()
			if hooks != null and not hooks.spared_line.is_empty() and _map.hud() != null:
				_map.hud().append_after_fight([ColoredLine.new(tr(hooks.spared_line), ColoredLine.PLAIN)])
			_map.npcs.leave_for_good(npc)


## An NPC no longer on this map: it noticed nobody here.
func forget_npc(id: StringName) -> void:
	room_present.erase(id)


## Outdoors the circle queues the NPC's berserk roll; the gang polls exact contact
## (collect_complete_combat_entry()). Indoors the room is the presence
## (refresh_room_presence()), not the circle.
func on_presence_entered(body: Node2D, character_id: StringName) -> void:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
	if _map.gameplay_open() and body == player_body and npc != null and not notices_room(npc):
		aggression.enter_player_presence(npc, _player, _combat_allowed(npc))


func on_presence_exited(body: Node2D, character_id: StringName) -> void:
	if notices_room(_map.npcs.find_resident_npc(character_id)):
		return
	if _map.gameplay_open() and body == player_body:
		aggression.leave_player_presence(character_id)


func aggression_adapter() -> NpcAggressionAdapter:
	return aggression


func last_aggression_decisions() -> Array[NpcAggressionDecision]:
	return _last_aggression_decisions.duplicate()


func last_aggression_initiations() -> Array[CombatSliceInitiationResult]:
	return _last_aggression_initiations.duplicate()


## Each world tick: the gang falls on the player when one of it is fresh in reach
## (collect_complete_combat_entry()), then the queued NPCs that only may go berserk roll
## (attack.c init()'s last case; those that attack on sight are the gang's).
func process_pending_aggression() -> Array[CombatSliceInitiationResult]:
	if not _map.gameplay_open() or session == null:
		return []
	var gang: Array[CombatSliceCharacterBinding] = collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION)
	var queued: bool = aggression.pending_count() > 0
	if gang.size() < 2 and not queued:
		return []
	_last_aggression_initiations.clear()
	# The room's description first, then whoever falls on the player in it (as
	# _player_berserk()): indoors one may be noticed the moment one comes in.
	if _map.hud() != null:
		_map.hud().describe_arrival()
	# Who noticed the player stays noticed for the start, the queue being read now.
	_noticed = gang_fresh.duplicate()
	if queued:
		_last_aggression_decisions = aggression.resolve_pending(_map.npcs.residents, _player, _combat_allowed())
	elif gang.size() > 1:
		_last_aggression_decisions = []
	# The gang's own decisions too (in reach by the exact shapes before its circle reported).
	for binding: CombatSliceCharacterBinding in gang.slice(1):
		if not _last_aggression_decisions.any(func(decision: NpcAggressionDecision) -> bool: return decision.npc_id == binding.character_id):
			var npc: NpcRuntimeState = _map.npcs.find_resident_npc(binding.character_id)
			_last_aggression_decisions.append(aggression._evaluate(npc, _player, _combat_allowed(npc)))
	if gang.size() > 1 and _alert_zone.is_empty():
		if _alert_beat_for(gang_noticer) > 0.0:
			_begin_alert(gang)
		else:
			_last_aggression_initiations.append(_gang_attacks(gang))
	_noticed.clear()
	# A fight began this tick, or the gang's falls on the player in a moment: the berserk rolls
	# wait for it to end (after_fight() lets the room notice the player anew), no stare drawn
	# into its opening, no fight of two before it.
	if queued and _alert_zone.is_empty() and not session.combat_encounter_coordinator().has_active_encounter():
		for decision: NpcAggressionDecision in _last_aggression_decisions:
			var npc: NpcRuntimeState = _map.npcs.find_resident_npc(decision.npc_id)
			if decision.outcome == NpcAggressionDecision.Outcome.READY and npc != null and not npc.definition().attacks_on_sight(npc.flags(), _player.state, _parley()):
				_go_berserk(npc)
	return _last_aggression_initiations.duplicate()


## The gang's fight (`gang`: the player, then the NPCs): each one's own init() case at
## once (combatd.c start_hatred(): one of catch_hunt_msg and a kill the player only fights
## back; start_vendetta() and start_aggressive() say nothing, their kill_ob() warns). A gang
## of one is the pair fight it always was: it first, then the player.
func _gang_attacks(gang: Array[CombatSliceCharacterBinding], drawn: Dictionary[StringName, String] = {}) -> CombatSliceInitiationResult:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var noticer: StringName = gang_noticer
	var started: CombatSliceInitiationResult = (
		coordinator.start_production(gang[1], gang[0], CombatTriggerCause.Value.NPC_AGGRESSION, kills_one_way(gang[1].character_id)) if gang.size() == 2
		else coordinator.start_complete_production(CombatTriggerCause.Value.NPC_AGGRESSION)
	)
	if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		return started
	# Drawn once the fight is on (a start refused is tried again next tick, drawing nothing).
	var lines: Array[String] = []
	for binding: CombatSliceCharacterBinding in gang.slice(1):
		var npc: NpcRuntimeState = _map.npcs.find_resident_npc(binding.character_id)
		# A hunter that shouted it in the alert beat said it already.
		if npc != null and npc.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER) and not drawn.has(binding.character_id):
			lines.append(catch_hunt_line(npc))
	announce_fight(lines, noticer)
	return started


## The alert beat before the gang falls on the player, in seconds: pacing's (0 in ES2,
## combatd.c auto_fight()'s call_out(0)); none after a toll-taker's greeting, whose shout
## and wait came before (DECISIONS「响应性」).
func _alert_beat_for(noticer_id: StringName) -> float:
	var noticer: NpcRuntimeState = _map.npcs.find_resident_npc(noticer_id)
	if noticer == null or _player == null or noticer.definition().toll_attack_delay_ms(noticer.flags(), _player.state, _parley()) > 0:
		return 0.0
	return GameContent.catalog().pacing().hostile_alert_seconds


## Deviation (DECISIONS「进门一起上」): the gang's first to notice the player shouts, a red ！
## over its head, and the others turn to the player; they fall on them when the beat is
## over, unless the player has left the place (ES2's start_*(): not in the same room).
func _begin_alert(gang: Array[CombatSliceCharacterBinding]) -> void:
	_alert_zone = _player.world_location().zone_id
	_alert_left = GameContent.catalog().pacing().hostile_alert_seconds
	_alert_members.clear()
	_alert_drawn.clear()
	var at: Vector2 = player_body.global_position
	for binding: CombatSliceCharacterBinding in gang.slice(1):
		_alert_members.append(binding.character_id)
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(binding.character_id)
		if body != null:
			body.face_toward(at)
			body.set_name_alert(true)
	var noticer: NpcRuntimeState = _map.npcs.find_resident_npc(gang_noticer)
	var noticer_body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(gang_noticer)
	if noticer_body != null:
		noticer_body.set_alert_mark(true)
	if noticer != null:
		_alert_shout(noticer)


## What the gang's first to notice the player shouts: a hunter's catch_hunt_msg
## (start_hatred()), else one of its own ES2 fight lines that is speech, else a plain native
## line; a beast says nothing (owner, A6 Q3).
func _alert_shout(npc: NpcRuntimeState) -> void:
	var hud: SharedGameplayUI = _map.hud()
	var name: String = tr(npc.definition().display_name)
	var text: String = ""
	if npc.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER):
		text = catch_hunt_line(npc)
		_alert_drawn[npc.character_id] = text
	else:
		var speech: Array[String] = []
		for entry: Variant in npc.definition().talk().combat_chat_entries():
			var line: String = (entry as ColoredLine).text if entry is ColoredLine else String(entry) if entry is String else ""
			if line.contains("道："):
				speech.append(NpcTalk.line(line))
		if not speech.is_empty():
			text = speech[clampi(_world_interaction_random.legacy_random(speech.size()), 0, speech.size() - 1)]
		elif npc.definition().race_id == &"beast":
			if hud != null:
				# TRANSLATORS: native (A6): a beast of the gang notices the player (it says nothing).
				hud.append_log_lines([tr("{npc}发现了你！").format({"npc": name})], true)
			return
		else:
			# TRANSLATORS: native (A6): the gang's first to notice the player, who has no ES2 fight line.
			text = tr("{npc}发现了你，大喝一声！").format({"npc": name})
	if hud != null:
		hud.npc_says(npc, [ColoredLine.new(text, ColoredLine.HIR)], [text], true)


## The beat runs on world time (the menu holds it): the player who leaves the place, or
## can no longer be fallen on, escapes it; when it is over the gang there falls on them,
## everyone who attacks on sight there now (one who came in meanwhile too).
func advance_alert(delta: float) -> void:
	if _alert_zone.is_empty():
		return
	if (
		not _map.gameplay_open() or session == null or _player == null or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
		or _player.world_location().map_id != map or _player.world_location().zone_id != _alert_zone
	):
		clear_alert()
		return
	_alert_left -= delta
	if _alert_left > 0.0:
		return
	_noticed = _alert_members.duplicate()
	var gang: Array[CombatSliceCharacterBinding] = collect_complete_combat_entry(CombatTriggerCause.Value.NPC_AGGRESSION)
	if gang.size() < 2:
		# Nobody of it left to fall on the player.
		_noticed.clear()
		clear_alert()
		return
	_last_aggression_initiations.clear()
	var started: CombatSliceInitiationResult = _gang_attacks(gang, _alert_drawn.duplicate())
	_last_aggression_initiations.append(started)
	_noticed.clear()
	# The fight's start took the marks off (freeze_world_gameplay()); one refused is tried
	# again next tick, the beat over and nothing said again.
	if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		_alert_left = 0.0


## The beat is over or gone: the marks come off.
func clear_alert() -> void:
	for id: StringName in _alert_members:
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(id)
		if body != null and is_instance_valid(body):
			body.set_alert_mark(false)
			body.set_name_alert(false)
	_alert_zone = &""
	_alert_members.clear()
	_alert_drawn.clear()
	_alert_left = 0.0


## Whether `id` is of a gang in its alert beat (its name in the alert red).
func alerted(id: StringName) -> bool:
	return _alert_members.has(id)


## Seconds left of the alert beat (0 when none runs).
func alert_seconds_left() -> float:
	return _alert_left if not _alert_zone.is_empty() else 0.0


## combatd.c start_hatred()'s message_vision(): one of catch_hunt_msg, `npc` the hunter.
func catch_hunt_line(npc: NpcRuntimeState) -> String:
	var line: String = CATCH_HUNT[clampi(_world_interaction_random.legacy_random(CATCH_HUNT.size()), 0, CATCH_HUNT.size() - 1)]
	return tr(line).replace("$N", tr(npc.definition().display_name)).replace("$n", tr("你"))


## gangster.c init(): call_out("greeting", 1). The toll-taker's greeting attacks a
## player still in reach when its delay has passed; one who walked on meets nobody.
## Owner (pacing knobs): walking past makes no grudge either (ES2's greeting
## kill_ob()s a passer-by who has left, and it attacks at once next time).
## Its seconds count while its greeting would come (it stands free and the player owes it):
## they start with its shout (DECISIONS「响应性」), so the shout always comes the whole delay
## before the attack.
func advance_toll_contacts(delta: float) -> void:
	for npc: NpcRuntimeState in _map.npcs.residents:
		if npc.definition().dealings().toll_attack_delay_ms > 0 and complete_entry_contact(npc.character_id) and _toll_applies(npc):
			if not toll_contact_seconds.has(npc.character_id) and not toll_shouted.has(npc.character_id):
				toll_shouted[npc.character_id] = true
				_shout_toll(npc)
			toll_contact_seconds[npc.character_id] = toll_contact_seconds.get(npc.character_id, 0.0) + delta
		else:
			toll_contact_seconds.erase(npc.character_id)
		# Once a visit: stepping back and forth at the edge of its reach is not a new arrival.
		if toll_shouted.has(npc.character_id) and (_player == null or _player.world_location().zone_id != npc.world_location().zone_id):
			toll_shouted.erase(npc.character_id)
		if npc.definition().dealings().toll_attack_delay_ms > 0:
			var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
			if body != null:
				body.set_name_alert(toll_pending(npc) or alerted(npc.character_id))


## The toll-taker in reach will attack the player once its delay has passed: the HUD marks it.
func toll_pending(npc: NpcRuntimeState) -> bool:
	return npc != null and toll_contact_seconds.has(npc.character_id) and _toll_applies(npc)


## Its greeting would attack the player: it stands free, they have not paid, it has not
## fought them (then it attacks at once, no greeting to wait for).
func _toll_applies(npc: NpcRuntimeState) -> bool:
	return (
		_player != null and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not npc.relationship.is_fighting()
		and npc.definition().attacks_on_sight(npc.flags(), _player.state, _parley(), _ignored(npc))
		and npc.definition().toll_attack_delay_ms(npc.flags(), _player.state, _parley()) > 0
	)


## Deviation (DECISIONS「响应性」): gangster.c's greeting attacks without a word, its 买路财
## line only a 1% chat; here it shouts that line the moment a passer-by who owes the toll
## comes into reach, so its wait is seen.
func _shout_toll(npc: NpcRuntimeState) -> void:
	var index: int = npc.definition().dealings().toll_shout
	var entries: Array = npc.definition().talk().chat_entries()
	if index < 0 or index >= entries.size() or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return
	var entry: Variant = entries[index]
	if not (entry is String or entry is ColoredLine):
		return
	# A warning: in the alert red, whatever colour the chat line has.
	var text: String = (entry as ColoredLine).text if entry is ColoredLine else String(entry)
	# The ridge's description first, then what is shouted on it (as _player_berserk()).
	_map.hud().describe_arrival()
	_map.hud().npc_says(npc, [ColoredLine.new(NpcTalk.line(text), ColoredLine.HIR)], [NpcTalk.line(text)], true)


func _toll_due(npc: NpcRuntimeState) -> bool:
	var delay_ms: int = npc.definition().toll_attack_delay_ms(npc.flags(), _player.state, _parley())
	return delay_ms <= 0 or toll_contact_seconds.get(npc.character_id, 0.0) * 1000.0 >= delay_ms


## Whether the story's parley holds (DECISIONS「老松寨的三条路」; 经典: off).
static func _parley() -> bool:
	return GameContent.catalog().pacing().story_parley


## Native (逆灵宫 A; DECISIONS「逆灵宫 A」): whether `npc` takes the player for one of its own now
## (its dealings' `ignores_when`: the 黑冠 on their head, a mark they bear) and so does not
## fall on them; read against the player's state, what they carry and wear, where they stand.
func _ignored(npc: NpcRuntimeState) -> bool:
	var condition: JournalEntryDefinition = npc.definition().dealings().ignores_when
	if condition == null or _player == null or session == null:
		return false
	# An ES2 NPC's story leniency (ignores_with_parley) is the modern pace's: 经典 keeps it ES2's.
	if npc.definition().dealings().ignores_with_parley and not GameContent.catalog().pacing().story_parley:
		return false
	var location: WorldLocationState = _player.world_location()
	return JournalLog.holds(condition, _player.state, _player.temp_marks, session.player_held_item_ids(), &"" if location == null else location.zone_id, session.player_worn_item_ids(), session.day_phase_id())


## gangster.c kill_passenger() sets attitude "aggressive", and attack.c's hatred
## follows whoever it fights: a toll-taker that fights the player (its aggression, a
## refused toll, the player's 攻击 or 切磋) attacks on sight from then on, mark or not,
## until a reset makes it anew. An object variable, saved with the NPC's memory.
func _note_toll_fights() -> void:
	for npc: NpcRuntimeState in _map.npcs.residents:
		if npc.definition().dealings().takes_toll() and npc.relationship.is_fighting():
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
## master; an NPC whose fight is not ported is not there for it either, nor one whose 攻击
## asks first (小娟, owner 黑松山 F3: no fight with her the player did not choose), nor a
## 木人 (A2: they only spar).
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
			or (npc.definition().hooks() != null and not npc.definition().hooks().attack_ask.is_empty())
			or npc.definition().spar_only()
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
	# The gang's alert beat runs: its fight comes first (as when it fell on the player at once).
	if not _alert_zone.is_empty():
		return
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
		# The gang's alert beat runs: its fight comes first (进门一起上).
		or not _alert_zone.is_empty()
	):
		_map.hud().append_log_lines(lines)
		return
	_npc_berserk(npc, Berserk.start(npc.character_state, npc.definition().score, _world_interaction_random), lines)


## The fight the player's last berserk started (or tried to), for tests.
func last_player_berserk() -> CombatSliceInitiationResult:
	return _last_player_berserk


## The gang (DECISIONS「进门一起上」): attack.c init() runs for every NPC in the room the
## player comes into, so all that attack the player on sight there (hatred, vendetta,
## aggressive, a toll-taker whose greeting is due) fall on them together: one encounter,
## the player first, then stable ID order, a manual target (the player's 攻击) in it too.
## Every such NPC in the player's zone belongs to it, near or far (owner, A6 Q1); it
## starts when one of them is fresh in reach (indoors the room, outdoors its presence
## circle; not `spent`). Toll-takers still waiting out their greeting join a fight that
## starts. `gang_noticer`: the nearest of the fresh ones in reach.
func collect_complete_combat_entry(cause: int, requested_target: StringName = &"") -> Array[CombatSliceCharacterBinding]:
	gang_noticer = &""
	gang_fresh.clear()
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
	var waiting: Array[StringName] = []
	var noticer_distance: float = INF
	for npc: NpcRuntimeState in _map.npcs.residents:
		var id: StringName = npc.character_id
		var named: bool = manual and id == requested_target
		# The player's own 攻击 brings the room down on them, whoever took them for one of their own.
		var on_sight: bool = (
			npc.definition().attacks_on_sight(npc.flags(), _player.state, _parley(), not manual and _ignored(npc))
			and aggression._evaluate(npc, _player, _combat_allowed(npc)).outcome == NpcAggressionDecision.Outcome.READY
		)
		if not on_sight and not named:
			continue
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(id)
		if npc.exists_in_map and (not is_instance_valid(body) or body._npc != npc or _map.npcs.map_characters.find_npc(id) != npc):
			return []
		if ids.has(id) or waiting.has(id):
			return []
		if on_sight and not named and not _toll_due(npc):
			waiting.append(id)
			continue
		ids.append(id)
		# In reach: the exact shapes now, or its presence entered since the last tick.
		if on_sight and _toll_due(npc) and not spent.has(id) and (complete_entry_contact(id) or aggression.has_pending(id) or _noticed.has(id)):
			gang_fresh.append(id)
			var distance: float = body.global_position.distance_squared_to(player_body.global_position)
			if distance < noticer_distance:
				noticer_distance = distance
				gang_noticer = id
	if ids.is_empty() or (not manual and gang_noticer.is_empty()):
		gang_noticer = &""
		return []
	# gangster.c: every robber's greeting comes from the same arrival (each init()), so the
	# toll-takers still waiting in the place join the fight that starts here.
	ids.append_array(waiting)
	ids.sort_custom(func(first: StringName, second: StringName) -> bool: return String(first) < String(second))
	ids.push_front(_player.character_id)
	var available: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
	var result: Array[CombatSliceCharacterBinding] = []
	for id: StringName in ids:
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(available, id)
		# kill.c: the one the player's 攻击 names may lie unconscious.
		if binding == null or not session.encounter_participant_is_available(id, manual and id == requested_target):
			gang_noticer = &""
			return []
		result.append(binding)
	return result


## Whether the gang's `id` only kills, the player fighting it back: one that hunts the
## player (combatd.c start_hatred()'s kill_ob(): attack.c is_killing()), unless it is the
## one the player's 攻击 names (then both kill, as kill.c).
func kills_one_way(id: StringName, requested_target: StringName = &"") -> bool:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
	return npc != null and id != requested_target and npc.has_flag(NpcDefinition.FLAG_HUNTS_PLAYER)


## Exact current shapes, not cached Area overlap lists or deferred signal order; indoors,
## the player in the NPC's room.
func complete_entry_contact(id: StringName) -> bool:
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(id)
	if not is_instance_valid(body) or not body.is_inside_tree():
		return false
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(id)
	if notices_room(npc):
		return shares_room(npc)
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


## The player's own 攻击 (kill.c) or an NPC's attack by `initiator_id`: the player's falls
## in with the gang of the place (collect_complete_combat_entry()), whose own kill_ob()s
## came with the player into it.
func initiate_lethal_combat(initiator_id: StringName, target_id: StringName, lines: Array[String]) -> CombatSliceInitiationResult:
	if not _map.gameplay_open() or session == null:
		return CombatSliceInitiationResult.new()
	var cause: int = CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK if initiator_id == _player.character_id else CombatTriggerCause.Value.NPC_AGGRESSION
	var result: CombatSliceInitiationResult
	if cause == CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK and collect_complete_combat_entry(cause, target_id).size() > 2:
		result = session.combat_encounter_coordinator().start_complete_production(cause, target_id)
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
	if not rule.line.is_empty():
		lines.append(tr(rule.line))
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
	if encounter != null:
		_allies_join(encounter)


## Native (关北 C; DECISIONS「替玩家打的 NPC」): as a fight the player is in opens, every NPC that
## fights beside them (NpcHooks.fights_beside_player) and stands conscious in the player's place,
## not yet in it — one the player's side summoned (the 王府's riders, summoners) or one following
## them (郭承) — kill_ob()s the player's living enemies and comes in on their side, as the 天将 do
## (heaven_soldier.c invocation(); CombatEncounterResolution's allies). Those enemies kill it back.
func _allies_join(encounter: CombatEncounter) -> void:
	if _player == null or encounter.participant_for(_player.character_id) == null:
		return
	var here: WorldLocationState = _player.world_location()
	var allies: Array[StringName] = []
	for npc: NpcRuntimeState in _map.npcs.residents:
		var hooks: NpcHooks = npc.definition().hooks()
		if (
			hooks == null or not hooks.fights_beside_player or not npc.exists_in_map
			or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting()
			or encounter.participant_for(npc.character_id) != null or not npc.world_location().shares_combat_location(here)
		):
			continue
		if _map.npcs.summoner_of(npc.character_id) == _player.character_id or npc.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER):
			allies.append(npc.character_id)
	if allies.is_empty():
		return
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var bindings: Array[CombatSliceCharacterBinding] = session.encounter_combat_bindings(encounter)
	coordinator.resolution().admit(bindings, CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_allies(allies))
	var told: Array[String] = []
	for ally_id: StringName in allies:
		if encounter.participant_for(ally_id) != null:
			var npc: NpcRuntimeState = _map.npcs.find_resident_npc(ally_id)
			if npc != null:
				# TRANSLATORS: one who fights beside the player ({npc}) comes into the fight.
				told.append(TranslationServer.translate("{npc}拔刀上前，和你并肩而立！").format({"npc": TranslationServer.translate(npc.definition().display_name)}))
	if not told.is_empty():
		_map.hud().append_log_lines(told, true)


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
