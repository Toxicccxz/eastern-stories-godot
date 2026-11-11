extends RefCounted

## DECISIONS「主线人物的武功」: a native NPC one can fight fights with the 武功 its data writes.
## Two slips made the story's bosses weak without anyone seeing (商玦 bare-handed with 六阴追魂剑,
## 庾子建's 短歌刀法 never enabled): this suite names any native NPC that is not fight_deferred and
## - knows a specialized skill that enables nothing (no skill_map entry: it fights at half its
##   basic level), or
## - has a weapon skill (sword, blade, …) and wields nothing, or wields a weapon whose skill it
##   does not have.
## ES2's own NPCs are as their LPC wrote them and are not checked. One that stands bare-handed on
## purpose goes in ALLOWED with the reason.

const ALLOWED: Dictionary[StringName, String] = {
	&"native.npc.huo_zheng": "关在逆灵宫牢里的霍铮，手腕上只有铁链，没有刀",
}

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	var catalog: ContentCatalog = GameContent.catalog()
	var weapon_skills: Dictionary[StringName, bool] = {}
	for item: ItemContentDefinition in catalog.items():
		if not item.weapon_skill_type.is_empty():
			weapon_skills[item.weapon_skill_type] = true
	weapon_skills.erase(&"unarmed")
	var unmapped: Array[String] = []
	var mismatched: Array[String] = []
	var checked: int = 0
	for npc: NpcDefinition in catalog.npcs():
		if not _native(npc) or ALLOWED.has(npc.definition_id):
			continue
		if npc.dealings() != null and npc.dealings().is_fight_deferred():
			continue
		checked += 1
		var enabled: Array[StringName] = npc.skill_map().values()
		var known: Dictionary[StringName, bool] = {}
		for level: NpcSkillLevelDefinition in npc.skill_levels():
			known[level.skill_id] = true
			var skill: SkillDefinition = catalog.skill(level.skill_id)
			if skill != null and skill.kind == SkillDefinition.Kind.SPECIALIZED and not enabled.has(level.skill_id):
				unmapped.append("%s %s" % [npc.definition_id, level.skill_id])
		var wielded: StringName = &""
		for entry: NpcLoadoutEntry in npc.loadout_entries():
			if entry.equipment_intent == NpcLoadoutEntry.EquipmentIntent.WIELD_PRIMARY:
				var item: ItemContentDefinition = catalog.item(entry.item_definition_id)
				wielded = &"" if item == null else item.weapon_skill_type
		var weapon_known: Array[StringName] = []
		for skill_id: StringName in known:
			if weapon_skills.has(skill_id):
				weapon_known.append(skill_id)
		if not weapon_known.is_empty() and wielded.is_empty():
			mismatched.append("%s knows %s and wields nothing" % [npc.definition_id, weapon_known])
		elif not wielded.is_empty() and wielded != &"unarmed" and not known.has(wielded):
			mismatched.append("%s wields a %s weapon and knows %s" % [npc.definition_id, wielded, weapon_known])
	_check(checked > 100, "the native NPCs one can fight are checked (%d)" % checked)
	_check(unmapped.is_empty(), "every specialized skill enables a basic one (skill_map): %s" % [unmapped])
	_check(mismatched.is_empty(), "every weapon skill has its weapon in hand, every weapon its skill: %s" % [mismatched])
	for id: StringName in ALLOWED:
		_check(catalog.npc(id) != null, "ALLOWED names an NPC that exists: %s" % id)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


static func _native(npc: NpcDefinition) -> bool:
	return String(npc.definition_id).begins_with("native.") or npc.legacy_source_path.begins_with("native")


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("npc martial data: " + label)
