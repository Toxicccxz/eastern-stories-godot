class_name PlayerEssenceMagic
extends RefCounted

## The player's 神通 (cmds/std/conjure.c with 八识神通 enabled as 法术), outside a fight
## (DECISIONS 山烟寺 C): 空识 and 游识 from the 武学 page, 心识 on the HUD for the selected
## NPC lying unconscious. 游识's question lists the NPCs the player has met in a room
## (CharacterState.seen_npcs; owner: DECISIONS 山烟寺 A Q3) and goes to one of that name
## wherever it is now, on this map first. The lines go to the log; `last_lines` keeps them
## for the page. Every request does nothing while portable actions are closed: in a fight,
## unconscious, between maps.
const VOID_SENSE: StringName = &"void_sense"
const HEART_SENSE: StringName = &"heart_sense"
const DRIFT_SENSE: StringName = &"drift_sense"
## How far from the NPC's centre 游识 puts the player (34 px bodies, so they never overlap).
const BESIDE: Array[int] = [48, 64, 96, 44]

var last_lines: Array[ColoredLine] = []
var _session: WorldSessionController


func _init(session: WorldSessionController) -> void:
	_session = session


func available() -> bool:
	return _session != null and _session.portable_inventory_available()


## The 神通 the enabled magic skill reaches.
func offered() -> Array[StringName]:
	var player: WorldPlayerRuntimeState = null if _session == null else _session.player_runtime()
	if player == null:
		return []
	return ConjureService.offered(player.state, GameContent.catalog())


## Those conjured at oneself (空识, 游识): the 武学 page's buttons.
func self_conjures() -> Array[StringName]:
	var out: Array[StringName] = []
	for function_id: StringName in offered():
		if not SpecialFunctions.conjure(function_id).targets_other:
			out.append(function_id)
	return out


# --- 空识神通 -----------------------------------------------------------------------

## Whether 空识 now would leave the player below zero gin (void_sense.c takes 50 and asks
## only for atman): they would fall unconscious (owner's rule: asked first). Not when
## conjure.c or the file would refuse anyway.
func void_knocks_out() -> bool:
	return _goes_ahead(VOID_SENSE, VoidSenseConjure.ATMAN_COST) and _state().essence.current < VoidSenseConjure.GIN_COST


## conjure void_sense: its lines or refusal; potential may rise or fall.
func void_sense() -> bool:
	if not available():
		return false
	var context: SpecialContext = _context()
	var conjured: bool = ConjureService.conjure(context, VOID_SENSE, _no_magic())
	_show(context, "")
	_fall_if_spent(_session.active_map() as WorldMapController)
	return conjured


# --- 游识神通 -----------------------------------------------------------------------

## conjure drift_sense: true when it asks whom to go to (DriftSenseConjure.PROMPT; the
## caller shows drift_names()), else its refusal is in the log.
func drift_begin() -> bool:
	if not available():
		return false
	var context: SpecialContext = _context()
	var asks: bool = ConjureService.conjure(context, DRIFT_SENSE, _no_magic())
	if not asks:
		_show(context, "")
	return asks


## The names the question offers: each kind of NPC the player has met, one line a name
## (authored, as NpcDefinition.display_name), in the order first met.
func drift_names() -> Array[String]:
	var out: Array[String] = []
	if _session == null or _session.player_runtime() == null:
		return out
	var seen: Dictionary[String, int] = _state().seen_npcs
	var ids: Array[String] = seen.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return seen[a] < seen[b])
	for id: String in ids:
		var definition: NpcDefinition = GameContent.catalog().npc(StringName(id))
		if definition != null and not out.has(definition.display_name):
			out.append(definition.display_name)
	return out


## find_living(name): the NPC called `name` (a kind the player has met) that is in the
## world now and awake (MudOS find_living() skips one whose commands unconcious() disabled):
## on the player's map first, then map by map. Null when there is none (dead, lying
## unconscious, or not come back yet).
func drift_target(name: String) -> NpcRuntimeState:
	var player: WorldPlayerRuntimeState = null if _session == null else _session.player_runtime()
	if player == null:
		return null
	var maps: Array[WorldMapController] = _session.world_maps()
	var here: WorldMapController = _session.active_map() as WorldMapController
	if here != null and maps.has(here):
		maps.erase(here)
		maps.push_front(here)
	for map: WorldMapController in maps:
		for npc: NpcRuntimeState in map.npc_runtimes():
			if (
				npc.exists_in_map and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
				and npc.definition().display_name == name and player.state.seen_npcs.has(String(npc.definition_id))
				and npc.world_location() != null and npc.world_location().map_id == map.map_id()
			):
				return npc
	return null


## Whether going to the one called `name` now would leave the player below zero gin
## (drift_sense.c takes 30 once it found them): asked first.
func drift_knocks_out(name: String) -> bool:
	return (
		_goes_ahead(DRIFT_SENSE, DriftSenseConjure.ATMAN_COST) and not _fighting()
		and drift_target(name) != null and _state().essence.current < DriftSenseConjure.GIN_COST
	)


## select_target() with `name`: false when nobody of that name is found (你无法感受到这个人
## 的灵力, the question stays); true once the conjuring is over, the player beside the one
## found when it worked.
func drift_to(name: String) -> bool:
	if not available():
		return false
	var npc: NpcRuntimeState = drift_target(name)
	# Where they stand is found before anything is spent; none (never so far) counts as not found.
	var spot: Vector2 = Vector2.INF if npc == null else _spot_beside(npc)
	var context: SpecialContext = _context()
	if npc != null and spot.is_finite():
		context.target = SpecialSide.new(npc.character_id, npc.character_state, npc.busy, npc.relationship)
	var over: bool = (SpecialFunctions.conjure(DRIFT_SENSE) as DriftSenseConjure).select_target(context)
	_show(context, "")
	var arrived: WorldMapController = _session.active_map() as WorldMapController
	if context.drifted and _move_beside(npc, spot):
		arrived = _session.active_map() as WorldMapController
		if arrived != null and arrived.hud() != null:
			arrived.hud().describe_arrival()
	_fall_if_spent(arrived)
	return over


## A spot in the NPC's room beside it, clear of its body, on open ground and off any open
## passage; INF when there is none.
func _spot_beside(npc: NpcRuntimeState) -> Vector2:
	var map: WorldMapController = _session.world_map_of(npc.world_location().map_id)
	var origin: Vector2 = Vector2.INF if map == null else map.npc_rest_position(npc.character_id)
	if not origin.is_finite():
		return Vector2.INF
	for distance: int in BESIDE:
		for direction: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var spot: Vector2 = (origin + direction.normalized() * distance).round()
			if MapPlacementValidator.is_valid_character_position(map, npc.world_location().zone_id, spot) and not map.point_in_passage(spot):
				return spot
	return Vector2.INF


## me->move(environment(ob)): into the NPC's room at `spot`; onto its map when it is on
## another one.
func _move_beside(npc: NpcRuntimeState, spot: Vector2) -> bool:
	var map: WorldMapController = _session.world_map_of(npc.world_location().map_id)
	var location: WorldLocationState = null if map == null else map.location_for_zone(npc.world_location().zone_id)
	if location == null:
		return false
	if map == _session.active_map():
		if not map.place_player(location.zone_id, spot):
			push_error("drift_sense could not put the player beside %s" % npc.character_id)
			return false
		var camera: Camera2D = map.player_body.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.reset_smoothing()
		return true
	var moved: OldPineMapHandoffResult = _session.handoff_to_point(map.map_id(), location.zone_id, location.combat_location_id, spot)
	if not moved.succeeded():
		push_error("drift_sense could not reach %s on %s: %s" % [npc.character_id, map.map_id(), moved.outcome])
	return moved.succeeded()


# --- 心识神通 -----------------------------------------------------------------------

## The one the HUD offers 心识 on: the selected NPC lying unconscious in the player's place,
## when the enabled magic skill reaches heart_sense.c (DECISIONS 山烟寺 C). Null otherwise.
func heart_target() -> NpcRuntimeState:
	if not offered().has(HEART_SENSE):
		return null
	var map: WorldMapController = _session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null if map == null else map.selected_npc_here()
	return npc if npc != null and npc.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS else null


## Whether 心识 on the selected NPC would go ahead (and so may knock the player out):
## the HUD asks first; a refusal it does not.
func heart_asks() -> bool:
	return heart_target() != null and _goes_ahead(HEART_SENSE, HeartSenseConjure.ATMAN_COST)


## conjure heart_sense on the selected NPC: its line, then it wakes, or the player falls
## unconscious (asked first: it may always).
func heart_sense() -> bool:
	if not available():
		return false
	var npc: NpcRuntimeState = heart_target()
	var map: WorldMapController = _session.active_map() as WorldMapController
	if npc == null or map == null:
		return false
	var context: SpecialContext = _context()
	var target := SpecialSide.new(npc.character_id, npc.character_state, npc.busy, npc.relationship)
	target.living = false
	context.target = target
	var conjured: bool = ConjureService.conjure(context, HEART_SENSE, _no_magic())
	_show(context, TranslationServer.translate(npc.definition().display_name))
	if context.revived:
		map.npc_life.revive(npc)
	if context.fainted:
		_state().fall_unconscious()
	_fall_if_spent(map)
	return conjured


# --- Shared --------------------------------------------------------------------------

## The player as a 神通 file sees them (me).
func _player_side() -> SpecialSide:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var state: CharacterState = player.state
	var armor: ArmorState = player.armor
	var side := SpecialSide.new(player.character_id, state, player.busy, player.relationship, func(key: StringName) -> int: return PlayerMartialArts.apply_of(state, armor, key))
	side.is_user = true
	side.age = player.facts.age
	side.location_id = player.world_location().combat_location_id
	return side


func _context() -> SpecialContext:
	return SpecialContext.new(_player_side(), [], _session.world_interaction_random_source().legacy_random, GameContent.catalog(), _session.encounter_skill_effect_registry())


func _no_magic() -> bool:
	return GameContent.catalog().zone_forbids_magic(_session.player_runtime().world_location().zone_id)


func _state() -> CharacterState:
	return _session.player_runtime().state


func _fighting() -> bool:
	return _session.player_runtime().relationship.is_fighting()


## conjure.c and the file go ahead with `function_id` and its atman: not busy, not where
## magic is forbidden, the file reached, enough atman.
func _goes_ahead(function_id: StringName, atman_cost: int) -> bool:
	return (
		available() and offered().has(function_id) and not _session.player_runtime().busy.is_busy()
		and not _no_magic() and _state().recovery.atman.current >= atman_cost
	)


## The file's lines (or its refusal) as the player reads them: 你 for $N, `target` for $n.
func _show(context: SpecialContext, target: String) -> void:
	var lines: Array[ColoredLine] = []
	for line: VisionLine in context.report().lines():
		lines.append(ColoredLine.new(TranslationServer.translate(line.template).replace("$N", TranslationServer.translate("你")).replace("$n", target), line.color))
	last_lines = lines
	var hud: SharedGameplayUI = _session.shared_ui()
	if hud != null and not lines.is_empty():
		hud.append_colored_lines(lines)


## A 神通's cost below zero (or heart_sense.c's unconcious()): char.c's next beat lets the
## player fall, where they are now.
func _fall_if_spent(map: WorldMapController) -> void:
	if map != null and _state().life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		map.player_fall_below_zero()


## The player meets `npc` in their room (an NPC's init() seeing them, or them coming in):
## a kind not met before joins 游识's list. One conjured, raised or summoned (`summoned`:
## it leaves with its fight or its master) is not listed, nor one dead or away.
static func meet(state: CharacterState, npc: NpcRuntimeState, summoned: bool) -> void:
	if state == null or npc == null or summoned or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
		return
	var definition: NpcDefinition = npc.definition()
	if definition.conjuring() != null or definition.raising() != null:
		return
	var key: String = String(definition.definition_id)
	if not state.seen_npcs.has(key):
		state.seen_npcs[key] = state.seen_npcs.size() + 1
