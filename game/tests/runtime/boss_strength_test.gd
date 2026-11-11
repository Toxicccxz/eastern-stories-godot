extends RefCounted

## DECISIONS「主线必打的仗」(owner 2026-11-10「按这个调」): the fights the main story cannot be got past
## without, fought as they are — the whole group and the allies always there — by a character grown to
## the story path's arrival exp (the lower trajectory; tests/support/grown_character.gd, a sword build).
## ROUNDS duels each with a fixed seed and the game's own resolver (the duel of
## build/strength/fights_probe.gd): each round the player and each ally strike the first standing enemy
## once, then each standing enemy strikes one of the player's side drawn evenly; ripostes and wounds in,
## beats, specials, stances and guarding left out (a conservative read). The target is about six in ten
## without help and nine in ten with the story's own helpers; the bands are wide: they flag a retune
## when the numbers or growth move, not the exact rate. Provisional until growth is set.
## 第一章's 黑衣道士 is the first two hours' (tuned and pinned there); 第九章 揭发's 庾子建 with 冯策 beside
## is a choice's fight (DECISIONS「主线人物的武功」), kept here as before.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Grown := preload("res://tests/support/grown_character.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const ROUNDS: int = 20
const MAX_ROUNDS: int = 600

const FIGHTS: Array[Dictionary] = [
	{"label": "第三章 祭坛 鬼卒×2", "zone": &"niling.altar", "point": &"niling.altar.hell_runner.1", "enemies": [["niling.altar.hell_runners", "niling.altar.hell_runner.1"], ["niling.altar.hell_runners", "niling.altar.hell_runner.2"]], "allies": [], "exp": 4695, "weapon": &"es2:obj/longsword", "low": 0.30, "high": 0.90}, # the probe: 60%
	{"label": "第三章 救人 带钥匙的狱卒×2", "zone": &"niling.corridor", "point": &"niling.corridor.jailer_keyed.1", "enemies": [["niling.corridor.jailers_keyed", "niling.corridor.jailer_keyed.1"], ["niling.corridor.jailers_keyed", "niling.corridor.jailer_keyed.2"]], "allies": [], "exp": 4695, "weapon": &"es2:obj/longsword", "low": 0.40, "high": 0.95}, # the probe: 70%
	{"label": "第五章 树洞 鬼卒×2", "zone": &"choyin.tomb3", "point": &"choyin.tomb3.hell_runner.1", "enemies": [["native.tomb3.hell_runners", "choyin.tomb3.hell_runner.1"], ["native.tomb3.hell_runners", "choyin.tomb3.hell_runner.2"]], "allies": [], "exp": 8442, "weapon": &"es2:obj/longsword", "low": 0.70, "high": 1.00}, # the probe: 100%
	{"label": "第六章 借兵 踏平工地", "zone": &"guanbei.fence_gate", "point": &"guanbei.fence_gate.pei_zhao.1", "enemies": [["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.1"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.2"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.3"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.4"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.5"], ["guanbei.fence_gate.officers_fighting", "guanbei.fence_gate.officer_fighting.6"], ["guanbei.fence_gate.pei_zhao", "guanbei.fence_gate.pei_zhao.1"], ["guanbei.fence_gate.lu_sun", "guanbei.fence_gate.lu_sun.1"]], "allies": [["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.1"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.2"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.3"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.4"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.5"], ["guanbei.fence_gate.riders", "guanbei.fence_gate.rider.6"]], "exp": 11625, "weapon": &"es2:obj/longsword", "low": 0.70, "high": 1.00}, # the probe: 90%, six 王府骑兵 beside
	{"label": "第六章 潜入 守夜武官×2", "zone": &"guanbei.sheds", "point": &"guanbei.sheds.night_watch_fighting.1", "enemies": [["guanbei.sheds.night_watch_fighting", "guanbei.sheds.night_watch_fighting.1"], ["guanbei.sheds.night_watch_fighting", "guanbei.sheds.night_watch_fighting.2"]], "allies": [], "exp": 11625, "weapon": &"es2:obj/longsword", "low": 0.40, "high": 0.95}, # the probe: 70%, 郭承 left out (he stands on another map)
	{"label": "终章 冰龙厅 商玦", "zone": &"village.lakebottom2", "point": &"village.lakebottom2.shang_jue_fighting.1", "enemies": [["native.lakebottom2.shang_jue_fighting", "village.lakebottom2.shang_jue_fighting.1"]], "allies": [], "exp": 37275, "weapon": &"native:lancheng/xuanmang", "low": 0.40, "high": 0.95}, # the probe: 68%
	{"label": "终章 冰龙厅 商玦+四道士（打过冰龙）", "zone": &"village.lakebottom2", "point": &"village.lakebottom2.shang_jue_fighting.1", "enemies": [["native.lakebottom2.shang_jue_fighting", "village.lakebottom2.shang_jue_fighting.1"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.1"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.2"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.3"], ["native.lakebottom2.niling_finale", "village.lakebottom2.niling_finale.4"]], "allies": [], "exp": 37275, "weapon": &"native:lancheng/xuanmang", "low": 0.25, "high": 0.85}, # the probe: 55%
	{"label": "终章 侮天鬼（穿宝衣·没拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.1", "enemies": [["native.seal_altar.wutian_gui", "village.seal_altar.demon.1"]], "allies": [], "exp": 37275, "weapon": &"native:lancheng/xuanmang", "low": 0.55, "high": 1.00}, # the probe: 85%
	{"label": "终章 侮天鬼（没宝衣·没拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.2", "enemies": [["native.seal_altar.wutian_gui_blazing", "village.seal_altar.demon.2"]], "allies": [], "exp": 37275, "weapon": &"native:lancheng/xuanmang", "low": 0.45, "high": 1.00}, # the probe: 73%
	{"label": "终章 侮天鬼（穿宝衣·拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.3", "enemies": [["native.seal_altar.wutian_gui_grown", "village.seal_altar.demon.3"]], "allies": [], "exp": 37275, "weapon": &"native:lancheng/xuanmang", "low": 0.45, "high": 1.00}, # the probe: 73%
	{"label": "终章 侮天鬼（没宝衣·拔过）", "zone": &"village.seal_altar", "point": &"village.seal_altar.demon.4", "enemies": [["native.seal_altar.wutian_gui_grown_blazing", "village.seal_altar.demon.4"]], "allies": [], "exp": 37275, "weapon": &"native:lancheng/xuanmang", "low": 0.40, "high": 1.00}, # the probe: 70%
	{"label": "第九章 揭发 庾子建（冯策并肩）", "zone": &"imperial.throne_hall", "point": &"imperial.throne_hall.yu_drawn.1", "enemies": [["imperial.throne_hall.yu_drawn", "imperial.throne_hall.yu_drawn.1"]], "allies": [["imperial.throne_hall.feng_ce_beside", "imperial.throne_hall.feng_ce_beside.1"]], "exp": 32234, "weapon": &"es2:obj/longsword", "low": 0.40, "high": 0.95}, # the probe: 73%
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for fight: Dictionary in FIGHTS:
		var rate: float = await _rate(tree, fight)
		_check(rate >= float(fight["low"]) and rate <= float(fight["high"]), "%s at %d exp: won %.0f%% (%.0f–%.0f%%)" % [fight["label"], fight["exp"], rate * 100.0, float(fight["low"]) * 100.0, float(fight["high"]) * 100.0])
	return {"assertions": _count, "failures": _failures.duplicate()}


## The share of ROUNDS duels won, or -1 when the fight could not be set up.
func _rate(tree: SceneTree, fight: Dictionary) -> float:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("强度", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new())
	var rate: float = -1.0
	var map: WorldMapController = MapPlaces.enter(session, fight["zone"], fight["point"])
	await _settle(tree)
	var enemies: Array[NpcRuntimeState] = _bring_all(map, fight["enemies"])
	var allies: Array[NpcRuntimeState] = _bring_all(map, fight["allies"])
	await _settle(tree)
	_check(map != null and enemies.size() == fight["enemies"].size() and allies.size() == fight["allies"].size(), "%s: everyone on the map" % fight["label"])
	if map != null and not enemies.is_empty():
		var state: CharacterState = session.player_runtime().state
		Grown.grow(state, fight["exp"], 50, true)
		_wield(session, fight["weapon"])
		var random := Specials.Seeded.new(7)
		var wins: int = 0
		for duel: int in ROUNDS:
			Grown.heal(state)
			for npc: NpcRuntimeState in enemies + allies:
				_heal(npc.character_state)
			wins += 1 if _duel(map, enemies, allies, state, random) else 0
		rate = float(wins) / ROUNDS
	session.free()
	await tree.process_frame
	return rate


func _bring_all(map: WorldMapController, pairs: Array) -> Array[NpcRuntimeState]:
	var out: Array[NpcRuntimeState] = []
	if map == null:
		return out
	for pair: Array in pairs:
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(StringName(pair[0]))
		if spawn != null and spawn.summoned:
			map.summon(StringName(pair[0]))
		var npc: NpcRuntimeState = map.npcs.npc_at_point(StringName(pair[1]))
		if npc != null and not npc.exists_in_map and spawn != null:
			map.npcs.appear(npc, spawn)
		if npc != null:
			out.append(npc)
	return out


func _duel(map: WorldMapController, enemies: Array[NpcRuntimeState], allies: Array[NpcRuntimeState], state: CharacterState, random: CombatRandomSource) -> bool:
	var everyone: Array[CombatSliceCharacterBinding] = map.combat_lifecycle.build_participants()
	var player: CombatSliceCharacterBinding = null
	for binding: CombatSliceCharacterBinding in everyone:
		if binding.is_user:
			player = binding
	var foes: Array[CombatSliceCharacterBinding] = _bindings(everyone, enemies)
	var friends: Array[CombatSliceCharacterBinding] = _bindings(everyone, allies)
	if player == null or foes.is_empty():
		return false
	var effects: SkillImprovementEffectRegistry = map.combat_lifecycle.effects
	for round: int in MAX_ROUNDS:
		for striker: CombatSliceCharacterBinding in [player] + friends:
			var target: CombatSliceCharacterBinding = _first_standing(foes)
			if target == null:
				return true
			if striker.state.vitality.current >= 0:
				CombatSliceOpportunityExecutor.execute_direct_attack(striker, target, everyone, random, effects)
		if _first_standing(foes) == null:
			return true
		for foe: CombatSliceCharacterBinding in foes:
			if foe.state.vitality.current < 0:
				continue
			var side: Array[CombatSliceCharacterBinding] = [player]
			for friend: CombatSliceCharacterBinding in friends:
				if friend.state.vitality.current >= 0:
					side.append(friend)
			CombatSliceOpportunityExecutor.execute_direct_attack(foe, side[random.next_below(side.size())], everyone, random, effects)
			if state.vitality.current < 0:
				return false
	return false


func _bindings(everyone: Array[CombatSliceCharacterBinding], npcs: Array[NpcRuntimeState]) -> Array[CombatSliceCharacterBinding]:
	var out: Array[CombatSliceCharacterBinding] = []
	for npc: NpcRuntimeState in npcs:
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(everyone, npc.character_id)
		if binding != null:
			out.append(binding)
	return out


func _first_standing(foes: Array[CombatSliceCharacterBinding]) -> CombatSliceCharacterBinding:
	for foe: CombatSliceCharacterBinding in foes:
		if foe.state.vitality.current >= 0:
			return foe
	return null


func _heal(state: CharacterState) -> void:
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	state.recovery.inner_force.current = state.recovery.inner_force.maximum


## TEST-ONLY: the weapon put straight in the hand (the probe's way).
func _wield(session: WorldSessionController, definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var item := ItemInstance.new(&"test:boss_weapon", definition_id)
	var registered: bool = context.inventory.register_item(item, GameContent.catalog().item(definition_id).own_weight) and context.index.register_snapshot(item) and context.inventory._apply_reparent(item.item_instance_id, context.endpoint())
	_check(registered and OldPineEquipmentInteractionAdapter.new().wield(session.player_runtime(), item.item_instance_id, session._inventory, session._item_index).succeeded, "%s in hand" % definition_id)


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("boss strength: " + label)
