class_name VersionedSaveFixture
extends RefCounted

## Explicit format request, not a production conversion or automatic rewrite.
static func as_v1(value: GameSaveSnapshot) -> GameSaveSnapshot:
	var metadata: GameSaveValueTypes.GameSaveMetadata = value.metadata
	metadata.schema_version = GameSaveSnapshot.LEGACY_SCHEMA_VERSION
	return GameSaveSnapshot.new(metadata, value.session_kind, value.item_id_allocator, value.player,
		value.npc_spawn_states, value.corpses, value.items, value.combat_rng,
		value.npc_initialization_rng, value.world_interaction_rng, value.world_content_revision)
