class_name WorldMapCombatLifecycle
extends RefCounted
## The map's side of a fight once it runs: participants and bindings, post actions
## (throw, bash, knock away), the encounter lifecycle (falls, deaths, corpses,
## killer_reward) and where a fallen character lands. Code moved from
## WorldMapController as it was; the map is `_map`.

var _map: WorldMapController
var post_actions: CombatSlicePostActions
var effects: SkillImprovementEffectRegistry
var weapon_resolver: WorldWeaponContentResolver = WorldWeaponContentResolver.new()
var player_content_resolution: WorldWeaponContentResolution
var _last_lifecycle_results: Array[CombatSliceLifecycleResult] = []
var _lifecycle_failed: bool = false

# The map's authorities, read as the controller reads them.
var session: WorldSessionController:
	get: return _map.session
var player_body: WorldCharacterBody2D:
	get: return _map.player_body
var _initialized: bool:
	get: return _map.is_map_initialized()
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()
var _inventory: InventoryState:
	get: return _map.inventory_state()
var _stacks: CombinedStackCollection:
	get: return _map.stack_collection()
var _item_index: WorldItemInstanceIndex:
	get: return _map.item_instance_index()
var _item_id_allocator: SessionItemIdAllocator:
	get: return _map.item_id_allocator()
var _world_interaction_random: WorldInteractionRandomSource:
	get: return _map.world_interaction_random_source()


func _init(controller: WorldMapController) -> void:
	_map = controller


## all_inventory(environment(actor)) without the actor, as an exert file sees it
## (roar.c): the NPCs in the actor's place, in the map's order, those in the fight
## through their fight bindings. An NPC whose fight is not ported is not there.
func exert_room(actor_id: StringName, bindings: Array[CombatSliceCharacterBinding]) -> Array[SpecialSide]:
	var room: Array[SpecialSide] = []
	var location: WorldLocationState = _location_for_character(actor_id)
	if location == null:
		return room
	for npc: NpcRuntimeState in _map.npcs.residents:
		if (
			npc.character_id == actor_id or not npc.exists_in_map or not npc.world_location().shares_combat_location(location)
			or npc.definition().dealings().is_fight_deferred()
		):
			continue
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, npc.character_id)
		if binding == null and npc.combat_available:
			binding = combat_binding_for(npc.character_id)
		if binding != null:
			room.append(CombatNpcChat.side_of(binding, npc))
	return room


## A fight binding for an NPC here that is not in the fight (one roar.c brings in).
func combat_binding_for(character_id: StringName) -> CombatSliceCharacterBinding:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
	if npc == null or not npc.exists_in_map:
		return null
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, _map.npcs.npc_content(npc))
	if binding != null:
		if post_actions == null:
			post_actions = CombatSlicePostActions.new(run_post_action)
		binding.post_actions = post_actions
	return binding


func encounter_combat_bindings(encounter: CombatEncounter) -> Array[CombatSliceCharacterBinding]:
	var result: Array[CombatSliceCharacterBinding] = []
	if not _initialized or encounter == null or not encounter.is_valid():
		return result
	var current: Array[CombatSliceCharacterBinding] = build_participants(true)
	for participant: CombatParticipant in encounter.participants():
		var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(current, participant.participant_id)
		if (
			binding == null
			or binding.state != participant.binding.state
			or binding.relationship != participant.binding.relationship
			or binding.busy != participant.binding.busy
			or binding.armor != participant.binding.armor
		):
			return []
		result.append(binding)
	return result


func encounter_skill_effect_registry() -> SkillImprovementEffectRegistry:
	return effects


func last_player_content_resolution() -> WorldWeaponContentResolution:
	return player_content_resolution


func build_participants(include_absent: bool = false) -> Array[CombatSliceCharacterBinding]:
	var result: Array[CombatSliceCharacterBinding] = []
	player_content_resolution = weapon_resolver.resolve(_player, _inventory, _item_index)
	var player_binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_player(
		_player,
		player_content_resolution.content_profile if player_content_resolution.succeeded else null,
	)
	if post_actions == null:
		post_actions = CombatSlicePostActions.new(run_post_action)
	if player_binding != null:
		player_binding.post_actions = post_actions
		result.append(player_binding)
	for npc: NpcRuntimeState in _map.npcs.residents:
		if not include_absent and not npc.exists_in_map:
			continue
		var content: CombatSliceContentProfile = _map.npcs.npc_content(npc)
		var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, content)
		if binding != null:
			binding.post_actions = post_actions
			result.append(binding)
	return result


## weapond.c's post_actions for one attack; what the player sees of it.
func run_post_action(binding: CombatSliceCharacterBinding, policy_id: StringName, victim: CombatSliceCharacterBinding, parried: bool, random: CombatRandomSource) -> Array[ColoredLine]:
	match policy_id:
		CombatPostActionIds.THROW_WEAPON:
			return _throw_weapon(binding)
		CombatPostActionIds.BASH_WEAPON:
			return _bash_weapon(binding, victim, parried, random)
	return []


## throw_weapon(): the weapon of the attack loses one of its amount; the last one is
## unequipped first and its thrower told (你的飞刀用完了！, tell_object()). At 0 it is
## gone (combined.c destructs it).
func _throw_weapon(binding: CombatSliceCharacterBinding) -> Array[ColoredLine]:
	var told: Array[ColoredLine] = []
	var weapon: EquippedWeaponRef = binding.state.equipment.primary_weapon()
	if weapon == null or not _stacks.has_stack(weapon.instance_id):
		return told
	if _stacks.stack_state(weapon.instance_id).amount == 1:
		binding.state.equipment.unwield(weapon.instance_id)
		if binding.is_user:
			# TRANSLATORS: weapond.c throw_weapon(): the last of a thrown weapon (飞刀) is gone.
			told.append(ColoredLine.new(tr("你的%s用完了！") % item_name(weapon.instance_id)))
	if not _map.floor_items.use_up_one(weapon.instance_id, ItemLifecycleOwnerContext.new(binding.character_id, binding.state.equipment, binding.armor)):
		push_error("throwing %s failed: the item state is inconsistent" % weapon.instance_id)
	return told


## bash_weapon() (hammers, staffs): a blow the victim parried with a weapon pits the two
## weapons, weight / 500 + rigidity + str each; random(wap) over 2 x wdp knocks the
## victim's weapon away, over wdp nearly, over wdp / 2 breaks it, else sparks.
## message_vision(): the room sees it. Rigidity is the item's set("rigidity") (the whips').
func _bash_weapon(binding: CombatSliceCharacterBinding, victim: CombatSliceCharacterBinding, parried: bool, random: CombatRandomSource) -> Array[ColoredLine]:
	var weapon: EquippedWeaponRef = binding.state.equipment.primary_weapon()
	var parrying: EquippedWeaponRef = null if victim == null else victim.state.equipment.primary_weapon()
	if weapon == null or parrying == null or not parried:
		return []
	@warning_ignore("integer_division")
	var wap: int = _inventory.own_weight(weapon.instance_id) / 500 + _rigidity(weapon) + binding.state.attributes.strength
	@warning_ignore("integer_division")
	var wdp: int = _inventory.own_weight(parrying.instance_id) / 500 + _rigidity(parrying) + victim.state.attributes.strength
	var roll: int = random.legacy_random(wap) if wap > 0 else 0
	var who: String = _vision_name(victim)
	var held: String = item_name(parrying.instance_id)
	if roll > 2 * wdp:
		# TRANSLATORS: weapond.c bash_weapon(): {who} (你 or a name) loses the weapon ({weapon}).
		var line := ColoredLine.new(tr("{who}只觉得手中{weapon}把持不定，脱手飞出！").format({"who": who, "weapon": held}), ColoredLine.HIW)
		var knocked: Array[ColoredLine] = []
		if _knock_away(victim, parrying.instance_id, false):
			knocked.append(line)
		return knocked
	if roll > wdp:
		# TRANSLATORS: weapond.c bash_weapon(): {who} nearly loses the weapon ({weapon}).
		return [ColoredLine.new(tr("{who}只觉得手中{weapon}一震，险些脱手！").format({"who": who, "weapon": held}))]
	@warning_ignore("integer_division")
	if roll > wdp / 2:
		# TRANSLATORS: weapond.c bash_weapon(): {who}'s weapon ({weapon}) breaks in two.
		var broken := ColoredLine.new(tr("只听见「啪」地一声，{who}手中的{weapon}已经断为两截！").format({"who": who, "weapon": held}), ColoredLine.HIW)
		var shown: Array[ColoredLine] = []
		if _knock_away(victim, parrying.instance_id, true):
			shown.append(broken)
		return shown
	# TRANSLATORS: weapond.c bash_weapon(): the two weapons meet; {me} and {who} are 你 or names.
	return [ColoredLine.new(tr("{me}的{weapon}和{who}的{other}相击，冒出点点的火星。").format({
		"me": _vision_name(binding), "weapon": item_name(weapon.instance_id), "who": who, "other": held,
	}))]


func _rigidity(weapon: EquippedWeaponRef) -> int:
	var content: ItemContentDefinition = GameContent.catalog().item(weapon.weapon_id)
	return 0 if content == null else content.weapon_rigidity


## unequip() and move(environment(victim)): the weapon falls at the victim's feet; a broken
## one is 断掉的 from then on (set("name"), set("value"), set("weapon_prop", 0)). False when
## the victim has no place to drop it in (nothing happens).
func _knock_away(victim: CombatSliceCharacterBinding, item_id: StringName, broken: bool) -> bool:
	var npc: NpcRuntimeState = null if victim.is_user else _map.npcs.find_resident_npc(victim.character_id)
	var location: WorldLocationState = _player.world_location() if victim.is_user else (null if npc == null else npc.world_location())
	var body: Node2D = player_body if victim.is_user else _map.npcs.runtime_body_for_character(victim.character_id)
	if location == null or body == null:
		return false
	victim.state.equipment.unwield(item_id)
	var moved: InventoryTransferResult = InventoryTransferService.new().transfer(
		_inventory, item_id, InventoryTransferDestination.new(WorldMapFloorItems.floor_endpoint(location), true, true, _map.WORLD_CAPACITY),
		victim.state.equipment, victim.armor,
	)
	if not moved.succeeded:
		push_error("knocking %s away failed: the item state is inconsistent" % item_id)
		return false
	if broken:
		var item: ItemInstance = _item_index.resolve(item_id)
		var broken_id: StringName = &"" if item == null else ItemContentDefinition.broken_id(item.item_definition_id)
		var form: ItemContentDefinition = GameContent.catalog().item(broken_id)
		if form == null or not _item_index.transmute(item_id, broken_id) or (_stacks.has_stack(item_id) and not _stacks.redefine(item_id, form.stack_definition())):
			push_error("breaking %s failed" % item_id)
	if not _map.floor_items.add_dropped_item_view(item_id, location, _map.floor_items.at_feet(location, body.global_position)):
		push_error("knocked-away %s has no view" % item_id)
	if victim.is_user and _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return true


## $N/$n as the player reads message_vision(): 你, or the character's name.
func _vision_name(binding: CombatSliceCharacterBinding) -> String:
	if binding.is_user:
		return tr("你")
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(binding.character_id)
	return "" if npc == null else tr(npc.definition().display_name)


## name() of a held item, in the shown language (断掉的 for a broken one).
func item_name(item_id: StringName) -> String:
	var item: ItemInstance = _item_index.resolve(item_id)
	var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
	return "" if content == null else tr(content.display_name)


func last_lifecycle_results() -> Array[CombatSliceLifecycleResult]:
	return _last_lifecycle_results.duplicate()


func lifecycle_is_pending() -> bool:
	return _lifecycle_failed


## Map-owned physical publication; rules remain in the existing lifecycle/death
## services. Encounter calls this only at its synchronous outer boundary.
func execute_encounter_lifecycle(victim: CombatSliceCharacterBinding, opportunity: CombatSliceOpportunityResult, participants: Array[CombatSliceCharacterBinding], last_hitter_id: StringName = &"") -> CombatSliceLifecycleResult:
	if _lifecycle_failed:
		return CombatSliceLifecycleResult.new()
	# Read before the lifecycle clears lethal relations and moves the body.
	var is_player: bool = _player != null and victim.character_id == _player.character_id
	var killer: CombatSliceCharacterBinding = _find_killer(victim, participants, last_hitter_id)
	var location: WorldLocationState = _location_for_character(victim.character_id)
	# killed_enemy() speaks before the dying player's ghost is moved away (damage.c die()).
	var killer_npc: NpcRuntimeState = null if killer == null else _map.npcs.find_resident_npc(killer.character_id)
	var killer_heard: bool = killer_npc != null and (_map.npc_life.player_hears(killer_npc) or (is_player and _map.npc_life.player_shares_zone(killer_npc)))
	var victim_npc: NpcRuntimeState = null if is_player else _map.npcs.find_resident_npc(victim.character_id)
	# chard.c make_corpse(): owner_is_killed() of what it carries (windspring.c) before the
	# corpse takes the rest: the item is gone, its NPC comes once the death is done.
	var comes: Array[StringName] = []
	if (victim_npc != null or is_player) and opportunity != null and opportunity.outcome == CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH:
		comes = _owner_is_killed(victim, &"" if victim_npc == null else victim_npc.definition().definition_id)
	var receipt: CombatSliceLifecycleResult = _execute_lifecycle(victim, opportunity, participants, killer)
	_last_lifecycle_results.append(receipt)
	# mind_bug.c die() runs its own lines before ::die()'s killer_reward().
	if receipt.completed() and receipt.outcome == CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE and victim_npc != null:
		_conjured_died(victim_npc, killer, participants)
	# damage.c unconcious(): winner_reward() on the last to hurt the one who falls, before the
	# dark (oldman.c defeated_enemy(): his line).
	if receipt.completed() and receipt.outcome == CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE and is_player and killer_npc != null:
		var hooks: NpcHooks = killer_npc.definition().hooks()
		if hooks != null and not hooks.defeated_say.is_empty() and _map.hud() != null:
			_map.hud().append_after_fight([ColoredLine.new(tr(hooks.defeated_say), hooks.defeated_color)])
	if receipt.completed() and receipt.outcome == CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE:
		for item_id: StringName in comes:
			_owner_killed_comes(item_id, location)
	if receipt.completed() and receipt.outcome == CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE and killer != null:
		_map.corpses.killed_enemy(killer_npc, killer_heard)
		# combatd.c killer_reward(): a possessed killer's reward goes to who called it (its
		# !is_living() test always holds: nothing defines is_living()).
		var rewarded: StringName = _map.npcs.summoners.get(killer.character_id, killer.character_id)
		if rewarded == _player.character_id and victim_npc != null:
			_player_killer_reward(victim_npc)
	if receipt.completed() and receipt.outcome == CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE and is_player and location != null:
		# damage.c die(): all_inventory(environment())->remove_killer(this_object()).
		for npc: NpcRuntimeState in _map.npcs.npc_runtimes():
			if npc.world_location() != null and npc.world_location().shares_combat_location(location):
				npc.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, false)
	if not receipt.completed():
		_lifecycle_failed = true
	elif is_player and session != null:
		session.on_player_lifecycle(receipt, killer != null, location)
	elif receipt.outcome == CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE and session != null:
		# damage.c unconcious(): call_out("revive", random(100 - con) + 30).
		var npc: NpcRuntimeState = _map.npcs.find_resident_npc(victim.character_id)
		if npc != null:
			npc.set_revive_in_ms(1000 * UnconsciousReviveDelay.seconds(npc.character_state.attributes.constitution, session.npc_revive_random_source()))
	return receipt


## owner_is_killed() of each item `victim` (an NPC of `definition_id`, or the player: "")
## carries that has one (ItemContentDefinition), unless the holder is the item's own NPC
## (sword_soul.c's sword): the item is destroyed now. Returns the item definitions whose
## NPC is to come. Its NPC is one summoned spawn on this map; while that one stands, or on
## a map without it, none can come and the item stays with the dead (默认: ES2 made another
## where the killer stood).
func _owner_is_killed(victim: CombatSliceCharacterBinding, definition_id: StringName) -> Array[StringName]:
	var comes: Array[StringName] = []
	var owner := ItemLifecycleOwnerContext.new(victim.character_id, victim.state.equipment, victim.armor)
	for item_id: StringName in _inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, victim.character_id)):
		var item: ItemInstance = _item_index.resolve(item_id)
		var content: ItemContentDefinition = null if item == null else GameContent.catalog().item(item.item_definition_id)
		if content == null or content.owner_killed_npc().is_empty() or content.owner_killed_unless() == definition_id:
			continue
		if not _map.npcs.can_summon_one(_owner_killed_spawn(content.owner_killed_npc())):
			continue
		var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(_inventory, _stacks, item_id, ItemLifecycleResult.ChildDisposition.DESTROY_SUBTREE, owner)
		if not (removal.succeeded and _item_index.forget_destroyed_snapshots(removal.removed_instance_ids, _inventory)):
			push_error("owner_is_killed: %s could not be destroyed" % item_id)
			continue
		comes.append(item.item_definition_id)
	return comes


## windspring.c owner_is_killed(): its NPC comes into the killer's place (the summoned spawn
## of that NPC on this map, where its master stood), the room reads its lines, and its
## chant() starts.
func _owner_killed_comes(item_definition_id: StringName, location: WorldLocationState) -> void:
	var content: ItemContentDefinition = GameContent.catalog().item(item_definition_id)
	var came: NpcRuntimeState = _map.npcs.summon_one(_owner_killed_spawn(content.owner_killed_npc()))
	if came == null:
		return
	if _player != null and location != null and _player.world_location().shares_combat_location(location) and _map.hud() != null:
		var lines: Array[ColoredLine] = []
		for line: String in content.owner_killed_lines():
			lines.append(ColoredLine.new(tr(line)))
		_map.hud().append_after_fight(lines)
	_map.npc_life.start_chant(came)


## The summoned spawn of `npc_definition_id` on this map ("" when none).
func _owner_killed_spawn(npc_definition_id: StringName) -> StringName:
	for spawn: NpcSpawnDefinition in GameContent.catalog().spawns_for_map(_map.map_id()):
		if spawn.summoned and spawn.npc_definition_id == npc_definition_id:
			return spawn.spawn_id
	return &""


## std/char.c heart_beat(): an NPC whose gin, kee or sen went below zero outside a
## fight (安惜迩's powerfade costs 100 sen) falls unconscious, or dies below zero
## effective, on its next beat. In a fight the encounter does it.
func fall_below_zero() -> void:
	for npc: NpcRuntimeState in _map.npcs.npc_runtimes():
		if not npc.exists_in_map or npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or npc.relationship.is_fighting():
			continue
		if npc.character_state.life_threshold() == CharacterState.LifeThreshold.ACTIVE:
			continue
		var content: CombatSliceContentProfile = _map.npcs.npc_content(npc)
		var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(npc, content)
		var required: CombatSliceOpportunityResult = null if binding == null else CombatSliceOpportunityExecutor.inspect_lifecycle(binding)
		if required == null:
			continue
		# The killer is last_damage_from (the player's poisoned blow too), while it stands here.
		var participants: Array[CombatSliceCharacterBinding] = [binding]
		var from_id: StringName = npc.relationship.last_damage_from_id
		var from: CombatSliceCharacterBinding = null
		if _player != null and from_id == _player.character_id and _player.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			player_content_resolution = weapon_resolver.resolve(_player, _inventory, _item_index)
			from = WorldCombatBindingAdapter.from_player(_player, player_content_resolution.content_profile if player_content_resolution.succeeded else null)
		else:
			var hitter: NpcRuntimeState = _map.npcs.find_resident_npc(from_id)
			if hitter != null and hitter != npc and hitter.exists_in_map and hitter.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
				from = WorldCombatBindingAdapter.from_npc(hitter, _map.npcs.npc_content(hitter))
		if from != null:
			participants.append(from)
		var receipt: CombatSliceLifecycleResult = execute_encounter_lifecycle(binding, required, participants, from_id)
		# combatd.c announce("unconcious"), heard in the same room (a drunk passing out).
		if receipt.outcome == CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE and _map.npc_life.player_hears(npc):
			_map.hud().append_log_lines([tr("%s脚下一个不稳，跌在地上一动也不动了。") % tr(npc.definition().display_name)])


## The same for the player outside a fight, after a condition's tick (snake_poison.c
## wounds kee without a `who`): the killer is whoever hurt the player last
## (last_damage_from), while that NPC still stands on this map.
## std/char.c heart_beat() below zero: a conscious player falls unconscious (or dies of
## a mortal wound). `even_unconscious`: one already lying there is taken below zero again
## (a greeting's blow, WorldMapActs) and dies, as heart_beat()'s !living() → die().
func player_fall_below_zero(even_unconscious: bool = false) -> void:
	var lying: bool = even_unconscious and _player != null and _player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS
	if _player == null or (_player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE and not lying) or _player.relationship.is_fighting():
		return
	if _player.state.life_threshold() == CharacterState.LifeThreshold.ACTIVE:
		return
	player_content_resolution = weapon_resolver.resolve(_player, _inventory, _item_index)
	var binding: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_player(
		_player,
		player_content_resolution.content_profile if player_content_resolution.succeeded else null,
	)
	var required: CombatSliceOpportunityResult = null if binding == null else CombatSliceOpportunityExecutor.inspect_lifecycle(binding)
	if required == null:
		return
	var participants: Array[CombatSliceCharacterBinding] = [binding]
	var from: NpcRuntimeState = _map.npcs.find_resident_npc(_player.relationship.last_damage_from_id)
	if from != null and from.exists_in_map and from.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
		var killer: CombatSliceCharacterBinding = WorldCombatBindingAdapter.from_npc(from, _map.npcs.npc_content(from))
		if killer != null:
			participants.append(killer)
	execute_encounter_lifecycle(binding, required, participants, _player.relationship.last_damage_from_id)


## combatd.c killer_reward() when the player killed an NPC (PlayerKillerReward): its
## tell_object() lines go to the log after the fight's result, so the HUD shows them last.
func _player_killer_reward(victim: NpcRuntimeState) -> void:
	var result: PlayerKillerReward.Result = PlayerKillerReward.apply(_player.state, victim.definition(), _world_interaction_random.legacy_random)
	if result.left_family:
		_player.take_title(PlayerKillerReward.REBEL_TITLE)
	if not result.lines.is_empty() and _map.hud() != null:
		_map.hud().append_after_fight(result.lines)


## mind_bug.c die() for the NPC the player's practice conjured: killed by the player
## (last_damage_from), improve_skill() by NpcConjuring.improvement() and its line; by
## anyone else (the 天将 they called), its lines and unconcious(), at once, in the fight
## too. tell_object() reaches a player who is conscious (an unconscious one's
## block_msg/all, and unconcious() returns at once); improve_skill() runs all the same.
## query_temp("mind_bug") is gone.
func _conjured_died(victim: NpcRuntimeState, killer: CombatSliceCharacterBinding, participants: Array[CombatSliceCharacterBinding]) -> void:
	var conjuring: NpcConjuring = victim.definition().conjuring()
	if conjuring == null or _player == null or _player.conjured_npc_id != victim.character_id:
		return
	_player.conjured_npc_id = &""
	var awake: bool = _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	var lines: Array[ColoredLine] = []
	if killer != null and killer.character_id == _player.character_id:
		for text: String in conjuring.killed_by_owner:
			lines.append(ColoredLine.new(tr(text)))
		var state: CharacterState = _player.state
		var amount: int = conjuring.improvement(state.attributes.spirituality, _world_interaction_random.legacy_random)
		var improvement: SkillImprovementResult = state.skills.improve_skill(conjuring.skill_id, amount, state.attributes.spirituality, false, true)
		var registry: SkillImprovementEffectRegistry = session.encounter_skill_effect_registry() if session != null else null
		var effect: SkillImprovementEffectResult = null if registry == null else registry.apply(state, improvement)
		lines.append_array(TrainingLines.improved(improvement, effect, GameContent.catalog().skill(conjuring.skill_id)))
	elif awake:
		for text: String in conjuring.killed_by_other:
			lines.append(ColoredLine.new(tr(text)))
		_player.state.fall_unconscious()
		var binding: CombatSliceCharacterBinding = null
		for candidate: CombatSliceCharacterBinding in participants:
			if candidate.character_id == _player.character_id:
				binding = candidate
		var required: CombatSliceOpportunityResult = null if binding == null else CombatSliceOpportunityExecutor.inspect_lifecycle(binding)
		if required != null:
			execute_encounter_lifecycle(binding, required, participants)
		else:
			player_fall_below_zero()
	if awake and _map.hud() != null:
		_map.hud().append_after_fight(lines)


func _execute_lifecycle(victim: CombatSliceCharacterBinding, opportunity: CombatSliceOpportunityResult, participants: Array[CombatSliceCharacterBinding], killer: CombatSliceCharacterBinding) -> CombatSliceLifecycleResult:
	var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(victim.character_id)
	var death_position: Vector2 = Vector2.ZERO if body == null else body.global_position
	var death_location: WorldLocationState = _location_for_character(victim.character_id)
	var destination: InventoryTransferDestination = _world_destination_for(victim.character_id)
	var allocation: SessionItemIdAllocationResult = _item_id_allocator.allocate(_inventory)
	if not allocation.succeeded:
		return CombatSliceLifecycleResult.new()
	var lifecycle: CombatSliceLifecycleResult = CombatSliceLifecycleAdapter.new().execute(
		opportunity,
		victim,
		participants,
		killer,
		_inventory,
		_stacks,
		allocation.item_instance_id,
		destination,
		_death_item_facts_for(victim.character_id),
		DeathItemPolicyRegistry.new(),
		DeathRewearPolicyRegistry.new(),
		_death_context_for(victim, killer, destination),
	)
	if lifecycle.completed():
		_sync_binding(victim)
		if body != null:
			body.refresh_runtime_state()
	var corpse: CorpseState = null if lifecycle.death_inventory_result == null else lifecycle.death_inventory_result.corpse_state
	if corpse == null:
		return lifecycle
	var view: CombatSliceCorpseView = _map.corpses.add_corpse_view(corpse, _map.corpses.corpse_position(death_position, death_location), death_location)
	if view == null:
		lifecycle._outcome = CombatSliceLifecycleResult.Outcome.WORLD_PUBLICATION_FAILED
		return lifecycle
	# Phase 6B3 keeps a partial corpse mutation and its view even when death
	# cannot complete; only a completed, indexed death becomes a loot interaction.
	if lifecycle.outcome != CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE:
		return lifecycle
	if not _item_index.register_snapshot(ItemInstance.new(corpse.corpse_item_instance_id, CombatSliceDeathAdapter.CORPSE_DEFINITION_ID)):
		lifecycle._outcome = CombatSliceLifecycleResult.Outcome.WORLD_PUBLICATION_FAILED
		return lifecycle
	_map.corpses.make_corpse_interactive(view)
	return lifecycle


func _death_context_for(victim: CombatSliceCharacterBinding, killer: CombatSliceCharacterBinding, destination: InventoryTransferDestination) -> DeathContext:
	if _player != null and victim.character_id == _player.character_id:
		return _player.death_context(destination, killer != null)
	var fallback: PlayerIdentityFacts = PlayerIdentityFacts.legacy_technical()
	var display_name: String = fallback.display_name
	var age: int = fallback.age
	var strength: int = victim.state.attributes.strength
	var body_weight: int = CharacterDerivedValues.human_weight(strength)
	var maximum_encumbrance: int = CharacterDerivedValues.maximum_encumbrance(strength)
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(victim.character_id)
	if npc != null:
		display_name = npc.definition().display_name
		age = npc.age
		# chard.c copies query_weight/query_max_encumbrance, not a fresh race setup.
		body_weight = npc.body_weight
		maximum_encumbrance = npc.maximum_encumbrance
	return DeathContext.new(
		victim.character_id,
		false,
		false,
		destination,
		ItemLifecycleOwnerContext.new(victim.character_id, victim.state.equipment, victim.armor),
		display_name,
		victim.state.gender,
		age,
		body_weight,
		maximum_encumbrance,
		false,
		destination.endpoint if killer != null else null,
		victim.state.gender,
		killer != null,
	)


func _death_item_facts_for(character_id: StringName) -> Array[DeathItemFacts]:
	var facts: Array[DeathItemFacts] = []
	var endpoint: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, character_id)
	# Current direct inventory, not the original bootstrap loadout or only sword.
	for item_id: StringName in _inventory.direct_children(endpoint):
		var item: ItemInstance = _item_index.resolve(item_id)
		if item == null:
			continue # Existing death validator fails closed on incomplete facts.
		var content: ItemContentDefinition = GameContent.catalog().item(item.item_definition_id)
		facts.append(DeathItemFacts.new(item, null if content == null else content.armor_definition()))
	return facts


func _sync_binding(binding: CombatSliceCharacterBinding) -> void:
	if binding.character_id == _player.character_id:
		WorldCombatBindingAdapter.sync_player(binding, _player)
		return
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(binding.character_id)
	if npc != null:
		WorldCombatBindingAdapter.sync_npc(binding, npc)


func _location_for_character(character_id: StringName) -> WorldLocationState:
	if _player != null and character_id == _player.character_id:
		return _player.world_location()
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
	return null if npc == null else npc.world_location()


func _world_destination_for(character_id: StringName) -> InventoryTransferDestination:
	var location: WorldLocationState = _location_for_character(character_id)
	return InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, location.combat_location_id),
		true,
		true,
		_map.WORLD_CAPACITY,
	)


## damage.c die(): the killer is last_damage_from, whoever hit the victim last,
## fight or kill. Without a hit in hand (a fall settled later) a participant
## holding a kill mark on either side stands in.
static func _find_killer(victim: CombatSliceCharacterBinding, participants: Array[CombatSliceCharacterBinding], last_hitter_id: StringName = &"") -> CombatSliceCharacterBinding:
	for candidate: CombatSliceCharacterBinding in participants:
		if candidate != victim and not last_hitter_id.is_empty() and candidate.character_id == last_hitter_id:
			return candidate
	for candidate: CombatSliceCharacterBinding in participants:
		if candidate != victim and (candidate.relationship.has_lethal_target(victim.character_id) or victim.relationship.has_lethal_target(candidate.character_id)):
			return candidate
	return null
