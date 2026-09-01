class_name GameSaveTestFixture
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const Endpoint := preload("res://core/inventory/containment_endpoint.gd")


static func substantial(profile_id: StringName = &"test", marker: int = 1) -> GameSaveSnapshot:
	var character := Values.CharacterStateSnapshot.new(
		&"女性",
		Values.BaseAttributesSnapshot.new(21, 22, 23, 24, 25, 26, 27, 28, -3, 151),
		Values.ResourceTrackSnapshot.new(91, 93, 100),
		Values.ResourceTrackSnapshot.new(81 + marker, 90, 110),
		Values.ResourceTrackSnapshot.new(-1, 75, 99),
		Values.InternalResourcesSnapshot.new(45, 60, -2, 80, 77, 90, 1234, -5),
		Values.ProgressionSnapshot.new(9223372036854775807, 5432, -9),
		Values.SkillStateSnapshot.new(
			true,
			true,
			[Values.SkillValueSnapshot.new(&"force", 37), Values.SkillValueSnapshot.new(&"unarmed", 42)],
			[Values.SkillValueSnapshot.new(&"force", 88), Values.SkillValueSnapshot.new(&"open-skill", -1)],
			[Values.SkillMappingSnapshot.new(&"force", &"force")],
		),
		[
			Values.ConditionSnapshot.duration(&"bandaged", 3),
			Values.ConditionSnapshot.poison(&"open-poison", 11, -1, "毒性仍在。"),
		],
		Values.FamilySnapshot.new(&"family:oldpine", 4),
		Values.ApprenticeshipSnapshot.new(&"teacher:master", "師父", 2),
	)
	var location := Values.WorldLocationSnapshot.new(&"region:oldpine", &"map:outdoor", &"zone:pine", &"combat:pine")
	var player := Values.PlayerRuntimeSnapshot.new(&"character:player", character, &"active", true, true, 9000, location, Values.MapPositionSnapshot.new(-12.5, 333.25))
	var item_records: Array[NativeItemRecord] = [
		NativeItemRecord.new(&"armor:leather", &"definition:leather", 300, Endpoint.new(Endpoint.Kind.CHARACTER, &"character:player")),
		NativeItemRecord.new(&"corpse:bandit", &"definition:corpse", 1000, Endpoint.new(Endpoint.Kind.WORLD, &"world:outdoor")),
		NativeItemRecord.new(&"stack:coin", &"definition:coin", 17, Endpoint.new(Endpoint.Kind.CHARACTER, &"character:player")),
		NativeItemRecord.new(&"weapon:sword", &"definition:sword", 700, Endpoint.new(Endpoint.Kind.CHARACTER, &"character:player")),
	]
	var item_snapshot := NativeItemStateSnapshot.new(
		NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION,
		item_records,
		[NativeCombinedStackRecord.new(&"stack:coin", 17)],
		[NativeCharacterEquipmentRecord.new(&"character:player", &"weapon:sword")],
		[NativeCharacterArmorRecord.new(&"character:player", [NativeArmorSlotRecord.new(&"armor", &"armor:leather")])],
	)
	var npc := Values.NpcSpawnStateSnapshot.new(&"spawn:tall", &"point:tall", &"npc:tall-bandit", &"character:tall", false, &"dead", false, character, 31, 75000, 5000, location, Values.MapPositionSnapshot.new(40.0, -20.5), [&"weapon:sword"])
	var corpse := Values.CorpseSnapshot.new(&"corpse:bandit", &"character:tall", "高個土匪", &"男性", 31, 2, 10000, [Values.CorpseWornItemSnapshot.new(&"armor", &"armor:leather")], location, Values.MapPositionSnapshot.new(41.0, -19.5))
	return GameSaveSnapshot.new(
		Values.GameSaveMetadata.new(GameSaveSnapshot.FORMAT_ID, GameSaveSnapshot.CURRENT_SCHEMA_VERSION, "2026-08-31T12:34:56Z", Values.OptionalText.some("deadbeef"), profile_id, GameSaveSnapshot.FIXED_SLOT_ID),
		GameSaveSnapshot.SESSION_KIND_OLDPINE,
		Values.ItemIdAllocatorSnapshot.new(&"scope:test", -9223372036854775807 - 1),
		player,
		[npc],
		[corpse],
		item_snapshot,
		RandomStreamSnapshot.new(RandomStreamSnapshot.GODOT_PCG32_ADAPTER_ID, 1, 2),
		RandomStreamSnapshot.new(RandomStreamSnapshot.GODOT_PCG32_ADAPTER_ID, 3, 4),
		RandomStreamSnapshot.new(RandomStreamSnapshot.GODOT_PCG32_ADAPTER_ID, 5, 6),
	)
