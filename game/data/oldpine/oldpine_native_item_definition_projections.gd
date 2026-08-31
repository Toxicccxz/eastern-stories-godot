class_name OldPineNativeItemDefinitionProjections
extends RefCounted

const CORPSE_DEFINITION_ID: StringName = &"es2:obj/corpse"
const CORPSE_LEGACY_SOURCE: String = "obj/corpse.c"


static func create() -> NativeItemDefinitionProjections:
	var items: Array[ItemDefinition] = []
	var weapons: Array[WeaponDefinition] = []
	var armor: Array[ArmorDefinition] = []
	var stacks: Array[CombinedStackDefinition] = []
	for content: NpcLoadoutItemDefinition in OldPineNpcDefinitions.loadout_item_definitions():
		if content == null or not content.is_valid():
			return NativeItemDefinitionProjections.new([ItemDefinition.new(&"")])
		var item_definition: ItemDefinition = content.item_definition()
		items.append(item_definition)
		var weapon_definition: WeaponDefinition = content.weapon_definition()
		if weapon_definition != null:
			weapons.append(weapon_definition)
		var armor_definition: ArmorDefinition = content.armor_definition()
		if armor_definition != null:
			armor.append(armor_definition)
		var stack_definition: CombinedStackDefinition = content.stack_definition()
		if stack_definition != null:
			stacks.append(stack_definition)
	items.append(ItemDefinition.new(CORPSE_DEFINITION_ID, CORPSE_LEGACY_SOURCE))
	return NativeItemDefinitionProjections.new(items, weapons, armor, stacks)
