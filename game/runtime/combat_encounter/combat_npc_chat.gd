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
	if entry is NpcWeaponMatch:
		return _match_weapon(entry, actor, npc, enemies)
	if entry is NpcFightChat.Wield:
		return _wield(entry, actor, npc)
	if entry is NpcFightChat.SayByAge:
		return _say_by_age(entry, actor, npc, enemies)
	if entry is NpcFightChat.CallPartner:
		return _call_partner(entry, actor)
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
## the one this NPC fights to the death; in a spar there is none, and nothing happens.
func _call_partner(rule: NpcFightChat.CallPartner, actor: CombatSliceCharacterBinding) -> CombatNpcChatResult:
	if actor.relationship.lethal_target_ids().is_empty() or not _partner_for.is_valid():
		return null
	var partner_id: StringName = _partner_for.call(actor.character_id, rule.partner_id)
	var partner: NpcRuntimeState = _npc(partner_id)
	if partner == null:
		return null
	var name: String = TranslationServer.translate(partner.definition().display_name)
	var line := VisionLine.new(rule.line.sentence(name, ""), partner_id)
	return CombatNpcChatResult.new([line]).with_joiners([partner_id])


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
