class_name NpcDefinition
extends RefCounted

const AttributeOverridesType := preload(
	"res://core/npcs/npc_base_attribute_overrides.gd"
)
const ResourceOverridesType := preload("res://core/npcs/npc_resource_overrides.gd")
const SkillLevelType := preload("res://core/npcs/npc_skill_level_definition.gd")
const LoadoutEntryType := preload("res://core/npcs/npc_loadout_entry.gd")
const AuthoredCombatFactsType := preload("res://core/npcs/npc_authored_combat_facts.gd")

## The NPC starts a fight when the player comes into contact (LPC attitude
## "aggressive" acted on in init()).
const CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE: StringName = &"aggressive_on_player_presence"

## LPC set("attitude"). Friendly and heroism only change how an NPC answers
## fight (npc.c accept_fight, NpcSparConsent) and ask (ask.c, NpcInquiry).
enum Attitude {
	PEACEFUL,
	AGGRESSIVE,
	FRIENDLY,
	HEROISM,
}

var _definition_id: StringName
var _legacy_source_path: String
var _display_name: String
var _description: String
var _aliases: Array[StringName] = []
var _race_id: StringName
var _has_authored_gender: bool
var _gender: StringName
var _has_authored_age: bool
var _age: int
var _base_attribute_overrides: AttributeOverridesType
var _resource_overrides: ResourceOverridesType
var _combat_experience: int
var _score: int
var _attitude: int
var _skill_levels: Array[NpcSkillLevelDefinition] = []
var _loadout_entries: Array[NpcLoadoutEntry] = []
var _capability_ids: Array[StringName] = []
var _authored_combat_facts: AuthoredCombatFactsType
var _title: String
var _skill_map: Dictionary[StringName, StringName] = {}
var _gender_roll: NpcRandomText
var _age_roll: NpcRandomInteger
var _combat_experience_roll: NpcRandomInteger
var _score_roll: NpcRandomInteger
var _fight_rules: Array[NpcFightRule] = []
var _talk: NpcTalk
var _nickname: String = ""
var _rank_respect: String = ""
var _dealings: NpcDealings
var _teaching: NpcTeaching

var definition_id: StringName:
	get:
		return _definition_id
var legacy_source_path: String:
	get:
		return _legacy_source_path
var display_name: String:
	get:
		return _display_name
var description: String:
	get:
		return _description
var race_id: StringName:
	get:
		return _race_id
var has_authored_gender: bool:
	get:
		return _has_authored_gender
var gender: StringName:
	get:
		return _gender
var has_authored_age: bool:
	get:
		return _has_authored_age
var age: int:
	get:
		return _age
var combat_experience: int:
	get:
		return _combat_experience
var score: int:
	get:
		return _score
var attitude: int:
	get:
		return _attitude
## LPC set("title"), e.g. 门房.
var title: String:
	get:
		return _title
## LPC set("nickname"), e.g. 风雨双侠.
var nickname: String:
	get:
		return _nickname
## LPC set("rank_info/respect"): how others address it (rankd.c), e.g. 小二哥.
var rank_respect: String:
	get:
		return _rank_respect


func _init(
	p_definition_id: StringName = &"",
	p_legacy_source_path: String = "",
	p_display_name: String = "",
	p_aliases: Array[StringName] = [],
	p_race_id: StringName = &"",
	p_has_authored_gender: bool = false,
	p_gender: StringName = &"",
	p_has_authored_age: bool = false,
	p_age: int = 0,
	p_base_attribute_overrides: AttributeOverridesType = null,
	p_resource_overrides: ResourceOverridesType = null,
	p_combat_experience: int = 0,
	p_score: int = 0,
	p_attitude: int = Attitude.PEACEFUL,
	p_skill_levels: Array[NpcSkillLevelDefinition] = [],
	p_loadout_entries: Array[NpcLoadoutEntry] = [],
	p_capability_ids: Array[StringName] = [],
	p_description: String = "",
	p_authored_combat_facts: AuthoredCombatFactsType = null,
) -> void:
	_definition_id = p_definition_id
	_legacy_source_path = p_legacy_source_path
	_display_name = p_display_name
	_description = p_description
	_aliases = p_aliases.duplicate()
	_race_id = p_race_id
	_has_authored_gender = p_has_authored_gender
	_gender = p_gender
	_has_authored_age = p_has_authored_age
	_age = p_age
	_base_attribute_overrides = (
		AttributeOverridesType.new()
		if p_base_attribute_overrides == null
		else p_base_attribute_overrides.duplicate_snapshot()
	)
	_resource_overrides = (
		ResourceOverridesType.new()
		if p_resource_overrides == null
		else p_resource_overrides.duplicate_snapshot()
	)
	for skill: SkillLevelType in p_skill_levels:
		_skill_levels.append(null if skill == null else skill.duplicate_snapshot())
	for entry: LoadoutEntryType in p_loadout_entries:
		_loadout_entries.append(null if entry == null else entry.duplicate_snapshot())
	_combat_experience = p_combat_experience
	_score = p_score
	_attitude = p_attitude
	_capability_ids = p_capability_ids.duplicate()
	_authored_combat_facts = (
		null if p_authored_combat_facts == null
		else p_authored_combat_facts.duplicate_snapshot()
	)


## Facts create() authors on top of the constructor's: the title, map_skill()
## and the values it draws (`600+random(400)`). Called once by the loader.
func with_creation_facts(
	p_title: String,
	p_skill_map: Dictionary[StringName, StringName],
	p_gender_roll: NpcRandomText,
	p_age_roll: NpcRandomInteger,
	p_combat_experience_roll: NpcRandomInteger,
	p_score_roll: NpcRandomInteger,
) -> NpcDefinition:
	_title = p_title
	_skill_map = p_skill_map.duplicate()
	_gender_roll = p_gender_roll
	_age_roll = p_age_roll
	_combat_experience_roll = p_combat_experience_roll
	_score_roll = p_score_roll
	return self


## The NPC's own accept_fight(), when it has one (see NpcFightRule).
func with_fight_rules(rules: Array[NpcFightRule]) -> NpcDefinition:
	_fight_rules = rules.duplicate()
	return self


func fight_rules() -> Array[NpcFightRule]:
	return _fight_rules.duplicate()


## inquiry, chat and greeting (NpcTalk). Called once by the loader.
func with_talk(value: NpcTalk) -> NpcDefinition:
	_talk = value
	return self


func talk() -> NpcTalk:
	if _talk == null:
		_talk = NpcTalk.new()
	return _talk


## nickname and rank_info/respect. Called once by the loader.
func with_naming(p_nickname: String, p_rank_respect: String) -> NpcDefinition:
	_nickname = p_nickname
	_rank_respect = p_rank_respect
	return self


## Vendor goods, accept_object(), object flags, fights deferred (NpcDealings).
func with_dealings(value: NpcDealings) -> NpcDefinition:
	_dealings = value
	return self


func dealings() -> NpcDealings:
	if _dealings == null:
		_dealings = NpcDealings.new()
	return _dealings


## Family, teaching and apprentices (NpcTeaching); null for an NPC that teaches no one.
func with_teaching(value: NpcTeaching) -> NpcDefinition:
	_teaching = value
	return self


func teaching() -> NpcTeaching:
	return _teaching


## race/human.c sets can_speak; beast.c does not. fight.c only asks a
## speaking character to spar.
func can_speak() -> bool:
	return _race_id == NpcCharacterStateFactory.HUMAN_RACE_ID


## feature/name.c short() without the "(Id)": title, a space, then the name.
func short_name() -> String:
	return _display_name if _title.is_empty() else "%s %s" % [_title, _display_name]


## map_skill(use, skill) in authored order.
func skill_map() -> Dictionary[StringName, StringName]:
	return _skill_map.duplicate()


func gender_roll() -> NpcRandomText:
	return _gender_roll


func age_roll() -> NpcRandomInteger:
	return _age_roll


func combat_experience_roll() -> NpcRandomInteger:
	return _combat_experience_roll


## Kept for the score rules; nothing reads an NPC's score yet.
func score_roll() -> NpcRandomInteger:
	return _score_roll


func authored_combat_facts() -> AuthoredCombatFactsType:
	return (
		null if _authored_combat_facts == null
		else _authored_combat_facts.duplicate_snapshot()
	)


func aliases() -> Array[StringName]:
	return _aliases.duplicate()


func base_attribute_overrides() -> AttributeOverridesType:
	return _base_attribute_overrides.duplicate_snapshot()


func resource_overrides() -> ResourceOverridesType:
	return _resource_overrides.duplicate_snapshot()


func skill_levels() -> Array[NpcSkillLevelDefinition]:
	var result: Array[NpcSkillLevelDefinition] = []
	for skill: SkillLevelType in _skill_levels:
		result.append(skill.duplicate_snapshot())
	return result


func loadout_entries() -> Array[NpcLoadoutEntry]:
	var result: Array[NpcLoadoutEntry] = []
	for entry: LoadoutEntryType in _loadout_entries:
		result.append(entry.duplicate_snapshot())
	return result


func capability_ids() -> Array[StringName]:
	return _capability_ids.duplicate()


func has_capability(capability_id: StringName) -> bool:
	return _capability_ids.has(capability_id)


func is_valid() -> bool:
	if (
		_definition_id.is_empty()
		or _legacy_source_path.is_empty()
		or _display_name.is_empty()
		or _aliases.is_empty()
		or _race_id.is_empty()
		or (_has_authored_gender and _gender.is_empty())
		or _attitude < Attitude.PEACEFUL
		or _attitude > Attitude.HEROISM
	):
		return false
	for roll: Variant in [_gender_roll, _age_roll, _combat_experience_roll, _score_roll]:
		if roll != null and not roll.is_valid():
			return false
	if not _unique_non_empty_ids(_aliases) or not _unique_non_empty_ids(_capability_ids):
		return false
	var skill_ids: Dictionary[StringName, bool] = {}
	for skill: SkillLevelType in _skill_levels:
		if skill == null or not skill.is_valid() or skill_ids.has(skill.skill_id):
			return false
		skill_ids[skill.skill_id] = true
	for use_id: StringName in _skill_map:
		if use_id.is_empty() or not skill_ids.has(_skill_map[use_id]):
			return false
	for entry: LoadoutEntryType in _loadout_entries:
		if entry == null or not entry.is_valid():
			return false
	return _talk == null or _talk.is_valid()


static func _unique_non_empty_ids(ids: Array[StringName]) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
