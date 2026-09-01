class_name GameSaveValueTypes
extends RefCounted

## Cohesive value records used by the game-save schema. These are persistence
## DTOs only: they do not capture or restore live gameplay authorities.

class OptionalText extends RefCounted:
	var has_value: bool
	var value: String

	func _init(p_has_value: bool = false, p_value: String = "") -> void:
		has_value = p_has_value
		value = p_value

	static func none() -> OptionalText:
		return OptionalText.new()

	static func some(p_value: String) -> OptionalText:
		return OptionalText.new(true, p_value)

	func duplicate_snapshot() -> OptionalText:
		return OptionalText.new(has_value, value)


class GameSaveMetadata extends RefCounted:
	var format_id: String
	var schema_version: int
	var saved_at_utc: String
	var build_commit: OptionalText
	var storage_profile: StringName
	var slot_id: StringName

	func _init(
		p_format_id: String = "",
		p_schema_version: int = 0,
		p_saved_at_utc: String = "",
		p_build_commit: OptionalText = null,
		p_storage_profile: StringName = &"",
		p_slot_id: StringName = &"",
	) -> void:
		format_id = p_format_id
		schema_version = p_schema_version
		saved_at_utc = p_saved_at_utc
		build_commit = OptionalText.none() if p_build_commit == null else p_build_commit.duplicate_snapshot()
		storage_profile = p_storage_profile
		slot_id = p_slot_id

	func duplicate_snapshot() -> GameSaveMetadata:
		return GameSaveMetadata.new(format_id, schema_version, saved_at_utc, build_commit, storage_profile, slot_id)


class ItemIdAllocatorSnapshot extends RefCounted:
	var scope: StringName
	var next_dynamic_sequence: int

	func _init(p_scope: StringName = &"", p_next_dynamic_sequence: int = 0) -> void:
		scope = p_scope
		next_dynamic_sequence = p_next_dynamic_sequence

	func duplicate_snapshot() -> ItemIdAllocatorSnapshot:
		return ItemIdAllocatorSnapshot.new(scope, next_dynamic_sequence)


class BaseAttributesSnapshot extends RefCounted:
	var strength: int
	var courage: int
	var intelligence: int
	var spirituality: int
	var composure: int
	var personality: int
	var constitution: int
	var karma: int
	var force_factor: int
	var bellicosity: int

	func _init(
		p_strength: int = 0, p_courage: int = 0, p_intelligence: int = 0,
		p_spirituality: int = 0, p_composure: int = 0, p_personality: int = 0,
		p_constitution: int = 0, p_karma: int = 0, p_force_factor: int = 0,
		p_bellicosity: int = 0,
	) -> void:
		strength = p_strength
		courage = p_courage
		intelligence = p_intelligence
		spirituality = p_spirituality
		composure = p_composure
		personality = p_personality
		constitution = p_constitution
		karma = p_karma
		force_factor = p_force_factor
		bellicosity = p_bellicosity

	func duplicate_snapshot() -> BaseAttributesSnapshot:
		return BaseAttributesSnapshot.new(strength, courage, intelligence, spirituality, composure, personality, constitution, karma, force_factor, bellicosity)


class ResourceTrackSnapshot extends RefCounted:
	var current: int
	var effective: int
	var maximum: int

	func _init(p_current: int = 0, p_effective: int = 0, p_maximum: int = 0) -> void:
		current = p_current
		effective = p_effective
		maximum = p_maximum

	func duplicate_snapshot() -> ResourceTrackSnapshot:
		return ResourceTrackSnapshot.new(current, effective, maximum)


class InternalResourcesSnapshot extends RefCounted:
	var force: int
	var max_force: int
	var mana: int
	var max_mana: int
	var atman: int
	var max_atman: int
	var food: int
	var water: int

	func _init(
		p_force: int = 0, p_max_force: int = 0, p_mana: int = 0,
		p_max_mana: int = 0, p_atman: int = 0, p_max_atman: int = 0,
		p_food: int = 0, p_water: int = 0,
	) -> void:
		force = p_force
		max_force = p_max_force
		mana = p_mana
		max_mana = p_max_mana
		atman = p_atman
		max_atman = p_max_atman
		food = p_food
		water = p_water

	func duplicate_snapshot() -> InternalResourcesSnapshot:
		return InternalResourcesSnapshot.new(force, max_force, mana, max_mana, atman, max_atman, food, water)


class ProgressionSnapshot extends RefCounted:
	var combat_experience: int
	var potential: int
	var potential_spent: int

	func _init(p_combat_experience: int = 0, p_potential: int = 0, p_potential_spent: int = 0) -> void:
		combat_experience = p_combat_experience
		potential = p_potential
		potential_spent = p_potential_spent

	func duplicate_snapshot() -> ProgressionSnapshot:
		return ProgressionSnapshot.new(combat_experience, potential, potential_spent)


class SkillValueSnapshot extends RefCounted:
	var skill_id: StringName
	var value: int

	func _init(p_skill_id: StringName = &"", p_value: int = 0) -> void:
		skill_id = p_skill_id
		value = p_value

	func duplicate_snapshot() -> SkillValueSnapshot:
		return SkillValueSnapshot.new(skill_id, value)


class SkillMappingSnapshot extends RefCounted:
	var use_id: StringName
	var skill_id: StringName

	func _init(p_use_id: StringName = &"", p_skill_id: StringName = &"") -> void:
		use_id = p_use_id
		skill_id = p_skill_id

	func duplicate_snapshot() -> SkillMappingSnapshot:
		return SkillMappingSnapshot.new(use_id, skill_id)


class SkillStateSnapshot extends RefCounted:
	var has_skills_mapping: bool
	var has_learned_mapping: bool
	var _raw_levels: Array[SkillValueSnapshot] = []
	var _learned_progress: Array[SkillValueSnapshot] = []
	var _mappings: Array[SkillMappingSnapshot] = []
	var raw_levels: Array[SkillValueSnapshot]:
		get: return _copy_skill_values(_raw_levels)
	var learned_progress: Array[SkillValueSnapshot]:
		get: return _copy_skill_values(_learned_progress)
	var mappings: Array[SkillMappingSnapshot]:
		get:
			var result: Array[SkillMappingSnapshot] = []
			for record: SkillMappingSnapshot in _mappings:
				result.append(null if record == null else record.duplicate_snapshot())
			return result

	func _init(
		p_has_skills_mapping: bool = false, p_has_learned_mapping: bool = false,
		p_raw_levels: Array[SkillValueSnapshot] = [], p_learned_progress: Array[SkillValueSnapshot] = [],
		p_mappings: Array[SkillMappingSnapshot] = [],
	) -> void:
		has_skills_mapping = p_has_skills_mapping
		has_learned_mapping = p_has_learned_mapping
		_raw_levels = _copy_skill_values(p_raw_levels)
		_learned_progress = _copy_skill_values(p_learned_progress)
		for record: SkillMappingSnapshot in p_mappings:
			_mappings.append(null if record == null else record.duplicate_snapshot())
		_raw_levels.sort_custom(_skill_value_before)
		_learned_progress.sort_custom(_skill_value_before)
		_mappings.sort_custom(_skill_mapping_before)

	func duplicate_snapshot() -> SkillStateSnapshot:
		return SkillStateSnapshot.new(has_skills_mapping, has_learned_mapping, _raw_levels, _learned_progress, _mappings)

	static func _copy_skill_values(source: Array[SkillValueSnapshot]) -> Array[SkillValueSnapshot]:
		var result: Array[SkillValueSnapshot] = []
		for record: SkillValueSnapshot in source:
			result.append(null if record == null else record.duplicate_snapshot())
		return result

	static func _skill_value_before(left: SkillValueSnapshot, right: SkillValueSnapshot) -> bool:
		if left == null: return right != null
		if right == null: return false
		return String(left.skill_id) < String(right.skill_id)

	static func _skill_mapping_before(left: SkillMappingSnapshot, right: SkillMappingSnapshot) -> bool:
		if left == null: return right != null
		if right == null: return false
		return String(left.use_id) < String(right.use_id)


class ConditionSnapshot extends RefCounted:
	const KIND_DURATION: StringName = &"duration"
	const KIND_POISON: StringName = &"poison"
	var condition_id: StringName
	var payload_kind: StringName
	var remaining: int
	var damage: int
	var legacy_message: String

	func _init(
		p_condition_id: StringName = &"", p_payload_kind: StringName = &"",
		p_remaining: int = 0, p_damage: int = 0, p_legacy_message: String = "",
	) -> void:
		condition_id = p_condition_id
		payload_kind = p_payload_kind
		remaining = p_remaining
		damage = p_damage
		legacy_message = p_legacy_message

	static func duration(p_condition_id: StringName, p_remaining: int) -> ConditionSnapshot:
		return ConditionSnapshot.new(p_condition_id, KIND_DURATION, p_remaining)

	static func poison(p_condition_id: StringName, p_damage: int, p_remaining: int, p_message: String) -> ConditionSnapshot:
		return ConditionSnapshot.new(p_condition_id, KIND_POISON, p_remaining, p_damage, p_message)

	func duplicate_snapshot() -> ConditionSnapshot:
		return ConditionSnapshot.new(condition_id, payload_kind, remaining, damage, legacy_message)


class FamilySnapshot extends RefCounted:
	var family_id: StringName
	var generation: int

	func _init(p_family_id: StringName = &"", p_generation: int = 0) -> void:
		family_id = p_family_id
		generation = p_generation

	func duplicate_snapshot() -> FamilySnapshot:
		return FamilySnapshot.new(family_id, generation)


class ApprenticeshipSnapshot extends RefCounted:
	var master_teacher_id: StringName
	var legacy_master_name: String
	var betrayer_count: int

	func _init(p_master_teacher_id: StringName = &"", p_legacy_master_name: String = "", p_betrayer_count: int = 0) -> void:
		master_teacher_id = p_master_teacher_id
		legacy_master_name = p_legacy_master_name
		betrayer_count = p_betrayer_count

	func duplicate_snapshot() -> ApprenticeshipSnapshot:
		return ApprenticeshipSnapshot.new(master_teacher_id, legacy_master_name, betrayer_count)


class CharacterStateSnapshot extends RefCounted:
	var gender: StringName
	var attributes: BaseAttributesSnapshot
	var gin: ResourceTrackSnapshot
	var kee: ResourceTrackSnapshot
	var sen: ResourceTrackSnapshot
	var internal_resources: InternalResourcesSnapshot
	var progression: ProgressionSnapshot
	var skills: SkillStateSnapshot
	var _conditions: Array[ConditionSnapshot] = []
	var conditions: Array[ConditionSnapshot]:
		get:
			var result: Array[ConditionSnapshot] = []
			for record: ConditionSnapshot in _conditions:
				result.append(null if record == null else record.duplicate_snapshot())
			return result
	var family: FamilySnapshot
	var apprenticeship: ApprenticeshipSnapshot

	func _init(
		p_gender: StringName = &"", p_attributes: BaseAttributesSnapshot = null,
		p_gin: ResourceTrackSnapshot = null, p_kee: ResourceTrackSnapshot = null, p_sen: ResourceTrackSnapshot = null,
		p_internal_resources: InternalResourcesSnapshot = null, p_progression: ProgressionSnapshot = null,
		p_skills: SkillStateSnapshot = null, p_conditions: Array[ConditionSnapshot] = [],
		p_family: FamilySnapshot = null, p_apprenticeship: ApprenticeshipSnapshot = null,
	) -> void:
		gender = p_gender
		attributes = BaseAttributesSnapshot.new() if p_attributes == null else p_attributes.duplicate_snapshot()
		gin = ResourceTrackSnapshot.new() if p_gin == null else p_gin.duplicate_snapshot()
		kee = ResourceTrackSnapshot.new() if p_kee == null else p_kee.duplicate_snapshot()
		sen = ResourceTrackSnapshot.new() if p_sen == null else p_sen.duplicate_snapshot()
		internal_resources = InternalResourcesSnapshot.new() if p_internal_resources == null else p_internal_resources.duplicate_snapshot()
		progression = ProgressionSnapshot.new() if p_progression == null else p_progression.duplicate_snapshot()
		skills = SkillStateSnapshot.new() if p_skills == null else p_skills.duplicate_snapshot()
		for record: ConditionSnapshot in p_conditions:
			_conditions.append(null if record == null else record.duplicate_snapshot())
		_conditions.sort_custom(_condition_before)
		family = FamilySnapshot.new() if p_family == null else p_family.duplicate_snapshot()
		apprenticeship = ApprenticeshipSnapshot.new() if p_apprenticeship == null else p_apprenticeship.duplicate_snapshot()

	func duplicate_snapshot() -> CharacterStateSnapshot:
		return CharacterStateSnapshot.new(gender, attributes, gin, kee, sen, internal_resources, progression, skills, _conditions, family, apprenticeship)

	static func _condition_before(left: ConditionSnapshot, right: ConditionSnapshot) -> bool:
		if left == null: return right != null
		if right == null: return false
		return String(left.condition_id) < String(right.condition_id)


class WorldLocationSnapshot extends RefCounted:
	var region_id: StringName
	var map_id: StringName
	var zone_id: StringName
	var combat_location_id: StringName

	func _init(p_region_id: StringName = &"", p_map_id: StringName = &"", p_zone_id: StringName = &"", p_combat_location_id: StringName = &"") -> void:
		region_id = p_region_id
		map_id = p_map_id
		zone_id = p_zone_id
		combat_location_id = p_combat_location_id

	func duplicate_snapshot() -> WorldLocationSnapshot:
		return WorldLocationSnapshot.new(region_id, map_id, zone_id, combat_location_id)


class MapPositionSnapshot extends RefCounted:
	var x: float
	var y: float

	func _init(p_x: float = 0.0, p_y: float = 0.0) -> void:
		x = p_x
		y = p_y

	func has_finite_coordinates() -> bool:
		return is_finite(x) and is_finite(y)

	func duplicate_snapshot() -> MapPositionSnapshot:
		return MapPositionSnapshot.new(x, y)


class PlayerRuntimeSnapshot extends RefCounted:
	var character_id: StringName
	var character: CharacterStateSnapshot
	var life_status: StringName
	var exists_in_world: bool
	var combat_available: bool
	var maximum_encumbrance: int
	var world_location: WorldLocationSnapshot
	var map_position: MapPositionSnapshot

	func _init(
		p_character_id: StringName = &"", p_character: CharacterStateSnapshot = null,
		p_life_status: StringName = &"active", p_exists_in_world: bool = true,
		p_combat_available: bool = true, p_maximum_encumbrance: int = 0,
		p_world_location: WorldLocationSnapshot = null, p_map_position: MapPositionSnapshot = null,
	) -> void:
		character_id = p_character_id
		character = CharacterStateSnapshot.new() if p_character == null else p_character.duplicate_snapshot()
		life_status = p_life_status
		exists_in_world = p_exists_in_world
		combat_available = p_combat_available
		maximum_encumbrance = p_maximum_encumbrance
		world_location = WorldLocationSnapshot.new() if p_world_location == null else p_world_location.duplicate_snapshot()
		map_position = MapPositionSnapshot.new() if p_map_position == null else p_map_position.duplicate_snapshot()

	func duplicate_snapshot() -> PlayerRuntimeSnapshot:
		return PlayerRuntimeSnapshot.new(character_id, character, life_status, exists_in_world, combat_available, maximum_encumbrance, world_location, map_position)


class NpcSpawnStateSnapshot extends RefCounted:
	var spawn_id: StringName
	var spawn_point_id: StringName
	var npc_definition_id: StringName
	var character_id: StringName
	var exists_in_world: bool
	var life_status: StringName
	var combat_available: bool
	var character: CharacterStateSnapshot
	var age: int
	var body_weight: int
	var maximum_encumbrance: int
	var world_location: WorldLocationSnapshot
	var map_position: MapPositionSnapshot
	var _live_loadout_item_ids: Array[StringName] = []
	var live_loadout_item_ids: Array[StringName]:
		get: return _live_loadout_item_ids.duplicate()

	func _init(
		p_spawn_id: StringName = &"", p_spawn_point_id: StringName = &"",
		p_npc_definition_id: StringName = &"", p_character_id: StringName = &"",
		p_exists_in_world: bool = true, p_life_status: StringName = &"active",
		p_combat_available: bool = true, p_character: CharacterStateSnapshot = null,
		p_age: int = 0, p_body_weight: int = 0, p_maximum_encumbrance: int = 0,
		p_world_location: WorldLocationSnapshot = null, p_map_position: MapPositionSnapshot = null,
		p_live_loadout_item_ids: Array[StringName] = [],
	) -> void:
		spawn_id = p_spawn_id
		spawn_point_id = p_spawn_point_id
		npc_definition_id = p_npc_definition_id
		character_id = p_character_id
		exists_in_world = p_exists_in_world
		life_status = p_life_status
		combat_available = p_combat_available
		character = CharacterStateSnapshot.new() if p_character == null else p_character.duplicate_snapshot()
		age = p_age
		body_weight = p_body_weight
		maximum_encumbrance = p_maximum_encumbrance
		world_location = WorldLocationSnapshot.new() if p_world_location == null else p_world_location.duplicate_snapshot()
		map_position = MapPositionSnapshot.new() if p_map_position == null else p_map_position.duplicate_snapshot()
		_live_loadout_item_ids = p_live_loadout_item_ids.duplicate()
		_live_loadout_item_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))

	func duplicate_snapshot() -> NpcSpawnStateSnapshot:
		return NpcSpawnStateSnapshot.new(spawn_id, spawn_point_id, npc_definition_id, character_id, exists_in_world, life_status, combat_available, character, age, body_weight, maximum_encumbrance, world_location, map_position, _live_loadout_item_ids)


class CorpseWornItemSnapshot extends RefCounted:
	var armor_type: StringName
	var item_instance_id: StringName

	func _init(p_armor_type: StringName = &"", p_item_instance_id: StringName = &"") -> void:
		armor_type = p_armor_type
		item_instance_id = p_item_instance_id

	func duplicate_snapshot() -> CorpseWornItemSnapshot:
		return CorpseWornItemSnapshot.new(armor_type, item_instance_id)


class CorpseSnapshot extends RefCounted:
	var corpse_item_instance_id: StringName
	var victim_character_id: StringName
	var victim_display_name: String
	var victim_gender: StringName
	var victim_age: int
	var decay_stage: int
	var maximum_contents_encumbrance: int
	var _worn_items: Array[CorpseWornItemSnapshot] = []
	var worn_items: Array[CorpseWornItemSnapshot]:
		get:
			var result: Array[CorpseWornItemSnapshot] = []
			for record: CorpseWornItemSnapshot in _worn_items:
				result.append(null if record == null else record.duplicate_snapshot())
			return result
	var world_location: WorldLocationSnapshot
	var map_position: MapPositionSnapshot

	func _init(
		p_corpse_item_instance_id: StringName = &"", p_victim_character_id: StringName = &"",
		p_victim_display_name: String = "", p_victim_gender: StringName = &"",
		p_victim_age: int = 0, p_decay_stage: int = 0,
		p_maximum_contents_encumbrance: int = 0,
		p_worn_items: Array[CorpseWornItemSnapshot] = [], p_world_location: WorldLocationSnapshot = null,
		p_map_position: MapPositionSnapshot = null,
	) -> void:
		corpse_item_instance_id = p_corpse_item_instance_id
		victim_character_id = p_victim_character_id
		victim_display_name = p_victim_display_name
		victim_gender = p_victim_gender
		victim_age = p_victim_age
		decay_stage = p_decay_stage
		maximum_contents_encumbrance = p_maximum_contents_encumbrance
		for record: CorpseWornItemSnapshot in p_worn_items:
			_worn_items.append(null if record == null else record.duplicate_snapshot())
		_worn_items.sort_custom(func(left: CorpseWornItemSnapshot, right: CorpseWornItemSnapshot) -> bool: return String(left.armor_type) < String(right.armor_type))
		world_location = WorldLocationSnapshot.new() if p_world_location == null else p_world_location.duplicate_snapshot()
		map_position = MapPositionSnapshot.new() if p_map_position == null else p_map_position.duplicate_snapshot()

	func duplicate_snapshot() -> CorpseSnapshot:
		return CorpseSnapshot.new(corpse_item_instance_id, victim_character_id, victim_display_name, victim_gender, victim_age, decay_stage, maximum_contents_encumbrance, _worn_items, world_location, map_position)
