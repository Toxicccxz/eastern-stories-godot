extends RefCounted

const Fixture := preload("res://tests/support/beast_persistence_fixture.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	var f: Fixture = Fixture.new()
	var restored: OldPineRestoredNpcEntry = f.restore(f.capture())
	_eq(restored != null, true, "death fixture restores fresh graph B before death")
	if restored == null:
		return {"assertions": _assertions, "failures": _failures.duplicate()}
	f.npc = restored.runtime
	f.inventory = f.restored_items.domain_state.inventory
	f.stacks = f.restored_items.domain_state.combined_stacks
	var controller: OldPineOutdoorController = OldPineOutdoorController.new()
	# Detached controller only: exercise the actual typed adapter, no QA scene,
	# spawn ledger, input/cadence or player-visible validation claim.
	controller._all_npcs.append(f.npc)
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(f.npc, CombatSliceContentProfile.new())
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"test.location"), true, true, 1000000)
	var context: DeathContext = controller._death_context_for(binding, null, destination)
	_eq(context.is_valid(), true, "actual NPC death adapter yields valid context")
	_eq([context.victim_display_name, context.victim_gender, context.victim_age, context.victim_body_own_weight, context.victim_maximum_encumbrance], ["黑冠巨蟒", &"雄性", 400, 62000, 200000], "source chard corpse copies established NPC facts")
	_eq(context.victim_owner.equipment_state == f.npc.character_state.equipment, true, "death owner exact Equipment")
	_eq(context.victim_owner.armor_state == f.npc.armor, true, "death owner exact Armor")
	f.npc.character_state.attributes.strength = 99
	var after_strength_change: DeathContext = controller._death_context_for(binding, null, destination)
	_eq([after_strength_change.victim_body_own_weight, after_strength_change.victim_maximum_encumbrance], [62000, 200000], "death copies runtime body, never recalculates from current strength")
	var corpse_item: ItemInstance = ItemInstance.new(&"test.corpse", &"es2:obj/corpse")
	var result: DeathInventoryResult = DeathInventoryService.process(context, f.inventory, f.stacks, [], DeathItemPolicyRegistry.new(), DeathRewearPolicyRegistry.new(), corpse_item, ItemDefinition.new(&"es2:obj/corpse", "obj/corpse.c"))
	_eq(result.outcome, DeathInventoryResult.Outcome.COMPLETED, "unchanged Death core accepts serpent")
	_eq(f.inventory.own_weight(corpse_item.item_instance_id), 62000, "corpse registered with actual Beast weight")
	var corpse: CorpseState = result.corpse_state
	_eq([corpse.victim_display_name, corpse.victim_gender, corpse.victim_age, corpse.maximum_contents_encumbrance], ["黑冠巨蟒", &"雄性", 400, 200000], "corpse state facts")
	_eq(corpse.decay_stage, CorpseState.Stage.FRESH, "ordinary fresh corpse, no custom Beast lifecycle")
	_eq(f.inventory.registered_item_ids(), [&"test.corpse"], "only corpse: no silver/skin/fang/material/quest loot")
	_eq(f.inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse_item.item_instance_id)), [], "empty corpse inventory")
	_eq([result.direct_snapshot_ids, result.deferred_effects, corpse.occupied_worn_slots()], [[], [], []], "no invented loadout/events/worn item")
	_eq(result.corpse_placement_result.succeeded, true, "existing transfer places corpse")
	_eq(f.npc_random.calls, 3, "death did not initialize another Beast")
	_eq(f.restored_random.calls, 0, "restore graph B then death consumes zero initialization draws")
	# Player not registered in NPC lookup: preserve the pre-BF3 player adapter.
	var state: CharacterState = CharacterState.new(CharacterBaseAttributes.new(20))
	state.gender = CharacterState.GENDER_MALE
	var player: CombatSliceCharacterBinding = CombatSliceCharacterBinding.new(&"test.player", state, CombatRelationshipState.new(&"test.player"), ActionBusyState.new(), ArmorState.new(), CombatSliceContentProfile.new(), &"test.location", true, CombatSliceLifeStatus.Value.ACTIVE, true)
	var player_context: DeathContext = controller._death_context_for(player, null, destination)
	_eq([player_context.victim_display_name, player_context.victim_gender, player_context.victim_age, player_context.victim_body_own_weight, player_context.victim_maximum_encumbrance], ["Player", &"男性", 20, 60000, 100000], "player body policy unchanged")
	controller.free()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
