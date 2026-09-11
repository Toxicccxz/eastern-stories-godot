class_name OldPineNativeItemDefinitionProjections
extends RefCounted

const CORPSE_DEFINITION_ID: StringName = &"es2:obj/corpse"
const CORPSE_LEGACY_SOURCE: String = "obj/corpse.c"


static func create(revision: WorldContentRevision.Value = WorldContentRevision.Value.LEGACY_OLDPINE_V1) -> NativeItemDefinitionProjections:
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
	if revision == WorldContentRevision.Value.SOURCE_ENTRY_V1:
		items.append(SourcePlayerCloth.item_definition())
		armor.append(SourcePlayerCloth.armor_definition())
	return NativeItemDefinitionProjections.new(items, weapons, armor, stacks)
