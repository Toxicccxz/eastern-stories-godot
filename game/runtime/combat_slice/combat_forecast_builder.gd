class_name CombatForecastBuilder
extends RefCounted

## The 战前预判 for the player's 攻击 (or 切磋) on `target` as the map stands now: the
## same bindings and attack inputs a fight would open with (WorldMapCombatLifecycle,
## CombatSliceProjectionBuilder), the gang that would fall on the player with it
## (WorldMapHostilities.would_join()), read by CombatForecast without a draw.


## Null when the player or the target cannot be bound (nothing to foresee).
static func for_attack(map: WorldMapController, target: NpcRuntimeState) -> CombatForecast:
	if map == null or target == null:
		return null
	var everyone: Array[CombatSliceCharacterBinding] = map.combat_lifecycle.build_participants()
	var player: CombatSliceCharacterBinding = null
	for binding: CombatSliceCharacterBinding in everyone:
		if binding.is_user:
			player = binding
			break
	if player == null:
		return null
	var outgoing: Array[CombatAttackInput] = []
	var incoming: Array[CombatAttackInput] = []
	var kee: Array[int] = []
	var outgoing_chance: Array[float] = []
	var incoming_chance: Array[float] = []
	for npc: NpcRuntimeState in map.hostilities.would_join(target):
		var enemy: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(everyone, npc.character_id)
		if enemy == null:
			continue
		var out: CombatAttackInput = _attack(player, enemy)
		if out == null:
			continue
		outgoing.append(out)
		incoming.append(_attack(enemy, player))
		kee.append(enemy.state.vitality.current)
		outgoing_chance.append(_chance(player, enemy))
		incoming_chance.append(_chance(enemy, player))
	if outgoing.is_empty():
		return null
	return CombatForecast.estimate(outgoing, incoming, kee, player.state.vitality.current, outgoing_chance, incoming_chance)


## fight()'s courage gate (CombatFightDecisionFacts) as a chance per round.
static func _chance(attacker: CombatSliceCharacterBinding, victim: CombatSliceCharacterBinding) -> float:
	var facts: CombatFightDecisionFacts = CombatSliceProjectionBuilder.build_fight_facts(attacker, victim)
	if facts == null:
		return 1.0
	return CombatForecast.attack_chance(facts.attacker_raw_courage, facts.attacker_raw_bellicosity, facts.victim_raw_composure, facts.victim_busy)


static func _attack(attacker: CombatSliceCharacterBinding, defender: CombatSliceCharacterBinding) -> CombatAttackInput:
	var action: CombatActionDefinition = CombatSliceProjectionBuilder.template_action_for(attacker)
	return null if action == null else CombatSliceProjectionBuilder.build_attack_input(attacker, defender, action)
