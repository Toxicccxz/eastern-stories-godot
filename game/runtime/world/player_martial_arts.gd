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
var _session: OldPineWorldSessionController
var _learn_policies: SkillLearnPolicyRegistry


func _init(session: OldPineWorldSessionController) -> void:
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


## practice <use>.
func practice(use_id: StringName) -> PracticeResult:
	if not available():
		return null
	var state: CharacterState = _state()
	var special: SkillDefinition = GameContent.catalog().skill(state.skills.mapped_skill(use_id))
	var result: PracticeResult = PracticeService.practice(
		state, use_id,
		null if special == null else special.practice_policy(),
		null if special == null else _learn_policies.policy_for(special.skill_id),
		_fighting(), true, _effects(),
	)
	_say(TrainingLines.practice(result, special))
	return result


## exercise <kee>.
func exercise(kee: int) -> CultivationResult:
	if not available():
		return null
	var result: CultivationResult = CultivationService.exercise(_state(), kee, _fighting(), apply_modifier(&"force"))
	_say(TrainingLines.exercise(result))
	return result


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
