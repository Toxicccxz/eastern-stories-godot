class_name CharacterStateSnapshotRestorer
extends RefCounted

const Values := preload("res://core/persistence/game_save_value_types.gd")
const AttributesType := preload(
	"res://core/characters/character_base_attributes.gd"
)
const ResourceType := preload(
	"res://core/characters/character_resource_state.gd"
)
const InternalResourceType := preload(
	"res://core/characters/character_internal_resource_state.gd"
)
const RecoveryType := preload(
	"res://core/characters/character_recovery_state.gd"
)
const ProgressionType := preload(
	"res://core/characters/character_progression_state.gd"
)
const SkillStateType := preload("res://core/skills/character_skill_state.gd")
const ConditionStateType := preload(
	"res://core/conditions/character_condition_state.gd"
)
const DurationPayloadType := preload(
	"res://core/conditions/duration_condition_payload.gd"
)
const PoisonPayloadType := preload(
	"res://core/conditions/poison_condition_payload.gd"
)
const FamilyType := preload("res://core/relationships/family_state.gd")
const ApprenticeshipType := preload(
	"res://core/relationships/apprenticeship_state.gd"
)


static func restore(
	snapshot: Values.CharacterStateSnapshot,
	equipment: EquipmentState,
) -> CharacterState:
	if snapshot == null or equipment == null:
		return null
	var attributes: AttributesType = AttributesType.new(
		snapshot.attributes.strength,
		snapshot.attributes.courage,
		snapshot.attributes.intelligence,
		snapshot.attributes.spirituality,
		snapshot.attributes.composure,
		snapshot.attributes.personality,
		snapshot.attributes.constitution,
		snapshot.attributes.karma,
	)
	attributes.force_factor = snapshot.attributes.force_factor
	attributes.bellicosity = snapshot.attributes.bellicosity

	var recovery: RecoveryType = RecoveryType.new(
		InternalResourceType.new(
			snapshot.internal_resources.force,
			snapshot.internal_resources.max_force,
		),
		InternalResourceType.new(
			snapshot.internal_resources.mana,
			snapshot.internal_resources.max_mana,
		),
		InternalResourceType.new(
			snapshot.internal_resources.atman,
			snapshot.internal_resources.max_atman,
		),
		snapshot.internal_resources.food,
		snapshot.internal_resources.water,
	)
	var skills: SkillStateType = SkillStateType.new()
	# Raw records must exist before mappings are restored because map_skill()
	# validates the mapped target against the raw authority.
	for raw: Values.SkillValueSnapshot in snapshot.skills.raw_levels:
		skills.set_raw_level(raw.skill_id, raw.value)
	for learned: Values.SkillValueSnapshot in snapshot.skills.learned_progress:
		skills.set_learned_progress(learned.skill_id, learned.value)
	for mapping: Values.SkillMappingSnapshot in snapshot.skills.mappings:
		if not skills.map_skill(mapping.use_id, mapping.skill_id):
			return null
	if not skills._restore_mapping_presence(
		snapshot.skills.has_skills_mapping,
		snapshot.skills.has_learned_mapping,
	):
		return null

	var conditions: ConditionStateType = ConditionStateType.new()
	for condition: Values.ConditionSnapshot in snapshot.conditions:
		if condition.payload_kind == Values.ConditionSnapshot.KIND_DURATION:
			conditions.add_or_replace(
				condition.condition_id,
				DurationPayloadType.new(condition.remaining),
			)
		elif condition.payload_kind == Values.ConditionSnapshot.KIND_POISON:
			conditions.add_or_replace(
				condition.condition_id,
				PoisonPayloadType.new(
					condition.damage,
					condition.remaining,
					condition.legacy_message,
				),
			)
		else:
			return null

	var state: CharacterState = CharacterState.new(
		attributes,
		_resource(snapshot.gin),
		_resource(snapshot.kee),
		_resource(snapshot.sen),
		recovery,
		conditions,
		skills,
		ProgressionType.new(
			snapshot.progression.combat_experience,
			snapshot.progression.potential,
			snapshot.progression.potential_spent,
		),
		FamilyType.new(snapshot.family.family_id, snapshot.family.generation),
		ApprenticeshipType.new(
			snapshot.apprenticeship.master_teacher_id,
			snapshot.apprenticeship.legacy_master_name,
			snapshot.apprenticeship.betrayer_count,
		),
		equipment,
	)
	state.gender = snapshot.gender
	return state if state.resources_have_valid_invariants() else null


static func _resource(snapshot: Values.ResourceTrackSnapshot) -> ResourceType:
	return ResourceType.new(snapshot.current, snapshot.effective, snapshot.maximum)
