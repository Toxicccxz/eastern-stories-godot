class_name TeacherPanel
extends CanvasLayer

## A teacher's panel: apprenticeship when the NPC takes apprentices, one learn
## button per skill it teaches, enable/disable for a specialized one. The
## TeacherService owns the rules; this only presents them and repeats the last
## lines the log received.
var _contact: TeacherService
var _rows: VBoxContainer
var _title: Label
var panel: PanelContainer
var status: Label
var feedback: Label
var apprentice_button: Button
var cancel_button: Button
## Skill ID -> its learn / enable / disable button.
var learn_buttons: Dictionary[StringName, Button] = {}
var enable_buttons: Dictionary[StringName, Button] = {}
var disable_buttons: Dictionary[StringName, Button] = {}


func configure(contact: TeacherService) -> void:
	_contact = contact


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	add_child(panel)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.09, 0.10, 0.085, 1)
	for side: String in ["left", "right", "top", "bottom"]:
		background.set("content_margin_" + side, 14.0)
	panel.add_theme_stylebox_override("panel", background)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	panel.add_child(_rows)
	_title = _label("", "Title")
	status = _label("", "Status")
	if _contact.takes_apprentices():
		apprentice_button = _button("Apprentice", "拜师 / 向师父请安", request_apprentice)
		cancel_button = _button("CancelApprentice", "取消拜师请求", cancel_apprentice)
	var catalog: ContentCatalog = GameContent.catalog()
	for skill_id: StringName in _contact.teachable_skills():
		var skill: SkillDefinition = catalog.skill(skill_id)
		learn_buttons[skill_id] = _button("Learn_" + String(skill_id), "", _learn.bind(skill_id))
		if not skill.valid_enabled_uses().is_empty():
			enable_buttons[skill_id] = _button("Enable_" + String(skill_id), "", _enable.bind(skill_id))
			disable_buttons[skill_id] = _button("Disable_" + String(skill_id), "", _disable.bind(skill_id))
	feedback = _label("", "Feedback")
	_button("Close", "离开", close_panel)
	_present()


## The title and the skill buttons in the shown language, put together again on each opening.
func _present() -> void:
	_title.text = _contact.npc.definition().short_name()
	var catalog: ContentCatalog = GameContent.catalog()
	for skill_id: StringName in learn_buttons:
		var skill: String = tr(catalog.skill(skill_id).display_name)
		learn_buttons[skill_id].text = tr("请教%s（一次）") % skill
		if enable_buttons.has(skill_id):
			enable_buttons[skill_id].text = tr("启用%s") % skill
			disable_buttons[skill_id].text = tr("停用%s") % skill


func _label(text: String, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	return label


func _button(node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	_rows.add_child(button)
	return button


func interact() -> void:
	if ExplorationPresentationBlocker.is_blocked(get_tree()) or not _contact.can_teach():
		return
	feedback.text = ""
	_present()
	_contact.open_panel(_contact.context_title(), panel)
	refresh()
	var first: Button = apprentice_button if apprentice_button != null else (learn_buttons.values()[0] if not learn_buttons.is_empty() else null)
	if first != null:
		first.grab_focus()


func _process(_delta: float) -> void:
	if not is_instance_valid(panel):
		return
	if panel.visible and not _contact.can_teach():
		close_panel()
	if panel.visible:
		refresh()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(panel) and panel.visible:
		_contact.map.player_body.quarantine_current_movement_input()


func refresh() -> void:
	var player: WorldPlayerRuntimeState = _contact.map.session.player_runtime()
	var state: CharacterState = player.state
	var catalog: ContentCatalog = GameContent.catalog()
	var lines: Array[String] = [player.shown_title()]
	for skill_id: StringName in _contact.teachable_skills():
		var skill: SkillDefinition = catalog.skill(skill_id)
		var line: String = tr("{skill} {level} · 学习进度 {progress} · 耗精 {cost}").format({
			"skill": tr(skill.display_name), "level": state.skills.raw_level(skill_id),
			"progress": state.skills.learned_progress(skill_id), "cost": _cost_text(state, skill_id),
		})
		if not skill.valid_enabled_uses().is_empty():
			var use_id: StringName = skill.valid_enabled_uses()[0]
			line += tr(" · 已启用") if state.skills.mapped_skill(use_id) == skill_id else tr(" · 未启用")
		lines.append(line)
	var uses: Array[StringName] = []
	for skill_id: StringName in _contact.teachable_skills():
		for use_id: StringName in catalog.skill(skill_id).valid_enabled_uses():
			if not uses.has(use_id):
				uses.append(use_id)
	for use_id: StringName in uses:
		var use_skill: SkillDefinition = catalog.skill(use_id)
		lines.append(tr("有效{skill} {level}").format({
			"skill": String(use_id) if use_skill == null else tr(use_skill.display_name),
			"level": state.skills.effective_level(use_id, player.armor.aggregate_numeric_modifiers().unarmed if use_id == &"unarmed" else 0),
		}))
	lines.append(tr("精 {gin}（须大于消耗才可进步） · 可用潜能 {potential} · 实战经验 {exp}").format({
		"gin": state.essence.current, "potential": state.progression.potential - state.progression.potential_spent,
		"exp": state.progression.combat_experience,
	}))
	status.text = "\n".join(lines)
	if cancel_button != null:
		cancel_button.visible = player.apprenticeship_request.is_pending()


func request_apprentice() -> void:
	if panel.visible:
		_contact.request_apprentice()
		_show_last()


func cancel_apprentice() -> void:
	if panel.visible:
		_contact.cancel_apprentice()
		_show_last()


func _learn(skill_id: StringName) -> void:
	if panel.visible:
		_contact.request_learn(skill_id)
		_show_last()


func _enable(skill_id: StringName) -> void:
	if not panel.visible:
		return
	var name: String = tr(GameContent.catalog().skill(skill_id).display_name)
	feedback.text = tr("已启用%s。") % name if _contact.enable(skill_id) else tr("无法启用%s：须已学会它和它的基本功夫。") % name
	refresh()


func _disable(skill_id: StringName) -> void:
	if not panel.visible:
		return
	var name: String = tr(GameContent.catalog().skill(skill_id).display_name)
	feedback.text = tr("已停用%s；技能与学习进度保留。") % name if _contact.disable(skill_id) else tr("%s没有启用。") % name
	refresh()


func _show_last() -> void:
	feedback.text = "\n".join(_contact.last_lines)
	refresh()


func close_panel() -> void:
	if not is_instance_valid(panel):
		return
	var was_open: bool = panel.visible
	panel.hide()
	_contact.map.session.shared_ui().close_business(panel)
	if was_open and is_instance_valid(_contact.map.player_body):
		_contact.map.player_body.quarantine_current_movement_input()


## learn.c's gin cost with the teacher's own int: 150/int + 150/int, doubled for a new skill.
@warning_ignore("integer_division")
func _cost_text(state: CharacterState, skill_id: StringName) -> String:
	var teacher_int: int = _contact.npc.character_state.attributes.intelligence
	if state.attributes.intelligence == 0 or teacher_int == 0:
		return tr("无法计算")
	var cost: int = 150 / teacher_int + 150 / state.attributes.intelligence
	return str(cost * 2 if state.skills.raw_level(skill_id) == 0 else cost)
