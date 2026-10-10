class_name WorldMapSelection
extends RefCounted
## What the player has selected (an NPC, a landmark, a corpse or a floor item) and the
## verbs on it: 查看, 攻击, 切磋, 打听, 转述, 说话, the context button and interact.
## Code moved from WorldMapController as it was; the map is `_map`.

var _map: WorldMapController
var selected_target: WorldInteractionTarget
var selected_landmark_available: bool = false

# The map's authorities, read as the controller reads them.
var session: WorldSessionController:
	get: return _map.session
var player_body: WorldCharacterBody2D:
	get: return _map.player_body
var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()
var _world_interaction_random: WorldInteractionRandomSource:
	get: return _map.world_interaction_random_source()


func _init(controller: WorldMapController) -> void:
	_map = controller


func selected_interaction_target() -> WorldInteractionTarget:
	return selected_target


func selected_character_id() -> StringName:
	if selected_target == null or selected_target.kind != WorldInteractionTarget.Kind.CHARACTER:
		return &""
	return selected_target.target_id


func selected_npc() -> NpcRuntimeState:
	return _map.npcs.find_resident_npc(selected_character_id())


func on_npc_selection_requested(character_id: StringName) -> void:
	select_npc(character_id)


func select_npc(character_id: StringName) -> bool:
	if not _map.gameplay_open() or session == null:
		return false
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
	if npc == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD:
		return false
	selected_target = WorldInteractionTarget.character(character_id)
	_map.hud().set_selected_target(npc)
	return true


func select_landmark(landmark_id: StringName) -> bool:
	if not _map.gameplay_open() or session == null or not _map.landmark_areas.has(landmark_id):
		return false
	var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
	selected_target = WorldInteractionTarget.landmark(landmark_id)
	selected_landmark_available = _map.landmark_available(landmark)
	_map.hud().set_selected_landmark(landmark, selected_landmark_available)
	return true


func inspect_selected() -> bool:
	if not _map.gameplay_open() or session == null or selected_target == null:
		return false
	match selected_target.kind:
		WorldInteractionTarget.Kind.ITEM:
			var floor_view: WorldFloorItemView = _map.floor_items.selected_floor_item()
			if floor_view != null:
				var floor_content: ItemContentDefinition = _map.floor_items.floor_item_content(floor_view)
				if floor_content == null or not _map.floor_items.floor_item_in_player_zone(floor_view):
					return false
				_map.hud().show_item_inspection(floor_content.display_name, floor_content.shown_description())
				return true
			var corpse: CorpseState = _map.corpses.find_corpse(selected_target.target_id)
			if corpse == null or not _map.corpses.corpse_is_live_in_world(corpse):
				return false
			_map.hud().show_corpse_inspection(corpse.victim_display_name, _map.corpses.corpse_content_count(corpse))
			return true
		WorldInteractionTarget.Kind.LANDMARK:
			var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(selected_target.target_id)
			var policy: WorldLandmarkPolicy = null if landmark == null else WorldLandmarkPolicies.create(landmark.policy)
			if policy == null:
				return false
			# look <item>: item_desc may be a function (house3.c's web calls a spider in).
			_map.hud().show_landmark_inspection(landmark, policy.look(_map, landmark))
			return true
	var npc: NpcRuntimeState = selected_npc()
	if npc == null or not npc.exists_in_map:
		return false
	var gender: StringName = npc.character_state.gender
	_map.hud().show_inspection(
		npc.definition(), FamilyRelation.of_npc(_player.state, npc.definition(), gender), gender,
		RelativeStrength.line(_player.state.progression.combat_experience, npc.character_state.progression.combat_experience),
	)
	_map.hostilities.look_berserk(npc)
	return true


func attack_selected() -> CombatSliceInitiationResult:
	var target: NpcRuntimeState = selected_npc() if _map.gameplay_open() else null
	if target == null or target.definition().dealings().is_fight_deferred():
		return CombatSliceInitiationResult.new()
	# kill.c checks the attacker's room, which in ES2 is also the target's.
	var catalog: ContentCatalog = GameContent.catalog()
	if catalog.zone_forbids_fighting(_player.world_location().zone_id) or catalog.zone_forbids_fighting(target.world_location().zone_id):
		_map.hud().append_log_lines([tr("这里不准战斗。")])
		return CombatSliceInitiationResult.new()
	# present(arg, environment(me)): an NPC selected before it walked away is not here.
	if not target.world_location().shares_combat_location(_player.world_location()):
		_map.hud().append_log_lines([tr("这里没有这个人。")])
		return CombatSliceInitiationResult.new()
	# cmds/std/kill.c: $N对著$n喝道：「<rude>！今日不是你死就是我活！」, then
	# obj->kill_ob(me) warns the player (_map.hostilities.announce_fight()).
	return _map.hostilities.initiate_lethal_combat(_player.character_id, target.character_id, [tr("你对著{npc}喝道：「{rude}！今日不是你死就是我活！」").format({
		"npc": tr(target.definition().display_name),
		"rude": tr(RankWords.query_rude(target.character_state.gender, target.age, target.definition().class_id)),
	})])


## cmds/std/fight.c for the selected NPC: ask a speaking character to spar; it
## accepts or refuses (NpcSparConsent). Beasts are not asked (no button).
func spar_selected() -> CombatSliceInitiationResult:
	var target: NpcRuntimeState = selected_npc() if _map.gameplay_open() else null
	if target == null or not target.definition().can_speak() or target.definition().dealings().is_fight_deferred():
		return CombatSliceInitiationResult.new()
	var catalog: ContentCatalog = GameContent.catalog()
	var name: String = tr(target.definition().display_name)
	if catalog.zone_forbids_fighting(_player.world_location().zone_id):
		_map.hud().append_log_lines([tr("这里禁止战斗。")])
		return CombatSliceInitiationResult.new()
	# present(arg, environment(me)): only someone in the same place can be asked.
	if not target.world_location().shares_combat_location(_player.world_location()):
		_map.hud().append_log_lines([tr("你想攻击谁？")])
		return CombatSliceInitiationResult.new()
	if target.relationship.has_opponent(_player.character_id):
		_map.hud().append_log_lines([tr("加油！加油！加油！")])
		return CombatSliceInitiationResult.new()
	if target.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		_map.hud().append_log_lines([tr("%s已经无法战斗了。") % name])
		return CombatSliceInitiationResult.new()
	var player_state: CharacterState = _player.state
	var lines: Array[String] = [tr("你对著{npc}说道：{self}{name}，领教{respect}的高招！").format({
		"npc": name, "self": tr(RankWords.query_self(player_state.gender, _player.facts.age, player_state.affiliation.class_id)),
		"name": _player.facts.display_name,
		"respect": tr(RankWords.query_respect(target.character_state.gender, target.age, target.definition().class_id, target.definition().rank_respect)),
	})]
	var consent: NpcSparConsent = spar_consent(target, true)
	var result := CombatSliceInitiationResult.new()
	if consent.accepted:
		var participants: Array[CombatSliceCharacterBinding] = _map.combat_lifecycle.build_participants()
		var player_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, _player.character_id)
		var target_binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, target.character_id)
		result = (
			# accept_fight() answered with kill_ob(): the NPC hunts the challenger.
			session.combat_encounter_coordinator().start_production(target_binding, player_binding, CombatTriggerCause.Value.NPC_AGGRESSION, true)
			if consent.kill
			else session.combat_encounter_coordinator().start_production(player_binding, target_binding, CombatTriggerCause.Value.PLAYER_SPAR)
		)
	var started: bool = result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED
	if consent.accepted and not started:
		# Accepted, yet this encounter model cannot hold the fight (e.g. someone
		# else's fight marks): say no rather than accept into nothing.
		if OS.is_debug_build():
			push_warning("Spar with %s accepted but not started: %s" % [target.character_id, CombatSliceInitiationResult.Outcome.find_key(result.outcome)])
	else:
		for line: NpcSparConsent.Line in consent.lines:
			var text: String = tr(line.text).replace("$RESPECT", tr(consent.respect)).replace("$SELF", tr(consent.npc_self))
			lines.append(tr("{npc}{action}").format({"npc": name, "action": text}) if line.emote else tr("{npc}说道：{line}").format({"npc": name, "line": text}))
	if not started:
		lines.append(tr("看起来%s并不想跟你较量。") % name)
	elif not consent.kill and spar_is_armed(target):
		# combatd.c wounds on `is_killing || weapon`: unlike a bare-handed spar, a
		# blade draws blood. Native hint; ES2 says nothing here.
		lines.append(tr("刀剑无眼，持兵刃比试可能真的受伤。"))
	if started:
		_map.hostilities.announce_fight(lines)
	else:
		_map.hud().append_log_lines(lines)
	return result


## fight.c's answer `target` gives the player now: NpcSparConsent.decide() draws
## nothing, so the HUD can know it before asking. `asked`: the spar itself, where an
## attitude that is a function (kid2.c) is drawn from the world-interaction stream.
func spar_consent(target: NpcRuntimeState, asked: bool = false) -> NpcSparConsent:
	var player_state: CharacterState = _player.state
	var attitude: int = -1
	var roll: NpcRandomText = target.definition().attitude_roll()
	if asked and roll != null:
		attitude = NpcContentRecords.attitude_of(String(roll.pick(_world_interaction_random.legacy_random(roll.bound))))
	return NpcSparConsent.decide(target, NpcSparConsent.Challenger.new(
		player_state.gender, _player.facts.age, player_state.affiliation.class_id, player_state.family.family_id,
	), attitude)


func selected_spar_risk() -> WorldMapController.SparRisk:
	var target: NpcRuntimeState = selected_npc() if _map.gameplay_open() else null
	if (
		target == null or not target.definition().can_speak() or target.definition().dealings().is_fight_deferred()
		or GameContent.catalog().zone_forbids_fighting(_player.world_location().zone_id)
		or not target.world_location().shares_combat_location(_player.world_location())
		or target.relationship.has_opponent(_player.character_id)
		or target.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
	):
		return WorldMapController.SparRisk.NONE
	var consent: NpcSparConsent = spar_consent(target)
	if not consent.accepted:
		return WorldMapController.SparRisk.NONE
	if consent.kill:
		return WorldMapController.SparRisk.DEADLY
	if spar_is_armed(target):
		return WorldMapController.SparRisk.ARMED
	return WorldMapController.SparRisk.STRONGER if selected_spar_stronger() else WorldMapController.SparRisk.NONE


## The selected NPC is clearly stronger than the player (RelativeStrength).
func selected_spar_stronger() -> bool:
	var target: NpcRuntimeState = selected_npc()
	return target != null and _player != null and RelativeStrength.clearly_stronger(
		_player.state.progression.combat_experience, target.character_state.progression.combat_experience,
	)


## attack_selected() would start a fight (none of kill.c's refusals).
func selected_attack_starts() -> bool:
	var target: NpcRuntimeState = selected_npc() if _map.gameplay_open() else null
	var catalog: ContentCatalog = GameContent.catalog()
	return (
		target != null and not target.definition().dealings().is_fight_deferred()
		and not catalog.zone_forbids_fighting(_player.world_location().zone_id)
		and not catalog.zone_forbids_fighting(target.world_location().zone_id)
		and target.world_location().shares_combat_location(_player.world_location())
	)


## Whether a spar with `target` is fought with a weapon in hand (the player's or
## its): combatd.c then wounds as in a fight to the death.
func spar_is_armed(target: NpcRuntimeState) -> bool:
	return target != null and _player != null and (
		not _player.state.equipment.is_primary_hand_empty() or not target.character_state.equipment.is_primary_hand_empty()
	)


## cmds/std/ask.c: the selected NPC can be asked when it speaks and is here
## (present()); a beast gets no 打听, as it gets no 切磋.
func can_ask_selected() -> bool:
	var target: NpcRuntimeState = selected_npc() if _map.gameplay_open() else null
	return (
		target != null and target.definition().can_speak() and target.exists_in_map
		and target.life_status != CharacterRuntimeLifeStatus.Value.DEAD
		and _player != null and target.world_location().shares_combat_location(_player.world_location())
	)


## The selected NPC when it is in the player's place (present()), alive: one an exert
## that names its target works on (lifeheal.c), awake or not.
func selected_npc_here() -> NpcRuntimeState:
	var target: NpcRuntimeState = selected_npc() if _map.gameplay_open() else null
	if (
		target == null or not target.exists_in_map or target.life_status == CharacterRuntimeLifeStatus.Value.DEAD
		or _player == null or not target.world_location().shares_combat_location(_player.world_location())
	):
		return null
	return target


## eff_kee * 100 / max_kee (herbalist.c heal_me()).
@warning_ignore("integer_division")
static func _kee_percent(state: CharacterState) -> int:
	return 0 if state.vitality.maximum <= 0 else state.vitality.effective * 100 / state.vitality.maximum


## What the selected NPC can be asked about, in ES2's listing order (NpcInquiry).
func ask_topics_selected() -> Array[String]:
	var topics: Array[String] = []
	if can_ask_selected():
		topics = NpcInquiry.topics(selected_npc().definition())
	return topics


## ask <npc> about <topic> on the selected NPC; its lines go to the log too. What
## the answer does happens here: marks on the player (d/green's set_temp() flags) and
## an item the NPC hands over (give.c; one the player cannot carry lands at their feet).
func ask_selected(topic: String) -> Array[String]:
	if not ask_topics_selected().has(topic):
		return []
	var target: NpcRuntimeState = selected_npc()
	var zone: ZoneDefinition = GameContent.catalog().zone(target.world_location().zone_id)
	var answer: NpcInquiry.Answer = NpcInquiry.answer(
		target.definition(), target.character_state.gender, target.age,
		target.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE,
		NpcInquiry.Asker.new(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id, _kee_percent(_player.state), _player.state.marks),
		topic, "" if zone == null else zone.display_name, _world_interaction_random, _map.floor_items.violates_unique,
	)
	for mark: String in answer.marks:
		_player.state.marks[mark] = 1
	for temp: String in answer.temps:
		_player.temp_marks[temp] = 1
	if not answer.hands_over.is_empty():
		_hand_over(target, answer)
	if not answer.gives.is_empty():
		var content: ItemContentDefinition = GameContent.catalog().item(answer.gives)
		var given: StringName = &"" if content == null else _map.floor_items.give_new_item_to_player(answer.gives)
		if not given.is_empty():
			# give.c to the receiver: "<npc>给你一<unit><name>。"
			answer.say(tr("{npc}给你{item}。").format({"npc": tr(target.definition().display_name), "item": HeldItemFacts.one_unit(content)}))
			var at_feet: String = _map.floor_items.at_feet_line(given, content)
			if not at_feet.is_empty():
				answer.say(at_feet)
			if not answer.mark_on_give.is_empty():
				_player.state.marks[answer.mark_on_give] = 1
	_map.hud().append_colored_lines(answer.lines)
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return answer.texts()


## command("give <it> to <player>") within an answer: the NPC's own carried item of that
## kind, give.c's line to the receiver, then what it says after (or, with none left,
## what it says instead).
func _hand_over(npc: NpcRuntimeState, answer: NpcInquiry.Answer) -> void:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)
	var carried: StringName = &""
	for item_id: StringName in _map.inventory_state().direct_children(holder):
		var item: ItemInstance = _map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == answer.hands_over:
			carried = item_id
			break
	var content: ItemContentDefinition = GameContent.catalog().item(answer.hands_over)
	var npc_owner := ItemLifecycleOwnerContext.new(npc.character_id, npc.character_state.equipment, npc.armor)
	var authorities := ItemHandlingService.Authorities.new(
		MoneyInventoryContext.new(npc_owner, _map.inventory_state(), _map.stack_collection(), _map.item_instance_index()),
		_map.food_collection(), _map.liquid_collection(), _map.item_id_allocator(),
	)
	var player_owner := ItemLifecycleOwnerContext.new(_player.character_id, _player.state.equipment, _player.armor)
	var held: int = 0 if carried.is_empty() else (_map.stack_collection().stack_state(carried).amount if _map.stack_collection().has_stack(carried) else 1)
	var moved: StringName = &"" if carried.is_empty() else ItemHandlingService.npc_hands_over(
		carried, answer.hands_over_amount, player_owner, _player.maximum_encumbrance, authorities,
	)
	if moved.is_empty() or content == null:
		answer.lines.append_array(answer.after_empty)
		return
	# What went: `amount` of them, or all he had when that was fewer (0: the whole
	# object, give.c's 一<unit><name>).
	var amount: int = 0 if answer.hands_over_amount <= 0 else mini(answer.hands_over_amount, held)
	var item_text: String = HeldItemFacts.one_unit(content)
	if amount == 2:
		# TRANSLATORS: two of a stack (两枚棋子): {unit} its measure word, {item} its name.
		item_text = tr("两{unit}{item}").format({"unit": tr(content.base_unit), "item": tr(content.display_name)})
	elif amount > 0:
		item_text = HeldItemFacts.counted(content, amount)
	# give.c to the receiver: "<npc>给你<amount><unit><name>。"
	answer.say(tr("{npc}给你{item}。").format({"npc": tr(npc.definition().display_name), "item": item_text}))
	answer.lines.append_array(answer.after)


## The lines the player can say beside the selected NPC that it answers (relay_say():
## oldman2.c's 必有妖孽); the UI offers them as 接话 instead of typing `say`.
func relay_phrases_selected() -> Array[String]:
	var phrases: Array[String] = []
	if can_ask_selected():
		phrases = selected_npc().definition().talk().relay_phrases()
	return phrases


## cmds/std/say.c beside the selected NPC, then its relay_say(). Badly hurt (kee below
## max_kee / 5) the player's words come out broken up ("必有妖孽 ..."), which the NPC
## does not take for its phrase. An unconscious NPC answers nothing.
@warning_ignore("integer_division")
func say_beside_selected(phrase: String) -> Array[String]:
	if not relay_phrases_selected().has(phrase):
		return []
	var target: NpcRuntimeState = selected_npc()
	var said: String = tr(phrase)
	var vitality: CharacterResourceState = _player.state.vitality
	if vitality.current < vitality.maximum / 5:
		said = said.replace(" ", " ... ") + " ..."
	var lines: Array[ColoredLine] = [ColoredLine.new(tr("你说道：%s") % said)]
	if said == tr(phrase) and target.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
		var respect: String = RankWords.query_respect(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id)
		for line: NpcLine in target.definition().talk().relay_answer(phrase):
			lines.append(line.colored(target.definition().display_name, respect))
	_map.hud().append_colored_lines(lines)
	return ColoredLine.texts(lines)


## The selected NPC's 剃度 when the player can kneel before it now (the kneel command
## daemon/class/bonze/master.c's init() adds): its ask_for_join() marked them and it is
## here and awake. 默认 (DECISIONS 山烟寺 B): ES2's add_action also shaved one before a
## master lying unconscious, whose say does nothing; here he must be awake.
func ordination_selected() -> NpcOrdination:
	var target: NpcRuntimeState = selected_npc() if can_ask_selected() else null
	var ordination: NpcOrdination = null if target == null else target.definition().ordination()
	if ordination == null or target.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or _player.temp_marks.get(ordination.temp, 0) == 0:
		return null
	return ordination


## kneel before the selected NPC (do_kneel()): its lines, its say with the new name,
## then the player's 法名 and class; the temp is gone. The lines go to the log too.
func kneel_selected() -> Array[String]:
	var ordination: NpcOrdination = ordination_selected()
	if ordination == null:
		return []
	var npc: String = tr(selected_npc().definition().display_name)
	var lines: Array[ColoredLine] = []
	for line: String in ordination.lines:
		# TRANSLATORS: message_vision(): the one kneeling, for the $N of a 剃度 line.
		lines.append(ColoredLine.new(tr(line).replace("$N", tr("你")).replace("$n", npc), ordination.color))
	var dharma_name: String = ordination.dharma_name(_player.facts.display_name, _world_interaction_random.legacy_random)
	lines.append(ColoredLine.new(tr("{npc}说道：{line}").format({"npc": npc, "line": NpcTalk.line(ordination.say).format({"name": dharma_name})})))
	_player.temp_marks.erase(ordination.temp)
	_player.take_name(dharma_name)
	_player.state.affiliation.class_id = ordination.class_id
	_map.player_body.refresh_label()
	_map.hud().append_colored_lines(lines)
	return ColoredLine.texts(lines)


## What the context button offers here: the nearest door or service in reach (a door
## when equally near), so beside 李火狮 by the school gate it is his lessons.
func interaction_title() -> String:
	var target: Variant = _context_target()
	if target is WorldService:
		return (target as WorldService).context_title()
	if target is StringName:
		var name_text: String = tr(GameContent.catalog().door(target).display_name)
		return (tr("关闭%s") if _map.doors_by_id[target].is_open() else tr("打开%s")) % name_text
	return ""


func interact() -> void:
	if ExplorationPresentationBlocker.is_blocked(_map.get_tree()):
		return
	var target: Variant = _context_target()
	if target is WorldService:
		(target as WorldService).interact()
	elif target is StringName:
		if _map.doors_by_id[target].is_open():
			_map.close_door(target)
		else:
			_map.open_door(target)


## A door's id or a WorldService, or null.
func _context_target() -> Variant:
	var best: Variant = null
	var nearest: float = INF
	var at: Vector2 = player_body.global_position
	for door_id: StringName in _map.doors_by_id:
		if _map.can_operate_door(door_id) and at.distance_to(_map.doors_by_id[door_id].wall_shape().global_position) < nearest:
			best = door_id
			nearest = at.distance_to(_map.doors_by_id[door_id].wall_shape().global_position)
	for candidate: WorldService in _map.service_nodes:
		if not candidate.context_title().is_empty() and at.distance_to(candidate.anchor()) < nearest:
			best = candidate
			nearest = at.distance_to(candidate.anchor())
	return best


## Back/Escape on a service panel. False when no service claims `content`.
func dismiss_panel(content: Control) -> bool:
	for candidate: WorldService in _map.service_nodes:
		if candidate.dismiss(content):
			return true
	return false
