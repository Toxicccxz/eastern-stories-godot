class_name WorldMapActs
extends RefCounted
## ScriptedAct steps on this map, in order: what an NPC's greeting(), a room's own
## command or a carried item's does to the player who is there. The game rule is the
## act's data; this does it to the player, the NPC, the doors and the log.

var _map: WorldMapController

var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


## What a branch may ask of the player (ScriptedAct.Facts): their marks, set_temp()
## flags, the ids of what they carry directly (present(id, me)) and the NPCs standing
## where they stand (present(); one lying unconscious says nothing: 默认), their force;
## the flags of the act's room (`room_zone_id`, else where the player stands), which
## items exist in the world, who stands in another room and their kar (the rolls draw only
## once the caller gives the facts a draw).
func facts(room_zone_id: StringName = &"") -> ScriptedAct.Facts:
	var known := ScriptedAct.Facts.new()
	if _player == null:
		return known
	known.marks = _player.state.marks
	known.temps = _player.temp_marks
	known.thirsty = _player.state.recovery.water < CharacterRecovery.maximum_water_capacity(_player.body_facts.body_weight)
	known.numbers = {
		"force": _player.state.recovery.inner_force.current,
		"max_force": _player.state.recovery.inner_force.maximum,
		"force_factor": _player.state.attributes.force_factor,
	}
	var here: StringName = _player.world_location().zone_id
	if _map.session != null:
		known.room = _map.session.room_states().flags(here if room_zone_id.is_empty() else room_zone_id)
	known.item_exists = _map.floor_items.item_exists
	known.standing_in = _standing_in
	known.kar = _player.state.attributes.karma
	known.ghost = _player.state.ghost
	known.per = _player.state.attributes.personality
	if _map.session != null:
		known.phase_id = _map.session.day_phase_id()
	for npc: NpcRuntimeState in _map.npcs.residents:
		var id: StringName = NpcDefinition.unnamed_id(npc.definition().definition_id)
		if not known.present_npcs.has(id) and _map.npcs.npc_present_in_zone(id, here, true):
			known.present_npcs.append(id)
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	for item_id: StringName in _map.inventory_state().direct_children(carried):
		var item: ItemInstance = _map.item_instance_index().resolve(item_id)
		var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
		if content != null:
			known.carried.append_array(content.aliases())
	if _player.armor != null:
		for slot: StringName in _player.armor.occupied_slots():
			var reference: EquippedArmorRef = _player.armor.equipped_ref_in_slot(slot)
			var content: ItemContentDefinition = null if reference == null else GameContent.catalog().item(reference.item_definition_id)
			if content != null:
				known.worn.append_array(content.aliases())
	return known


## Whether an NPC of `definition_id` stands in `zone_id`, on whichever map the room lies (the
## 瓜农 in his 瓜棚, a map of its own since the remap).
func _standing_in(definition_id: StringName, zone_id: StringName) -> bool:
	var there: WorldMapController = null if _map.session == null else _map.session.caught_up_map_of_zone(zone_id)
	return (_map if there == null else there).npcs.npc_present_in_zone(definition_id, zone_id, true)


## Runs `act` on the player; `npc` is the one acting (a greeting) or null (a room's or an
## item's command). `draw` is MudOS random(n). The player reads the lines only while
## conscious (damage.c block_msg); what is done to them is done either way. Lines go to
## the log before a door, a move or a fight, which say their own; the fight's opening
## says the lines before it. A move to another map is a handoff and ends the act (the
## steps after it would act on the map left behind); a greeting's NPC moves the player
## only on its own map. `room_zone_id` is the act's room (else where the player stands).
## An NPC that `comes` is the act's NPC from then on (its kill, its flag).
func run(act: ScriptedAct, acting_npc: NpcRuntimeState, draw: Callable, room_zone_id: StringName = &"") -> void:
	if act == null or _player == null:
		return
	var room: StringName = _player.world_location().zone_id if room_zone_id.is_empty() else room_zone_id
	var npc: NpcRuntimeState = acting_npc
	var state: CharacterState = _player.state
	var hears: bool = _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	var npc_name: String = "" if npc == null else npc.definition().display_name
	var respect: String = RankWords.query_respect(state.gender, _player.facts.age, state.affiliation.class_id)
	var said: Array[ColoredLine] = []
	# What the NPC itself says, for the bubble over its head (DECISIONS「手感」).
	var spoken: Array[String] = []
	var moved_away: bool = false
	for step: ScriptedAct.Step in act.steps:
		if moved_away:
			break
		match step.kind:
			ScriptedAct.Kind.LINE:
				said.append(step.line.colored(npc_name, respect))
				spoken.append(said[-1].text)
			ScriptedAct.Kind.DAMAGE:
				for key: String in ScriptedAct.RESOURCES:
					if step.amounts.has(key):
						ScriptedAct.resource_of(state, key).apply_damage(step.amounts[key])
			ScriptedAct.Kind.HURT:
				for key: String in ScriptedAct.RESOURCES:
					if step.amounts.has(key):
						var random_of: int = step.randoms.get(key, 0)
						var hurt: int = step.amounts[key] + (int(draw.call(random_of)) if random_of > 0 else 0)
						# eff_x and x each lowered by n: receive_damage() then receive_wound().
						ScriptedAct.resource_of(state, key).apply_damage(hurt)
						ScriptedAct.resource_of(state, key).apply_wound(hurt)
			ScriptedAct.Kind.HEAL:
				var amount: int = step.base + (int(draw.call(step.random_of)) if step.random_of > 0 else 0)
				ScriptedAct.resource_of(state, step.resource).heal(amount)
			ScriptedAct.Kind.CONDITION:
				state.conditions.add_or_replace_duration(step.condition_id, step.duration)
			ScriptedAct.Kind.CALM:
				# uproom3.c: only a bellicosity above 0 goes down, and it may go below 0;
				# random(n) with n <= 0 is 0 (DECISIONS' global rule).
				if state.attributes.bellicosity > 0:
					var kar: int = state.attributes.karma
					state.attributes.bellicosity -= (int(draw.call(kar)) if kar > 0 else 0) + step.value
			ScriptedAct.Kind.NPC_FORCE:
				if npc != null:
					npc.character_state.recovery.inner_force.current += step.value
			ScriptedAct.Kind.CLOSE_DOOR:
				_show(said, hears, npc, spoken)
				if npc != null:
					_close_door(npc, hears)
			ScriptedAct.Kind.MOVE:
				_show(said, hears, npc, spoken)
				var zone: ZoneDefinition = GameContent.catalog().zone(step.zone_id)
				if zone != null and zone.map_id != _map.map_id() and npc != null:
					push_error("%s's greeting cannot move the player off its map to %s" % [npc_name, step.zone_id])
				elif not move_player(step.zone_id, step.point_id):
					push_error("%s could not move the player to %s at %s" % [npc_name, step.zone_id, step.point_id])
				else:
					moved_away = zone.map_id != _map.map_id()
			ScriptedAct.Kind.KILL:
				if npc == null:
					continue
				var opening: Array[ColoredLine] = []
				if hears:
					opening = said.duplicate()
				said.clear()
				spoken.clear()
				var started: CombatSliceInitiationResult = _map.hostilities.npc_kills(npc, ColoredLine.texts(opening), opening)
				if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED and not opening.is_empty() and _map.hud() != null:
					_map.hud().append_colored_lines(opening)
			ScriptedAct.Kind.GIVE:
				if not step.unless_temp.is_empty() and _player.temp_marks.get(step.unless_temp, 0) != 0:
					continue
				var made: StringName = step.item_id if step.pick.is_empty() else step.pick[clampi(int(draw.call(step.pick.size())), 0, step.pick.size() - 1)]
				var made_id: StringName = _map.give_new_item_to_player(made)
				if not step.unless_temp.is_empty():
					_player.temp_marks[step.unless_temp] = 1
				for line: NpcLine in step.lines:
					said.append(line.colored(npc_name, respect))
				# Too heavy to carry, it lies at their feet; they are told so.
				var made_item: ItemInstance = null if made_id.is_empty() else _map.item_instance_index().resolve(made_id)
				if made_item != null:
					var feet: String = _map.floor_items.at_feet_line(made_id, GameContent.catalog().item(made_item.item_definition_id))
					if not feet.is_empty():
						said.append(ColoredLine.new(feet))
			ScriptedAct.Kind.COMES:
				var comer: NpcRuntimeState = _map.npcs.first_npc_in_zone(step.npc_id, step.zone_id, true)
				# From a room on another map (the 瓜农 out of his own 瓜棚 since the remap): he comes
				# through onto this one first.
				if comer == null and _map.session != null:
					var home: WorldMapController = _map.session.caught_up_map_of_zone(step.zone_id)
					if home != null and home != _map:
						comer = home.npcs.first_npc_in_zone(step.npc_id, step.zone_id, true)
						if comer != null and not _map.session.bring_npc_onto(comer, home, _map, _player.world_location().zone_id):
							comer = null
				if comer != null and _map.npcs.bring_beside_player(comer):
					npc = comer
					npc_name = comer.definition().display_name
			ScriptedAct.Kind.NPC_FLAG:
				if npc != null:
					npc.set_flag(StringName(step.flag), true)
			ScriptedAct.Kind.UNFOLLOW:
				if npc != null:
					npc.clear_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER)
			ScriptedAct.Kind.SET_TEMP:
				_player.temp_marks[step.flag] = 1
			ScriptedAct.Kind.CLEAR_TEMP:
				_player.temp_marks.erase(step.flag)
			ScriptedAct.Kind.UNMARK:
				state.marks.erase(step.flag)
			ScriptedAct.Kind.MARK:
				state.marks[step.flag] = 1
				_map.open_found_ways(step.flag)
			ScriptedAct.Kind.SUMMON:
				_show(said, hears, npc, spoken)
				if _map.summon(step.spawn_id).is_empty():
					push_error("%s could not summon %s" % [npc_name, step.spawn_id])
			ScriptedAct.Kind.NPC_MOOD:
				var hooks: NpcHooks = null if npc == null else npc.definition().hooks()
				if hooks != null and hooks.moods.has(step.flag):
					npc.put_in_mood(hooks.moods[step.flag])
			ScriptedAct.Kind.NPC_WIELD:
				# carry_object(item)->wield(): a new one, in its hand.
				if npc != null and not _map.floor_items.give_new_item_to(npc, step.item_id).is_empty():
					_map.npcs.npc_wield_item(npc.character_id, step.item_id)
			ScriptedAct.Kind.LEAVE:
				var leaving: NpcRuntimeState = npc
				if not step.npc_id.is_empty():
					# A room's own act (no NPC acting) sends off one standing in the act's room.
					leaving = _map.npcs.first_npc_in_zone(step.npc_id, room if npc == null else npc.world_location().zone_id, true)
				if leaving != null:
					_map.npcs.leave_for_good(leaving)
			ScriptedAct.Kind.UNTIL_PHASE:
				_show(said, hears, npc, spoken)
				if _map.session != null and not _map.session.wait_until_phase(step.phases):
					push_error("the act could not wait for %s" % [step.phases])
			ScriptedAct.Kind.WATER:
				state.recovery.water += step.value
			ScriptedAct.Kind.REINCARNATE:
				# reincarnate() and the move to REVIVE_ROOM: the lines first, then the session's move.
				_show(said, hears, npc, spoken)
				if _map.session != null:
					_map.session.request_reincarnation()
			ScriptedAct.Kind.BY:
				# The lines so far are the last speaker's; from here they are this one's.
				_show(said, hears, npc, spoken)
				var speaker: NpcRuntimeState = _map.npcs.first_npc_in_zone(step.npc_id, room, true)
				# Nobody of them here (a scene cut short and replayed): the rest of the act is
				# theirs and does not happen.
				if speaker == null:
					moved_away = true
					continue
				npc = speaker
				npc_name = speaker.definition().display_name
				_map.npc_life.scene_look_at(npc)
			ScriptedAct.Kind.DROP:
				_show(said, hears, npc, spoken)
				var feet: Vector2 = Vector2.INF
				var body: WorldCharacterBody2D = null if npc == null else _map.npcs.runtime_body_for_character(npc.character_id)
				if body != null and npc.exists_in_map:
					feet = body.global_position
				if _map.floor_items.place_new_floor_item(step.item_id, feet).is_empty():
					push_error("%s could not drop %s" % [npc_name, step.item_id])
				if npc != null:
					_map.npc_life.scene_look_at(npc)
			ScriptedAct.Kind.SET_ROOM:
				if _map.session != null:
					_map.session.room_states().set_flag(room, step.flag)
			ScriptedAct.Kind.CLEAR_ROOM:
				if _map.session != null:
					_map.session.room_states().clear_flag(room, step.flag)
	_show(said, hears, npc, spoken)
	var hud: SharedGameplayUI = _map.hud()
	if hud != null and hud.inventory_is_open():
		hud.show_inventory(_map.session.player_inventory_rows())
	# std/char.c heart_beat(): gone below zero, the player falls where they now are; one
	# already lying unconscious dies (!living() → die()).
	var here: WorldMapController = _map.session.active_map() as WorldMapController if _map.session != null else null
	if state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		(here if here != null else _map).player_fall_below_zero(true)


## ob->move(room): within this map the player is put at `point_id`; another map's room is
## a handoff there. Whether the player is there now.
func move_player(zone_id: StringName, point_id: StringName) -> bool:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	if zone == null:
		return false
	# The player is led (a climb, a fall): who follows them every way comes along (F2).
	if zone.map_id == _map.map_id():
		var left: StringName = _player.world_location().zone_id
		if not _map.relocate_player(zone_id, point_id, true):
			return false
		_map.npc_life.lead_followers(left, zone_id)
		return true
	if _map.session == null:
		return false
	return _map.session.handoff_led(zone.map_id, zone.zone_id, zone.combat_location_id, point_id).succeeded()


func _show(said: Array[ColoredLine], hears: bool, npc: NpcRuntimeState, spoken: Array[String]) -> void:
	if hears and not said.is_empty() and _map.hud() != null:
		_map.hud().npc_says(npc, said.duplicate(), spoken.duplicate())
	# A scene's camera goes to whoever speaks (DECISIONS「剧情演出」).
	if not said.is_empty() and npc != null:
		_map.npc_life.scene_look_at(npc)
	said.clear()
	spoken.clear()


## command("close door") (cmds/std/close.c): the door the player came in by, else the
## room's first (DECISIONS 晚月庄 A: the one the player came by); one already shut stays
## so, without a word (close_door()'s notify_fail()).
func _close_door(npc: NpcRuntimeState, hears: bool) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var came_from: StringName = _map.npc_life.came_from_zone_id
	var chosen: DoorDefinition = null
	for door: WorldDoor in _map.doors():
		var definition: DoorDefinition = GameContent.catalog().door(door.door_id)
		if definition == null or not definition.zone_ids().has(zone_id):
			continue
		# A way found by a clue (found_by) is no door to shut: once found it stays open.
		if not definition.found_by.is_empty():
			continue
		if definition.zone_ids().has(came_from):
			chosen = definition
			break
		if chosen == null:
			chosen = definition
	if chosen == null or _map.door(chosen.door_id) == null or not _map.door(chosen.door_id).is_open():
		return
	_map.set_door_open(chosen.door_id, false)
	if hears and _map.hud() != null:
		# TRANSLATORS: close.c: an NPC ({npc}) shuts a door ({door}) in the player's room.
		_map.hud().append_log_lines([TranslationServer.translate("{npc}将{door}关上。").format({
			"npc": TranslationServer.translate(npc.definition().display_name),
			"door": TranslationServer.translate(chosen.display_name),
		})])
