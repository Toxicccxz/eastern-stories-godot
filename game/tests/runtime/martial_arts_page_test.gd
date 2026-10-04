extends RefCounted

## Offense/defense routes, PR B, in a running Snow session: the character panel's
## 武学 page drives enable.c, exercise.c, practice.c, selflearn.c and study.c through
## its buttons, anywhere outside a fight; 柳淳风 teaches force, 封山派内功, 封山剑法
## and 基本招架 with valid_learn()'s own refusals; the state survives Save/Continue.
## TEST-ONLY fixtures, each marked where used: gin/sen refills between lessons,
## combat experience to learn past level 2, force skill 5 and max_force 49 (an hour
## of exercise), the silk jacket and the old book put into the pack.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")

var _count: int = 0
var _failures: Array[String] = []
var _session: OldPineWorldSessionController
var _player: WorldPlayerRuntimeState
var _state: CharacterState
var _hud: SharedGameplayUI
var _page: MartialArtsPage
var _school: TeacherService


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_session = Work.create_session(tree)
	await tree.process_frame
	await _to_snow(tree)
	_player = _session.player_runtime()
	_state = _player.state
	_hud = _session.shared_ui()
	_page = _hud.martial_arts_page()
	_test_page_opens()
	await _test_force_route(tree)
	await _test_sword_route(tree)
	_test_self_learn_and_study()
	_test_availability()
	# Continue is ES2's login: race/human.c adds max_force 50 / 4 to max kee. With that
	# applied first, the round trip is exact.
	CharacterDerivedValues.refresh_human_player_maxima(_state, _player.facts.age)
	_check(_state.vitality.maximum == 112, "the max kee a Continue gives: %d" % _state.vitality.maximum)
	var snapshot: GameSaveSnapshot = Work.capture(_session)
	var probe := Work.new()
	await probe.round_trip(tree, _session, snapshot, "routes B")
	_check(probe._failures.is_empty(), "Save/Continue keeps skills, mappings and internal power exactly: %s" % [probe._failures])
	_session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## The HUD's 角色 button, then the 武学 tab.
func _test_page_opens() -> void:
	var layout: SharedGameplayLayout = _hud._presentation_layout
	layout.character_button.pressed.emit()
	_check(layout.frame.visible and layout.character.sheet.visible and not _page.visible, "角色 opens on the score sheet")
	layout.character.arts_tab.pressed.emit()
	_check(_page.is_visible_in_tree() and not layout.character.sheet.visible, "the 武学 tab shows the page")
	_check(_page.force_text.text == "内力 0 / 0 (+0)", "the page shows internal power: " + _page.force_text.text)
	_page.exercise_button.pressed.emit()
	_check(_last() == ["你必须先用 enable 选择你要用的内功心法。"], "exercise.c without an enabled force")
	_check(_hud.log_lines().back() == "你必须先用 enable 选择你要用的内功心法。", "the line reaches the log")
	_hud.dismiss_current_panel()


## Apprentice, learn force and 封山派内功, enable it (force empties), exercise.
func _test_force_route(tree: SceneTree) -> void:
	var map: WorldMapController = _session.active_map() as WorldMapController
	_check(_beside(map, &"snow.schoolhall", &"snow.schoolhall.master.1"), "in the hall")
	await tree.physics_frame
	_school = map.service(&"snow.outdoor.schoolhall.master") as TeacherService
	_school.request_apprentice()
	_check(_state.family.family_id == &"family.fonxan", "apprenticed to 柳淳风")
	_state.progression.combat_experience = 1000 # TEST-ONLY: lessons past level 2.
	_check(_learn_to(&"force", 1) and _learn_to(&"fonxanforce", 1), "learn.c: force and 封山派内功 from 柳淳风")
	_state.recovery.inner_force.current = 5 # TEST-ONLY: some force to lose.
	_hud.open_martial_arts()
	_check(_page.buttons.has("enable:force:fonxanforce") and not _page.buttons.has("practice:force"), "激发封山派内功 offered, nothing to practise yet")
	_page.buttons["enable:force:fonxanforce"].pressed.emit()
	_check(_state.skills.mapped_skill(&"force") == &"fonxanforce" and _state.recovery.inner_force.current == 0, "enable force fonxanforce empties force")
	_check(_last() == ["Ok.", "你改用另一种内功，内力必须重新锻炼。"], "enable.c's lines " + str(_last()))
	_check(not _page.buttons.has("enable:force:fonxanforce") and _page.buttons.has("disable:force") and _page.buttons.has("practice:force"), "the enabled skill is not offered again (it would empty force)")
	_check(_page.skills_text.text.contains("□封山派内功"), "skills.c marks the enabled skill: " + _page.skills_text.text)
	_page.buttons["practice:force"].pressed.emit()
	_check(_last() == ["封山派内功只能用学的，或是从运用(exert)中增加熟练度。"], "fonxanforce.c refuses practice")
	@warning_ignore("integer_division")
	var gain: int = 30 * (_state.skills.raw_level(&"force") + _state.attributes.constitution) / 300
	var kee: int = _state.vitality.current
	_page.exercise_amount.value = 30
	_page.exercise_button.pressed.emit()
	_check(_last()[0] == "你坐下来运气用功，一股内息开始在体内流动。" and _state.vitality.current == kee - 30, "exercise 30 kee")
	_check(_state.recovery.inner_force.current == gain or _last().size() == 2, "gain kee * (force + con) / 300 = %d" % gain)
	# TEST-ONLY: an hour of exercise (run_with_max_force.gd does this for a playtest),
	# and force 5, without which max_force stops at (5 + query_skill(force) / 5) * 10.
	_state.skills.set_raw_level(&"force", 5)
	_state.recovery.inner_force.maximum = 49
	_state.recovery.inner_force.current = 98
	_heal()
	_page.exercise_button.pressed.emit()
	_check(_last() == ["你坐下来运气用功，一股内息开始在体内流动。", "你的内力增强了！"] and _state.recovery.inner_force.maximum == 50, "max_force 50 " + str(_last()))
	_page.refresh()
	_check(_page.force_text.text == "内力 50 / 50 (+0)", "the page follows: " + _page.force_text.text)
	_hud.dismiss_current_panel()
	await tree.physics_frame


## 封山剑法: valid_learn()'s refusals, the 竹剑, learn, enable for sword and parry, practise.
func _test_sword_route(tree: SceneTree) -> void:
	_state.recovery.inner_force.maximum = 49
	_heal()
	_school.request_learn(&"fonxansword")
	_check(_school.last_lines == ["你的内力不够，没有办法练封山剑法。"], "learn.c prints valid_learn()'s line (the last notify_fail wins): " + str(_school.last_lines))
	_state.recovery.inner_force.maximum = 50
	_school.request_learn(&"fonxansword")
	_check(_school.last_lines == ["你必须先找一把剑才能练剑法。"], "no sword in hand: " + str(_school.last_lines))
	var map: WorldMapController = _session.active_map() as WorldMapController
	var sword: StringName = ItemSpawnDefinition.item_instance_id(_session.item_id_allocator().scope, &"snow.weapon_storage.bamboo_sword.1")
	_check(_beside(map, &"snow.weapon_storage", &"snow.weapon_storage.bamboo_sword.1") and map.select_floor_item(sword) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "the 竹剑 taken")
	_check(_session.wield_player_item(sword) != null and _state.equipment.primary_weapon() != null, "the 竹剑 wielded")
	_check(_beside(map, &"snow.schoolhall", &"snow.schoolhall.master.1"), "back in the hall")
	await tree.physics_frame
	_check(_learn_to(&"sword", 2) and _learn_to(&"fonxansword", 1), "基本剑法 and 封山剑法 learnt with the 竹剑")
	_hud.open_martial_arts()
	_check(_page.buttons.has("enable:sword:fonxansword") and _page.buttons.has("enable:force:fonxanforce") == false, "激发封山剑法 for sword")
	_page.buttons["enable:sword:fonxansword"].grab_focus()
	_page.buttons["enable:sword:fonxansword"].pressed.emit()
	var focused: Control = _page.get_viewport().gui_get_focus_owner()
	_check(focused != null and focused == _page.buttons.get("disable:sword"), "focus moves to 停用 after 激发 (the button is rebuilt)")
	@warning_ignore("integer_division")
	var effective: int = _state.skills.raw_level(&"sword") / 2 + _state.skills.raw_level(&"fonxansword")
	_check(_page._use_texts[&"sword"].text == "剑法：封山剑法 · 有效等级 %d" % effective, "enable.c's list: " + _page._use_texts[&"sword"].text)
	_check(_state.recovery.inner_force.current == 50, "enabling a sword skill keeps force")
	_check(_page.buttons.has("enable:parry:fonxansword"), "封山剑法 can be enabled for parry too")
	_page.buttons["enable:parry:fonxansword"].pressed.emit()
	_check(_last() == ["你连「基本招架」都没学会，更别提封山剑法了。"], "parry needs 基本招架: " + str(_last()))
	_hud.dismiss_current_panel()
	_check(_learn_to(&"parry", 1), "基本招架 learnt")
	_hud.open_martial_arts()
	_page.buttons["enable:parry:fonxansword"].pressed.emit()
	_check(_state.skills.mapped_skill(&"parry") == &"fonxansword" and _page._use_texts[&"parry"].text.begins_with("招架：封山剑法"), "封山剑法 enabled for parry")
	_heal()
	var kee: int = _state.vitality.current
	_page.buttons["practice:sword"].pressed.emit()
	_check(_last().slice(0, 1) == ["你按著所学练了一遍封山剑法。"] and _last().back() == "你的封山剑法进步了！", "practice sword: " + str(_last()))
	_check(_state.vitality.current == kee - 30 and _state.recovery.inner_force.current == 47, "practice spends 30 kee and 3 force")
	var yellow: String = "[color=#%s]你的封山剑法进步了！[/color]" % SharedGameplayUI.ES2_COLORS[ColoredLine.HIY].to_html(false)
	_check(_hud.combat_log.text.ends_with(yellow), "practice.c's line in HIY")
	_page.buttons["practice:parry"].pressed.emit()
	_check(_last().back() == "你的封山剑法进步了！", "practising parry practises 封山剑法 too")
	# A jacket with armor_prop/dodge 6 (柳淳风's 丝绸马褂): the effective level in HIC.
	_add_item(&"test:silk_cloth", &"es2:daemon/class/swordsman/silk_cloth") # TEST-ONLY
	for row: PlayerInventoryRowProjection in _session.player_inventory_rows():
		if _player.armor.is_worn(row.item_instance_id):
			_session.remove_player_item(row.item_instance_id)
	_session.wear_player_item(&"test:silk_cloth")
	_check(_player.armor.is_worn(&"test:silk_cloth"), "the jacket worn")
	_page.refresh()
	var cyan: String = "[color=#%s]6[/color]" % SharedGameplayUI.ES2_COLORS[ColoredLine.HIC].to_html(false)
	_check(_page._use_texts.has(&"dodge") and _page._use_texts[&"dodge"].text == "轻功：无 · 有效等级 %s" % cyan, "apply/dodge counts, in HIC: " + str(_page._use_texts.get(&"dodge")))
	_hud.dismiss_current_panel()


func _test_self_learn_and_study() -> void:
	_hud.open_martial_arts()
	_check(_page.buttons.has("self_learn:sword") and _page.buttons.has("self_learn:force") and not _page.buttons.has("self_learn:fonxansword"), "自学 for selflearn.c's basic skills")
	_page.buttons["self_learn:sword"].pressed.emit()
	_check(_last() == ["你得有「基本剑法」的入门知识才行。"], "selflearn.c needs level 40")
	_check(not _page.study_row.visible, "no book, no 研读")
	_hud.dismiss_current_panel()
	_add_item(&"test:old_book", &"es2:obj/old_book") # TEST-ONLY: the scavenger's book
	_hud.open_martial_arts()
	_check(_page.study_row.visible and _page.buttons["study:test:old_book"].text == "研读旧书", "研读旧书 offered")
	_page.buttons["study:test:old_book"].pressed.emit()
	_check(_last() == ["你是个文盲，先学学读书识字(literate)吧。"], "study.c needs literate")
	_hud.dismiss_current_panel()
	_check(_learn_to(&"literate", 1), "读书识字 from 柳淳风")
	_hud.open_martial_arts()
	_state.skills.set_raw_level(&"force", 9) # TEST-ONLY: just below the book's 10
	var sen: int = _state.spirit.current
	var spent: int = _state.progression.potential_spent
	_page.buttons["study:test:old_book"].pressed.emit()
	_check(_last().back() == "你研读有关基本内功的技巧，似乎有点心得。" and _state.spirit.current < sen and _state.progression.potential_spent == spent, "study.c spends sen, not potential: " + str(_last()))
	_state.skills.set_raw_level(&"force", 11)
	_page.buttons["study:test:old_book"].pressed.emit()
	_check(_last() == ["你研读了一会儿，但是发现上面所说的对你而言都太浅了，没有学到任何东西。"], "the book teaches to 10")
	_state.skills.set_raw_level(&"force", 5)
	_hud.dismiss_current_panel()


func _test_availability() -> void:
	var arts: PlayerMartialArts = _session.martial_arts()
	_player.relationship.add_opponent(&"opponent")
	var lines: Array[String] = _hud.log_lines()
	_check(not arts.enable(&"sword", &"fonxansword") and arts.practice(&"sword") == null and arts.exercise(30) == null, "nothing in a fight")
	_hud.open_martial_arts()
	_check(not _hud._presentation_layout.frame.visible and _hud.log_lines() == lines, "the panel stays closed, no lines")
	_player.relationship.remove_opponent(&"opponent")
	_check(_player.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS) and not arts.disable(&"sword") and arts.study(&"test:old_book") == null, "nothing while unconscious")
	_player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	_player.busy.start_busy(1)
	_check(arts.disable(&"sword") and arts.enable(&"sword", &"fonxansword"), "enable.c has no busy check")
	_player.busy.advance()


## Lessons from 柳淳风 until the skill reaches `level`.
func _learn_to(skill_id: StringName, level: int) -> bool:
	for lesson: int in 60:
		if _state.skills.raw_level(skill_id) >= level:
			return true
		_heal()
		var teacher: CharacterState = _school.npc.character_state
		teacher.spirit.current = teacher.spirit.maximum # TEST-ONLY
		_school.request_learn(skill_id)
	return _state.skills.raw_level(skill_id) >= level


## TEST-ONLY: gin, kee and sen full.
func _heal() -> void:
	for resource: CharacterResourceState in [_state.essence, _state.vitality, _state.spirit]:
		resource.effective = resource.maximum
		resource.current = resource.maximum


func _last() -> Array[String]:
	return ColoredLine.texts(_session.martial_arts().last_lines)


func _add_item(id: StringName, definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(_session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var item: ItemInstance = ItemInstance.new(id, definition_id)
	_check(context.inventory.register_item(item, content.own_weight) and context.index.register_snapshot(item) and context.inventory._apply_reparent(id, context.endpoint()), "test item %s" % id)


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
		_failures.append("martial arts page: " + label)
