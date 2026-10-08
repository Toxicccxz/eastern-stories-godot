extends RefCounted

## 野羊山 (d/goathill, region plan #2): the mountain road north of Snow's crossroad with
## the bandits on its corner and 黄霸 in the small temple, the canyon down to the caverns
## and their thirteen rock leeches. What it first needed: a second weapon in the other hand
## (equip.c; its weapon_prop counts), hammers' and staffs' verbs with weapond.c
## bash_weapon() (a parried blow knocks the weapon away or breaks it: 断掉的 forms), and
## 伏蛟功 (serpentforce, std/force.c's hit). TEST-ONLY fixtures are marked where used.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const HAMMER: StringName = &"es2:d/goathill/obj/sledge_hammer"
const AXE: StringName = &"es2:d/goathill/obj/hand_axe"
const BLADE: StringName = &"es2:d/goathill/obj/steel_blade"
const ROOMS: Array[String] = ["mroad1", "mroad2", "mroad3", "mroad4", "mroad5", "mroad6", "temple1", "slope1",
	"canyon1", "canyon2", "canyon3", "cavern1", "cavern2", "cavern3", "cavern4"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	_test_tiles(session)
	_test_two_hands(session)
	await _test_portals(tree, session)
	await _test_corner(tree, session)
	await _test_bash(tree, session)
	await _test_hwang_fight(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.region(&"goathill") != null and catalog.region(&"goathill").display_name == "野羊山", "the region 野羊山")
	var missing: Array[String] = []
	for room: String in ROOMS:
		var zone: ZoneDefinition = catalog.zone(StringName("goathill." + room))
		if catalog.room(StringName("es2:d/goathill/" + room)) == null or zone == null or zone.room_ids() != [StringName("es2:d/goathill/" + room)]:
			missing.append(room)
	_check(missing.is_empty(), "fifteen rooms, a zone each: missing " + str(missing))
	_check(catalog.room(&"es2:d/goathill/cavern1.c") == null, "cavern1.c.c (an empty stray copy nothing leads to) is not a room")
	_check(catalog.room(&"es2:d/goathill/mroad4").short == "山路转角" and catalog.zone(&"goathill.mroad4").map_id == &"goathill.mountain" and catalog.zone(&"goathill.cavern3").map_id == &"goathill.caverns", "room text and maps")
	_check(catalog.zones_adjacent(&"snow.crossroad", &"goathill.mroad1") and catalog.zones_adjacent(&"goathill.canyon3", &"goathill.cavern1"), "crossroad north to mroad1; canyon3 east to cavern1")
	var counts: Dictionary[String, int] = {}
	for spawn_id: String in ["goathill.mountain.mroad4.bandits", "goathill.mountain.mroad4.bandit_leader", "goathill.mountain.temple1.bandit_hwang",
			"goathill.caverns.cavern1.worms", "goathill.caverns.cavern2.fat_worm", "goathill.caverns.cavern2.worms",
			"goathill.caverns.cavern3.big_worms", "goathill.caverns.cavern3.huge_worms", "goathill.caverns.cavern4.worms", "goathill.caverns.cavern4.big_worm"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(StringName(spawn_id))
		counts[spawn_id] = 0 if spawn == null else spawn.quantity
	_check(counts.values() == [3, 1, 1, 2, 1, 3, 2, 2, 2, 1], "the rooms' objects: three 土匪爪牙 and a 土匪首领, 黄霸, thirteen leeches: %s" % counts)
	_check(catalog.spawn(&"goathill.caverns.cavern1.silver_worm") == null and catalog.npc(&"goathill.npc.silver_worm") == null, "银色岩蛭: no room places it (owner: as LPC)")
	var hwang: NpcDefinition = catalog.npc(&"goathill.npc.bandit_hwang")
	_check(hwang.skill_map().get(&"force") == &"serpentforce" and catalog.skill(&"serpentforce").standard_force_hit and catalog.skill(&"serpentforce").display_name == "伏蛟功", "黄霸's force is 伏蛟功, std/force.c's hit")
	_check(hwang.attitude == NpcDefinition.Attitude.FRIENDLY and catalog.npc(&"goathill.npc.bandit").attitude == NpcDefinition.Attitude.AGGRESSIVE and catalog.npc(&"goathill.npc.worm").attitude == NpcDefinition.Attitude.PEACEFUL, "黄霸 friendly, the bandits aggressive, the leeches peaceful")
	_check(catalog.zone(&"goathill.mroad4").combat_entry == &"complete_set", "the corner's four join one fight together")
	var hammer: ItemContentDefinition = catalog.item(HAMMER)
	_check(hammer.weapon_skill_type == &"hammer" and hammer.weapon_damage == 45 and hammer.can_wield_secondary and hammer.weapon_apply == {&"attack": -4, &"defense": 5}, "大金槌: hammer 45, SECONDARY, attack -4, defense 5")
	_check(catalog.item(AXE).can_wield_secondary and catalog.item(AXE).weapon_skill_type == &"axe", "短斧: SECONDARY")
	var broken: ItemContentDefinition = catalog.item(ItemContentDefinition.broken_id(BLADE))
	_check(broken != null and broken.display_name == "断掉的钢刀" and broken.value == 70 and broken.weapon_definition() == null and broken.own_weight == 9000 and broken.is_broken(), "every weapon has its broken form: 断掉的钢刀, value 70, no longer a weapon")
	var verbs: Array[String] = []
	for action: CombatActionDefinition in catalog.combat_actions().weapon_action_set(&"hammer").actions():
		verbs.append("%s %s" % [action.legacy_action_text, action.post_action_policy_id])
	_check(verbs == ["$N挥舞$w，往$n的$l用力一砸 bash_weapon", "$N高高举起$w，往$n的$l当头砸下 bash_weapon", "$N手握$w，眼露凶光，猛地对准$n的$l挥了过去 bash_weapon"], "hammer.c's verbs, the source's 用力一□ as 用力一砸: " + str(verbs))
	_check(catalog.combat_actions().weapon_action_set(&"staff").actions().size() == 3, "staff.c's verbs are the same three")


func _test_tiles(session: WorldSessionController) -> void:
	for map_id: StringName in [&"goathill.mountain", &"goathill.caverns"]:
		var map: WorldMapController = session.world_map_of(map_id)
		var layers: Array[TileMapLayer] = TerrainProbe.layers(map)
		var walkable: Dictionary[Vector2i, bool] = {}
		for layer: TileMapLayer in layers:
			for cell: Vector2i in layer.get_used_cells():
				if layer.get_cell_tile_data(cell).get_collision_polygons_count(0) == 0:
					walkable[cell] = true
		var start: Vector2i = layers[0].local_to_map(map.resolve_spawn_marker(GameContent.catalog().map(map_id).entry_spawn_id).position)
		var reached: Dictionary[Vector2i, bool] = {start: true}
		var frontier: Array[Vector2i] = [start]
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if walkable.has(cell + step) and not reached.has(cell + step):
					reached[cell + step] = true
					frontier.append(cell + step)
		var cut_off: Array[StringName] = []
		var rects: Array[Rect2] = []
		for zone: WorldPhysicalZoneArea2D in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
			var shape: RectangleShape2D = (zone.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
			var rect := Rect2(zone.position - shape.size / 2.0, shape.size)
			rects.append(rect)
			if not reached.keys().any(func(cell: Vector2i) -> bool: return rect.has_point(layers[0].map_to_local(cell))):
				cut_off.append(zone.zone_id)
		_check(cut_off.is_empty(), "every room of %s is joined to its entry on the tiles: cut off %s" % [map_id, cut_off])
		var outside: Array[Vector2i] = []
		for cell: Vector2i in walkable:
			if not rects.any(func(rect: Rect2) -> bool: return rect.has_point(layers[0].map_to_local(cell))):
				outside.append(cell)
		_check(outside.is_empty(), "%s: no open ground outside its rooms: %s" % [map_id, outside.slice(0, 5)])
		var unplaced: Array[String] = []
		for npc: NpcRuntimeState in map.npc_runtimes():
			var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
			if body == null or not walkable.has(layers[0].local_to_map(body.global_position)):
				unplaced.append(String(npc.spawn_point_id))
		_check(unplaced.is_empty(), "%s's NPCs stand on open ground: %s" % [map_id, unplaced])


## equip.c wield(): the second SECONDARY weapon goes to the other hand and its
## weapon_prop counts too (damage included); only the first attacks.
func _test_two_hands(session: WorldSessionController) -> void:
	var mountain: WorldMapController = session.world_map_of(&"goathill.mountain")
	var hwang: NpcRuntimeState = _find(mountain, &"goathill.npc.bandit_hwang")
	var leader: NpcRuntimeState = _find(mountain, &"goathill.npc.bandit_leader")
	var held: Array[String] = []
	for npc: NpcRuntimeState in [hwang, leader]:
		var primary: EquippedWeaponRef = npc.character_state.equipment.primary_weapon()
		var secondary: EquippedWeaponRef = npc.character_state.equipment.secondary_weapon()
		held.append("%s %s" % ["" if primary == null else primary.weapon_id, "" if secondary == null else secondary.weapon_id])
	_check(held == ["%s %s" % [HAMMER, HAMMER], "%s %s" % [AXE, AXE]], "黄霸 holds a 大金槌 in each hand, the leader a 短斧 in each: " + str(held))
	var binding: CombatSliceCharacterBinding = null
	for candidate: CombatSliceCharacterBinding in mountain.combat_lifecycle.build_participants(true):
		if candidate.character_id == hwang.character_id:
			binding = candidate
	_check(binding != null and CombatSliceProjectionBuilder.apply_of(binding, &"attack") == 100 - 4 - 4 and CombatSliceProjectionBuilder.apply_of(binding, &"defense") == 90 + 5 + 5 + 1, "apply/attack 100 - 4 - 4, apply/defense 90 + 5 + 5 and the boots' 1: both hammers' weapon_prop")
	_check(binding != null and CombatSliceProjectionBuilder._secondary_apply(binding, &"damage") == 45 and binding.content.projected_apply_damage(binding.state.equipment.primary_weapon()) == 45, "each hammer adds its 45 to apply/damage")


## The way in from Snow's crossroad and down into the caverns, walked.
func _test_portals(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(session.handoff_to(&"snow.outdoor", &"snow.crossroad", &"snow.crossroad", &"snow.crossroad.goathill_return").succeeded(), "on Snow's crossroad")
	await tree.physics_frame
	await _walk_until_map(tree, session, &"goathill.mountain", "move_up")
	_check(session.active_map_id() == &"goathill.mountain" and player.world_location().zone_id == &"goathill.mroad1", "north from the crossroad: 山路 (mroad1)")
	_check(session.shared_ui().log_lines().any(func(line: String) -> bool: return line.begins_with("【山路】")), "its room text on arrival")
	await _walk_until_map(tree, session, &"snow.outdoor", "move_down")
	_check(session.active_map_id() == &"snow.outdoor" and player.world_location().zone_id == &"snow.crossroad", "south again: the crossroad")
	_check(session.handoff_to(&"goathill.mountain", &"goathill.canyon3", &"goathill.canyon3", &"goathill.canyon3.cavern_return").succeeded(), "in the canyon")
	await tree.physics_frame
	await _walk_until_map(tree, session, &"goathill.caverns", "move_right")
	_check(session.active_map_id() == &"goathill.caverns" and player.world_location().zone_id == &"goathill.cavern1", "east from canyon3: 岩洞 (cavern1)")
	await _walk_until_map(tree, session, &"goathill.mountain", "move_left")
	_check(session.active_map_id() == &"goathill.mountain" and player.world_location().zone_id == &"goathill.canyon3", "west again: canyon3")


## The corner's four come on together (complete_set: everyone whose presence reaches the
## player as they step onto the corner), walked up the steep road from mroad3 and along the
## narrow one from mroad5. Each fight is fled at once.
func _test_corner(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"goathill.mountain")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for way: Array in [[&"goathill.mroad3", Vector2(640, 1420), "move_up"], [&"goathill.mroad5", Vector2(900, 1216), "move_left"]]:
		map.runtime_player_body().global_position = way[1] # TEST-ONLY: on the road, out of the bandits' reach
		player.set_world_location(map.location_for_zone(way[0]))
		for _step: int in range(3):
			await tree.physics_frame
		Input.action_press(way[2])
		for _step: int in range(300):
			await tree.physics_frame
			if coordinator.has_active_encounter():
				break
		Input.action_release(way[2])
		var joined: Array[String] = []
		if coordinator.has_active_encounter():
			for participant: CombatParticipant in coordinator.active_encounter().participants():
				var npc: NpcRuntimeState = map.find_resident_npc(participant.participant_id)
				joined.append("player" if npc == null else String(npc.definition().definition_id))
		joined.sort()
		_check(player.world_location().zone_id == &"goathill.mroad4" and joined == ["goathill.npc.bandit", "goathill.npc.bandit", "goathill.npc.bandit", "goathill.npc.bandit_leader", "player"],
			"from %s onto the corner: one fight with all four: %s" % [way[0], joined])
		if coordinator.has_active_encounter():
			coordinator.submit_player_action(CombatTacticalRequest.new(&"flee", coordinator.active_encounter().encounter_id, player.character_id,
				CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE))
			for tick: int in range(10):
				coordinator.advance_scheduler(0.0 if tick == 0 else 1.0)
				if not coordinator.has_active_encounter():
					break
		_check(not coordinator.has_active_encounter() and session.world_simulation_gate().is_open(), "fled from the corner")
	# kill.c at one lying unconscious (茅山 C): 攻击 brings the corner's set in, it among them.
	var downed: NpcRuntimeState = _find(map, &"goathill.npc.bandit")
	downed.character_state.vitality.current = -1 # TEST-ONLY: knocked out outside a fight
	map.combat_lifecycle.fall_below_zero()
	_check(downed.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "TEST-ONLY: a bandit lies unconscious")
	map.select_npc(downed.character_id)
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED and coordinator.has_active_encounter() and coordinator.active_encounter().participant_for(downed.character_id) != null and player.relationship.has_lethal_target(downed.character_id), "攻击 at the one lying there starts the fight: %s" % CombatSliceInitiationResult.Outcome.find_key(started.outcome))
	if coordinator.has_active_encounter():
		coordinator.submit_player_action(CombatTacticalRequest.new(&"flee:downed", coordinator.active_encounter().encounter_id, player.character_id,
			CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE))
		for tick: int in range(40):
			coordinator.advance_scheduler(0.0 if tick == 0 else 1.0)
			if not coordinator.has_active_encounter():
				break
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "that fight ends too: " + coordinator.last_abort_detail())
	session.handoff_to(&"goathill.mountain", &"goathill.canyon3", &"goathill.canyon3", &"goathill.canyon3.cavern_return")
	await tree.physics_frame


## weapond.c bash_weapon() with scripted rolls: the player's 大金槌 against a bandit's
## parrying 钢刀. TEST-ONLY: strength 100 (wap 80 + 100), the bandits' 20 (wdp 18 + 20).
func _test_bash(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"goathill.mountain")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hammer: StringName = _give(session, HAMMER)
	_check(session.wield_player_item(hammer).succeeded, "the player wields a 大金槌")
	var player_strength: int = player.state.attributes.strength
	player.state.attributes.strength = 100 # TEST-ONLY
	var bandits: Array[NpcRuntimeState] = []
	var strengths: Array[int] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"goathill.npc.bandit":
			strengths.append(npc.character_state.attributes.strength)
			npc.character_state.attributes.strength = 20 # TEST-ONLY
			bandits.append(npc)
	var me: CombatSliceCharacterBinding = _binding(map, player.character_id)
	var first: CombatSliceCharacterBinding = _binding(map, bandits[0].character_id)
	var blade: StringName = bandits[0].character_state.equipment.primary_weapon().instance_id
	var lines: Array[ColoredLine] = map.combat_lifecycle.run_post_action(me, CombatPostActionIds.BASH_WEAPON, first, false, ScriptedCombatRandomSource.new([170]))
	_check(lines.is_empty() and bandits[0].character_state.equipment.primary_weapon() != null, "not parried: nothing")
	var random := ScriptedCombatRandomSource.new([10, 50, 30])
	lines = map.combat_lifecycle.run_post_action(me, CombatPostActionIds.BASH_WEAPON, first, true, random)
	_check(_texts(lines) == ["你的大金槌和土匪爪牙的钢刀相击，冒出点点的火星。"] and random.call_count() == 1, "10 of random(180): sparks; one draw: " + str(_texts(lines)))
	lines = map.combat_lifecycle.run_post_action(me, CombatPostActionIds.BASH_WEAPON, first, true, random)
	_check(_texts(lines) == ["土匪爪牙只觉得手中钢刀一震，险些脱手！"] and bandits[0].character_state.equipment.primary_weapon() != null, "50 > wdp 38: nearly")
	lines = map.combat_lifecycle.run_post_action(me, CombatPostActionIds.BASH_WEAPON, first, true, random)
	var shown: ItemInstance = session.item_instance_index().resolve(blade)
	_check(_texts(lines) == ["只听见「啪」地一声，土匪爪牙手中的钢刀已经断为两截！"] and lines[0].color == ColoredLine.HIW, "30 > wdp / 2 = 19: broken, in HIW")
	_check(bandits[0].character_state.equipment.primary_weapon() == null and shown != null and shown.item_definition_id == ItemContentDefinition.broken_id(BLADE) and map.floor_item_view(blade) != null, "unwielded, at his feet, 断掉的钢刀 from now on")
	_check(map.floor_item_view(blade).display_name == "断掉的钢刀", "the floor shows its new name: " + map.floor_item_view(blade).display_name)
	var second: CombatSliceCharacterBinding = _binding(map, bandits[1].character_id)
	var second_blade: StringName = bandits[1].character_state.equipment.primary_weapon().instance_id
	lines = map.combat_lifecycle.run_post_action(me, CombatPostActionIds.BASH_WEAPON, second, true, ScriptedCombatRandomSource.new([100]))
	_check(_texts(lines) == ["土匪爪牙只觉得手中钢刀把持不定，脱手飞出！"] and bandits[1].character_state.equipment.primary_weapon() == null and session.item_instance_index().resolve(second_blade).item_definition_id == BLADE and map.floor_item_view(second_blade) != null, "100 > 2 x wdp: knocked away whole, onto the floor")
	_check(map.combat_lifecycle.run_post_action(me, CombatPostActionIds.BASH_WEAPON, first, true, ScriptedCombatRandomSource.new([100])).is_empty(), "a victim without a weapon: nothing")
	# The broken blade picked up: no longer wieldable, worth a tenth.
	var context: MoneyInventoryContext = Finance.session_context(session)
	_check(InventoryTransferService.new().transfer(context.inventory, blade, InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)).succeeded, "picked up") # TEST-ONLY
	map.floor_items._forget_floor_item(blade)
	_check(not session.wield_player_item(blade).succeeded, "断掉的钢刀 cannot be wielded (weapon_prop 0)")
	var quote: HockshopValuationResult = HockshopValuation.appraise(context, session.food_collection(), session.liquid_collection(), blade)
	_check(quote.source_value == 70, "worth 70 now (700 / 10): %d" % quote.source_value)
	# A parrying stack (飞刀) breaks whole and stays a stack, of broken ones (review on #55).
	var knives: StringName = _give_stack(session, &"es2:d/snow/npc/obj/throwing_knife", 10) # TEST-ONLY
	_check(session.wield_player_item(knives).succeeded and player.state.equipment.primary_weapon().instance_id == knives, "the player parries with 飞刀")
	var hwang: CombatSliceCharacterBinding = _binding(map, _find(map, &"goathill.npc.bandit_hwang").character_id)
	me = _binding(map, player.character_id)
	@warning_ignore("integer_division")
	var wdp: int = session.inventory_state().own_weight(knives) / 500 + player.state.attributes.strength
	lines = map.combat_lifecycle.run_post_action(hwang, CombatPostActionIds.BASH_WEAPON, me, true, ScriptedCombatRandomSource.new([wdp]))
	var stacks: CombinedStackCollection = session.stack_collection()
	_check(_texts(lines) == ["只听见「啪」地一声，你手中的飞刀已经断为两截！"], "黄霸 breaks the player's 飞刀: " + str(_texts(lines)))
	_check(player.state.equipment.primary_weapon() == null or player.state.equipment.primary_weapon().instance_id != knives, "unwielded")
	_check(stacks.has_stack(knives) and stacks.stack_state(knives).amount == 10 and stacks.stack_definition(knives).item_definition_id == ItemContentDefinition.broken_id(&"es2:d/snow/npc/obj/throwing_knife") and map.floor_item_view(knives).display_name == "断掉的飞刀", "ten 断掉的飞刀 on the floor, still one stack")
	# TEST-ONLY: strengths back to what Save derives.
	player.state.attributes.strength = player_strength
	for index: int in bandits.size():
		bandits[index].character_state.attributes.strength = strengths[index]
	var work: RefCounted = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "a broken blade carried, a knocked-away one and ten broken 飞刀 on the floor")
	_check(work._failures.is_empty(), "Save/Continue keeps both: " + str(work._failures))


## 黄霸 fought: his 大金槌 bash, crush and slam, and 伏蛟功's force hit lands without
## aborting the fight. TEST-ONLY: a strong player who only parries with a weapon.
func _test_hwang_fight(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"goathill.mountain")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hwang: NpcRuntimeState = _find(map, &"goathill.npc.bandit_hwang")
	session.handoff_to(&"goathill.mountain", &"goathill.temple1", &"goathill.temple1", &"goathill.canyon3.cavern_return")
	await tree.physics_frame
	map.runtime_player_body().global_position = map.runtime_body_for_character(hwang.character_id).global_position + Vector2(0, 46) # TEST-ONLY
	player.set_world_location(map.location_for_zone(&"goathill.temple1"))
	await tree.physics_frame
	player.state.vitality = CharacterResourceState.new(50000, 50000, 50000) # TEST-ONLY
	map.select_npc(hwang.character_id)
	var started: CombatSliceInitiationResult = map.attack_selected()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 黄霸: %s" % CombatSliceInitiationResult.Outcome.find_key(started.outcome))
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var aborted_before: int = CombatEncounterCoordinator.take_aborted_total()
	var text: String = ""
	for _round: int in range(60):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		ui.refresh_projection()
		text = ui.log_panel._text.get_parsed_text()
		if text.contains("黄霸挥舞大金槌") or text.contains("黄霸高高举起大金槌") or text.contains("黄霸手握大金槌"):
			break
	_check(text.contains("大金槌"), "黄霸 swings his 大金槌 with hammer.c's verbs: " + text.right(300))
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "伏蛟功's force hit and both hands: the fight never aborts")


func _walk_until_map(tree: SceneTree, session: WorldSessionController, target: StringName, action: String) -> void:
	Input.action_press(action)
	for _step: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == target:
			break
	Input.action_release(action)
	for _step: int in range(3):
		await tree.physics_frame


## TEST-ONLY: a new item in the player's hands.
func _give(session: WorldSessionController, definition_id: StringName) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, content.own_weight))
	assert(context.index.register_snapshot(item))
	assert(InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)).succeeded)
	return item.item_instance_id


## TEST-ONLY: a new stack in the player's hands, merged.
func _give_stack(session: WorldSessionController, definition_id: StringName, amount: int) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, 0))
	assert(context.index.register_snapshot(item))
	assert(CombinedStackService.register_stack(context.stacks, context.inventory, item, content.stack_definition(), amount).accepted)
	var merged: CombinedStackMergeResult = CombinedStackService.transfer_and_merge(context.stacks, context.inventory, item.item_instance_id,
		InventoryTransferDestination.new(context.endpoint(), true, true, 1000000), null, null, context.owner)
	assert(context.index.forget_destroyed_snapshots(merged.absorbed_instance_ids, context.inventory))
	return merged.surviving_instance_id


func _binding(map: WorldMapController, character_id: StringName) -> CombatSliceCharacterBinding:
	for binding: CombatSliceCharacterBinding in map.combat_lifecycle.build_participants(true):
		if binding.character_id == character_id:
			return binding
	return null


func _find(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _texts(lines: Array[ColoredLine]) -> Array[String]:
	return ColoredLine.texts(lines)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
