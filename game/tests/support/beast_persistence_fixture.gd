extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")

## Lowest-boundary test composition: real value types, capture, codec, item and
## Character restorers. It intentionally does NOT alter the production ledger or
## claim OldPineWorldRestoreComposition.prepare accepts a new serpent slot.
class CountingNpcRandom extends GodotNpcInitializationRandomSource:
	var calls: int = 0

	func _init(seed_value: int = 0) -> void:
		super(seed_value, true)

	func next_below(bound: int) -> int:
		calls += 1
		return super.next_below(bound)

var inventory: InventoryState = InventoryState.new()
var stacks: CombinedStackCollection = CombinedStackCollection.new()
var index: WorldItemInstanceIndex = WorldItemInstanceIndex.new()
var npc_random: CountingNpcRandom = CountingNpcRandom.new(73917)
var npc: NpcRuntimeState
var restored_items: NativeItemRestoreCompositionResult
var restored_random: CountingNpcRandom


func _init() -> void:
	npc = NpcCharacterStateFactory.new().create_one(
		OldPineNpcDefinitions.serpent_definition(), &"test.serpent", &"test.spawn", &"test.point",
		WorldLocationState.new(&"test.region", &"test.map", &"test.zone", &"test.location"),
		inventory, stacks, npc_random, [],
	)


func capture() -> GameSaveSnapshot:
	var capture_service: OldPineWorldSaveCapture = OldPineWorldSaveCapture.new()
	var character: Values.CharacterStateSnapshot = capture_service._character_snapshot(npc.character_state, "test.character")
	var item_result: NativeItemSnapshotCaptureResult = NativeItemPersistenceComposition.capture(
		inventory, stacks, index,
		[NativeCharacterEquipmentSource.new(npc.character_id, npc.character_state.equipment)],
		[NativeCharacterArmorSource.new(npc.character_id, npc.armor)],
		OldPineNativeItemDefinitionProjections.create(),
	)
	if character == null or not item_result.succeeded:
		return null
	var location: Values.WorldLocationSnapshot = OldPineWorldSaveCapture._location_snapshot(npc.world_location())
	var saved: Values.NpcSpawnStateSnapshot = Values.NpcSpawnStateSnapshot.new(
		npc.spawn_id, npc.spawn_point_id, npc.definition_id, npc.character_id,
		npc.exists_in_map, OldPineWorldSaveCapture._life_text(npc.life_status), npc.combat_available,
		character, npc.age, npc.body_weight, npc.maximum_encumbrance, location,
		Values.MapPositionSnapshot.new(17.5, -3.25), [],
	)
	# Root DTO requires a Player record; this is a schema fixture, not a Session.
	var player: Values.PlayerRuntimeSnapshot = Values.PlayerRuntimeSnapshot.new(
		&"test.player", Values.CharacterStateSnapshot.new(), &"active", true, true,
		0, location, Values.MapPositionSnapshot.new(),
	)
	return GameSaveSnapshot.new(
		Values.GameSaveMetadata.new(GameSaveSnapshot.FORMAT_ID, 1, "2026-09-10T12:00:00Z", Values.OptionalText.none(), &"test", GameSaveSnapshot.FIXED_SLOT_ID),
		GameSaveSnapshot.SESSION_KIND_OLDPINE, Values.ItemIdAllocatorSnapshot.new(&"test.bf3", 0),
		player, [saved], [], item_result.snapshot,
		GodotCombatRandomSource.new(123, true).capture_random_state(), npc_random.capture_random_state(),
		GodotWorldInteractionRandomSource.new(456, true).capture_random_state(),
	)


func restore(snapshot: GameSaveSnapshot) -> OldPineRestoredNpcEntry:
	if snapshot == null or not GameSaveSnapshotValidator.validate(snapshot).succeeded():
		return null
	var saved: Values.NpcSpawnStateSnapshot = snapshot.npc_spawn_states[0]
	var definition: NpcDefinition = OldPineNpcDefinitions.npc_by_id(saved.npc_definition_id)
	var body: NpcBodyFacts = NpcBodyFacts.derive(definition, saved.character.attributes.strength)
	if body == null or not body.matches_saved(saved.body_weight, saved.maximum_encumbrance):
		return null
	restored_items = NativeItemPersistenceComposition.restore(snapshot.items, OldPineNativeItemDefinitionProjections.create(), snapshot.item_id_allocator)
	if not restored_items.succeeded:
		return null
	var domain: NativeItemDomainState = restored_items.domain_state
	var state: CharacterState = CharacterStateSnapshotRestorer.restore(saved.character, domain.equipment_state(saved.character_id))
	if state == null:
		return null
	# Deliberate test-only grouping of the existing production constructors, not
	# fresh-create-and-patch: no factory, resource derivation, or RNG draw here.
	var runtime: NpcRuntimeState = NpcRuntimeState.new(
		saved.character_id, definition, saved.spawn_id, saved.spawn_point_id, state,
		CombatRelationshipState.new(saved.character_id), ActionBusyState.new(), domain.armor_state(saved.character_id),
		OldPineWorldRestoreComposition._location(saved.world_location),
		OldPineWorldRestoreComposition._life_status(saved.life_status), saved.combat_available, saved.exists_in_world,
		saved.age, saved.body_weight, saved.maximum_encumbrance, [],
	)
	restored_random = CountingNpcRandom.new(0)
	if not restored_random.restore_random_state(snapshot.npc_initialization_rng):
		return null
	return OldPineRestoredNpcEntry.new(runtime, Vector2(saved.map_position.x, saved.map_position.y))
