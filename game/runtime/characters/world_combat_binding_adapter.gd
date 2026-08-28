class_name WorldCombatBindingAdapter
extends RefCounted

const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)


static func from_player(
	player: WorldPlayerRuntimeType,
	content: CombatSliceContentProfile,
) -> CombatSliceCharacterBinding:
	if player == null or not player.is_valid() or content == null or not content.is_valid():
		return null
	return CombatSliceCharacterBinding.new(
		player.character_id,
		player.state,
		player.relationship,
		player.busy,
		player.armor,
		content,
		player.world_location().combat_location_id,
		player.exists_in_world,
		player.life_status,
		true,
		player.combat_available,
	)


static func from_npc(
	npc: NpcRuntimeState,
	content: CombatSliceContentProfile,
) -> CombatSliceCharacterBinding:
	if npc == null or not npc.is_valid() or content == null or not content.is_valid():
		return null
	return CombatSliceCharacterBinding.new(
		npc.character_id,
		npc.character_state,
		npc.relationship,
		npc.busy,
		npc.armor,
		content,
		npc.world_location().combat_location_id,
		npc.exists_in_map,
		npc.life_status,
		false,
		npc.combat_available,
	)


static func sync_player(
	binding: CombatSliceCharacterBinding,
	player: WorldPlayerRuntimeType,
) -> bool:
	if binding == null or player == null or binding.character_id != player.character_id:
		return false
	return (
		player.set_life_status(binding.life_status)
		and _sync_player_existence(binding, player)
	)


static func sync_npc(
	binding: CombatSliceCharacterBinding,
	npc: NpcRuntimeState,
) -> bool:
	if binding == null or npc == null or binding.character_id != npc.character_id:
		return false
	if not npc.set_life_status(binding.life_status):
		return false
	npc.set_exists_in_map(binding.exists_in_encounter)
	return true


static func _sync_player_existence(
	binding: CombatSliceCharacterBinding,
	player: WorldPlayerRuntimeType,
) -> bool:
	player.set_exists_in_world(binding.exists_in_encounter)
	return true
