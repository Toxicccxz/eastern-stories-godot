class_name CombatNpcChat
extends RefCounted

## std/char/npc.c chat() for an NPC in a fight, on the heart beat of its attack()
## (std/char.c; a busy beat says nothing): with chat_chance_combat percent it picks
## one of chat_msg_combat, both from the fight's random source. A line is said
## (say(): everyone else reads it); a special (NpcSpecials) runs against the fight
## as it is now. Only NPCs chat; the player is never one.
var _npc_for: Callable


## `npc_for`: (character_id: StringName) -> NpcRuntimeState, null for the player.
func _init(npc_for: Callable) -> void:
	_npc_for = npc_for


## What the NPC's chat() did this beat, or null when it did nothing visible.
func beat(
	actor: CombatSliceCharacterBinding,
	enemies: Array[CombatSliceCharacterBinding],
	others: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effects: SkillImprovementEffectRegistry,
) -> CombatNpcChatResult:
	var npc: NpcRuntimeState = _npc(actor.character_id)
	if npc == null or npc.definition() == null:
		return null
	var talk: NpcTalk = npc.definition().talk()
	if talk == null or not talk.has_combat_chat():
		return null
	if random_source.legacy_random(100) >= talk.combat_chat_chance:
		return null
	var entries: Array = talk.combat_chat_entries()
	var entry: Variant = entries[clampi(random_source.legacy_random(entries.size()), 0, entries.size() - 1)]
	if entry is String:
		return CombatNpcChatResult.new([VisionLine.new(entry, actor.character_id)])
	if entry is ColoredLine:
		return CombatNpcChatResult.new([VisionLine.new(entry.text, actor.character_id, &"", entry.color)])
	if not (entry is NpcSpecialAction):
		return null
	var other_sides: Array[SpecialSide] = []
	for binding: CombatSliceCharacterBinding in others:
		other_sides.append(side_of(binding, _npc(binding.character_id)))
	var enemy_sides: Array[SpecialSide] = [] # query_enemy() order: offensive_target() keeps it.
	for binding: CombatSliceCharacterBinding in enemies:
		for side: SpecialSide in other_sides:
			if side.character_id == binding.character_id:
				enemy_sides.append(side)
	var context := SpecialContext.new(
		side_of(actor, npc), enemy_sides, random_source.legacy_random, GameContent.catalog(), effects, other_sides,
	)
	NpcSpecials.run(entry, context)
	if context.lines.is_empty() and context.damaged.is_empty():
		return null
	return CombatNpcChatResult.new(context.lines, context.damaged)


## A fight participant as the special files see it.
static func side_of(binding: CombatSliceCharacterBinding, npc: NpcRuntimeState) -> SpecialSide:
	var side := SpecialSide.new(
		binding.character_id, binding.state, binding.busy, binding.relationship,
		func(key: StringName) -> int: return CombatSliceProjectionBuilder.apply_of(binding, key),
	)
	side.living = binding.life_status == CombatSliceLifeStatus.Value.ACTIVE
	side.location_id = binding.location_id
	side.is_user = binding.is_user
	side.age = 0 if npc == null else npc.age
	return side


func _npc(character_id: StringName) -> NpcRuntimeState:
	return _npc_for.call(character_id) if _npc_for.is_valid() else null
