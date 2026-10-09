class_name WorldMapSpells
extends RefCounted
## The player's spells outside a fight on this map: 驱尸 (necromancy/animate.c) on the
## selected corpse and the NPC it raises (obj/npc/zombie.c: it follows the player, onto
## other maps too, and lives on their atman); the 符 they draw on a paper with the
## selected NPC's name (cmds/std/scribe.c, haunt.c) and put on the NPC they raised
## (cmds/std/attach.c) to send it after that one. The map is `_map`.

var _map: WorldMapController

## NpcAmbience's call_out kind for zombie.c call_out("dispell", 1).
const DISPELL: StringName = &"dispell"
## Where a raised NPC comes in beside the player it follows onto a new map: clear of the
## player's body first (WorldMapNpcs.BESIDE).
const ANIMATE: StringName = &"animate"
const HAUNT: StringName = &"haunt"

# The map's authorities, read as the controller reads them.
var session: WorldSessionController:
	get: return _map.session
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


## cast animate on <the selected corpse>: whether the HUD offers 驱尸 there (the enabled
## spells skill has the file and a corpse lies selected in the player's place).
func animatable_corpse() -> CorpseState:
	if _player == null or not CastService.offered(_player.state, GameContent.catalog()).has(ANIMATE):
		return null
	var corpse: CorpseState = _map.corpses.selected_corpse_here()
	return corpse if corpse != null and corpse.is_legacy_corpse() else null


## Whether 驱尸 now would leave the player below zero sen (animate.c takes 30 sen and
## asks only for mana): they would fall unconscious (owner's rule: asked first). Not when
## cast.c or animate.c would refuse anyway (busy, a no_magic room, too little mana).
func animate_knocks_out() -> bool:
	return (
		_player != null and not _player.busy.is_busy()
		and not GameContent.catalog().zone_forbids_magic(_player.world_location().zone_id)
		and _player.state.recovery.mana.current >= AnimateSpell.MANA_COST and _player.state.spirit.current < AnimateSpell.SEN_COST
	)


## cast animate on the selected corpse (cmds/std/cast.c): the spell's line or refusal, and
## the corpse rises as the NPC its victim was (corpse.c animate()), beside where it lay,
## what it held falling there.
func animate_selected_corpse() -> bool:
	if not _map.floor_items.can_handle_items():
		return false
	var corpse: CorpseState = _map.corpses.selected_corpse_here()
	if corpse == null:
		_map.hud().append_log_lines([tr("你要驱动哪一具尸体？")])
		return false
	var corpse_name: String = _map.corpses.corpse_name(corpse)
	var context := SpecialContext.new(_player_side(), [], _map.world_interaction_random_source().legacy_random, GameContent.catalog(), _map.combat_lifecycle.effects)
	context.corpse = corpse
	var no_magic: bool = GameContent.catalog().zone_forbids_magic(_player.world_location().zone_id)
	var cast: bool = CastService.cast(context, ANIMATE, no_magic)
	var lines: Array[String] = []
	for line: VisionLine in context.report().lines():
		lines.append(_vision(line.template, corpse_name))
	if not context.raised:
		_map.hud().append_log_lines(lines)
		return cast
	var victim: String = corpse.victim_display_name
	var location: WorldLocationState = _map.corpses.corpse_world_location(corpse.corpse_item_instance_id)
	var position: Vector2 = _clear_of_player(location, _map.corpses.lying_at(corpse))
	if not _map.corpses.raise_corpse(corpse):
		push_error("raising %s failed: the item state is inconsistent" % corpse.corpse_item_instance_id)
		return false
	_map.hud().append_log_lines(lines)
	var raised: NpcRuntimeState = _map.npcs.raise_at(_player.character_id, &"common.npc.zombie", victim, location, position)
	if raised == null:
		push_error("the zombie of %s could not stand up" % victim)
	else:
		_map.npc_life.npc_arrived(raised)
	_after_cost()
	return cast


## The raised NPC's spot where the corpse lay, or beside it, clear of the player's body
## (34 px each, so neither is pushed when the world moves).
func _clear_of_player(location: WorldLocationState, origin: Vector2) -> Vector2:
	for distance: int in [0, 28, 44, 64, 96]:
		for direction: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var spot: Vector2 = (origin + direction.normalized() * distance).round()
			if spot.distance_to(_map.player_body.global_position) >= WorldMapNpcs.BESIDE[0] and MapPlacementValidator.is_valid_character_position(_map, location.zone_id, spot):
				return spot
	return _map.floor_items.at_feet(location, origin)


## zombie.c heal_up(), `count` times on this beat, for a raised NPC: one its sheet sent
## (end_tag) dispells a second later once it is not fighting; else it tells its master
## (message("tell"): the player reads it wherever they are) and takes their atman and gin
## while they have more than raising.drain_above atman, and otherwise dispells a second
## later. Deviation (默认, DECISIONS 茅山 D): it takes nothing from a master lying
## unconscious, whose gin unconcious() set to 0 (ES2's drain then kills them, char.c).
func raised_heal_up(npc: NpcRuntimeState, count: int) -> void:
	var raising: NpcRaising = npc.definition().raising()
	if raising == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
		return
	var ambience: NpcAmbience = _map.npc_life.npc_ambience()
	for _beat: int in count:
		if npc.has_flag(NpcDefinition.FLAG_SENT) and not npc.relationship.is_fighting():
			ambience.start_call(npc.character_id, NpcRaising.DISPELL_DELAY_SECONDS, DISPELL)
			return
		var master: bool = _player != null and _map.npcs.summoner_of(npc.character_id) == _player.character_id
		if not master or not raising.feeds_on(_player.state.recovery.atman.current):
			ambience.start_call(npc.character_id, NpcRaising.DISPELL_DELAY_SECONDS, DISPELL)
			return
		if _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
			continue
		_map.hud().append_colored_lines([ColoredLine.new(tr(raising.tell).replace("$N", tr(npc.definition().display_name)), raising.color)])
		raising.drain(_player.state)
	# receive_damage("gin", 1) can leave the master below zero: char.c's next beat.
	_map.combat_lifecycle.player_fall_below_zero()


## zombie.c dispell(): say() to its room, then destruct() (no corpse).
func dispell(npc: NpcRuntimeState) -> void:
	if npc == null or npc.definition().raising() == null or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
		return
	if _map.npc_life.player_hears(npc):
		_map.hud().append_log_lines([tr(npc.definition().raising().dissolve).replace("$N", tr(npc.definition().display_name))])
	_map.npcs.destruct_summoned(npc)


## go.c's follow_me() onto another map (owner, DECISIONS 茅山 A): a raised NPC that
## follows the player and stood, conscious and not fighting, in the room they walked out
## of (`left_zone_id`) comes along onto `to` beside them; the player sees 走了过来。. Its
## call_out("dispell") goes with it. Not saved: Continue starts without it.
func carry_followers(to: WorldMapController, left_zone_id: StringName) -> void:
	var location: WorldLocationState = null if _player == null else to.location_for_zone(_player.world_location().zone_id)
	if location == null:
		return
	var ambience: NpcAmbience = _map.npc_life.ambience
	for npc: NpcRuntimeState in _map.npcs.residents.duplicate():
		if (
			npc.definition().raising() == null or not npc.has_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER) or not npc.exists_in_map
			or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting()
			or npc.world_location().zone_id != left_zone_id
		):
			continue
		var dispelling: bool = ambience != null and ambience.has_call(npc.character_id, DISPELL)
		var caster_id: StringName = _map.npcs.release(npc)
		if not to.npcs.admit(npc, caster_id, location, to.floor_items.at_feet(location, to.player_body.global_position, false, WorldMapNpcs.BESIDE)):
			push_error("%s could not follow the player onto %s" % [npc.character_id, to.map])
			continue
		if dispelling:
			to.npc_life.npc_ambience().start_call(npc.character_id, NpcRaising.DISPELL_DELAY_SECONDS, DISPELL)
		to.hud().describe_arrival()
		# TRANSLATORS: go.c: someone ({name}) comes into the player's room.
		to.hud().append_log_lines([tr("{name}走了过来。").format({"name": tr(npc.definition().display_name)})])
		to.npc_life.npc_arrived(npc)


## The NPC whose name the player may write on a 僵尸追魂符 now: the selected one, in their
## place and not dead (present() in the room, DECISIONS 茅山 A), when their enabled spells
## skill draws it. A raised NPC (named after its corpse) and one whose fight is not ported
## are not offered. Null otherwise.
func scribable_npc() -> NpcRuntimeState:
	if _player == null or not ScribeService.offered(_player.state, GameContent.catalog()).has(HAUNT):
		return null
	var npc: NpcRuntimeState = _map.selection.selected_npc()
	if (
		npc == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD
		or not npc.world_location().shares_combat_location(_player.world_location())
		or npc.definition().raising() != null or npc.definition().dealings().is_fight_deferred()
	):
		return null
	return npc


## Whether drawing the 符 now would leave the player below zero sen (scribe.c asks for 30
## sen and takes 40 with haunt.c's): they would fall unconscious. Not when it would be
## refused anyway.
func scribe_knocks_out() -> bool:
	return _scribe_goes_ahead() and _player.state.spirit.current < ScribeService.SEN_COST + HauntScribe.SEN_COST


## Whether the 1 kee wound of drawing the 符 would leave the player's effective kee below
## zero: they would die (char.c's eff_kee < 0).
func scribe_kills() -> bool:
	return _scribe_goes_ahead() and _player.state.vitality.effective < ScribeService.KEE_WOUND


func _scribe_goes_ahead() -> bool:
	return _player != null and _player.state.recovery.mana.current >= HauntScribe.MANA_COST and _player.state.spirit.current >= ScribeService.MIN_SEN


## scribe haunt on <paper_id> for <the selected NPC>: its refusal, or the paper becomes a
## 僵尸追魂符 with that name (one of a stack; owner, DECISIONS 茅山 A). scribe.c says
## nothing when it works: the player reads a native line.
func scribe_on(paper_id: StringName) -> bool:
	if not _map.floor_items.can_handle_items():
		return false
	var item: ItemInstance = _map.item_instance_index().resolve(paper_id)
	var paper: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	if paper == null or not paper.scribe or not _map.inventory_state().is_direct_child(paper_id, carried):
		return false
	var npc: NpcRuntimeState = scribable_npc()
	if npc == null:
		return false
	var sheet: ItemContentDefinition = GameContent.catalog().item(ItemContentDefinition.haunting_sheet_id(paper.item_definition_id, npc.definition().definition_id))
	if sheet == null:
		return false
	var refused: String = ScribeService.scribe(_player_side(), HAUNT, npc.definition().display_name, _player.relationship.is_fighting(), GameContent.catalog())
	if not refused.is_empty():
		_map.hud().append_log_lines([tr(refused)])
		return false
	var owner := ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)
	if not _map.floor_items.use_up_one(paper_id, owner) or _map.floor_items.give_new_item_to_player(sheet.item_definition_id).is_empty():
		push_error("drawing a sheet on %s failed: the item state is inconsistent" % paper_id)
		return false
	# TRANSLATORS: scribe.c: the player draws 僵尸追魂符 in their blood on a 桃符纸 ({paper}) and writes a name ({name}) on it.
	_map.hud().append_log_lines([tr("你咬破手指，用鲜血在{paper}上画了一道僵尸追魂符，写上了{name}的名字。").format({
		"paper": tr(paper.display_name), "name": tr(npc.definition().display_name),
	})])
	_refresh_inventory()
	_after_cost()
	return true


## The NPC attach.c puts a sheet on: present("zombie", environment(me)), the selected one
## when it is a raised NPC standing in the player's place, else the first such there.
## Only one standing can go after anyone. Null when none is there.
func sheet_carrier() -> NpcRuntimeState:
	if _player == null:
		return null
	var selected: NpcRuntimeState = _map.selection.selected_npc()
	if _carries_sheets(selected):
		return selected
	for npc: NpcRuntimeState in _map.npcs.residents:
		if _carries_sheets(npc):
			return npc
	return null


func _carries_sheets(npc: NpcRuntimeState) -> bool:
	return (
		npc != null and npc.definition().raising() != null and npc.exists_in_map
		and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and not npc.relationship.is_fighting()
		and npc.world_location().shares_combat_location(_player.world_location())
	)


## The one a carried 僵尸追魂符 `sheet_id` would send the carrier after: present(name,
## environment(zombie)), the first of that NPC there (not the carrier, not dead). Null
## when there is none.
func sheet_target(sheet_id: StringName) -> NpcRuntimeState:
	var carrier: NpcRuntimeState = sheet_carrier()
	var item: ItemInstance = _map.item_instance_index().resolve(sheet_id)
	var sheet: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	if carrier == null or sheet == null or sheet.haunts.is_empty():
		return null
	for npc: NpcRuntimeState in _map.npcs.residents:
		if (
			npc != carrier and npc.definition().definition_id == sheet.haunts and npc.exists_in_map
			and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
			and npc.world_location().shares_combat_location(carrier.world_location())
		):
			return npc
	return null


## attach <sheet_id> on the carrier (attach.c, haunt.c do_scribe_haunt()/do_haunt()): the
## one it names is here, so the sheet is used up and the carrier kill_ob()s them, makes
## them its leader (no longer following the player) and is done once that fight is over
## (end_tag); they fight it back while the player stands by. One not here (DECISIONS
## 茅山 A): 这里没有…, and the sheet stays.
func attach_sheet(sheet_id: StringName) -> bool:
	if not _map.floor_items.can_handle_items():
		return false
	var item: ItemInstance = _map.item_instance_index().resolve(sheet_id)
	var sheet: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, _player.character_id)
	var carrier: NpcRuntimeState = sheet_carrier()
	if sheet == null or sheet.haunts.is_empty() or carrier == null or not _map.inventory_state().is_direct_child(sheet_id, carried):
		return false
	var target: NpcRuntimeState = sheet_target(sheet_id)
	if target == null:
		var named: NpcDefinition = GameContent.catalog().npc(sheet.haunts)
		# TRANSLATORS: cast.c's 这里没有…: the one ({name}) a 僵尸追魂符 names is not here; the sheet stays.
		_map.hud().append_log_lines([tr("这里没有{name}。").format({"name": "" if named == null else tr(named.display_name)})])
		return false
	var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
	var started: CombatSliceInitiationResult = session.combat_encounter_coordinator().start_servant_kill(
		CombatSliceProjectionBuilder.find_binding(participants, carrier.character_id),
		CombatSliceProjectionBuilder.find_binding(participants, target.character_id),
	)
	if started.outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		push_warning("the fight of %s against %s did not start: %s" % [carrier.character_id, target.character_id, started.outcome])
		return false
	var owner := ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)
	if not _map.floor_items.use_up_one(sheet_id, owner):
		push_error("putting %s on %s failed: the item state is inconsistent" % [sheet_id, carrier.character_id])
	carrier.set_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER, false)
	carrier.set_flag(NpcDefinition.FLAG_SENT, true)
	var line: String = tr(HauntScribe.KILL_LINE).replace("$N", tr(carrier.definition().display_name)).replace("$n", tr(target.definition().display_name))
	_map.hud().append_colored_lines([ColoredLine.new(line, ColoredLine.RED)])
	session.combat_encounter_coordinator().note_opening([line], [])
	return true


## The player as a spell or 符 file sees them (me).
func _player_side() -> SpecialSide:
	var state: CharacterState = _player.state
	var armor: ArmorState = _player.armor
	var side := SpecialSide.new(_player.character_id, state, _player.busy, _player.relationship, func(key: StringName) -> int: return PlayerMartialArts.apply_of(state, armor, key))
	side.is_user = true
	side.age = _player.facts.age
	side.location_id = _player.world_location().combat_location_id
	return side


## message_vision() as the player reads it: 你 for $N, `target` for $n.
func _vision(template: String, target: String) -> String:
	return tr(template).replace("$N", tr("你")).replace("$n", target)


## A spell's or 符's cost can leave the player below zero: char.c's next beat lets them fall.
func _after_cost() -> void:
	if _player.state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		_map.combat_lifecycle.player_fall_below_zero()


func _refresh_inventory() -> void:
	if _map.hud() != null and _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
