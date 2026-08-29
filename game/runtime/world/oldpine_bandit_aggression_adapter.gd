class_name OldPineBanditAggressionAdapter
extends RefCounted

const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)

var _present_npc_ids: Array[StringName] = []
var _pending_npc_ids: Array[StringName] = []


func enter_player_presence(
	npc: NpcRuntimeState,
	player: WorldPlayerRuntimeType,
	combat_allowed: bool,
) -> OldPineAggressionDecision:
	var decision: OldPineAggressionDecision = _evaluate(
		npc,
		player,
		combat_allowed,
	)
	if decision.outcome != OldPineAggressionDecision.Outcome.READY:
		return decision
	if not _present_npc_ids.has(npc.character_id):
		_present_npc_ids.append(npc.character_id)
	if _pending_npc_ids.has(npc.character_id):
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.DUPLICATE_PENDING,
			npc.character_id,
		)
	_pending_npc_ids.append(npc.character_id)
	return OldPineAggressionDecision.new(
		OldPineAggressionDecision.Outcome.QUEUED,
		npc.character_id,
	)


func leave_player_presence(npc_id: StringName) -> void:
	_present_npc_ids.erase(npc_id)
	_pending_npc_ids.erase(npc_id)


func clear_npc(npc_id: StringName) -> void:
	leave_player_presence(npc_id)


func clear_all() -> void:
	_present_npc_ids.clear()
	_pending_npc_ids.clear()


func resolve_pending(
	ordered_npcs: Array[NpcRuntimeState],
	player: WorldPlayerRuntimeType,
	combat_allowed: bool,
) -> Array[OldPineAggressionDecision]:
	var decisions: Array[OldPineAggressionDecision] = []
	var pending: Array[StringName] = _pending_npc_ids.duplicate()
	_pending_npc_ids.clear()
	for npc: NpcRuntimeState in ordered_npcs:
		if npc == null or not pending.has(npc.character_id):
			continue
		if not _present_npc_ids.has(npc.character_id):
			decisions.append(
				OldPineAggressionDecision.new(
					OldPineAggressionDecision.Outcome.CANCELLED_NOT_PRESENT,
					npc.character_id,
				)
			)
			continue
		decisions.append(_evaluate(npc, player, combat_allowed))
	return decisions


func has_pending(npc_id: StringName) -> bool:
	return _pending_npc_ids.has(npc_id)


func pending_count() -> int:
	return _pending_npc_ids.size()


func is_present(npc_id: StringName) -> bool:
	return _present_npc_ids.has(npc_id)


func _evaluate(
	npc: NpcRuntimeState,
	player: WorldPlayerRuntimeType,
	combat_allowed: bool,
) -> OldPineAggressionDecision:
	var npc_id: StringName = &"" if npc == null else npc.character_id
	if npc == null or player == null or not npc.is_valid() or not player.is_valid():
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.INVALID_INPUT,
			npc_id,
		)
	if not npc.definition().has_capability(
		OldPineNpcDefinitions.AGGRESSIVE_ON_PLAYER_PRESENCE
	):
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.NOT_AUTHORED,
			npc_id,
		)
	if not player.exists_in_world or not player.combat_available:
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.PLAYER_NOT_AVAILABLE,
			npc_id,
		)
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.PLAYER_NOT_ACTIVE,
			npc_id,
		)
	if not npc.exists_in_map or not npc.combat_available:
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.NPC_NOT_AVAILABLE,
			npc_id,
		)
	if npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.NPC_NOT_ACTIVE,
			npc_id,
		)
	if npc.relationship.is_fighting():
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.NPC_ALREADY_FIGHTING,
			npc_id,
		)
	if not npc.world_location().shares_combat_location(player.world_location()):
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.DIFFERENT_COMBAT_LOCATION,
			npc_id,
		)
	if not combat_allowed:
		return OldPineAggressionDecision.new(
			OldPineAggressionDecision.Outcome.COMBAT_NOT_ALLOWED,
			npc_id,
		)
	return OldPineAggressionDecision.new(
		OldPineAggressionDecision.Outcome.READY,
		npc_id,
	)
