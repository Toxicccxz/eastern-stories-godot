extends RefCounted

const Fixture := preload("res://tests/support/beast_combat_fixture.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_live_state_and_bidirectional_projection()
	_test_real_armor_and_weapon_composition()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_live_state_and_bidirectional_projection() -> void:
	var f: Fixture = Fixture.new()
	_assert_projection(f, 60, 20, 90, 80, "initial")
	f.serpent.state.spirit.apply_damage(250)
	f.serpent.state.skills.set_raw_level(&"unarmed", 6)
	f.serpent.state.skills.set_raw_level(&"dodge", 8)
	f.serpent.state.skills.set_raw_level(&"parry", 10)
	f.serpent.busy.start_busy(2)
	var forward: CombatAttackInput = f.project(f.serpent, f.human)
	var defender: CombatAttackInput = f.project(f.human, f.serpent)
	_eq([forward.attacker.current_spirit, forward.attacker.maximum_spirit, forward.attacker.effective_attack_skill_level], [250, 500, 3], "live attacker spirit and raw/2")
	_eq([defender.defender.current_spirit, defender.defender.maximum_spirit, defender.defender.effective_dodge_skill_level, defender.defender.effective_parry_skill_level, defender.defender.effective_unarmed_skill_level, defender.defender.busy], [250, 500, 84, 5, 3, true], "live defender state, no permanent zero skills")
	var reverse: CombatReverseAttackProjection = f.reverse(f.serpent, f.human)
	_eq(reverse.attacker_authority().state() == f.serpent.state, true, "reverse exact live Character authority")
	_eq(reverse.attack_input_template().attacker.current_spirit, 250, "reverse current spirit")
	_eq(reverse.attack_input_template().attacker.effective_attack_skill_level, 3, "reverse new unarmed")
	reverse = f.reverse(f.human, f.serpent)
	_eq([reverse.attack_input_template().defender.effective_dodge_skill_level, reverse.attack_input_template().defender.effective_parry_skill_level, reverse.attack_input_template().defender.busy], [84, 5, true], "reverse defender symmetry")
	_eq([f.serpent.content.intrinsic_attack, f.serpent.content.intrinsic_dodge], [60, 80], "mutable skills do not rewrite authored facts")
	var other: Fixture = Fixture.new()
	_eq([other.serpent.state.spirit.current, other.serpent.state.skills.raw_level(&"unarmed")], [500, 0], "other character independent")


func _test_real_armor_and_weapon_composition() -> void:
	var f: Fixture = Fixture.new()
	var leather: NpcLoadoutItemDefinition = OldPineNpcDefinitions.leather_content()
	var item: ItemInstance = ItemInstance.new(&"test.leather", leather.item_definition().item_definition_id)
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, f.serpent.character_id)
	_eq(f.inventory.register_item(item, leather.own_weight), true, "register actual leather")
	_eq(InventoryTransferService.new().transfer(f.inventory, item.item_instance_id, InventoryTransferDestination.new(owner, true, true, 200000)).succeeded, true, "transfer actual leather to direct inventory")
	_eq(ArmorService.wear(f.serpent.armor, f.inventory, owner, item, leather.armor_definition()).succeeded, true, "real wear service")
	_assert_projection(f, 60, 20, 95, 78, "wear leather adds armor5/dodge-2")
	_eq(f.serpent.armor.remove(item.item_instance_id).succeeded, true, "real remove")
	_assert_projection(f, 60, 20, 90, 80, "remove leaves intrinsics intact")
	# Typed synthetic modifier fixture exercises nonzero attack/unarmed contributions;
	# no new authored item is added to production or a catalog.
	var mod_item: ItemInstance = ItemInstance.new(&"test.modifier", &"test.modifier.definition")
	var mods: ArmorNumericModifiers = ArmorNumericModifiers.new(7, 0, 3, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 2)
	f.inventory.register_item(mod_item, 1)
	InventoryTransferService.new().transfer(f.inventory, mod_item.item_instance_id, InventoryTransferDestination.new(owner, true, true, 200000))
	_eq(ArmorService.wear(f.serpent.armor, f.inventory, owner, mod_item, ArmorDefinition.new(mod_item.item_definition_id, &"test.slot", mods)).succeeded, true, "nonzero modifier fixture through real wear")
	_assert_projection(f, 63, 20, 97, 84, "add intrinsic and armor contributions once")
	_eq(f.project(f.serpent, f.human).attacker.effective_attack_skill_level, 2, "armor unarmed is separate from attack usage60+3")
	_eq(f.reverse(f.serpent, f.human).modifier_projection().attacker_attack_skill_modifier, 2, "reverse armor unarmed contribution")
	var sword: NpcLoadoutItemDefinition = OldPineNpcDefinitions.long_sword_content()
	var weapon_item: ItemInstance = ItemInstance.new(&"test.sword", sword.item_definition().item_definition_id)
	f.inventory.register_item(weapon_item, sword.own_weight)
	InventoryTransferService.new().transfer(f.inventory, weapon_item.item_instance_id, InventoryTransferDestination.new(owner, true, true, 200000))
	_eq(f.serpent.state.equipment.wield(EquippedWeaponRef.new(weapon_item.item_instance_id, sword.weapon_definition()), false).succeeded, true, "real equipment authority wield")
	_assert_projection(f, 63, 45, 97, 84, "verified long25 plus intrinsic20, both directions")
	_eq(f.project(f.serpent, f.human).attacker.effective_attack_skill_level, 0, "armor unarmed does not modify sword")
	_eq(f.project(f.serpent, f.human).selected_action.action_id, CombatSliceContentProfile.SLASH_ACTION_ID, "feature/attack.c weapon precedes race default")
	var rng: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([0])
	_eq(CombatActionSelector.select_action(CombatSliceProjectionBuilder.build_action_selection_input(f.serpent), rng).selected_action.action_id, CombatSliceContentProfile.SLASH_ACTION_ID, "verified actual weapon action provider")
	f.serpent.state.equipment.unwield(weapon_item.item_instance_id)
	f.serpent.armor.remove(mod_item.item_instance_id)
	_assert_projection(f, 60, 20, 90, 80, "unwield/remove restores only equipment delta")
	_eq(f.project(f.serpent, f.human).selected_action.action_id, BeastCombatActionDefinitions.BITE_ACTION_ID, "unwield returns to bite")
	_eq(f.serpent.state.skills.raw_skill_ids(), [], "wear and projection never write raw skills")


func _assert_projection(f: Fixture, attack: int, damage: int, armor: int, dodge: int, label: String) -> void:
	var a: CombatAttackInput = f.project(f.serpent, f.human)
	var d: CombatAttackInput = f.project(f.human, f.serpent)
	_eq([a.attacker.attack_usage_bonus, a.attacker.projected_apply_damage, d.defender.armor, d.defender.effective_dodge_skill_level], [attack, damage, armor, dodge], "%s forward pairs" % label)
	var ra: CombatReverseAttackProjection = f.reverse(f.serpent, f.human)
	var rd: CombatReverseAttackProjection = f.reverse(f.human, f.serpent)
	_eq([ra.modifier_projection().attacker_attack_usage_bonus, ra.modifier_projection().attacker_apply_damage, rd.modifier_projection().defender_armor, rd.modifier_projection().defender_dodge_skill_modifier], [attack, damage, armor, dodge], "%s reverse modifier pairs" % label)
	_eq([ra.attack_input_template().attacker.attack_usage_bonus, ra.attack_input_template().attacker.projected_apply_damage, rd.attack_input_template().defender.armor, rd.attack_input_template().defender.effective_dodge_skill_level], [attack, damage, armor, dodge], "%s reverse template pairs" % label)


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
