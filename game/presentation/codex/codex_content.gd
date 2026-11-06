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
	result.append_array(_schools_seen(state, catalog))
	return result


## 见识录 (识招, DECISIONS「战斗内容」; 战斗拍数 D, DECISIONS「战斗拍数 D」): one entry per school
## the player has met — its moves watched (MoveRecognition) or learned, listing only those,
## each with its tag once read (「？」until then), the tag that beats it and how many times it
## was watched; the school's way in one sentence once its style word is known; what the town
## said of it (CombatInsights: the hearsay heard), what its guide taught and showed (the
## lesson's verdict), and the beat habits read of the NPCs who fight with it. Nothing unmet
## is listed, and no count of what is left. The race's and the weapons' moves and the beasts'
## verbs count as schools here.
static func _schools_seen(state: CharacterState, catalog: ContentCatalog) -> Array[Entry]:
	var result: Array[Entry] = []
	if state == null or catalog == null or catalog.pacing().decision_rules().recognise_after <= 0:
		return result
	var rules: CombatDecisionRules = catalog.pacing().decision_rules()
	var schools: Array = []
	for skill_id: StringName in catalog.skill_ids():
		var skill: SkillDefinition = catalog.skill(skill_id)
		if skill.action_set() != null:
			schools.append(["moves/%s" % skill_id, skill.display_name, skill.action_set(), skill])
	schools.append(["moves/race/human", _t("拳脚"), catalog.combat_actions().race_action_set(NpcCharacterStateFactory.HUMAN_RACE_ID), null, &"unarmed"])
	for skill_type: StringName in catalog.combat_actions().weapon_skill_types():
		var weapon: SkillDefinition = catalog.skill(skill_type)
		schools.append(["moves/weapon/%s" % skill_type, weapon.display_name if weapon != null else String(skill_type), catalog.combat_actions().weapon_action_set(skill_type), null, skill_type])
	var beast: Array[CombatActionDefinition] = []
	for verb: StringName in [&"bite", &"claw", &"hoof", &"poke"]:
		beast.append(BeastCombatActionDefinitions.action(verb))
	schools.append(["moves/race/beast", _t("禽兽"), CombatActionSet.new(beast), null])
	for school: Array in schools:
		var set: CombatActionSet = school[2]
		if set == null or set.is_empty():
			continue
		var skill: SkillDefinition = school[3]
		var skill_id: StringName = skill.skill_id if skill != null else (school[4] if school.size() > 4 else &"")
		var watched: bool = false
		var lines: Array[String] = []
		var known_all: bool = true
		for action: CombatActionDefinition in set.actions():
			var seen: int = MoveRecognition.times_seen(state, action.action_id)
			var own: bool = MoveRecognition.is_own(state, action, catalog)
			if seen <= 0 and not own:
				continue
			watched = true
			var known: bool = MoveRecognition.recognised(state, action, rules, catalog)
			known_all = known_all and known
			var name: String = _t(action.display_name) if not action.display_name.is_empty() else String(action.action_id).get_slice("/", String(action.action_id).get_slice_count("/") - 1)
			var parts: Array[String] = [name]
			if known:
				parts.append(CombatMoveTags.label(action.tag))
				var weakness: StringName = MoveRecognition.weakness(action.tag)
				if not weakness.is_empty():
					parts.append(_t("破绽：{tag}").format({"tag": CombatMoveTags.label(weakness)}))
			else:
				parts.append(_t("？"))
			if seen > 0:
				parts.append(_t("见过 {n} 次").format({"n": seen}))
			lines.append(_t(" · ").join(parts))
		var told: Array[String] = _school_told(state, catalog, skill, skill_id)
		if not watched and told.is_empty():
			continue
		var entry := Entry.new(school[0], _t("见识录 · {school}").format({"school": _t(school[1])}))
		if watched:
			entry.add(_t("看熟一招（见过 {n} 次）就认得它的快、重、虚、守和破绽；自家门派的招一学就认得。").format({"n": rules.recognise_after}) if not known_all else _t("这一路的招你都认得。"))
		if skill != null and skill.skeleton != null and not skill.skeleton.style_line.is_empty() and MoveRecognition.style_known(state, skill, rules, catalog):
			# TRANSLATORS: a school's way on its 见识录 entry: {word} the style word (候隙), {line} the way in one sentence.
			entry.add(_t("打法 · {word}：{line}").format({"word": _t(skill.skeleton.style_word), "line": _t(skill.skeleton.style_line)}), Paragraph.Kind.HEADING)
		for line: String in lines:
			entry.add(line)
		for line: String in told:
			entry.add(line, Paragraph.Kind.NOTE)
		result.append(entry)
	return result


## 战斗拍数 D: what the player was told and shown of the school `skill` (`skill_id` for a
## weapon's or the race's moves): the hearsay heard, each with who said it; the guide's 打法
## taught; the lesson's verdict; the beat habits read of the NPCs fighting with it.
static func _school_told(state: CharacterState, catalog: ContentCatalog, skill: SkillDefinition, skill_id: StringName) -> Array[String]:
	var told: Array[String] = []
	if skill_id.is_empty():
		return told
	if skill != null:
		var guide: FamilyDefinition.SchoolGuide = catalog.guide_for(skill_id)
		var master: NpcDefinition = null if guide == null else catalog.npc(guide.master_id)
		for line: FamilyDefinition.Hearsay in catalog.hearsay_for(skill_id):
			if not CombatInsights.has_heard(state, line.key):
				continue
			var npc: NpcDefinition = catalog.npc(line.npc_id)
			# TRANSLATORS: a line of hearsay on a 见识录 entry: {npc} who said it, {line} what.
			told.append(_t("{npc}说过：{line}").format({"npc": npc.short_name() if npc != null else String(line.npc_id), "line": CombatInsights.fill(line.say, master).replace("$RESPECT", "")}))
		if guide != null:
			var npc: NpcDefinition = catalog.npc(guide.npc_id)
			var name: String = npc.short_name() if npc != null else String(guide.npc_id)
			if CombatInsights.taught(state, skill_id) and not guide.teach.is_empty():
				# TRANSLATORS: the guide's teaching on a 见识录 entry: {npc} the guide, {line} their first line.
				told.append(_t("{npc}讲过：{line}").format({"npc": name, "line": CombatInsights.fill(guide.teach[0], master)}))
			var verdict: int = CombatInsights.lesson_verdict(state, skill_id)
			if verdict != 0:
				# TRANSLATORS: the guide's verdict after their lesson, on a 见识录 entry: {npc} the guide, {line} the verdict.
				told.append(_t("{npc}拆过招，说：{line}").format({"npc": name, "line": CombatInsights.fill(CombatInsights.verdict_line(guide, verdict), master)}))
	for habit: CombatInsights.Habit in CombatInsights.habits_of_school(state, skill_id):
		var npc: NpcDefinition = catalog.npc(habit.npc_id)
		var name: String = npc.short_name() if npc != null else String(habit.npc_id)
		# TRANSLATORS: a move of that tag in a beat habit: {tag} 快 / 重 / 虚 / 守 / 平.
		var what: String = _t("绝招") if habit.tag == &"perform" else _t("{tag}招").format({"tag": CombatMoveTags.label(habit.tag) if habit.tag != CombatBeatRules.COST_PLAIN else _t("平")})
		if habit.always():
			# TRANSLATORS: a beat habit read of an NPC: {npc} who, {beat} which beat of a round (1 the first), {tag} 快 / 重 / 虚 / 守 / 绝招.
			told.append(_t("{npc}的第 {beat} 拍总是{tag}（看过 {n} 回）。").format({"npc": name, "beat": habit.beat, "tag": what, "n": habit.total}))
		else:
			# TRANSLATORS: the same, most of the time.
			told.append(_t("{npc}的第 {beat} 拍多半是{tag}（{m} 回里有 {n} 回）。").format({"npc": name, "beat": habit.beat, "tag": what, "m": habit.total, "n": habit.count}))
	return told


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
