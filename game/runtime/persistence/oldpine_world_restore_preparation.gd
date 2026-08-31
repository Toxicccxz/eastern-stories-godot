class_name OldPineWorldRestorePreparation
extends RefCounted

var player: WorldPlayerRuntimeState
var player_position: Vector2
var item_domain: NativeItemDomainState
var item_index: WorldItemInstanceIndex
var item_allocator: SessionItemIdAllocator
var npc_random: NpcInitializationRandomSource
var combat_random: CombatRandomSource
var world_interaction_random: WorldInteractionRandomSource
var _npc_entries: Array[OldPineRestoredNpcEntry] = []
var _corpse_entries: Array[OldPineRestoredCorpseEntry] = []


func _init(
	p_player: WorldPlayerRuntimeState = null,
	p_player_position: Vector2 = Vector2.ZERO,
	p_item_domain: NativeItemDomainState = null,
	p_item_index: WorldItemInstanceIndex = null,
	p_item_allocator: SessionItemIdAllocator = null,
	p_npc_random: NpcInitializationRandomSource = null,
	p_combat_random: CombatRandomSource = null,
	p_world_interaction_random: WorldInteractionRandomSource = null,
	p_npc_entries: Array[OldPineRestoredNpcEntry] = [],
	p_corpse_entries: Array[OldPineRestoredCorpseEntry] = [],
) -> void:
	player = p_player
	player_position = p_player_position
	item_domain = p_item_domain
	item_index = p_item_index
	item_allocator = p_item_allocator
	npc_random = p_npc_random
	combat_random = p_combat_random
	world_interaction_random = p_world_interaction_random
	_npc_entries = p_npc_entries.duplicate()
	_corpse_entries = p_corpse_entries.duplicate()


func npc_entries() -> Array[OldPineRestoredNpcEntry]:
	return _npc_entries.duplicate()


func corpse_entries() -> Array[OldPineRestoredCorpseEntry]:
	return _corpse_entries.duplicate()


func is_valid() -> bool:
	if (
		player == null
		or not player.is_valid()
		or not player_position.is_finite()
		or item_domain == null
		or item_index == null
		or item_allocator == null
		or not item_allocator.is_valid()
		or npc_random == null
		or combat_random == null
		or world_interaction_random == null
	):
		return false
	for entry: OldPineRestoredNpcEntry in _npc_entries:
		if entry == null or not entry.is_valid():
			return false
	for entry: OldPineRestoredCorpseEntry in _corpse_entries:
		if entry == null or not entry.is_valid():
			return false
	return true
