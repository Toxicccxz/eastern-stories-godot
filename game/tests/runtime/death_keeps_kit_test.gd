extends RefCounted

## Owner 2026-11-19 (「都按推荐」; DECISIONS「减轻死亡」): at death what the player wields and wears stays
## on them; money and the rest of the bag go into the corpse (quest items with it). ES2 (chard.c
## make_corpse()) moved everything into the corpse, worn armour worn again on it; pacing.json's
## death_keeps_equipped off is that. Here: killed by 黑衣道士 in the 山洞 (chapter 1's must-win fight,
## aggressive, standing by the corpse), back to life at the 城隍庙, the walk back through the doors with
## the sword in hand, the fight again armed, and the bag's things taken back from the corpse.

const MapPlaces := preload("res://tests/support/map_places.gd")
const Grown := preload("res://tests/support/grown_character.gd")
const FIGHT: String = "第一章 山洞 黑衣道士"
const CAVE: StringName = &"oldpine.caves.mouth"
const SWORD: StringName = &"es2:obj/longsword"
const MONEY: StringName = &"es2:obj/money/silver"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_rule()
	TestDeath.use()
	await _die_and_walk_back(tree)
	TestDeath.restore()
	await _es2_takes_everything(tree)
	return {"assertions": _count, "failures": _failures.duplicate()}


func _rule() -> void:
	_check(TestDeath.game_keeps_equipped(), "pacing.json: death_keeps_equipped on")
	_check(not PacingDefinition.new(1000).death_keeps_equipped, "left out it is ES2's: everything into the corpse")


## Dies to the 黑衣道士 with the sword in hand and cloth worn: both stay on the player, the silver goes
## into the corpse; the card says so and that the 道士 stands by it; back to life, walks back armed,
## wins with the sword, takes the silver back.
func _die_and_walk_back(tree: SceneTree) -> void:
	var sim := MainlineFightSim.new(tree)
	var entry: Dictionary = MainlineFightSim.fight(FIGHT)
	_check(not entry.is_empty() and await sim._open(entry), "the fight set up")
	var session: WorldSessionController = sim.session
	var map: WorldMapController = sim.map
	if session == null or map == null:
		await sim.close()
		return
	var player: WorldPlayerRuntimeState = session.player_runtime()
	Grown.grow(player.state, 900, 50, true)
	var sword: StringName = player.state.equipment.primary_weapon().instance_id if player.state.equipment.primary_weapon() != null else &""
	_check(not sword.is_empty(), "the sword in hand")
	var silver: StringName = map.give_new_item_to_player(MONEY)
	_check(not silver.is_empty(), "silver in the bag")
	var worn: Array[StringName] = []
	for slot: StringName in player.armor.occupied_slots():
		worn.append(player.armor.item_instance_id_in_slot(slot))
	_check(not worn.is_empty(), "something worn")
	# Killed: the 道士 attacks, the player cannot stand a blow.
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	map.select_npc(sim._enemies[0].character_id)
	map.attack_selected()
	player.state.vitality = CharacterResourceState.new(1, 1, player.state.vitality.maximum)
	var steps: int = 0
	while coordinator.has_active_encounter() and steps < 600:
		coordinator.advance_scheduler(1.0)
		steps += 1
	await tree.physics_frame
	var flow: PlayerLifeFlow = session.player_life_flow()
	_check(flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE, "killed by the 道士")
	_check(player.state.equipment.has_weapon_instance(sword), "the sword still in hand")
	for armour: StringName in worn:
		_check(player.armor.is_worn(armour), "%s still worn" % armour)
	var corpses: Array[WorldLeftBehind.Place] = WorldLeftBehind.corpses(session)
	_check(corpses.size() == 1 and corpses[0].zone_id == CAVE, "the corpse in the 山洞")
	var corpse_id: StringName = flow.corpse_item_instance_id
	var inside: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_id))
	_check(inside.has(silver) and not inside.has(sword), "the silver in the corpse, the sword not: %s" % [inside])
	var card: String = session.shared_ui().life_overlay._death_text(flow)
	_check(card.contains("兵器和身上穿的还在你身上") and card.contains("钱和背包里的东西留在尸体上"), "the card says what stays and what lies: %s" % card)
	_check(WorldLeftBehind.corpse_guarded(session, corpse_id), "the 道士 stands by the corpse")
	# Back to life.
	session.continue_after_death()
	await tree.physics_frame
	session.request_reincarnation()
	session._process(0.1)
	await tree.physics_frame
	_check(not player.state.ghost and session.active_map_id() == SnowWorldDefinitions.temple_map_id(), "back at the 城隍庙")
	_check(player.state.equipment.has_weapon_instance(sword), "armed at the 城隍庙")
	# The walk back, through the doors.
	Grown.grow(player.state, 40000, 50, true)
	player.state.vitality = CharacterResourceState.new(player.state.vitality.maximum, player.state.vitality.maximum, player.state.vitality.maximum)
	# Through the temple's door, the town and the east road onto 老松岭, to the stone bridge; the vine's
	# swing and the climbs down to the cave are chance and landmarks (TEST-ONLY: taken as made).
	var bridge: WorldMapController = await _walk(tree, session, &"oldpine.outdoor.east_bridge")
	_check(bridge != null and player.state.equipment.has_weapon_instance(sword), "walked to 老松岭's stone bridge, sword in hand: %s" % _walk_note)
	var caves: WorldMapController = session.world_map_of(MapPlaces.map_of(CAVE))
	_check(session.handoff_to_point(caves.map_id(), CAVE, GameContent.catalog().zone(CAVE).combat_location_id, MapPlaces.spot(caves, CAVE, MapPlaces.zone_centre(caves, CAVE))).succeeded(), "TEST-ONLY: the vine and the climbs down, into the 山洞")
	await tree.physics_frame
	var cave: WorldMapController = session.active_map() as WorldMapController
	_check(cave != null and player.world_location().zone_id == CAVE, "back in the 山洞")
	if cave == null:
		await sim.close()
		return
	_check(player.state.equipment.has_weapon_instance(sword), "armed in the 山洞")
	# The fight was set up without the quest that keeps him there (MainlineFightSim): set again.
	var brought: Array[NpcRuntimeState] = sim._bring_all(entry["enemies"])
	var taoist: NpcRuntimeState = null if brought.is_empty() else brought[0]
	_check(taoist != null and taoist.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the 道士 still there")
	if taoist == null:
		await sim.close()
		return
	cave.select_npc(taoist.character_id)
	cave.attack_selected()
	steps = 0
	var with_sword: bool = false
	while coordinator.has_active_encounter() and steps < 1500:
		with_sword = with_sword or player.state.equipment.primary_weapon_skill_type() == &"sword"
		for victim: StringName in coordinator.held_victims():
			coordinator.spare_downed(victim)
		coordinator.advance_scheduler(1.0)
		steps += 1
	session.shared_ui().dismiss_current_panel()
	await tree.physics_frame
	_check(with_sword and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and taoist.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE, "fought again with the sword, and won")
	# The silver back from the corpse.
	_check(cave.corpses.select_corpse(corpse_id), "at the corpse")
	cave.corpses.open_selected_loot()
	for item_id: StringName in session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_id)):
		cave.corpses.take_selected_loot_item(item_id)
	_check(WorldLeftBehind.corpses(session).is_empty(), "the corpse emptied: nothing left behind")
	await sim.close()


var _walk_note: String = ""


## MapPlaces.go_to() with a note of where it stopped; a fight on the way (someone who attacks on
## sight) is fought out with the sword first.
func _walk(tree: SceneTree, session: WorldSessionController, zone_id: StringName) -> WorldMapController:
	var map: WorldMapController = session.active_map() as WorldMapController
	var chain: Array[PortalDefinition] = MapPlaces.portal_chain(map.map_id(), MapPlaces.map_of(zone_id))
	_walk_note = "chain %s" % [chain.map(func(portal: PortalDefinition) -> String: return String(portal.portal_id))]
	for portal: PortalDefinition in chain:
		if session.player_runtime().world_location().zone_id != portal.source_zone_id and not await MapPlaces.drive_to_zone(tree, map, portal.source_zone_id):
			_fight_out(session)
			if not await MapPlaces.drive_to_zone(tree, map, portal.source_zone_id):
				_walk_note += "; stopped short of %s in %s" % [portal.source_zone_id, session.player_runtime().world_location().zone_id]
				return null
		if not await MapPlaces.take_passage(tree, map, portal.portal_id):
			_fight_out(session)
			if not await MapPlaces.take_passage(tree, map, portal.portal_id):
				_walk_note += "; %s not taken" % portal.portal_id
				return null
		map = session.active_map() as WorldMapController
		await tree.physics_frame
		await MapPlaces.until_built(tree, session)
	if not await MapPlaces.drive_to_zone(tree, map, zone_id):
		_fight_out(session)
		if not await MapPlaces.drive_to_zone(tree, map, zone_id):
			_walk_note += "; not into %s" % zone_id
			return null
	return map


func _fight_out(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var steps: int = 0
	while coordinator.has_active_encounter() and steps < 1500:
		for victim: StringName in coordinator.held_victims():
			coordinator.spare_downed(victim)
		coordinator.advance_scheduler(1.0)
		steps += 1
	session.shared_ui().dismiss_current_panel()


## pacing death_keeps_equipped off (ES2): the sword goes into the corpse with everything else.
func _es2_takes_everything(tree: SceneTree) -> void:
	var sim := MainlineFightSim.new(tree)
	var entry: Dictionary = MainlineFightSim.fight(FIGHT)
	_check(await sim._open(entry), "the fight set up (ES2's death)")
	var session: WorldSessionController = sim.session
	if session == null:
		await sim.close()
		return
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var sword: StringName = player.state.equipment.primary_weapon().instance_id if player.state.equipment.primary_weapon() != null else &""
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	sim.map.select_npc(sim._enemies[0].character_id)
	sim.map.attack_selected()
	player.state.vitality = CharacterResourceState.new(1, 1, player.state.vitality.maximum)
	var steps: int = 0
	while coordinator.has_active_encounter() and steps < 600:
		coordinator.advance_scheduler(1.0)
		steps += 1
	await tree.physics_frame
	var flow: PlayerLifeFlow = session.player_life_flow()
	var inside: Array[StringName] = session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, flow.corpse_item_instance_id))
	_check(flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and inside.has(sword) and not player.state.equipment.has_weapon_instance(sword), "ES2: the sword lies in the corpse")
	await sim.close()


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
