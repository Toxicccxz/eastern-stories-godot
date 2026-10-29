extends RefCounted

## 主线 A (owner, 2026-10-29; DECISIONS「剧情演出」「老松寨的三条路」「安葬必得书」): the
## pieces the story's scenes are made of, as data — the `quest` condition, a spawn's
## `present` / `until`, a scene's calls and the `spared` hook, an act's `by` and `drop`,
## an answer's `asker_carries`, the toll with several marks and its parley, a trap's
## `unless_marks`, the bury landmark's mark, `with` and `teaches`, the two pacing knobs —
## and 伪墓 as loaded.

var _count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_quest_condition()
	_test_spawn_presence()
	_test_scene_calls_and_spared()
	_test_by_and_drop()
	_test_asker_carries()
	_test_toll_marks_and_parley()
	_test_trap_unless_marks()
	_test_bury_landmark()
	_test_pacing_knobs()
	_test_chapter1_data()
	return {"assertions": _count, "failures": _failures.duplicate()}


func _when(record: Dictionary) -> JournalEntryDefinition:
	var errors: Array[String] = []
	var definition := JournalEntryDefinition.new()
	JournalEntryDefinition.read_when(ContentRecordReader.new(record, "test", errors), definition)
	_check(errors.is_empty(), "a when reads: %s" % [errors])
	return definition


## `quest`: a ledger key, a branch step's by any of its options.
func _test_quest_condition() -> void:
	var state := CharacterState.new()
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	var started: JournalEntryDefinition = _when({"when": {"quest": "main.prologue#started"}})
	var square: JournalEntryDefinition = _when({"when": {"quest": "main.prologue/square"}})
	_check(started.when == JournalEntryDefinition.When.QUEST and started.key == "main.prologue#started", "the quest condition names a ledger key")
	_check(not JournalLog.holds(started, state, temps, held) and not JournalLog.holds(square, state, temps, held), "nothing in the ledger: neither holds")
	state.quests["main.prologue#started"] = 1
	state.quests["main.prologue/square/official"] = 2
	_check(JournalLog.holds(started, state, temps, held) and JournalLog.holds(square, state, temps, held), "the key, and the branch step through its option")
	_check(not JournalLog.holds(_when({"when": {"quest": "main.prologue/squared"}}), state, temps, held), "a longer key is another key")


## A spawn on the stage: present / until read as whens; neither summoned nor drawn.
func _test_spawn_presence() -> void:
	var errors: Array[String] = []
	var spawn: NpcSpawnDefinition = NpcContentRecords.spawn_from_record(ContentRecordReader.new({
		"id": "t.spawn", "npc": "t.npc", "map": "m", "zone": "z", "points": ["p1"], "legacy_room": "native", "legacy_quantity": 1,
		"present": {"quest": "q#started"}, "until": {"mark": "gone"},
	}, "test", errors))
	_check(errors.is_empty() and spawn.staged and spawn.starts_absent and not spawn.summoned, "present and until make a staged spawn, absent at the world's making: %s" % [errors])
	_check(spawn.present.when == JournalEntryDefinition.When.QUEST and spawn.until.when == JournalEntryDefinition.When.MARK and spawn.until.key == "gone", "its conditions")
	var plain: NpcSpawnDefinition = NpcContentRecords.spawn_from_record(ContentRecordReader.new({
		"id": "t.plain", "npc": "t.npc", "map": "m", "zone": "z", "points": ["p1"], "legacy_room": "r", "legacy_quantity": 1,
	}, "test", errors))
	_check(errors.is_empty() and not plain.staged and not plain.starts_absent, "a spawn without them is there from the start")
	NpcContentRecords.spawn_from_record(ContentRecordReader.new({
		"id": "t.bad", "npc": "t.npc", "map": "m", "zone": "z", "points": ["p1"], "legacy_room": "r", "legacy_quantity": 1,
		"summoned": true, "present": {"mark": "x"},
	}, "test", errors))
	_check(errors.size() == 1 and errors[0].contains("present"), "a summoned spawn is not on the stage: %s" % [errors])
	errors.clear()
	var item: ItemSpawnDefinition = ItemSpawnDefinition.from_record(ContentRecordReader.new({
		"id": "t.item", "item": "t:thing", "map": "m", "zone": "z", "points": ["p1"], "legacy_room": "native", "legacy_quantity": 1,
		"present": {"quest": "q/step"},
	}, "test", errors))
	_check(errors.is_empty() and item.staged and item.present.key == "q/step" and item.until == null, "an item spawn on the stage: %s" % [errors])


## A scene's calls are told lines; `spared` names a mood of its own or a mark.
func _test_scene_calls_and_spared() -> void:
	var errors: Array[String] = []
	var hooks: NpcHooks = NpcHooks.from_record(ContentRecordReader.new({
		"calls": [
			{"after": 1, "scene": true, "not_mark": "seen", "steps": [{"say": "一"}]},
			{"after": 5, "steps": [{"say": "二"}]},
		],
		"moods": {"fled": {"title": "逃了", "lasting": true}},
		"spared": {"mood": "fled", "mark": "放过了"},
	}, "test", errors))
	_check(errors.is_empty() and hooks != null and hooks.calls.size() == 2, "hooks read: %s" % [errors])
	_check(hooks.calls[0].scene and hooks.calls[0].hurry and not hooks.calls[1].scene and not hooks.calls[1].hurry, "a scene call is a told line (hurry); the other is as written")
	_check(hooks.has_spared() and hooks.spared_mood == "fled" and hooks.spared_mark == "放过了", "spared: the mood and the mark")
	NpcHooks.from_record(ContentRecordReader.new({"spared": {"mood": "angry"}}, "test", errors))
	_check(errors.size() == 1 and errors[0].contains("spared"), "a mood it has not is refused: %s" % [errors])
	errors.clear()
	NpcHooks.from_record(ContentRecordReader.new({"spared": {}}, "test", errors))
	_check(errors.size() == 1, "an empty spared is refused")
	errors.clear()
	var marked: NpcHooks = NpcHooks.from_record(ContentRecordReader.new({"spared": {"mark": "m"}}, "test", errors))
	_check(errors.is_empty() and marked.spared_mood.is_empty() and marked.spared_mark == "m", "a mark alone")


## `by` hands the act to another NPC standing by; `drop` lays an item at its feet.
func _test_by_and_drop() -> void:
	var errors: Array[String] = []
	var act: ScriptedAct = ScriptedAct.from_record(ContentRecordReader.new({"steps": [
		{"line": "一道黑影掠下。"}, {"by": "t.taoist"}, {"say": "多谢。"}, {"drop": "t:strip"}, {"leave": true},
	]}, "test", errors))
	_check(errors.is_empty() and act.steps.size() == 5, "the act reads: %s" % [errors])
	_check(act.steps[1].kind == ScriptedAct.Kind.BY and act.steps[1].npc_id == &"t.taoist", "by names the NPC")
	_check(act.steps[3].kind == ScriptedAct.Kind.DROP and act.steps[3].item_id == &"t:strip", "drop names the item")
	ScriptedAct.from_record(ContentRecordReader.new({"steps": [{"by": "a", "drop": "b"}]}, "test", errors))
	_check(not errors.is_empty(), "a step does one thing")


## An answer for one who carries something.
func _test_asker_carries() -> void:
	var errors: Array[String] = []
	var rule: NpcInquiryRule = NpcInquiryRule.from_record(ContentRecordReader.new({"asker_carries": "letter", "say": "信我看了。"}, "test", errors))
	_check(errors.is_empty() and rule.asker_carries == "letter", "asker_carries reads: %s" % [errors])
	_check(not rule.matches({}, &"", &"", 0, {}, []) and rule.matches({}, &"", &"", 0, {}, ["letter", "sword"]), "only with the thing in hand")
	var plain: NpcInquiryRule = NpcInquiryRule.from_record(ContentRecordReader.new({"say": "嗯。"}, "test", errors))
	_check(plain.matches({}, &"", &"", 0, {}, []), "a rule without it asks nothing of what is carried")
	var chosen: NpcInquiryRule = NpcInquiryRule.decide([rule, plain], {}, null, &"", &"", 0, {}, ["letter"])
	_check(chosen == rule and NpcInquiryRule.decide([rule, plain], {}, null, &"", &"", 0, {}, []) == plain, "decide takes what is carried into account")


## A toll spared by any of several marks; a parleying toll-taker is plain aggressive with
## the parley off (经典), and does not go berserk either way.
func _test_toll_marks_and_parley() -> void:
	var errors: Array[String] = []
	var npc: NpcDefinition = NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.guard", "legacy_source": "t/guard.c", "name": "喽罗", "aliases": ["guard"], "gender": "男性", "age": 30, "attitude": "heroism",
		"skills": {"parry": 5}, "attack_unless_marks": ["过路钱", "叫阵"], "parley": true, "toll_attack_delay_ms": 8000,
		"chat_chance": 1, "chat_msg": ["站住！\n"], "toll_shout": 0,
	}, "test", errors))
	_check(errors.is_empty() and npc != null and npc.dealings().attack_unless_marks == ["过路钱", "叫阵"] and npc.dealings().parley, "the toll's marks and its parley: %s" % [errors])
	var state := CharacterState.new()
	var flags: Dictionary[StringName, bool] = {}
	_check(npc.attacks_on_sight(flags, state, true) and npc.toll_attack_delay_ms(flags, state, true) == 8000, "no mark: it attacks, after its toll delay")
	state.marks["叫阵"] = 1
	_check(not npc.attacks_on_sight(flags, state, true), "either mark spares the player")
	state.marks.erase("叫阵")
	state.marks["过路钱"] = 1
	_check(not npc.attacks_on_sight(flags, state, true), "the other mark too")
	_check(npc.attacks_on_sight(flags, state, false) and npc.toll_attack_delay_ms(flags, state, false) == 0, "经典 (the parley off): plain aggressive, at once, mark or not")
	flags[NpcDefinition.FLAG_FOUGHT_PLAYER] = true
	_check(npc.attacks_on_sight(flags, state, true), "having fought the player it attacks on sight, as a toll-taker does")
	var one: NpcDefinition = NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.robber", "legacy_source": "t/robber.c", "name": "强盗", "aliases": ["robber"], "gender": "男性", "age": 30, "attitude": "heroism",
		"skills": {"parry": 5}, "attack_unless_mark": "强盗",
	}, "test", errors))
	_check(errors.is_empty() and one.dealings().attack_unless_marks == ["强盗"] and not one.dealings().parley, "attack_unless_mark alone, as cloud's robbers have it")
	_check(one.attacks_on_sight({}, CharacterState.new(), false), "without a parley the knob changes nothing")
	NpcContentRecords.npc_from_record(ContentRecordReader.new({
		"id": "t.x", "legacy_source": "t/x.c", "name": "x", "aliases": ["x"], "gender": "男性", "age": 30, "skills": {"parry": 5}, "parley": true,
	}, "test", errors))
	_check(errors.size() == 1 and errors[0].contains("parley"), "only a toll-taker parleys: %s" % [errors])


func _test_trap_unless_marks() -> void:
	var errors: Array[String] = []
	var trap: RoomTrapDefinition = RoomTrapDefinition.from_record(ContentRecordReader.new({
		"id": "t.trap", "room": "r", "door": "d", "from_zone": "a", "to_zone": "b", "unless_marks": ["过路钱", "叫阵"],
		"messages": {"shout": "1", "shut": "2", "open": "3"}, "legacy_source": "s",
	}, "test", errors))
	_check(errors.is_empty() and trap.unless_marks == ["过路钱", "叫阵"], "the trap's unless_marks: %s" % [errors])
	var plain: RoomTrapDefinition = RoomTrapDefinition.from_record(ContentRecordReader.new({
		"id": "t.trap2", "room": "r", "door": "d", "from_zone": "a", "to_zone": "b",
		"messages": {"shout": "1", "shut": "2", "open": "3"}, "legacy_source": "s",
	}, "test", errors))
	_check(errors.is_empty() and plain.unless_marks.is_empty(), "none by default")


func _test_bury_landmark() -> void:
	var errors: Array[String] = []
	var wall: WorldLandmarkDefinition = WorldLandmarkDefinition.from_record(ContentRecordReader.new({
		"id": "t.wall", "zone": "z", "name": "石壁", "long": "字", "action": "埋葬骸骨", "policy": "bury", "portals": ["p"],
		"mark": "安葬", "teaches": ["看过"], "items": {"buried": "bones", "reward": "book", "with": "token"},
		"messages": {"bury": "1", "book": "2", "paper": "3", "fall": "4"}, "legacy_source": "s",
	}, "test", errors))
	_check(errors.is_empty() and wall.mark == "安葬" and wall.teaches == ["看过"] and wall.item("with") == &"token", "a bury landmark with a mark, teaches and a thing buried with: %s" % [errors])
	var bare: WorldLandmarkDefinition = WorldLandmarkDefinition.from_record(ContentRecordReader.new({
		"id": "t.wall2", "zone": "z", "name": "石壁", "long": "字", "action": "埋葬骸骨", "policy": "bury", "portals": ["p"],
		"items": {"buried": "bones", "reward": "book"},
		"messages": {"bury": "1", "book": "2", "paper": "3", "fall": "4"}, "legacy_source": "s",
	}, "test", errors))
	_check(errors.is_empty() and bare.mark.is_empty() and bare.item("with").is_empty(), "as before without them")
	WorldLandmarkDefinition.from_record(ContentRecordReader.new({
		"id": "t.vine", "zone": "z", "name": "藤", "long": "l", "action": "抓", "policy": "vine", "portals": ["p", "q"], "teaches": ["x"],
		"messages": {"hold": "1", "fall": "2"}, "legacy_source": "s",
	}, "test", errors))
	_check(not errors.is_empty() and errors.any(func(e: String) -> bool: return e.contains("teaches")), "a vine teaches nothing: %s" % [errors])


func _test_pacing_knobs() -> void:
	var errors: Array[String] = []
	var es2: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000}, "p", errors))
	_check(errors.is_empty() and not es2.story_parley and not es2.bury_always_rewards, "left out (经典): no parley, the burial rolls")
	var ours: PacingDefinition = PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "story_parley": true, "bury_always_rewards": true}, "p", errors))
	_check(errors.is_empty() and ours.story_parley and ours.bury_always_rewards and ours.copy().story_parley and ours.copy().bury_always_rewards, "set, and kept by copy()")
	var production: PacingDefinition = GameContent.catalog().pacing()
	_check(production.story_parley and production.bury_always_rewards, "the game's pacing has both on")


## 伪墓 as loaded: after 寻剑令, on the strip; its steps and branches; 寻剑令's new steps.
func _test_chapter1_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter1")
	_check(quest != null and quest.title == "伪墓" and quest.line == "main" and quest.requires == [&"main.prologue"], "伪墓 is the main line after 寻剑令")
	if quest == null:
		return
	_check(quest.starts.when == JournalEntryDefinition.When.ITEM and quest.starts.key == "native:oldpine/cloth_strip", "it begins with the strip in hand")
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> String: return String(step.step_id))
	_check(ids == ["trail", "gate", "boss", "cave", "taoist", "wall", "bones"], "the steps: %s" % [ids])
	_check(quest.steps[1].is_branch() and quest.steps[1].options.size() == 3 and quest.steps[1].options[2].condition.key == "defeat/oldpine.npc.bandit_guard", "the gate: pay, challenge or force")
	_check(quest.steps[2].is_branch() and quest.steps[2].options[0].condition.when == JournalEntryDefinition.When.HEARD and quest.steps[2].options[1].condition.key == "defeat/oldpine.npc.bandit_commander", "常老大: asked or beaten")
	_check(quest.steps[6].is_branch() and quest.steps[6].options[0].condition.key == "安葬无名人" and quest.steps[6].options[1].condition.key == "native:waterfog/guild_token" and quest.steps[6].options[1].reward.marks == ["带走腰牌"], "the bones: buried or the token taken")
	_check(quest.reward.milestone and not quest.reward.deed.is_empty(), "a 历练 and a deed at the end")
	var prologue: StoryQuestDefinition = catalog.story_quest(&"main.prologue")
	var prologue_ids: Array = prologue.steps.map(func(step: StoryQuestDefinition.Step) -> String: return String(step.step_id))
	_check(prologue_ids == ["waiter", "square", "pass", "scene", "strip"], "寻剑令 goes on to the scene and the strip: %s" % [prologue_ids])
	_check(catalog.npc(&"native.npc.bai_daozhang") != null and catalog.npc(&"native.npc.black_taoist") != null and catalog.npc(&"native.npc.black_taoist_pass") != null, "白道长 and the 黑衣道士 (twice)")
	var scene: NpcHooks = catalog.npc(&"native.npc.bai_daozhang").hooks()
	_check(scene != null and scene.calls.size() == 7 and scene.calls.all(func(call: NpcHooks.Call) -> bool: return call.scene and call.act.not_mark == "隘口的道士"), "白道长's seven scene calls, once")
	_check(catalog.npc(&"native.npc.black_taoist").hooks().spared_mark == "放过了黑衣道士" and catalog.npc(&"native.npc.black_taoist_pass").dealings().is_fight_deferred(), "the taoist spared leaves a mark; at the pass he cannot be fought")
	var pass_spawn: NpcSpawnDefinition = catalog.spawn(&"native.pass.bai_daozhang")
	_check(pass_spawn != null and pass_spawn.present.key == "main.prologue/square" and pass_spawn.until.key == "main.chapter1#started", "the pass crew come after the square and go once 伪墓 began")
	_check(catalog.spawn(&"native.square.feng_ce").until.key == "main.prologue/square", "the square's officials leave once asked")
	var cave: NpcSpawnDefinition = catalog.spawn(&"native.caves.black_taoist")
	_check(cave != null and cave.once and cave.present.key == "main.chapter1/boss" and cave.until.key == "defeat/native.npc.black_taoist", "the taoist waits in cave5 after 常老大, and is gone once beaten")
	_check(catalog.item_spawn(&"native.caves.cave5.guild_token").present.key == "main.chapter1#started", "the 腰牌 lies there from 伪墓's start")
	var wall: WorldLandmarkDefinition = catalog.landmark(&"oldpine.caves.landmark.wall")
	_check(wall.mark == "安葬无名人" and wall.teaches == ["看过石壁"] and wall.item("with") == &"native:waterfog/guild_token", "the wall teaches its clues and buries the token with the bones")
	var traps: Array = catalog.traps().filter(func(trap: RoomTrapDefinition) -> bool: return trap.trap_id == &"oldpine.keep2.gate_trap")
	_check(traps.size() == 1 and (traps[0] as RoomTrapDefinition).unless_marks == ["老松寨的过路钱", "叫阵老松寨"], "the gate trap lets the paid and the challengers through")
	var guard: NpcDefinition = catalog.npc(&"oldpine.npc.bandit_guard")
	_check(guard.dealings().parley and guard.dealings().attack_unless_marks == ["老松寨的过路钱", "叫阵老松寨"] and not guard.has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE) and not Berserk.applies_to(guard), "the keep's guards take a toll, and never go berserk")
	_check(catalog.npc(&"oldpine.npc.bandit_commander").dealings().attack_unless_marks == ["老松寨的过路钱"], "常老大 fights a challenger and talks to one who paid")


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
