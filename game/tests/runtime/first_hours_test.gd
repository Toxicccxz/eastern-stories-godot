extends RefCounted

## 前两小时 A + B (owner, 2026-10-26; DECISIONS「新手链与当前目标」「客栈的老鼠」「开场卡片」):
## the journal's new conditions, a guide chain's `next` on the status card and in the
## toasts (off with 目标提示), the 老鼠 errand end to end (the spawn's cleared mark, 店小二's
## three answers, the 烤鸡腿), 打坐's 历练 steps, the 拜师 card, the opening card over
## New Game, the 角色 page's 历练 block, and the settings file's sixth version.

const ShellTests := preload("res://tests/application/application_shell_test.gd")
const SHELL_SCENE: PackedScene = preload("res://scenes/application/application_shell.tscn")

const WAITER_SPAWN: StringName = &"snow.inn.waiter"
const RATS_SPAWN: StringName = &"snow.inn_upstairs.inn_2f.rats"
const MASTER_SPAWN: StringName = &"snow.school_compound.schoolhall.master"
const CHICKEN_LEG: StringName = &"es2:obj/example/chicken_leg"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_journal_rules()
	_test_data()
	_test_settings()
	await _test_opening_through_shell(tree)
	var session: WorldSessionController = await _session(tree, true)
	await _test_opening_card(tree, session)
	await _test_newcomer_and_errand(tree, session)
	_test_force_milestones(session)
	await _test_apprentice_card(tree, session)
	_test_sheet(session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _chain(record: Dictionary, errors: Array[String]) -> JournalChainDefinition:
	return JournalChainDefinition.from_record(ContentRecordReader.new(record, "test", errors))


## The new conditions read the character's state; a guide chain's newest entry says what
## comes next until the chain is seen through; `next` belongs to guide chains alone.
func _test_journal_rules() -> void:
	var errors: Array[String] = []
	var guide: JournalChainDefinition = _chain({
		"id": "t.guide", "title": "引路", "region": "某地", "guide": true,
		"entries": [
			{"id": "won", "when": {"milestone": "spar/t.npc"}, "text": "胜过", "next": "去打坐"},
			{"id": "force", "when": {"force_at_least": 10}, "text": "内力十", "next": "再练"},
			{"id": "exp", "when": {"exp_at_least": 150}, "text": "经验", "next": "去远处"},
			{"id": "skill", "when": {"skill_at_least": {"skill": "sword", "level": 2}}, "text": "剑二", "next": "切磋"},
			{"id": "family", "when": {"family": "family.fonxan"}, "text": "入门", "next": "请教"},
			{"id": "end", "final": true, "when": {"mark": "done"}, "text": "完"},
		],
	}, errors)
	var plain: JournalChainDefinition = _chain({"id": "t.plain", "title": "平", "region": "别处", "entries": [{"id": "a", "when": {"mark": "n"}, "text": "甲"}]}, errors)
	_check(errors.is_empty() and guide.guide and guide.entries.size() == 6 and guide.entries[0].when == JournalEntryDefinition.When.MILESTONE and guide.entries[3].key == "sword" and guide.entries[3].amount == 2, "the guide chain reads: %s" % [errors])
	errors.clear()
	_chain({"id": "t.bad", "title": "坏", "region": "某地", "entries": [{"id": "a", "when": {"mark": "m"}, "text": "甲", "next": "乙"}]}, errors)
	_check(not errors.is_empty(), "`next` on a chain that is no guide is refused")
	errors.clear()
	_chain({"id": "t.bad", "title": "坏", "region": "某地", "guide": true, "entries": [{"id": "a", "when": {"force_at_least": 0}, "text": "甲"}]}, errors)
	_check(not errors.is_empty(), "force_at_least 0 is refused")
	var chains: Array[JournalChainDefinition] = [guide, plain]
	var state := CharacterState.new()
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	_check(JournalLog.record_entries(state, temps, held, chains).is_empty() and JournalLog.objective(state, chains) == "", "nothing yet: no objective")
	state.marks["n"] = 1
	JournalLog.record(state, temps, held, chains)
	_check(JournalLog.objective(state, chains) == "", "a plain chain's entry says nothing")
	state.milestones["spar/t.npc"] = 1
	var fresh: Array[JournalLog.Fresh] = JournalLog.record_entries(state, temps, held, chains)
	_check(fresh.size() == 1 and fresh[0].chain == guide and fresh[0].entry.entry_id == &"won", "a milestone records its entry")
	_check(JournalLog.objective(state, chains) == "去打坐", "the newest guide entry's next is the objective")
	var told: Array[String] = ColoredLine.texts(JournalLog.told_lines(fresh[0], true))
	_check(told == ["【见闻】胜过", "下一步：去打坐"], "told with its next: %s" % [told])
	_check(ColoredLine.texts(JournalLog.told_lines(fresh[0], false)) == ["【见闻】胜过"], "目标提示 off: the entry alone")
	state.recovery.inner_force.maximum = 10
	state.progression.combat_experience = 149
	state.skills.set_raw_level(&"sword", 1)
	JournalLog.record(state, temps, held, chains)
	_check(state.journal.has("t.guide/force") and not state.journal.has("t.guide/exp") and not state.journal.has("t.guide/skill"), "max_force 10 counts; 149 exp and sword 1 do not: %s" % [state.journal])
	state.progression.combat_experience = 150
	state.skills.set_raw_level(&"sword", 2)
	state.family.family_id = &"family.fonxan"
	JournalLog.record(state, temps, held, chains)
	_check(state.journal.has("t.guide/exp") and state.journal.has("t.guide/skill") and state.journal.has("t.guide/family"), "exp, skill and family record: %s" % [state.journal])
	_check(JournalLog.objective(state, chains) == "请教", "the last recorded in one look is the newest")
	state.marks["done"] = 1
	JournalLog.record(state, temps, held, chains)
	_check(JournalLog.objective(state, chains) == "", "seen through: no objective")


## The data: the 新手链 is a guide over 雪亭镇, 魏无极's one native line, the waiter's goods
## as waiter.c has them, the 烤鸡腿 leaving a bone, the rats' cleared mark, 打坐's steps.
func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var newcomer: JournalChainDefinition = null
	for chain: JournalChainDefinition in catalog.journal_chains():
		if chain.chain_id == &"snow.newcomer":
			newcomer = chain
	_check(newcomer != null and newcomer.guide and newcomer.entries.size() == 13 and newcomer.entries[-1].final and newcomer.entries[-1].next.is_empty(), "the 新手链: a guide chain of 13, the last final")
	var fee: PackedStringArray = catalog.npc(&"snow.npc.teacher").talk().answer("学费")
	_check(fee.size() == 6 and fee[4] == "只要五两银子。" and fee[5] == "手头紧？街东头的谷场正缺短工，干一回给一两。", "魏无极's 学费: ES2's five lines, then the native one: %s" % [fee])
	_check(catalog.vendor(&"snow.vendor.waiter").goods_keys() == ["dagger", "wineskin", "dumpling", "chicken leg"], "waiter.c's four goods: %s" % [catalog.vendor(&"snow.vendor.waiter").goods_keys()])
	var leg: ItemContentDefinition = catalog.item(CHICKEN_LEG)
	_check(leg != null and leg.display_name == "烤鸡腿" and not leg.leftover_id().is_empty() and catalog.item(leg.leftover_id()).aliases().has("bone"), "chicken_leg.c: food that leaves a bone")
	_check(catalog.spawn(RATS_SPAWN).cleared_mark == "客栈老鼠" and catalog.spawn(WAITER_SPAWN).cleared_mark.is_empty(), "the rats' spawn carries the cleared mark")
	_check(catalog.progression().force_milestones == [10, 25, 50] and catalog.progression().reward_exp(ProgressionRules.Kind.FORCE, 0) == 3, "打坐's steps: 25% of the unit (15 → 3)")
	_check(catalog.opening() != null and catalog.opening().paragraphs.size() == 9 and OpeningDefinition.card_text(catalog.opening()).ends_with("那少年，便是你。"), "the opening: the theme story and the closing line")
	var waiter: NpcDefinition = catalog.npc(&"snow.npc.waiter")
	_check(waiter.talk().inquiry_topics().has("老鼠") and waiter.talk().inquiry_topics().has("楼上") and waiter.talk().inquiry_rules("楼上").size() == 3, "店小二 answers 老鼠 and 楼上 by three rules")


## Settings schema 6: 目标提示 is kept; a version 5 file reads as on; applying sets ObjectiveHints.
func _test_settings() -> void:
	var files := ShellTests.MemoryFiles.new()
	var repository := ApplicationSettingsRepository.new(files)
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=5\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\nafter_knockout=\"finish\"\n".to_utf8_buffer()
	var old: ApplicationSettingsResult = repository.load()
	_check(old.succeeded() and old.snapshot().objective_hints() and old.snapshot().after_knockout() == BattlePace.AfterKnockout.FINISH, "a version 5 file: 目标提示 on, the rest kept")
	var written: ApplicationSettingsResult = repository.write(old.snapshot().with_objective_hints(false))
	var back: ApplicationSettingsResult = repository.load()
	_check(written.succeeded() and back.succeeded() and back.snapshot().version() == ApplicationSettingsSnapshot.SCHEMA_VERSION and not back.snapshot().objective_hints(), "written and read back: off")
	_check(files.files[ApplicationSettingsRepository.SETTINGS_PATH].get_string_from_utf8().contains("objective_hints=false"), "stored")
	files.files[ApplicationSettingsRepository.SETTINGS_PATH] = "[application]\nschema_version=6\nwindow_mode=\"windowed\"\nlanguage=\"\"\nbattle_speed=\"fast\"\nhit_flash=false\nui_scale=125\nafter_knockout=\"finish\"\n".to_utf8_buffer()
	_check(repository.load().outcome() == ApplicationSettingsResult.Outcome.INVALID_SETTINGS, "a version 6 file without it is refused")
	ApplicationSettingsService._apply_battle(back.snapshot())
	_check(not ObjectiveHints.shown, "applied")
	ApplicationSettingsService._apply_battle(ApplicationSettingsSnapshot.defaults())
	_check(ObjectiveHints.shown and BattlePace.after_knockout == BattlePace.AfterKnockout.ASK, "on by default")


## The game's own New Game (the shell and its host): the card comes up over the world; the
## host's switch (the suites' fixture turns it off) leaves it out.
func _test_opening_through_shell(tree: SceneTree) -> void:
	for with_card: bool in [true, false]:
		var shell: ApplicationShellController = SHELL_SCENE.instantiate()
		_check(shell.configure_before_start(GameSaveStorageProfile.isolated_test("first-hours-%s" % with_card), ShellTests.MemoryFiles.new(), null, ShellTests.MemoryFiles.new()), "shell configures")
		tree.root.add_child(shell)
		await _frames(tree, 3)
		shell.runtime_host().opening_card = with_card
		_check(shell.request_new_game_from_menu(), "New Game")
		shell.player_name_edit.text = "开场"
		shell.select_new_game_gender(CharacterState.GENDER_FEMALE)
		_check(shell.submit_new_game_setup(), "the journey starts")
		await _frames(tree, 3)
		if shell.shell_state().mode() == ApplicationShellState.Mode.RESULT:
			shell.confirm_current_result()
			await _frames(tree, 3)
		var session: WorldSessionController = shell.runtime_host().current_session()
		_check(session != null and session.shared_ui() != null, "playing (card %s)" % with_card)
		if session != null and session.shared_ui() != null:
			var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
			_check(overlay.card_shown() == with_card and session.world_time_held() == with_card, "the host asks for the card: %s; world time held: %s" % [overlay.card_shown(), session.world_time_held()])
			if with_card:
				_check(overlay.text().ends_with("那少年，便是你。"), "the theme story's card over the first moment")
				overlay.go_on()
				await _frames(tree, 2)
				_check(not session.world_time_held(), "继续 lets the world run")
		shell.queue_free()
		await tree.process_frame


## New Game asked for by the host: the theme story's card is up, blocking, world time held;
## 继续 takes it away and lets time run.
func _test_opening_card(tree: SceneTree, session: WorldSessionController) -> void:
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	_check(overlay != null and overlay.card_shown() and overlay.is_blocking(), "the opening card is up")
	_check(overlay.text().begins_with("东方故事") and overlay.text().contains("黄石隘口") and overlay.text().ends_with("那少年，便是你。"), "the theme story, then the closing line: " + overlay.text().left(40))
	_check(session.world_time_held() and not session.opening_card_due(), "world time stands still under it; the card was taken")
	overlay.go_on()
	await tree.process_frame
	_check(not overlay.card_shown() and not overlay.visible and not session.world_time_held(), "继续: gone, time runs")
	# A fall or a death puts a waiting card away; here nothing else is waiting.
	overlay.show_card("")
	await tree.process_frame
	_check(not overlay.visible, "an empty card shows nothing")


## The 新手链's first steps in the world: meeting the waiter opens it (a toast with 下一步,
## the 目标 row), 楼上 records the errand, knocking the six rats down sets the mark, and
## the waiter's three answers: the errand, the thanks with the 烤鸡腿 once, the bone hint.
func _test_newcomer_and_errand(tree: SceneTree, session: WorldSessionController) -> void:
	var ui: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	for pulse: int in 3:
		session.advance_npc_heartbeat(2.0)
	await _settle(tree)
	if not state.seen_npcs.has("snow.npc.waiter"):
		# The player is born beside him; the greeting beat lists him. TEST-ONLY when the frames did not.
		PlayerEssenceMagic.meet(state, _npc_of(session, &"snow.npc.waiter"), false)
	session.record_journal()
	_check(state.journal.has("snow.newcomer/woke"), "meeting the waiter opens the 新手链: %s" % [state.journal])
	var log: Array[String] = ui.log_lines()
	_check(log.has("【见闻】你在饮风客栈醒来，店小二笑着招呼了你。") and log.has("下一步：跟店小二打听「楼上」。"), "told once, with its next: %s" % [log.slice(maxi(0, log.size() - 4))])
	ui.refresh_exploration()
	# 任务系统: the main quest 寻剑令 began with the waiter met and holds the 目标 row; the 新手链 is the 建议.
	_check(ui.player_objective.visible and ui.player_objective.text == "目标：跟店小二打听广场上的「官爷」。" and ui.player_advice.visible and ui.player_advice.text == "建议：跟店小二打听「楼上」。", "the 目标 row and the 建议 row: %s / %s" % [ui.player_objective.text, ui.player_advice.text])
	ObjectiveHints.shown = false
	ui.refresh_exploration()
	_check(not ui.player_objective.visible and not ui.player_advice.visible, "目标提示 off: no row")
	ObjectiveHints.shown = true
	await _stand_at(tree, session, WAITER_SPAWN)
	var map: WorldMapController = session.active_map() as WorldMapController
	var waiter: NpcRuntimeState = _npc_of(session, &"snow.npc.waiter")
	_check(map.select_npc(waiter.character_id) and map.ask_topics_selected().has("楼上"), "店小二 in reach, 楼上 to ask")
	var said: Array[String] = map.ask_selected("楼上")
	_check(said.size() == 2 and said[1].contains("楼上几间客房闹老鼠") and said[1].contains("这位小兄弟要是"), "the errand, $RESPECT as the waiter addresses the player: %s" % [said])
	_check(state.journal.has("snow.newcomer/errand"), "recorded at the ask")
	ui.refresh_exploration()
	_check(ui.player_advice.text == "建议：上楼收拾老鼠。", "the next step: " + ui.player_advice.text)
	_check(not state.marks.has("客栈老鼠"), "the rats still stand")
	var upstairs: WorldMapController = session.resident_map(&"snow.inn_upstairs") as WorldMapController
	var rats: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in upstairs.npc_runtimes():
		if npc.spawn_id == RATS_SPAWN:
			rats.append(npc)
	_check(rats.size() == 6, "six rats upstairs")
	for index: int in 5:
		rats[index].set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: knocked down
	session.record_journal()
	_check(not state.marks.has("客栈老鼠"), "five down: not yet")
	rats[5].set_life_status(CharacterRuntimeLifeStatus.Value.DEAD) # TEST-ONLY: the last one killed
	session.record_journal()
	_check(state.marks.get("客栈老鼠", 0) == 1 and state.journal.has("snow.newcomer/rats"), "all six down: the mark, and the entry")
	ui.refresh_exploration()
	_check(ui.player_advice.text == "建议：下楼找店小二。", "back to the waiter: " + ui.player_advice.text)
	# The HUD's refresh let the selection go; the player clicks him again.
	map.select_npc(waiter.character_id)
	said = map.ask_selected("老鼠")
	_check(said.size() == 4 and said[1].contains("可算清净了") and said[2].contains("骨头别扔") and said[3] == "店小二给你一根烤鸡腿。", "the thanks and the 烤鸡腿: %s" % [said])
	session.record_journal()
	_check(_carried(session, CHICKEN_LEG) == 1 and state.marks.get("店小二谢过", 0) == 1 and state.journal.has("snow.newcomer/thanked"), "one leg in hand, thanked, recorded: %d %s" % [_carried(session, CHICKEN_LEG), state.marks])
	map.select_npc(waiter.character_id)
	said = map.ask_selected("楼上")
	_check(said.size() == 2 and said[1].contains("骨头别扔") and _carried(session, CHICKEN_LEG) == 1, "asked again: the hint alone, no second leg: %s" % [said])
	ui.refresh_exploration()
	_check(ui.player_advice.text == "建议：去淳风武馆拜柳淳风为师。", "on to the 武馆: " + ui.player_advice.text)


## 打坐's steps (owner Q5): each max_force number first reached is a small 历练, once.
func _test_force_milestones(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var before: int = _rewards(session).size()
	state.recovery.inner_force.maximum = 25 # TEST-ONLY: as 打坐 would leave it
	session.record_journal()
	var lines: Array[String] = _rewards(session).slice(before)
	_check(lines.size() == 2 and lines[0].begins_with("【历练】你的内力练到了 10：实战经验 +") and lines[1].begins_with("【历练】你的内力练到了 25："), "10 and 25 at once, lowest first: %s" % [lines])
	_check(state.milestones.has("force/10") and state.milestones.has("force/25") and not state.milestones.has("force/50"), "written down")
	_check(state.journal.has("snow.newcomer/force_25"), "the 新手链 follows")
	session.record_journal()
	_check(_rewards(session).size() == before + 2, "once")
	state.recovery.inner_force.maximum = 50 # TEST-ONLY
	session.record_journal()
	_check(_rewards(session).size() == before + 3 and state.milestones.has("force/50"), "then 50")


## 拜师 taken: the card over the world names the master, the family and the generation.
func _test_apprentice_card(tree: SceneTree, session: WorldSessionController) -> void:
	await _stand_at(tree, session, MASTER_SPAWN)
	var map: WorldMapController = session.active_map() as WorldMapController
	var master: NpcRuntimeState = _npc_of(session, &"common.npc.swordsman.master")
	var service: TeacherService = null
	for candidate: WorldService in map.service_nodes:
		if candidate is TeacherService and master != null and (candidate as TeacherService).npc.character_id == master.character_id:
			service = candidate as TeacherService
	_check(service != null, "柳淳风 teaches in the 武馆")
	if service == null:
		return
	var overlay: PlayerLifeOverlay = session.shared_ui().life_overlay
	_check(not overlay.card_shown(), "no card before")
	_check(service.request_apprentice() == NpcApprenticeship.Outcome.RECRUITED, "a fresh 30/30 player is taken")
	await tree.process_frame
	_check(overlay.card_shown() and overlay.text().begins_with("柳淳风收下了你。") and overlay.text().contains("封山剑派第十四代弟子"), "the 拜师 card: " + overlay.text().left(40))
	overlay.go_on()
	await tree.process_frame
	session.record_journal()
	_check(state_of(session).journal.has("snow.newcomer/apprenticed") and JournalLog.objective(state_of(session), GameContent.catalog().journal_chains()) == "向柳淳风请教基本剑法。", "the 新手链 follows the family")


## The 角色 page's 历练 block: newest first, the birthplace as where the player was born.
func _test_sheet(session: WorldSessionController) -> void:
	var sheet := CharacterSheet.new()
	sheet.refresh(session.player_runtime(), session)
	var lines: PackedStringArray = sheet.milestones.text.split("\n")
	_check(lines[0] == "内力练到 50" and lines[-1] == "生在雪亭镇" and lines.has("内力练到 10"), "the block: %s" % [lines])
	var empty := CharacterState.new()
	_check(sheet.milestone_text(empty).begins_with("还没有历练"), "nothing yet: says so")


func _session(tree: SceneTree, opening: bool) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("新手", CharacterState.GENDER_MALE)
	if opening:
		session.request_opening_card()
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
	await _settle(tree)


func _frames(tree: SceneTree, count: int) -> void:
	for index: int in count:
		await tree.process_frame


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


static func state_of(session: WorldSessionController) -> CharacterState:
	return session.player_runtime().state


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
