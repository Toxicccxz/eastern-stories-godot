extends RefCounted

## DECISIONS「任务物品不被拿走」 (owner 2026-11-19): a thief never takes what cannot be dropped (no_drop):
## 穿灵 carried beside a plain 长剑, the 飞贼 picks the 长剑 or nothing, never 穿灵; a corpse dissolved with
## 化尸粉 leaves its no_drop things lying where it lay (the rest goes), and the 化尸粉's count leaves them out.
## DECISIONS「任务兵器不脱手」: weapond.c bash_weapon() (hammers, staffs) never knocks away nor breaks a
## weapon that cannot be dropped: 穿灵 and 旋芒, the finale's swords, parried against a bandit's 大金槌
## two hundred times over every roll random(wap) can give, stay whole in the player's hand (a roll that
## would is the 险些脱手); an ordinary 长剑 under the same rolls is still knocked away or broken.
## DECISIONS「穿灵在手」: 穿灵 and 旋芒 fight alike (the same weapon numbers), so the one the 封坛 puts in
## the player's hand is as good as the other.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const CHUANLING: StringName = &"native:village/soul_impaler"
const XUANMANG: StringName = &"native:lancheng/xuanmang"
const LONGSWORD: StringName = &"es2:obj/longsword"
const HAMMER: StringName = &"es2:d/goathill/obj/sledge_hammer"
const BANDIT_POINT: StringName = &"goathill.mroad4.bandit.1"
const THIEF_POINT: StringName = &"cloud.park.thief.1"
const DUST: StringName = &"es2:obj/dust"
const ROLLS: int = 200

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("神兵", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY
	var map: WorldMapController = MapPlaces.enter(session, &"goathill.mroad4", BANDIT_POINT)
	var bandit: NpcRuntimeState = MapPlaces.npc_at(session, BANDIT_POINT)
	_check(map != null and bandit != null, "a bandit on the mountain road")
	if map != null and bandit != null:
		_check(not map.floor_items.give_new_item_to(bandit, HAMMER).is_empty() and map.npcs.npc_wield_item(bandit.character_id, HAMMER), "the bandit takes up a 大金槌 (TEST-ONLY)")
		bandit.character_state.attributes.strength = 300 # TEST-ONLY: random(wap) reaches past 2 x wdp
		for sword: StringName in [CHUANLING, XUANMANG]:
			_check(_bashed(session, map, bandit, sword) == [0, 0], "%s: never knocked away nor broken in %d parries" % [sword, ROLLS])
		var plain: Array[int] = _bashed(session, map, bandit, LONGSWORD, true)
		_check(plain[0] + plain[1] > 0, "a 长剑 under the same rolls is still knocked away or broken: %s" % [plain])
		await _test_dissolve(tree, session, map, bandit)
	await _test_thief(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var chuanling: ItemContentDefinition = catalog.item(CHUANLING)
	var xuanmang: ItemContentDefinition = catalog.item(XUANMANG)
	_check(chuanling.no_drop and xuanmang.no_drop, "both swords cannot be dropped")
	var one: WeaponDefinition = chuanling.weapon_definition()
	var other: WeaponDefinition = xuanmang.weapon_definition()
	_check(
		one != null and other != null and one.skill_type == other.skill_type and one.is_two_handed == other.is_two_handed
		and chuanling.weapon_damage == xuanmang.weapon_damage and chuanling.weapon_apply == xuanmang.weapon_apply
		and chuanling.own_weight == xuanmang.own_weight and chuanling.weapon_rigidity == xuanmang.weapon_rigidity,
		"穿灵 and 旋芒: the same weapon numbers",
	)


## The bandit falls holding 穿灵 and a 长剑; his corpse dissolved: 穿灵 lies where he lay, the 长剑 is gone.
func _test_dissolve(tree: SceneTree, session: WorldSessionController, map: WorldMapController, bandit: NpcRuntimeState) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var kept: StringName = map.floor_items.give_new_item_to(bandit, CHUANLING) # TEST-ONLY
	var lost: StringName = map.floor_items.give_new_item_to(bandit, LONGSWORD) # TEST-ONLY
	_check(not kept.is_empty() and not lost.is_empty(), "the bandit carries 穿灵 and a 长剑 (TEST-ONLY)")
	player.state.progression.combat_experience = 10000000 # TEST-ONLY: the blows land
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	bandit.character_state.vitality.effective = 1 # TEST-ONLY
	bandit.character_state.vitality.current = 1
	_check(map.select_npc(bandit.character_id) and map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks the bandit")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	coordinator.set_manual_turns(false) # TEST-ONLY
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	session.shared_ui().dismiss_current_panel()
	await tree.process_frame
	var corpse: CorpseState = null
	for each: CorpseState in map.corpse_states():
		if each.victim_character_id == bandit.character_id:
			corpse = each
	_check(corpse != null and map.select_corpse(corpse.corpse_item_instance_id), "the bandit's corpse, selected")
	if corpse == null:
		return
	var all: int = map.corpses.corpse_content_count(corpse)
	_check(map.dissolvable_corpse_contents() == all - 1, "the 化尸粉 counts all but 穿灵 (%d of %d)" % [map.dissolvable_corpse_contents(), all])
	var dust: StringName = map.give_new_item_to_player(DUST) # TEST-ONLY
	_check(map.corpses.dissolve_selected_corpse(dust), "dissolved")
	_check(map.corpse_states().all(func(each: CorpseState) -> bool: return each.victim_character_id != bandit.character_id), "the corpse is gone")
	var item: ItemInstance = session.item_instance_index().resolve(kept)
	_check(item != null and item.item_definition_id == CHUANLING and map.floor_item_view(kept) != null, "穿灵 lies where he lay")
	_check(session.item_instance_index().resolve(lost) == null, "the 长剑 dissolved with him")


## The 飞贼 (u/cloud thief.c) by a player carrying 穿灵 and a 长剑: whatever he reaches for, never 穿灵.
func _test_thief(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = MapPlaces.enter(session, &"cloud.park", THIEF_POINT)
	await tree.process_frame
	var thief: NpcRuntimeState = MapPlaces.npc_at(session, THIEF_POINT)
	_check(map != null and thief != null and thief.definition().dealings().steal != null, "the 飞贼 in the park")
	if map == null or thief == null:
		return
	var player: WorldPlayerRuntimeState = session.player_runtime()
	for item_id: StringName in map.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id)
		if item != null and not GameContent.catalog().item(item.item_definition_id).no_drop:
			map.drop_item(item_id) # TEST-ONLY: only the two below carried, no silver
	var kept: StringName = map.give_new_item_to_player(CHUANLING)
	var plain: StringName = map.give_new_item_to_player(LONGSWORD)
	await tree.process_frame
	thief.set_world_location(map.location_for_zone(&"cloud.park")) # TEST-ONLY: he may have wandered
	player.set_world_location(map.location_for_zone(&"cloud.park"))
	map.npc_life.npc_ambience()
	var open: int = 0
	for item_id: StringName in map.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)):
		if not GameContent.catalog().item(session.item_instance_index().resolve(item_id).item_definition_id).no_drop:
			open += 1
	_check(open > 0, "something a thief may take is carried")
	var reached: Dictionary[StringName, int] = {}
	for attempt: int in 40:
		map.npc_life.pending_steals.clear()
		# Each pick in turn among what he may take (random(n) in steal.c).
		session.configure_npc_ambience_random_source(ScriptedWorldInteractionRandomSource.new([attempt % maxi(open, 1)])) # TEST-ONLY
		map.npc_life._advance_ambience(0.0)
		map.npc_life.ambience.cancel_call(thief.character_id)
		map.npc_life._start_stealing(thief)
		var pending: Dictionary = map.npc_life.pending_steals.get(thief.character_id, {})
		var item_id: StringName = pending.get("item", &"")
		reached[item_id] = reached.get(item_id, 0) + 1
	map.npc_life.pending_steals.clear()
	map.npc_life.ambience.cancel_call(thief.character_id)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY
	var never: bool = reached.keys().all(func(item_id: StringName) -> bool: return item_id.is_empty() or not GameContent.catalog().item(session.item_instance_index().resolve(item_id).item_definition_id).no_drop)
	_check(not reached.has(kept) and never and reached.get(plain, 0) > 0, "the 飞贼 reaches for the 长剑, never 穿灵 nor another no_drop thing: %s" % [reached])


## `sword` new in the player's hand, parried against the bandit's hammer ROLLS times, each roll of
## random(wap) in turn (0, 1, ... wrapped): [times knocked away, times broken]. A sword knocked off is
## put back in hand (a broken one replaced) so every roll meets the sword; `first`: stop at the first
## sword lost (the floor holds only so much).
func _bashed(session: WorldSessionController, map: WorldMapController, bandit: NpcRuntimeState, sword: StringName, first: bool = false) -> Array[int]:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var knocked: int = 0
	var broken: int = 0
	var held: StringName = _wield_new(session, sword)
	var attacker: CombatSliceCharacterBinding = _binding(map, bandit.character_id)
	var wap: int = maxi(1, attacker.state.attributes.strength + 200)
	for roll: int in ROLLS:
		var me: CombatSliceCharacterBinding = _binding(map, player.character_id)
		map.combat_lifecycle.run_post_action(_binding(map, bandit.character_id), CombatPostActionIds.BASH_WEAPON, me, true, ScriptedCombatRandomSource.new([roll * 37 % wap]))
		var in_hand: EquippedWeaponRef = player.state.equipment.primary_weapon()
		var item: ItemInstance = session.item_instance_index().resolve(held)
		if item != null and item.item_definition_id != sword:
			broken += 1
		elif in_hand == null or in_hand.instance_id != held:
			knocked += 1
		else:
			continue
		if first:
			break
		held = _wield_new(session, sword)
	return [knocked, broken]


func _wield_new(session: WorldSessionController, definition_id: StringName) -> StringName:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var in_hand: EquippedWeaponRef = player.state.equipment.primary_weapon()
	if in_hand != null:
		session.unwield_player_item(in_hand.instance_id)
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	var given: bool = (
		context.inventory.register_item(item, content.own_weight) and context.index.register_snapshot(item)
		and InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)).succeeded
		and session.wield_player_item(item.item_instance_id).succeeded
	)
	if not given:
		_check(false, "%s in the player's hand (TEST-ONLY)" % definition_id)
	return item.item_instance_id


func _binding(map: WorldMapController, character_id: StringName) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in map.combat_lifecycle.build_participants(true):
		if binding.character_id == character_id:
			return binding
	return null


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("quest items: " + message)
