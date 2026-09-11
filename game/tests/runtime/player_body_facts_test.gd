extends RefCounted

var _count: int = 0
var _failures: Array[String] = []


func run_all(_tree: SceneTree) -> Dictionary[String, Variant]:
	_test_source_growth_and_carry()
	return {"assertions": _count, "failures": _failures}


func _test_source_growth_and_carry() -> void:
	var birth: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
	_check(birth.initialize(&"player", CharacterState.GENDER_FEMALE, "初雪", SessionItemIdAllocator.new(&"body-test")), "source graph initializes")
	var player: WorldPlayerRuntimeState = NewPlayerRuntimeComposition.create(&"player", birth.player, SnowWorldDefinitions.birth_location())
	_check(player.is_valid(), "explicit body runtime valid")
	var body: PlayerBodyFacts = player.body_facts
	_check(body == birth.player.body_facts, "birth/runtime share one exact body authority")
	_check(body.body_weight == 80000 and body.maximum_encumbrance == 150000, "LPC fresh str30 body80000/cap150000")
	var other: NewPlayerInitialization = NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "独立")
	_check(body != other.body_facts, "independent fresh Players do not share body objects")
	_grow(player, 128)
	_check(player.state.attributes.strength == 32, "unarmed129: 30 < 129/4=32, str +=2")
	_check(player.body_facts == body and body.body_weight == 80000 and body.maximum_encumbrance == 150000, "real registered effect does not refresh body")
	_check(other.state.attributes.strength == 30 and other.body_facts.body_weight == 80000, "other Player remains untouched")
	var world: InventoryTransferDestination = InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, &"fixture"), true, true, 1000000)
	var death: DeathContext = player.death_context(world, false)
	_check(death.victim_body_own_weight == 80000 and death.victim_maximum_encumbrance == 150000, "death copies established facts, NOT 84000/160000")
	_check(death.victim_display_name == "初雪" and death.victim_age == 14 and death.victim_gender == CharacterState.GENDER_FEMALE, "death identity unchanged")
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)
	_check(birth.inventory.contents_weight(owner) == 3000 and body.body_weight == 80000, "cloth contents weight is separate from own body weight")
	var item: ItemInstance = ItemInstance.new(&"ballast", &"test:ballast")
	_check(birth.inventory.register_item(item, 147001), "carry fixture registers")
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(owner, true, true, player.maximum_encumbrance)
	var transfer: InventoryTransferService = InventoryTransferService.new()
	_check(not transfer.transfer(birth.inventory, item.item_instance_id, destination).succeeded, "150001 contents rejected even with strength32")
	birth.inventory.update_own_weight(item.item_instance_id, 147000)
	_check(transfer.transfer(birth.inventory, item.item_instance_id, destination).succeeded, "exact150000 contents admitted by established capacity")
	_check(body.body_weight == 80000, "inventory mutation never changes own body")
	# Exercise the actual loot adapter's Player capacity consumer as well.
	var corpse: CorpseState = CorpseState.new(&"body-corpse", &"victim", "Victim", CharacterState.GENDER_MALE, 20, 50000)
	var corpse_item: ItemInstance = ItemInstance.new(&"body-corpse", &"es2:obj/corpse")
	birth.inventory.register_item(corpse_item, 0)
	birth.item_index.register_snapshot(corpse_item)
	_check(transfer.transfer(birth.inventory, corpse_item.item_instance_id, world).succeeded, "loot fixture corpse placed in world")
	var sword: ItemInstance = ItemInstance.new(&"body-loot", OldPineItemContentDefinitions.LONG_SWORD_ITEM_ID)
	birth.inventory.register_item(sword, 7000)
	birth.item_index.register_snapshot(sword)
	_check(transfer.transfer(birth.inventory, sword.item_instance_id, InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id), true, true, 50000)).succeeded, "loot fixture sword placed inside corpse")
	var loot: OldPineCorpseLootAdapter = OldPineCorpseLootAdapter.new()
	var denied: CorpseLootTransferResult = loot.take(player, corpse, sword.item_instance_id, true, birth.inventory, birth.stacks, birth.item_index)
	_check(not denied.succeeded and denied.outcome == CorpseLootTransferResult.Outcome.TRANSFER_FAILED, "real loot adapter rejects157000 despite strength32 derived160000")
	birth.inventory.update_own_weight(item.item_instance_id, 140000)
	var admitted: CorpseLootTransferResult = loot.take(player, corpse, sword.item_instance_id, true, birth.inventory, birth.stacks, birth.item_index)
	_check(admitted.succeeded and birth.inventory.contents_weight(owner) == 150000, "real loot adapter admits exact150000 using same authority")
	var signed: PlayerBodyFacts = PlayerBodyFacts.new(-1, -2)
	_check(signed.body_weight == -1 and signed.maximum_encumbrance == -2, "LPC signed facts preserved without invented clamp")
	var zero: PlayerBodyFacts = PlayerBodyFacts.new(0, 0)
	_check(zero.body_weight == 0 and zero.maximum_encumbrance == 0, "explicit zero facts are not silently derived")
	var missing: WorldPlayerRuntimeState = WorldPlayerRuntimeState.new(&"invalid", player.state, player.relationship, player.busy, player.armor, player.world_location())
	_check(not missing.is_valid() and missing.body_facts == null, "missing body fails validation instead of guessing")


func _grow(player: WorldPlayerRuntimeState, previous_level: int) -> void:
	# Controlled precondition, then the real generic progression + registered hook.
	# skill.c strict learned > (raw+1)^2; exactly one more point must level up.
	player.state.skills.set_raw_level(&"unarmed", previous_level)
	player.state.skills.set_learned_progress(&"unarmed", (previous_level + 1) * (previous_level + 1))
	var registry: SkillImprovementEffectRegistry = SkillImprovementEffectRegistry.new()
	registry.register_legacy_defaults()
	var improved: SkillImprovementResult = player.state.skills.improve_skill(&"unarmed", 1, 30, false, true)
	_check(improved.leveled_up and improved.current_level == previous_level + 1, "production improve_skill crosses strict threshold")
	var effect: SkillImprovementEffectResult = registry.apply(player.state, improved)
	_check(effect.status == SkillImprovementEffectResult.Status.APPLIED and effect.mutation_amount == 2, "registered authored effect applies exact +2")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("NGE5A0: " + label)
