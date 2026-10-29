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
	_test_asker_lacks()
	_test_chapter2_data()
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
	_check(errors.is_empty() and marked.spared_mood.is_empty() and marked.spared_mark == "m" and not marked.spared_leave, "a mark alone")
	var fled: NpcHooks = NpcHooks.from_record(ContentRecordReader.new({"spared": {"leave": true, "line": "逃了。"}}, "test", errors))
	_check(errors.is_empty() and fled.spared_leave and fled.spared_line == "逃了。" and fled.has_spared(), "leave with its line")
	NpcHooks.from_record(ContentRecordReader.new({"spared": {"mark": "m", "line": "x"}}, "test", errors))
	_check(errors.size() == 1, "a line without leave is refused")
	errors.clear()
	NpcHooks.from_record(ContentRecordReader.new({"scene_mark": "s"}, "test", errors))
	_check(errors.size() == 1 and errors[0].contains("scene_mark"), "scene_mark needs a scene")
	errors.clear()
	var scened: NpcHooks = NpcHooks.from_record(ContentRecordReader.new({"scene_mark": "s", "calls": [{"after": 1, "scene": true, "steps": [{"say": "一"}]}]}, "test", errors))
	_check(errors.is_empty() and scened.scene_mark == "s", "scene_mark with a scene")


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
	var classic: PacingDefinition = PacePresets.of(production, CharacterState.PACE_CLASSIC)
	_check(not classic.story_parley and not classic.bury_always_rewards and PacePresets.of(production, CharacterState.PACE_MODERN).story_parley, "经典 turns both off; 现代 keeps them")


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
	_check(quest.steps[1].is_branch() and quest.steps[1].options.size() == 3 and quest.steps[1].options[2].condition.key == "打倒了寨门的喽罗" and catalog.spawn(&"oldpine.outdoor.keep1.bandit_guards").cleared_mark == "打倒了寨门的喽罗", "the gate: pay, challenge or force (the guards' cleared_mark, not a 历练 the 经典 pace never writes)")
	_check(quest.steps[2].is_branch() and quest.steps[2].options[0].condition.when == JournalEntryDefinition.When.HEARD and quest.steps[2].options[1].condition.key == "打倒了常老大" and catalog.spawn(&"oldpine.keep_hall.keep3.bandit_commander").cleared_mark == "打倒了常老大", "常老大: asked or beaten")
	_check(quest.steps[6].is_branch() and quest.steps[6].options[0].condition.key == "安葬无名人" and quest.steps[6].options[1].condition.key == "native:waterfog/guild_token" and quest.steps[6].options[1].reward.marks == ["带走腰牌"], "the bones: buried or the token taken")
	_check(quest.reward.milestone and not quest.reward.deed.is_empty(), "a 历练 and a deed at the end")
	var prologue: StoryQuestDefinition = catalog.story_quest(&"main.prologue")
	var prologue_ids: Array = prologue.steps.map(func(step: StoryQuestDefinition.Step) -> String: return String(step.step_id))
	_check(prologue_ids == ["waiter", "square", "pass", "scene", "strip"], "寻剑令 goes on to the scene and the strip: %s" % [prologue_ids])
	_check(catalog.npc(&"native.npc.bai_daozhang") != null and catalog.npc(&"native.npc.black_taoist") != null and catalog.npc(&"native.npc.black_taoist_pass") != null, "白道长 and the 黑衣道士 (twice)")
	var scene: NpcHooks = catalog.npc(&"native.npc.bai_daozhang").hooks()
	_check(scene != null and scene.calls.size() == 7 and scene.scene_mark == "隘口的道士" and scene.calls.all(func(call: NpcHooks.Call) -> bool: return call.scene and call.act.not_mark == "隘口的道士"), "白道长's seven scene calls, once (marked as it begins)")
	_check(catalog.npc(&"native.npc.black_taoist").hooks().spared_mark == "放过了黑衣道士" and catalog.npc(&"native.npc.black_taoist").hooks().spared_leave and catalog.npc(&"native.npc.black_taoist_pass").dealings().is_fight_deferred(), "the taoist spared leaves a mark and flees; at the pass he cannot be fought")
	var pass_spawn: NpcSpawnDefinition = catalog.spawn(&"native.pass.bai_daozhang")
	_check(pass_spawn != null and pass_spawn.present.key == "main.prologue/square" and pass_spawn.until.key == "main.chapter1#started", "the pass crew come after the square and go once 伪墓 began")
	_check(catalog.spawn(&"native.square.feng_ce").until.key == "main.prologue/square", "the square's officials leave once asked")
	var cave: NpcSpawnDefinition = catalog.spawn(&"native.caves.black_taoist")
	_check(cave != null and cave.once and cave.present.key == "main.chapter1/boss" and cave.until.key == "main.chapter1/taoist" and cave.cleared_mark == "黑衣道士倒了" and quest.steps[4].condition.key == "黑衣道士倒了", "the taoist waits in cave5 after 常老大; down, his spawn marks the step, and he is gone")
	_check(catalog.item_spawn(&"native.caves.cave5.guild_token").present.key == "main.chapter1#started" and catalog.item_spawn(&"native.caves.cave5.guild_token").until.key == "main.chapter1/bones", "the 腰牌 lies there from 伪墓's start until the bones are dealt with")
	var wall: WorldLandmarkDefinition = catalog.landmark(&"oldpine.caves.landmark.wall")
	_check(wall.mark == "安葬无名人" and wall.teaches == ["看过石壁"] and wall.item("with") == &"native:waterfog/guild_token", "the wall teaches its clues and buries the token with the bones")
	var traps: Array = catalog.traps().filter(func(trap: RoomTrapDefinition) -> bool: return trap.trap_id == &"oldpine.keep2.gate_trap")
	_check(traps.size() == 1 and (traps[0] as RoomTrapDefinition).unless_marks == ["老松寨的过路钱", "叫阵老松寨"], "the gate trap lets the paid and the challengers through")
	var guard: NpcDefinition = catalog.npc(&"oldpine.npc.bandit_guard")
	_check(guard.dealings().parley and guard.dealings().attack_unless_marks == ["老松寨的过路钱", "叫阵老松寨"] and not guard.has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE) and not Berserk.applies_to(guard), "the keep's guards take a toll, and never go berserk")
	_check(catalog.npc(&"oldpine.npc.bandit_commander").dealings().attack_unless_marks == ["老松寨的过路钱"], "常老大 fights a challenger and talks to one who paid")


## A rule for one who has NOT taken the other side of a choice (主线 B).
func _test_asker_lacks() -> void:
	var errors: Array[String] = []
	var rule: NpcInquiryRule = NpcInquiryRule.from_record(ContentRecordReader.new({"asker_marks": ["a"], "asker_lacks": ["b"], "say": "好。"}, "test", errors))
	_check(errors.is_empty() and rule.asker_lacks == ["b"], "asker_lacks reads: %s" % [errors])
	_check(rule.matches({"a": 1}) and not rule.matches({"a": 1, "b": 1}) and not rule.matches({}), "with a, without b")


## 旧案 as loaded: after 伪墓, the letter, the 镖单, the two inscriptions, 南危水's three ways to
## the truth, 潘军禅 with the letter in hand, and the choice with its consequences.
func _test_chapter2_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter2")
	_check(quest != null and quest.title == "旧案" and quest.requires == [&"main.chapter1"] and quest.starts == null, "旧案 follows 伪墓 at once")
	if quest == null:
		return
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> String: return String(step.step_id))
	_check(ids == ["liu", "escort", "tomb", "stone", "nan", "pan", "choice"], "the steps: %s" % [ids])
	_check(catalog.story_quest(&"main.chapter1").reward.marks == ["查明伪墓"], "伪墓 done leaves the mark 柳淳风 reads")
	var liu: NpcDefinition = catalog.npc(&"common.npc.swordsman.master")
	var letter: NpcInquiryRule = NpcInquiryRule.decide(liu.talk().inquiry_rules("水烟阁"), {"查明伪墓": 1})
	_check(letter != null and letter.gives == &"native:snow/letter_to_pan" and letter.mark_asker == "柳淳风的引荐信", "柳淳风 writes the letter for one who found the false tomb")
	_check(NpcInquiryRule.decide(liu.talk().inquiry_rules("水烟阁"), {}).gives.is_empty(), "and not before")
	var chen: NpcDefinition = catalog.npc(&"cloud.npc.b_header")
	var note: NpcInquiryRule = NpcInquiryRule.decide(chen.talk().inquiry_rules("失镖"), {"柳淳风的引荐信": 1})
	_check(note != null and note.gives == &"native:cloud/escort_note" and note.mark_asker == "看过镖单", "陈剑秋 hands over the 镖单 to 柳淳风's messenger")
	_check(catalog.landmark(&"waterfog.swordtomb.landmark.monolith").teaches == ["看过葬剑亭碑"] and catalog.landmark(&"waterfog.wpath2.landmark.stone").teaches == ["看过石台碑"], "the two inscriptions teach their marks")
	var nan: NpcDefinition = catalog.npc(&"waterfog.npc.elder5")
	var by_token: NpcInquiryRule = NpcInquiryRule.decide(nan.talk().inquiry_rules("山洞的骸骨"), {}, null, &"", &"", 0, {}, ["guild token"])
	var by_note: NpcInquiryRule = NpcInquiryRule.decide(nan.talk().inquiry_rules("山洞的骸骨"), {"看过石台碑": 1, "看过葬剑亭碑": 1}, null, &"", &"", 0, {}, ["escort note"])
	var by_nothing: NpcInquiryRule = NpcInquiryRule.decide(nan.talk().inquiry_rules("山洞的骸骨"), {"看过石台碑": 1}, null, &"", &"", 0, {}, ["escort note"])
	_check(by_token != null and by_token.mark_asker == "南危水承认了" and by_note != null and by_note.mark_asker == "南危水承认了" and by_nothing.mark_asker.is_empty(), "南危水 admits to the 腰牌, or to the 镖单 with both inscriptions seen; not to less")
	var hooks: NpcHooks = nan.hooks()
	_check(hooks != null and hooks.calls.size() == 1 and hooks.calls[0].act.mark == "安葬无名人" and hooks.calls[0].act.not_mark == "南危水承认了" and not hooks.calls[0].scene, "to one who buried 阿岭 he speaks first (a call, no scene)")
	_check(nan.talk().has_greeting() and nan.talk().choose_greeting(&"男性", &"", Callable(), _facts({"替南危水保密": 1})) != null and nan.talk().choose_greeting(&"男性", &"", Callable(), _facts({})) == null, "his greeting: only for one who chose")
	var keep: NpcInquiryRule = NpcInquiryRule.decide(nan.talk().inquiry_rules("保密"), {"南危水承认了": 1})
	_check(keep != null and keep.mark_asker == "替南危水保密" and NpcInquiryRule.decide(nan.talk().inquiry_rules("保密"), {"南危水承认了": 1, "告发了南危水": 1}).mark_asker.is_empty(), "保密 only before telling")
	var yan: NpcDefinition = catalog.npc(&"waterfog.npc.elder7")
	var tell: NpcInquiryRule = NpcInquiryRule.decide(yan.talk().inquiry_rules("南危水的事"), {"南危水承认了": 1})
	_check(tell != null and tell.mood == "acting" and tell.mark_asker == "告发了南危水" and yan.hooks().moods["acting"].title == "水烟阁代盟主" and yan.hooks().moods["acting"].lasting, "颜违 takes the seat, for good")
	_check(NpcInquiryRule.decide(yan.talk().inquiry_rules("南危水的事"), {"南危水承认了": 1, "替南危水保密": 1}).mark_asker.is_empty(), "not after 保密")
	var pan: NpcDefinition = catalog.npc(&"common.npc.fighter.executioner")
	_check(NpcInquiryRule.decide(pan.talk().inquiry_rules("邪剑穿灵"), {}, null, &"", &"", 0, {}, ["pan letter"]).lines.size() == 4 and NpcInquiryRule.decide(pan.talk().inquiry_rules("邪剑穿灵"), {}).lines.size() == 1, "潘军禅 talks to the letter's bearer")
	_check(quest.steps[6].is_branch() and quest.steps[6].options[0].condition.key == "替南危水保密" and quest.steps[6].options[1].condition.key == "告发了南危水", "the choice")


func _facts(marks: Dictionary[String, int]) -> ScriptedAct.Facts:
	var facts := ScriptedAct.Facts.new()
	facts.marks = marks
	return facts


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
