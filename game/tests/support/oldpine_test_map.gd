class_name OldPineTestMap
extends RefCounted

## Old Pine regression suites were written against the retired Old Pine map
## controller: pre-placed bodies (Bandit01…Serpent05) and map-level inventory
## actions that bypassed the Session's portable-inventory gate. Bodies are now
## spawned from spawns.json; these helpers find them by the same names, drive
## their presence signals and keep the old direct adapter calls for tests.
const POINTS: Dictionary[String, StringName] = {
	"Bandit01": &"oldpine.outdoor.slope.spath1.bandit.1",
	"Bandit02": &"oldpine.outdoor.slope.spath1.bandit.2",
	"Bandit03": &"oldpine.outdoor.slope.spath1.bandit.3",
	"TallBandit": &"oldpine.outdoor.pine_entrance.pine1.tall_bandit.1",
	"FatBandit": &"oldpine.outdoor.pine_entrance.pine1.fat_bandit.1",
	"Serpent01": &"oldpine.gorge.lake.serpent.1",
	"Serpent02": &"oldpine.gorge.lake.serpent.2",
	"Serpent03": &"oldpine.gorge.lake.serpent.3",
	"Serpent04": &"oldpine.gorge.lake.serpent.4",
	"Serpent05": &"oldpine.gorge.lake.serpent.5",
}
const ORDER: Array[String] = ["Bandit01", "Bandit02", "Bandit03", "TallBandit", "FatBandit"]


static func body(map: WorldMapController, name: String) -> WorldCharacterBody2D:
	return map.runtime_body_for_spawn_point(POINTS[name])


static func bodies(map: WorldMapController, names: Array[String]) -> Array[WorldCharacterBody2D]:
	var result: Array[WorldCharacterBody2D] = []
	for name: String in names:
		result.append(body(map, name))
	return result


static func presence(map: WorldMapController, name: String) -> Area2D:
	return body(map, name).get_node("AggressionPresence") as Area2D


## The presence Area of spawned NPC `index` (spawn order) reports `other`.
static func presence_entered(map: WorldMapController, index: int, other: Node2D) -> void:
	map._on_presence_entered(other, map.npc_runtimes()[index].character_id)


static func presence_exited(map: WorldMapController, index: int, other: Node2D) -> void:
	map._on_presence_exited(other, map.npc_runtimes()[index].character_id)


## What queueing NPC `index`'s presence decides, as the retired
## _queue_bandit_presence() returned it.
static func queue_presence(map: WorldMapController, index: int, other: Node2D) -> NpcAggressionDecision:
	if not map.gameplay_open() or other != map.player_body or index < 0 or index >= map.npc_runtimes().size():
		return NpcAggressionDecision.new()
	return map.aggression_adapter().enter_player_presence(map.npc_runtimes()[index], map.player_runtime(), map._combat_allowed())


## A body arriving in a zone the way the retired per-zone callbacks moved it:
## the location follows the zone that owns the body's center.
static func enter_zone(map: WorldMapController, zone_id: StringName, other: Node2D) -> void:
	var character: WorldCharacterBody2D = other as WorldCharacterBody2D
	var zone: WorldPhysicalZoneArea2D = map.physical_zone(zone_id)
	if character != null and zone != null and map.gameplay_open() and zone.contains_center(character.global_position):
		character.set_world_location(map.location_for_zone(zone_id))


## The retired map-level Inventory: opens while the player is ACTIVE, even in a fight.
static func open_inventory(map: WorldMapController) -> bool:
	var hud: SharedGameplayUI = map.session.shared_ui()
	var player: WorldPlayerRuntimeState = map.player_runtime()
	if not map.gameplay_open():
		return false
	if player == null or not player.is_valid() or not player.exists_in_world or player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		hud.close_inventory()
		return false
	hud.show_inventory(map.session.player_inventory_rows())
	return true


static func inspect_item(map: WorldMapController, item_instance_id: StringName) -> bool:
	if not map.gameplay_open():
		return false
	var row: PlayerInventoryRowProjection = PlayerInventoryProjection.new().project_item(
		map.player_runtime(), map.inventory_state(), map.stack_collection(), map.item_instance_index(), item_instance_id,
	)
	if row == null:
		return false
	map.session.shared_ui().show_inventory_inspection(row)
	return true


## ES2 wield/unwield/wear/remove have no fighting gate; the adapters apply the rules.
static func wield(map: WorldMapController, id: StringName) -> OldPineEquipmentInteractionResult:
	if not map.gameplay_open():
		return OldPineEquipmentInteractionResult.new()
	return _refreshed(map, OldPineEquipmentInteractionAdapter.new().wield(map.player_runtime(), id, map.inventory_state(), map.item_instance_index()))


static func unwield(map: WorldMapController, id: StringName) -> OldPineEquipmentInteractionResult:
	if not map.gameplay_open():
		return OldPineEquipmentInteractionResult.new()
	return _refreshed(map, OldPineEquipmentInteractionAdapter.new().unwield(map.player_runtime(), id, map.inventory_state()))


static func wear(map: WorldMapController, id: StringName) -> OldPineArmorInteractionResult:
	if not map.gameplay_open():
		return OldPineArmorInteractionResult.new()
	return _refreshed(map, OldPineArmorInteractionAdapter.new().wear(map.player_runtime(), id, map.inventory_state(), map.item_instance_index()))


static func remove(map: WorldMapController, id: StringName) -> OldPineArmorInteractionResult:
	if not map.gameplay_open():
		return OldPineArmorInteractionResult.new()
	return _refreshed(map, OldPineArmorInteractionAdapter.new().remove(map.player_runtime(), id, map.inventory_state(), map.item_instance_index()))


static func _refreshed(map: WorldMapController, result: RefCounted) -> RefCounted:
	var hud: SharedGameplayUI = map.session.shared_ui()
	if hud.inventory_is_open():
		hud.show_inventory(map.session.player_inventory_rows())
	return result
