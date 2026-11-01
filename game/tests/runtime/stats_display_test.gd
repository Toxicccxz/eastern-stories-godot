extends RefCounted

## 数值用到才出现 (现代基线 C; DECISIONS「数值用到才出现」): stats_display.json has a name and a
## line for every number; 法力 with 基本咒文, 灵力 with 基本法术, each on its own; 杀气 and 加力
## while they are not 0; 经典 shows all; the 角色 page's cells and the 武学 page's sections
## follow; every shown number has its hover. TEST-ONLY fixtures, marked where used.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const NUMBERS: Array[StringName] = [
	&"tracks", &"essence", &"vitality", &"spirit", &"force", &"enforce", &"mana", &"atman", &"bellicosity",
	&"food", &"water", &"combat_experience", &"potential", &"score", &"kills", &"burden", &"weight",
	&"strength", &"courage", &"intelligence", &"spirituality", &"composure", &"personality", &"constitution", &"karma",
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_table()
	_test_rules()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	_test_sheet(session)
	_test_arts_page(session)
	_test_translated(session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_table() -> void:
	var table: StatDisplayTable = GameContent.catalog().stats_display()
	for stat_id: StringName in NUMBERS:
		var stat: StatDisplayDefinition = table.stat(stat_id)
		_check(stat != null and not stat.display_name.is_empty() and not stat.hint.is_empty(), "'%s' has a name and a line" % stat_id)
	_check(table.ids().size() == NUMBERS.size(), "nothing else in the table: %s" % [table.ids()])
	var errors: Array[String] = []
	StatDisplayDefinition.from_record(ContentRecordReader.new({"id": "x", "name": "x", "hint": "x", "when_resource": "gold"}, "test", errors))
	StatDisplayDefinition.from_record(ContentRecordReader.new({"id": "y", "name": "y", "hint": "y", "when_nonzero": "gold"}, "test", errors))
	_check(errors.size() == 2, "a condition on nothing known is refused: %s" % [errors])
	_check(GameContent.catalog().pacing().stats_appear_when_used and not PacePresets.of(GameContent.catalog().pacing(), CharacterState.PACE_CLASSIC).stats_appear_when_used, "现代 on, 经典 off")


func _test_rules() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state := CharacterState.new()
	for stat_id: StringName in [&"mana", &"atman", &"bellicosity", &"enforce"]:
		_check(not catalog.stat_shown(stat_id, state), "a new character has no '%s'" % stat_id)
	for stat_id: StringName in [&"essence", &"force", &"composure", &"score"]:
		_check(catalog.stat_shown(stat_id, state), "'%s' always shows" % stat_id)
	# TEST-ONLY: the skill, then the resource alone.
	state.skills.set_raw_level(SkillIds.SPELLS, 1)
	_check(catalog.stat_shown(&"mana", state) and not catalog.stat_shown(&"atman", state), "基本咒文: 法力, not 灵力")
	state.skills.remove_skill(SkillIds.SPELLS)
	state.skills.set_raw_level(SkillIds.MAGIC, 1)
	_check(catalog.stat_shown(&"atman", state) and not catalog.stat_shown(&"mana", state), "基本法术: 灵力, not 法力")
	state.skills.remove_skill(SkillIds.MAGIC)
	state.skills.set_raw_level(&"essencemagic", 1)
	state.skills.map_skill(SkillIds.MAGIC, &"essencemagic")
	_check(catalog.stat_shown(&"atman", state) and not catalog.stat_shown(&"mana", state), "a 神通 enabled before 基本法术: 灵力 too")
	state.skills.unmap_skill(SkillIds.MAGIC)
	state.skills.remove_skill(&"essencemagic")
	state.recovery.mana.maximum = 10
	_check(catalog.stat_shown(&"mana", state), "a maximum shows it whatever the skills")
	state.recovery.mana.maximum = 0
	state.recovery.atman.current = 3
	_check(catalog.stat_shown(&"atman", state), "something left shows it too")
	state.recovery.atman.current = 0
	state.attributes.bellicosity = 1
	_check(catalog.stat_shown(&"bellicosity", state), "杀气 after the first kill")
	state.attributes.bellicosity = -4
	_check(catalog.stat_shown(&"bellicosity", state), "below 0 it shows too (a donation does not stop at 0)")
	state.attributes.bellicosity = 0
	_check(not catalog.stat_shown(&"bellicosity", state), "back at 0 it goes")
	state.attributes.force_factor = 3
	_check(catalog.stat_shown(&"enforce", state), "加力 once set")
	state.attributes.force_factor = 0
	var base: PacingDefinition = catalog.pacing()
	catalog.set_pacing(PacePresets.of(base, CharacterState.PACE_CLASSIC))
	for stat_id: StringName in [&"mana", &"atman", &"bellicosity", &"enforce"]:
		_check(catalog.stat_shown(stat_id, state), "经典 shows '%s' as score.c does" % stat_id)
	catalog.set_pacing(base)


func _test_sheet(session: WorldSessionController) -> void:
	var sheet := CharacterSheet.new()
	var state: CharacterState = session.player_runtime().state
	sheet.refresh(session.player_runtime(), session)
	var text: String = sheet.text()
	_check(text.contains("内力 ") and not text.contains("法力") and not text.contains("灵力") and not text.contains("杀气") and not text.contains("加力"), "a new character's page: " + text)
	for stat_id: StringName in sheet.cells:
		_check(not sheet.cells[stat_id].tooltip_text.is_empty(), "'%s' has its hover" % stat_id)
	_check(sheet.cells[&"composure"].text == "定力 %d" % state.attributes.composure and sheet.cells[&"composure"].tooltip_text.contains("抢攻"), "定力 says what it does to the other's 抢攻")
	_check(sheet.potential_cap.tooltip_text == sheet.cells[&"potential"].tooltip_text and not sheet.kills.tooltip_text.is_empty(), "the page's two whole lines hover too")
	# TEST-ONLY: the skills and the first kill.
	state.skills.set_raw_level(SkillIds.SPELLS, 1)
	state.attributes.bellicosity = 2
	sheet.refresh(session.player_runtime(), session)
	text = sheet.text()
	_check(text.contains("法力 0 / 0") and not text.contains("灵力") and text.contains("杀气 2"), "法力 and 杀气 appear, 灵力 does not: " + text)
	state.skills.remove_skill(SkillIds.SPELLS)
	state.attributes.bellicosity = 0
	sheet.free()


func _test_arts_page(session: WorldSessionController) -> void:
	var page: MartialArtsPage = session.shared_ui().arts_page
	var state: CharacterState = session.player_runtime().state
	page.refresh()
	var quiet: Array[Control] = page.meditate_rows + page.respirate_rows
	_check(not quiet.is_empty() and quiet.all(func(row: Control) -> bool: return not row.visible), "no 冥思 or 修行 before their skills")
	_check(page.bellicosity_text.text == "定力 %d" % state.attributes.composure and page.force_text.text == "内力 %d / %d" % [state.recovery.inner_force.current, state.recovery.inner_force.maximum], "定力 alone, 内力 alone: %s | %s" % [page.bellicosity_text.text, page.force_text.text])
	_check(page.force_text.tooltip_text.contains("打坐") and page.bellicosity_text.tooltip_text.contains("抢攻"), "their hovers")
	# TEST-ONLY: the skill.
	state.skills.set_raw_level(SkillIds.MAGIC, 1)
	page.refresh()
	_check(page.respirate_rows.all(func(row: Control) -> bool: return row.visible) and not page.meditate_button.get_parent().visible, "基本法术 brings 修行 alone")
	state.skills.remove_skill(SkillIds.MAGIC)
	var base: PacingDefinition = GameContent.catalog().pacing()
	GameContent.catalog().set_pacing(PacePresets.of(base, CharacterState.PACE_CLASSIC))
	page.refresh()
	_check(quiet.all(func(row: Control) -> bool: return row.visible) and page.bellicosity_text.text.begins_with("杀气 0 · 定力"), "经典: both sections, 杀气 0 as ES2 lists it")
	GameContent.catalog().set_pacing(base)


## The sheet and every hover on it under the pseudo-locale; a page opens on its tab, not a cell.
func _test_translated(session: WorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var translation: Translation = PseudoLocale.translation()
	var locale: String = TranslationServer.get_locale()
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(PseudoLocale.CODE)
	hud.menu.present(GameMenu.Tab.CHARACTER)
	hud.panels.refresh_character()
	var player_name := PackedStringArray([session.player_runtime().facts.display_name])
	_check(VisibleTextScan.untranslated(hud.character_sheet, player_name).is_empty(), "the 角色 page: %s" % [VisibleTextScan.untranslated(hud.character_sheet, player_name)])
	_check(FocusNav.first_focusable(hud.character_sheet) == null, "a page does not open on a cell")
	hud.menu.dismiss()
	TranslationServer.set_locale(locale)
	TranslationServer.remove_translation(translation)


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
