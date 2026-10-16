class_name CodexContent
extends RefCounted

## The 百科's entries (界面重构 C), put together from the data and what the player has met:
## 江湖常识 are the ES2 help files for players (codex.json); 武学 the skills the player has
## learned, 物品 the items they have carried, 门派 the families whose people they have met
## or that they belong to, 人物 the people they have met. Nothing unmet is listed, so
## nothing is given away. Every text is in the shown language.

enum Section { LORE, ARTS, ITEMS, FAMILIES, PEOPLE }

## Section titles, in Section order.
const SECTION_TITLES: Array[String] = ["江湖常识", "武学", "物品", "门派", "人物"]


class Paragraph:
	extends RefCounted
	enum Kind { BODY, HEADING, NOTE }
	var text: String
	var kind: int

	func _init(p_text: String, p_kind: int = Kind.BODY) -> void:
		text = p_text
		kind = p_kind


class Entry:
	extends RefCounted
	var key: String
	var title: String
	var paragraphs: Array[Paragraph] = []

	func _init(p_key: String, p_title: String) -> void:
		key = p_key
		title = p_title

	func add(text: String, kind: int = Paragraph.Kind.BODY) -> void:
		paragraphs.append(Paragraph.new(text, kind))

	## Every text of the entry, one per line (tests).
	func text() -> String:
		var lines: Array[String] = [title]
		for paragraph: Paragraph in paragraphs:
			lines.append(paragraph.text)
		return "\n".join(lines)


static func entries(section: int, state: CharacterState, catalog: ContentCatalog) -> Array[Entry]:
	match section:
		Section.LORE:
			return _lore(catalog)
		Section.ARTS:
			return _arts(state, catalog)
		Section.ITEMS:
			return _items(state, catalog)
		Section.FAMILIES:
			return _families(state, catalog)
		Section.PEOPLE:
			return _people(state, catalog)
	return []


static func _lore(catalog: ContentCatalog) -> Array[Entry]:
	var result: Array[Entry] = []
	for topic: CodexTopicDefinition in catalog.codex_topics():
		var entry := Entry.new(String(topic.topic_id), _t(topic.title))
		for index: int in topic.paragraphs.size():
			entry.add(_t(topic.paragraphs[index]), Paragraph.Kind.HEADING if topic.headings.has(index) else Paragraph.Kind.BODY)
		if not topic.byline.is_empty():
			entry.add("—— " + topic.byline, Paragraph.Kind.NOTE)
		result.append(entry)
	return result


## Basic skills first, then the others, each by name as authored.
static func _arts(state: CharacterState, catalog: ContentCatalog) -> Array[Entry]:
	var result: Array[Entry] = []
	if state == null:
		return result
	var skills: Array[SkillDefinition] = []
	for skill_id: StringName in state.skills.raw_skill_ids():
		var skill: SkillDefinition = catalog.skill(skill_id)
		if skill != null:
			skills.append(skill)
	skills.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		return a.display_name < b.display_name if a.kind == b.kind else a.kind == SkillDefinition.Kind.BASIC)
	for skill: SkillDefinition in skills:
		var entry := Entry.new(String(skill.skill_id), _t(skill.display_name))
		entry.add("{kind} · {type}".format({
			"kind": _t("基本功夫" if skill.kind == SkillDefinition.Kind.BASIC else "特殊技能"),
			"type": _t("知识" if skill.skill_type == SkillDefinition.Type.KNOWLEDGE else "武功"),
		}))
		var uses: Array[String] = []
		for use_id: StringName in skill.valid_enabled_uses():
			var basic: SkillDefinition = catalog.skill(use_id)
			if basic != null and use_id != skill.skill_id:
				uses.append(_t(basic.display_name))
		if not uses.is_empty():
			entry.add(_t("可以激发为：{uses}").format({"uses": _t("、").join(uses)}))
		var functions: Array[String] = []
		for function_id: StringName in skill.exert_functions:
			if ExertFunctions.LABELS.has(function_id):
				functions.append(_t(ExertFunctions.LABELS[function_id]))
		if not functions.is_empty():
			entry.add(_t("运功：{functions}").format({"functions": _t("、").join(functions)}))
		entry.add(_t("你的等级：{level}").format({"level": state.skills.raw_level(skill.skill_id)}), Paragraph.Kind.NOTE)
		result.append(entry)
	return result


## In the order first carried.
static func _items(state: CharacterState, catalog: ContentCatalog) -> Array[Entry]:
	var result: Array[Entry] = []
	if state == null:
		return result
	for item_id: String in _in_order(state.known_items):
		var content: ItemContentDefinition = catalog.item(StringName(item_id))
		if content == null:
			continue
		var entry := Entry.new(item_id, _t(content.display_name))
		var description: String = content.shown_description().strip_edges()
		if description.is_empty():
			entry.add(_t("没有什么特别之处。"), Paragraph.Kind.NOTE)
		else:
			entry.add(description)
		result.append(entry)
	return result


## The player's own family first, then by when one of its people was first met.
static func _families(state: CharacterState, catalog: ContentCatalog) -> Array[Entry]:
	var result: Array[Entry] = []
	if state == null:
		return result
	var order: Array[StringName] = []
	var members: Dictionary[StringName, Array] = {}
	var own: StringName = state.family.family_id
	if not own.is_empty() and catalog.family(own) != null:
		order.append(own)
		members[own] = []
	for npc_id: String in _in_order(state.seen_npcs):
		var npc: NpcDefinition = catalog.npc(StringName(npc_id))
		var family: FamilyDefinition = null if npc == null else _family_of(npc, catalog)
		if family == null:
			continue
		if not members.has(family.family_id):
			order.append(family.family_id)
			members[family.family_id] = []
		members[family.family_id].append(npc.short_name())
	for family_id: StringName in order:
		var family: FamilyDefinition = catalog.family(family_id)
		var entry := Entry.new(String(family_id), _t(family.display_name))
		if family_id == own:
			entry.add(_t("你是{family}的弟子。").format({"family": _t(family.display_name)}))
		var names: Array[String] = []
		for name: String in members[family_id]:
			names.append(name)
		if not names.is_empty():
			entry.add(_t("你见过的门人：{names}").format({"names": _t("、").join(names)}))
		result.append(entry)
	return result


## In the order first met.
static func _people(state: CharacterState, catalog: ContentCatalog) -> Array[Entry]:
	var result: Array[Entry] = []
	if state == null:
		return result
	for npc_id: String in _in_order(state.seen_npcs):
		var npc: NpcDefinition = catalog.npc(StringName(npc_id))
		if npc == null:
			continue
		var entry := Entry.new(npc_id, npc.short_name())
		var description: String = _t(npc.description).strip_edges()
		if description.is_empty():
			entry.add(_t("你没有特别留意过此人的模样。"), Paragraph.Kind.NOTE)
		else:
			entry.add(description)
		var family: FamilyDefinition = _family_of(npc, catalog)
		if family != null:
			entry.add(_t("门派：{family}").format({"family": _t(family.display_name)}), Paragraph.Kind.NOTE)
		result.append(entry)
	return result


static func _family_of(npc: NpcDefinition, catalog: ContentCatalog) -> FamilyDefinition:
	var teaching: NpcTeaching = npc.teaching()
	if teaching == null or not teaching.has_family():
		return null
	return catalog.family_named(teaching.family_name)


## The keys of an {id: order} record, by order.
static func _in_order(counts: Dictionary[String, int]) -> Array[String]:
	var keys: Array[String] = []
	keys.assign(counts.keys())
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] < counts[b])
	return keys


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
