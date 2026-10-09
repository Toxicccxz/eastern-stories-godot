class_name WorldMapActs
extends RefCounted
## ScriptedAct steps on this map, in order: what an NPC's greeting() or a room's own
## command does to the player who is there. The game rule is the act's data; this does
## it to the player, the NPC, the doors and the log.

var _map: WorldMapController

var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


## Runs `act` on the player; `npc` is the one acting (a greeting) or null (a room's
## command). `draw` is MudOS random(n). The player reads the lines only while conscious
## (damage.c block_msg); what is done to them is done either way. Lines go to the log
## before a door, a move or a fight, which say their own; the fight's opening says the
## lines before it.
func run(act: ScriptedAct, npc: NpcRuntimeState, draw: Callable) -> void:
	if act == null or _player == null:
		return
	var state: CharacterState = _player.state
	var hears: bool = _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	var npc_name: String = "" if npc == null else npc.definition().display_name
	var respect: String = RankWords.query_respect(state.gender, _player.facts.age, state.affiliation.class_id)
	var said: Array[ColoredLine] = []
	for step: ScriptedAct.Step in act.steps:
		match step.kind:
			ScriptedAct.Kind.LINE:
				said.append(step.line.colored(npc_name, respect))
			ScriptedAct.Kind.DAMAGE:
				for key: String in ScriptedAct.RESOURCES:
					if step.amounts.has(key):
						ScriptedAct.resource_of(state, key).apply_damage(step.amounts[key])
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
				_show(said, hears)
				if npc != null:
					_close_door(npc, hears)
			ScriptedAct.Kind.MOVE:
				_show(said, hears)
				if not _map.relocate_player(step.zone_id, step.point_id, true):
					push_error("%s could not move the player to %s at %s" % [npc_name, step.zone_id, step.point_id])
			ScriptedAct.Kind.KILL:
				if npc == null:
					continue
				var opening: Array[ColoredLine] = []
				if hears:
					opening = said.duplicate()
				said.clear()
				var started: CombatSliceInitiationResult = _map.hostilities.npc_kills(npc, ColoredLine.texts(opening), opening)
				if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED and not opening.is_empty() and _map.hud() != null:
					_map.hud().append_colored_lines(opening)
			ScriptedAct.Kind.GIVE:
				if not step.unless_temp.is_empty() and _player.temp_marks.get(step.unless_temp, 0) != 0:
					continue
				_map.give_new_item_to_player(step.item_id)
				if not step.unless_temp.is_empty():
					_player.temp_marks[step.unless_temp] = 1
				for line: NpcLine in step.lines:
					said.append(line.colored(npc_name, respect))
	_show(said, hears)
	var hud: SharedGameplayUI = _map.hud()
	if hud != null and hud.inventory_is_open():
		hud.show_inventory(_map.session.player_inventory_rows())
	# std/char.c heart_beat(): gone below zero, the player falls where they now are; one
	# already lying unconscious dies (!living() → die()).
	if state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		_map.player_fall_below_zero(true)


func _show(said: Array[ColoredLine], hears: bool) -> void:
	if hears and not said.is_empty() and _map.hud() != null:
		_map.hud().append_colored_lines(said.duplicate())
	said.clear()


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
