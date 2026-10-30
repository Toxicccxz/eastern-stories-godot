class_name JournalLog
extends RefCounted

## The 任务 page's story entries and the 百科's carried items (界面重构 C). An entry is
## recorded the first time its condition holds (JournalEntryDefinition) and kept in
## CharacterState.journal from then on, so a mark or temp mark later cleared, or an item
## given away, does not take back what happened. Only what has happened is shown (owner,
## 界面重构 Q3): a chain shows once one of its entries is recorded, and only those entries.
## Native (前两小时 A; DECISIONS「新手链与当前目标」): recording an entry is told once as a
## 【见闻】 line, and a guide chain's latest entry says what to do next (objective()).


## One chain as the page shows it: its recorded entries in the order they happened.
class Shown:
	extends RefCounted
	var chain: JournalChainDefinition
	var entries: Array[JournalEntryDefinition] = []
	## The order of its latest entry (chains with the newest news come first).
	var latest: int = 0


## An entry just recorded, with its chain.
class Fresh:
	extends RefCounted
	var chain: JournalChainDefinition
	var entry: JournalEntryDefinition

	func _init(p_chain: JournalChainDefinition, p_entry: JournalEntryDefinition) -> void:
		chain = p_chain
		entry = p_entry


## Records every entry whose condition now holds. `temps` are the player's temp marks,
## `held` the item definitions the player carries, `zone_id` where the player stands (ZONE;
## "" when nowhere). True when anything was recorded.
static func record(state: CharacterState, temps: Dictionary[String, int], held: Dictionary[StringName, bool], chains: Array[JournalChainDefinition], zone_id: StringName = &"", worn: Dictionary[StringName, bool] = {}) -> bool:
	return not record_entries(state, temps, held, chains, zone_id, worn).is_empty()


## record(), telling which entries it recorded, in the order it did. `worn` are the item
## definitions the player wears (WEARING).
static func record_entries(state: CharacterState, temps: Dictionary[String, int], held: Dictionary[StringName, bool], chains: Array[JournalChainDefinition], zone_id: StringName = &"", worn: Dictionary[StringName, bool] = {}) -> Array[Fresh]:
	var recorded: Array[Fresh] = []
	if state == null:
		return recorded
	for chain: JournalChainDefinition in chains:
		for entry: JournalEntryDefinition in chain.entries:
			var key: String = chain.key_of(entry)
			if not state.journal.has(key) and holds(entry, state, temps, held, zone_id, worn):
				state.journal[key] = state.journal.size() + 1
				recorded.append(Fresh.new(chain, entry))
	return recorded


## The player asked `npc_id` about `topic` and was answered: the entries that wait for
## that answer are recorded.
static func heard(state: CharacterState, npc_id: StringName, topic: String, chains: Array[JournalChainDefinition]) -> bool:
	return not heard_entries(state, npc_id, topic, chains).is_empty()


## heard(), telling which entries it recorded.
static func heard_entries(state: CharacterState, npc_id: StringName, topic: String, chains: Array[JournalChainDefinition]) -> Array[Fresh]:
	var recorded: Array[Fresh] = []
	if state == null:
		return recorded
	for chain: JournalChainDefinition in chains:
		for entry: JournalEntryDefinition in chain.entries:
			var key: String = chain.key_of(entry)
			if (
				entry.when == JournalEntryDefinition.When.HEARD and not state.journal.has(key)
				and StringName(entry.key) == npc_id and entry.topic == topic
			):
				state.journal[key] = state.journal.size() + 1
				recorded.append(Fresh.new(chain, entry))
	return recorded


## The player heard `npc_id` say `text` (a chat line, in the world or in a fight): the
## entries that wait for those words are recorded.
static func chat_heard(state: CharacterState, npc_id: StringName, text: String, chains: Array[JournalChainDefinition]) -> Array[Fresh]:
	var recorded: Array[Fresh] = []
	if state == null or text.is_empty():
		return recorded
	for chain: JournalChainDefinition in chains:
		for entry: JournalEntryDefinition in chain.entries:
			var key: String = chain.key_of(entry)
			if (
				entry.when == JournalEntryDefinition.When.CHAT and not state.journal.has(key)
				and StringName(entry.key) == npc_id and text.contains(entry.topic)
			):
				state.journal[key] = state.journal.size() + 1
				recorded.append(Fresh.new(chain, entry))
	return recorded


## The items carried join the 百科's list, each in the order first carried.
static func note_items(state: CharacterState, held: Dictionary[StringName, bool]) -> bool:
	if state == null:
		return false
	var noted: bool = false
	for item_id: StringName in held:
		var key: String = String(item_id)
		if not state.known_items.has(key):
			state.known_items[key] = state.known_items.size() + 1
			noted = true
	return noted


## Whether `entry`'s condition holds now; `zone_id` is where the player stands (ZONE), `worn`
## the item definitions they wear (WEARING).
static func holds(entry: JournalEntryDefinition, state: CharacterState, temps: Dictionary[String, int], held: Dictionary[StringName, bool], zone_id: StringName = &"", worn: Dictionary[StringName, bool] = {}) -> bool:
	match entry.when:
		JournalEntryDefinition.When.WEARING:
			return worn.has(StringName(entry.key))
		JournalEntryDefinition.When.ANY:
			return entry.parts.any(func(part: JournalEntryDefinition) -> bool: return holds(part, state, temps, held, zone_id, worn))
		JournalEntryDefinition.When.ALL:
			return entry.parts.all(func(part: JournalEntryDefinition) -> bool: return holds(part, state, temps, held, zone_id, worn))
		JournalEntryDefinition.When.MARK:
			return int(state.marks.get(entry.key, 0)) != 0
		JournalEntryDefinition.When.TEMP:
			return int(temps.get(entry.key, 0)) != 0
		JournalEntryDefinition.When.ITEM:
			return held.has(StringName(entry.key))
		JournalEntryDefinition.When.SEEN:
			return state.seen_npcs.has(entry.key)
		JournalEntryDefinition.When.MILESTONE:
			return state.milestones.has(entry.key)
		JournalEntryDefinition.When.FORCE_AT_LEAST:
			return state.recovery.inner_force.maximum >= entry.amount
		JournalEntryDefinition.When.EXP_AT_LEAST:
			return state.progression.combat_experience >= entry.amount
		JournalEntryDefinition.When.SKILL_AT_LEAST:
			return state.skills.raw_level(StringName(entry.key)) >= entry.amount
		JournalEntryDefinition.When.FAMILY:
			return state.family.family_id == StringName(entry.key)
		JournalEntryDefinition.When.ZONE:
			return not zone_id.is_empty() and StringName(entry.key) == zone_id
		JournalEntryDefinition.When.QUEST:
			# A branch step's key stands for whichever of its options was taken.
			if state.quests.has(entry.key):
				return true
			var prefix: String = entry.key + "/"
			for key: String in state.quests:
				if key.begins_with(prefix):
					return true
			return false
	# HEARD is recorded at the ask (heard()), CHAT as the line is said (chat_heard()).
	return false


## The chains whose story is seen through: one of their `final` entries is recorded.
static func finished_chains(state: CharacterState, chains: Array[JournalChainDefinition]) -> Array[JournalChainDefinition]:
	var result: Array[JournalChainDefinition] = []
	if state == null:
		return result
	for chain: JournalChainDefinition in chains:
		if finished(state, chain):
			result.append(chain)
	return result


static func finished(state: CharacterState, chain: JournalChainDefinition) -> bool:
	for entry: JournalEntryDefinition in chain.entries:
		if entry.final and state.journal.has(chain.key_of(entry)):
			return true
	return false


## The chains with something recorded, the one with the newest entry first.
static func shown(state: CharacterState, chains: Array[JournalChainDefinition]) -> Array[Shown]:
	var result: Array[Shown] = []
	if state == null:
		return result
	for chain: JournalChainDefinition in chains:
		var view := Shown.new()
		view.chain = chain
		for entry: JournalEntryDefinition in chain.entries:
			var order: int = int(state.journal.get(chain.key_of(entry), 0))
			if order > 0:
				view.entries.append(entry)
				view.latest = maxi(view.latest, order)
		if not view.entries.is_empty():
			view.entries.sort_custom(func(a: JournalEntryDefinition, b: JournalEntryDefinition) -> bool:
				return int(state.journal[chain.key_of(a)]) < int(state.journal[chain.key_of(b)]))
			result.append(view)
	result.sort_custom(func(a: Shown, b: Shown) -> bool: return a.latest > b.latest)
	return result


## What to do next (the status card's 目标 row): the `next` of the newest recorded entry
## among the guide chains not seen through; "" when no guide chain says anything.
static func objective(state: CharacterState, chains: Array[JournalChainDefinition]) -> String:
	for view: Shown in shown(state, chains):
		if view.chain.guide and not finished(state, view.chain):
			return view.entries[-1].next
	return ""


## The lines that tell an entry was recorded: 【见闻】 and its text, then (a guide chain's
## entry, `with_next`) what to do next.
static func told_lines(fresh: Fresh, with_next: bool) -> Array[ColoredLine]:
	var lines: Array[ColoredLine] = []
	# TRANSLATORS: native (前两小时 A): the 任务 page recorded {text} (an entry's own line).
	lines.append(ColoredLine.new(_t("【见闻】{text}").format({"text": _t(fresh.entry.text)}), ColoredLine.HIG))
	if with_next and fresh.chain.guide and not fresh.entry.next.is_empty():
		# TRANSLATORS: native (前两小时 A): under a guide chain's 【见闻】 line, {next} what to do next.
		lines.append(ColoredLine.new(_t("下一步：{next}").format({"next": _t(fresh.entry.next)}), ColoredLine.HIG))
	return lines


## What `entry` quotes, as the ask showed it (NpcInquiry: translated, $RESPECT as the NPC
## addressed the player); empty when it quotes nothing.
static func quote_lines(entry: JournalEntryDefinition, npc: NpcDefinition, asker_respect: String) -> Array[String]:
	var lines: Array[String] = []
	if npc == null or entry.quote_npc.is_empty():
		return lines
	for text: String in npc.talk().answer(entry.quote_topic):
		# An authored line of several lines quotes as several.
		for line: String in NpcTalk.line(text).replace("$RESPECT", asker_respect).split("\n", false):
			if not line.strip_edges().is_empty():
				lines.append(line.strip_edges())
	return lines


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
