class_name BattleLabRoster
extends RefCounted

## Dev only (tests/dev/battle_lab.tscn, tests/dev/battle_lab/run_battle_lab.gd): who can stand in a
## battle-lab fight, and how a fighter is brought to a level. Nothing here is read by the game;
## tests/ never reaches a release.
##
## A family's way of fighting is read off its own NPCs: of the family's human NPCs with a skill map,
## the one with the most combat_exp is its template — its skill map, its martial skills and what it
## wields (the master, mostly). A fighter "of a family at level L" is that template with every martial
## skill it has at L, the combat_exp a story-grown player has at L (tests/support/grown_character.gd's
## curve) and half exercise.c's force cap, its gin / kee / sen from race/human.c at its age. Level 0
## keeps an NPC as authored. The player at a family and level gets the same skills and wields the
## template's weapon.

const Grown := preload("res://tests/support/grown_character.gd")

## Half exercise.c's cap, as grown_character.gd grows the player (about an hour of 打坐 at 10000 exp).
const FORCE_PERCENT: int = 50
const MAX_LEVEL: int = 300
## The families' order (and ids) as the game lists them.
const FAMILIES_PATH: String = "res://data/common/families.json"


## One family the lab can field: its id and name, and its template NPC.
class Family:
	extends RefCounted
	var family_id: StringName
	var display_name: String
	var template_id: StringName
	var template_exp: int


static var _families: Array[Family] = []


## Every family with a template, in the order families.json lists them, then the families only NPCs
## name.
static func families() -> Array[Family]:
	if not _families.is_empty():
		return _families
	var catalog: ContentCatalog = GameContent.catalog()
	var by_name: Dictionary[String, Family] = {}
	var order: Array[String] = []
	for npc: NpcDefinition in catalog.npcs():
		var teaching: NpcTeaching = npc.teaching()
		if teaching == null or teaching.family_name.is_empty() or npc.race_id != &"human" or npc.skill_map().is_empty():
			continue
		var known: Family = by_name.get(teaching.family_name)
		if known == null:
			known = Family.new()
			known.display_name = teaching.family_name
			var family: FamilyDefinition = catalog.family_named(teaching.family_name)
			known.family_id = family.family_id if family != null else StringName("family:" + teaching.family_name)
			known.template_exp = -1
			by_name[teaching.family_name] = known
			order.append(teaching.family_name)
		if npc.combat_experience > known.template_exp:
			known.template_exp = npc.combat_experience
			known.template_id = npc.definition_id
	var listed: Array[StringName] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FAMILIES_PATH))
	if data is Dictionary:
		for record: Variant in (data as Dictionary).get("families", []):
			listed.append(StringName(str((record as Dictionary).get("id", ""))))
	order.sort_custom(func(a: String, b: String) -> bool:
		var ia: int = listed.find(by_name[a].family_id)
		var ib: int = listed.find(by_name[b].family_id)
		ia = listed.size() if ia < 0 else ia
		ib = listed.size() if ib < 0 else ib
		return ia < ib if ia != ib else a < b)
	for name: String in order:
		_families.append(by_name[name])
	return _families


static func family(family_id: StringName) -> Family:
	for known: Family in families():
		if known.family_id == family_id:
			return known
	return null


## Every NPC a lab fighter can be made of (human or beast with a valid definition), by display name.
static func npcs() -> Array[NpcDefinition]:
	var out: Array[NpcDefinition] = []
	for npc: NpcDefinition in GameContent.catalog().npcs():
		if npc.is_valid() and npc.race_id in [&"human", &"beast"]:
			out.append(npc)
	out.sort_custom(func(a: NpcDefinition, b: NpcDefinition) -> bool: return String(a.definition_id) < String(b.definition_id))
	return out


## The least combat_exp at which a story-grown player has `level` in each skill.
static func experience_for(level: int) -> int:
	if level <= 0:
		return 0
	var low: int = 0
	var high: int = 1
	while Grown.level_for(high) < level and high < 2000000000:
		high *= 2
	while low < high:
		@warning_ignore("integer_division")
		var middle: int = (low + high) / 2
		if Grown.level_for(middle) >= level:
			high = middle
		else:
			low = middle + 1
	return low


## The template's martial skills (basic and special), the ones a level sets.
static func martial_skills(template: NpcDefinition) -> Array[StringName]:
	var catalog: ContentCatalog = GameContent.catalog()
	var out: Array[StringName] = []
	for entry: NpcSkillLevelDefinition in template.skill_levels():
		var skill: SkillDefinition = catalog.skill(entry.skill_id)
		if skill != null and skill.skill_type == SkillDefinition.Type.MARTIAL and not out.has(entry.skill_id):
			out.append(entry.skill_id)
	for use_id: StringName in template.skill_map():
		for id: StringName in [use_id, template.skill_map()[use_id]]:
			if not out.has(id):
				out.append(id)
	return out


## What the template wields first (its loadout's primary weapon), or &"".
static func weapon_of(template: NpcDefinition) -> StringName:
	for entry: NpcLoadoutEntry in template.loadout_entries():
		if entry.equipment_intent == NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY:
			return entry.item_definition_id
	return &""


## An NPC's state brought to `level` (nothing done at 0): its martial skills at the level, the
## grown player's combat_exp, half the force cap, its gin / kee / sen from its age, all full.
static func level_npc(npc: NpcRuntimeState, level: int) -> void:
	if level <= 0:
		return
	var state: CharacterState = npc.character_state
	_level_skills(state, npc.definition(), level, false)
	if npc.definition().race_id == &"human":
		state.essence = _full(CharacterDerivedValues.human_maximum_essence(npc.age, state.recovery.atman.maximum))
		state.vitality = _full(CharacterDerivedValues.human_maximum_vitality(npc.age, state.recovery.inner_force.maximum))
		state.spirit = _full(CharacterDerivedValues.human_maximum_spirit(npc.age, state.recovery.mana.maximum))
	heal(state)


## The player made a fighter of `template`'s family at `level`: every martial skill the player had
## dropped, the template's put on at the level and mapped as the template maps them.
static func level_player(state: CharacterState, template: NpcDefinition, level: int, age: int) -> void:
	_level_skills(state, template, maxi(level, 1), true)
	CharacterDerivedValues.refresh_human_player_maxima(state, age)
	heal(state)


## Every martial skill dropped and every skill unmapped (knowledge such as 读书识字 kept).
static func clear_martial(state: CharacterState) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for use_id: StringName in state.skills.enabled_use_ids():
		state.skills.unmap_skill(use_id)
	for skill_id: StringName in state.skills.raw_skill_ids():
		var skill: SkillDefinition = catalog.skill(skill_id)
		if skill != null and skill.skill_type == SkillDefinition.Type.MARTIAL:
			state.skills.remove_skill(skill_id)


static func _level_skills(state: CharacterState, template: NpcDefinition, level: int, replace: bool) -> void:
	level = clampi(level, 1, MAX_LEVEL)
	if replace:
		clear_martial(state)
	for skill_id: StringName in martial_skills(template):
		state.skills.set_raw_level(skill_id, level)
	var skill_map: Dictionary[StringName, StringName] = template.skill_map()
	for use_id: StringName in skill_map:
		state.skills.map_skill(use_id, skill_map[use_id])
	state.progression.combat_experience = experience_for(level)
	@warning_ignore("integer_division")
	var max_force: int = CultivationService.exercise_cap(state) * FORCE_PERCENT / 100
	state.recovery.inner_force = CharacterInternalResourceState.new(max_force, max_force)


static func _full(maximum: int) -> CharacterResourceState:
	return CharacterResourceState.new(maximum, maximum, maximum)


## Everything back to full: conditions cleared, gin / kee / sen and the force at their maxima.
static func heal(state: CharacterState) -> void:
	state.conditions.clear()
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum
	state.recovery.inner_force.current = state.recovery.inner_force.maximum
