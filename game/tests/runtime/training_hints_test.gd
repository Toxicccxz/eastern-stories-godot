extends RefCounted

## How far a teacher can take the player and a master's conditions (DECISIONS「上限预览和
## 拜师条件」): the thirteen masters' rows from their data (met / not met / told no more,
## no test, oath, letter or 桃林 told before; the 桃林 once 骆云舟 said it); in a running
## Snow session 柳淳风's 拜师 page lists his conditions with the player's values, 查看 counts
## them, his 请教 page says under each skill how far and why not further, the 武学 page says
## how far practice and cultivation go; all of it translated under the pseudo-locale.
## TEST-ONLY fixtures, marked where used: attributes, combat_exp and skill levels set.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SCHOOL: StringName = &"snow.school_compound.schoolhall.master"

var _count: int = 0
var _failures: Array[String] = []
var _session: WorldSessionController
var _player: WorldPlayerRuntimeState
var _state: CharacterState
var _hud: SharedGameplayUI
var _school: TeacherService


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_every_master()
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_state = _player.state
	_hud = _session.shared_ui()
	var map: WorldMapController = MapPlaces.enter(_session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	_check(map != null and _beside(map, &"snow.schoolhall", &"snow.schoolhall.master.1"), "in the hall")
	await tree.physics_frame
	await tree.process_frame
	await tree.process_frame
	_school = map.service(SCHOOL) as TeacherService
	_test_apprentice_page()
	_test_quotes()
	_test_arts_page()
	_test_pseudo_locale()
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## A commoner (no family, 100 coins short of a silver tael never) before each master.
func _test_every_master() -> void:
	var student := CharacterState.new()
	student.gender = CharacterState.GENDER_MALE
	student.attributes.courage = 22
	student.attributes.composure = 18
	student.attributes.spirituality = 30
	student.progression.combat_experience = 5000
	var poor: Callable = func(_price: int) -> bool: return false
	var expected: Dictionary[StringName, Array] = {
		&"common.npc.swordsman.master": [["胆识 ≥ 20（你 22）", true], ["定力 ≥ 20（你 18）", false]],
		&"cloud.npc.b_header": [["胆识 ≥ 25（你 22）", false]],
		&"common.npc.juechen.master": [["灵性 ≥ 24（你 30）", true], ["实战经验 ≥ 100000（你 5000）", false], ["只收没有门派的人", true]],
		&"common.npc.taoist.taolord": [["只收男弟子", true]],
		&"common.npc.dancer.master": [["只收女弟子", false]],
		&"common.npc.bonze.master": [["只收男弟子", true], ["须先剃度出家", false]],
		&"common.npc.beggar.master": [["身上的钱不到 1 两银子", true]],
		&"common.npc.scholar.master": [["另有条件（拜师时便知）", false]],
		&"common.npc.fighter.champion": [["须通过考验", null]],
		&"common.npc.fighter.master": [["拜师时另有要求", null]],
		&"city.npc.chen": [["须另有机缘", null]],
		&"latemoon.npc.room.elon": [["实战经验 ≥ 100000（你 5000）", false], ["只收女弟子", false], ["只收没有门派的人", true], ["须通过考验", null]],
		&"latemoon.npc.room.annihi": [["不收徒", false]],
	}
	var catalog: ContentCatalog = GameContent.catalog()
	for npc_id: StringName in expected:
		var master: NpcDefinition = catalog.npc(npc_id)
		if master == null:
			_check(false, "no %s" % npc_id)
			continue
		var rows: Array[ApprenticeConditions.Row] = ApprenticeConditions.of(student, master, NpcApprenticeship.new(), poor, NpcApprenticeship.COMMONER_TITLE, "阁下")
		_check(_rows(rows) == expected[npc_id], "%s: %s" % [npc_id, _rows(rows)])
	# Nothing a master keeps for the asking is told before (owner Q3).
	for npc_id: StringName in expected:
		for row: Array in expected[npc_id]:
			for secret: String in ["桃林", "三招", "三鞭", "信", "守门规", "发誓"]:
				_check(not String(row[0]).contains(secret), "%s tells %s" % [npc_id, secret])
	# 骆云舟's 桃林: told once he has said it (marks/书生), met once walked (marks/桃林).
	var scholar: NpcDefinition = catalog.npc(&"common.npc.scholar.master")
	student.marks["书生"] = 1
	var rows: Array[ApprenticeConditions.Row] = ApprenticeConditions.of(student, scholar, NpcApprenticeship.new(), poor, NpcApprenticeship.COMMONER_TITLE, "阁下")
	_check(_rows(rows) == [["骆云舟说过：你还是先走一趟东边的桃林吧。", false]], "the 桃林 once he said it: %s" % [_rows(rows)])
	student.marks["桃林"] = 1
	rows = ApprenticeConditions.of(student, scholar, NpcApprenticeship.new(), poor, NpcApprenticeship.COMMONER_TITLE, "阁下")
	_check(_rows(rows) == [["另有条件", true]], "walked: met, still not named: %s" % [_rows(rows)])
	var rich: Callable = func(_price: int) -> bool: return true
	rows = ApprenticeConditions.of(student, catalog.npc(&"common.npc.beggar.master"), NpcApprenticeship.new(), rich, NpcApprenticeship.COMMONER_TITLE, "阁下")
	_check(_rows(rows) == [["身上的钱不到 1 两银子", false]], "carrying a tael: %s" % [_rows(rows)])
	rows = ApprenticeConditions.of(student, catalog.npc(&"common.npc.juechen.master"), NpcApprenticeship.new(), poor, "封山剑派第十四代弟子", "阁下")
	_check(_rows(rows).back() == ["只收没有门派的人", false], "a family's member: %s" % [_rows(rows)])
	_check(ApprenticeConditions.money(10000) == "1 两黄金" and ApprenticeConditions.money(250) == "250 文钱", "money")


## 柳淳风's 拜师 page and 查看 before the player is his: his two conditions.
func _test_apprentice_page() -> void:
	_state.attributes.courage = 30 # TEST-ONLY
	_state.attributes.composure = 10
	var nearby: SharedUiNearby = _hud.nearby
	var text: String = nearby.conditions_text(_school)
	var courage: int = NpcApprenticeship.requirement_value(_state, &"cor")
	var composure: int = NpcApprenticeship.requirement_value(_state, &"cps")
	_check(text == "收徒条件：\n· 胆识 ≥ 20（你 %d） ✓\n· 定力 ≥ 20（你 %d） ✗" % [courage, composure], "the 拜师 page's list: " + text)
	var thing: WorldNearbyThing = _thing()
	_check(thing != null and nearby.about(thing)[0].has("拜师条件还差 1 项（详见拜师）。"), "查看 counts them: %s" % [nearby.about(thing) if thing != null else null])
	_state.attributes.composure = 30
	_check(nearby.about(thing)[0].has("拜师条件都已满足（详见拜师）。"), "all met: %s" % [nearby.about(thing)])
	_school.request_apprentice()
	_check(_state.family.family_id == &"family.fonxan", "his apprentice")
	_check(nearby.conditions_text(_school).is_empty() and not "\n".join(nearby.about(thing)[0]).contains("拜师条件"), "his own master: no conditions")


## The 请教 page's line under each skill.
func _test_quotes() -> void:
	var teacher_level: int = _school.npc.character_state.skills.raw_level(&"sword")
	_check(teacher_level > 22, "柳淳风's sword: %d" % teacher_level)
	_state.skills.set_raw_level(&"sword", 10) # TEST-ONLY
	_state.progression.combat_experience = 1000
	_state.progression.potential = 1000
	_school.interact()
	var panel: TeacherPanel = _school.ui
	_check(panel.quote_labels[&"sword"].text == "还能学到 22 级（22 级要再学，须实战经验 ≥ 1064）。", "the experience gate: " + panel.quote_labels[&"sword"].text)
	_check(panel.quote_labels[&"sword"].get_index() + 1 == panel.learn_buttons[&"sword"].get_parent().get_index(), "right above its buttons")
	_check(panel.quote_labels[&"fonxansword"].text == "学不了：你的内力不够，没有办法练封山剑法。", "valid_learn()'s refusal: " + panel.quote_labels[&"fonxansword"].text)
	_state.progression.combat_experience = 100000000
	panel._learn(&"sword")
	_check(panel.quote_labels[&"sword"].text == "还能学到 %d 级（柳淳风自己是 %d 级）。" % [teacher_level, teacher_level], "after a lesson, again: " + panel.quote_labels[&"sword"].text)
	_state.apprenticeship.betrayer_count = 1 # TEST-ONLY
	panel.close_panel()
	panel.interact()
	_check(panel.quote_labels[&"sword"].text == "还能学到 %d 级（背叛师门 1 次，柳淳风只教到 %d - 20×1 = %d 级）。" % [teacher_level - 20, teacher_level, teacher_level - 20], "a betrayal: " + panel.quote_labels[&"sword"].text)
	_state.apprenticeship.betrayer_count = 0
	panel.close_panel()


## The 武学 page: how far practice goes, and the bottleneck.
func _test_arts_page() -> void:
	_state.skills.set_raw_level(&"unarmed", 20) # TEST-ONLY
	_state.skills.set_raw_level(&"liuh-ken", 10)
	_state.skills.set_learned_progress(&"liuh-ken", 0)
	_state.skills.map_skill(&"unarmed", &"liuh-ken")
	_state.skills.set_raw_level(&"force", 5)
	_state.skills.set_raw_level(&"fonxanforce", 1)
	_state.skills.map_skill(&"force", &"fonxanforce")
	_state.recovery.inner_force.maximum = 10
	_hud.open_martial_arts()
	var page: MartialArtsPage = _hud.martial_arts_page()
	page.refresh()
	_check(page._use_texts[&"unarmed"].text.ends_with("\n练习可练到 20 级（基本拳脚的等级）"), "practice up to the basic skill: " + page._use_texts[&"unarmed"].text)
	_check(not page._use_texts[&"force"].text.contains("练习"), "封山派内功 is not practised: no line")
	var cap: int = CultivationService.exercise_cap(_state, _session.martial_arts().apply_modifier(&"force"))
	_check(page.force_cap_text.text == "最大内力可练到 %d" % cap, "the force cap: " + page.force_cap_text.text)
	_state.skills.set_raw_level(&"unarmed", 10)
	_state.recovery.inner_force.maximum = cap
	page.refresh()
	_check(page._use_texts[&"unarmed"].text.ends_with("\n练习只攒进度，基本拳脚到 11 级才会升级"), "weak mode: " + page._use_texts[&"unarmed"].text)
	_check(page.force_cap_text.text == "最大内力已到瓶颈（%d），先提高基本内功" % cap, "at the bottleneck: " + page.force_cap_text.text)
	_state.skills.set_learned_progress(&"liuh-ken", 122)
	page.refresh()
	_check(page._use_texts[&"unarmed"].text.ends_with("\n这一级的进度已攒满，先把基本拳脚提高到 11 级"), "progress full: " + page._use_texts[&"unarmed"].text)
	_check(page.mana_cap_text.text == "最大法力已到瓶颈（0），先提高基本咒文", "no spells: " + page.mana_cap_text.text)
	_hud.dismiss_current_panel()


func _test_pseudo_locale() -> void:
	var translation: Translation = PseudoLocale.translation()
	var locale: String = TranslationServer.get_locale()
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(PseudoLocale.CODE)
	_school.interact()
	_check(VisibleTextScan.untranslated(_school.ui.panel).is_empty(), "the 请教 page: %s" % [VisibleTextScan.untranslated(_school.ui.panel)])
	_school.ui.close_panel()
	_hud.open_martial_arts()
	_check(VisibleTextScan.untranslated(_hud.martial_arts_page()).is_empty(), "the 武学 page: %s" % [VisibleTextScan.untranslated(_hud.martial_arts_page())])
	_hud.dismiss_current_panel()
	var student := CharacterState.new()
	var untranslated: Array[String] = []
	for npc_id: StringName in [&"common.npc.swordsman.master", &"common.npc.juechen.master", &"common.npc.beggar.master", &"latemoon.npc.room.elon", &"city.npc.chen", &"common.npc.bonze.master"]:
		for row: ApprenticeConditions.Row in ApprenticeConditions.of(student, GameContent.catalog().npc(npc_id), NpcApprenticeship.new(), func(_p: int) -> bool: return false, NpcApprenticeship.COMMONER_TITLE, "阁下"):
			if not PseudoLocale.untranslated(row.text).is_empty():
				untranslated.append(row.text)
	_check(untranslated.is_empty(), "the conditions: %s" % [untranslated])
	TranslationServer.set_locale(locale)
	TranslationServer.remove_translation(translation)


func _rows(rows: Array[ApprenticeConditions.Row]) -> Array:
	var out: Array = []
	for row: ApprenticeConditions.Row in rows:
		out.append([row.text, null if row.state == ApprenticeConditions.State.UNSAID else row.state == ApprenticeConditions.State.MET])
	return out


func _thing() -> WorldNearbyThing:
	_hud.nearby.refresh()
	return _hud.nearby.find(_school.npc.character_id)


func _to_snow(tree: SceneTree) -> void:
	Input.action_press("move_right")
	for _step: int in range(400):
		await tree.physics_frame
		if _session.active_map_id() == &"snow.outdoor":
			break
	Input.action_release("move_right")
	await tree.physics_frame
	_session.set_process(false)
	_check(_session.active_map_id() == &"snow.outdoor", "out of the Inn")


func _beside(map: WorldMapController, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			map.runtime_player_body().global_position = marker.global_position + offset
			return _player.set_world_location(map.location_for_zone(zone_id))
	return false


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("training hints: " + label)
