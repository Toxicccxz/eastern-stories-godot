class_name CombatNpcChat
extends RefCounted

## std/char/npc.c chat() for an NPC in a fight, on the heart beat of its attack()
## (std/char.c; a busy beat says nothing): with chat_chance_combat percent it picks
## one of chat_msg_combat, both from the fight's random source. A line is said
## (say(): everyone else reads it); a special (NpcSpecials) runs against the fight
## as it is now. Only NPCs chat; the player is never one.
var _npc_for: Callable
var _wield_for: Callable
var _respect_for: Callable
var _wield_item_for: Callable
var _age_for: Callable
var _partner_for: Callable
var _summon_for: Callable
var _leave_for: Callable


## `npc_for`: (character_id: StringName) -> NpcRuntimeState, null for the player.
## `wield_for`: (character_id, skill type, wield: bool) -> CombatSliceContentProfile, the
## NPC taking up or putting away a weapon it carries (NpcWeaponMatch), and its combat
## content now (null when nothing changed). `respect_for`: (character_id)
## -> RANK_D->query_respect() of a participant, in the shown language.
func _init(npc_for: Callable, wield_for: Callable = Callable(), respect_for: Callable = Callable()) -> void:
	_npc_for = npc_for
	_wield_for = wield_for
	_respect_for = respect_for


## 青石村's fight chat (NpcFightChat). `wield_item_for`: (character_id, item definition
## ID) -> CombatSliceContentProfile after wielding a carried one, null when none was.
## `age_for`: (character_id) -> age. `partner_for`: (character_id, partner NPC definition
## ID) -> the character ID of that partner present() in the room and not fighting, or "".
func with_villagers(wield_item_for: Callable, age_for: Callable, partner_for: Callable) -> CombatNpcChat:
	_wield_item_for = wield_item_for
	_age_for = age_for
	_partner_for = partner_for
	return self


## A spell's summons (saveme.c's heaven soldier). `summon_for`: (caster character ID, NPC
## definition ID) -> the character ID of the NPC that came into the caster's place, or "".
func with_summons(summon_for: Callable) -> CombatNpcChat:
	_summon_for = summon_for
	return self


## npc.c random_move() in a fight (d/sanyen's cripple and 独眼头陀). `leave_for`:
## (character ID, draw: Callable) -> NpcRandomMove.Move the NPC makes from where it
## fights now, or null when go.c fails (a closed door, beyond its range).
func with_leaving(leave_for: Callable) -> CombatNpcChat:
	_leave_for = leave_for
	return self


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
	# woman1.c wield_weapon() sets its own chat_chance_combat lower for good.
	var chance: int = talk.combat_chat_chance if npc.combat_chat_chance < 0 else npc.combat_chat_chance
	if random_source.legacy_random(100) >= chance:
		return null
	var entries: Array = talk.combat_chat_entries()
	var entry: Variant = entries[clampi(random_source.legacy_random(entries.size()), 0, entries.size() - 1)]
	if entry is String:
		return CombatNpcChatResult.new([VisionLine.new(entry, actor.character_id)])
	if entry is ColoredLine:
		return CombatNpcChatResult.new([VisionLine.new(entry.text, actor.character_id, &"", entry.color)])
	if entry is StringName and entry == NpcTalk.RANDOM_MOVE:
		return _walk_out(actor, npc, random_source)
	if entry is NpcWeaponMatch:
		return _match_weapon(entry, actor, npc, enemies)
	if entry is NpcFightChat.Wield:
		return _wield(entry, actor, npc)
	if entry is NpcFightChat.SayByAge:
		return _say_by_age(entry, actor, npc, enemies)
	if entry is NpcFightChat.CallPartner:
		return _call_partner(entry, actor)
	if entry is NpcFightChat.Poison:
		return _poison(entry, actor, enemies, random_source)
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
	# A perform's own attacks (hasten.c's fight()s) run in the fight like the player's.
	var everyone: Array[CombatSliceCharacterBinding] = [actor]
	everyone.append_array(others)
	context.attack_source = CombatSpecialAttackSource.new(everyone, random_source, effects)
	NpcSpecials.run(entry, context)
	var joins: Array[CombatJoin] = _summon(actor, context)
	if context.lines.is_empty() and context.damaged.is_empty() and context.attacks.is_empty():
		return null
	var said := CombatNpcChatResult.new(context.lines, context.damaged).with_joins(joins)
	return said.with_special(context.report()) if not context.attacks.is_empty() else said


## oldman.c receive_damage(type, pts) after a blow took `damage` kee from `victim`
## (NpcHooks): above max_kee / divisor its hurt line, and when random(kee) is below the
## damage it walks out of the fight (random_move()); then, while it has pills and gin, kee
## or sen is below `pill_below`, its pill line, gin, kee and sen back to their eff_, a pill
## less. Null when it does nothing.
func hurt(victim: CombatSliceCharacterBinding, damage: int, random_source: CombatRandomSource) -> CombatNpcChatResult:
	var npc: NpcRuntimeState = _npc(victim.character_id)
	var hooks: NpcHooks = null if npc == null or npc.definition() == null else npc.definition().hooks()
	if hooks == null or not hooks.has_receive_damage():
		return null
	var lines: Array[VisionLine] = []
	var departure: StringName = &""
	var state: CharacterState = victim.state
	@warning_ignore("integer_division")
	if hooks.hurt_divisor > 0 and damage > state.vitality.maximum / hooks.hurt_divisor:
		lines.append(VisionLine.new(hooks.hurt_say, victim.character_id, &"", hooks.hurt_color))
		if random_source.legacy_random(state.vitality.current) < damage:
			var walked: CombatNpcChatResult = _walk_out(victim, npc, random_source)
			if walked != null:
				lines.append_array(walked.lines())
				departure = walked.departure_zone_id()
	var below: int = hooks.pill_below
	if npc.pills() > 0 and (state.vitality.current < below or state.essence.current < below or state.spirit.current < below):
		lines.append(VisionLine.new(hooks.pill_line, victim.character_id, &"", hooks.pill_color))
		state.essence.current = state.essence.effective
		state.vitality.current = state.vitality.effective
		state.spirit.current = state.spirit.effective
		npc.pills_left = npc.pills() - 1
	if lines.is_empty():
		return null
	var result := CombatNpcChatResult.new(lines)
	return result.with_departure(departure) if not departure.is_empty() else result


## go.c for one fighting: `往<dir>落荒而逃了。`, then remove_all_enemy(); the fight
## goes on without it (CombatEncounterResolution.depart()). A go that fails (go.c: busy,
## a shut door, beyond its range) says nothing.
func _walk_out(actor: CombatSliceCharacterBinding, npc: NpcRuntimeState, random_source: CombatRandomSource) -> CombatNpcChatResult:
	if not _leave_for.is_valid() or actor.busy.is_busy():
		return null
	var move: NpcRandomMove.Move = _leave_for.call(actor.character_id, random_source.legacy_random)
	if move == null:
		return null
	var line := VisionLine.new(move.flee_line(npc.definition().display_name), actor.character_id)
	return CombatNpcChatResult.new([line]).with_departure(move.to_zone_id)


## heaven_soldier.c invocation(caster): each soldier kill_ob()s the caster's living
## enemies, from the last (while(i--)), and the NPCs among them kill it back.
func _summon(actor: CombatSliceCharacterBinding, context: SpecialContext) -> Array[CombatJoin]:
	var targets: Array[StringName] = []
	for side: SpecialSide in context.enemies:
		if side.living:
			targets.push_front(side.character_id)
	var joins: Array[CombatJoin] = []
	for summoned_id: StringName in bring_summons(actor.character_id, context, _summon_for, _npc_for):
		joins.append(CombatJoin.new(summoned_id, targets, true))
	return joins


## Each NPC the spell called comes into the caster's place with its invocation() lines;
## the fight then admits it against the caster's enemies, when one of them is living()
## (invocation() kill_ob()s only those): those are returned. `summon_for` as in
## with_summons(), `npc_for` as in _init().
static func bring_summons(caster_id: StringName, context: SpecialContext, summon_for: Callable, npc_for: Callable) -> Array[StringName]:
	var joiners: Array[StringName] = []
	for definition_id: StringName in context.summons:
		var summoned_id: StringName = summon_for.call(caster_id, definition_id) if summon_for.is_valid() else &""
		var summoned: NpcRuntimeState = npc_for.call(summoned_id) if npc_for.is_valid() and not summoned_id.is_empty() else null
		if summoned == null or summoned.definition().summoning() == null:
			continue
		var summoning: NpcSummoning = summoned.definition().summoning()
		for text: String in summoning.arrive:
			var line := VisionLine.new(text, summoned_id, &"", summoning.color)
			line.actor_name = summoned.definition().display_name
			context.lines.append(line)
		if context.enemies.any(func(side: SpecialSide) -> bool: return side.living):
			joiners.append(summoned_id)
	return joiners


## consider(): the says, then wield or unwield (command() runs as it is reached).
func _match_weapon(rule: NpcWeaponMatch, actor: CombatSliceCharacterBinding, npc: NpcRuntimeState, enemies: Array[CombatSliceCharacterBinding]) -> CombatNpcChatResult:
	var seen: Array[NpcWeaponMatch.Enemy] = []
	for enemy: CombatSliceCharacterBinding in enemies:
		var respect: String = _respect_for.call(enemy.character_id) if _respect_for.is_valid() else ""
		seen.append(NpcWeaponMatch.Enemy.new(
			enemy.life_status == CombatSliceLifeStatus.Value.ACTIVE, not enemy.state.equipment.is_primary_hand_empty(), respect,
		))
	var decision: NpcWeaponMatch.Decision = rule.decide(seen, not actor.state.equipment.is_primary_hand_empty())
	if decision.change == NpcWeaponMatch.Change.NONE:
		return null
	var name: String = TranslationServer.translate(npc.definition().display_name)
	var lines: Array[VisionLine] = []
	for say: String in decision.says:
		# TRANSLATORS: an NPC's say() in a fight: {npc} its name, {line} what it says.
		lines.append(VisionLine.new(TranslationServer.translate("{npc}说道：{line}").format({"npc": name, "line": say}), actor.character_id))
	if _wield_for.is_valid():
		var content: CombatSliceContentProfile = _wield_for.call(actor.character_id, rule.weapon_type, decision.change == NpcWeaponMatch.Change.WIELD)
		# The rest of this advance's cycles reuse these bindings: they see the new weapon.
		actor.replace_content(content)
	return CombatNpcChatResult.new(lines)


## wield_weapon(), wield_something(): only with nothing in hand; the say, the wield.
func _wield(rule: NpcFightChat.Wield, actor: CombatSliceCharacterBinding, npc: NpcRuntimeState) -> CombatNpcChatResult:
	if not actor.state.equipment.is_primary_hand_empty() or not _wield_item_for.is_valid():
		return null
	var lines: Array[VisionLine] = []
	if not rule.say.is_empty():
		lines.append(VisionLine.new(_says(npc, rule.say), actor.character_id))
	var content: CombatSliceContentProfile = _wield_item_for.call(actor.character_id, rule.item_id)
	if content != null:
		actor.replace_content(content)
	if rule.combat_chance >= 0:
		npc.combat_chat_chance = rule.combat_chance
	return null if lines.is_empty() and content == null else CombatNpcChatResult.new(lines)


## converse_one(): measured against the first enemy (query_enemy() order).
func _say_by_age(rule: NpcFightChat.SayByAge, actor: CombatSliceCharacterBinding, npc: NpcRuntimeState, enemies: Array[CombatSliceCharacterBinding]) -> CombatNpcChatResult:
	if enemies.is_empty() or not _age_for.is_valid():
		return null
	var lines: Array[VisionLine] = []
	for say: String in rule.says(int(_age_for.call(enemies[0].character_id)), npc.age):
		lines.append(VisionLine.new(_says(npc, say), actor.character_id))
	return CombatNpcChatResult.new(lines)


## ask_for_help(): the partner here and not fighting does its line and comes in to kill
## query_temp("killer"), the last one this NPC kill_ob()ed (its kill_ob() keeps it); in
## a spar there is none, and nothing happens.
func _call_partner(rule: NpcFightChat.CallPartner, actor: CombatSliceCharacterBinding) -> CombatNpcChatResult:
	var killing: Array[StringName] = actor.relationship.lethal_target_ids()
	if killing.is_empty() or not _partner_for.is_valid():
		return null
	var partner_id: StringName = _partner_for.call(actor.character_id, rule.partner_id)
	var partner: NpcRuntimeState = _npc(partner_id)
	if partner == null:
		return null
	var name: String = TranslationServer.translate(partner.definition().display_name)
	var line := VisionLine.new(rule.line.sentence(name, ""), partner_id)
	return CombatNpcChatResult.new([line]).with_joins([CombatJoin.new(partner_id, [killing.back()])])


## use_poison(): enemy[random(sizeof(enemy))]; none of the condition yet: tell_object() it
## (only the player reads it), then random(my combat_exp) over its combat_exp poisons it.
func _poison(rule: NpcFightChat.Poison, actor: CombatSliceCharacterBinding, enemies: Array[CombatSliceCharacterBinding], random_source: CombatRandomSource) -> CombatNpcChatResult:
	if enemies.is_empty():
		return null
	var ob: CombatSliceCharacterBinding = enemies[clampi(random_source.legacy_random(enemies.size()), 0, enemies.size() - 1)]
	var current: DurationConditionPayload = ob.state.conditions.get_condition(rule.condition_id) as DurationConditionPayload
	if current != null and current.remaining != 0:
		return null
	var lines: Array[VisionLine] = []
	if _npc(ob.character_id) == null:
		lines.append(VisionLine.new(rule.tell, ob.character_id))
	if random_source.legacy_random(actor.state.progression.combat_experience) > ob.state.progression.combat_experience:
		ob.state.conditions.add_or_replace_duration(rule.condition_id, rule.duration)
	return null if lines.is_empty() else CombatNpcChatResult.new(lines)


## say(): "<name>说道：<line>", in the shown language.
static func _says(npc: NpcRuntimeState, say: String) -> String:
	# TRANSLATORS: an NPC's say() in a fight: {npc} its name, {line} what it says.
	return TranslationServer.translate("{npc}说道：{line}").format({
		"npc": TranslationServer.translate(npc.definition().display_name), "line": NpcTalk.line(say),
	})


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
