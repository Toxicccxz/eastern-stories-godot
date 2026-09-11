class_name OldPineResidentMapController
extends WorldResidentMapController

## Compatibility boundary: only Old Pine maps need its concrete bootstrap,
## restore ledger, encounter coordinator and Cave handoff observations.
## Shared physical maps do not depend on that Session type.
var _session_owner: OldPineWorldSessionController
var _item_instance_scope: StringName = &""


func configure_session_authorities(
	p_session: OldPineWorldSessionController,
	p_player: WorldPlayerRuntimeState,
	p_inventory: InventoryState,
	p_stacks: CombinedStackCollection,
	p_item_index: WorldItemInstanceIndex,
	p_npc_random: NpcInitializationRandomSource,
	p_combat_random: CombatRandomSource,
	p_world_interaction_random: WorldInteractionRandomSource,
	p_item_id_allocator: SessionItemIdAllocator,
	p_world_simulation_gate: WorldSimulationGate,
) -> bool:
	if p_session == null or not configure_world_authorities(
		p_player, p_inventory, p_stacks, p_item_index, p_npc_random,
		p_combat_random, p_world_interaction_random, p_item_id_allocator,
		p_world_simulation_gate,
	):
		return false
	_session_owner = p_session
	_item_instance_scope = p_item_id_allocator.scope
	return true
