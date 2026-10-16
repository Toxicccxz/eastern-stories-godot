class_name WorldMapThefts
extends RefCounted
## The player's cmds/std/steal.c on an NPC of this map, with NpcSteal's odds: the player names a
## thing the NPC is seen to wear or wield (look.c shows only those) or takes 随手摸一样 (steal.c
## picks one of everything it carries when the name matches nothing); asked first when the NPC
## is clearly stronger (RelativeStrength; plan default). Three seconds later: taken (得手了！),
## unnoticed, or caught (失手了！): the NPC attacks to kill (kill_ob()), the player is busy five
## and query("thief") + 1 (CrimeRecord), which the 县衙's constables catch thieves by.
## The call_out is this map's: it waits in a fight and goes when the player leaves the map.

const DELAY_SECONDS: float = 3.0
## steal.c: query("thief") * 20 off the thief's odds; me->start_busy(5) when caught.
const CAUGHT_BUSY: int = 5

## The steal under way: {npc, item, sp, dp, left}; empty when none (query_temp("stealing")).
var _pending: Dictionary = {}
var _map: WorldMapController

var session: WorldSessionController:
	get: return _map.session
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


func is_stealing() -> bool:
	return not _pending.is_empty()


## The steal under way as the HUD shows it (DECISIONS「响应性」): its three seconds kept, seen
## filling; null when none.
func wait() -> WorldWait:
	if _pending.is_empty():
		return null
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(_pending["npc"])
	var name: String = "" if npc == null else tr(npc.definition().display_name)
	# TRANSLATORS: the HUD while the player's steal waits for its chance (steal.c's three seconds): {npc} the one stolen from.
	return WorldWait.new(tr("等待机会对{npc}下手").format({"npc": name}), clampf(1.0 - float(_pending["left"]) / DELAY_SECONDS, 0.0, 1.0))


## The selected NPC can be stolen from: here (present(), awake or not), the player awake and
## free to act outside a fight.
func can_steal_selected() -> bool:
	return can_steal(_map.selection.selected_npc())


## can_steal_selected() for any NPC.
func can_steal(target: NpcRuntimeState) -> bool:
	var npc: NpcRuntimeState = _map.selection.npc_here(target)
	return npc != null and _player != null and _map.can_act(false)


## What look.c shows the NPC to carry: the things it wears or wields, in the order it carries
## them.
func seen_items(npc: NpcRuntimeState) -> Array[StringName]:
	var seen: Array[StringName] = []
	for item_id: StringName in _carried(npc):
		if npc.character_state.equipment.has_weapon_instance(item_id) or npc.armor.is_worn(item_id):
			seen.append(item_id)
	return seen


## The item's name as the list shows it.
func item_name(item_id: StringName) -> String:
	var content: ItemContentDefinition = _content(item_id)
	return "" if content == null else tr(content.display_name)


## Asked first: one caught at it is attacked to the death, and the NPC is clearly stronger.
func asks_first(npc: NpcRuntimeState) -> bool:
	return npc != null and _player != null and RelativeStrength.clearly_stronger(
		_player.state.progression.combat_experience, npc.character_state.progression.combat_experience,
	)


## steal <item> from <npc> (`item_id` empty: 随手摸一样). steal.c main()'s refusals, its pick and
## odds, and its line; compelete_steal() DELAY_SECONDS later. False when it did not start.
func begin(npc: NpcRuntimeState, item_id: StringName) -> bool:
	if npc == null or _player == null or not _map.can_act(false):
		return false
	var lines: Array[String] = []
	var started: bool = false
	if GameContent.catalog().zone_forbids_fighting(_player.world_location().zone_id):
		lines.append(tr("这里禁止行窃。"))
	elif is_stealing():
		lines.append(tr("你已经在找机会下手了！"))
	elif not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not _map.npc_life.player_shares_zone(npc):
		lines.append(tr("你想行窃的对象不在这里。"))
	else:
		var random: WorldInteractionRandomSource = session.world_interaction_random_source()
		var carried: Array[StringName] = _carried(npc)
		var target: StringName = item_id if carried.has(item_id) else &""
		if target.is_empty() and not carried.is_empty():
			target = carried[clampi(random.legacy_random(carried.size()), 0, carried.size() - 1)]
		var name: String = tr(npc.definition().display_name)
		if target.is_empty():
			lines.append(tr("{npc}身上看起来没有什麽值钱的东西好偷。").format({"npc": name}))
		else:
			# The player is never fighting here (the 偷窃 button is outside fights).
			var sp: int = NpcSteal.thief_odds(
				_player.state.skills.effective_level(&"stealing"), _player.state.attributes.karma,
				CrimeRecord.thief(_player.state), false,
			)
			var equipped: bool = npc.character_state.equipment.has_weapon_instance(target) or npc.armor.is_worn(target)
			var dp: int = NpcSteal.victim_odds(npc.character_state.spirit.current, _map.inventory_state().subtree_weight(target), npc.relationship.is_fighting(), equipped)
			_pending = {"npc": npc.character_id, "item": target, "sp": sp, "dp": dp, "left": DELAY_SECONDS}
			lines.append(tr("你不动声色地慢慢靠近{npc}，等待机会下手 ...").format({"npc": name}))
			started = true
	_map.hud().append_log_lines(lines)
	return started


## The call_out on this map's running time.
func advance(delta: float) -> void:
	if _pending.is_empty() or not is_finite(delta) or delta < 0.0:
		return
	_pending["left"] = float(_pending["left"]) - delta
	if float(_pending["left"]) <= 0.0:
		var pending: Dictionary = _pending
		_pending = {}
		_complete(pending)


## The player went to another map: the call_out is gone with it (茅山 B's rule).
func player_left() -> void:
	_pending = {}


## compelete_steal().
func _complete(pending: Dictionary) -> void:
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(pending["npc"])
	var hud: SharedGameplayUI = _map.hud()
	if _player == null or hud == null:
		return
	var awake: bool = _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	if npc == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not _map.npc_life.player_shares_zone(npc):
		if awake:
			hud.append_log_lines([tr("太可惜了，你下手的目标已经走了。")])
		return
	var item_id: StringName = pending["item"]
	var content: ItemContentDefinition = _content(item_id)
	if content == null or not _carried(npc).has(item_id):
		return
	var sp: int = pending["sp"]
	var dp: int = pending["dp"]
	var victim_awake: bool = npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	var random: WorldInteractionRandomSource = session.world_interaction_random_source()
	var outcome: NpcSteal.Outcome = NpcSteal.resolve(sp, dp, victim_awake, random)
	var npc_name: String = tr(npc.definition().display_name)
	var item_text: String = HeldItemFacts.one_unit(content)
	var lines: Array[ColoredLine] = []
	match outcome:
		NpcSteal.Outcome.TAKEN:
			# ob->move(me): the whole thing, or nothing when it is too heavy.
			if not _take(npc, item_id):
				lines.append(ColoredLine.new(tr("你摸到{item}，可是对你而言太重了，不得不放弃。").format({"item": item_text})))
			else:
				lines.append(ColoredLine.new(tr("得手了！"), ColoredLine.HIW))
				lines.append(ColoredLine.new(tr("你成功地偷到{item}！").format({"item": item_text})))
				if victim_awake:
					lines.append_array(_improve(random.legacy_random(_player.state.attributes.intelligence)))
				# random(sp) < dp / 2: others see it (nobody else to tell); the draw is kept.
				random.legacy_random(sp)
		NpcSteal.Outcome.UNNOTICED:
			lines.append(ColoredLine.new(tr("{npc}不经意地一转头，你急忙将手缩了回去！").format({"npc": npc_name})))
			lines.append(ColoredLine.new(tr("还好，没有被发现。")))
		NpcSteal.Outcome.CAUGHT:
			_caught(npc, content, lines)
			return
	if awake:
		hud.append_colored_lines(lines)
	if hud.inventory_is_open():
		hud.show_inventory(session.player_inventory_rows())


## Caught: its shout, improve_skill("stealing", 1), kill_ob(me) (a fight to the death the
## player only answers), me->start_busy(5) and thief + 1.
func _caught(npc: NpcRuntimeState, content: ItemContentDefinition, lines: Array[ColoredLine]) -> void:
	var npc_name: String = tr(npc.definition().display_name)
	var pronoun: String = tr("她") if npc.character_state.gender == CharacterState.GENDER_FEMALE else tr("他")
	lines.append(ColoredLine.new(tr("糟糕！你失手了！"), ColoredLine.HIR))
	# TRANSLATORS: steal.c's message_vision() as the player reads it: {npc} the one stolen from, {pronoun} 他 or 她, {item} what the player's hand is on.
	lines.append(ColoredLine.new(tr("{npc}一回头，正好发现你的手正抓著{pronoun}身上的{item}！").format({"npc": npc_name, "pronoun": pronoun, "item": tr(content.display_name)})))
	lines.append(ColoredLine.new(tr("{npc}喝道：「干什麽！」").format({"npc": npc_name})))
	lines.append_array(_improve(1))
	CrimeRecord.add_thief(_player.state, 1)
	var started: CombatSliceInitiationResult = _map.hostilities.npc_kills(npc, ColoredLine.texts(lines), lines)
	if started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		_player.busy.start_busy(CAUGHT_BUSY)
	else:
		_map.hud().append_colored_lines(lines)


## improve_skill("stealing", amount) and its lines (进步了).
func _improve(amount: int) -> Array[ColoredLine]:
	var state: CharacterState = _player.state
	var improvement: SkillImprovementResult = state.skills.improve_skill(&"stealing", amount, state.attributes.spirituality, false, true)
	var registry: SkillImprovementEffectRegistry = session.encounter_skill_effect_registry() if session != null else null
	var effect: SkillImprovementEffectResult = null if registry == null else registry.apply(state, improvement)
	return TrainingLines.improved(improvement, effect, GameContent.catalog().skill(&"stealing"))


## ob->move(me) from the NPC: the whole object, merged into what the player holds (what it
## wore or wielded comes off it). False when too heavy.
func _take(npc: NpcRuntimeState, item_id: StringName) -> bool:
	var npc_owner := ItemLifecycleOwnerContext.new(npc.character_id, npc.character_state.equipment, npc.armor)
	var authorities := ItemHandlingService.Authorities.new(
		MoneyInventoryContext.new(npc_owner, _map.inventory_state(), _map.stack_collection(), _map.item_instance_index()),
		_map.food_collection(), _map.liquid_collection(), _map.item_id_allocator(),
	)
	var player_owner := ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)
	return not ItemHandlingService.npc_hands_over(item_id, 0, player_owner, _player.maximum_encumbrance, authorities).is_empty()


func _carried(npc: NpcRuntimeState) -> Array[StringName]:
	return _map.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id))


func _content(item_id: StringName) -> ItemContentDefinition:
	var item: ItemInstance = _map.item_instance_index().resolve(item_id)
	return null if item == null else GameContent.catalog().item(item.item_definition_id)

