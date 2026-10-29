extends RefCounted

## 前两小时 C (owner, 2026-10-26; DECISIONS「雪亭驿的信」): 杜宽's errand end to end — the
## letter and the mark at 送信, 陈剑秋 takes the letter (and only the letter rule marks it),
## the one 两 of 脚钱 paid once, the guide chain's next steps and its 历练, 杜宽's other answers.

const POST_SPAWN: StringName = &"snow.postoffice_house.postoffice.post_officer"
const CHEN_SPAWN: StringName = &"cloud.biaoju_house.biaoju.b_header"
const LETTER: StringName = &"native:snow/letter_to_chen"
const SILVER: StringName = &"es2:obj/money/silver"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = await _session(tree)
	await _test_errand(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var post: NpcDefinition = catalog.npc(&"snow.npc.post_officer")
	_check(post.talk().inquiry_topics() == ["驿站", "悬赏", "送信"] and post.talk().answer("驿站").size() == 2 and post.talk().inquiry_rules("送信").size() == 4, "杜宽: 驿站 with its second line, 送信 by four rules, 悬赏")
	var letter: ItemContentDefinition = catalog.item(LETTER)
	_check(letter != null and letter.display_name == "雪亭驿的书信" and letter.unit == "封", "the letter is a native item")
	var chain: JournalChainDefinition = null
	for candidate: JournalChainDefinition in catalog.journal_chains():
		if candidate.chain_id == &"snow.letter":
			chain = candidate
	_check(chain != null and chain.guide and chain.entries.size() == 3 and chain.entries[2].final, "the chain: three steps, a guide")
	_check(catalog.progression().reward_exp(ProgressionRules.Kind.CHAIN, 0, &"snow.letter") == 15, "its 历练 is one unit (100%)")


func _test_errand(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	await _stand_at(tree, session, POST_SPAWN)
	var map: WorldMapController = session.active_map() as WorldMapController
	var post: NpcRuntimeState = _npc_of(session, &"snow.npc.post_officer")
	_check(map.select_npc(post.character_id) and map.ask_topics_selected() == ["这里", "名字", "传闻", "驿站", "悬赏", "送信"], "杜宽 in reach: %s" % [map.ask_topics_selected()])
	var said: Array[String] = map.ask_selected("悬赏")
	_check(said.size() == 2 and said[1].contains("乔阴府发的悬赏"), "悬赏: the board outside: %s" % [said])
	map.select_npc(post.character_id)
	said = map.ask_selected("送信")
	_check(said.size() == 3 and said[1].contains("回来给你一两脚钱") and said[2] == "杜宽给你一封雪亭驿的书信。", "送信: the errand and the letter: %s" % [said])
	_check(_carried(session, LETTER) == 1 and state.marks.get("雪亭驿的信", 0) == 1, "the letter in hand, marked")
	session.record_journal()
	_check(state.journal.has("snow.letter/taken") and JournalLog.objective(state, GameContent.catalog().journal_chains()).begins_with("出镇往南过卧龙岗"), "the chain opens with its next step")
	map.select_npc(post.character_id)
	said = map.ask_selected("送信")
	_check(said.size() == 2 and said[1].contains("信送到了么") and _carried(session, LETTER) == 1, "asked again: no second letter: %s" % [said])
	# 绮云镇: 陈剑秋 takes the letter; a dumpling he refuses as before.
	await _stand_at(tree, session, CHEN_SPAWN)
	map = session.active_map() as WorldMapController
	var chen: NpcRuntimeState = _npc_of(session, &"cloud.npc.b_header")
	_check(chen != null and map.select_npc(chen.character_id), "陈剑秋 in reach")
	var dumpling: StringName = map.give_new_item_to_player(&"es2:obj/example/dumpling")
	var refused: ItemHandlingResult = map.give_to_selected(dumpling)
	_check(refused.outcome != ItemHandlingResult.Outcome.DONE and not state.marks.has("信送到了"), "a dumpling: 你拿什么东西唬我, no mark: %s" % [refused.lines])
	var given: ItemHandlingResult = map.give_to_selected(_instance_of(session, LETTER))
	_check(given.outcome == ItemHandlingResult.Outcome.DONE and given.lines.any(func(line: String) -> bool: return line.contains("有劳小兄弟，替我谢谢杜驿长")), "the letter: taken with his thanks: %s" % [given.lines])
	_check(_carried(session, LETTER) == 0 and state.marks.get("信送到了", 0) == 1, "gone from the player, marked")
	session.record_journal()
	_check(state.journal.has("snow.letter/delivered") and JournalLog.objective(state, GameContent.catalog().journal_chains()) == "回雪亭驿找杜宽拿脚钱。", "next: back for the 脚钱")
	# Back at the post office: one 两, once.
	await _stand_at(tree, session, POST_SPAWN)
	map = session.active_map() as WorldMapController
	post = _npc_of(session, &"snow.npc.post_officer")
	var silver_before: int = _carried(session, SILVER)
	var rewards_before: int = _rewards(session).size()
	map.select_npc(post.character_id)
	said = map.ask_selected("送信")
	_check(said.size() == 3 and said[1].contains("说好的脚钱") and said[2] == "杜宽给你一些银子。", "paid: %s" % [said])
	_check(_carried(session, SILVER) == silver_before + 1 and state.marks.get("脚钱", 0) == 1, "one 两 of silver, marked")
	session.record_journal()
	session.record_journal()
	# The first arrival in 绮云镇 also ended the 新手链: only this chain's line is looked at.
	var lines: Array[String] = _rewards(session).slice(rewards_before).filter(func(line: String) -> bool: return line.contains("雪亭驿的信"))
	_check(state.journal.has("snow.letter/paid") and lines.size() == 1 and lines[0].begins_with("【历练】你了结了「雪亭驿的信」"), "the chain seen through, once: %s" % [lines])
	# Both guide chains are seen through (the 新手链 ended with the first arrival in 绮云镇): no 目标.
	_check(JournalLog.objective(state, GameContent.catalog().journal_chains()) == "" and JournalLog.finished(state, _chain(&"snow.newcomer")), "no next step left: " + JournalLog.objective(state, GameContent.catalog().journal_chains()))
	ui.refresh_exploration()
	# 任务系统: the main quest 寻剑令 (begun with the waiter met, never followed here) still holds the row; no 建议 is left.
	_check(ui.player_objective.text == "目标：跟店小二打听广场上的「官爷」。" and not ui.player_advice.visible, "the 目标 row is the main quest's alone: " + ui.player_objective.text)
	map.select_npc(post.character_id)
	said = map.ask_selected("送信")
	_check(said.size() == 2 and said[1].contains("往后有信，还找你") and _carried(session, SILVER) == silver_before + 1, "asked again: no second payment: %s" % [said])
	_check(ui.log_lines().has("【见闻】杜宽付了你一两脚钱，说往后有信还找你。"), "told")


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("信差", CharacterState.GENDER_MALE)
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


func _carried(session: WorldSessionController, item_definition_id: StringName) -> int:
	var count: int = 0
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.item_definition_id == item_definition_id:
			count += row.amount
	return count


func _instance_of(session: WorldSessionController, item_definition_id: StringName) -> StringName:
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.item_definition_id == item_definition_id:
			return row.item_instance_id
	return &""


func _rewards(session: WorldSessionController) -> Array[String]:
	var lines: Array[String] = []
	for line: String in session.shared_ui().log_lines():
		if line.begins_with("【历练】"):
			lines.append(line)
	return lines


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
