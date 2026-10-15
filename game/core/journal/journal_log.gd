class_name JournalLog
extends RefCounted

## The 任务 page's story entries and the 百科's carried items (界面重构 C). An entry is
## recorded the first time its condition holds (JournalEntryDefinition) and kept in
## CharacterState.journal from then on, so a mark or temp mark later cleared, or an item
## given away, does not take back what happened. Only what has happened is shown (owner,
## 界面重构 Q3): a chain shows once one of its entries is recorded, and only those entries.


## One chain as the page shows it: its recorded entries in the order they happened.
class Shown:
	extends RefCounted
	var chain: JournalChainDefinition
	var entries: Array[JournalEntryDefinition] = []
	## The order of its latest entry (chains with the newest news come first).
	var latest: int = 0


## Records every entry whose condition now holds. `temps` are the player's temp marks,
## `held` the item definitions the player carries. True when anything was recorded.
static func record(state: CharacterState, temps: Dictionary[String, int], held: Dictionary[StringName, bool], chains: Array[JournalChainDefinition]) -> bool:
	if state == null:
		return false
	var recorded: bool = false
	for chain: JournalChainDefinition in chains:
		for entry: JournalEntryDefinition in chain.entries:
			var key: String = chain.key_of(entry)
			if not state.journal.has(key) and holds(entry, state, temps, held):
				state.journal[key] = state.journal.size() + 1
				recorded = true
	return recorded


## The player asked `npc_id` about `topic` and was answered: the entries that wait for
## that answer are recorded.
static func heard(state: CharacterState, npc_id: StringName, topic: String, chains: Array[JournalChainDefinition]) -> bool:
	if state == null:
		return false
	var recorded: bool = false
	for chain: JournalChainDefinition in chains:
		for entry: JournalEntryDefinition in chain.entries:
			var key: String = chain.key_of(entry)
			if (
				entry.when == JournalEntryDefinition.When.HEARD and not state.journal.has(key)
				and StringName(entry.key) == npc_id and entry.topic == topic
			):
				state.journal[key] = state.journal.size() + 1
				recorded = true
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


static func holds(entry: JournalEntryDefinition, state: CharacterState, temps: Dictionary[String, int], held: Dictionary[StringName, bool]) -> bool:
	match entry.when:
		JournalEntryDefinition.When.MARK:
			return int(state.marks.get(entry.key, 0)) != 0
		JournalEntryDefinition.When.TEMP:
			return int(temps.get(entry.key, 0)) != 0
		JournalEntryDefinition.When.ITEM:
			return held.has(StringName(entry.key))
		JournalEntryDefinition.When.SEEN:
			return state.seen_npcs.has(entry.key)
	# HEARD is recorded at the ask (heard()).
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


## What `entry` quotes, as the ask showed it (NpcInquiry: translated, $RESPECT as the NPC
## addressed the player); empty when it quotes nothing.
static func quote_lines(entry: JournalEntryDefinition, npc: NpcDefinition, asker_respect: String) -> Array[String]:
	var lines: Array[String] = []
	if npc == null or entry.quote_npc.is_empty():
		return lines
	for text: String in npc.talk().answer(entry.quote_topic):
		var line: String = NpcTalk.line(text).replace("$RESPECT", asker_respect)
		if not line.is_empty():
			lines.append(line)
	return lines
