class_name WorldMapSelection
extends RefCounted
## What the player has selected (an NPC, a landmark, a corpse or a floor item) and the
## verbs on it: 查看, 攻击, 切磋, 打听, 转述, 说话, the context button and interact.
## Code moved from WorldMapController as it was; the map is `_map`.

## How near a thing must be for the HUD to offer its actions (owner, 2026-10-11): about
## a shop counter's reach. Doors and room services keep their own authored reach.
const NEARBY_REACH: float = 96.0
# TRANSLATORS: native (A2): 攻击 on one of the 武馆's 木人 (training dummies), which are for sparring only.
const SPAR_ONLY: String = "木人是武馆拆招用的，只能切磋，打坏了还得赔。"

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


## A click or tap on an NPC in reach interacts with it (DECISIONS「说话和交互」), as E / A
## on it would; one out of reach does nothing.
func on_npc_selection_requested(character_id: StringName) -> void:
	on_thing_clicked(character_id)


## A click or tap on a landmark, a corpse or a floor item in reach does the same.
func on_thing_clicked(id: StringName) -> void:
	if _map.gameplay_open() and _map.hud() != null:
		_map.hud().interact_with(id)


func select_npc(character_id: StringName) -> bool:
	if not _map.gameplay_open() or session == null:
		return false
	var npc: NpcRuntimeState = _map.npcs.find_resident_npc(character_id)
	# name.c id() fails for one the player cannot see (a ghost): present() finds nothing.
	if npc == null or not npc.exists_in_map or npc.life_status == CharacterRuntimeLifeStatus.Value.DEAD or not _map.player_sees(npc):
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
			_map.hud().show_corpse_inspection(_map.corpses.corpse_name(corpse), _map.corpses.corpse_content_count(corpse), _map.corpses.corpse_long(corpse))
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
		"" if npc.mood() == null else npc.mood().title,
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
	# A2: the 武馆's 木人 are for sparring only.
	if target.definition().spar_only():
		_map.hud().append_log_lines([tr(SPAR_ONLY)])
		return CombatSliceInitiationResult.new()
	# cmds/std/kill.c: $N对著$n喝道：「<rude>！今日不是你死就是我活！」, then
	# obj->kill_ob(me) warns the player (_map.hostilities.announce_fight()).
	var shout: String = tr("你对著{npc}喝道：「{rude}！今日不是你死就是我活！」").format({
		"npc": tr(target.definition().display_name),
		"rude": tr(RankWords.query_rude(target.character_state.gender, target.age, target.definition().class_id)),
	})
	# An NPC's own kill_ob() that answers otherwise (oldman.c: his ghost story, then gone).
	var hooks: NpcHooks = target.definition().hooks()
	if hooks != null and hooks.has_kill_ob():
		var told: Array[ColoredLine] = [ColoredLine.new(shout)]
		for line: NpcLine in hooks.kill_ob_lines:
			told.append(line.colored(target.definition().display_name, ""))
		_map.hud().append_colored_lines(told)
		_map.npcs.vanish(target)
		return CombatSliceInitiationResult.new()
	return _map.hostilities.initiate_lethal_combat(_player.character_id, target.character_id, [shout])


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
		and not target.definition().spar_only()
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
	return can_ask(selected_npc())


## can_ask_selected() for any NPC (the HUD's nearby groups).
func can_ask(npc: NpcRuntimeState) -> bool:
	var target: NpcRuntimeState = npc if _map.gameplay_open() else null
	return (
		target != null and target.definition().can_speak() and target.exists_in_map
		and target.life_status != CharacterRuntimeLifeStatus.Value.DEAD
		and _player != null and target.world_location().shares_combat_location(_player.world_location())
	)


## The selected NPC when it is in the player's place (present()), alive: one an exert
## that names its target works on (lifeheal.c), awake or not.
func selected_npc_here() -> NpcRuntimeState:
	return npc_here(selected_npc())


## selected_npc_here() for any NPC: the NPC when it is in the player's place, else null.
func npc_here(npc: NpcRuntimeState) -> NpcRuntimeState:
	var target: NpcRuntimeState = npc if _map.gameplay_open() else null
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
		topics = NpcInquiry.topics(selected_npc().definition(), selected_npc().forgotten_topics())
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
		NpcInquiry.Asker.new(_player.state.gender, _player.facts.age, _player.state.affiliation.class_id, _kee_percent(_player.state), _player.state.marks, _player.state.progression.combat_experience, _map.acts.facts().carried),
		topic, "" if zone == null else zone.display_name, _world_interaction_random, _map.floor_items.violates_unique,
		target.forgotten_topics(), target.flags(),
	)
	if answer.vendor_list:
		_vendor_list(target, answer)
	for forgotten: String in answer.forgets:
		target.forget_topic(forgotten)
	for mark: String in answer.marks:
		_player.state.marks[mark] = 1
	# What was said goes on the 任务 page (an NPC out cold, or one that does not know, says nothing).
	var heard: Array[JournalLog.Fresh] = []
	var quests_heard: Array[StoryQuestLog.Fresh] = []
	if answer.answered and target.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
		heard = JournalLog.heard_entries(_player.state, target.definition().definition_id, NpcInquiry.asked_key(target.definition(), topic), GameContent.catalog().journal_chains())
		quests_heard = StoryQuestLog.heard(_player.state, target.definition().definition_id, NpcInquiry.asked_key(target.definition(), topic), GameContent.catalog().story_quests())
	for temp: String in answer.temps:
		_player.temp_marks[temp] = 1
	if not answer.hands_over.is_empty():
		_hand_over(target, answer)
	# captain.c tell_story(): call_out("make_stage", 2, who, 0).
	if answer.make != null:
		_map.npc_life.start_making(target, answer.make)
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
	# What was recorded of the answer, after the answer itself.
	session.tell_journal(heard)
	session.tell_quests(quests_heard)
	# guard.c ask_me(): the NPC turns (its mood: title, nickname, applies, a blade book in
	# hand) and kill_ob()s the asker.
	if not answer.mood.is_empty():
		var hooks: NpcHooks = target.definition().hooks()
		if hooks != null and hooks.moods.has(answer.mood):
			var mood: NpcMood = hooks.moods[answer.mood]
			target.put_in_mood(mood)
			for item_id: StringName in mood.carry:
				_map.floor_items.give_new_item_to(target, item_id)
	if answer.attacks:
		_map.npc_kills_player(target)
	if _map.hud().inventory_is_open():
		_map.hud().show_inventory(session.player_inventory_rows())
	return answer.texts()


## feature/vendor.c get_vendor_list(): the goods and their prices (price_string()), as
## `list` writes them; an NPC that sells nothing writes nothing.
func _vendor_list(npc: NpcRuntimeState, answer: NpcInquiry.Answer) -> void:
	var vendor: VendorDefinition = GameContent.catalog().vendor(npc.definition().dealings().vendor_id)
	if vendor == null:
		return
	answer.say(tr("你可以购买下列这些东西："))
	for key: String in vendor.goods_keys():
		var content: ItemContentDefinition = GameContent.catalog().item(vendor.item_definition_id(key))
		if content != null:
			answer.say(tr("{item}：{price}").format({"item": tr(content.display_name), "price": VendorService.price_string(vendor.price(key, content))}))


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


## Where `thing` is for the ring and the prompt (`title`) over it.
func focus_of(thing: WorldNearbyThing, title: String) -> WorldFocus:
	match thing.kind:
		WorldNearbyThing.Kind.NPC:
			return WorldFocus.new(title, thing, _map.npcs.runtime_body_for_character(thing.id))
		WorldNearbyThing.Kind.CORPSE:
			return WorldFocus.new(title, thing, _map.corpses.corpse_view_for(thing.id))
		WorldNearbyThing.Kind.ITEM:
			return WorldFocus.new(title, thing, _map.floor_items.floor_item_view(thing.id))
		WorldNearbyThing.Kind.LANDMARK:
			return WorldFocus.new(title, thing, _map.landmark_areas[thing.id])
		WorldNearbyThing.Kind.DOOR:
			return WorldFocus.new(title, thing, _map.doors_by_id[thing.id].wall_shape())
	return WorldFocus.new(title, thing, null, thing.services[0].anchor())


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


## What is within the player's reach, nearest first (owner, 2026-10-11): living NPCs in
## the player's place within NEARBY_REACH (and the constable leading the player, wherever
## he is) with the services they offer from their body,
## corpses and floor items there, landmarks near or touched, and the doors and room
## services whose own reach the player stands in. Empty outside open gameplay.
func nearby() -> Array[WorldNearbyThing]:
	var found: Array[WorldNearbyThing] = []
	if not _map.gameplay_open() or session == null or _player == null or player_body == null:
		return found
	var at: Vector2 = player_body.global_position
	var location: WorldLocationState = _player.world_location()
	var by_npc: Dictionary[StringName, WorldNearbyThing] = {}
	for npc: NpcRuntimeState in _map.npcs.npc_runtimes():
		var body: WorldCharacterBody2D = _map.npcs.runtime_body_for_character(npc.character_id)
		# The constable leading the player (yamen_po.c) is at hand wherever he walks: his
		# 行贿 is offered from the catch on (he caught them anywhere in the room).
		var leading: bool = body != null and _map.patrols.can_bribe(npc)
		var near: bool = (
			body != null and npc_here(npc) != null and _map.player_sees(npc)
			and at.distance_to(body.global_position) <= NEARBY_REACH
		)
		if not near and not leading:
			continue
		var thing := WorldNearbyThing.new(WorldNearbyThing.Kind.NPC, npc.character_id, npc.definition().display_name, at.distance_to(body.global_position))
		thing.npc = npc
		thing.bribe_only = not near
		by_npc[npc.character_id] = thing
		found.append(thing)
	for service: WorldService in _map.service_nodes:
		if service.context_title().is_empty():
			continue
		var keeper: NpcRuntimeState = (service as NpcService).npc if service is NpcService else null
		if keeper != null:
			if by_npc.has(keeper.character_id):
				by_npc[keeper.character_id].services.append(service)
			continue
		var room_service := WorldNearbyThing.new(WorldNearbyThing.Kind.SERVICE, service.service_id(), service.display_name(), at.distance_to(service.anchor()))
		room_service.services.append(service)
		found.append(room_service)
	for door_id: StringName in _map.doors_by_id:
		if _map.can_operate_door(door_id):
			found.append(WorldNearbyThing.new(WorldNearbyThing.Kind.DOOR, door_id, GameContent.catalog().door(door_id).display_name,
				at.distance_to(_map.doors_by_id[door_id].wall_shape().global_position)))
	for corpse: CorpseState in _map.corpses.corpse_states():
		var view: CombatSliceCorpseView = _map.corpses.corpse_view_for(corpse.corpse_item_instance_id)
		if view == null or not _map.corpses.corpse_is_live_in_world(corpse) or not _map.corpses.corpse_in_location(corpse, location):
			continue
		if at.distance_to(view.global_position) <= NEARBY_REACH or view.is_body_in_loot_range(player_body):
			found.append(WorldNearbyThing.new(WorldNearbyThing.Kind.CORPSE, corpse.corpse_item_instance_id, _map.corpses.corpse_name(corpse), at.distance_to(view.global_position)))
	for item_id: StringName in _map.floor_items.floor_item_ids():
		var floor_view: WorldFloorItemView = _map.floor_items.floor_item_view(item_id)
		if floor_view != null and floor_view.is_body_in_reach(player_body) and _map.floor_items.floor_item_in_player_zone(floor_view):
			found.append(WorldNearbyThing.new(WorldNearbyThing.Kind.ITEM, item_id, floor_view.display_name, at.distance_to(floor_view.global_position)))
	for landmark_id: StringName in _map.landmark_areas:
		var landmark: WorldLandmarkDefinition = GameContent.catalog().landmark(landmark_id)
		if landmark == null or not _map.landmark_available(landmark):
			continue
		var gap: float = _distance_to_area(_map.landmark_areas[landmark_id], at)
		if gap <= NEARBY_REACH:
			found.append(WorldNearbyThing.new(WorldNearbyThing.Kind.LANDMARK, landmark_id, landmark.display_name, gap))
	found.sort_custom(func(a: WorldNearbyThing, b: WorldNearbyThing) -> bool: return a.distance < b.distance)
	return found


## How far `point` is from a landmark's area (0 inside it).
static func _distance_to_area(area: Area2D, point: Vector2) -> float:
	var collision: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = null if collision == null or collision.disabled else collision.shape as RectangleShape2D
	if rectangle == null:
		return area.global_position.distance_to(point)
	var local: Vector2 = collision.to_local(point)
	var half: Vector2 = rectangle.size / 2.0
	return Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0)).length()
