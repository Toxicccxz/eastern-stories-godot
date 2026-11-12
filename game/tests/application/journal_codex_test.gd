extends RefCounted
## The 任务 page's 江湖见闻 and the 百科 (界面重构 C): entries are recorded the first time
## their condition holds and kept; only what happened shows (owner Q3); the 百科's 江湖常识 is
## 入门 then 传说 (百科重写) and it lists only skills learned, items carried, families and
## people met, each skill and family with what it is.

const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_log_rules()
	_test_records_refused()
	_test_help_topics()
	_test_journal_data()
	await _test_menu_pages(tree)
	await _test_ask_and_continue(tree)
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _chain(record: Dictionary, errors: Array[String]) -> JournalChainDefinition:
	return JournalChainDefinition.from_record(ContentRecordReader.new(record, "test", errors))


## Marks, temp marks, items carried and people met record their entries once, in the order
## they happen; what is recorded stays when the mark goes; an answer waits for the ask.
func _test_log_rules() -> void:
	var errors: Array[String] = []
	var chain: JournalChainDefinition = _chain({
		"id": "t.story", "title": "故事", "region": "某地", "sources": ["d/x.c"],
		"entries": [
			{"id": "asked", "when": {"heard": {"npc": "t.npc", "topic": "玉佩"}}, "text": "问过"},
			{"id": "marked", "when": {"mark": "m"}, "text": "标记"},
			{"id": "temp", "when": {"temp": "x/y"}, "text": "临时"},
			{"id": "got", "when": {"item": "t.item"}, "text": "拿到"},
			{"id": "met", "when": {"seen": "t.npc"}, "text": "遇见"},
		],
	}, errors)
	var other: JournalChainDefinition = _chain({"id": "t.other", "title": "另一个", "region": "别处", "entries": [{"id": "a", "when": {"mark": "n"}, "text": "甲"}]}, errors)
	_check(errors.is_empty() and chain.entries.size() == 5, "chains read: %s" % [errors])
	var chains: Array[JournalChainDefinition] = [chain, other]
	var state := CharacterState.new()
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	_check(not JournalLog.record(state, temps, held, chains) and JournalLog.shown(state, chains).is_empty(), "nothing happened: nothing shows")
	state.marks["n"] = 1
	_check(JournalLog.record(state, temps, held, chains) and state.journal == {"t.other/a": 1}, "a mark records its entry")
	state.seen_npcs["t.npc"] = 1
	held[&"t.item"] = true
	JournalLog.record(state, temps, held, chains)
	_check(state.journal.get("t.story/got") == 2 and state.journal.get("t.story/met") == 3, "carried and met, in chain order within one look: %s" % [state.journal])
	_check(not state.journal.has("t.story/asked"), "an answer is not recorded by looking")
	_check(JournalLog.heard(state, &"t.npc", "玉佩", chains) and state.journal.get("t.story/asked") == 4, "the ask records it")
	_check(not JournalLog.heard(state, &"t.npc", "玉佩", chains) and not JournalLog.heard(state, &"t.npc", "别的", chains), "once, and only for its topic")
	temps["x/y"] = 1
	state.marks["m"] = 1
	JournalLog.record(state, temps, held, chains)
	state.marks.erase("m")
	temps.clear()
	held.clear()
	_check(not JournalLog.record(state, temps, held, chains) and state.journal.size() == 6, "a cleared mark, temp or item takes nothing back")
	var shown: Array[JournalLog.Shown] = JournalLog.shown(state, chains)
	var order: Array[String] = []
	for entry: JournalEntryDefinition in shown[0].entries:
		order.append(String(entry.entry_id))
	_check(shown.size() == 2 and shown[0].chain == chain and shown[1].chain == other, "the chain with the newest entry first")
	_check(order == ["got", "met", "asked", "marked", "temp"], "entries in the order they happened: %s" % [order])
	_check(JournalLog.note_items(state, {&"t.item": true, &"t.other": true} as Dictionary[StringName, bool]) and state.known_items.size() == 2, "items carried join the 百科's list")
	_check(not JournalLog.note_items(state, {&"t.item": true} as Dictionary[StringName, bool]) and state.known_items["t.item"] == 1, "once, in the order first carried")


func _test_records_refused() -> void:
	var errors: Array[String] = []
	_chain({"id": "t.bad", "title": "坏", "region": "某地", "entries": [{"id": "a", "when": {"mark": "m", "temp": "t"}, "text": "甲"}]}, errors)
	_check(not errors.is_empty(), "an entry with two conditions is refused")
	errors.clear()
	_chain({"id": "t.bad", "title": "坏", "region": "某地", "entries": [{"id": "a", "when": {"mark": "m"}, "text": "甲"}, {"id": "a", "when": {"mark": "n"}, "text": "乙"}]}, errors)
	_check(not errors.is_empty(), "a duplicate entry is refused")
	errors.clear()
	_chain({"id": "t.bad", "title": "坏", "region": "某地", "entries": []}, errors)
	_check(not errors.is_empty(), "a chain without entries is refused")


## 江湖常识 (DECISIONS「百科重写」): the 入门 entries first, then the 传说 kept from ES2's
## help files; no MUD commands, players, wizards, authors' asides or bylines.
func _test_help_topics() -> void:
	var topics: Array[CodexTopicDefinition] = GameContent.catalog().codex_topics()
	var titles: Array[String] = []
	var groups: Array[String] = []
	for topic: CodexTopicDefinition in topics:
		titles.append(topic.title)
		if groups.is_empty() or groups.back() != topic.group:
			groups.append(topic.group)
	_check(titles[0] == "初入江湖" and titles.has("精气神") and titles.has("学武") and titles.has("主题故事") and titles.has("历史"), "the 江湖常识: %s" % [titles])
	_check(groups == ["入门", "传说"], "入门, then 传说: %s" % [groups])
	var bare: Array[String] = []
	for skill_id: StringName in GameContent.catalog().skill_ids():
		if GameContent.catalog().skill(skill_id).summary.is_empty():
			bare.append(String(skill_id))
	for family_id: StringName in [&"family.fonxan", &"family.fonxan_north", &"family.zhenyuan", &"family.dongfang", &"family.celestial", &"family.juechen", &"family.maoshan", &"family.latemoon", &"family.sanyen", &"family.xiaoyao", &"family.tianshan", &"family.buxuan", &"family.huazi", &"family.shield_guild", &"family.ghost_hat_ronin", &"family.ritola_temple"]:
		if GameContent.catalog().family(family_id).intro.is_empty():
			bare.append(String(family_id))
	_check(bare.is_empty(), "every skill has a summary and every family an intro: %s" % [bare])
	var commands := RegEx.create_from_string("\\b(score|enable|exercise|meditate|respirate|kill|fight|help|study|learn|surrender|wield|tear|quit|who|login)\\b")
	var mud: Array[String] = []
	for topic: CodexTopicDefinition in topics:
		for paragraph: String in topic.paragraphs:
			if commands.search(paragraph) != null or paragraph.contains("玩家") or paragraph.contains("巫师") or paragraph.contains("东方故事") or paragraph.contains("Annihilator") or paragraph.contains("二十世纪") or paragraph.contains("美少女"):
				mud.append("%s: %s" % [topic.title, paragraph.left(30)])
	_check(mud.is_empty(), "no MUD commands, players or wizards left: %s" % [mud])


## Every chain's conditions name what the game has (ContentCatalogBuilder checks it).
func _test_journal_data() -> void:
	var chains: Array[JournalChainDefinition] = GameContent.catalog().journal_chains()
	var entries: int = 0
	for chain: JournalChainDefinition in chains:
		entries += chain.entries.size()
	_check(chains.size() >= 10 and entries >= 25, "the story chains: %d chains, %d entries" % [chains.size(), entries])


## The menu: 任务 shows nothing before anything happened, then the chain; 百科's sections,
## the list beside the entry read; people and items as met.
func _test_menu_pages(tree: SceneTree) -> void:
	var session: WorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	_check(session.configure_source_entry("百科", CharacterState.GENDER_MALE), "source setup")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	var ui: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	ui.menu.open(GameMenu.Tab.JOURNAL)
	# The 新手链 (前两小时 A) opens with the waiter met at New Game, under 差事 (任务系统); the main
	# quest 寻剑令 begins with him too, under 主线 with its next step; a chain never says one.
	var opening: String = ui.quest_page.shown_text()
	_check(opening.begins_with("主线\n寻剑令 · 雪亭镇") and opening.contains("差事\n雪亭镇的头几天 · 雪亭镇\n· 你在饮风客栈醒来") and not opening.contains("下一步：跟店小二打听「楼上」"), "任务: 寻剑令 under 主线, the 新手链's first entry alone under 差事: " + opening.left(120))
	var chain: JournalChainDefinition = null
	for candidate: JournalChainDefinition in GameContent.catalog().journal_chains():
		if candidate.entries[0].when == JournalEntryDefinition.When.MARK:
			chain = candidate
			break
	if chain != null:
		state.marks[chain.entries[0].key] = 1
		ui.menu.show_tab(GameMenu.Tab.JOURNAL)
		var text: String = ui.quest_page.shown_text()
		_check(text.contains(chain.title) and text.contains(chain.entries[0].text) and not text.contains(QuestPage.NOTHING_YET), "the chain shows once its first entry happened: " + text.left(80))
		state.marks.erase(chain.entries[0].key)
		ui.menu.show_tab(GameMenu.Tab.JOURNAL)
		_check(ui.quest_page.shown_text() == text, "and stays when its mark is gone")
	# Carried items: a master form counts as the item, a book inside a carried case too.
	var floor: WorldMapFloorItems = (session.active_map() as WorldMapController).floor_items
	_check(not floor.give_new_item_to_player(&"es2:u/cloud/npc/obj/letter#master").is_empty() and not floor.give_new_item_to_player(&"es2:d/canyon/bamboo/obj/slipcase").is_empty(), "the letter and the case are carried")
	session.record_journal()
	_check(state.journal.has("cloud.wangyou_grass/letter") and state.known_items.has("es2:u/cloud/npc/obj/letter") and not state.known_items.has("es2:u/cloud/npc/obj/letter#master"), "the master letter records its entry under the letter's own ID")
	_check(state.journal.has("canyon.bamboo/slipcase") and state.journal.has("canyon.bamboo/book"), "the book in the case counts as carried: %s" % [state.journal.keys()])
	ui.menu.show_tab(GameMenu.Tab.CODEX)
	var codex: CodexPage = ui.codex_page
	_check(codex.is_visible_in_tree() and codex.current_section() == CodexContent.Section.LORE and codex.entry_buttons.size() == GameContent.catalog().codex_topics().size() and codex.entry_list.get_node_or_null("Group0") != null, "百科 opens on 江湖常识: %d" % codex.entry_buttons.size())
	# 界面重做 2: the list on the left, the entry read on the right; a section opens on its first.
	var first: String = codex.entries()[0].key
	_check(codex.open_key() == first and codex.entry_buttons[first].button_pressed and codex.article.visible and codex.shown_text().begins_with(codex.entries()[0].title), "its first entry is read at once: " + codex.shown_text().left(40))
	codex.entry_buttons["guide.health"].pressed.emit()
	_check(codex.open_key() == "guide.health" and codex.shown_text().begins_with("精气神") and codex.shown_text().contains("当前") and codex.list_scroll.visible and codex.entry_buttons["guide.health"].button_pressed and not codex.entry_buttons[first].button_pressed, "an entry is read beside the list: " + codex.shown_text().left(40))
	codex.entry_buttons["help.theme"].grab_focus()
	await tree.process_frame
	_check(codex.open_key() == "help.theme" and codex.entry_buttons["help.theme"].button_pressed, "moving onto an entry reads it")
	# Back / Esc close the menu as on every tab (the shell's, game_menu_test); it opens again
	# on the entry read.
	ui.menu.close()
	_check(not ui.menu.is_presented(), "the menu closes from 百科")
	ui.menu.open(GameMenu.Tab.CODEX)
	for i: int in 3:
		await tree.process_frame
	_check(codex.open_key() == "help.theme" and tree.root.gui_get_focus_owner() == codex.entry_buttons["help.theme"], "back on the entry read")
	codex.section_buttons[CodexContent.Section.ARTS].pressed.emit()
	var learned: int = codex.entry_buttons.keys().filter(func(key: String) -> bool: return not key.begins_with("moves/")).size()
	_check(learned == state.skills.raw_skill_ids().size() and codex.entry_buttons.has("moves/race/human"), "武学: the skills learned (%d) and the 见识录 of one's own 拳脚: " % learned + codex.shown_text().left(40))
	codex.section_buttons[CodexContent.Section.ITEMS].pressed.emit()
	_check(not state.known_items.is_empty() and codex.entry_buttons.size() == state.known_items.size(), "物品: what was carried (%d)" % state.known_items.size())
	codex.section_buttons[CodexContent.Section.PEOPLE].pressed.emit()
	_check(codex.entry_buttons.size() == state.seen_npcs.size(), "人物: the people met (%d)" % state.seen_npcs.size())
	var stranger: NpcDefinition = GameContent.catalog().npc(&"green.npc.oldman2")
	_check(not codex.listed_titles().has(stranger.display_name) and not codex.entry_buttons.has(String(stranger.definition_id)), "someone not met is not listed")
	state.seen_npcs[String(stranger.definition_id)] = state.seen_npcs.size() + 1
	codex.fill(state)
	_check(codex.entry_buttons.has(String(stranger.definition_id)), "met: listed")
	codex.open_entry(String(stranger.definition_id))
	_check(codex.shown_text().begins_with(stranger.short_name()), "the person's entry: " + codex.shown_text().left(40))
	# 百科重写: a skill's entry leads with what it is; a family's with its intro, its head only once met.
	codex.section_buttons[CodexContent.Section.ARTS].pressed.emit()
	var skill: SkillDefinition = GameContent.catalog().skill(&"liuh-ken")
	state.skills.set_raw_level(skill.skill_id, 1)
	codex.fill(state)
	codex.open_entry(String(skill.skill_id))
	_check(not skill.summary.is_empty() and codex.shown_text().split("\n")[1] == skill.summary, "武学: the skill's summary first: " + codex.shown_text().left(60))
	var fonxan: FamilyDefinition = GameContent.catalog().family(&"family.fonxan")
	var head: NpcDefinition = GameContent.catalog().npc(fonxan.head_id)
	state.seen_npcs.erase(String(fonxan.head_id))
	var disciple: NpcDefinition = null
	for npc: NpcDefinition in GameContent.catalog().npcs():
		if npc.definition_id != fonxan.head_id and CodexContent._family_of(npc, GameContent.catalog()) == fonxan:
			disciple = npc
			break
	state.seen_npcs[String(disciple.definition_id)] = state.seen_npcs.size() + 1
	codex.section_buttons[CodexContent.Section.FAMILIES].pressed.emit()
	codex.open_entry(String(fonxan.family_id))
	var before: String = codex.shown_text()
	_check(before.contains(fonxan.intro) and not before.contains(head.short_name() + "，在"), "门派: the intro once a disciple is met, not the head: " + before.left(80))
	state.seen_npcs[String(fonxan.head_id)] = state.seen_npcs.size() + 1
	codex.fill(state)
	_check(codex.shown_text().contains("为首的是%s，在%s。" % [head.short_name(), fonxan.seat]), "and the head with their seat once met: " + codex.shown_text().left(120))
	ui.menu.close()
	session.queue_free()
	await tree.process_frame


## 打听 through the real ask: an answer is recorded, an NPC out cold records nothing; the
## entries and the items carried come back exactly after Save/Continue.
func _test_ask_and_continue(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	await tree.process_frame
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "to the square")
	await tree.process_frame
	# The 书院 is its own map (snow.academy) since the remap: place the player beside 魏无极 there.
	var map: WorldMapController = MapPlaces.enter(session, &"snow.school", &"snow.school.teacher.1")
	_check(map != null, "beside 魏无极")
	await tree.physics_frame
	await tree.physics_frame
	# The teacher's own point is behind the desk since the remap (not a place a player can be
	# saved at): stand on the nearest free spot beside it.
	var beside: Vector2 = MapPlaces.spot(map, &"snow.school", map.resolve_spawn_marker(&"snow.school.teacher.1").global_position)
	_check(map.place_player(&"snow.school", beside), "standing beside 魏无极's desk")
	var teacher: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == &"snow.npc.teacher":
			teacher = npc
	var state: CharacterState = session.player_runtime().state
	map.select_npc(teacher.character_id)
	teacher.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: out cold
	map.ask_selected("学费")
	_check(not state.journal.has("snow.wei_wuji/asked_fee"), "an NPC out cold says nothing: nothing recorded")
	teacher.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_check(not map.ask_selected("学费").is_empty() and state.journal.has("snow.wei_wuji/asked_fee"), "asked and answered: recorded")
	session.record_journal()
	_check(state.known_items.has("es2:obj/cloth"), "the cloth worn is carried")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text)
	_check(decoded.succeeded() and decoded.snapshot.player.character.journal == state.journal and decoded.snapshot.player.character.known_items == state.known_items, "the save holds the entries and the items")
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "界面重构 C")
	_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))
	session.queue_free()
	await tree.process_frame


func _check(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)
