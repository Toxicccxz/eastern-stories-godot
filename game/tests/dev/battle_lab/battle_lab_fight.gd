class_name BattleLabFight
extends RefCounted

## Dev only (tests/dev/battle_lab.tscn, tests/dev/battle_lab/run_battle_lab.gd): any fight set up at
## will and fought as the game fights — the real coordinator and scheduler, each side's beats, NPC
## specials, 了结 / 放过, wounds. Nothing here is read by the game; tests/ never reaches a release.
##
## A spec (a Dictionary, as the panel and the command line write it):
##   {"place": zone id (an outdoor one with nobody of its own: ARENAS),
##    "player": {"family": family id or "" (the story-grown sword build), "level": n, "age": n (14: New
##               Game's; race/human.c's kee grows to 20, so an NPC of 30 has more at the same level)},
##    "allies": [fighter, ...], "foes": [fighter, ...] (at least one),
##    "seed": n}
## and a fighter {"family": family id} (that family's template, BattleLabRoster) or {"npc": definition
## id}, with "level" (0: as authored; a family's fighter at 0 is its template as authored) and
## "count" (1 when left out).
##
## The player always fights, on the first side, as every fight of the game has them (a 鬼仆's fight
## aside). The fight opens as the player's 攻击 on the first foe; the other foes come in on them
## (CombatJoin, killing back whoever kills them) and the allies at their side, as the 天将 do
## (CombatEncounterResolution.admit). The place is cleared first: the map's own people are taken off it.
##
## run(): `duels` fights from the same setup, everyone made whole before each, the player on the game's
## own 自动 (BattlePace.manual_turns off), the fallen let be (放过). A loss is the moment the player
## would have fallen: they fight on a buffer of BUFFER kee so no death flow runs, and the foes are worn
## down once it is lost (MainlineFightSim's way).

const Roster := preload("res://tests/dev/battle_lab/battle_lab_roster.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const Grown := preload("res://tests/support/grown_character.gd")
const SESSION_SCENE: String = "res://scenes/world/oldpine/oldpine_world_session.tscn"
const DEFAULT_PLACE: StringName = &"oldpine.outdoor.central_clearing"
## Outdoor places with nobody of their own and room to stand a crowd (a probe of the catalog's zones).
const ARENAS: Array[StringName] = [
	&"oldpine.outdoor.central_clearing", &"goathill.slope1", &"goathill.canyon2", &"green.field0",
	&"latemoon.bamboo", &"choyin.taolin", &"waterfog.frontyard", &"temple.square", &"cloud.cross", &"snow.sroad5",
]
const DEFAULT_WEAPON: StringName = &"es2:obj/longsword"
const PLAYER_AGE: int = 14
const BUFFER: int = 1000000
## Scheduler steps (a second of the fight's clock each) before a duel is called stuck.
const MAX_STEPS: int = 4000
const SPACING: float = 56.0


## One spec's run: each duel's end, and what they add up to.
class Result:
	extends RefCounted
	var duels: int = 0
	var wins: int = 0
	var stuck: int = 0
	var won_rounds: Array[int] = []
	var lost_rounds: Array[int] = []
	## The player's kee left at the end of each won duel, in percent of the most.
	var kee_left: Array[int] = []
	## Fighters on each side as the first duel had them in the fight (player included on ours).
	var ours_in: int = 0
	var theirs_in: int = 0
	var forecast: int = -1
	var notes: Array[String] = []

	func rate() -> float:
		return 0.0 if duels == 0 else float(wins) / float(duels)

	static func median(values: Array[int]) -> int:
		if values.is_empty():
			return -1
		var sorted: Array[int] = values.duplicate()
		sorted.sort()
		return sorted[sorted.size() / 2]

	func summary() -> String:
		var lines: Array[String] = []
		lines.append("胜 %d / %d（%.0f%%）%s" % [wins, duels, rate() * 100.0, "，卡住 %d" % stuck if stuck > 0 else ""])
		lines.append("阵容：我方 %d 人，对方 %d 人；战前预判 %s" % [ours_in, theirs_in, BattleLabFight.verdict_word(forecast)])
		lines.append("胜场回合中位 %s，败场回合中位 %s" % [_text(median(won_rounds)), _text(median(lost_rounds))])
		lines.append("胜场剩余气血中位 %s" % ("—" if kee_left.is_empty() else "%d%%" % median(kee_left)))
		for note: String in notes:
			lines.append("注：" + note)
		return "\n".join(lines)

	static func _text(value: int) -> String:
		return "—" if value < 0 else str(value)


var tree: SceneTree
var session: WorldSessionController
var map: WorldMapController
var spec: Dictionary = {}
var allies: Array[NpcRuntimeState] = []
var foes: Array[NpcRuntimeState] = []
## What went wrong setting up, or "".
var error: String = ""
## The player's side in the fight start_live() opened.
var player_side: StringName = &""
## Print each duel's end (run_battle_lab.gd's `verbose`).
var verbose: bool = false
var _made: Array[NpcRuntimeState] = []
## Where the player stood as the place was set up: everyone is put back round it.
var _origin: Vector2 = Vector2.ZERO
## Weapons made for the player so far (each one's id counts on).
var _weapons_made: int = 0
## The seed the fighters are made from, the same for every duel of a setup (spec "seed"; 0: one drawn).
var _npc_seed: int = 1
## A duel the fight could not be closed after: the batch stops there.
var _broken: bool = false


func _init(p_tree: SceneTree) -> void:
	tree = p_tree


## A fresh New Game session under `parent` (the tree's root when null), the world's time still.
func make_session(parent: Node = null) -> void:
	await close()
	session = (load(SESSION_SCENE) as PackedScene).instantiate() as WorldSessionController
	session.configure_source_entry("试战", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	(parent if parent != null else tree.root).add_child(session)
	for frame: int in 4:
		await tree.process_frame


func close() -> void:
	if session != null and is_instance_valid(session):
		session.queue_free()
		await tree.process_frame
	session = null
	map = null
	_made.clear()


## Everyone put where `p_spec` says, nobody fighting yet. False (and `error`) when it could not be.
func setup(p_spec: Dictionary) -> bool:
	spec = p_spec
	error = ""
	_broken = false
	var seed: int = int(spec.get("seed", 0))
	_npc_seed = seed if seed != 0 else randi_range(1, 999999)
	if session == null:
		await make_session()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if coordinator.has_active_encounter() or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		await make_session()
		player = session.player_runtime()
	# The world's clock held while everyone is put down: nobody falls on the player before the fight.
	session.set_process(false)
	_take_away_made()
	if (spec.get("foes", []) as Array).is_empty():
		return _fail("对方至少要有一个人")
	if not await _enter(StringName(str(spec.get("place", DEFAULT_PLACE)))):
		return false
	_clear_place()
	if not _make_player(spec.get("player", {})):
		return false
	_origin = map.player_body.global_position
	if not _place_sides():
		return false
	await _settle()
	return true


## The fight opened: the player's 攻击 on the first foe, the rest coming in. False when it would not.
func start() -> bool:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player_id: StringName = session.player_runtime().character_id
	map.select_npc(foes[0].character_id)
	map.attack_selected()
	if not coordinator.has_active_encounter():
		return _fail("开不了战：%s" % coordinator.last_abort_detail())
	var encounter: CombatEncounter = coordinator.active_encounter()
	var joins: Array[CombatJoin] = []
	for npc: NpcRuntimeState in foes:
		if encounter.participant_for(npc.character_id) == null:
			joins.append(CombatJoin.new(npc.character_id, [player_id], true))
	var ally_ids: Array[StringName] = []
	for npc: NpcRuntimeState in allies:
		ally_ids.append(npc.character_id)
	coordinator.resolution().admit(session.encounter_combat_bindings(encounter), CombatTacticalExecutionResult.new(CombatTacticalExecutionResult.Outcome.APPLIED).with_joins(joins).with_allies(ally_ids))
	return true


## The set-up fight opened to be played: the spec's seed on the fight's dice (0: any), the world's
## clock running, the battle shown as the game shows it. False (and `error`) when it would not open.
func start_live() -> bool:
	var seed: int = int(spec.get("seed", 0))
	session.configure_combat_random_source(_Seeded.new(seed if seed != 0 else randi()))
	var opened: bool = start()
	if opened:
		player_side = session.combat_encounter_coordinator().active_encounter().participant_for(session.player_runtime().character_id).side_id
	session.set_process(true)
	return opened


## Who stands in the running fight on each side: [ours (player included), theirs].
func lineup() -> Array[int]:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	if not coordinator.has_active_encounter():
		return [0, 0]
	var encounter: CombatEncounter = coordinator.active_encounter()
	var ours: int = 1 if encounter.participant_for(session.player_runtime().character_id) != null else 0
	var theirs: int = 0
	for npc: NpcRuntimeState in allies:
		ours += 1 if encounter.participant_for(npc.character_id) != null else 0
	for npc: NpcRuntimeState in foes:
		theirs += 1 if encounter.participant_for(npc.character_id) != null else 0
	return [ours, theirs]


## `duels` fights of the set-up spec from `seed`, the world held between them.
func run(duels: int, seed: int = 7, each: Callable = Callable()) -> Result:
	var result := Result.new()
	var paces: Array = [BattlePace.manual_turns, BattlePace.after_knockout, BattlePace.opening]
	BattlePace.manual_turns = false
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	BattlePace.opening = BattlePace.Opening.OFF
	session.set_process(false)
	session.configure_combat_random_source(_Seeded.new(seed if seed != 0 else randi()))
	for duel: int in duels:
		if _broken:
			break
		await _reset()
		if duel == 0:
			var forecast: CombatForecast = CombatForecastBuilder.for_attack(map, foes[0])
			result.forecast = -1 if forecast == null else forecast.verdict
		await _duel(result, duel == 0)
		if each.is_valid():
			each.call(duel + 1, result)
	session.set_process(true)
	BattlePace.manual_turns = paces[0]
	BattlePace.after_knockout = paces[1]
	BattlePace.opening = paces[2]
	return result


func _duel(result: Result, first: bool) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var s: CharacterState = player.state
	var real: int = s.vitality.maximum
	if not start():
		if not result.notes.has(error):
			result.notes.append(error)
		result.stuck += 1
		return
	var counts: Array[int] = lineup()
	if first:
		result.ours_in = counts[0]
		result.theirs_in = counts[1]
	var my_side: StringName = coordinator.active_encounter().participant_for(player.character_id).side_id
	s.vitality = CharacterResourceState.new(real + BUFFER, real + BUFFER, real + BUFFER)
	var lost: bool = false
	var rounds: int = 0
	var lost_at: int = 0
	var steps: int = 0
	while coordinator.has_active_encounter() and steps < MAX_STEPS:
		steps += 1
		for victim: StringName in coordinator.held_victims():
			coordinator.spare_downed(victim)
		coordinator.advance_scheduler(1.0)
		if coordinator.has_active_encounter() and coordinator.active_scheduler() != null:
			rounds = coordinator.active_scheduler().rounds_completed()
		if not lost and (s.vitality.current < BUFFER or s.vitality.effective < BUFFER):
			lost = true
			lost_at = rounds
		if lost:
			# Lost: the foes dropped so the fight closes (what follows counts for nothing).
			for npc: NpcRuntimeState in foes:
				if npc.character_state.vitality.current >= 0:
					npc.character_state.vitality = CharacterResourceState.new(-1, 1, npc.character_state.vitality.maximum)
	if coordinator.has_active_encounter():
		result.stuck += 1
		for npc: NpcRuntimeState in foes:
			npc.character_state.vitality = CharacterResourceState.new(-1, 1, npc.character_state.vitality.maximum)
		for step: int in 200:
			if not coordinator.has_active_encounter():
				break
			coordinator.advance_scheduler(1.0)
		session.shared_ui().dismiss_current_panel()
		s.vitality = CharacterResourceState.new(real, real, real)
		if coordinator.has_active_encounter():
			_broken = true
			result.notes.append("有一场打了 %d 步还收不了场，批量就此停下" % (MAX_STEPS + 200))
		return
	session.shared_ui().dismiss_current_panel()
	var left: int = s.vitality.current - BUFFER
	s.vitality = CharacterResourceState.new(real, real, real)
	var completion: CombatEncounterCompletionResult = coordinator.last_completion()
	var ending: CombatEncounterResult = null if completion == null else completion.terminal_result
	if not lost and (player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or ending == null or ending.kind != CombatEncounterResultKind.Value.VICTORY or not ending.winning_side_ids().has(my_side)):
		lost = true
		lost_at = rounds
		var note: String = "有一场以「%s」收场" % ending_word(ending, my_side)
		if not result.notes.has(note):
			result.notes.append(note)
	result.duels += 1
	if verbose:
		var sides: Array = (allies + foes).map(func(npc: NpcRuntimeState) -> String: return "%s %d/%d %s" % [npc.definition().display_name, npc.character_state.vitality.current, npc.character_state.vitality.maximum, CharacterRuntimeLifeStatus.Value.find_key(npc.life_status)])
		print("  %s 回合 %d（输在 %d）步 %d 我 %d/%d %s" % ["输" if lost else "赢", rounds, lost_at, steps, left, real, sides])
	if lost:
		result.lost_rounds.append(lost_at)
	else:
		result.wins += 1
		result.won_rounds.append(rounds)
		result.kee_left.append(clampi(roundi(100.0 * float(left) / float(maxi(real, 1))), 0, 100))


## Everyone back as set up: whole, standing, nobody's fight remembered, the corpses gone.
func _reset() -> void:
	for corpse: CorpseState in map.corpses._corpse_states.duplicate():
		map.corpses._destruct_corpse(corpse)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	# One that lay unconscious (精 or 神 run out: the buffer covers only kee) is stood up again.
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
		player.set_combat_available(true)
		map.player_body.refresh_runtime_state()
	_make_player(spec.get("player", {}))
	_forget(player.relationship)
	player.busy.restore(0, 0)
	# The game takes the summoned away as a fight ends (WorldMapNpcs.dismiss_summoned()): both
	# sides are made anew, as the spec has them.
	_take_away_made()
	if not map.place_player(session.player_runtime().world_location().zone_id, _origin):
		_fail("站不回原地")
	_place_sides()
	await _settle()


## Both sides made as the spec has them, round where the player stood. False (and `error`) when not.
func _place_sides() -> bool:
	# The same people every time: their ages, names and drawn attributes from one seed.
	var stream: GodotNpcInitializationRandomSource = map.npc_random_source() as GodotNpcInitializationRandomSource
	if stream != null:
		stream.configure_seed(_npc_seed)
	allies = _make_side(spec.get("allies", []), _origin, -1.0)
	if error.is_empty():
		foes = _make_side(spec.get("foes", []), _origin + Vector2(SPACING * 3.0, 0.0), 1.0)
	return error.is_empty()


## The lab's own people still on the map taken off it.
func _take_away_made() -> void:
	for npc: NpcRuntimeState in _made:
		if map != null and map.npcs.find_resident_npc(npc.character_id) != null:
			map.npcs.destruct_summoned(npc)
	_made.clear()
	allies.clear()
	foes.clear()


func _forget(relationship: CombatRelationshipState) -> void:
	for id: StringName in relationship.lethal_target_ids():
		relationship.remove_lethal_relation(id)
	relationship.clear_opponents_preserving_lethal_targets()
	relationship.clear_last_opponent()
	relationship.clear_last_damage_from()


func _enter(zone_id: StringName) -> bool:
	var zone: ZoneDefinition = GameContent.catalog().zone(zone_id)
	if zone == null:
		return _fail("没有这个地方：%s" % zone_id)
	var target: WorldMapController = session.resident_map(zone.map_id) as WorldMapController
	if target == null:
		return _fail("没有这张图：%s" % zone.map_id)
	var spot: Vector2 = MapPlaces.zone_spot(target, zone_id)
	if session.active_map_id() == zone.map_id:
		if not target.place_player(zone_id, spot):
			return _fail("站不进 %s" % zone_id)
	elif not session.handoff_to_point(zone.map_id, zone_id, zone_id, spot).succeeded():
		return _fail("进不去 %s" % zone_id)
	await _settle()
	map = session.active_map() as WorldMapController
	return map != null and map.map_id() == zone.map_id


## The map's own people taken off it, so nobody but the lab's comes into the fight.
func _clear_place() -> void:
	for npc: NpcRuntimeState in map.npcs.residents.duplicate():
		if npc.exists_in_map:
			map.npcs.withdraw(npc)


## The player made as `facts` say, the weapon taken up again (a duel may have knocked it away or
## broken it: WorldMapCombatLifecycle's bash).
func _make_player(facts: Dictionary) -> bool:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var level: int = maxi(int(facts.get("level", 20)), 1)
	var family_id: StringName = StringName(str(facts.get("family", "")))
	var age: int = clampi(int(facts.get("age", PLAYER_AGE)), PLAYER_AGE, 60)
	var weapon: StringName = DEFAULT_WEAPON
	if family_id.is_empty():
		Roster.clear_martial(player.state)
		Grown.grow(player.state, Roster.experience_for(level), Roster.FORCE_PERCENT, true)
		CharacterDerivedValues.refresh_human_player_maxima(player.state, age)
		Roster.heal(player.state)
	else:
		var family: BattleLabRoster.Family = Roster.family(family_id)
		if family == null:
			return _fail("没有这个门派：%s" % family_id)
		var template: NpcDefinition = GameContent.catalog().npc(family.template_id)
		Roster.level_player(player.state, template, level, age)
		weapon = Roster.weapon_of(template)
	player.state.attributes.force_factor = 0
	_wield(weapon)
	return true


func _make_side(fighters: Array, origin: Vector2, direction: float) -> Array[NpcRuntimeState]:
	var out: Array[NpcRuntimeState] = []
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var zone_id: StringName = player.world_location().zone_id
	var index: int = 0
	for raw: Variant in fighters:
		var fighter: Dictionary = raw
		var definition: NpcDefinition = _definition_of(fighter)
		if definition == null:
			return out
		for copy: int in maxi(int(fighter.get("count", 1)), 1):
			@warning_ignore("integer_division")
			var near: Vector2 = origin + Vector2(direction * SPACING * float(index / 3 + 1), SPACING * float(index % 3 - 1))
			index += 1
			var spot: Vector2 = MapPlaces.spot(map, zone_id, near, 160.0)
			if spot == Vector2.INF:
				_fail("站不下这么多人（%s）" % definition.display_name)
				return out
			var npc: NpcRuntimeState = map.npcs._new_summoned(definition, player.world_location(), spot, player.character_id)
			if npc == null:
				_fail("做不出 %s" % definition.definition_id)
				return out
			_made.append(npc)
			Roster.level_npc(npc, int(fighter.get("level", 0)))
			if direction < 0.0:
				map.npcs.summoners[npc.character_id] = player.character_id
				npc.set_flag(NpcDefinition.FLAG_FOLLOWS_PLAYER, true)
			out.append(npc)
	return out


func _definition_of(fighter: Dictionary) -> NpcDefinition:
	var npc_id: String = str(fighter.get("npc", ""))
	if npc_id.is_empty():
		var family: BattleLabRoster.Family = Roster.family(StringName(str(fighter.get("family", ""))))
		if family == null:
			_fail("没有这个门派：%s" % fighter.get("family", ""))
			return null
		npc_id = String(family.template_id)
	var definition: NpcDefinition = GameContent.catalog().npc(StringName(npc_id))
	if definition == null:
		_fail("没有这个人：%s" % npc_id)
	return definition


## What the player holds: whatever was in their hands put away, `definition_id` taken up (bare-handed
## when it is empty or no item). Each weapon is made once per session and kept in the pack.
func _wield(definition_id: StringName) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var adapter := OldPineEquipmentInteractionAdapter.new()
	for weapon: EquippedWeaponRef in [player.state.equipment.primary_weapon(), player.state.equipment.secondary_weapon()]:
		if weapon != null:
			adapter.unwield(player, weapon.instance_id, session._inventory)
	if definition_id.is_empty() or GameContent.catalog().item(definition_id) == null:
		return
	var context: MoneyInventoryContext = MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor),
		session.inventory_state(), session.stack_collection(), session.item_instance_index())
	# The one made before, if it is still that weapon and still the player's; else a new one (the old
	# one lies where it was knocked, or is what its breaking turned it into).
	var held := StringName("lab:%s:%d" % [definition_id, _weapons_made])
	var kept: ItemInstance = context.index.resolve(held) if context.index.has_snapshot(held) else null
	if kept == null or kept.item_definition_id != definition_id or not context.inventory.is_direct_child(held, context.endpoint()):
		_weapons_made += 1
		held = StringName("lab:%s:%d" % [definition_id, _weapons_made])
		var item := ItemInstance.new(held, definition_id)
		context.inventory.register_item(item, GameContent.catalog().item(definition_id).own_weight)
		context.index.register_snapshot(item)
		context.inventory._apply_reparent(item.item_instance_id, context.endpoint())
	adapter.wield(player, held, session._inventory, session._item_index)


func _settle() -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _fail(message: String) -> bool:
	error = message
	return false


## A fight's end in words (null: none).
static func ending_word(ending: CombatEncounterResult, my_side: StringName) -> String:
	if ending == null:
		return "—"
	match ending.kind:
		CombatEncounterResultKind.Value.VICTORY: return "我方胜" if ending.winning_side_ids().has(my_side) else "对方胜"
		CombatEncounterResultKind.Value.DEFEAT: return "我方败"
		CombatEncounterResultKind.Value.FLED: return "有人逃了"
	return str(CombatEncounterResultKind.Value.find_key(ending.kind))


static func life_word(status: int) -> String:
	match status:
		CharacterRuntimeLifeStatus.Value.ACTIVE: return "站着"
		CharacterRuntimeLifeStatus.Value.UNCONSCIOUS: return "昏过去了"
		CharacterRuntimeLifeStatus.Value.DEAD: return "死了"
	return "?"


static func verdict_word(verdict: int) -> String:
	match verdict:
		CombatForecast.Verdict.SURE_WIN: return "稳赢"
		CombatForecast.Verdict.FAVOURED: return "占优"
		CombatForecast.Verdict.EVEN: return "五五开"
		CombatForecast.Verdict.UNFAVOURED: return "吃亏"
		CombatForecast.Verdict.SURE_LOSS: return "必败"
	return "—"


class _Seeded extends CombatRandomSource:
	var _rng := RandomNumberGenerator.new()
	func _init(seed_value: int) -> void:
		_rng.seed = seed_value
	func next_below(bound: int) -> int:
		return _rng.randi_range(0, bound - 1)
