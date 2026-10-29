extends RefCounted

## 前两小时 D (owner, 2026-10-26; DECISIONS「刘安禄的揭露」): guard.c ask_me() ported — below
## 20000 combat_exp 刘老三 gets ask.c's own line; from 20000 a draw of random(10) < 5 says
## 我...不知道！, else the revealed mood (title, nickname, applies, the 残破刀谱, lasting
## through a reset) and the attack; asked again he attacks at once; the confirm before the
## ask; the clue chain 门房的来历 (heard, chat in the world and in a fight, the mark).

const GUARD_SPAWN: StringName = &"snow.outdoor.school1.guard"
const BLADE_BOOK: StringName = &"es2:d/snow/obj/blade_book"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_rules()
	_test_chat_entries()
	var session: WorldSessionController = await _session(tree)
	await _test_in_the_world(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## ask_me()'s branches, through NpcInquiry alone: the exp gate, the draw, the mood and the
## attack, the revealed NPC's own line.
func _test_rules() -> void:
	var guard: NpcDefinition = GameContent.catalog().npc(&"snow.npc.guard")
	_check(guard.talk().inquiry_topics() == ["刘老三", "血手刘三", "大寨主"] and guard.talk().ask_confirm("血手刘三").begins_with("刘安禄的来历不简单"), "the two topics (and 主线 C's 大寨主), confirmed first")
	var mood: NpcMood = guard.hooks().moods.get("revealed")
	_check(mood != null and mood.lasting and mood.title == "野羊山寨二寨主" and mood.nickname == "血手刘三" and mood.applies.get("combat_exp", 0) == 30000 and mood.carry == [BLADE_BOOK] and mood.has_combat_chat(), "the revealed mood as guard.c sets it")
	var none := ScriptedWorldInteractionRandomSource.new([])
	var weak := NpcInquiry.Asker.new(&"男性", 20, &"", 100, {}, 19999)
	var said: Array[String] = NpcInquiry.ask(guard, &"男性", 26, true, weak, "刘老三", "", ScriptedWorldInteractionRandomSource.new([0]))
	_check(said.size() == 2 and said[0] == "你向刘安禄打听有关『刘老三』的消息。" and not said[1].contains("血手") and not said[1].contains("不知道！"), "below 20000: ask.c's own line, no reaction: %s" % [said])
	var strong := NpcInquiry.Asker.new(&"男性", 20, &"", 100, {}, 20000)
	var dodged: NpcInquiry.Answer = NpcInquiry.answer(guard, &"男性", 26, true, strong, "刘老三", "", ScriptedWorldInteractionRandomSource.new([4]))
	_check(dodged.texts().size() == 2 and dodged.texts()[1] == "刘安禄说道：我...不知道！" and dodged.mood.is_empty() and not dodged.attacks, "random(10) = 4 < 5: 我...不知道！: %s" % [dodged.texts()])
	var revealed: NpcInquiry.Answer = NpcInquiry.answer(guard, &"男性", 26, true, strong, "血手刘三", "", ScriptedWorldInteractionRandomSource.new([5]))
	_check(revealed.texts().size() == 4 and revealed.texts()[1].begins_with("刘安禄眼中突然放出异样的光芒") and revealed.texts()[3].ends_with("判若两人！"), "random(10) = 5: the reveal's three lines: %s" % [revealed.texts()])
	_check(revealed.mood == "revealed" and revealed.attacks and revealed.marks == ["血手刘三"], "the mood, the attack, the mark")
	var again: NpcInquiry.Answer = NpcInquiry.answer(guard, &"男性", 26, true, strong, "刘老三", "", none, Callable(), [], {&"mood/revealed": true})
	_check(again.texts().size() == 2 and again.texts()[1] == "刘安禄说道：老子就是血手刘三，血手刘三就是你老子！纳命来！" and again.attacks and again.mood.is_empty(), "revealed and asked again: 纳命来: %s" % [again.texts()])
	var weak_again: NpcInquiry.Answer = NpcInquiry.answer(guard, &"男性", 26, true, weak, "刘老三", "", none, Callable(), [], {&"mood/revealed": true})
	_check(weak_again.attacks, "revealed: the exp gate no longer holds him back")
	_check(none.call_count() == 0, "a revealed NPC draws nothing")


## The 任务 page's `chat` condition: an NPC's line with the words, in the world or in a fight.
func _test_chat_entries() -> void:
	var errors: Array[String] = []
	var chain: JournalChainDefinition = JournalChainDefinition.from_record(ContentRecordReader.new({
		"id": "t.chat", "title": "闲话", "region": "某地",
		"entries": [{"id": "heard", "when": {"chat": {"npc": "t.npc", "contains": "臭道士"}}, "text": "听见了"}],
	}, "test", errors))
	_check(errors.is_empty() and chain.entries[0].when == JournalEntryDefinition.When.CHAT and chain.entries[0].key == "t.npc" and chain.entries[0].topic == "臭道士", "a chat condition reads: %s" % [errors])
	var state := CharacterState.new()
	var chains: Array[JournalChainDefinition] = [chain]
	_check(JournalLog.chat_heard(state, &"t.npc", "樵夫说道：日子不好过", chains).is_empty() and JournalLog.chat_heard(state, &"other", "臭道士", chains).is_empty(), "other words, another NPC: nothing")
	_check(JournalLog.chat_heard(state, &"t.npc", "樵夫说道：野羊山那群臭道士真是该千刀万剐....", chains).size() == 1 and state.journal.has("t.chat/heard"), "the words heard: recorded")
	_check(JournalLog.chat_heard(state, &"t.npc", "臭道士", chains).is_empty(), "once")
	_check(not JournalLog.holds(chain.entries[0], state, {}, {}), "never by looking")


## In the world: the confirm, the reveal (a scripted draw), the mood on the NPC, the blade
## book in his hands, the fight, the chain's entries; a reset keeps the mood.
func _test_in_the_world(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var chains: Array[JournalChainDefinition] = GameContent.catalog().journal_chains()
	# The clues: 魏无极's and 柳淳风's answers end the chain; the woodcutter's chat and the
	# guard's slip in a fight add theirs.
	var woodcutter: NpcRuntimeState = _npc_of(session, &"snow.npc.woodcutter")
	session.chat_heard(woodcutter, "樵夫说道：野羊山那群臭道士真是该千刀万剐....")
	_check(state.journal.has("snow.liu_anlu/woodcutter") and ui.log_lines().has("【见闻】樵夫骂野羊山那群道士该千刀万剐，说他们施了妖法。"), "the woodcutter's chat: recorded and told")
	var guard: NpcRuntimeState = _npc_of(session, &"snow.npc.guard")
	session.chat_heard(guard, "刘安禄说道：想我堂堂....呃....连我这个淳风武馆的小小的门房都可以收拾你！\n")
	_check(state.journal.has("snow.liu_anlu/slip"), "the guard's slip in a fight: recorded")
	_check(JournalLog.objective(state, chains) != "去淳风武馆问问柳淳风「刘安禄」。", "no next step before 魏无极 was asked")
	JournalLog.heard(state, &"snow.npc.teacher", "刘安禄", chains)
	_check(JournalLog.objective(state, chains) == "去淳风武馆问问柳淳风「刘安禄」。", "魏无极 asked: on to 柳淳风")
	JournalLog.heard(state, &"common.npc.swordsman.master", "刘安禄", chains)
	_check(JournalLog.finished(state, _chain(&"snow.liu_anlu")), "柳淳风 asked: the chain is seen through")
	# At the gate: below 20000 nothing; the confirm first.
	await _stand_at(tree, session, GUARD_SPAWN)
	var map: WorldMapController = session.active_map() as WorldMapController
	guard = _npc_of(session, &"snow.npc.guard")
	_check(map.select_npc(guard.character_id) and map.ask_topics_selected().has("刘老三"), "刘安禄 in reach")
	ui.open_current_context()
	ui.ask._ask_topic("刘老三")
	_check(ui.questions.is_asking() and ui.confirm_prompt.message.text.begins_with("刘安禄的来历不简单"), "the confirm first: " + ui.confirm_prompt.message.text)
	ui.confirm_prompt.cancel()
	_check(not ui.questions.is_asking() and not state.journal.has("snow.liu_anlu/revealed") and guard.mood() == null, "取消: nothing asked")
	map.select_npc(guard.character_id)
	var said: Array[String] = map.ask_selected("刘老三")
	_check(said.size() == 2 and guard.mood() == null and not session.combat_encounter_coordinator().has_active_encounter(), "below 20000: no reaction: %s" % [said])
	# From 20000: the draw decides; asked until he turns (the seeded source).
	state.progression.combat_experience = 20000 # TEST-ONLY
	var turned: bool = false
	for attempt: int in 12:
		map.select_npc(guard.character_id)
		said = map.ask_selected("血手刘三")
		if guard.mood() != null:
			turned = true
			break
		_check(said.size() == 2 and said[1] == "刘安禄说道：我...不知道！", "a miss: 我...不知道！: %s" % [said])
	_check(turned and said.size() == 4 and said[3].ends_with("判若两人！"), "the reveal: %s" % [said])
	_check(guard.mood().name == "revealed" and guard.short_name() == "野羊山寨二寨主「血手刘三」刘安禄" and guard.has_flag(&"aggressive") and guard.has_flag(&"hunts_player"), "the mood: title, nickname, flags: " + guard.short_name())
	_check(guard.character_state.applies.get("combat_exp", 0) == 30000 and guard.character_state.applies.get("attack", 0) == 70, "the applies")
	_check(_carries(session, guard, BLADE_BOOK), "the 残破刀谱 in his hands")
	_check(state.marks.get("血手刘三", 0) == 1, "marked")
	_check(session.combat_encounter_coordinator().has_active_encounter(), "and he attacks")
	session.record_journal()
	_check(state.journal.has("snow.liu_anlu/revealed"), "the chain's last entry")
	_check(guard.combat_talk() != guard.definition().talk() and guard.combat_talk().has_combat_chat(), "his combat chat is the mood's (游走)")
	# A room reset keeps a lasting mood (guard.c's object variable).
	guard.end_mood(true)
	_check(guard.mood() != null, "a reset keeps it")
	guard.end_mood()
	_check(guard.mood() == null, "ended outright, it goes")


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("追问", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _stand_at(tree: SceneTree, session: WorldSessionController, spawn_id: StringName) -> void:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	session.handoff_to(spawn.map_id, spawn.zone_id, spawn.zone_id, spawn.spawn_point_ids()[0])
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _chain(chain_id: StringName) -> JournalChainDefinition:
	for chain: JournalChainDefinition in GameContent.catalog().journal_chains():
		if chain.chain_id == chain_id:
			return chain
	return null


func _npc_of(session: WorldSessionController, definition_id: StringName) -> NpcRuntimeState:
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id:
				return npc
	return null


func _carries(session: WorldSessionController, npc: NpcRuntimeState, item_definition_id: StringName) -> bool:
	var inventory: InventoryState = session.inventory_state()
	for item_id: StringName in inventory.direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, npc.character_id)):
		var item: ItemInstance = session.item_instance_index().resolve(item_id) if inventory.is_registered(item_id) else null
		if item != null and item.item_definition_id == item_definition_id:
			return true
	return false


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
