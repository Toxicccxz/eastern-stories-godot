extends RefCounted

## 山烟寺 C: 八识神通's 神通 (cmds/std/conjure.c, daemon/class/bonze/essencemagic/). The
## files with scripted draws: 空识 (50 atman, 50 gin; random(magic) beats query_int(), then
## random(max_atman) < atman / 2 lowers potential, else below 500 unspent random(spi / 5) + 1
## more), 心识 (50 atman, 30 sen; random(max_atman) above 100 wakes the target, else the caster
## falls; busy 3 in a fight), 游识 (not in a fight, 75 atman: the question; the one found, 75
## atman and 30 gin, then random(their max_atman) above atman / 2 or random(magic) below their
## atman / 50 fails, else the caster goes there). A refused 拜师 is over (默认). Then the real
## session: the NPCs met (CharacterState.seen_npcs), the 武学 page's 空识 and 游识 (its
## question, across maps and on this one, nobody found, 中止施法, asked first when the gin
## would knock the player out), the HUD's 心识 on one lying unconscious (always asked first;
## it wakes them, or the player falls), Save/Continue with the NPCs met. TEST-ONLY fixtures
## are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MASTER: StringName = &"common.npc.bonze.master"
const LITTLE: StringName = &"sanyen.npc.little_bonze"
const FAMILY: StringName = &"family.sanyen"
const VOID_LINE: String = "你盘膝而座，开始运用空识神通静思入定 ..."
const DRIFT_LINE: String = "你低头闭目，开始施展游识神通 ...."
const HEART_LINE: String = "你一手放在小沙弥的天灵盖上，一手贴在小沙弥的後心，闭上眼睛缓缓低吟 ..."


## random(n) from a queue, the bounds asked kept in order; an empty queue gives n - 1.
class Draws:
	extends RefCounted
	var queue: Array[int] = []
	var bounds: Array[int] = []

	func _init(p_queue: Array[int] = []) -> void:
		queue = p_queue.duplicate()

	func next(n: int) -> int:
		if n <= 0:
			return 0 # MudOS random(0): no draw
		bounds.append(n)
		return queue.pop_front() if not queue.is_empty() else n - 1


var _count: int = 0
var _failures: Array[String] = []
var _catalog: ContentCatalog


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_catalog = GameContent.catalog()
	_test_data()
	_test_command()
	_test_void()
	_test_heart()
	_test_drift()
	_test_refusal_ends_request()
	_test_meet_rule()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await tree.physics_frame
	await _test_met(tree, session)
	await _test_page(tree, session)
	await _test_drift_session(tree, session)
	await _test_heart_hud(tree, session)
	await _test_continue(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


# --- The files ----------------------------------------------------------------------

func _test_data() -> void:
	var skill: SkillDefinition = _catalog.skill(&"essencemagic")
	_check(skill.conjure_functions == [&"heart_sense", &"drift_sense", &"void_sense"] and skill.cast_functions.is_empty(), "八识神通 reaches 心识, 游识 and 空识 (essencemagic/ holds three of doc/skill's eight)")
	_check(SpecialFunctions.CONJURES == [&"heart_sense", &"drift_sense", &"void_sense"], "the conjure files, in doc/skill/essencemagic's order")
	_check(SpecialFunctions.conjure(&"heart_sense").label == "心识神通" and SpecialFunctions.conjure(&"heart_sense").targets_other, "心识神通 works on another")
	_check(SpecialFunctions.conjure(&"drift_sense").label == "游识神通" and not SpecialFunctions.conjure(&"drift_sense").targets_other, "游识神通 at oneself")
	_check(SpecialFunctions.conjure(&"void_sense").label == "空识神通" and not SpecialFunctions.conjure(&"void_sense").targets_other, "空识神通 at oneself")
	var state: CharacterState = _monk(0, 0)
	_check(ConjureService.offered(state, _catalog) == [&"heart_sense", &"drift_sense", &"void_sense"], "enabled as 法术: all three offered")
	state.skills.unmap_skill(&"magic")
	_check(ConjureService.offered(state, _catalog).is_empty(), "八识神通 not enabled: none")
	for maximum: int in [0, 101, 102, 202, 1010]:
		var expected: int = {0: 100, 101: 100, 102: 99, 202: 50, 1010: 10}[maximum]
		_check(HeartSenseConjure.faint_percent(maximum) == expected, "心识 knocks a caster of max_atman %d out %d%% of the time" % [maximum, expected])


## conjure.c: busy, a no_magic room, nothing enabled, a file the skill has not.
func _test_command() -> void:
	var state: CharacterState = _monk(200, 200)
	var context: SpecialContext = _context(state, Draws.new())
	context.me.busy.start_busy(2)
	_check(not ConjureService.conjure(context, &"void_sense", false) and _fail(context) == "( 你上一个动作还没有完成，不能施展神通。)", "busy: 上一个动作还没有完成")
	context = _context(state, Draws.new())
	_check(not ConjureService.conjure(context, &"void_sense", true) and _fail(context) == "这里无法使用神通。", "a no_magic room: 这里无法使用神通。")
	state.skills.unmap_skill(&"magic")
	context = _context(state, Draws.new())
	_check(not ConjureService.conjure(context, &"void_sense", false) and _fail(context) == "你请先用 enable 指令选择你要使用的神通系。", "nothing enabled as 法术")
	state.skills.map_skill(&"magic", &"essencemagic")
	context = _context(state, Draws.new())
	_check(not ConjureService.conjure(context, &"light_sense", false) and _fail(context) == "你所选用的法术系中没有这种法术。", "光识: no such file (std/skill.c conjure_magic())")
	_check(state.recovery.atman.current == 200, "a refusal costs nothing")


func _test_void() -> void:
	var state: CharacterState = _monk(49, 300)
	var context: SpecialContext = _context(state, Draws.new())
	_check(not ConjureService.conjure(context, &"void_sense", false) and _fail(context) == "你的灵力不够！" and state.recovery.atman.current == 49, "49 atman: 你的灵力不够！, nothing spent")
	var magic: int = state.skills.effective_level(&"magic")
	var intelligence: int = state.attributes.intelligence
	# random(magic) no more than query_int(): nothing comes of it, the cost is spent.
	state = _monk(200, 300)
	state.essence = CharacterResourceState.new(120, 120, 120)
	var draws := Draws.new([intelligence])
	context = _context(state, draws)
	_check(ConjureService.conjure(context, &"void_sense", false), "空识 runs")
	_check(_texts(context) == [VOID_LINE, "可是你只觉得一无所获。"] and context.lines[0].color == ColoredLine.HIY, "its HIY line, then 一无所获")
	_check(state.recovery.atman.current == 150 and state.essence.current == 70 and state.essence.effective == 120, "50 atman and 50 gin of damage (receive_damage)")
	_check(draws.bounds == [magic], "one draw: random(query_skill(\"magic\") %d)" % magic)
	# random(magic) beats int, random(max_atman 300) below atman / 2 (75): 潜能降低.
	state = _monk(200, 300)
	state.progression.potential = 100
	state.progression.potential_spent = 20
	draws = Draws.new([intelligence + 1, 74])
	context = _context(state, draws)
	ConjureService.conjure(context, &"void_sense", false)
	_check(_texts(context) == [VOID_LINE, "你觉得脑中一片混乱，你的潜能降低了！"] and context.lines[1].color == ColoredLine.HIR, "random(max_atman) below atman / 2: HIR 潜能降低")
	_check(state.progression.potential == 100 and state.progression.potential_spent == 21 and draws.bounds == [magic, 300], "learned_points + 1; draws: magic, max_atman")
	# Then, below 500 unspent: random(spi / 5) + 1 more potential.
	state = _monk(200, 300)
	state.attributes.spirituality = 23
	state.progression.potential = 600
	state.progression.potential_spent = 101
	draws = Draws.new([intelligence + 1, 75, 3])
	context = _context(state, draws)
	ConjureService.conjure(context, &"void_sense", false)
	_check(_texts(context) == [VOID_LINE, "你的潜能提高了！"] and context.lines[1].color == ColoredLine.HIG, "499 unspent: HIG 潜能提高")
	_check(state.progression.potential == 604 and state.progression.potential_spent == 101 and draws.bounds == [magic, 300, 4], "potential + random(23 / 5) + 1 = 4")
	# 500 unspent: nothing.
	state = _monk(200, 300)
	state.progression.potential = 600
	state.progression.potential_spent = 100
	draws = Draws.new([intelligence + 1, 75])
	context = _context(state, draws)
	ConjureService.conjure(context, &"void_sense", false)
	_check(_texts(context) == [VOID_LINE, "可是你只觉得一无所获。"] and state.progression.potential == 600, "500 unspent: 一无所获")
	context = _context(_monk(200, 300), Draws.new())
	context.target = _side(&"other", CharacterState.new())
	_check(not ConjureService.conjure(context, &"void_sense", false) and _fail(context) == "空识神通只能对自己使用。", "at another: 只能对自己使用")


func _test_heart() -> void:
	var state: CharacterState = _monk(49, 200)
	var context: SpecialContext = _context(state, Draws.new())
	_check(not ConjureService.conjure(context, &"heart_sense", false) and _fail(context) == "你要对谁使用心识神通？", "nobody named: 你要对谁使用心识神通？")
	context = _context(state, Draws.new())
	context.target = _side(&"little", CharacterState.new())
	_check(not ConjureService.conjure(context, &"heart_sense", false) and _fail(context) == "你的灵力不够！", "49 atman: 你的灵力不够！")
	state = _monk(200, 300)
	state.spirit = CharacterResourceState.new(100, 100, 100)
	var draws := Draws.new([101])
	context = _context(state, draws)
	context.target = _side(&"little", CharacterState.new())
	_check(ConjureService.conjure(context, &"heart_sense", false) and context.revived and not context.fainted, "random(300) = 101: the target wakes")
	_check(_texts(context, "小沙弥") == [HEART_LINE] and context.lines[0].color == ColoredLine.HIY and context.lines[0].target_id == &"little", "its HIY line on the target")
	_check(state.recovery.atman.current == 150 and state.spirit.current == 70 and draws.bounds == [300], "50 atman, 30 sen; one draw: random(max_atman)")
	_check(not context.me.busy.is_busy(), "not fighting: not busy")
	draws = Draws.new([100])
	context = _context(state, draws)
	context.target = _side(&"little", CharacterState.new())
	ConjureService.conjure(context, &"heart_sense", false)
	_check(context.fainted and not context.revived, "random(300) = 100: the caster falls (unconcious())")
	# In a fight: busy 3 after it, unless the caster fell.
	state = _monk(200, 300)
	context = _context(state, Draws.new([200]))
	context.me.relationship.add_opponent(&"enemy")
	context.target = _side(&"little", CharacterState.new())
	ConjureService.conjure(context, &"heart_sense", false)
	_check(context.revived and context.me.busy.is_busy(), "in a fight: busy after it")
	context = _context(state, Draws.new([0]))
	context.me.relationship.add_opponent(&"enemy")
	context.target = _side(&"little", CharacterState.new())
	ConjureService.conjure(context, &"heart_sense", false)
	_check(context.fainted and not context.me.busy.is_busy(), "fallen: unconcious() ended the fight, no busy")
	state = _monk(200, 0)
	draws = Draws.new()
	context = _context(state, draws)
	context.target = _side(&"little", CharacterState.new())
	ConjureService.conjure(context, &"heart_sense", false)
	_check(context.fainted and draws.bounds.is_empty(), "max_atman 0: random(0) is 0, no draw: the caster falls")


func _test_drift() -> void:
	var drift: DriftSenseConjure = SpecialFunctions.conjure(&"drift_sense") as DriftSenseConjure
	var state: CharacterState = _monk(74, 300)
	var context: SpecialContext = _context(state, Draws.new())
	_check(not ConjureService.conjure(context, &"drift_sense", false) and _fail(context) == "你的灵力不够！", "74 atman: 你的灵力不够！")
	state = _monk(300, 300)
	context = _context(state, Draws.new())
	context.me.relationship.add_opponent(&"enemy")
	_check(not ConjureService.conjure(context, &"drift_sense", false) and _fail(context) == "战斗中无法使用游识神通！", "in a fight: 战斗中无法使用游识神通！")
	context = _context(state, Draws.new())
	context.target = _side(&"other", CharacterState.new())
	_check(not ConjureService.conjure(context, &"drift_sense", false) and _fail(context) == "游识神通只能对自己使用！", "at another: 只能对自己使用")
	context = _context(state, Draws.new())
	_check(ConjureService.conjure(context, &"drift_sense", false) and context.lines.is_empty() and state.recovery.atman.current == 300, "the question comes; nothing spent yet")
	# select_target(): nobody found asks again, at no cost.
	context = _context(state, Draws.new())
	_check(not drift.select_target(context) and _texts(context) == ["你无法感受到这个人的灵力 ...."] and state.recovery.atman.current == 300, "nobody of that name: 无法感受到, asked again")
	# Found, no atman of their own: the caster goes.
	var magic: int = state.skills.effective_level(&"magic")
	state.essence = CharacterResourceState.new(100, 100, 100)
	var draws := Draws.new()
	context = _context(state, draws)
	context.target = _side(&"waiter", CharacterState.new())
	_check(drift.select_target(context) and context.drifted, "found, no atman: the caster goes")
	_check(_texts(context) == [DRIFT_LINE] and context.lines[0].color == ColoredLine.HIY, "its HIY line")
	_check(state.recovery.atman.current == 225 and state.essence.current == 70, "75 atman and 30 gin")
	_check(draws.bounds == [magic], "random(their max_atman 0) draws nothing; random(magic) %d" % magic)
	# Their max_atman: random(1000) above atman / 2 (225 / 2 = 112) is 不够强烈.
	var strong := CharacterState.new()
	strong.recovery.atman = CharacterInternalResourceState.new(5000, 1000)
	draws = Draws.new([113])
	context = _context(state, draws)
	context.target = _side(&"monk", strong)
	_check(drift.select_target(context) and not context.drifted and _texts(context) == [DRIFT_LINE, "你感受到对方的灵力，但是不够强烈。"], "random(1000) above atman / 2: 不够强烈")
	_check(state.recovery.atman.current == 150 and draws.bounds == [1000], "the cost is spent all the same")
	# Then random(magic) below their atman / 50 (5000 / 50 = 100) is 不够熟练.
	draws = Draws.new([37, 99])
	context = _context(state, draws)
	context.target = _side(&"monk", strong)
	_check(drift.select_target(context) and not context.drifted and _texts(context).back() == "你因为不够熟练而失败了。", "random(magic) below their atman / 50: 不够熟练")
	draws = Draws.new([37, 100])
	context = _context(_monk(300, 300), draws)
	context.target = _side(&"monk", strong)
	_check(drift.select_target(context) and context.drifted and draws.bounds == [1000, magic], "both beaten: the caster goes")
	# The checks again once a name is answered.
	state = _monk(74, 300)
	context = _context(state, Draws.new())
	context.target = _side(&"waiter", CharacterState.new())
	_check(drift.select_target(context) and not context.drifted and _texts(context) == ["你的灵力不够！"] and state.recovery.atman.current == 74, "74 atman by then: 你的灵力不够！, over")


## 默认 (DECISIONS 山烟寺 C): a master's refusal ends the request; asking again asks anew.
func _test_refusal_ends_request() -> void:
	var master: NpcDefinition = _catalog.npc(MASTER)
	var family: FamilyDefinition = _catalog.family(FAMILY)
	var layman: CharacterState = NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "山烟").state
	var request := NpcApprenticeship.new()
	_check(request.request(layman, master, family, 1, "施主") == NpcApprenticeship.Outcome.ANSWER_DUE and request.is_pending_with(master.definition_id), "玄智: the request waits on his answer")
	_check(request.answer(layman, master, family, 2, "施主") == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and not request.is_pending(), "his refusal (请先到小寺剃度出家) ends it")
	_check(request.request(layman, master, family, 3, "施主") == NpcApprenticeship.Outcome.ANSWER_DUE and request.lines == ["你想要拜玄智和尚为师。"], "asked again: a new request, not 对方还没有答应")
	layman.affiliation.class_id = &"bonze" # TEST-ONLY: ordained since
	_check(request.answer(layman, master, family, 4, "大师") == NpcApprenticeship.Outcome.RECRUITED, "ordained, the new request is answered: taken")
	# A master that answers at once (柳淳风's 定力).
	var liu: NpcDefinition = null
	for definition: NpcDefinition in _catalog.npcs():
		var teaching: NpcTeaching = definition.teaching()
		if teaching != null and teaching.apprentice != null and teaching.apprentice.kind == NpcTeaching.Kind.REQUIREMENTS and teaching.apprentice.answer_after <= 0.0 and not teaching.apprentice.checks.is_empty() and teaching.apprentice.commoners_only.is_empty():
			liu = definition
			break
	_check(liu != null, "a master who answers at once with a check")
	if liu == null:
		return
	var weak: CharacterState = NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "山烟").state
	for attribute: StringName in [&"composure", &"strength", &"courage", &"intelligence", &"spirituality", &"personality", &"constitution", &"karma"]:
		weak.attributes.set(attribute, 1) # TEST-ONLY: short of every check
	weak.progression.combat_experience = 0
	request = NpcApprenticeship.new()
	var refused: NpcApprenticeship.Outcome = request.request(weak, liu, _catalog.family(liu.teaching().family_id), 1, "小兄弟")
	_check(refused == NpcApprenticeship.Outcome.QUALIFICATION_REJECTED and not request.is_pending(), "%s refuses at once: over" % liu.display_name)
	request.request(weak, liu, _catalog.family(liu.teaching().family_id), 2, "小兄弟")
	_check(not request.lines.has("你想拜%s为师，但是对方还没有答应。" % liu.display_name), "asked again: answered again")


## Who goes on 游识's list: a kind not met before, in order; not one conjured, raised,
## summoned or dead.
func _test_meet_rule() -> void:
	var state := CharacterState.new()
	var master := _npc(MASTER)
	var little := _npc(LITTLE)
	PlayerEssenceMagic.meet(state, little, false)
	PlayerEssenceMagic.meet(state, master, false)
	PlayerEssenceMagic.meet(state, little, false)
	_check(state.seen_npcs == {String(LITTLE): 1, String(MASTER): 2}, "met in order, each kind once: %s" % [state.seen_npcs])
	var zombie := _npc(&"common.npc.zombie")
	PlayerEssenceMagic.meet(state, zombie, false)
	var soldier := _npc(&"sanyen.npc.greeting")
	PlayerEssenceMagic.meet(state, soldier, true)
	var dead := _npc(&"sanyen.npc.cook_bonze")
	dead.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	PlayerEssenceMagic.meet(state, dead, false)
	_check(state.seen_npcs.size() == 2, "a raised zombie, a summoned one and a dead one are not listed")


# --- The session --------------------------------------------------------------------

## New Game in the Inn: whoever is there is met; on the temple grounds the monks there.
func _test_met(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var inn: WorldMapController = session.active_map() as WorldMapController
	inn.npc_life._advance_ambience(0.0)
	var here: Array[String] = []
	for npc: NpcRuntimeState in inn.resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == player.world_location().zone_id:
			here.append(String(npc.definition_id))
	_check(not here.is_empty(), "someone stands in the Inn's room: %s" % [here])
	var met: bool = true
	for id: String in here:
		met = met and player.state.seen_npcs.has(id)
	_check(met, "New Game: the Inn's people are met: %s" % [player.state.seen_npcs])
	_check(session.handoff_to(&"sanyen.grounds", &"sanyen.front_yard", &"sanyen.front_yard", &"sanyen.front_yard.gate_arrival").succeeded(), "TEST-ONLY: onto the temple grounds")
	await tree.physics_frame
	await tree.physics_frame
	var grounds: WorldMapController = session.active_map() as WorldMapController
	grounds.npc_life._advance_ambience(0.0)
	_check(player.state.seen_npcs.has("cloud.npc.monk_guard"), "the 护寺武僧 in the yard are met")
	_check(not player.state.seen_npcs.has(String(MASTER)), "玄智, in the hall, not yet")
	await _beside(tree, session, grounds, _first(grounds, MASTER))
	grounds.npc_life._advance_ambience(0.0)
	_check(player.state.seen_npcs.has(String(MASTER)), "in the hall: 玄智 met")
	var little: NpcRuntimeState = _first(grounds, LITTLE)
	await _beside(tree, session, grounds, little)
	grounds.npc_life._advance_ambience(0.0)
	_check(player.state.seen_npcs.has(String(LITTLE)), "in the 后殿: 小沙弥 met")
	var names: Array[String] = session.essence_magic().drift_names()
	_check(names.has("玄智和尚") and names.has("小沙弥") and names.has("护寺武僧") and names.find("护寺武僧") < names.find("玄智和尚"), "the names, in the order met: %s" % [names])


## The 武学 page: 八识神通 enabled as 法术 shows 空识 and 游识 (心识 is the HUD's); 空识 runs
## from it, asked first when its 50 gin would knock the player out (取消: back to the page).
func _test_page(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	hud.open_martial_arts()
	var page: MartialArtsPage = hud.martial_arts_page()
	page.refresh()
	_check(not page.buttons.has("conjure:void_sense") and not page.conjure_title.visible, "八识神通 not enabled: no 神通")
	_make_monk(player.state, 200, 300) # TEST-ONLY
	page.refresh()
	_check(page.buttons.has("conjure:void_sense") and page.buttons.has("conjure:drift_sense") and not page.buttons.has("conjure:heart_sense") and page.conjure_title.visible, "enabled: 空识 and 游识 on the page")
	_check(page.buttons["conjure:void_sense"].text == "空识神通" and page.buttons["conjure:drift_sense"].text == "游识神通" and page.buttons["conjure:void_sense"].tooltip_text.contains("50 灵力、50 精"), "their labels and costs")
	player.state.essence = CharacterResourceState.new(200, 200, 200)
	page.buttons["conjure:void_sense"].pressed.emit()
	_check(hud.log_lines().has(VOID_LINE) and player.state.recovery.atman.current == 150 and player.state.essence.current == 150, "空识: its line, 50 atman and 50 gin")
	_check(page.feedback.text.begins_with(VOID_LINE) and not hud.is_asking(), "the page repeats its lines; nothing asked")
	while player.busy.is_busy():
		player.busy.advance()
	player.state.essence = CharacterResourceState.new(49, 200, 200)
	page.buttons["conjure:void_sense"].pressed.emit()
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("50 点精") and hud.confirm_prompt.confirm_button.text == "确定施展", "49 gin: asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(not hud.is_asking() and player.state.recovery.atman.current == 150 and page.is_visible_in_tree(), "取消: nothing spent, back on the page")
	player.state.essence = CharacterResourceState.new(200, 200, 200)
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame


## 游识 from the page: its question with the names met; going to someone on another map
## and on this one; nobody of that name (asked again); 中止施法; asked first when the 30 gin
## would knock the player out.
func _test_drift_session(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var magic: PlayerEssenceMagic = session.essence_magic()
	player.state.recovery.atman = CharacterInternalResourceState.new(70, 300)
	hud.open_martial_arts()
	var page: MartialArtsPage = hud.martial_arts_page()
	page.refresh()
	page.buttons["conjure:drift_sense"].pressed.emit()
	_check(hud.log_lines()[-1] == "你的灵力不够！" and page.is_visible_in_tree(), "70 atman: 你的灵力不够！, no question")
	player.state.recovery.atman = CharacterInternalResourceState.new(300, 300)
	page.buttons["conjure:drift_sense"].pressed.emit()
	_check(hud._presentation_layout._content == hud.drift_panel and hud.drift_panel.question.text == "你要移动到哪一个人身边？", "the question opens")
	_check(hud.drift_panel.shown_names() == magic.drift_names() and hud.drift_panel.shown_names().has("玄智和尚"), "with the names met: %s" % [hud.drift_panel.shown_names()])
	# Someone met on another map: the first name standing elsewhere.
	var away: NpcRuntimeState = null
	for name: String in magic.drift_names():
		var found: NpcRuntimeState = magic.drift_target(name)
		if found != null and found.world_location().map_id != session.active_map_id():
			away = found
			break
	_check(away != null, "someone met on another map")
	if away == null:
		return
	var before: int = hud.log_lines().size()
	hud.drift_panel.chosen.emit(away.definition().display_name)
	await tree.physics_frame
	var there: WorldMapController = session.active_map() as WorldMapController
	_check(session.active_map_id() == away.world_location().map_id and player.world_location().zone_id == away.world_location().zone_id, "游识: in %s's room on %s" % [away.definition().display_name, away.world_location().map_id])
	var distance: float = there.runtime_player_body().global_position.distance_to(there.npc_rest_position(away.character_id))
	_check(distance >= 40.0 and distance <= 100.0, "beside them, clear of their body: %.0f px" % distance)
	_check(MapPlacementValidator.is_valid_character_position(there, player.world_location().zone_id, there.runtime_player_body().global_position), "on open ground")
	var log: Array[String] = hud.log_lines().slice(before)
	_check(log.size() >= 2 and log[0] == DRIFT_LINE and log[1].begins_with("【"), "its line, then the room: %s" % [log])
	_check(player.state.recovery.atman.current == 225 and hud._presentation_layout._content != hud.drift_panel, "75 atman; the question closed")
	# Back to the temple's 玄智 (another map again), then to the 小沙弥 on the same map.
	while player.busy.is_busy():
		player.busy.advance()
	_check(magic.drift_begin(), "asked again")
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	# TEST-ONLY: 玄智's 灵力 sensed (random(max_atman) = 0), the skill beats his atman / 50.
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0, 999, 0, 999]))
	_check(magic.drift_to("玄智和尚") and session.active_map_id() == &"sanyen.grounds" and player.world_location().zone_id == _first(session.active_map() as WorldMapController, MASTER).world_location().zone_id, "游识 to 玄智: his room in the temple")
	_check(magic.drift_begin() and magic.drift_to("小沙弥") and player.world_location().zone_id == _first(session.active_map() as WorldMapController, LITTLE).world_location().zone_id, "on the same map: the 小沙弥's room")
	session.configure_world_interaction_random_source(original)
	# Nobody of that name now: the question asks again, nothing spent.
	var little: NpcRuntimeState = _first(session.active_map() as WorldMapController, LITTLE)
	little.set_exists_in_map(false) # TEST-ONLY: gone
	var atman: int = player.state.recovery.atman.current
	hud.open_martial_arts()
	hud.martial_arts_page().buttons["conjure:drift_sense"].pressed.emit()
	hud.drift_panel.chosen.emit("小沙弥")
	_check(hud._presentation_layout._content == hud.drift_panel and hud.log_lines()[-1] == "你无法感受到这个人的灵力 ...." and hud.drift_panel.last_lines.text == "你无法感受到这个人的灵力 ...." and player.state.recovery.atman.current == atman, "gone: 无法感受到, asked again, nothing spent")
	little.set_exists_in_map(true)
	# 中止施法: its line, back on the 武学 page.
	hud.drift_panel.cancel_button.pressed.emit()
	_check(hud.log_lines()[-1] == "中止施法。" and hud.martial_arts_page().is_visible_in_tree(), "中止施法: back on the page")
	# 29 gin: asked first once the name is found; 取消 goes back to the question.
	player.state.essence = CharacterResourceState.new(29, 200, 200)
	hud.martial_arts_page().buttons["conjure:drift_sense"].pressed.emit()
	hud.drift_panel.chosen.emit("玄智和尚")
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("30 点精"), "29 gin: asked first: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	_check(hud._presentation_layout._content == hud.drift_panel and player.state.recovery.atman.current == atman, "取消: back to the question, nothing spent")
	player.state.essence = CharacterResourceState.new(200, 200, 200)
	hud.dismiss_current_panel()
	await tree.physics_frame
	await tree.physics_frame


## 心识 on the HUD: the 小沙弥 lying unconscious, selected: always asked first (the odds from
## max_atman); it wakes him (the room hears it), or the player falls.
func _test_heart_hud(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	var map: WorldMapController = session.active_map() as WorldMapController
	var little: NpcRuntimeState = _first(map, LITTLE)
	await _beside(tree, session, map, little)
	map.select_npc(little.character_id)
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(not hud.heart_sense_button.visible, "the 小沙弥 awake: no 心识")
	little.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY: knocked out
	little.set_revive_in_ms(600000)
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(hud.heart_sense_button.visible and hud.heart_sense_button.text == "心识神通", "lying unconscious, selected: 心识神通 on the HUD")
	player.state.recovery.atman = CharacterInternalResourceState.new(300, 101)
	hud.heart_sense_button.pressed.emit()
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("必定失败") and hud.confirm_prompt.message.text.contains("小沙弥"), "max_atman 101: asked, it must fail: %s" % hud.confirm_prompt.message.text)
	hud.confirm_prompt.cancel_button.pressed.emit()
	player.state.recovery.atman = CharacterInternalResourceState.new(300, 303)
	hud.heart_sense_button.pressed.emit()
	_check(hud.is_asking() and hud.confirm_prompt.message.text.contains("约有 33% 的机会失败"), "max_atman 303: one in three: %s" % hud.confirm_prompt.message.text)
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([200])) # TEST-ONLY: random(303) = 200
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(little.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and little.revive_in_ms <= 0, "he wakes")
	var log: Array[String] = hud.log_lines()
	_check(log.slice(-2) == [HEART_LINE, "小沙弥慢慢睁开眼睛，清醒了过来。"], "its line, then combatd.c's revive: %s" % [log.slice(-2)])
	_check(player.state.recovery.atman.current == 250 and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "50 atman; the player stands")
	hud.refresh_live_state()
	hud.refresh_exploration()
	_check(not hud.heart_sense_button.visible, "awake: the button goes")
	# A failure: the player falls.
	little.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) # TEST-ONLY
	little.set_revive_in_ms(600000)
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([100])) # TEST-ONLY: random(303) = 100
	hud.refresh_live_state()
	hud.refresh_exploration()
	hud.heart_sense_button.pressed.emit()
	hud.confirm_prompt.confirm_button.pressed.emit()
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and little.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "random(303) = 100: the player falls; he lies on")
	session.configure_world_interaction_random_source(original)
	for _second: int in 10:
		session._process(1.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the player comes to")
	await tree.physics_frame


## Save/Continue keeps the NPCs met, in order.
func _test_continue(tree: SceneTree, session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	while player.busy.is_busy():
		player.busy.advance()
	player.state.recovery.atman = CharacterInternalResourceState.new(100, 300)
	CharacterDerivedValues.refresh_human_player_maxima(player.state, player.facts.age) # TEST-ONLY: Continue recomputes them
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "the save captures")
	if snapshot == null:
		return
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	_check(encoded.succeeded() and encoded.text.contains("\"seen_npcs\"") and encoded.text.contains(String(MASTER)), "the save holds the NPCs met")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(decoded.succeeded() and decoded.snapshot.player.character.seen_npcs == player.state.seen_npcs, "decoded as captured")
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "山烟寺 C")
	_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))


# --- Helpers ------------------------------------------------------------------------

## TEST-ONLY: 八识神通 100 enabled as 法术 (and 大乘佛法 above it), `atman` of `maximum`.
static func _monk(atman: int, maximum: int) -> CharacterState:
	var state: CharacterState = NewPlayerInitializationPolicy.create(CharacterState.GENDER_MALE, "山烟").state
	_make_monk(state, atman, maximum)
	return state


static func _make_monk(state: CharacterState, atman: int, maximum: int) -> void:
	state.affiliation.class_id = &"bonze"
	state.skills.set_raw_level(&"buddhism", 120)
	state.skills.set_raw_level(&"magic", 40)
	state.skills.set_raw_level(&"essencemagic", 100)
	state.skills.map_skill(&"magic", &"essencemagic")
	state.recovery.atman = CharacterInternalResourceState.new(atman, maximum)


func _context(state: CharacterState, draws: Draws) -> SpecialContext:
	var me := SpecialSide.new(&"player", state, ActionBusyState.new(), CombatRelationshipState.new(&"player"))
	me.is_user = true
	return SpecialContext.new(me, [], draws.next, _catalog, SkillImprovementEffectRegistry.new())


static func _side(id: StringName, state: CharacterState) -> SpecialSide:
	return SpecialSide.new(id, state, ActionBusyState.new(), CombatRelationshipState.new(id))


func _npc(definition_id: StringName) -> NpcRuntimeState:
	return NpcRuntimeState.new(StringName("test." + String(definition_id)), _catalog.npc(definition_id), &"test.spawn", &"test.point", CharacterState.new(), CombatRelationshipState.new(&"test"), ActionBusyState.new(), ArmorState.new())


static func _fail(context: SpecialContext) -> String:
	return "" if context.fail_line == null else context.fail_line.template


## The lines as the player reads them (你 for $N, `target` for $n).
static func _texts(context: SpecialContext, target: String = "") -> Array[String]:
	var out: Array[String] = []
	for line: VisionLine in context.report().lines():
		out.append(line.template.replace("$N", "你").replace("$n", target))
	return out


## TEST-ONLY: the player beside the NPC, in its room.
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var zone_id: StringName = npc.world_location().zone_id
	var body: WorldCharacterBody2D = map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = MapPlaces.spot(map, zone_id, body.global_position + Vector2(0, 56), 60.0)
	map.runtime_player_body().global_position = at
	_check(at != Vector2.INF and session.player_runtime().set_world_location(map.location_for_zone(zone_id)), "TEST-ONLY: beside %s" % npc.definition().display_name)
	await tree.physics_frame
	await tree.physics_frame


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("山烟寺 C: " + label)
