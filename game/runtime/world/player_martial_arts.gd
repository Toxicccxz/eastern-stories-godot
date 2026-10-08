class_name PlayerMartialArts
extends RefCounted

## The player's own training, anywhere outside a fight (the character panel's 武学
## page): cmds/std/enable.c, practice.c, exercise.c, selflearn.c, study.c, enforce.c
## and exert.c, each with fresh facts. The lines go to the log; `last_lines` keeps
## them for the page. Every request is refused (no lines) while portable actions are
## closed: in a fight, unconscious, between maps. enforce.c alone also works in the
## player's fight (the battle panel), where its lines are the battle log's; exert in a
## fight is the battle panel's queued action (CombatExertTacticalPolicy).

var last_lines: Array[ColoredLine] = []
var _session: WorldSessionController
var _learn_policies: SkillLearnPolicyRegistry


func _init(session: WorldSessionController) -> void:
	_session = session
	_learn_policies = SkillLearnPolicyRegistry.new()
	_learn_policies.register_known_legacy_policies()


func available() -> bool:
	return _session != null and _session.portable_inventory_available()


## query_temp("apply/<key>"): the worn armor's armor_prop, the wielded weapon's
## weapon_prop (equip.c) and timed applies (powerup), as combat counts them.
func apply_modifier(key: StringName) -> int:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return apply_of(player.state, player.armor, key)


static func apply_of(state: CharacterState, armor: ArmorState, key: StringName) -> int:
	var value: int = armor.aggregate_numeric_modifiers().value(key)
	# equip.c wield(): both hands' weapon_prop (as CombatSliceProjectionBuilder._apply).
	for weapon: EquippedWeaponRef in [state.equipment.primary_weapon(), state.equipment.secondary_weapon()]:
		var content: ItemContentDefinition = null if weapon == null else GameContent.catalog().item(weapon.weapon_id)
		if content != null:
			value += content.weapon_apply.get(key, 0)
	return value + state.timed_applies.value(key)


## query_skill(skill): half the raw level, the mapped skill's level and apply/<skill>.
func effective_level(skill_id: StringName) -> int:
	return _session.player_runtime().state.skills.effective_level(skill_id, apply_modifier(skill_id))


## query_skill("force").
func force_level() -> int:
	return effective_level(&"force")


## The highest factor enforce.c accepts now.
func enforce_limit() -> int:
	return EnforceService.limit(force_level())


## enforce <points> (0 is none): outside a fight or in the player's own. Returns the
## lines; outside a fight they also go to the log.
func enforce(points: int) -> Array[ColoredLine]:
	var fighting: bool = in_own_fight()
	if not fighting and not available():
		return []
	var lines: Array[ColoredLine] = EnforceService.enforce(_state(), points, force_level())
	if fighting:
		last_lines = lines
	else:
		_say(lines)
	return lines


## The functions exert.c reaches with the enabled force.
func exert_functions() -> Array[StringName]:
	return ExertService.offered(_state(), GameContent.catalog())


## exert <function>, outside a fight.
func exert(function_id: StringName) -> ExertResult:
	if not available():
		return null
	var result: ExertResult = ExertService.exert(
		_state(), function_id, GameContent.catalog(), force_level(), false,
		_session.player_runtime().busy, _session.world_interaction_random_source().legacy_random, _effects(),
		_session.player_runtime().character_id,
	)
	# A powerup can raise bellicosity over the line: the warning reads on the page too.
	if Berserk.take_warning(_state()):
		result.lines.append(ColoredLine.new(tr(Berserk.WARNING), ColoredLine.HIR))
	_say(result.lines)
	# powerfade's 100 sen can take sen below zero: std/char.c's next heart beat makes
	# the player fall (run at once, as after 於兰天武's blows).
	var map := _session.active_map() as WorldMapController
	if map != null and _state().life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		map.player_fall_below_zero()
	return result


## enable <use> <skill>.
func enable(use_id: StringName, skill_id: StringName) -> bool:
	if not available():
		return false
	var catalog: ContentCatalog = GameContent.catalog()
	var skill: SkillDefinition = catalog.skill(skill_id)
	if skill == null:
		return false
	var result: SkillMappingChangeResult = SkillEnableService.enable(_state(), skill, use_id)
	_say(TrainingLines.enable(result, catalog.skill(use_id), skill))
	return result.applied


## enable <use> none.
func disable(use_id: StringName) -> bool:
	if not available() or not SkillEnableService.disable(_state(), use_id):
		return false
	_say(TrainingLines.disable())
	return true


## practice <use>. necromancy.c's may conjure an NPC instead (PracticeConjuring): it comes
## beside the player and kill_ob()s them, who fight back (me->fight(bug)).
func practice(use_id: StringName) -> PracticeResult:
	if not available():
		return null
	var state: CharacterState = _state()
	var special: SkillDefinition = GameContent.catalog().skill(state.skills.mapped_skill(use_id))
	var standing: NpcRuntimeState = standing_conjured()
	var result: PracticeResult = PracticeService.practice(
		state, use_id,
		null if special == null else special.practice_policy(),
		null if special == null else _learn_policies.policy_for(special.skill_id),
		_fighting(), true, _effects(), _session.world_interaction_random_source().legacy_random,
		"" if standing == null else standing.definition().display_name,
	)
	if result.failure_reason == PracticeResult.FailureReason.PRACTICE_CONJURED:
		_conjure(result, special)
	else:
		_say(TrainingLines.practice(result, special))
	return result


## query_temp("mind_bug"): the NPC the player's practice conjured, while it is not dead
## (on any map), or null.
func standing_conjured() -> NpcRuntimeState:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	if player == null or player.conjured_npc_id.is_empty():
		return null
	for npc: NpcRuntimeState in _session.world_npcs():
		if npc.character_id == player.conjured_npc_id and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			return npc
	return null


## bug->move(environment(me)); bug->kill_ob(me); me->fight(bug); set_temp("mind_bug", bug):
## the practice's lines open the fight.
func _conjure(result: PracticeResult, special: SkillDefinition) -> void:
	var definition: NpcDefinition = GameContent.catalog().npc(result.conjured_npc_id)
	var lines: Array[ColoredLine] = TrainingLines.practice(result, special, definition.display_name)
	var map := _session.active_map() as WorldMapController
	var npc: NpcRuntimeState = null if map == null else map.conjure_beside_player(result.conjured_npc_id)
	if npc == null:
		push_error("practice could not conjure %s" % result.conjured_npc_id)
		_say(lines)
		return
	_session.player_runtime().conjured_npc_id = npc.character_id
	last_lines = lines
	if not map.npc_kills_player(npc, ColoredLine.texts(lines)):
		_say(lines)


## The 练习 button's hover for `use_id` when its skill's practice may conjure (owner,
## 茅山 A: practising 茅山道术 asks nothing, its hover tells of the 观想虫); "" otherwise.
func practice_hint(use_id: StringName) -> String:
	var catalog: ContentCatalog = GameContent.catalog()
	var special: SkillDefinition = catalog.skill(_state().skills.mapped_skill(use_id))
	var policy: PracticePolicy = null if special == null else special.practice_policy()
	if policy == null or policy.conjuring == null or not policy is VitalityInnerForcePracticePolicy:
		return ""
	var paid := policy as VitalityInnerForcePracticePolicy
	var names: Array[String] = []
	for npc_id: StringName in policy.conjuring.npc_ids:
		names.append(tr(catalog.npc(npc_id).display_name))
	var improved: SkillDefinition = catalog.skill(catalog.npc(policy.conjuring.npc_ids[0]).conjuring().skill_id)
	# TRANSLATORS: hover of 练习 for 茅山道术 (necromancy.c practice_skill()): {mana} mana and {sen} sen each time; {npcs} 观想虫或观想兽 may come and attack at once; while it lives no more practice; killed by the player's own hand {skill} (基本咒文) improves, killed by anyone else the player faints.
	return tr("每次练习耗 {mana} 点法力、{sen} 点神。心神一乱会变出{npcs}，它会立刻攻击你，活着时不能再练。亲手杀了它，{skill}会有长进；被别人杀了，你会昏倒。").format({
		"mana": paid.mana_cost, "sen": paid.spirit_cost, "npcs": tr("或").join(names), "skill": tr(improved.display_name),
	})


## exercise <kee>.
func exercise(kee: int) -> CultivationResult:
	if not available():
		return null
	var result: CultivationResult = CultivationService.exercise(_state(), kee, _fighting(), apply_modifier(&"force"))
	_refresh_maxima(result)
	_say(TrainingLines.exercise(result))
	return result


## meditate <sen>.
func meditate(sen: int) -> CultivationResult:
	if not available():
		return null
	var result: CultivationResult = CultivationService.meditate(_state(), sen, _fighting(), apply_modifier(&"spells"))
	_refresh_maxima(result)
	var lines: Array[ColoredLine] = TrainingLines.meditate(result)
	if result.success and _state().skills.raw_level(SkillIds.SPELLS) <= 0:
		lines.append(ColoredLine.new(tr(MEDITATE_NEEDS_SPELLS)))
	_say(lines)
	return result


## respirate <gin>.
func respirate(gin: int) -> CultivationResult:
	if not available():
		return null
	var result: CultivationResult = CultivationService.respirate(_state(), gin, _fighting(), apply_modifier(&"magic"))
	_refresh_maxima(result)
	var lines: Array[ColoredLine] = TrainingLines.respirate(result)
	if result.success and _state().skills.raw_level(SkillIds.MAGIC) <= 0:
		lines.append(ColoredLine.new(tr(RESPIRATE_NEEDS_MAGIC)))
	_say(lines)
	return result


## Native hints (owner, modern fixes II): with no 基本咒文 (基本法术) meditate.c
## (respirate.c) hits its bottleneck at once and says nothing of why.
## TRANSLATORS: after 冥思 (meditate) with no 基本咒文 (spells): mana cannot grow without it.
const MEDITATE_NEEDS_SPELLS: String = "需要先学会基本咒文，法力才能增长。"
## TRANSLATORS: after 修行 (respirate) with no 基本法术 (magic): atman cannot grow without it.
const RESPIRATE_NEEDS_MAGIC: String = "需要先学会基本法术，灵力才能增长。"


## Whether 冥思 / 修行 can grow anything: the hint the 武学 page shows on their buttons.
func cultivation_hint(skill_id: StringName) -> String:
	if _session == null or _session.player_runtime() == null or _state().skills.raw_level(skill_id) > 0:
		return ""
	return tr(MEDITATE_NEEDS_SPELLS if skill_id == SkillIds.SPELLS else RESPIRATE_NEEDS_MAGIC)


## selflearn <skill>.
func self_learn(skill_id: StringName) -> SelfLearningResult:
	if not available():
		return null
	var result: SelfLearningResult = SelfLearningService.self_learn(
		_state(), skill_id, _fighting(), 0, _effects(), _session.world_interaction_random_source(),
	)
	_say(TrainingLines.self_learn(result, GameContent.catalog().skill(skill_id)))
	return result


## study <item>: an item the player carries.
func study(item_instance_id: StringName) -> StudyResult:
	if not available():
		return null
	var material: StudyMaterial = null
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if row.item_instance_id == item_instance_id:
			var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
			material = null if content == null else content.study
	var policy: SkillLearnPolicy = null if material == null else _learn_policies.policy_for(material.skill_id)
	var result: StudyResult = StudyService.study(_state(), material, policy, _fighting(), _effects())
	_say(TrainingLines.study(result, null if material == null else GameContent.catalog().skill(material.skill_id)))
	return result


## The items the player carries that study.c can read.
func study_items() -> Array[PlayerInventoryRowProjection]:
	var rows: Array[PlayerInventoryRowProjection] = []
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		var content: ItemContentDefinition = GameContent.catalog().item(row.item_definition_id)
		if content != null and content.study != null:
			rows.append(row)
	return rows


func _state() -> CharacterState:
	return _session.player_runtime().state


## Deviation (owner, modern fixes II, A7): ES2 recomputes max gin, kee and sen
## (race/human.c, a quarter of max atman, force and mana) only at login; here they
## follow at once when exercise, meditate or respirate raised a maximum.
func _refresh_maxima(result: CultivationResult) -> void:
	if result != null and result.completion == CultivationResult.Completion.MAXIMUM_INCREASED:
		CharacterDerivedValues.refresh_human_player_maxima(_state(), _session.player_runtime().facts.age)


func _fighting() -> bool:
	return _session.player_runtime().relationship.is_fighting()


## The player is conscious in an active fight of their own (enforce.c still works).
func in_own_fight() -> bool:
	if _session == null or not _session.is_initialized() or not _session.application_gameplay_allows_encounter_advance():
		return false
	var encounter: CombatEncounter = _session.combat_encounter_coordinator().active_encounter()
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	return (
		encounter != null and encounter.phase == CombatEncounterLifecycle.Value.ACTIVE
		and encounter.participant_for(player.character_id) != null
		and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)


func _effects() -> SkillImprovementEffectRegistry:
	return _session.encounter_skill_effect_registry()


func _say(lines: Array[ColoredLine]) -> void:
	last_lines = lines
	var hud: SharedGameplayUI = _session.shared_ui()
	if hud != null and not lines.is_empty():
		hud.append_colored_lines(lines)
